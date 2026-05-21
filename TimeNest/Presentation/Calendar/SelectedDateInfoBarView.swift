import SwiftUI

/// 选中日期信息条 - 紧凑的信息展示条，替代原来的详情区域
struct SelectedDateInfoBarView: View {
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
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(shiftType.shiftLabelColor)
                        .cornerRadius(3)
                }
            }

            Spacer()

            // 右侧 詳細 > 按钮
            Button(action: onDetailTapped) {
                HStack(spacing: 2) {
                    Text("詳細")
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
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d（E）"
        let date = cell.date.toDate()
        let result = formatter.string(from: date)
        // 将 "5/27（Wed）" 转换为 "5/27（水）"
        return result
            .replacing("Wed", with: "水")
            .replacing("Thu", with: "木")
            .replacing("Fri", with: "金")
            .replacing("Sat", with: "土")
            .replacing("Sun", with: "日")
            .replacing("Mon", with: "月")
            .replacing("Tue", with: "火")
    }
}

// MARK: - Preview

#Preview {
    VStack {
        SelectedDateInfoBarView(
            cell: CalendarDayCell(
                id: "2026-05-27",
                date: DateOnly(year: 2026, month: 5, day: 27),
                dayText: "27",
                weekdayText: "水",
                holidays: [],
                events: [],
                isToday: false,
                isWeekend: false,
                isInCurrentMonth: true,
                shiftType: "入り",
                eventMarkers: []
            ),
            onDetailTapped: {}
        )

        SelectedDateInfoBarView(
            cell: CalendarDayCell(
                id: "2026-05-24",
                date: DateOnly(year: 2026, month: 5, day: 24),
                dayText: "24",
                weekdayText: "土",
                holidays: [],
                events: [],
                isToday: false,
                isWeekend: true,
                isInCurrentMonth: true,
                shiftType: "休み",
                eventMarkers: []
            ),
            onDetailTapped: {}
        )
    }
    .background(ShiftCalendarColors.backgroundColor)
}
