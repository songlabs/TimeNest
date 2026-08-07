import Foundation
import SwiftData

@ModelActor
actor SwiftDataEventRepository: EventRepository, OwnerSharedEventMutationRepository {
    func create(_ event: CalendarEvent) async throws {
        try save(event, operation: "create event")
    }

    func applyBatch(
        upserting events: [CalendarEvent],
        deleting eventsToDelete: [CalendarEvent],
        ifUnchanged expectedEvents: [CalendarEvent]
    ) async throws {
        let transactionContext = ModelContext(modelContext.container)
        transactionContext.autosaveEnabled = false
        do {
            let currentEntities = try transactionContext.fetch(
                FetchDescriptor<SwiftDataCalendarEventEntity>()
            )
            let currentEvents = currentEntities.map(SwiftDataEventMapper.makeDomainModel)
            try EventRepositoryBatchValidator.validateApplyBatch(
                currentEvents: currentEvents,
                upserting: events,
                deleting: eventsToDelete,
                ifUnchanged: expectedEvents
            )
            let currentEntitiesByID = Dictionary(
                uniqueKeysWithValues: currentEntities.map { ($0.id, $0) }
            )

            for event in events {
                if let currentEntity = currentEntitiesByID[event.id] {
                    SwiftDataEventMapper.update(currentEntity, from: event)
                } else {
                    transactionContext.insert(SwiftDataEventMapper.makeEntity(from: event))
                }
            }

            for event in eventsToDelete {
                guard let currentEntity = currentEntitiesByID[event.id] else {
                    throw EventRepositoryBatchError.eventNotFound
                }
                transactionContext.delete(currentEntity)
            }
            try transactionContext.save()
        } catch {
            transactionContext.rollback()
            SwiftDataRepositoryLogger.log("apply event batch", error: error)
            throw error
        }
    }

    func applyBatchWithOwnerSharedEventMutations(
        upserting events: [CalendarEvent],
        deleting eventsToDelete: [CalendarEvent],
        ifUnchanged expectedEvents: [CalendarEvent],
        mutations: [OwnerSharedEventMutation]
    ) async throws {
        let transactionContext = ModelContext(modelContext.container)
        transactionContext.autosaveEnabled = false
        do {
            let currentEntities = try transactionContext.fetch(
                FetchDescriptor<SwiftDataCalendarEventEntity>()
            )
            let currentEvents = currentEntities.map(SwiftDataEventMapper.makeDomainModel)
            try EventRepositoryBatchValidator.validateApplyBatch(
                currentEvents: currentEvents,
                upserting: events,
                deleting: eventsToDelete,
                ifUnchanged: expectedEvents
            )
            let currentEntitiesByID = Dictionary(
                uniqueKeysWithValues: currentEntities.map { ($0.id, $0) }
            )

            for event in events {
                if let currentEntity = currentEntitiesByID[event.id] {
                    SwiftDataEventMapper.update(currentEntity, from: event)
                } else {
                    transactionContext.insert(SwiftDataEventMapper.makeEntity(from: event))
                }
            }
            for event in eventsToDelete {
                guard let currentEntity = currentEntitiesByID[event.id] else {
                    throw EventRepositoryBatchError.eventNotFound
                }
                transactionContext.delete(currentEntity)
            }

            let existingMutations = try transactionContext.fetch(
                FetchDescriptor<SwiftDataOwnerSharedEventMutationEntity>()
            )
            var nextSequence = (existingMutations.map(\.sequence).max() ?? 0) + 1
            for mutation in mutations {
                for previous in existingMutations
                where previous.calendarID == mutation.calendarID
                    && previous.eventID == mutation.eventID
                    && previous.statusRawValue == SharedEventMutationStatus.prepared.rawValue {
                    previous.statusRawValue = SharedEventMutationStatus.superseded.rawValue
                }
                var sequenced = mutation
                sequenced.sequence = nextSequence
                nextSequence += 1
                transactionContext.insert(Self.makeMutationEntity(from: sequenced))
            }
            try transactionContext.save()
        } catch {
            transactionContext.rollback()
            SwiftDataRepositoryLogger.log("apply event and owner mutation batch", error: error)
            throw error
        }
    }

    func ownerSharedEventMutations(
        calendarID: UUID
    ) async throws -> [OwnerSharedEventMutation] {
        do {
            let context = ModelContext(modelContext.container)
            let descriptor = FetchDescriptor<SwiftDataOwnerSharedEventMutationEntity>(
                predicate: #Predicate { $0.calendarID == calendarID },
                sortBy: [SortDescriptor(\.sequence)]
            )
            return try context.fetch(descriptor).compactMap(Self.makeMutation)
        } catch {
            SwiftDataRepositoryLogger.log("fetch owner shared-event mutations", error: error)
            throw error
        }
    }

    func saveOwnerSharedEventMutation(
        _ mutation: OwnerSharedEventMutation
    ) async throws {
        do {
            let mutationID = mutation.id
            let descriptor = FetchDescriptor<SwiftDataOwnerSharedEventMutationEntity>(
                predicate: #Predicate { $0.id == mutationID }
            )
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw CalendarSharingError.localPersistenceFailed
            }
            Self.updateMutationEntity(entity, from: mutation)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            SwiftDataRepositoryLogger.log("save owner shared-event mutation", error: error)
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
            let context = ModelContext(modelContext.container)
            let descriptor = FetchDescriptor<SwiftDataCalendarEventEntity>(
                sortBy: [SortDescriptor(\.startDate)]
            )
            return try context.fetch(descriptor)
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
            let context = ModelContext(modelContext.container)
            let descriptor = FetchDescriptor<SwiftDataCalendarEventEntity>(
                predicate: #Predicate { $0.id == id }
            )
            return try context.fetch(descriptor).first
                .map(SwiftDataEventMapper.makeDomainModel)
        } catch {
            SwiftDataRepositoryLogger.log("fetch event", error: error)
            throw error
        }
    }

    func events(unifiedEntryID: UUID) async throws -> [CalendarEvent] {
        do {
            let context = ModelContext(modelContext.container)
            let descriptor = FetchDescriptor<SwiftDataCalendarEventEntity>(
                predicate: #Predicate { $0.unifiedEntryID == unifiedEntryID },
                sortBy: [SortDescriptor(\.createdAt)]
            )
            return try context.fetch(descriptor)
                .map(SwiftDataEventMapper.makeDomainModel)
        } catch {
            SwiftDataRepositoryLogger.log("fetch unified entry", error: error)
            throw error
        }
    }

    func workRecordEvents(workSessionID: UUID) async throws -> [CalendarEvent] {
        do {
            let context = ModelContext(modelContext.container)
            let descriptor = FetchDescriptor<SwiftDataCalendarEventEntity>(
                predicate: #Predicate { $0.workSessionID == workSessionID },
                sortBy: [SortDescriptor(\.createdAt)]
            )
            return try context.fetch(descriptor)
                .map(SwiftDataEventMapper.makeDomainModel)
        } catch {
            SwiftDataRepositoryLogger.log("fetch work session", error: error)
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

    private static func makeMutationEntity(
        from mutation: OwnerSharedEventMutation
    ) -> SwiftDataOwnerSharedEventMutationEntity {
        SwiftDataOwnerSharedEventMutationEntity(
            id: mutation.id,
            calendarID: mutation.calendarID,
            eventID: mutation.eventID,
            operationRawValue: mutation.operation.rawValue,
            title: mutation.payload.title,
            startDate: mutation.payload.startDate,
            endDate: mutation.payload.endDate,
            isAllDay: mutation.payload.isAllDay,
            updatedAt: mutation.payload.updatedAt,
            isDeleted: mutation.payload.isDeleted,
            deletedAt: mutation.payload.deletedAt,
            createdAt: mutation.createdAt,
            sequence: mutation.sequence,
            statusRawValue: mutation.status.rawValue,
            retryCount: mutation.retryCount,
            lastErrorCode: mutation.lastErrorCode
        )
    }

    private static func updateMutationEntity(
        _ entity: SwiftDataOwnerSharedEventMutationEntity,
        from mutation: OwnerSharedEventMutation
    ) {
        entity.operationRawValue = mutation.operation.rawValue
        entity.title = mutation.payload.title
        entity.startDate = mutation.payload.startDate
        entity.endDate = mutation.payload.endDate
        entity.isAllDay = mutation.payload.isAllDay
        entity.updatedAt = mutation.payload.updatedAt
        entity.isDeleted = mutation.payload.isDeleted
        entity.deletedAt = mutation.payload.deletedAt
        entity.statusRawValue = mutation.status.rawValue
        entity.retryCount = mutation.retryCount
        entity.lastErrorCode = mutation.lastErrorCode
    }

    private static func makeMutation(
        from entity: SwiftDataOwnerSharedEventMutationEntity
    ) -> OwnerSharedEventMutation? {
        guard let operation = SharedEventMutationOperation(rawValue: entity.operationRawValue),
              let status = SharedEventMutationStatus(rawValue: entity.statusRawValue) else {
            return nil
        }
        return OwnerSharedEventMutation(
            id: entity.id,
            calendarID: entity.calendarID,
            eventID: entity.eventID,
            operation: operation,
            payload: SharedEventSnapshot(
                id: entity.eventID,
                title: entity.title,
                startDate: entity.startDate,
                endDate: entity.endDate,
                isAllDay: entity.isAllDay,
                updatedAt: entity.updatedAt,
                isDeleted: entity.isDeleted,
                deletedAt: entity.deletedAt
            ),
            createdAt: entity.createdAt,
            sequence: entity.sequence,
            status: status,
            retryCount: entity.retryCount,
            lastErrorCode: entity.lastErrorCode
        )
    }
}
