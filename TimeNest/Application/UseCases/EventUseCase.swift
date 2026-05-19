import Foundation

class EventUseCase {
    private let repository: EventRepository
    
    init(repository: EventRepository) {
        self.repository = repository
    }
    
    func createEvent(_ event: CalendarEvent) async throws {
        try await repository.create(event)
    }
    
    func updateEvent(_ event: CalendarEvent) async throws {
        try await repository.update(event)
    }
    
    func deleteEvent(id: UUID) async throws {
        try await repository.delete(id: id)
    }
    
    func events(in range: DateInterval) async throws -> [CalendarEvent] {
        try await repository.events(in: range)
    }
    
    func occurrences(in range: DateInterval) async throws -> [EventOccurrence] {
        let events = try await repository.events(in: range)
        return events.map { event in
            EventOccurrence(
                id: "\(event.id)-\(event.startDate)",
                eventID: event.id,
                occurrenceDate: DateOnly(from: event.startDate) ?? DateOnly(year: 2026, month: 1, day: 1),
                startDate: event.startDate,
                endDate: event.endDate,
                title: event.title,
                categoryID: event.categoryID
            )
        }
    }
}
