import SwiftUI

/// 日历 Header - 支持月/周/日视图的不同布局
/// 月视图：左箭头 + 年月 + 右箭头 | 右侧：设置
/// 周视图：左箭头 + segmented control + 右箭头 | 右侧：设置
/// 日视图：年月日（星期） | 右侧：设置
struct CalendarHeaderView: View {
    @EnvironmentObject private var localization: LocalizationManager

    let title: String
    let displayMode: CalendarViewMode
    let weekDisplayDays: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onTodayTapped: () -> Void
    let onTitleTapped: () -> Void
    let onSettingsTapped: () -> Void
    let onWeekDaysChanged: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            if displayMode == .month {
                // 月视图：三段式布局，确保标题视觉居中
                monthHeaderView
            } else {
                // 周视图/日视图：左侧导航 + 标题 + 右侧按钮
                HStack(spacing: 0) {
                    // 左侧导航区域
                    leftNavigationArea
                        .frame(width: 44)

                    // 中间内容区域
                    middleContentView
                        .frame(maxWidth: .infinity, alignment: .center)

                    // 右侧按钮区域
                    rightButtonsView
                        .frame(width: 76)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: ShiftCalendarLayout.headerHeight)
        .background(ShiftCalendarColors.backgroundColor)
    }

    /// 月视图 Header - 三段式布局确保标题视觉居中
    /// 左侧占位 + 中间（左箭头 + 标题 + 右箭头）+ 右侧设置按钮
    private var monthHeaderView: some View {
        HStack(spacing: 0) {
            // 左侧占位区域（与设置按钮区域等宽，保证中间区域对称）
            Color.clear
                .frame(width: 44)

            // 中间标题区域：左箭头 + 年月标题 + 右箭头
            HStack(spacing: 18) {
                navigationButton(icon: "chevron.left", action: onPrevious)

                Button(action: onTitleTapped) {
                    Text(title)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(ShiftCalendarColors.primaryText)
                }
                .contentShape(Rectangle())

                navigationButton(icon: "chevron.right", action: onNext)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // 右侧固定宽度区域：设置按钮
            rightButtonsView
                .frame(width: 44)
        }
    }

    /// 中间内容区域（周视图/日视图共用）
    @ViewBuilder
    private var middleContentView: some View {
        if displayMode == .week {
            // 周视图：左箭头 + segmented control + 右箭头
            HStack(spacing: 12) {
                navigationButton(icon: "chevron.left", action: onPrevious)

                weekSegmentedControl

                navigationButton(icon: "chevron.right", action: onNext)
            }
        } else {
            // 日视图：居中显示完整日期
            HStack(spacing: 12) {
                navigationButton(icon: "chevron.left", action: onPrevious)

                Text(title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(ShiftCalendarColors.primaryText)

                navigationButton(icon: "chevron.right", action: onNext)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    /// 左侧导航区域（上一月按钮）
    private var leftNavigationArea: some View {
        HStack(spacing: 12) {
            navigationButton(icon: "chevron.left", action: onPrevious)
        }
    }

    /// 右侧按钮区域（设置）
    private var rightButtonsView: some View {
        Button(action: onSettingsTapped) {
            Image(systemName: "gearshape")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(ShiftCalendarColors.primaryBlue)
        }
    }

    private var weekSegmentedControl: some View {
        HStack(spacing: 4) {
            ForEach([3, 5, 7], id: \.self) { days in
                Button(action: {
                    onWeekDaysChanged(days)
                }) {
                    Text(verbatim: "\(days) 日")
                        .font(.system(size: 13, weight: weekDisplayDays == days ? .semibold : .regular))
                        .foregroundColor(weekDisplayDays == days ? .white : ShiftCalendarColors.primaryBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(weekDisplayDays == days ? ShiftCalendarColors.primaryBlue : ShiftCalendarColors.primaryBlue.opacity(0.12))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func navigationButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ShiftCalendarColors.primaryBlue)
                .frame(width: 28, height: 28)
                .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
                .clipShape(Circle())
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Month View") {
    CalendarHeaderView(
        title: "2026 年 6 月",
        displayMode: .month,
        weekDisplayDays: 7,
        onPrevious: {},
        onNext: {},
        onTodayTapped: {},
        onTitleTapped: {},
        onSettingsTapped: {},
        onWeekDaysChanged: { _ in }
    )
    .environmentObject(LocalizationManager.preview(languageCode: "ja"))
    .background(ShiftCalendarColors.backgroundColor)
}

#Preview("Week View") {
    CalendarHeaderView(
        title: "2026 年 6 月",
        displayMode: .week,
        weekDisplayDays: 7,
        onPrevious: {},
        onNext: {},
        onTodayTapped: {},
        onTitleTapped: {},
        onSettingsTapped: {},
        onWeekDaysChanged: { _ in }
    )
    .environmentObject(LocalizationManager.preview(languageCode: "ja"))
    .background(ShiftCalendarColors.backgroundColor)
}

#Preview("Day View") {
    CalendarHeaderView(
        title: "2026 年 6 月 7 日（日）",
        displayMode: .day,
        weekDisplayDays: 7,
        onPrevious: {},
        onNext: {},
        onTodayTapped: {},
        onTitleTapped: {},
        onSettingsTapped: {},
        onWeekDaysChanged: { _ in }
    )
    .environmentObject(LocalizationManager.preview(languageCode: "ja"))
    .background(ShiftCalendarColors.backgroundColor)
}
#endif
