import Foundation

actor InMemoryEventRepository: EventRepository {
    static let shared = InMemoryEventRepository()
    
    private var events: [UUID: CalendarEvent] = [:]
    
    func create(_ event: CalendarEvent) async throws {
        events[event.id] = event
    }

    func createBatch(_ newEvents: [CalendarEvent], ifUnchanged expectedEvents: [CalendarEvent]) async throws {
        let ids = newEvents.map(\.id)
        guard Set(ids).count == ids.count,
              ids.allSatisfy({ events[$0] == nil }) else {
            throw EventRepositoryBatchError.duplicateEvent
        }
        guard expectedEvents.allSatisfy({ events[$0.id] == $0 }) else {
            throw EventRepositoryBatchError.staleData
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard newEvents.allSatisfy({ newEvent in
            guard newEvent.shiftTemplateID != nil else { return true }
            return !events.values.contains {
                $0.calendarID == newEvent.calendarID
                    && $0.shiftTemplateID != nil
                    && calendar.isDate($0.startDate, inSameDayAs: newEvent.startDate)
            }
        }) else {
            throw EventRepositoryBatchError.shiftConflict
        }
        newEvents.forEach { events[$0.id] = $0 }
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

    func reassignEvents(from sourceCalendarID: UUID, to targetCalendarID: UUID) async throws {
        let now = Date()
        for (id, var event) in events where event.calendarID == sourceCalendarID {
            event.calendarID = targetCalendarID
            event.updatedAt = now
            events[id] = event
        }
    }
}
