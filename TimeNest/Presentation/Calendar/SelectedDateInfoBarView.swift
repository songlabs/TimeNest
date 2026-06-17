import SwiftUI

/// 选中日期信息条 - 紧凑的信息展示条，替代原来的详情区域
struct SelectedDateInfoBarView: View {
    @EnvironmentObject private var localization: LocalizationManager
    let cell: CalendarDayCell
    let onDetailTapped: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // 左侧日历图标
            Image(systemName: "calendar")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ShiftCalendarColors.primaryBlue)
                .frame(width: 24)

            // 中间：日期 + 班次
            HStack(spacing: 6) {
                // 日期 "5/27（水）"
                Text(formattedDate)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ShiftCalendarColors.primaryText)

                // 班次标签
                if let shiftType = cell.shiftType {
                    Text(shiftType)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(shiftType.shiftLabelForegroundColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(shiftType.shiftLabelBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(shiftType.shiftLabelBorderColor, lineWidth: 0.7)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
            }

            Spacer()

            // 右侧 詳細 > 按钮
            Button(action: onDetailTapped) {
                HStack(spacing: 2) {
                    Text(localization.localized(.detail))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ShiftCalendarColors.primaryBlue)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(ShiftCalendarColors.primaryBlue)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: ShiftCalendarLayout.selectedDateInfoHeight)
        .background(ShiftCalendarColors.cardBackgroundColor)
    }

    private var formattedDate: String {
        let date = cell.date.toDate()
        return LocalizationManager.shared.formattedDateShort(for: date)
    }
}
