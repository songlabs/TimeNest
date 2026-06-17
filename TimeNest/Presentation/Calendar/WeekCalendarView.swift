import SwiftUI

/// 周视图 - 浅色时间轴样式日历
struct WeekCalendarView: View {
    let selectedDate: Date
    let cells: [CalendarDayCell]
    let onDateSelected: (Date) -> Void

    private let timeLabelWidth: CGFloat = 52
    private let dateHeaderHeight: CGFloat = 72
    private let allDayRowVerticalPadding: CGFloat = 8
    private let allDayChipHeight: CGFloat = 20
    private let allDayChipSpacing: CGFloat = 4

    private var hasAllDayEvents: Bool {
        cells.contains { cell in
            cell.events.contains { $0.isAllDay }
        }
    }

    private var allDayRowHeight: CGFloat {
        guard hasAllDayEvents else { return 0 }
        let maxVisibleRows = cells.map { cell in
            let count = cell.events.filter { $0.isAllDay }.count
            if count > 2 { return 3 }
            return count
        }.max() ?? 1
        return allDayRowVerticalPadding * 2
            + CGFloat(max(1, maxVisibleRows)) * allDayChipHeight
            + CGFloat(max(0, maxVisibleRows - 1)) * allDayChipSpacing
    }

    var body: some View {
        GeometryReader { geometry in
            let displayCellCount = max(cells.count, 1)
            let columnWidth = (geometry.size.width - timeLabelWidth) / CGFloat(displayCellCount)

            VStack(spacing: 0) {
                WeekDateHeaderView(
                    cells: cells,
                    timeLabelWidth: timeLabelWidth,
                    columnWidth: columnWidth,
                    selectedDate: selectedDate,
                    onDateSelected: onDateSelected
                )
                .frame(height: dateHeaderHeight)

                if hasAllDayEvents {
                    WeekAllDayEventsRow(
                        cells: cells,
                        timeLabelWidth: timeLabelWidth,
                        columnWidth: columnWidth,
                        selectedDate: selectedDate,
                        rowHeight: allDayRowHeight
                    )
                    .frame(height: allDayRowHeight)
                }

                WeekTimeAxisView(
                    cells: cells,
                    timeLabelWidth: timeLabelWidth,
                    columnWidth: columnWidth,
                    selectedDate: selectedDate
                )
                .frame(height: max(0, geometry.size.height - dateHeaderHeight - allDayRowHeight))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ShiftCalendarColors.backgroundColor)
    }
}

// MARK: - 日期 Header 行

struct WeekDateHeaderView: View {
    let cells: [CalendarDayCell]
    let timeLabelWidth: CGFloat
    let columnWidth: CGFloat
    let selectedDate: Date
    let onDateSelected: (Date) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(ShiftCalendarColors.backgroundColor)
                .frame(width: timeLabelWidth)

            ForEach(cells, id: \.id) { cell in
                WeekDateHeaderCell(
                    cell: cell,
                    columnWidth: columnWidth,
                    isSelected: isDateSelected(cell.date)
                )
                .frame(width: columnWidth)
                .contentShape(Rectangle())
                .onTapGesture {
                    onDateSelected(cell.date.toDate())
                }
            }
        }
        .background(ShiftCalendarColors.backgroundColor)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ShiftCalendarColors.separatorColor)
                .frame(height: 0.5)
        }
    }

    private func isDateSelected(_ dateOnly: DateOnly) -> Bool {
        guard let selectedDateOnly = DateOnly(from: selectedDate) else {
            return false
        }
        return dateOnly == selectedDateOnly
    }
}

struct WeekDateHeaderCell: View {
    let cell: CalendarDayCell
    let columnWidth: CGFloat
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(cell.dayText)
                .font(.system(size: 22, weight: isSelected ? .semibold : .medium))
                .foregroundColor(dateTextColor)

            Text(cell.weekdayText)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(weekdayTextColor)
        }
        .frame(width: columnWidth)
        .frame(maxHeight: .infinity)
        .background(isSelected ? ShiftCalendarColors.primaryBlue.opacity(0.10) : Color.clear)
    }

    private var dateTextColor: Color {
        if isSelected {
            return ShiftCalendarColors.primaryBlue
        }
        return weekendColor ?? ShiftCalendarColors.secondaryText
    }

    private var weekdayTextColor: Color {
        weekendColor ?? ShiftCalendarColors.secondaryText
    }

    private var weekendColor: Color? {
        ShiftCalendarColors.weekendTextColor(for: cell.weekdayText)
    }
}

// MARK: - 全天事件行

struct WeekAllDayEventsRow: View {
    let cells: [CalendarDayCell]
    let timeLabelWidth: CGFloat
    let columnWidth: CGFloat
    let selectedDate: Date
    let rowHeight: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(LocalizationManager.shared.localized(.editorAllDay))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ShiftCalendarColors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: timeLabelWidth - 8, height: rowHeight, alignment: .topTrailing)
                .padding(.top, 10)
                .padding(.trailing, 6)

            ForEach(cells, id: \.id) { cell in
                WeekAllDayColumn(
                    events: allDayEvents(in: cell),
                    isSelected: isDateSelected(cell.date)
                )
                .frame(width: columnWidth, height: rowHeight, alignment: .top)
            }
        }
        .background(ShiftCalendarColors.backgroundColor)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ShiftCalendarColors.separatorColor)
                .frame(height: 0.5)
        }
    }

    private func allDayEvents(in cell: CalendarDayCell) -> [EventOccurrence] {
        cell.events.filter { $0.isAllDay }.sorted { $0.title < $1.title }
    }

    private func isDateSelected(_ dateOnly: DateOnly) -> Bool {
        guard let selectedDateOnly = DateOnly(from: selectedDate) else {
            return false
        }
        return dateOnly == selectedDateOnly
    }
}

private struct WeekAllDayColumn: View {
    let events: [EventOccurrence]
    let isSelected: Bool

    private var visibleEvents: [EventOccurrence] { Array(events.prefix(2)) }
    private var hiddenCount: Int { max(0, events.count - visibleEvents.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(visibleEvents, id: \.id) { event in
                AllDayEventChipView(title: event.title, compact: true)
            }

            if hiddenCount > 0 {
                Text(moreEventsText(hiddenCount))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(ShiftCalendarColors.secondaryText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isSelected ? ShiftCalendarColors.primaryBlue.opacity(0.06) : Color.clear)
        .clipped()
    }
}

struct AllDayEventChipView: View {
    let title: String
    let compact: Bool

    var body: some View {
        Text(title)
            .font(.system(size: compact ? 10 : 13, weight: .semibold))
            .foregroundColor(ShiftCalendarColors.primaryBlueDark)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, compact ? 5 : 10)
            .padding(.vertical, compact ? 3 : 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ShiftCalendarColors.primaryBlue.opacity(0.14))
            .cornerRadius(compact ? 5 : 8)
    }
}

func moreEventsText(_ count: Int) -> String {
    String(format: LocalizationManager.shared.localized(.calendarMoreEventsCount), count)
}

// MARK: - 时间轴区域

struct WeekTimeAxisView: View {
    let cells: [CalendarDayCell]
    let timeLabelWidth: CGFloat
    let columnWidth: CGFloat
    let selectedDate: Date

    private let startHour = 0
    private let endHour = 24
    private let defaultVisibleHour = 9
    private let hourHeight: CGFloat = 64
    private var contentHeight: CGFloat { CGFloat(endHour - startHour) * hourHeight }

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = columnWidth * CGFloat(cells.count)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        ShiftCalendarColors.backgroundColor

                        hourAnchors

                        if let selectedIndex = selectedColumnIndex {
                            Rectangle()
                                .fill(ShiftCalendarColors.primaryBlue.opacity(0.08))
                                .frame(width: columnWidth, height: contentHeight)
                                .offset(x: timeLabelWidth + columnWidth * CGFloat(selectedIndex))
                        }

                        timeLabels
                            .frame(width: timeLabelWidth, height: contentHeight, alignment: .topLeading)

                        gridLines(contentWidth: contentWidth)
                            .offset(x: timeLabelWidth)

                        eventBlocks
                            .offset(x: timeLabelWidth)

                        if let todayIndex = todayColumnIndex,
                           let lineOffset = currentTimeOffset {
                            CurrentTimeLine(
                                timeLabelWidth: timeLabelWidth,
                                columnWidth: columnWidth,
                                cellsCount: cells.count,
                                selectedIndex: todayIndex,
                                lineY: lineOffset
                            )
                        }
                    }
                    .frame(width: geometry.size.width, height: contentHeight, alignment: .topLeading)
                }
                .onAppear {
                    proxy.scrollTo(hourID(defaultVisibleHour), anchor: .top)
                }
            }
        }
    }

    private var selectedColumnIndex: Int? {
        guard let selectedDateOnly = DateOnly(from: selectedDate) else { return nil }
        return cells.firstIndex(where: { $0.date == selectedDateOnly })
    }

    private var todayColumnIndex: Int? {
        guard let today = DateOnly(from: Date()) else { return nil }
        return cells.firstIndex(where: { $0.date == today })
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
            ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                ForEach(timedEvents(in: cell), id: \.id) { event in
                    CalendarEventBlockView(
                        event: event,
                        timeText: eventTimeText(for: event),
                        compact: columnWidth < 64
                    )
                    .frame(
                        width: max(0, columnWidth - 6),
                        height: eventHeight(for: event),
                        alignment: .topLeading
                    )
                    .offset(
                        x: CGFloat(index) * columnWidth + 3,
                        y: eventOffset(for: event)
                    )
                }
            }
        }
        .frame(width: columnWidth * CGFloat(cells.count), height: contentHeight, alignment: .topLeading)
    }

    private func gridLines(contentWidth: CGFloat) -> some View {
        Path { path in
            for row in 0...(endHour - startHour) {
                let y = CGFloat(row) * hourHeight
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: contentWidth, y: y))
            }

            for column in 0...cells.count {
                let x = CGFloat(column) * columnWidth
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: contentHeight))
            }
        }
        .stroke(ShiftCalendarColors.separatorColor, lineWidth: 0.5)
        .frame(width: contentWidth, height: contentHeight)
    }

    private func timedEvents(in cell: CalendarDayCell) -> [EventOccurrence] {
        cell.events.filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }
    }

    private func eventOffset(for event: EventOccurrence) -> CGFloat {
        CGFloat(minutesFromStartOfDay(event.startDate)) / 60.0 * hourHeight
    }

    private func eventHeight(for event: EventOccurrence) -> CGFloat {
        let duration = max(15, minutesBetween(event.startDate, event.endDate))
        return max(24, CGFloat(duration) / 60.0 * hourHeight)
    }

    private func eventTimeText(for event: EventOccurrence) -> String {
        if event.isClockInEvent {
            return formatTime(event.workInfo?.workInTime ?? event.startDate)
        }
        if event.isClockOutEvent {
            return formatTime(event.workInfo?.workOutTime ?? event.startDate)
        }
        return "\(formatTime(event.startDate)) - \(formatTime(event.endDate))"
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
        "week-hour-\(hour)"
    }
}

struct CalendarEventBlockView: View {
    let event: EventOccurrence
    let timeText: String
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title)
                .font(.system(size: compact ? 10 : 12, weight: .semibold))
                .foregroundColor(eventForegroundColor)
                .lineLimit(1)

            if !compact {
                Text(timeText)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(eventForegroundColor.opacity(0.90))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(eventColor)
        .cornerRadius(6)
    }

    private var eventColor: Color {
        event.shiftTemplateID?.color ?? ShiftCalendarColors.primaryBlue
    }

    private var eventForegroundColor: Color {
        guard let shiftTemplateID = event.shiftTemplateID else {
            return ShiftCalendarColors.whiteText
        }
        return ShiftDisplayColors.solidForegroundColor(for: shiftTemplateID.color)
    }
}

struct CurrentTimeLine: View {
    let timeLabelWidth: CGFloat
    let columnWidth: CGFloat
    let cellsCount: Int
    let selectedIndex: Int
    let lineY: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: timeLabelWidth + columnWidth * CGFloat(selectedIndex))

            Circle()
                .fill(ShiftCalendarColors.sundayRed)
                .frame(width: 7, height: 7)
                .offset(x: -3.5)

            Rectangle()
                .fill(ShiftCalendarColors.sundayRed)
                .frame(width: columnWidth * CGFloat(cellsCount - selectedIndex) + 3.5, height: 2)
        }
        .offset(y: lineY)
    }
}

// MARK: - Preview

#if DEBUG
private func makePreviewCells() -> [CalendarDayCell] {
    let calendar = Calendar(identifier: .gregorian)
    let today = Date()
    var cells: [CalendarDayCell] = []

    for offset in -3...3 {
        if let date = calendar.date(byAdding: .day, value: offset, to: today) {
            let dateOnly = DateOnly(from: date)!
            let weekdayIndex = (calendar.component(.weekday, from: date) - 1 + 7) % 7

            cells.append(CalendarDayCell(
                id: dateOnly.id,
                date: dateOnly,
                dayText: "\(dateOnly.day)",
                weekdayText: LocalizationManager.preview(languageCode: "ja").shortWeekdaySymbol(for: date),
                holidays: [],
                events: [],
                isToday: offset == 0,
                isWeekend: weekdayIndex == 0 || weekdayIndex == 6,
                isInCurrentMonth: true,
                shiftType: nil,
                eventMarkers: []
            ))
        }
    }
    return cells
}

#Preview {
    WeekCalendarView(
        selectedDate: Date(),
        cells: makePreviewCells(),
        onDateSelected: { _ in }
    )
}
#endif
