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

    static func remoteNotificationRefreshFailed(
        result: EventNotificationScheduleResult
    ) {
        logger.error(
            "operation=remote_event_notification_refresh status=\(result.diagnosticStatus, privacy: .public)"
        )
    }

    static func remoteNotificationStatePersistenceFailed(_ error: Error) {
        logger.error(
            "operation=remote_event_notification_persist error_type=\(String(reflecting: type(of: error)), privacy: .public)"
        )
    }
}

class EventUseCase {
    private let repository: EventRepository
    private let calendarRepository: (any CalendarRepository)?
    private let notificationScheduler: LocalNotificationScheduling?
    /// Local user mutations only. The app may enqueue cloud work from this callback.
    var onEventsChanged: (() -> Void)?
    /// Remote materialization only. This callback is deliberately widget/UI-only.
    var onRemoteEventsMaterialized: (() -> Void)?

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
            let mutations = try await ownerMutations(oldEvent: nil, newEvent: eventToSave)
            try await persistLocalEventChange(
                upserting: [eventToSave],
                deleting: [],
                expected: [],
                mutations: mutations,
                fallback: { try await self.repository.create(eventToSave) }
            )
        } catch {
            if let notificationID = eventToSave.notificationID {
                notificationScheduler?.cancelNotification(id: notificationID)
            }
            throw error
        }
        onEventsChanged?()
        return notificationResult
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
            let mutations = try await ownerMutations(oldEvent: oldEvent, newEvent: eventToSave)
            try await persistLocalEventChange(
                upserting: [eventToSave],
                deleting: [],
                expected: [oldEvent],
                mutations: mutations,
                fallback: { try await self.repository.update(eventToSave) }
            )
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
                let mutations = try await ownerMutations(oldEvent: oldEvent, newEvent: eventToSave)
                try await persistLocalEventChange(
                    upserting: [eventToSave],
                    deleting: [],
                    expected: [oldEvent],
                    mutations: mutations,
                    fallback: { try await self.repository.update(eventToSave) }
                )
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
        let mutations = try await ownerMutations(oldEvent: event, newEvent: nil)
        try await persistLocalEventChange(
            upserting: [],
            deleting: [event].compactMap { $0 },
            expected: [event].compactMap { $0 },
            mutations: mutations,
            fallback: { try await self.repository.delete(id: id) }
        )
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

        let mutations = try await ownerMutationsForBatch(
            upserting: [],
            deleting: expectedEvents,
            expected: expectedEvents
        )
        try await persistLocalEventChange(
            upserting: [],
            deleting: expectedEvents,
            expected: expectedEvents,
            mutations: mutations,
            fallback: { try await self.repository.deleteBatch(expectedEvents) }
        )
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

    /// Creates independent local rows for the shareable events and shifts in one calendar.
    /// Work records and owner-local event metadata are intentionally not copied.
    @discardableResult
    func copyShareableEventsOnce(
        from sourceCalendarID: UUID,
        to targetCalendarID: UUID
    ) async throws -> [CalendarEvent] {
        guard sourceCalendarID != targetCalendarID else { return [] }
        try await validateWriteAccess(calendarID: targetCalendarID)

        let sourceEvents = try await events(
            in: DateInterval(start: .distantPast, end: .distantFuture),
            calendarID: sourceCalendarID
        )
        let now = Date()
        let copies = sourceEvents.compactMap { source -> CalendarEvent? in
            if let shift = SharedShiftMapper.snapshot(from: source) {
                return CalendarEvent(
                    id: UUID(),
                    calendarID: targetCalendarID,
                    title: shift.displayName,
                    note: nil,
                    startDate: shift.startDate,
                    endDate: shift.endDate,
                    isAllDay: false,
                    categoryID: nil,
                    recurrenceRule: .none,
                    reminderTemplateID: nil,
                    importSource: nil,
                    createdAt: now,
                    updatedAt: now,
                    shiftTemplateID: source.shiftTemplateID
                )
            }
            guard let event = SharedEventMapper.snapshot(from: source) else { return nil }
            return CalendarEvent(
                id: UUID(),
                calendarID: targetCalendarID,
                title: event.title,
                note: nil,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                categoryID: nil,
                recurrenceRule: .none,
                reminderTemplateID: nil,
                importSource: nil,
                createdAt: now,
                updatedAt: now
            )
        }
        guard !copies.isEmpty else { return [] }
        for event in copies { try validate(event) }

        let mutations = try await ownerMutationsForBatch(
            upserting: copies,
            deleting: [],
            expected: []
        )
        try await persistLocalEventChange(
            upserting: copies,
            deleting: [],
            expected: [],
            mutations: mutations,
            fallback: {
                try await self.repository.applyBatch(
                    upserting: copies,
                    deleting: [],
                    ifUnchanged: []
                )
            }
        )
        onEventsChanged?()
        return copies
    }

    func event(id: UUID) async throws -> CalendarEvent? {
        try await repository.event(id: id)
    }

    /// Applies only SharedEvent schema fields from CloudKit while preserving owner-local fields
    /// such as note, reminder, category and import metadata. This deliberately bypasses the
    /// ordinary mutation callback so a remote merge cannot enqueue an owner overwrite.
    func mergeSharedEventFromCloud(
        _ snapshot: SharedEventSnapshot,
        calendarID: UUID
    ) async throws {
        if snapshot.isDeleted {
            try await removeSharedEventFromCloud(id: snapshot.id, calendarID: calendarID)
            return
        }

        let now = snapshot.updatedAt
        if let existing = try await repository.event(id: snapshot.id) {
            guard existing.calendarID == calendarID,
                  SharedEventMapper.isShareable(existing) else {
                throw CalendarSharingError.syncFailed
            }
            let merged = CalendarEvent(
                id: existing.id,
                unifiedEntryID: existing.unifiedEntryID,
                calendarID: existing.calendarID,
                title: snapshot.title,
                note: existing.note,
                startDate: snapshot.startDate,
                endDate: snapshot.endDate,
                isAllDay: snapshot.isAllDay,
                categoryID: existing.categoryID,
                recurrenceRule: existing.recurrenceRule,
                reminderTemplateID: existing.reminderTemplateID,
                reminderOffsetMinutes: existing.reminderOffsetMinutes,
                notificationID: existing.notificationID,
                importSource: existing.importSource,
                createdAt: existing.createdAt,
                updatedAt: now,
                shiftTemplateID: nil,
                workInfo: nil
            )
            try validate(merged)
            try await repository.update(merged)
            await refreshNotificationAfterRemoteMerge(merged, previous: existing)
            onRemoteEventsMaterialized?()
            return
        }

        let event = CalendarEvent(
            id: snapshot.id,
            calendarID: calendarID,
            title: snapshot.title,
            note: nil,
            startDate: snapshot.startDate,
            endDate: snapshot.endDate,
            isAllDay: snapshot.isAllDay,
            categoryID: nil,
            recurrenceRule: .none,
            reminderTemplateID: nil,
            reminderOffsetMinutes: nil,
            notificationID: nil,
            importSource: nil,
            createdAt: now,
            updatedAt: now,
            shiftTemplateID: nil,
            workInfo: nil
        )
        try validate(event)
        try await repository.create(event)
        onRemoteEventsMaterialized?()
    }

    /// Idempotently removes a remotely tombstoned SharedEvent from the owner's SwiftData rows.
    func removeSharedEventFromCloud(id: UUID, calendarID: UUID) async throws {
        guard let existing = try await repository.event(id: id) else { return }
        guard existing.calendarID == calendarID,
              SharedEventMapper.isShareable(existing) else {
            throw CalendarSharingError.syncFailed
        }
        try await repository.delete(id: id)
        if let notificationID = existing.notificationID {
            notificationScheduler?.cancelNotification(id: notificationID)
        }
        onRemoteEventsMaterialized?()
    }

    func ownerSharedEventMutations(
        calendarID: UUID
    ) async throws -> [OwnerSharedEventMutation] {
        guard let mutationRepository = repository as? any OwnerSharedEventMutationRepository else {
            throw CalendarSharingError.localPersistenceFailed
        }
        return try await mutationRepository.ownerSharedEventMutations(calendarID: calendarID)
    }

    func saveOwnerSharedEventMutation(
        _ mutation: OwnerSharedEventMutation
    ) async throws {
        guard let mutationRepository = repository as? any OwnerSharedEventMutationRepository else {
            throw CalendarSharingError.localPersistenceFailed
        }
        try await mutationRepository.saveOwnerSharedEventMutation(mutation)
    }

    func sharedEventSnapshots(calendarID: UUID) async throws -> [SharedEventSnapshot] {
        try await events(
            in: DateInterval(start: .distantPast, end: .distantFuture),
            calendarID: calendarID
        ).compactMap(SharedEventMapper.snapshot(from:))
    }

    func unifiedEntryGroup(
        for request: UnifiedEntryLoadRequest
    ) async throws -> UnifiedEntryGroup {
        switch request {
        case .event(let eventID):
            guard let event = try await repository.event(id: eventID) else {
                throw UnifiedEntryGroupError.linkedEventNotFound
            }
            guard let unifiedEntryID = event.unifiedEntryID else {
                return try UnifiedEntryGroupAssembler.assemble(
                    unifiedEntryID: nil,
                    events: [event]
                )
            }
            let group = try await unifiedEntryGroup(id: unifiedEntryID)
            guard group.event?.id == event.id else {
                throw UnifiedEntryGroupError.linkedEventNotFound
            }
            return group

        case .workRecord(
            let clockInEventID,
            let clockOutEventID,
            let workSessionID
        ):
            let workEvents = try await workRecordEvents(
                clockInEventID: clockInEventID,
                clockOutEventID: clockOutEventID,
                workSessionID: workSessionID
            )
            guard !workEvents.isEmpty else {
                throw UnifiedEntryGroupError.linkedWorkRecordNotFound
            }
            let workOnlyGroup = try UnifiedEntryGroupAssembler.assemble(
                unifiedEntryID: nil,
                events: workEvents
            )
            guard let workRecord = workOnlyGroup.workRecord else {
                throw UnifiedEntryGroupError.linkedWorkRecordNotFound
            }
            guard let unifiedEntryID = workOnlyGroup.unifiedEntryID else {
                return workOnlyGroup
            }

            let group = try await unifiedEntryGroup(id: unifiedEntryID)
            guard let linkedWorkRecord = group.workRecord,
                  Set(linkedWorkRecord.events.map(\.id))
                    == Set(workRecord.events.map(\.id)) else {
                throw UnifiedEntryGroupError.linkedWorkRecordNotFound
            }
            return group
        }
    }

    func resolveUnifiedEntrySave(
        _ request: UnifiedEntrySaveRequest
    ) async throws -> UnifiedEntrySaveResolution {
        guard request.hasEnabledEntry else {
            throw UnifiedEntrySaveError.noEnabledEntry
        }

        let requestedEvent: CalendarEvent?
        if let eventID = request.event?.eventID {
            guard let event = try await repository.event(id: eventID) else {
                throw UnifiedEntryGroupError.linkedEventNotFound
            }
            requestedEvent = event
        } else {
            requestedEvent = nil
        }

        let requestedWorkEvents: [CalendarEvent]
        if let workRecord = request.workRecord,
           workRecord.clockInEventID != nil || workRecord.clockOutEventID != nil {
            requestedWorkEvents = try await workRecordEvents(
                clockInEventID: workRecord.clockInEventID,
                clockOutEventID: workRecord.clockOutEventID,
                workSessionID: workRecord.sessionID
            )
        } else {
            requestedWorkEvents = []
        }
        let requestedWorkRecord = try UnifiedEntryGroupAssembler.assembleWorkRecord(
            from: requestedWorkEvents
        )

        let candidateIDs = Set(
            [request.unifiedEntryID, requestedEvent?.unifiedEntryID]
                .compactMap { $0 }
                + requestedWorkEvents.compactMap(\.unifiedEntryID)
        )
        guard candidateIDs.count <= 1 else {
            throw UnifiedEntryGroupError.mismatchedUnifiedEntryID
        }

        let unifiedEntryID: UUID
        let currentGroup: UnifiedEntryGroup
        if let persistedID = candidateIDs.first {
            unifiedEntryID = persistedID
            currentGroup = try await unifiedEntryGroup(id: persistedID)
            guard !currentGroup.allEvents.isEmpty else {
                throw UnifiedEntryGroupError.staleEditorState
            }
        } else {
            unifiedEntryID = UUID()
            currentGroup = try UnifiedEntryGroupAssembler.assemble(
                unifiedEntryID: nil,
                events: [requestedEvent].compactMap { $0 } + requestedWorkEvents
            )
        }

        if let requestedEvent,
           let groupedEvent = currentGroup.event,
           groupedEvent.id != requestedEvent.id {
            throw UnifiedEntryGroupError.staleEditorState
        }
        if let requestedWorkRecord,
           let groupedWorkRecord = currentGroup.workRecord,
           Set(groupedWorkRecord.events.map(\.id))
                != Set(requestedWorkRecord.events.map(\.id)) {
            throw UnifiedEntryGroupError.staleEditorState
        }
        if currentGroup.event != nil, request.event == nil {
            throw UnifiedEntryGroupError.staleEditorState
        }
        if currentGroup.workRecord != nil, request.workRecord == nil {
            throw UnifiedEntryGroupError.staleEditorState
        }

        let existingEvent = currentGroup.event ?? requestedEvent
        let existingWorkRecord = currentGroup.workRecord ?? requestedWorkRecord
        let requestedCalendarIDs = Set(
            [request.event?.calendarID, request.workRecord?.calendarID]
                .compactMap { $0 }
        )
        let persistedCalendarIDs = Set(
            [existingEvent?.calendarID]
                .compactMap { $0 }
                + (existingWorkRecord?.events.map(\.calendarID) ?? [])
        )
        guard requestedCalendarIDs.count <= 1,
              persistedCalendarIDs.count <= 1,
              requestedCalendarIDs.isEmpty
                || persistedCalendarIDs.isEmpty
                || requestedCalendarIDs == persistedCalendarIDs else {
            throw UnifiedEntryGroupError.calendarMismatch
        }

        return UnifiedEntrySaveResolution(
            unifiedEntryID: unifiedEntryID,
            existingEvent: existingEvent,
            existingWorkRecord: existingWorkRecord
        )
    }

    private func unifiedEntryGroup(id: UUID) async throws -> UnifiedEntryGroup {
        let events = try await repository.events(unifiedEntryID: id)
        return try UnifiedEntryGroupAssembler.assemble(
            unifiedEntryID: id,
            events: events
        )
    }

    private func workRecordEvents(
        clockInEventID: UUID?,
        clockOutEventID: UUID?,
        workSessionID: UUID?
    ) async throws -> [CalendarEvent] {
        if let clockInEventID,
           clockInEventID == clockOutEventID {
            throw WorkRecordPairSaveError.duplicateExplicitEventID
        }

        var eventsByID: [UUID: CalendarEvent] = [:]
        if let workSessionID {
            for event in try await repository.workRecordEvents(
                workSessionID: workSessionID
            ) {
                eventsByID[event.id] = event
            }
        }
        for id in [clockInEventID, clockOutEventID].compactMap({ $0 }) {
            guard let event = try await repository.event(id: id) else {
                throw UnifiedEntryGroupError.linkedWorkRecordNotFound
            }
            eventsByID[event.id] = event
        }

        let events = Array(eventsByID.values)
        for event in events {
            guard event.workInfo != nil, event.workClockKind != nil else {
                throw UnifiedEntryGroupError.linkedWorkRecordNotFound
            }
        }
        if let clockInEventID,
           !events.contains(where: {
               $0.id == clockInEventID && $0.workClockKind == .clockIn
           }) {
            throw UnifiedEntryGroupError.linkedWorkRecordNotFound
        }
        if let clockOutEventID,
           !events.contains(where: {
               $0.id == clockOutEventID && $0.workClockKind == .clockOut
           }) {
            throw UnifiedEntryGroupError.linkedWorkRecordNotFound
        }
        return events
    }

    func saveWorkRecordPair(_ request: WorkRecordPairSaveRequest) async throws {
        try await validateWriteAccess(calendarID: request.calendarID)
        let batch = try await prepareWorkRecordPair(request)

        try await repository.applyBatch(
            upserting: batch.upserting,
            deleting: batch.deleting,
            ifUnchanged: batch.expectedEvents
        )
        batch.expectedEvents.compactMap(\.notificationID).forEach {
            notificationScheduler?.cancelNotification(id: $0)
        }
        onEventsChanged?()
    }

    @discardableResult
    func saveEventAndWorkRecordAtomically(
        event: CalendarEvent,
        existingEvent: CalendarEvent?,
        workRecord request: WorkRecordPairSaveRequest,
        deleting additionalEvents: [CalendarEvent] = []
    ) async throws -> EventNotificationScheduleResult {
        try validate(event)
        try await validateWriteAccess(calendarID: event.calendarID)
        try await validateWriteAccess(calendarID: request.calendarID)
        for eventToDelete in additionalEvents {
            try await validateWriteAccess(calendarID: eventToDelete.calendarID)
        }
        if let existingEvent, existingEvent.id != event.id {
            throw EventUseCaseError.eventNotFound
        }

        let workRecordBatch = try await prepareWorkRecordPair(request)
        var eventToSave = event
        let oldNotificationID = existingEvent?.notificationID
        let notificationResult: EventNotificationScheduleResult

        if existingEvent != nil, eventToSave.reminderOffsetMinutes == nil {
            notificationResult = .noReminder
            eventToSave.notificationID = nil
        } else {
            if existingEvent != nil {
                eventToSave.notificationID = oldNotificationID
            }
            notificationResult = await scheduleNotification(for: eventToSave)
            eventToSave.notificationID = notificationResult.notificationID
        }

        let expectedEvents = Dictionary(
            (
                workRecordBatch.expectedEvents
                    + [existingEvent].compactMap { $0 }
                    + additionalEvents
            ).map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        ).values.map { $0 }
        let deletingEvents = Dictionary(
            (workRecordBatch.deleting + additionalEvents).map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        ).values.map { $0 }

        do {
            let upsertingEvents = [eventToSave] + workRecordBatch.upserting
            let mutations = try await ownerMutationsForBatch(
                upserting: upsertingEvents,
                deleting: deletingEvents,
                expected: expectedEvents
            )
            try await persistLocalEventChange(
                upserting: upsertingEvents,
                deleting: deletingEvents,
                expected: expectedEvents,
                mutations: mutations,
                fallback: {
                    try await self.repository.applyBatch(
                        upserting: upsertingEvents,
                        deleting: deletingEvents,
                        ifUnchanged: expectedEvents
                    )
                }
            )
        } catch {
            if let newNotificationID = notificationResult.notificationID {
                if newNotificationID != oldNotificationID {
                    notificationScheduler?.cancelNotification(id: newNotificationID)
                }
                if let existingEvent, oldNotificationID != nil {
                    let compensationResult = await scheduleNotification(for: existingEvent)
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
        let retainedNotificationID = eventToSave.notificationID
        expectedEvents.compactMap(\.notificationID)
            .filter { $0 != retainedNotificationID && $0 != oldNotificationID }
            .forEach {
                notificationScheduler?.cancelNotification(id: $0)
            }
        onEventsChanged?()
        return notificationResult
    }

    private struct PreparedWorkRecordPairBatch {
        let upserting: [CalendarEvent]
        let deleting: [CalendarEvent]
        let expectedEvents: [CalendarEvent]
    }

    private func prepareWorkRecordPair(
        _ request: WorkRecordPairSaveRequest
    ) async throws -> PreparedWorkRecordPairBatch {
        if let clockInEventID = request.clockInEventID,
           clockInEventID == request.clockOutEventID {
            throw WorkRecordPairSaveError.duplicateExplicitEventID
        }

        var existingEvents = try await repository.workRecordEvents(
            workSessionID: request.sessionID
        ).filter {
            $0.calendarID == request.calendarID && $0.workClockKind != nil
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
        return PreparedWorkRecordPairBatch(
            upserting: [clockIn, clockOut],
            deleting: duplicates,
            expectedEvents: expectedEvents
        )
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

    private func ownerMutationsForBatch(
        upserting: [CalendarEvent],
        deleting: [CalendarEvent],
        expected: [CalendarEvent]
    ) async throws -> [OwnerSharedEventMutation] {
        let expectedByID = Dictionary(
            expected.map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        var mutations: [OwnerSharedEventMutation] = []
        for event in upserting {
            mutations.append(contentsOf: try await ownerMutations(
                oldEvent: expectedByID[event.id],
                newEvent: event
            ))
        }
        for event in deleting {
            mutations.append(contentsOf: try await ownerMutations(
                oldEvent: expectedByID[event.id] ?? event,
                newEvent: nil
            ))
        }
        return mutations
    }

    private func ownerMutations(
        oldEvent: CalendarEvent?,
        newEvent: CalendarEvent?
    ) async throws -> [OwnerSharedEventMutation] {
        var calendarsByID: [UUID: TimeNestCalendar?] = [:]
        func calendar(for id: UUID) async throws -> TimeNestCalendar? {
            if let cached = calendarsByID[id] { return cached }
            let value = try await calendarRepository?.calendar(id: id)
            calendarsByID[id] = value
            return value
        }

        func isCollaborativeOwner(_ calendar: TimeNestCalendar?) -> Bool {
            calendar?.kind == .sharedOwned
                && (calendar?.collaborationProtocolVersion ?? 0) >= 1
                && calendar?.stopPhase.isStopping == false
        }

        let oldSnapshot = oldEvent.flatMap(SharedEventMapper.snapshot(from:))
        let newSnapshot = newEvent.flatMap(SharedEventMapper.snapshot(from:))
        let oldCalendar: TimeNestCalendar?
        if let oldEvent {
            oldCalendar = try await calendar(for: oldEvent.calendarID)
        } else {
            oldCalendar = nil
        }
        let newCalendar: TimeNestCalendar?
        if let newEvent {
            newCalendar = try await calendar(for: newEvent.calendarID)
        } else {
            newCalendar = nil
        }
        var mutations: [OwnerSharedEventMutation] = []

        if let oldEvent, let oldSnapshot, isCollaborativeOwner(oldCalendar),
           newEvent == nil || newEvent?.calendarID != oldEvent.calendarID || newSnapshot == nil {
            mutations.append(makeOwnerMutation(
                calendarID: oldEvent.calendarID,
                snapshot: oldSnapshot,
                operation: .delete
            ))
        }

        if let newEvent, let newSnapshot, isCollaborativeOwner(newCalendar) {
            let isSameCollaborativeRecord = oldEvent?.calendarID == newEvent.calendarID
                && oldSnapshot != nil
                && isCollaborativeOwner(oldCalendar)
            mutations.append(makeOwnerMutation(
                calendarID: newEvent.calendarID,
                snapshot: newSnapshot,
                operation: isSameCollaborativeRecord ? .update : .create
            ))
        }
        return mutations
    }

    private func makeOwnerMutation(
        calendarID: UUID,
        snapshot: SharedEventSnapshot,
        operation: SharedEventMutationOperation
    ) -> OwnerSharedEventMutation {
        let now = Date()
        let payload = SharedEventSnapshot(
            id: snapshot.id,
            title: snapshot.title,
            startDate: snapshot.startDate,
            endDate: snapshot.endDate,
            isAllDay: snapshot.isAllDay,
            updatedAt: snapshot.updatedAt,
            isDeleted: operation == .delete,
            deletedAt: operation == .delete ? now : nil
        )
        return OwnerSharedEventMutation(
            id: UUID(),
            calendarID: calendarID,
            eventID: snapshot.id,
            operation: operation,
            payload: payload,
            createdAt: now,
            sequence: 0,
            status: .prepared,
            retryCount: 0,
            lastErrorCode: nil
        )
    }

    private func persistLocalEventChange(
        upserting: [CalendarEvent],
        deleting: [CalendarEvent],
        expected: [CalendarEvent],
        mutations: [OwnerSharedEventMutation],
        fallback: () async throws -> Void
    ) async throws {
        guard !mutations.isEmpty else {
            try await fallback()
            return
        }
        guard let mutationRepository = repository as? any OwnerSharedEventMutationRepository else {
            throw CalendarSharingError.localPersistenceFailed
        }
        do {
            try await mutationRepository.applyBatchWithOwnerSharedEventMutations(
                upserting: upserting,
                deleting: deleting,
                ifUnchanged: expected,
                mutations: mutations
            )
        } catch let error as CalendarSharingError {
            throw error
        } catch {
            throw CalendarSharingError.localPersistenceFailed
        }
    }

    private func refreshNotificationAfterRemoteMerge(
        _ event: CalendarEvent,
        previous: CalendarEvent
    ) async {
        guard event.reminderOffsetMinutes != nil else { return }
        let result = await scheduleNotification(for: event)
        guard case .scheduled(let notificationID) = result else {
            if let oldNotificationID = previous.notificationID {
                notificationScheduler?.cancelNotification(id: oldNotificationID)
            }
            EventUseCaseDiagnostics.remoteNotificationRefreshFailed(result: result)
            return
        }
        guard notificationID != event.notificationID else { return }
        var persisted = event
        persisted.notificationID = notificationID
        do {
            try await repository.update(persisted)
            if let oldNotificationID = previous.notificationID,
               oldNotificationID != notificationID {
                notificationScheduler?.cancelNotification(id: oldNotificationID)
            }
        } catch {
            notificationScheduler?.cancelNotification(id: notificationID)
            EventUseCaseDiagnostics.remoteNotificationStatePersistenceFailed(error)
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
            unifiedEntryID: event.unifiedEntryID,
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
            unifiedEntryID: request.unifiedEntryID,
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
