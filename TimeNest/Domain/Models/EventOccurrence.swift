import Foundation

struct EventOccurrence: Identifiable, Hashable {
    let id: String
    let eventID: UUID
    let occurrenceDate: DateOnly
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let title: String
    let note: String?
    let categoryID: UUID?
    let reminderOffsetMinutes: Int?
    let notificationID: String?
    let shiftTemplateID: ShiftTimeTemplateID?
}
