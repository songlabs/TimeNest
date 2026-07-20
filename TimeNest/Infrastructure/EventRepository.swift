import Foundation

protocol EventRepository {
    func create(_ event: CalendarEvent) async throws
    func createBatch(_ events: [CalendarEvent], ifUnchanged expectedEvents: [CalendarEvent]) async throws
    func update(_ event: CalendarEvent) async throws
    func delete(id: UUID) async throws
    func deleteBatch(_ expectedEvents: [CalendarEvent]) async throws
    func events(in range: DateInterval) async throws -> [CalendarEvent]
    func event(id: UUID) async throws -> CalendarEvent?
    func reassignEvents(from sourceCalendarID: UUID, to targetCalendarID: UUID) async throws
}

enum EventRepositoryBatchError: Error {
    case duplicateEvent
    case eventNotFound
    case staleData
    case shiftConflict
}
