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
        Group {
            switch displayMode {
            case .month:
                monthHeaderView
            case .week:
                weekHeaderView
            case .day:
                dayHeaderView
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

    /// 周视图 Header - 左侧年月标题，右侧 3/5/7 日切换与设置
    private var weekHeaderView: some View {
        HStack(spacing: 12) {
            Button(action: onTitleTapped) {
                Text(title)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(ShiftCalendarColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer(minLength: 8)

            weekSegmentedControl

            rightButtonsView
                .frame(width: 36)
        }
    }

    /// 日视图 Header - 浅蓝圆形左右切换按钮 + 完整日期标题 + 设置
    private var dayHeaderView: some View {
        HStack(spacing: 10) {
            navigationButton(icon: "chevron.left", action: onPrevious)

            Button(action: onTitleTapped) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(ShiftCalendarColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(PlainButtonStyle())

            navigationButton(icon: "chevron.right", action: onNext)

            rightButtonsView
                .frame(width: 36)
        }
    }

    /// 右侧按钮区域（设置）
    private var rightButtonsView: some View {
        Button(action: onSettingsTapped) {
            Image(systemName: "gearshape")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(ShiftCalendarColors.primaryBlue)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var weekSegmentedControl: some View {
        HStack(spacing: 0) {
            ForEach([3, 5, 7], id: \.self) { days in
                Button(action: {
                    onWeekDaysChanged(days)
                }) {
                    Text(verbatim: "\(days)日")
                        .font(.system(size: 16, weight: weekDisplayDays == days ? .semibold : .regular))
                        .foregroundColor(weekDisplayDays == days ? ShiftCalendarColors.primaryBlue : ShiftCalendarColors.secondaryText)
                        .frame(width: 52, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(weekDisplayDays == days ? ShiftCalendarColors.primaryBlue.opacity(0.12) : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())

                if days != 7 {
                    Rectangle()
                        .fill(ShiftCalendarColors.separatorColor.opacity(0.5))
                        .frame(width: 0.5, height: 22)
                }
            }
        }
    }

    @ViewBuilder
    private func navigationButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(ShiftCalendarColors.primaryBlue)
                .frame(width: 42, height: 42)
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
