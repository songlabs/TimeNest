import Foundation
import SwiftData

@ModelActor
actor SwiftDataEventRepository: EventRepository {
    func create(_ event: CalendarEvent) async throws {
        try save(event, operation: "create event")
    }

    func createBatch(_ events: [CalendarEvent], ifUnchanged expectedEvents: [CalendarEvent]) async throws {
        do {
            let ids = events.map(\.id)
            guard Set(ids).count == ids.count else {
                throw EventRepositoryBatchError.duplicateEvent
            }
            for event in events {
                guard try entity(id: event.id) == nil else {
                    throw EventRepositoryBatchError.duplicateEvent
                }
            }

            for expectedEvent in expectedEvents {
                guard let currentEntity = try entity(id: expectedEvent.id) else {
                    throw EventRepositoryBatchError.eventNotFound
                }
                guard SwiftDataEventMapper.makeDomainModel(from: currentEntity) == expectedEvent else {
                    throw EventRepositoryBatchError.staleData
                }
            }

            let existingEvents = try modelContext.fetch(FetchDescriptor<SwiftDataCalendarEventEntity>())
                .map(SwiftDataEventMapper.makeDomainModel)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            guard events.allSatisfy({ newEvent in
                guard newEvent.shiftTemplateID != nil else { return true }
                return !existingEvents.contains {
                    $0.calendarID == newEvent.calendarID
                        && $0.shiftTemplateID != nil
                        && calendar.isDate($0.startDate, inSameDayAs: newEvent.startDate)
                }
            }) else {
                throw EventRepositoryBatchError.shiftConflict
            }

            events.forEach {
                modelContext.insert(SwiftDataEventMapper.makeEntity(from: $0))
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            SwiftDataRepositoryLogger.log("create event batch", error: error)
            throw error
        }
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

    func deleteBatch(_ expectedEvents: [CalendarEvent]) async throws {
        do {
            var entities: [SwiftDataCalendarEventEntity] = []
            for expectedEvent in expectedEvents {
                guard let eventEntity = try entity(id: expectedEvent.id) else {
                    throw EventRepositoryBatchError.eventNotFound
                }
                guard SwiftDataEventMapper.makeDomainModel(from: eventEntity) == expectedEvent else {
                    throw EventRepositoryBatchError.staleData
                }
                entities.append(eventEntity)
            }
            entities.forEach(modelContext.delete)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            SwiftDataRepositoryLogger.log("delete event batch", error: error)
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
                    let isWorkClockEvent = event.workClockKind != nil
                    let workDate = isWorkClockEvent ? event.workInfo?.workDate : nil
                    return (event.startDate < range.end && event.endDate > range.start)
                        || (event.startDate >= range.start && event.startDate < range.end)
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

    func reassignEvents(from sourceCalendarID: UUID, to targetCalendarID: UUID) async throws {
        do {
            let descriptor = FetchDescriptor<SwiftDataCalendarEventEntity>(
                predicate: #Predicate { $0.calendarID == sourceCalendarID }
            )
            let entities = try modelContext.fetch(descriptor)
            let now = Date()
            entities.forEach {
                $0.calendarID = targetCalendarID
                $0.updatedAt = now
            }
            if !entities.isEmpty {
                try modelContext.save()
            }
        } catch {
            modelContext.rollback()
            SwiftDataRepositoryLogger.log("reassign calendar events", error: error)
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
