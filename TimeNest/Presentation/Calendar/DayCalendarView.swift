import SwiftUI

/// 日视图 - 浅色时间轴样式日历
struct DayCalendarView: View {
    let selectedDate: Date
    let cell: CalendarDayCell?
    let onEventTapped: (EventOccurrence) -> Void

    init(
        selectedDate: Date,
        cell: CalendarDayCell?,
        onEventTapped: @escaping (EventOccurrence) -> Void = { _ in }
    ) {
        self.selectedDate = selectedDate
        self.cell = cell
        self.onEventTapped = onEventTapped
    }

    private let timeLabelWidth = CalendarTimelineLayout.timeLabelWidth

    var body: some View {
        GeometryReader { geometry in
            let allDayEvents = CalendarTimelineEventMetrics.allDayEvents(in: cell?.events ?? [])
            let contentWidth = CalendarTimelineLayout.nonNegativeDimension(geometry.size.width - timeLabelWidth)
            let timeAxisHeight = CalendarTimelineLayout.nonNegativeDimension(geometry.size.height)

            VStack(spacing: 0) {
                if !allDayEvents.isEmpty {
                    DayAllDayEventsSection(
                        events: allDayEvents,
                        timeLabelWidth: timeLabelWidth,
                        onEventTapped: onEventTapped
                    )
                }

                DayTimeAxisView(
                    cell: cell,
                    timeLabelWidth: timeLabelWidth,
                    contentWidth: contentWidth,
                    timeAxisHeight: timeAxisHeight,
                    onEventTapped: onEventTapped
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
    let onEventTapped: (EventOccurrence) -> Void

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
                    AllDayEventChipView(event: event, compact: false)
                        .contentShape(Rectangle())
                        .onTapGesture { onEventTapped(event) }
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
    let onEventTapped: (EventOccurrence) -> Void

    private let startHour = CalendarTimelineLayout.startHour
    private let endHour = CalendarTimelineLayout.endHour
    private let defaultVisibleHour = CalendarTimelineLayout.defaultVisibleHour
    private let hourHeight = CalendarTimelineLayout.hourHeight
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
        CalendarTimelineEventMetrics.currentTimeOffset(for: Date(), hourHeight: hourHeight)
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
                    event: event,
                    timeText: eventTimeText(for: event),
                    compact: false
                )
                .frame(
                    width: max(0, contentWidth - 10),
                    height: eventHeight(for: event),
                    alignment: .topLeading
                )
                .offset(x: 5, y: eventOffset(for: event))
                .contentShape(Rectangle())
                .onTapGesture { onEventTapped(event) }
            }
        }
        .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
    }

    private var timedEvents: [EventOccurrence] {
        CalendarTimelineEventMetrics.timedEvents(in: cell?.events ?? [])
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
        CalendarTimelineEventMetrics.verticalOffset(for: event, hourHeight: hourHeight)
    }

    private func eventHeight(for event: EventOccurrence) -> CGFloat {
        CalendarTimelineEventMetrics.eventHeight(
            for: event,
            minimumHeight: 28,
            hourHeight: hourHeight
        )
    }

    private func eventTimeText(for event: EventOccurrence) -> String {
        CalendarTimelineEventMetrics.timeText(for: event)
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
