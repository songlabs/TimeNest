import SwiftUI

/// 日历 Header - 左箭头 | 年月 | 右箭头 + 今日按钮
struct CalendarHeaderView: View {
    @EnvironmentObject private var localization: LocalizationManager
    
    let title: String
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onTodayTapped: () -> Void
    let onTitleTapped: () -> Void
    
    var body: some View {
        ZStack {
            // 中央区域：左箭头 | 年月 | 右箭头（整体居中）
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
                
                // 中央年月 - "2026 年 5 月" 格式（可点击）
                Button(action: onTitleTapped) {
                    Text(title)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(ShiftCalendarColors.primaryText)
                }
                .contentShape(Rectangle())
                
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
            
            // 今日按钮（靠右）
            HStack {
                Spacer()
                Button(action: onTodayTapped) {
                    Text(verbatim: localization.localized(.today))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ShiftCalendarColors.primaryBlue)
                        .frame(height: 34)
                        .padding(.horizontal, 16)
                        .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
                        .cornerRadius(8)
                }
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
        onTitleTapped: {}
    )
    .padding()
    .background(ShiftCalendarColors.backgroundColor)
}
