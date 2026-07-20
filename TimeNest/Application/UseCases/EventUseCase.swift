import Foundation

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
        try await repository.create(eventToSave)
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
                case .triggerDateInPast, .denied, .failed:
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
        if let oldNotificationID = oldEvent.notificationID {
            notificationScheduler?.cancelNotification(id: oldNotificationID)
        }

        var eventToSave = event
        let notificationResult = await scheduleNotification(for: eventToSave)
        eventToSave.notificationID = notificationResult.notificationID
        try await repository.update(eventToSave)
        onEventsChanged?()
        return notificationResult
    }

    func deleteEvent(id: UUID) async throws {
        let event = try await repository.event(id: id)
        if let event {
            try await validateWriteAccess(calendarID: event.calendarID)
        }
        if let notificationID = event?.notificationID {
            notificationScheduler?.cancelNotification(id: notificationID)
        }
        try await repository.delete(id: id)
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
}
