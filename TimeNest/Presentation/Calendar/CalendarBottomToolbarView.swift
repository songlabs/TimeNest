import SwiftUI

/// 日历底部工具栏 - 替代原有 TabBar
struct CalendarBottomToolbarView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Binding var selectedViewMode: CalendarViewMode
    let onTodayTapped: () -> Void
    let onAddEventTapped: () -> Void
    let onSettingsTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 顶部浅分隔线
            Rectangle()
                .fill(ShiftCalendarColors.separatorColor)
                .frame(height: 0.5)

            // 工具栏主体
            HStack(spacing: 0) {
                // 左侧：今日按钮
                Button(action: onTodayTapped) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 16, weight: .medium))
                        Text(verbatim: localization.localized(.today))
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(ShiftCalendarColors.primaryBlue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
                    .cornerRadius(8)
                }

                // 中间弹性空间
                Spacer()

                // 中间：视图切换按钮
                HStack(spacing: 8) {
                    ForEach(CalendarViewMode.allCases) { mode in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedViewMode = mode
                            }
                        }) {
                            Text(verbatim: mode.displayName)
                                .font(.system(size: 14, weight: selectedViewMode == mode ? .semibold : .regular))
                                .foregroundColor(selectedViewMode == mode ? ShiftCalendarColors.primaryBlue : .gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(selectedViewMode == mode ? ShiftCalendarColors.primaryBlue.opacity(0.12) : Color.clear)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                // 右侧弹性空间
                Spacer()

                // 右侧：添加按钮
                Button(action: onAddEventTapped) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 52, height: 52)
                        .background(ShiftCalendarColors.primaryBlue)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(ShiftCalendarColors.backgroundColor)
        .frame(height: CalendarBottomToolbarLayout.toolbarHeight)
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Layout Constants

struct CalendarBottomToolbarLayout {
    static let toolbarHeight: CGFloat = 72
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        CalendarBottomToolbarView(
            selectedViewMode: .constant(.month),
            onTodayTapped: {},
            onAddEventTapped: {},
            onSettingsTapped: {}
        )
        .environmentObject(LocalizationManager.preview(languageCode: "ja"))
    }
    .background(ShiftCalendarColors.backgroundColor)
}
