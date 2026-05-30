import SwiftUI

/// 日历 Header - 压缩高度，"2026 年 5 月" 格式，前后月切换 + Shift Input 按钮
struct CalendarHeaderView: View {
    @EnvironmentObject private var localization: LocalizationManager
    let title: String
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onAddButtonTapped: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // 左侧菜单/返回按钮
            Button(action: onPreviousMonth) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ShiftCalendarColors.primaryBlue)
                    .frame(width: 36, height: 36)
                    .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
                    .clipShape(Circle())
            }

            Spacer(minLength: 4)

            // 中央年月 - "2026 年 5 月" 格式
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(ShiftCalendarColors.primaryText)

            Spacer(minLength: 4)

            // 右侧前后月切换按钮
            HStack(spacing: 4) {
                Button(action: onPreviousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ShiftCalendarColors.primaryBlue)
                        .frame(width: 28, height: 28)
                        .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
                        .clipShape(Circle())
                }

                Button(action: onNextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ShiftCalendarColors.primaryBlue)
                        .frame(width: 28, height: 28)
                        .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
                        .clipShape(Circle())
                }
            }

            // Shift Input 按钮
            Button(action: onAddButtonTapped) {
                Text(verbatim: localization.localized(.shiftInput))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 68, height: 28)
                    .background(ShiftCalendarColors.primaryBlue)
                    .cornerRadius(5)
            }
        }
        .padding(.horizontal, 12)
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
        onAddButtonTapped: {}
    )
    .padding()
    .background(ShiftCalendarColors.backgroundColor)
}
