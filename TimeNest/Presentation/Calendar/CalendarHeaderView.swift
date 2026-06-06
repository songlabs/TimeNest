import SwiftUI

/// 日历 Header - 左侧：左箭头 + 年月 + 右箭头 | 右侧：设置按钮
struct CalendarHeaderView: View {
    @EnvironmentObject private var localization: LocalizationManager

    let title: String
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onTodayTapped: () -> Void
    let onTitleTapped: () -> Void
    let onSettingsTapped: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // 左侧区域：左箭头 + 年月标题 + 右箭头
            HStack(spacing: 16) {
                // 上一月按钮
                Button(action: onPreviousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ShiftCalendarColors.primaryBlue)
                        .frame(width: 32, height: 32)
                        .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
                        .clipShape(Circle())
                }

                // 年月标题 - "2026 年 5 月" 格式（可点击）
                Button(action: onTitleTapped) {
                    Text(title)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(ShiftCalendarColors.primaryText)
                }
                .contentShape(Rectangle())

                // 下一月按钮
                Button(action: onNextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ShiftCalendarColors.primaryBlue)
                        .frame(width: 32, height: 32)
                        .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            .padding(.leading, 12)

            // 中间 Spacer - 将右侧按钮推到右边
            Spacer()

            // 右侧：设置按钮
            Button(action: onSettingsTapped) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ShiftCalendarColors.primaryBlue)
                    .frame(width: 36, height: 36)
                    .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
                    .clipShape(Circle())
            }
            .padding(.trailing, 12)
        }
        .padding(.vertical, 12)
        .frame(height: ShiftCalendarLayout.headerHeight)
        .background(ShiftCalendarColors.backgroundColor)
    }
}

// MARK: - Preview

#Preview {
    CalendarHeaderView(
        title: "2026 年 5 月",
        onPreviousMonth: {},
        onNextMonth: {},
        onTodayTapped: {},
        onTitleTapped: {},
        onSettingsTapped: {}
    )
    .padding()
    .background(ShiftCalendarColors.backgroundColor)
}
