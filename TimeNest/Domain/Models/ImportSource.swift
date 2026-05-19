import Foundation

struct ImportSource: Codable, Hashable {
    let sourceType: ImportSourceType
    let externalEventIdentifier: String?
    let externalCalendarIdentifier: String?
    let externalCalendarTitle: String?
    let importedAt: Date
}
