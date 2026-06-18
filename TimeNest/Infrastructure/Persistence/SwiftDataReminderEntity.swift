import Foundation
import SwiftData

@Model
final class SwiftDataReminderEntity {
    @Attribute(.unique) var id: UUID
    var eventID: UUID
    var occurrenceID: String
    var occurrenceStartDate: Date
    var title: String
    var message: String?
    var scheduledDate: Date
    var statusRawValue: String
    var systemNotificationID: String?
    var alarmKitID: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        eventID: UUID,
        occurrenceID: String,
        occurrenceStartDate: Date,
        title: String,
        scheduledDate: Date,
        statusRawValue: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.eventID = eventID
        self.occurrenceID = occurrenceID
        self.occurrenceStartDate = occurrenceStartDate
        self.title = title
        self.scheduledDate = scheduledDate
        self.statusRawValue = statusRawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
