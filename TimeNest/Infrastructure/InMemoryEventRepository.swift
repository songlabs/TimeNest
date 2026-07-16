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
