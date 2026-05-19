import Foundation

struct ScheduledReminder: Identifiable, Codable, Hashable {
    let id: UUID
    let eventID: UUID
    let occurrenceID: String
    let occurrenceStartDate: Date
    let title: String
    let message: String?
    let scheduledDate: Date
    var status: ReminderStatus
    let systemNotificationID: String?
    let alarmKitID: String?
    let createdAt: Date
    var updatedAt: Date
}
