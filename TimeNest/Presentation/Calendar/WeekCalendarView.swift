import SwiftUI

/// 周视图 - 浅色时间轴样式日历
struct WeekCalendarView: View {
    @EnvironmentObject private var localization: LocalizationManager
    let selectedDate: Date
    let displayDays: Int  // 7, 5, 或 3
    let cells: [CalendarDayCell]
    let onDateSelected: (Date) -> Void
    let onTitleTapped: () -> Void

    private let timeLabelWidth: CGFloat = 52
    private let dateHeaderHeight: CGFloat = 72

    var body: some View {
        GeometryReader { geometry in
            let displayCellCount = max(displayCells.count, 1)
            let columnWidth = (geometry.size.width - timeLabelWidth) / CGFloat(displayCellCount)

            VStack(spacing: 0) {
                WeekDateHeaderView(
                    cells: displayCells,
                    timeLabelWidth: timeLabelWidth,
                    columnWidth: columnWidth,
                    selectedDate: selectedDate,
                    onDateSelected: onDateSelected
                )
                .frame(height: dateHeaderHeight)

                WeekTimeAxisView(
                    cells: displayCells,
                    timeLabelWidth: timeLabelWidth,
                    columnWidth: columnWidth,
                    selectedDate: selectedDate
                )
                .frame(height: max(0, geometry.size.height - dateHeaderHeight))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ShiftCalendarColors.backgroundColor)
    }

    private var displayCells: [CalendarDayCell] {
        guard displayDays != 7 else { return cells }

        if let selectedDateOnly = DateOnly(from: selectedDate),
           let selectedIndex = cells.firstIndex(where: { $0.date == selectedDateOnly }) {
            let halfCount = displayDays / 2
            let startIndex = min(max(0, selectedIndex - halfCount), max(0, cells.count - displayDays))
            let endIndex = min(cells.count, startIndex + displayDays)
            return Array(cells[startIndex..<endIndex])
        }

        let centerIndex = cells.count / 2
        let halfCount = displayDays / 2
        let startIndex = min(max(0, centerIndex - halfCount), max(0, cells.count - displayDays))
        let endIndex = min(cells.count, startIndex + displayDays)
        return Array(cells[startIndex..<endIndex])
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
        .frame(width: columnWidth, maxHeight: .infinity)
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
        if isSunday(weekdayText: cell.weekdayText) {
            return ShiftCalendarColors.sundayRed
        }
        if isSaturday(weekdayText: cell.weekdayText) {
            return ShiftCalendarColors.saturdayBlue
        }
        return nil
    }

    private func isSunday(weekdayText: String) -> Bool {
        ["日", "Sun", "Sunday", "일", "dom"].contains(weekdayText)
    }

    private func isSaturday(weekdayText: String) -> Bool {
        ["土", "Sat", "Saturday", "토", "sab"].contains(weekdayText)
    }
}

// MARK: - 时间轴区域

struct WeekTimeAxisView: View {
    let cells: [CalendarDayCell]
    let timeLabelWidth: CGFloat
    let columnWidth: CGFloat
    let selectedDate: Date

    private let startHour = 9
    private let endHour = 17
    private var hourCount: Int { endHour - startHour + 1 }

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let contentWidth = columnWidth * CGFloat(cells.count)
            let rowHeight = height / CGFloat(hourCount)

            ZStack(alignment: .topLeading) {
                ShiftCalendarColors.backgroundColor

                if let selectedIndex = selectedColumnIndex {
                    Rectangle()
                        .fill(ShiftCalendarColors.primaryBlue.opacity(0.08))
                        .frame(width: columnWidth, height: height)
                        .offset(x: timeLabelWidth + columnWidth * CGFloat(selectedIndex))
                }

                timeLabels(rowHeight: rowHeight)
                    .frame(width: timeLabelWidth, height: height, alignment: .topLeading)

                gridLines(contentWidth: contentWidth, height: height, rowHeight: rowHeight)
                    .offset(x: timeLabelWidth)

                if let todayIndex = todayColumnIndex,
                   let lineOffset = currentTimeOffset(rowHeight: rowHeight) {
                    CurrentTimeLine(
                        timeLabelWidth: timeLabelWidth,
                        columnWidth: columnWidth,
                        cellsCount: cells.count,
                        selectedIndex: todayIndex,
                        lineY: lineOffset
                    )
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

    private func currentTimeOffset(rowHeight: CGFloat) -> CGFloat? {
        let components = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        guard hour >= startHour, hour <= endHour else { return nil }
        return (CGFloat(hour - startHour) + CGFloat(minute) / 60.0) * rowHeight
    }

    private func timeLabels(rowHeight: CGFloat) -> some View {
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

    private func gridLines(contentWidth: CGFloat, height: CGFloat, rowHeight: CGFloat) -> some View {
        Path { path in
            for row in 0...hourCount {
                let y = CGFloat(row) * rowHeight
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: contentWidth, y: y))
            }

            for column in 0...cells.count {
                let x = CGFloat(column) * columnWidth
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: height))
            }
        }
        .stroke(ShiftCalendarColors.separatorColor, lineWidth: 0.5)
        .frame(width: contentWidth, height: height)
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
            let weekdayIndex = Calendar.current.component(.weekday, from: date) - 1
            let weekdaySymbols = LocalizationManager.shared.shortWeekdaySymbols(weekStartPolicy: .sunday)

            cells.append(CalendarDayCell(
                id: dateOnly.id,
                date: dateOnly,
                dayText: "\(dateOnly.day)",
                weekdayText: weekdaySymbols[weekdayIndex],
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
        displayDays: 7,
        cells: makePreviewCells(),
        onDateSelected: { _ in },
        onTitleTapped: {}
    )
    .environmentObject(LocalizationManager.preview(languageCode: "ja"))
}
#endif
