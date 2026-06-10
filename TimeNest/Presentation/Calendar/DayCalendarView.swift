import SwiftUI

/// 日视图 - 浅色时间轴样式日历
struct DayCalendarView: View {
    let selectedDate: Date
    let cell: CalendarDayCell?

    private let timeLabelWidth: CGFloat = 52

    var body: some View {
        GeometryReader { geometry in
            DayTimeAxisView(
                cell: cell,
                timeLabelWidth: timeLabelWidth,
                contentWidth: geometry.size.width - timeLabelWidth,
                timeAxisHeight: geometry.size.height
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ShiftCalendarColors.backgroundColor)
    }
}

// MARK: - 时间轴区域（日视图）

struct DayTimeAxisView: View {
    let cell: CalendarDayCell?
    let timeLabelWidth: CGFloat
    let contentWidth: CGFloat
    let timeAxisHeight: CGFloat

    private let startHour = 9
    private let endHour = 17
    private var hourCount: Int { endHour - startHour + 1 }
    private var rowHeight: CGFloat { timeAxisHeight / CGFloat(hourCount) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ShiftCalendarColors.backgroundColor

            timeLabels
                .frame(width: timeLabelWidth, height: timeAxisHeight, alignment: .topLeading)

            gridLines
                .offset(x: timeLabelWidth)

            if isToday, let lineOffset = currentTimeOffset {
                CurrentTimeLineDay(
                    timeLabelWidth: timeLabelWidth,
                    contentWidth: contentWidth,
                    lineY: lineOffset
                )
            }
        }
    }

    private var isToday: Bool {
        guard let cell, let today = DateOnly(from: Date()) else { return false }
        return cell.date == today
    }

    private var currentTimeOffset: CGFloat? {
        let components = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        guard hour >= startHour, hour <= endHour else { return nil }
        return (CGFloat(hour - startHour) + CGFloat(minute) / 60.0) * rowHeight
    }

    private var timeLabels: some View {
        VStack(spacing: 0) {
            ForEach(startHour...endHour, id: \.self) { hour in
                Text("\(hour)")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(ShiftCalendarColors.secondaryText)
                    .frame(width: timeLabelWidth - 10, height: rowHeight, alignment: .topTrailing)
                    .padding(.trailing, 6)
            }
        }
    }

    private var gridLines: some View {
        Path { path in
            for row in 0...hourCount {
                let y = CGFloat(row) * rowHeight
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: contentWidth, y: y))
            }

            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: timeAxisHeight))
        }
        .stroke(ShiftCalendarColors.separatorColor, lineWidth: 0.5)
        .frame(width: contentWidth, height: timeAxisHeight)
    }
}

struct CurrentTimeLineDay: View {
    let timeLabelWidth: CGFloat
    let contentWidth: CGFloat
    let lineY: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: timeLabelWidth)

            Circle()
                .fill(ShiftCalendarColors.sundayRed)
                .frame(width: 7, height: 7)
                .offset(x: -3.5)

            Rectangle()
                .fill(ShiftCalendarColors.sundayRed)
                .frame(width: contentWidth + 3.5, height: 2)
        }
        .offset(y: lineY)
    }
}

// MARK: - Preview

#if DEBUG
private func makePreviewCell() -> CalendarDayCell {
    let today = Date()
    let dateOnly = DateOnly(from: today)!

    return CalendarDayCell(
        id: dateOnly.id,
        date: dateOnly,
        dayText: "\(dateOnly.day)",
        weekdayText: "日",
        holidays: [],
        events: [
            EventOccurrence(
                id: "test_event",
                eventID: UUID(),
                occurrenceDate: dateOnly,
                startDate: today,
                endDate: nil,
                title: "测试全天事件",
                categoryID: nil
            )
        ],
        isToday: true,
        isWeekend: true,
        isInCurrentMonth: true,
        shiftType: nil,
        eventMarkers: []
    )
}

#Preview {
    DayCalendarView(
        selectedDate: Date(),
        cell: makePreviewCell()
    )
}
#endif
