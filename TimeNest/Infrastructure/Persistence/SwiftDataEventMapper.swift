import Foundation

enum SwiftDataEventMapper {
    static func makeEntity(from event: CalendarEvent) -> SwiftDataCalendarEventEntity {
        let entity = SwiftDataCalendarEventEntity(
            id: event.id,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            recurrenceRuleRawValue: event.recurrenceRule.rawValue,
            createdAt: event.createdAt,
            updatedAt: event.updatedAt
        )
        update(entity, from: event)
        return entity
    }

    static func update(_ entity: SwiftDataCalendarEventEntity, from event: CalendarEvent) {
        entity.id = event.id
        entity.title = event.title
        entity.note = event.note
        entity.startDate = event.startDate
        entity.endDate = event.endDate
        entity.isAllDay = event.isAllDay
        entity.categoryID = event.categoryID
        entity.recurrenceRuleRawValue = event.recurrenceRule.rawValue
        entity.reminderTemplateID = event.reminderTemplateID
        entity.reminderOffsetMinutes = event.reminderOffsetMinutes
        entity.notificationID = event.notificationID
        entity.importSourceTypeRawValue = event.importSource?.sourceType.rawValue
        entity.importExternalEventIdentifier = event.importSource?.externalEventIdentifier
        entity.importExternalCalendarIdentifier = event.importSource?.externalCalendarIdentifier
        entity.importExternalCalendarTitle = event.importSource?.externalCalendarTitle
        entity.importedAt = event.importSource?.importedAt
        entity.createdAt = event.createdAt
        entity.updatedAt = event.updatedAt

        switch event.shiftTemplateID {
        case .day:
            entity.shiftTemplateKind = "day"
            entity.shiftTemplateCustomID = nil
        case .night:
            entity.shiftTemplateKind = "night"
            entity.shiftTemplateCustomID = nil
        case .custom(let id):
            entity.shiftTemplateKind = "custom"
            entity.shiftTemplateCustomID = id
        case nil:
            entity.shiftTemplateKind = nil
            entity.shiftTemplateCustomID = nil
        }

        entity.hasWorkInfo = event.workInfo != nil
        entity.workInTime = event.workInfo?.workInTime
        entity.workOutTime = event.workInfo?.workOutTime
        entity.restHours = event.workInfo?.restHours
        entity.workDate = event.workInfo?.workDate
        entity.transportFee = event.workInfo?.transportFee
        entity.hourlyRate = event.workInfo?.hourlyRate
        entity.workSessionID = event.workInfo?.workSessionId
        entity.isWorkOutTimeSet = event.workInfo?.isWorkOutTimeSet
    }

    static func makeDomainModel(from entity: SwiftDataCalendarEventEntity) -> CalendarEvent {
        CalendarEvent(
            id: entity.id,
            title: entity.title,
            note: entity.note,
            startDate: entity.startDate,
            endDate: entity.endDate,
            isAllDay: entity.isAllDay,
            categoryID: entity.categoryID,
            recurrenceRule: RecurrenceRule(rawValue: entity.recurrenceRuleRawValue) ?? .none,
            reminderTemplateID: entity.reminderTemplateID,
            reminderOffsetMinutes: entity.reminderOffsetMinutes,
            notificationID: entity.notificationID,
            importSource: makeImportSource(from: entity),
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            shiftTemplateID: makeShiftTemplateID(from: entity),
            workInfo: makeWorkInfo(from: entity)
        )
    }

    private static func makeImportSource(from entity: SwiftDataCalendarEventEntity) -> ImportSource? {
        guard
            let rawValue = entity.importSourceTypeRawValue,
            let sourceType = ImportSourceType(rawValue: rawValue),
            let importedAt = entity.importedAt
        else {
            return nil
        }

        return ImportSource(
            sourceType: sourceType,
            externalEventIdentifier: entity.importExternalEventIdentifier,
            externalCalendarIdentifier: entity.importExternalCalendarIdentifier,
            externalCalendarTitle: entity.importExternalCalendarTitle,
            importedAt: importedAt
        )
    }

    private static func makeShiftTemplateID(from entity: SwiftDataCalendarEventEntity) -> ShiftTimeTemplateID? {
        switch entity.shiftTemplateKind {
        case "day":
            return .day
        case "night":
            return .night
        case "custom":
            return entity.shiftTemplateCustomID.map(ShiftTimeTemplateID.custom)
        default:
            return nil
        }
    }

    private static func makeWorkInfo(from entity: SwiftDataCalendarEventEntity) -> WorkInfo? {
        guard entity.hasWorkInfo else { return nil }

        return WorkInfo(
            workInTime: entity.workInTime,
            workOutTime: entity.workOutTime,
            restHours: entity.restHours ?? 1.0,
            workDate: entity.workDate,
            transportFee: entity.transportFee,
            hourlyRate: entity.hourlyRate,
            workSessionId: entity.workSessionID,
            isWorkOutTimeSet: entity.isWorkOutTimeSet ?? WorkInfo.legacyIsWorkOutTimeSet(for: entity.workOutTime)
        )
    }
}
