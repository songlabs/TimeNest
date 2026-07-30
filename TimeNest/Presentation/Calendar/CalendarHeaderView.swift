import SwiftUI

/// 日历 Header - 月/周/日共用同一套导航布局。
/// 结构统一为：中间（左箭头 + 标题 + 右箭头）+ 右侧更多菜单。
struct CalendarHeaderView: View {
    @EnvironmentObject private var localization: LocalizationManager

    let title: String
    let displayMode: CalendarViewMode
    let calendarAvatarInitial: String?
    let calendarDisplayName: String
    let isReadOnlyCalendar: Bool
    let onCalendarTapped: () -> Void
    let onStatisticsTapped: () -> Void
    let onShiftInputTapped: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onTitleTapped: () -> Void
    let onSettingsTapped: () -> Void

    init(
        title: String,
        displayMode: CalendarViewMode,
        calendarAvatarInitial: String? = nil,
        calendarDisplayName: String = "",
        isReadOnlyCalendar: Bool = false,
        onCalendarTapped: @escaping () -> Void = {},
        onStatisticsTapped: @escaping () -> Void,
        onShiftInputTapped: @escaping () -> Void,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onTitleTapped: @escaping () -> Void,
        onSettingsTapped: @escaping () -> Void
    ) {
        self.title = title
        self.displayMode = displayMode
        self.calendarAvatarInitial = calendarAvatarInitial
        self.calendarDisplayName = calendarDisplayName
        self.isReadOnlyCalendar = isReadOnlyCalendar
        self.onCalendarTapped = onCalendarTapped
        self.onStatisticsTapped = onStatisticsTapped
        self.onShiftInputTapped = onShiftInputTapped
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.onTitleTapped = onTitleTapped
        self.onSettingsTapped = onSettingsTapped
    }

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
            calendarSelectionButton

            HStack(spacing: 6) {
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
                    .padding(.vertical, 3)
                    .frame(minHeight: 36)
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
                .accessibilityLabel(Text(localization.localized(.selectYearMonth)))

                navigationButton(icon: "chevron.right", action: onNext)
            }
            .padding(.horizontal, 4)
            .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, alignment: .center)

            moreMenu
        }
    }

    private var calendarSelectionButton: some View {
        Button(action: onCalendarTapped) {
            ZStack(alignment: .bottomTrailing) {
                CalendarIdentityAvatarView(initial: calendarAvatarInitial, size: 36)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(ShiftCalendarColors.primaryBlue)
                    .frame(width: 14, height: 14)
                    .background(ShiftCalendarColors.backgroundColor)
                    .clipShape(Circle())
                    .offset(x: 2, y: 2)
            }
            .frame(
                width: ShiftCalendarLayout.headerHeight,
                height: ShiftCalendarLayout.headerHeight,
                alignment: .center
            )
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localization.localized(.calendarSharingSwitchAccessibilityLabel))
        .accessibilityHint(localization.localized(.calendarSharingSwitchAccessibilityHint))
        .accessibilityValue(
            calendarDisplayName.isEmpty
                ? localization.localized(.calendarSharingMyCalendar)
                : calendarDisplayName
        )
        .accessibilityAddTraits(.isSelected)
        .accessibilityIdentifier("sharing.calendarSelector")
    }

    private var titleFont: Font {
        switch displayMode {
        case .month, .week:
            return .system(size: 28, weight: .semibold)
        case .day:
            return .system(size: 24, weight: .semibold)
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
            if displayMode == .month && !isReadOnlyCalendar {
                Button(action: onShiftInputTapped) {
                    Label(localization.localized(.shiftInputTitle), systemImage: "calendar.badge.plus")
                }
            }

            if !isReadOnlyCalendar {
                Button(action: onStatisticsTapped) {
                    Label(localization.localized(.workStatistics), systemImage: "chart.bar.xaxis")
                }
            }

            Button(action: onSettingsTapped) {
                Label(localization.localized(.settingsTitle), systemImage: "gearshape")
            }
            .accessibilityIdentifier("settings.open")
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(ShiftCalendarColors.primaryBlue)
                .frame(width: 36, height: 36)
                .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
                .clipShape(Circle())
                .frame(
                    width: ShiftCalendarLayout.headerHeight,
                    height: ShiftCalendarLayout.headerHeight,
                    alignment: .center
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("calendar.moreMenu")
        .accessibilityLabel(Text(localization.localized(.moreMenu)))
        .accessibilityHint(Text(localization.localized(.moreMenu)))
    }

    /// 左右箭头按钮：背景由共用导航容器统一提供。
    private func navigationButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(ShiftCalendarColors.primaryBlue)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

}
