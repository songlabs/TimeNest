import SwiftUI

// MARK: - ナスカレ风格 排班日历主题颜色

struct ShiftCalendarColors {
    // 主色调 - 亮蓝色
    static let primaryBlue = Color(red: 0.15, green: 0.65, blue: 0.95) // #26A6F5
    static let primaryBlueDark = Color(red: 0.08, green: 0.4, blue: 0.75)

    // accent 色（选中项）
    static let accentYellow = Color(red: 1.0, green: 0.84, blue: 0.0) // #FFD700

    // 周末颜色
    static let sundayRed = Color(red: 0.95, green: 0.25, blue: 0.25)
    static let saturdayBlue = Color(red: 0.3, green: 0.55, blue: 0.9)

    // 非本月日期
    static let otherMonthGray = Color(red: 0.75, green: 0.75, blue: 0.75)

    // 分隔线 - 浅灰/浅米色
    static let separatorColor = Color(red: 0.88, green: 0.88, blue: 0.90)

    // 月历网格线 - 浅灰色，清晰但柔和
    static let gridLineColor = Color(red: 0.86, green: 0.86, blue: 0.88)

    // 背景色
    static let backgroundColor = Color.white
    static let cardBackgroundColor = Color.white

    // 文字颜色
    static let primaryText = Color.black
    static let secondaryText = Color(red: 0.45, green: 0.45, blue: 0.48)
    static let whiteText = Color.white

    // 选中日期边框
    static let selectedDayBorder = Color(red: 0.95, green: 0.25, blue: 0.25) // 红色边框

    // 排班标签颜色
    static let shiftDayWork = Color(red: 1.0, green: 0.78, blue: 0.1) // 黄色 - 日勤
    static let shiftStart = Color(red: 0.2, green: 0.65, blue: 0.95) // 水蓝色 - 入り
    static let shiftMorning = Color(red: 0.35, green: 0.75, blue: 0.92) // 浅蓝色 - 明け
    static let shiftDayOff = Color(red: 0.98, green: 0.35, blue: 0.38) // 珊瑚红 - 休み
    static let shiftAfternoon = Color(red: 0.6, green: 0.35, blue: 0.88) // 紫色 - 午後
    static let shiftHalfRest = Color(red: 1.0, green: 0.55, blue: 0.72) // 粉色 - 半休
}

// MARK: - 排班标签颜色扩展

// 预定义的班次标签颜色池，用于用户输入的班次内容
private let shiftLabelColors: [Color] = [
    ShiftCalendarColors.shiftDayWork,
    ShiftCalendarColors.shiftStart,
    ShiftCalendarColors.shiftMorning,
    ShiftCalendarColors.shiftDayOff,
    ShiftCalendarColors.shiftAfternoon,
    ShiftCalendarColors.shiftHalfRest
]

extension String {
    // 基于字符串内容生成一致的颜色（使用哈希值）
    var shiftLabelColor: Color {
        let hash = self.hashValue & 0x7FFFFFFF
        let index = hash % shiftLabelColors.count
        return shiftLabelColors[index]
    }

    // 显示名称就是字符串本身
    var shiftDisplayName: String {
        self
    }
}

// MARK: - 事件标记颜色扩展

extension EventMarkerType {
    var icon: String {
        switch self {
        case .clover:
            return "leaf.fill"
        case .memo:
            return "note.text"
        case .car:
            return "car.fill"
        case .health:
            return "heart.fill"
        case .dot:
            return "circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .clover:
            return .green
        case .memo:
            return .blue
        case .car:
            return .orange
        case .health:
            return .red
        case .dot:
            return .gray
        }
    }
}

// MARK: - ナスカレ风格 布局常量

struct ShiftCalendarLayout {
    // Header 高度 - 增加至 64pt，提供更充足的上下留白
    static let headerHeight: CGFloat = 64

    // 星期行高度（网格内）- 32pt
    static let weekdayRowHeight: CGFloat = 32

    // 月历网格
    static let calendarGridTopMargin: CGFloat = 0
    static let calendarGridHorizontalPadding: CGFloat = 0
    static let dayCellMinHeight: CGFloat = 90
    static let dayCellRecommendedHeight: CGFloat = 100

    // 表格网格线
    static let gridLineWidth: CGFloat = 0.5
    static let gridLineColor: Color = ShiftCalendarColors.gridLineColor

    // 班次标签
    static let shiftLabelHeight: CGFloat = 28
    static let shiftLabelCornerRadius: CGFloat = 4
    static let shiftLabelHorizontalPadding: CGFloat = 8
    static let dayNumberFontSize: CGFloat = 20
    static let dayNumberFontSizeToday: CGFloat = 22

    // Footer 工具栏字体大小 - 接近 Header 区域按钮文字的视觉比例
    static let footerButtonFontSize: CGFloat = 26
    static let footerButtonFontWeight: Font.Weight = .medium

    // 选中日期信息条
    static let selectedDateInfoHeight: CGFloat = 40

    // 广告 banner
    static let adBannerHeight: CGFloat = 58

    // 底部 TabBar
    static let tabBarHeight: CGFloat = 64

    // 图标尺寸
    static let smallIconSize: CGFloat = 16
    static let tabBarIconSize: CGFloat = 22
    static let tabBarIconSelectedSize: CGFloat = 24
}
