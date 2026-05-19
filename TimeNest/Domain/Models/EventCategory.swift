import Foundation

struct EventCategory: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let colorHex: String
    var sortOrder: Int
}
