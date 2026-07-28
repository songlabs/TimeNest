import Foundation
import OSLog

enum EventUseCaseError: Error, LocalizedError {
    case invalidDateRange
    case eventNotFound

    var errorDescription: String? {
        switch self {
        case .invalidDateRange:
            return LocalizationManager.shared.localized(.editorInvalidDateRange)
        case .eventNotFound:
            return LocalizationManager.shared.localized(.eventNotFound)
        }
    }
}

enum WorkRecordPairSaveError: Error, Equatable, LocalizedError {
    case duplicateExplicitEventID
    case explicitEventNotFound
    case calendarMismatch
    case notWorkRecord
    case clockKindMismatch
    case sessionMismatch

    var errorDescription: String? {
        switch self {
        case .calendarMismatch, .sessionMismatch:
            return LocalizationManager.shared.localized(.calendarSharingPermissionDenied)
        case .duplicateExplicitEventID, .explicitEventNotFound, .notWorkRecord, .clockKindMismatch:
            return LocalizationManager.shared.localized(.eventNotFound)
        }
    }
}

struct EventNotificationCompensationError: Error, LocalizedError {
    let primaryError: Error
    let compensationResult: EventNotificationScheduleResult

    var errorDescription: String? {
        "\(primaryError.localizedDescription) [notification restoration: \(compensationResult.diagnosticStatus)]"
    }
}

private extension EventNotificationScheduleResult {
    var diagnosticStatus: String {
        switch self {
        case .scheduled:
            return "scheduled"
        case .noReminder:
            return "no_reminder"
        case .triggerDateInPast:
            return "trigger_date_in_past"
        case .denied:
            return "denied"
        case .failed, .failedWithCause:
            return "failed"
        }
    }
}

private enum EventUseCaseDiagnostics {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.song.TimeNest",
        category: "EventUseCase"
    )

    static func notificationRestorationFailed(
        primaryError: Error,
        compensationResult: EventNotificationScheduleResult
    ) {
        logger.error(
            "operation=update_notification_compensation primary_type=\(String(reflecting: type(of: primaryError)), privacy: .public) compensation_status=\(compensationResult.diagnosticStatus, privacy: .public)"
        )
    }
}

class EventUseCase {
    private let repository: EventRepository
    private let calendarRepository: (any CalendarRepository)?
    private let notificationScheduler: LocalNotificationScheduling?
    var onEventsChanged: (() -> Void)?

    init(
        repository: EventRepository,
        notificationScheduler: LocalNotificationScheduling? = nil,
        calendarRepository: (any CalendarRepository)? = nil
    ) {
        self.repository = repository
        self.notificationScheduler = notificationScheduler
        self.calendarRepository = calendarRepository
    }

    @discardableResult
    func createEvent(_ event: CalendarEvent) async throws -> EventNotificationScheduleResult {
        try validate(event)
        try await validateWriteAccess(calendarID: event.calendarID)
        var eventToSave = event
        let notificationResult = await scheduleNotification(for: eventToSave)
        eventToSave.notificationID = notificationResult.notificationID
        do {
            try await repository.create(eventToSave)
        } catch {
            if let notificationID = eventToSave.notificationID {
                notificationScheduler?.cancelNotification(id: notificationID)
            }
            throw error
        }
        onEventsChanged?()
        return notificationResult
    }

    struct BatchCreateResult {
        let savedEvents: [CalendarEvent]
        let notificationResults: [EventNotificationScheduleResult]

        var auxiliaryFailureCount: Int {
            notificationResults.filter {
                switch $0 {
                case .scheduled, .noReminder:
                    return false
                case .triggerDateInPast, .denied, .failed, .failedWithCause:
                    return true
                }
            }.count
        }
    }

    func createEventsBatch(
        _ events: [CalendarEvent],
        ifUnchanged expectedEvents: [CalendarEvent] = []
    ) async throws -> BatchCreateResult {
        for event in events {
            try validate(event)
            try await validateWriteAccess(calendarID: event.calendarID)
        }

        var savedEvents: [CalendarEvent] = []
        var notificationResults: [EventNotificationScheduleResult] = []
        for event in events {
            var eventToSave = event
            let notificationResult = await scheduleNotification(for: eventToSave)
            eventToSave.notificationID = notificationResult.notificationID
            savedEvents.append(eventToSave)
            notificationResults.append(notificationResult)
        }

        do {
            try await repository.createBatch(savedEvents, ifUnchanged: expectedEvents)
        } catch {
            savedEvents.compactMap(\.notificationID).forEach {
                notificationScheduler?.cancelNotification(id: $0)
            }
            throw error
        }

        onEventsChanged?()
        return BatchCreateResult(
            savedEvents: savedEvents,
            notificationResults: notificationResults
        )
    }

    @discardableResult
    func updateEvent(_ event: CalendarEvent) async throws -> EventNotificationScheduleResult {
        try validate(event)
        try await validateWriteAccess(calendarID: event.calendarID)
        guard let oldEvent = try await repository.event(id: event.id) else {
            throw EventUseCaseError.eventNotFound
        }
        var eventToSave = event
        let oldNotificationID = oldEvent.notificationID
        let notificationResult: EventNotificationScheduleResult

        if eventToSave.reminderOffsetMinutes == nil {
            notificationResult = .noReminder
            eventToSave.notificationID = nil
            try await repository.update(eventToSave)
            if let oldNotificationID {
                notificationScheduler?.cancelNotification(id: oldNotificationID)
            }
        } else {
            // Reuse the existing identifier so UNUserNotificationCenter replaces the request
            // without first creating a reminder-free gap.
            eventToSave.notificationID = oldNotificationID
            notificationResult = await scheduleNotification(for: eventToSave)
            eventToSave.notificationID = notificationResult.notificationID
            do {
                try await repository.update(eventToSave)
            } catch {
                if let newNotificationID = notificationResult.notificationID {
                    if newNotificationID != oldNotificationID {
                        notificationScheduler?.cancelNotification(id: newNotificationID)
                    }
                    if oldNotificationID != nil {
                        let compensationResult = await scheduleNotification(for: oldEvent)
                        guard case .scheduled = compensationResult else {
                            EventUseCaseDiagnostics.notificationRestorationFailed(
                                primaryError: error,
                                compensationResult: compensationResult
                            )
                            throw EventNotificationCompensationError(
                                primaryError: error,
                                compensationResult: compensationResult
                            )
                        }
                    }
                }
                throw error
            }
            if let oldNotificationID, oldNotificationID != eventToSave.notificationID {
                notificationScheduler?.cancelNotification(id: oldNotificationID)
            }
        }
        onEventsChanged?()
        return notificationResult
    }

    func deleteEvent(id: UUID) async throws {
        let event = try await repository.event(id: id)
        if let event {
            try await validateWriteAccess(calendarID: event.calendarID)
        }
        try await repository.delete(id: id)
        if let notificationID = event?.notificationID {
            notificationScheduler?.cancelNotification(id: notificationID)
        }
        onEventsChanged?()
    }

    @discardableResult
    func deleteEventsBatch(expectedEvents: [CalendarEvent]) async throws -> [CalendarEvent] {
        for event in expectedEvents {
            try await validateWriteAccess(calendarID: event.calendarID)
        }

        try await repository.deleteBatch(expectedEvents)
        expectedEvents.compactMap(\.notificationID).forEach {
            notificationScheduler?.cancelNotification(id: $0)
        }
        onEventsChanged?()
        return expectedEvents
    }

    func events(
        in range: DateInterval,
        calendarID: UUID = TimeNestCalendar.personalID
    ) async throws -> [CalendarEvent] {
        try await repository.events(in: range).filter { $0.calendarID == calendarID }
    }

    func event(id: UUID) async throws -> CalendarEvent? {
        try await repository.event(id: id)
    }

    func saveWorkRecordPair(_ request: WorkRecordPairSaveRequest) async throws {
        try await validateWriteAccess(calendarID: request.calendarID)

        if let clockInEventID = request.clockInEventID,
           clockInEventID == request.clockOutEventID {
            throw WorkRecordPairSaveError.duplicateExplicitEventID
        }

        var existingEvents = try await repository.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        existingEvents = existingEvents.filter {
            $0.calendarID == request.calendarID
                && $0.workInfo?.workSessionId == request.sessionID
                && $0.workClockKind != nil
        }

        let explicitClockIn = try await validatedExplicitWorkClockEvent(
            id: request.clockInEventID,
            expectedKind: .clockIn,
            request: request
        )
        let explicitClockOut = try await validatedExplicitWorkClockEvent(
            id: request.clockOutEventID,
            expectedKind: .clockOut,
            request: request
        )

        for explicitEvent in [explicitClockIn, explicitClockOut].compactMap({ $0 }) {
            if !existingEvents.contains(where: { $0.id == explicitEvent.id }) {
                existingEvents.append(explicitEvent)
            }
        }

        let sortedExisting = existingEvents.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        let existingClockIn = explicitClockIn
            ?? sortedExisting.first { $0.workClockKind == .clockIn }
        let existingClockOut = explicitClockOut
            ?? sortedExisting.first { $0.workClockKind == .clockOut }
        let now = Date()
        let clockIn = makeWorkClockEvent(
            existing: existingClockIn,
            id: existingClockIn?.id ?? UUID(),
            request: request,
            kind: .clockIn,
            now: now
        )
        let clockOut = makeWorkClockEvent(
            existing: existingClockOut,
            id: existingClockOut?.id ?? UUID(),
            request: request,
            kind: .clockOut,
            now: now
        )
        try validate(clockIn)
        try validate(clockOut)

        let retainedIDs = Set([clockIn.id, clockOut.id])
        let duplicates = existingEvents.filter { !retainedIDs.contains($0.id) }
        let expectedEvents = Dictionary(
            existingEvents.map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        ).values.map { $0 }

        try await repository.applyBatch(
            upserting: [clockIn, clockOut],
            deleting: duplicates,
            ifUnchanged: expectedEvents
        )
        expectedEvents.compactMap(\.notificationID).forEach {
            notificationScheduler?.cancelNotification(id: $0)
        }
        onEventsChanged?()
    }

    private func validatedExplicitWorkClockEvent(
        id: UUID?,
        expectedKind: WorkClockKind,
        request: WorkRecordPairSaveRequest
    ) async throws -> CalendarEvent? {
        guard let id else { return nil }
        guard let event = try await repository.event(id: id) else {
            throw WorkRecordPairSaveError.explicitEventNotFound
        }
        guard event.calendarID == request.calendarID else {
            throw WorkRecordPairSaveError.calendarMismatch
        }
        guard event.shiftTemplateID == nil,
              event.workInfo != nil,
              let actualKind = event.workClockKind else {
            throw WorkRecordPairSaveError.notWorkRecord
        }
        guard actualKind == expectedKind else {
            throw WorkRecordPairSaveError.clockKindMismatch
        }
        if let existingSessionID = event.workInfo?.workSessionId,
           existingSessionID != request.sessionID {
            throw WorkRecordPairSaveError.sessionMismatch
        }
        return event
    }

    func reassignEvents(from sourceCalendarID: UUID, to targetCalendarID: UUID) async throws {
        try await validateWriteAccess(calendarID: sourceCalendarID)
        try await validateWriteAccess(calendarID: targetCalendarID)
        try await performReassignment(from: sourceCalendarID, to: targetCalendarID)
    }

    func reassignEventsForStoppingOwnedCalendar(
        from sourceCalendarID: UUID,
        to targetCalendarID: UUID
    ) async throws {
        try await validateWriteAccess(calendarID: targetCalendarID)
        guard let calendarRepository,
              let source = try await calendarRepository.calendar(id: sourceCalendarID),
              source.kind == .sharedOwned,
              source.stopPhase.isStopping else {
            throw CalendarSharingError.permissionDenied
        }
        try await performReassignment(from: sourceCalendarID, to: targetCalendarID)
    }

    private func performReassignment(from sourceCalendarID: UUID, to targetCalendarID: UUID) async throws {
        try await repository.reassignEvents(
            from: sourceCalendarID,
            to: targetCalendarID
        )
        onEventsChanged?()
    }

    private func validateWriteAccess(calendarID: UUID) async throws {
        guard let calendarRepository else { return }
        if let calendar = try await calendarRepository.calendar(id: calendarID) {
            guard calendar.canEditContent else {
                throw CalendarSharingError.permissionDenied
            }
            return
        }
        // Migration fallback: personal rows remain usable even if the calendar bootstrap must retry.
        guard calendarID == TimeNestCalendar.personalID else {
            throw CalendarSharingError.permissionDenied
        }
    }

    func occurrences(
        in range: DateInterval,
        calendarID: UUID = TimeNestCalendar.personalID
    ) async throws -> [EventOccurrence] {
        let events = try await repository.events(in: range).filter { $0.calendarID == calendarID }
        let calendar = Calendar(identifier: .gregorian)

        return events.flatMap { event -> [EventOccurrence] in
            let isWorkClockEvent = event.workClockKind != nil

            if isWorkClockEvent {
                let occurrenceDate = event.workInfo?.workDate ?? event.startDate
                return [makeOccurrence(event: event, occurrenceDate: occurrenceDate)]
            }

            // 班次事件只生成一个 occurrence，使用 startDate 的日期
            if event.shiftTemplateID != nil {
                let occurrenceDate = calendar.startOfDay(for: event.startDate)
                return [makeOccurrence(event: event, occurrenceDate: occurrenceDate)]
            }

            return coveredDates(for: event, in: range, calendar: calendar).map { occurrenceDate in
                makeOccurrence(event: event, occurrenceDate: occurrenceDate)
            }
        }
        .sorted { lhs, rhs in
            let leftDay = lhs.isWorkClockEvent ? calendar.startOfDay(for: lhs.workDate) : lhs.occurrenceDate.toDate()
            let rightDay = rhs.isWorkClockEvent ? calendar.startOfDay(for: rhs.workDate) : rhs.occurrenceDate.toDate()
            if leftDay != rightDay { return leftDay < rightDay }
            let leftSessionTime = lhs.isWorkClockEvent ? sessionSortTime(for: lhs) : lhs.startDate
            let rightSessionTime = rhs.isWorkClockEvent ? sessionSortTime(for: rhs) : rhs.startDate
            if leftSessionTime != rightSessionTime { return leftSessionTime < rightSessionTime }
            if lhs.isClockInEvent != rhs.isClockInEvent { return lhs.isClockInEvent }
            return lhs.actualWorkClockDate < rhs.actualWorkClockDate
        }
    }

    private func makeOccurrence(event: CalendarEvent, occurrenceDate: Date) -> EventOccurrence {
        let dateOnly = DateOnly(from: occurrenceDate) ?? DateOnly(year: 2026, month: 1, day: 1)
        return EventOccurrence(
            id: "\(event.id)-\(dateOnly.id)",
            eventID: event.id,
            calendarID: event.calendarID,
            occurrenceDate: dateOnly,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            title: event.title,
            note: event.note,
            categoryID: event.categoryID,
            reminderOffsetMinutes: event.reminderOffsetMinutes,
            notificationID: event.notificationID,
            shiftTemplateID: event.shiftTemplateID,
            workInfo: event.workInfo
        )
    }

    private func coveredDates(for event: CalendarEvent, in range: DateInterval, calendar: Calendar) -> [Date] {
        guard event.endDate > event.startDate else {
            guard event.startDate >= range.start, event.startDate < range.end else { return [] }
            return [calendar.startOfDay(for: event.startDate)]
        }

        let coveredStart = max(event.startDate, range.start)
        let coveredEnd = min(event.endDate, range.end)
        guard coveredEnd > coveredStart else { return [] }

        var dates: [Date] = []
        var date = calendar.startOfDay(for: coveredStart)
        while date < coveredEnd {
            dates.append(date)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date), nextDate > date else {
                break
            }
            date = nextDate
        }
        return dates
    }

    private func sessionSortTime(for occurrence: EventOccurrence) -> Date {
        if occurrence.isClockInEvent {
            return occurrence.workInfo?.workInTime ?? occurrence.startDate
        }
        return occurrence.workInfo?.workInTime ?? occurrence.workInfo?.workOutTime ?? occurrence.startDate
    }

    private func validate(_ event: CalendarEvent) throws {
        guard event.endDate > event.startDate else {
            throw EventUseCaseError.invalidDateRange
        }
    }

    private func scheduleNotification(for event: CalendarEvent) async -> EventNotificationScheduleResult {
        guard event.reminderOffsetMinutes != nil else {
            return .noReminder
        }

        return await notificationScheduler?.scheduleEventNotificationResult(event: event) ?? .failed
    }

    private func makeWorkClockEvent(
        existing: CalendarEvent?,
        id: UUID,
        request: WorkRecordPairSaveRequest,
        kind: WorkClockKind,
        now: Date
    ) -> CalendarEvent {
        let clockDate: Date
        let workInfo: WorkInfo
        switch kind {
        case .clockIn:
            clockDate = request.clockInDate
            workInfo = WorkInfo(
                workInTime: request.clockInDate,
                workOutTime: nil,
                restHours: request.restHours,
                workDate: request.workDate,
                transportFee: request.transportFee,
                hourlyRate: request.hourlyRate,
                workSessionId: request.sessionID,
                isWorkOutTimeSet: request.isWorkOutTimeSet
            )
        case .clockOut:
            clockDate = request.clockOutDate
            workInfo = WorkInfo(
                workInTime: nil,
                workOutTime: request.clockOutDate,
                restHours: request.restHours,
                workDate: request.workDate,
                transportFee: request.transportFee,
                hourlyRate: request.hourlyRate,
                workSessionId: request.sessionID,
                isWorkOutTimeSet: request.isWorkOutTimeSet
            )
        }
        return CalendarEvent(
            id: id,
            calendarID: request.calendarID,
            title: request.title,
            note: nil,
            startDate: clockDate,
            endDate: CalendarEvent.defaultEndDate(for: clockDate, isAllDay: false),
            isAllDay: false,
            categoryID: existing?.categoryID,
            recurrenceRule: existing?.recurrenceRule ?? .none,
            reminderTemplateID: existing?.reminderTemplateID,
            reminderOffsetMinutes: nil,
            notificationID: nil,
            importSource: existing?.importSource,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            shiftTemplateID: nil,
            workInfo: workInfo
        )
    }
}
