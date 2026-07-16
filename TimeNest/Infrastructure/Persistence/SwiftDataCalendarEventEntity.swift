import Foundation
import SwiftData

@Model
final class SwiftDataCalendarEventEntity {
    @Attribute(.unique) var id: UUID
    /// Optional only at the persistence boundary so pre-v2 rows can migrate without data loss.
    var calendarID: UUID?
    var title: String
    var note: String?
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var categoryID: UUID?
    var recurrenceRuleRawValue: String
    var reminderTemplateID: UUID?
    var reminderOffsetMinutes: Int?
    var notificationID: String?
    var importSourceTypeRawValue: String?
    var importExternalEventIdentifier: String?
    var importExternalCalendarIdentifier: String?
    var importExternalCalendarTitle: String?
    var importedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var shiftTemplateKind: String?
    var shiftTemplateCustomID: UUID?
    var hasWorkInfo: Bool
    var workInTime: Date?
    var workOutTime: Date?
    var restHours: Double?
    var workDate: Date?
    var transportFee: Int?
    var hourlyRate: Int?
    var workSessionID: UUID?
    var isWorkOutTimeSet: Bool?

    init(
        id: UUID,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        recurrenceRuleRawValue: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.recurrenceRuleRawValue = recurrenceRuleRawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.hasWorkInfo = false
    }
}
