import SwiftUI

/// 日历 Header - 月/周/日共用同一套导航布局。
/// 结构统一为：中间（左箭头 + 标题 + 右箭头）+ 右侧更多菜单。
struct CalendarHeaderView: View {
    @EnvironmentObject private var localization: LocalizationManager

    let title: String
    let displayMode: CalendarViewMode
    let onStatisticsTapped: () -> Void
    let onShiftInputTapped: () -> Void
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
    /// 中间导航区域 + 右侧更多菜单。
    private var unifiedHeaderView: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: 44)

            HStack(spacing: titleSpacing) {
                navigationButton(icon: "chevron.left", action: onPrevious)

                Button(action: onTitleTapped) {
                    HStack(spacing: 7) {
                        Text(title)
                            .font(titleFont)
                            .lineLimit(1)
                            .minimumScaleFactor(titleMinimumScaleFactor)
                            .allowsTightening(true)
                            .fixedSize(horizontal: false, vertical: true)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ShiftCalendarColors.primaryBlue)
                    }
                    .foregroundColor(ShiftCalendarColors.primaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ShiftCalendarColors.primaryBlue.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Capsule())
                .accessibilityLabel(Text(localization.localized(.selectYearMonth)))

                navigationButton(icon: "chevron.right", action: onNext)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            moreMenu
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

    /// 右侧更多菜单：收纳低频入口。
    private var moreMenu: some View {
        Menu {
            if displayMode == .month {
                Button(action: onShiftInputTapped) {
                    Label(localization.localized(.shiftInputTitle), systemImage: "calendar.badge.plus")
                }
            }

            Button(action: onStatisticsTapped) {
                Label(localization.localized(.workStatistics), systemImage: "chart.bar.xaxis")
            }

            Button(action: onSettingsTapped) {
                Label(localization.localized(.settingsTitle), systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(ShiftCalendarColors.primaryBlue)
                .frame(width: 36, height: 36)
                .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(Text(localization.localized(.moreMenu)))
        .accessibilityHint(Text(localization.localized(.moreMenu)))
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

}
