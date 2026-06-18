import Foundation
import SwiftData

@ModelActor
actor SwiftDataEventRepository: EventRepository {
    func create(_ event: CalendarEvent) async throws {
        try save(event, operation: "create event")
    }

    func update(_ event: CalendarEvent) async throws {
        try save(event, operation: "update event")
    }

    func delete(id: UUID) async throws {
        do {
            if let entity = try entity(id: id) {
                modelContext.delete(entity)
                try modelContext.save()
            }
        } catch {
            modelContext.rollback()
            SwiftDataRepositoryLogger.log("delete event", error: error)
            throw error
        }
    }

    func events(in range: DateInterval) async throws -> [CalendarEvent] {
        do {
            let descriptor = FetchDescriptor<SwiftDataCalendarEventEntity>(
                sortBy: [SortDescriptor(\.startDate)]
            )
            return try modelContext.fetch(descriptor)
                .map(SwiftDataEventMapper.makeDomainModel)
                .filter { event in
                    let isWorkClockEvent = WorkClockTitleMatcher.isClockInTitle(event.title)
                        || WorkClockTitleMatcher.isClockOutTitle(event.title)
                    let workDate = isWorkClockEvent ? event.workInfo?.workDate : nil
                    return (event.startDate < range.end && event.endDate > range.start)
                        || (workDate.map { $0 >= range.start && $0 < range.end } ?? false)
                }
        } catch {
            SwiftDataRepositoryLogger.log("fetch events", error: error)
            throw error
        }
    }

    func event(id: UUID) async throws -> CalendarEvent? {
        do {
            return try entity(id: id).map(SwiftDataEventMapper.makeDomainModel)
        } catch {
            SwiftDataRepositoryLogger.log("fetch event", error: error)
            throw error
        }
    }

    private func save(_ event: CalendarEvent, operation: String) throws {
        do {
            if let existingEntity = try entity(id: event.id) {
                SwiftDataEventMapper.update(existingEntity, from: event)
            } else {
                modelContext.insert(SwiftDataEventMapper.makeEntity(from: event))
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            SwiftDataRepositoryLogger.log(operation, error: error)
            throw error
        }
    }

    private func entity(id: UUID) throws -> SwiftDataCalendarEventEntity? {
        let descriptor = FetchDescriptor<SwiftDataCalendarEventEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
}
