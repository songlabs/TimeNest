import SwiftUI

/// 日历底部工具栏 - 旧版 TabBar 风格
/// 左侧：今日 | 中间：月/周/日 | 右侧：蓝色圆形加号
/// 广告位在 TabBar 上方
struct CalendarBottomToolbarView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Binding var selectedViewMode: CalendarViewMode
    let onTodayTapped: () -> Void
    let onAddEventTapped: () -> Void
    let onModeChanged: ((CalendarViewMode) -> Void)?

    init(
        selectedViewMode: Binding<CalendarViewMode>,
        onTodayTapped: @escaping () -> Void,
        onAddEventTapped: @escaping () -> Void,
        onModeChanged: ((CalendarViewMode) -> Void)? = nil
    ) {
        _selectedViewMode = selectedViewMode
        self.onTodayTapped = onTodayTapped
        self.onAddEventTapped = onAddEventTapped
        self.onModeChanged = onModeChanged
    }

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
                            .font(.system(size: 14, weight: .medium))
                        Text(verbatim: localization.localized(.today))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(ShiftCalendarColors.primaryBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
                    .cornerRadius(6)
                }

                // 中间弹性空间
                Spacer()

                // 中间：视图切换按钮
                HStack(spacing: 4) {
                    ForEach(CalendarViewMode.allCases) { mode in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedViewMode = mode
                            }
                            onModeChanged?(mode)
                        }) {
                            Text(verbatim: mode.displayName)
                                .font(.system(size: 13, weight: selectedViewMode == mode ? .semibold : .regular))
                                .foregroundColor(selectedViewMode == mode ? ShiftCalendarColors.primaryBlue : ShiftCalendarColors.secondaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
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
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(ShiftCalendarColors.primaryBlue)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(ShiftCalendarColors.backgroundColor)
        .frame(height: CalendarBottomToolbarLayout.toolbarHeight)
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Layout Constants

struct CalendarBottomToolbarLayout {
    static let toolbarHeight: CGFloat = 56
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack {
        Spacer()
        CalendarBottomToolbarView(
            selectedViewMode: .constant(.month),
            onTodayTapped: {},
            onAddEventTapped: {},
            onModeChanged: { _ in }
        )
        .environmentObject(LocalizationManager.preview(languageCode: "ja"))
    }
    .background(ShiftCalendarColors.backgroundColor)
}
#endif
