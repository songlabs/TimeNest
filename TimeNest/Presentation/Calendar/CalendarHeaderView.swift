import SwiftUI

/// 日历 Header - 月/周/日共用同一套导航布局。
/// 结构统一为：左侧统计按钮 + 中间（左箭头 + 标题 + 右箭头）+ 右侧设置按钮。
struct CalendarHeaderView: View {
    let title: String
    let displayMode: CalendarViewMode
    let onStatisticsTapped: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onTitleTapped: () -> Void
    let onSettingsTapped: () -> Void

    var body: some View {
        unifiedHeaderView
            .padding(.horizontal, 16)
            .padding(.top, ShiftCalendarLayout.headerTopPadding)
            .frame(height: ShiftCalendarLayout.headerHeight, alignment: .top)
            .background(ShiftCalendarColors.backgroundColor)
    }

    /// 月/周/日共用 Header。
    /// 左侧统计按钮 + 中间导航区域 + 右侧设置按钮。
    private var unifiedHeaderView: some View {
        HStack(spacing: 0) {
            // 左侧：统计按钮
            statisticsButton
                .frame(width: 44)

            HStack(spacing: titleSpacing) {
                navigationButton(icon: "chevron.left", action: onPrevious)

                Button(action: onTitleTapped) {
                    Text(title)
                        .font(titleFont)
                        .foregroundColor(ShiftCalendarColors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(titleMinimumScaleFactor)
                        .allowsTightening(true)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())

                navigationButton(icon: "chevron.right", action: onNext)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            settingsButton
                .frame(width: 44)
        }
    }

    private var titleFont: Font {
        switch displayMode {
        case .month, .week:
            return .system(size: 28, weight: .semibold)
        case .day:
            return .system(size: 24, weight: .semibold)
        }
    }

    private var titleSpacing: CGFloat {
        switch displayMode {
        case .month, .week:
            return 18
        case .day:
            return 10
        }
    }

    private var titleMinimumScaleFactor: CGFloat {
        switch displayMode {
        case .month, .week:
            return 0.85
        case .day:
            return 0.70
        }
    }

    /// 右侧设置按钮：沿用月视图的蓝色齿轮风格。
    private var settingsButton: some View {
        Button(action: onSettingsTapped) {
            Image(systemName: "gearshape")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(ShiftCalendarColors.primaryBlue)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// 左右箭头按钮：沿用月视图的浅蓝色圆形背景。
    private func navigationButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(ShiftCalendarColors.primaryBlue)
                .frame(width: 36, height: 36)
                .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// 左侧统计按钮：沿用浅蓝色圆形背景风格。
    private var statisticsButton: some View {
        Button(action: onStatisticsTapped) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(ShiftCalendarColors.primaryBlue)
                .frame(width: 36, height: 36)
                .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Month View") {
    CalendarHeaderView(
        title: "2026 年 6 月",
        displayMode: .month,
        onStatisticsTapped: {},
        onPrevious: {},
        onNext: {},
        onTitleTapped: {},
        onSettingsTapped: {}
    )
    .environmentObject(LocalizationManager.preview(languageCode: "ja"))
    .background(ShiftCalendarColors.backgroundColor)
}

#Preview("Week View") {
    CalendarHeaderView(
        title: "2026 年 6 月",
        displayMode: .week,
        onStatisticsTapped: {},
        onPrevious: {},
        onNext: {},
        onTitleTapped: {},
        onSettingsTapped: {}
    )
    .environmentObject(LocalizationManager.preview(languageCode: "ja"))
    .background(ShiftCalendarColors.backgroundColor)
}

#Preview("Day View") {
    CalendarHeaderView(
        title: "2026 年 6 月 10 日（三）",
        displayMode: .day,
        onStatisticsTapped: {},
        onPrevious: {},
        onNext: {},
        onTitleTapped: {},
        onSettingsTapped: {}
    )
    .environmentObject(LocalizationManager.preview(languageCode: "ja"))
    .background(ShiftCalendarColors.backgroundColor)
}
#endif
