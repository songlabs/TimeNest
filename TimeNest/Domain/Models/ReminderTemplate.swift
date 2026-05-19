import Foundation

struct ReminderTemplate: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let steps: [ReminderStep]
    let createdAt: Date
    var updatedAt: Date
}
