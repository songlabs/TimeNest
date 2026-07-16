import Foundation
import SwiftData

@ModelActor
actor SwiftDataCalendarRepository: CalendarRepository {
    func calendars() throws -> [TimeNestCalendar] {
        let descriptor = FetchDescriptor<SwiftDataCalendarEntity>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try modelContext.fetch(descriptor).compactMap(Self.makeDomainModel)
    }

    func calendar(id: UUID) throws -> TimeNestCalendar? {
        let descriptor = FetchDescriptor<SwiftDataCalendarEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first.flatMap(Self.makeDomainModel)
    }

    func save(_ calendar: TimeNestCalendar) throws {
        if let entity = try entity(id: calendar.id) {
            Self.update(entity, from: calendar)
        } else {
            modelContext.insert(Self.makeEntity(from: calendar))
        }
        try modelContext.save()
    }

    func delete(id: UUID) throws {
        guard id != TimeNestCalendar.personalID,
              let entity = try entity(id: id) else { return }
        modelContext.delete(entity)
        try modelContext.save()
    }

    private func entity(id: UUID) throws -> SwiftDataCalendarEntity? {
        let descriptor = FetchDescriptor<SwiftDataCalendarEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    private static func makeEntity(from calendar: TimeNestCalendar) -> SwiftDataCalendarEntity {
        SwiftDataCalendarEntity(
            id: calendar.id,
            name: calendar.name,
            kindRawValue: calendar.kind.rawValue,
            zoneName: calendar.zoneName,
            ownerName: calendar.ownerName,
            rootRecordName: calendar.rootRecordName,
            shareRecordName: calendar.shareRecordName,
            stopPhaseRawValue: calendar.stopPhase.rawValue,
            createdAt: calendar.createdAt,
            updatedAt: calendar.updatedAt
        )
    }

    private static func update(_ entity: SwiftDataCalendarEntity, from calendar: TimeNestCalendar) {
        entity.name = calendar.name
        entity.kindRawValue = calendar.kind.rawValue
        entity.zoneName = calendar.zoneName
        entity.ownerName = calendar.ownerName
        entity.rootRecordName = calendar.rootRecordName
        entity.shareRecordName = calendar.shareRecordName
        entity.stopPhaseRawValue = calendar.stopPhase.rawValue
        entity.updatedAt = calendar.updatedAt
    }

    private static func makeDomainModel(from entity: SwiftDataCalendarEntity) -> TimeNestCalendar? {
        guard let kind = TimeNestCalendarKind(rawValue: entity.kindRawValue) else { return nil }
        return TimeNestCalendar(
            id: entity.id,
            name: entity.name,
            kind: kind,
            zoneName: entity.zoneName,
            ownerName: entity.ownerName,
            rootRecordName: entity.rootRecordName,
            shareRecordName: entity.shareRecordName,
            stopPhase: TimeNestCalendarStopPhase(rawValue: entity.stopPhaseRawValue) ?? .active,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }
}
