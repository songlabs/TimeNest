import Foundation

struct ReminderStep: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    let offsetMinutes: Int
    let message: String?
}
