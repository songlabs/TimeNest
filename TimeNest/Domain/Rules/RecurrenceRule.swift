import Foundation

enum RecurrenceRule: String, Codable, Hashable {
    case none
    case daily
    case weekly
    case monthly
    case yearly
}
