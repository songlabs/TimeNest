import SwiftUI

/// 日视图 - 浅色时间轴样式日历
struct DayCalendarView: View {
    let selectedDate: Date
    let cell: CalendarDayCell?

    private let timeLabelWidth: CGFloat = 52

    private var allDayEvents: [EventOccurrence] {
        (cell?.events ?? []).filter { $0.isAllDay }.sorted { $0.title < $1.title }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if !allDayEvents.isEmpty {
                    DayAllDayEventsSection(
                        events: allDayEvents,
                        timeLabelWidth: timeLabelWidth
                    )
                }

                DayTimeAxisView(
                    cell: cell,
                    timeLabelWidth: timeLabelWidth,
                    contentWidth: geometry.size.width - timeLabelWidth,
                    timeAxisHeight: geometry.size.height
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ShiftCalendarColors.backgroundColor)
    }
}

// MARK: - 全天事件区域（日视图）

struct DayAllDayEventsSection: View {
    let events: [EventOccurrence]
    let timeLabelWidth: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(LocalizationManager.shared.localized(.editorAllDay))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ShiftCalendarColors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: timeLabelWidth - 8, alignment: .topTrailing)
                .padding(.top, 12)
                .padding(.trailing, 6)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(events, id: \.id) { event in
                    AllDayEventChipView(title: event.title, compact: false)
                }
            }
            .padding(.vertical, 8)
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(ShiftCalendarColors.backgroundColor)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ShiftCalendarColors.separatorColor)
                .frame(height: 0.5)
        }
    }
}

// MARK: - 时间轴区域（日视图）

struct DayTimeAxisView: View {
    let cell: CalendarDayCell?
    let timeLabelWidth: CGFloat
    let contentWidth: CGFloat
    let timeAxisHeight: CGFloat

    private let startHour = 0
    private let endHour = 24
    private let defaultVisibleHour = 9
    private let hourHeight: CGFloat = 64
    private var contentHeight: CGFloat { CGFloat(endHour - startHour) * hourHeight }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    ShiftCalendarColors.backgroundColor

                    hourAnchors

                    timeLabels
                        .frame(width: timeLabelWidth, height: contentHeight, alignment: .topLeading)

                    gridLines
                        .offset(x: timeLabelWidth)

                    eventBlocks
                        .offset(x: timeLabelWidth)

                    if isToday, let lineOffset = currentTimeOffset {
                        CurrentTimeLineDay(
                            timeLabelWidth: timeLabelWidth,
                            contentWidth: contentWidth,
                            lineY: lineOffset
                        )
                    }
                }
                .frame(width: timeLabelWidth + contentWidth, height: contentHeight, alignment: .topLeading)
            }
            .onAppear {
                proxy.scrollTo(hourID(defaultVisibleHour), anchor: .top)
            }
        }
    }

    private var isToday: Bool {
        guard let cell, let today = DateOnly(from: Date()) else { return false }
        return cell.date == today
    }

    private var currentTimeOffset: CGFloat? {
        let components = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: Date())
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        guard hour >= startHour, hour < endHour else { return nil }
        return (CGFloat(hour - startHour) + CGFloat(minute) / 60.0) * hourHeight
    }

    private var hourAnchors: some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                Color.clear
                    .frame(height: hourHeight)
                    .id(hourID(hour))
            }
        }
        .frame(width: 1)
    }

    private var timeLabels: some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(ShiftCalendarColors.secondaryText)
                    .frame(width: timeLabelWidth - 8, height: hourHeight, alignment: .topTrailing)
                    .padding(.trailing, 6)
            }
        }
    }

    private var eventBlocks: some View {
        ZStack(alignment: .topLeading) {
            ForEach(timedEvents, id: \.id) { event in
                CalendarEventBlockView(
                    title: event.title,
                    timeText: eventTimeText(for: event),
                    compact: false
                )
                .frame(
                    width: max(0, contentWidth - 10),
                    height: eventHeight(for: event),
                    alignment: .topLeading
                )
                .offset(x: 5, y: eventOffset(for: event))
            }
        }
        .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
    }

    private var timedEvents: [EventOccurrence] {
        (cell?.events ?? []).filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }
    }

    private var gridLines: some View {
        Path { path in
            for row in 0...(endHour - startHour) {
                let y = CGFloat(row) * hourHeight
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: contentWidth, y: y))
            }

            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: contentHeight))
        }
        .stroke(ShiftCalendarColors.separatorColor, lineWidth: 0.5)
        .frame(width: contentWidth, height: contentHeight)
    }

    private func eventOffset(for event: EventOccurrence) -> CGFloat {
        CGFloat(minutesFromStartOfDay(event.startDate)) / 60.0 * hourHeight
    }

    private func eventHeight(for event: EventOccurrence) -> CGFloat {
        let duration = max(15, minutesBetween(event.startDate, event.endDate))
        return max(28, CGFloat(duration) / 60.0 * hourHeight)
    }

    private func eventTimeText(for event: EventOccurrence) -> String {
        "\(formatTime(event.startDate)) - \(formatTime(event.endDate))"
    }

    private func minutesFromStartOfDay(_ date: Date) -> Int {
        let components = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: date)
        return max(0, min(24 * 60, (components.hour ?? 0) * 60 + (components.minute ?? 0)))
    }

    private func minutesBetween(_ start: Date, _ end: Date) -> Int {
        max(0, Calendar(identifier: .gregorian).dateComponents([.minute], from: start, to: end).minute ?? 0)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func hourID(_ hour: Int) -> String {
        "day-hour-\(hour)"
    }
}

private struct CurrentTimeLineDay: View {
    let timeLabelWidth: CGFloat
    let contentWidth: CGFloat
    let lineY: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(ShiftCalendarColors.sundayRed)
                .frame(width: contentWidth, height: 2)
                .offset(x: timeLabelWidth)

            Circle()
                .fill(ShiftCalendarColors.sundayRed)
                .frame(width: 7, height: 7)
                .offset(x: timeLabelWidth - 3.5)
        }
        .frame(width: timeLabelWidth + contentWidth, alignment: .topLeading)
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
                endDate: CalendarEvent.defaultEndDate(for: today, isAllDay: true),
                isAllDay: true,
                title: "测试全天事件",
                categoryID: nil,
                reminderOffsetMinutes: nil,
                notificationID: nil
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
