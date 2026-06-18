enum SwiftDataReminderMapper {
    static func makeEntity(from reminder: ScheduledReminder) -> SwiftDataReminderEntity {
        let entity = SwiftDataReminderEntity(
            id: reminder.id,
            eventID: reminder.eventID,
            occurrenceID: reminder.occurrenceID,
            occurrenceStartDate: reminder.occurrenceStartDate,
            title: reminder.title,
            scheduledDate: reminder.scheduledDate,
            statusRawValue: reminder.status.rawValue,
            createdAt: reminder.createdAt,
            updatedAt: reminder.updatedAt
        )
        update(entity, from: reminder)
        return entity
    }

    static func update(_ entity: SwiftDataReminderEntity, from reminder: ScheduledReminder) {
        entity.id = reminder.id
        entity.eventID = reminder.eventID
        entity.occurrenceID = reminder.occurrenceID
        entity.occurrenceStartDate = reminder.occurrenceStartDate
        entity.title = reminder.title
        entity.message = reminder.message
        entity.scheduledDate = reminder.scheduledDate
        entity.statusRawValue = reminder.status.rawValue
        entity.systemNotificationID = reminder.systemNotificationID
        entity.alarmKitID = reminder.alarmKitID
        entity.createdAt = reminder.createdAt
        entity.updatedAt = reminder.updatedAt
    }

    static func makeDomainModel(from entity: SwiftDataReminderEntity) -> ScheduledReminder {
        ScheduledReminder(
            id: entity.id,
            eventID: entity.eventID,
            occurrenceID: entity.occurrenceID,
            occurrenceStartDate: entity.occurrenceStartDate,
            title: entity.title,
            message: entity.message,
            scheduledDate: entity.scheduledDate,
            status: ReminderStatus(rawValue: entity.statusRawValue) ?? .failed,
            systemNotificationID: entity.systemNotificationID,
            alarmKitID: entity.alarmKitID,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }
}
