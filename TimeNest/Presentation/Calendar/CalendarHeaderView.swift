import SwiftUI

/// 日历 Header - 简化布局：左箭头 | 年月 | 右箭头
struct CalendarHeaderView: View {
    let title: String
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // 左侧：上一月按钮
            Button(action: onPreviousMonth) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ShiftCalendarColors.primaryBlue)
                    .frame(width: 32, height: 32)
                    .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
                    .clipShape(Circle())
            }

            // 中央年月 - "2026 年 5 月" 格式
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(ShiftCalendarColors.primaryText)

            // 右侧：下一月按钮
            Button(action: onNextMonth) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ShiftCalendarColors.primaryBlue)
                    .frame(width: 32, height: 32)
                    .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
                    .clipShape(Circle())
            }
        }
        .frame(maxWidth: .infinity)
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
        onNextMonth: {}
    )
    .padding()
    .background(ShiftCalendarColors.backgroundColor)
}
