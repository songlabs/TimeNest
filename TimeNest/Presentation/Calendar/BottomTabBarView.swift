import SwiftUI

/// 底部 TabBar 入口类型
enum CalendarTab: String, CaseIterable {
    case monthCalendar = "カレンダー"
    case listCalendar = "リスト"
    case shiftInput = "シフト入力"
    case shiftShare = "シフト共有"
    case settings = "設定"

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
}

/// 标准底部 TabBar - 白色背景，选中项蓝色
struct BottomTabBarView: View {
    @Binding var selectedTab: CalendarTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CalendarTab.allCases, id: \.self) { tab in
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
    }
}

/// TabBar 按钮
struct TabButton: View {
    let tab: CalendarTab
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: isSelected ? ShiftCalendarLayout.tabBarIconSelectedSize : ShiftCalendarLayout.tabBarIconSize, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? ShiftCalendarColors.primaryBlue : .gray)

                Text(tab.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? ShiftCalendarColors.primaryBlue : .gray)
                    .lineLimit(1)
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
    }
    .background(ShiftCalendarColors.backgroundColor)
}
