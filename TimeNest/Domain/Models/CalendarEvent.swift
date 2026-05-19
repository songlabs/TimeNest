import Foundation

struct CalendarEvent: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var note: String?
    let startDate: Date
    let endDate: Date?
    let isAllDay: Bool
    let categoryID: UUID?
    var recurrenceRule: RecurrenceRule
    let reminderTemplateID: UUID?
    let importSource: ImportSource?
    let createdAt: Date
    var updatedAt: Date
}
