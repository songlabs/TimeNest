import Foundation

protocol EventRepository {
    func create(_ event: CalendarEvent) async throws
    func update(_ event: CalendarEvent) async throws
    func delete(id: UUID) async throws
    func events(in range: DateInterval) async throws -> [CalendarEvent]
    func event(id: UUID) async throws -> CalendarEvent?
}
