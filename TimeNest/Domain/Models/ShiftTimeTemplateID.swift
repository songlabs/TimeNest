import Foundation

/// 班次时间模板 ID
/// 用于标识事件关联的班次类型（白班/夜班）
enum ShiftTimeTemplateID: Codable, Hashable, Identifiable {
    case day
    case night
    case custom(UUID)

    var id: String {
        switch self {
        case .day:
            return "day"
        case .night:
            return "night"
        case .custom(let uuid):
            return uuid.uuidString
        }
    }

    static func == (lhs: ShiftTimeTemplateID, rhs: ShiftTimeTemplateID) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
