import SwiftUI

/// 底部 TabBar 入口类型
enum CalendarTab: String, CaseIterable, Identifiable {
    case monthCalendar
    case listCalendar
    case shiftInput
    case shiftShare
    case settings

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .monthCalendar:
            return "calendar"
        case .listCalendar:
            return "list.bullet"
        case .shiftInput:
            return "pencil.circle"
        case .shiftShare:
            return "square.and.arrow.up"
        case .settings:
            return "gear"
        }
    }

    var localizedKey: LocalizedString {
        switch self {
        case .monthCalendar:
            return .listCalendar
        case .listCalendar:
            return .listCalendar
        case .shiftInput:
            return .shiftInput
        case .shiftShare:
            return .shiftShare
        case .settings:
            return .settingsTitle
        }
    }
}

/// 标准底部 TabBar - 白色背景，选中项蓝色
struct BottomTabBarView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Binding var selectedTab: CalendarTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CalendarTab.allCases) { tab in
                TabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    onTap: {
                        selectedTab = tab
                    }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .background(ShiftCalendarColors.backgroundColor)
        .frame(height: ShiftCalendarLayout.tabBarHeight)
        .ignoresSafeArea(edges: .bottom)
        .id(localization.selectedLanguageCode)
    }
}

/// TabBar 按钮
struct TabButton: View {
    @EnvironmentObject private var localization: LocalizationManager
    let tab: CalendarTab
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: isSelected ? ShiftCalendarLayout.tabBarIconSelectedSize : ShiftCalendarLayout.tabBarIconSize, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? ShiftCalendarColors.primaryBlue : .gray)

                // 使用 localization.selectedLanguageCode 作为依赖，确保语言切换时刷新
                Text(verbatim: localization.localized(tab.localizedKey))
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? ShiftCalendarColors.primaryBlue : .gray)
                    .lineLimit(1)
                    .id(localization.selectedLanguageCode)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        BottomTabBarView(selectedTab: .constant(.monthCalendar))
            .environmentObject(LocalizationManager.preview(languageCode: "ja"))
    }
    .background(ShiftCalendarColors.backgroundColor)
}
