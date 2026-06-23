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
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: ShiftCalendarLayout.footerButtonFontSize * 0.9, weight: ShiftCalendarLayout.footerButtonFontWeight))
                        Text(verbatim: localization.localized(.today))
                            .font(.system(size: ShiftCalendarLayout.footerButtonFontSize, weight: ShiftCalendarLayout.footerButtonFontWeight))
                    }
                    .foregroundColor(ShiftCalendarColors.primaryBlue)
                    .padding(.horizontal, 14)
                    .frame(height: ShiftCalendarLayout.footerButtonHeight)
                    .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
                    .cornerRadius(ShiftCalendarLayout.footerButtonCornerRadius)
                }

                // 中间弹性空间
                Spacer()

                // 中间：视图切换按钮
                HStack(spacing: 5) {
                    ForEach(CalendarViewMode.allCases) { mode in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedViewMode = mode
                            }
                            onModeChanged?(mode)
                        }) {
                            Text(verbatim: localization.localized(mode.localizedKey))
                                .font(.system(size: ShiftCalendarLayout.footerButtonFontSize, weight: selectedViewMode == mode ? .semibold : ShiftCalendarLayout.footerButtonFontWeight))
                                .foregroundColor(selectedViewMode == mode ? ShiftCalendarColors.primaryBlue : ShiftCalendarColors.secondaryText)
                                .frame(width: 48, height: ShiftCalendarLayout.footerButtonHeight)
                                .background(
                                    RoundedRectangle(cornerRadius: ShiftCalendarLayout.footerButtonCornerRadius)
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: ShiftCalendarLayout.addButtonSize, height: ShiftCalendarLayout.addButtonSize)
                        .background(ShiftCalendarColors.primaryBlue)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
        .background(ShiftCalendarColors.backgroundColor)
        .frame(height: ShiftCalendarLayout.footerToolbarHeight)
    }
}
