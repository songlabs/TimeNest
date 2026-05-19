import Foundation

enum ReminderStatus: String, Codable, Hashable {
    case pending
    case scheduled
    case delivered
    case cancelled
    case failed
}
