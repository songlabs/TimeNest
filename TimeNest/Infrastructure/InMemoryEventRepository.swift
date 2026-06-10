import Foundation

actor InMemoryEventRepository: EventRepository {
    static let shared = InMemoryEventRepository()
    
    private var events: [UUID: CalendarEvent] = [:]
    
    func create(_ event: CalendarEvent) async throws {
        events[event.id] = event
    }
    
    func update(_ event: CalendarEvent) async throws {
        events[event.id] = event
    }
    
    func delete(id: UUID) async throws {
        events.removeValue(forKey: id)
    }
    
    func events(in range: DateInterval) async throws -> [CalendarEvent] {
        events.values.filter {
            $0.startDate < range.end && $0.endDate > range.start
        }.sorted { $0.startDate < $1.startDate }
    }
    
    func event(id: UUID) async throws -> CalendarEvent? {
        events[id]
    }
}
