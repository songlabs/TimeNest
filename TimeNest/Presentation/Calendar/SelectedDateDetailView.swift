import SwiftUI

struct SelectedDateDetailView: View {
    @EnvironmentObject private var localization: LocalizationManager
    let cell: CalendarDayCell
    let onAddEventTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 分隔线
            Rectangle()
                .fill(ShiftCalendarColors.separatorColor)
                .frame(height: 0.5)

            // 第一行：日期 + 星期徽章 + 班次
            HStack(alignment: .center, spacing: 8) {
                // 大号日期 "5/21"
                Text(formattedDateTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ShiftCalendarColors.primaryText)

                // 圆形星期徽章
                Text(cell.weekdayText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(ShiftCalendarColors.primaryBlue)
                    .clipShape(Circle())

                Spacer()

                // 班次标签
                if let shiftType = cell.shiftType {
                    Text(shiftType)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(shiftType.shiftLabelForegroundColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(shiftType.shiftLabelBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(shiftType.shiftLabelBorderColor, lineWidth: 0.7)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // 第二行：事件图标
            if let marker = cell.eventMarkers.first {
                HStack {
                    Image(systemName: marker.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(marker.color)

                    Text(markerTypeToString(marker))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ShiftCalendarColors.secondaryText)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            // 第三行：添加日程入口
            Button(action: onAddEventTapped) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ShiftCalendarColors.primaryBlue)

                    Text(verbatim: localization.localized(.calendarAddEvent))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ShiftCalendarColors.primaryText)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .background(ShiftCalendarColors.cardBackgroundColor)
        .frame(height: 100)
    }

    private var formattedDateTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        let date = cell.date.toDate()
        return formatter.string(from: date)
    }

    private func markerTypeToString(_ marker: EventMarkerType) -> String {
        switch marker {
        case .clover:
            return localization.localized(.eventMarkerDayOff)
        case .memo:
            return localization.localized(.eventMarkerMemo)
        case .car:
            return localization.localized(.eventMarkerTransport)
        case .health:
            return localization.localized(.eventMarkerHealth)
        case .dot:
            return localization.localized(.eventMarkerEvent)
        }
    }
}

// MARK: - Preview

#Preview {
    SelectedDateDetailView(
        cell: CalendarDayCell(
            id: "2026-05-21",
            date: DateOnly(year: 2026, month: 5, day: 21),
            dayText: "21",
            weekdayText: "木",
            holidays: [],
            events: [],
            isToday: false,
            isWeekend: false,
            isInCurrentMonth: true,
            shiftType: "休み",
            eventMarkers: [.clover]
        ),
        onAddEventTapped: {}
    )
    .environmentObject(LocalizationManager.preview(languageCode: "ja"))
    .background(ShiftCalendarColors.backgroundColor)
}
