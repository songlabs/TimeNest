import Foundation

actor InMemoryEventRepository: EventRepository, OwnerSharedEventMutationRepository {
    static let shared = InMemoryEventRepository()
    
    private var events: [UUID: CalendarEvent] = [:]
    private var ownerMutations: [UUID: OwnerSharedEventMutation] = [:]
    private var nextOwnerMutationSequence: Int64 = 1
    
    func create(_ event: CalendarEvent) async throws {
        events[event.id] = event
    }

    func applyBatch(
        upserting newEvents: [CalendarEvent],
        deleting eventsToDelete: [CalendarEvent],
        ifUnchanged expectedEvents: [CalendarEvent]
    ) async throws {
        try EventRepositoryBatchValidator.validateApplyBatch(
            currentEvents: Array(events.values),
            upserting: newEvents,
            deleting: eventsToDelete,
            ifUnchanged: expectedEvents
        )

        var updated = events
        for event in newEvents {
            updated[event.id] = event
        }
        for event in eventsToDelete {
            updated.removeValue(forKey: event.id)
        }
        events = updated
    }

    func applyBatchWithOwnerSharedEventMutations(
        upserting newEvents: [CalendarEvent],
        deleting eventsToDelete: [CalendarEvent],
        ifUnchanged expectedEvents: [CalendarEvent],
        mutations: [OwnerSharedEventMutation]
    ) async throws {
        try EventRepositoryBatchValidator.validateApplyBatch(
            currentEvents: Array(events.values),
            upserting: newEvents,
            deleting: eventsToDelete,
            ifUnchanged: expectedEvents
        )
        var updatedEvents = events
        var updatedMutations = ownerMutations
        for event in newEvents { updatedEvents[event.id] = event }
        for event in eventsToDelete { updatedEvents.removeValue(forKey: event.id) }
        for mutation in mutations {
            for (id, var previous) in updatedMutations
            where previous.calendarID == mutation.calendarID
                && previous.eventID == mutation.eventID
                && previous.status == .prepared {
                previous.status = .superseded
                updatedMutations[id] = previous
            }
            var sequenced = mutation
            sequenced.sequence = nextOwnerMutationSequence
            nextOwnerMutationSequence += 1
            updatedMutations[sequenced.id] = sequenced
        }
        events = updatedEvents
        ownerMutations = updatedMutations
    }

    func ownerSharedEventMutations(
        calendarID: UUID
    ) async throws -> [OwnerSharedEventMutation] {
        ownerMutations.values
            .filter { $0.calendarID == calendarID }
            .sorted { $0.sequence < $1.sequence }
    }

    func saveOwnerSharedEventMutation(
        _ mutation: OwnerSharedEventMutation
    ) async throws {
        guard ownerMutations[mutation.id] != nil else {
            throw CalendarSharingError.localPersistenceFailed
        }
        ownerMutations[mutation.id] = mutation
    }
    
    func update(_ event: CalendarEvent) async throws {
        events[event.id] = event
    }
    
    func delete(id: UUID) async throws {
        events.removeValue(forKey: id)
    }

    func deleteBatch(_ expectedEvents: [CalendarEvent]) async throws {
        guard expectedEvents.allSatisfy({ events[$0.id] != nil }) else {
            throw EventRepositoryBatchError.eventNotFound
        }
        guard expectedEvents.allSatisfy({ events[$0.id] == $0 }) else {
            throw EventRepositoryBatchError.staleData
        }
        expectedEvents.forEach { events.removeValue(forKey: $0.id) }
    }
    
    func events(in range: DateInterval) async throws -> [CalendarEvent] {
        events.values.filter {
            let isWorkClockEvent = $0.workClockKind != nil
            let workDate = isWorkClockEvent ? $0.workInfo?.workDate : nil
            return ($0.startDate < range.end && $0.endDate > range.start)
                || ($0.startDate >= range.start && $0.startDate < range.end)
                || (workDate.map { $0 >= range.start && $0 < range.end } ?? false)
        }.sorted { $0.startDate < $1.startDate }
    }
    
    func event(id: UUID) async throws -> CalendarEvent? {
        events[id]
    }

    func events(unifiedEntryID: UUID) async throws -> [CalendarEvent] {
        events.values
            .filter { $0.unifiedEntryID == unifiedEntryID }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    func workRecordEvents(workSessionID: UUID) async throws -> [CalendarEvent] {
        events.values
            .filter { $0.workInfo?.workSessionId == workSessionID }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    func reassignEvents(from sourceCalendarID: UUID, to targetCalendarID: UUID) async throws {
        let now = Date()
        for (id, var event) in events where event.calendarID == sourceCalendarID {
            event.calendarID = targetCalendarID
            event.updatedAt = now
            events[id] = event
        }
    }
}
