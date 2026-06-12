import Foundation

/// 班次时间模板 ID
/// 用于标识事件关联的班次类型（白班/夜班）
enum ShiftTimeTemplateID: String, Codable, Hashable, CaseIterable, Identifiable {
    case day
    case night

    var id: String { rawValue }
}
