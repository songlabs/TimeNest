import Foundation

protocol EventRepository {
    func create(_ event: CalendarEvent) async throws
    func applyBatch(
        upserting events: [CalendarEvent],
        deleting eventsToDelete: [CalendarEvent],
        ifUnchanged expectedEvents: [CalendarEvent]
    ) async throws
    func update(_ event: CalendarEvent) async throws
    func delete(id: UUID) async throws
    func deleteBatch(_ expectedEvents: [CalendarEvent]) async throws
    func events(in range: DateInterval) async throws -> [CalendarEvent]
    func event(id: UUID) async throws -> CalendarEvent?
    func events(unifiedEntryID: UUID) async throws -> [CalendarEvent]
    func workRecordEvents(workSessionID: UUID) async throws -> [CalendarEvent]
    func reassignEvents(from sourceCalendarID: UUID, to targetCalendarID: UUID) async throws
}

enum EventRepositoryBatchError: Error, Equatable {
    case duplicateEvent
    case eventNotFound
    case staleData
}

enum EventRepositoryBatchValidator {
    static func validateApplyBatch(
        currentEvents: [CalendarEvent],
        upserting events: [CalendarEvent],
        deleting eventsToDelete: [CalendarEvent],
        ifUnchanged expectedEvents: [CalendarEvent]
    ) throws {
        let upsertIDs = events.map(\.id)
        let deleteIDs = eventsToDelete.map(\.id)
        guard Set(upsertIDs).count == upsertIDs.count,
              Set(deleteIDs).count == deleteIDs.count,
              Set(upsertIDs).isDisjoint(with: Set(deleteIDs)) else {
            throw EventRepositoryBatchError.duplicateEvent
        }

        var currentEventsByID: [UUID: CalendarEvent] = [:]
        for event in currentEvents {
            guard currentEventsByID.updateValue(event, forKey: event.id) == nil else {
                throw EventRepositoryBatchError.duplicateEvent
            }
        }

        var expectedIDs = Set<UUID>()
        for expectedEvent in expectedEvents {
            guard expectedIDs.insert(expectedEvent.id).inserted else {
                throw EventRepositoryBatchError.duplicateEvent
            }
            guard let currentEvent = currentEventsByID[expectedEvent.id] else {
                throw EventRepositoryBatchError.eventNotFound
            }
            guard currentEvent == expectedEvent else {
                throw EventRepositoryBatchError.staleData
            }
        }

        for event in events where currentEventsByID[event.id] != nil {
            guard expectedIDs.contains(event.id) else {
                throw EventRepositoryBatchError.duplicateEvent
            }
        }

        for event in eventsToDelete {
            guard expectedIDs.contains(event.id),
                  currentEventsByID[event.id] != nil else {
                throw EventRepositoryBatchError.eventNotFound
            }
        }

        var projectedEventsByID = currentEventsByID
        eventsToDelete.forEach { projectedEventsByID[$0.id] = nil }
        events.forEach { projectedEventsByID[$0.id] = $0 }
        let affectedUnifiedEntryIDs = Set(
            (events + eventsToDelete + expectedEvents)
                .compactMap(\.unifiedEntryID)
        )
        for unifiedEntryID in affectedUnifiedEntryIDs {
            let groupEvents = projectedEventsByID.values.filter {
                $0.unifiedEntryID == unifiedEntryID
            }
            _ = try UnifiedEntryGroupAssembler.assemble(
                unifiedEntryID: unifiedEntryID,
                events: groupEvents
            )
        }
    }
}
