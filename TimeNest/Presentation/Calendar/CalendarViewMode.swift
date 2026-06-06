import SwiftUI

/// 日历视图模式
enum CalendarViewMode: String, CaseIterable, Identifiable {
    case month = "month"
    case week = "week"
    case day = "day"

    var id: String { rawValue }

    var localizedKey: LocalizedString {
        switch self {
        case .month:
            return .viewModeMonth
        case .week:
            return .viewModeWeek
        case .day:
            return .viewModeDay
        }
    }

    var displayName: String {
        switch self {
        case .month:
            return "月"
        case .week:
            return "周"
        case .day:
            return "日"
        }
    }
}
