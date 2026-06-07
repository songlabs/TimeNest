import SwiftUI

/// 周视图 - 时间轴样式日历
/// 布局结构（使用 GeometryReader 统一计算宽度）：
/// 1. 日期 header：左侧空白占位列 + 7 列日期（7 日/8 日/...）
/// 2. 全天事件区域：左侧空白占位列 + 7 列全天事件条
/// 3. 时间轴区域：左侧小时刻度列 + 7 列时间网格
///
/// 列宽计算：
/// - timeLabelWidth: 左侧小时刻度列宽度（固定 52pt）
/// - columnWidth: (容器宽度 - timeLabelWidth) / 显示天数
/// - 所有区域共享同一组宽度计算
struct WeekCalendarView: View {
    @EnvironmentObject private var localization: LocalizationManager
    let selectedDate: Date
    let displayDays: Int  // 7, 5, 或 3
    let cells: [CalendarDayCell]
    let onDateSelected: (Date) -> Void
    let onTitleTapped: () -> Void

    private let timeLabelWidth: CGFloat = 52  // 左侧小时刻度列固定宽度

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let displayCellCount = displayCells.count
            let availableWidth = totalWidth - timeLabelWidth
            let columnWidth = availableWidth / CGFloat(displayCellCount)

            VStack(spacing: 0) {
                // 日期 header 行
                WeekDateHeaderView(
                    cells: displayCells,
                    timeLabelWidth: timeLabelWidth,
                    columnWidth: columnWidth,
                    selectedDate: selectedDate
                )
                .frame(height: 32)

                // 全天事件区域
                AllDayEventsSection(
                    cells: displayCells,
                    timeLabelWidth: timeLabelWidth,
                    columnWidth: columnWidth,
                    selectedDate: selectedDate
                )
                .frame(height: 60)

                // 时间轴区域
                WeekTimeAxisView(
                    cells: displayCells,
                    timeLabelWidth: timeLabelWidth,
                    columnWidth: columnWidth,
                    selectedDate: selectedDate
                )
                .frame(height: geometry.size.height - 32 - 60)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var displayCells: [CalendarDayCell] {
        if displayDays == 7 {
            return cells
        } else {
            // 5 日/3 日视图：居中显示
            let centerIndex = cells.count / 2
            let halfCount = displayDays / 2
            let startIndex = max(0, centerIndex - halfCount)
            let endIndex = min(cells.count, startIndex + displayDays)
            return Array(cells[startIndex..<endIndex])
        }
    }
}

// MARK: - 日期 Header 行

struct WeekDateHeaderView: View {
    let cells: [CalendarDayCell]
    let timeLabelWidth: CGFloat
    let columnWidth: CGFloat
    let selectedDate: Date

    var body: some View {
        HStack(spacing: 0) {
            // 左侧空白占位列（与小时刻度列对齐）
            Rectangle()
                .fill(ShiftCalendarColors.primaryBlue)
                .frame(width: timeLabelWidth, height: 32)

            // 日期列
            ForEach(cells, id: \.id) { cell in
                WeekDateHeaderCell(
                    cell: cell,
                    columnWidth: columnWidth,
                    isSelected: isDateSelected(cell.date)
                )
                .frame(width: columnWidth, height: 32)
            }

            // 如果显示天数少于 7 天，添加空占位
            let emptyCount = 7 - cells.count
            ForEach(0..<emptyCount, id: \.self) { _ in
                Rectangle()
                    .fill(ShiftCalendarColors.primaryBlue)
                    .frame(width: columnWidth, height: 32)
            }
        }
        .background(ShiftCalendarColors.primaryBlue)
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
        VStack(spacing: 2) {
            // 日期数字
            Text(cell.dayText)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? ShiftCalendarColors.primaryBlue : .white)

            // 星期
            Text(cell.weekdayText)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(weekdayTextColor)
        }
        .frame(width: columnWidth, height: 32)
        .background(isSelected ? ShiftCalendarColors.primaryBlue.opacity(0.15) : Color.clear)
    }

    private var weekdayTextColor: Color {
        if !cell.holidays.isEmpty {
            return ShiftCalendarColors.sundayRed
        }
        if cell.isWeekend {
            if isSunday(weekdayText: cell.weekdayText) {
                return ShiftCalendarColors.sundayRed
            }
            if isSaturday(weekdayText: cell.weekdayText) {
                return ShiftCalendarColors.saturdayBlue
            }
        }
        return .white
    }

    private func isSunday(weekdayText: String) -> Bool {
        ["日", "Sun", "Sunday", "일", "dom"].contains(weekdayText)
    }

    private func isSaturday(weekdayText: String) -> Bool {
        ["土", "Sat", "Saturday", "토", "sab"].contains(weekdayText)
    }
}

// MARK: - 全天事件区域

struct AllDayEventsSection: View {
    let cells: [CalendarDayCell]
    let timeLabelWidth: CGFloat
    let columnWidth: CGFloat
    let selectedDate: Date

    var body: some View {
        HStack(spacing: 0) {
            // 左侧空白占位列（与小时刻度列对齐）
            Rectangle()
                .fill(ShiftCalendarColors.backgroundColor)
                .frame(width: timeLabelWidth)

            // 日期列
            ForEach(cells, id: \.id) { cell in
                AllDayEventsColumn(
                    cell: cell,
                    columnWidth: columnWidth,
                    isSelected: isDateSelected(cell.date)
                )
                .frame(width: columnWidth)
            }

            // 空占位
            let emptyCount = 7 - cells.count
            ForEach(0..<emptyCount, id: \.self) { _ in
                Rectangle()
                    .fill(ShiftCalendarColors.backgroundColor)
                    .frame(width: columnWidth)
            }
        }
        .background(ShiftCalendarColors.backgroundColor)
    }

    private func isDateSelected(_ dateOnly: DateOnly) -> Bool {
        guard let selectedDateOnly = DateOnly(from: selectedDate) else {
            return false
        }
        return dateOnly == selectedDateOnly
    }
}

struct AllDayEventsColumn: View {
    let cell: CalendarDayCell
    let columnWidth: CGFloat
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            // 全天事件条（包括六曜如"先勝"）
            if !cell.events.isEmpty || !cell.holidays.isEmpty {
                ForEach(displayEvents, id: \.id) { event in
                    AllDayEventBar(event: event, columnWidth: columnWidth - 8)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .background(isSelected ? ShiftCalendarColors.primaryBlue.opacity(0.08) : Color.clear)
    }

    private var displayEvents: [EventOccurrence] {
        // 将六曜作为特殊事件显示
        var events = cell.events
        // 如果有六曜信息，添加到事件列表
        if let shiftType = cell.shiftType, !shiftType.isEmpty {
            // 创建六曜事件
            let yokoEvent = EventOccurrence(
                id: "yoho_\(cell.date.id)",
                eventID: UUID(),
                occurrenceDate: cell.date,
                startDate: cell.date.toDate(),
                endDate: nil,
                title: shiftType,
                categoryID: nil
            )
            events.insert(yokoEvent, at: 0)
        }
        return Array(events.prefix(3))
    }
}

struct AllDayEventBar: View {
    let event: EventOccurrence
    let columnWidth: CGFloat

    var body: some View {
        Text(event.title)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(ShiftCalendarColors.primaryBlue.opacity(0.85))
            .cornerRadius(4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 时间轴区域

struct WeekTimeAxisView: View {
    let cells: [CalendarDayCell]
    let timeLabelWidth: CGFloat
    let columnWidth: CGFloat
    let selectedDate: Date

    private var timeAxisHeight: CGFloat {
        // 由父视图控制高度
        0
    }

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let hourHeight = height / 24.0

            ZStack(alignment: .topLeading) {
                // 背景
                Rectangle()
                    .fill(ShiftCalendarColors.backgroundColor)

                // 左侧小时刻度列
                HStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text("\(hour)")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(ShiftCalendarColors.secondaryText)
                            .frame(width: timeLabelWidth - 8, alignment: .trailing)
                            .padding(.trailing, 4)
                            .frame(height: hourHeight)
                    }
                }
                .frame(width: timeLabelWidth, alignment: .trailing)

                // 日期列区域
                HStack(spacing: 0) {
                    // 纵向日期分隔线
                    ForEach(0..<cells.count, id: \.self) { index in
                        Rectangle()
                            .fill(ShiftCalendarColors.separatorColor)
                            .frame(width: 0.5, height: height)

                        // 选中日期列背景
                        if let selectedIndex = cells.firstIndex(where: { isDateSelected($0.date) }),
                           index == selectedIndex {
                            Rectangle()
                                .fill(ShiftCalendarColors.primaryBlue.opacity(0.05))
                                .frame(width: columnWidth, height: height)
                        }
                    }

                    // 横向小时网格线
                    VStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { hour in
                            HStack(spacing: 0) {
                                // 横向网格线
                                Rectangle()
                                    .fill(ShiftCalendarColors.separatorColor)
                                    .frame(height: 0.5)
                                    .frame(maxWidth: .infinity)
                            }
                            .frame(height: hourHeight)
                        }
                    }
                    .frame(width: columnWidth * CGFloat(cells.count))
                }

                // 当前时间红线（仅在当前日期显示）
                if let today = DateOnly(from: Date()),
                   let selectedIndex = cells.firstIndex(where: { $0.date == today }) {
                    CurrentTimeLine(
                        timeLabelWidth: timeLabelWidth,
                        columnWidth: columnWidth,
                        cellsCount: cells.count,
                        hourHeight: hourHeight,
                        selectedIndex: selectedIndex
                    )
                }
            }
        }
    }

    private func isDateSelected(_ dateOnly: DateOnly) -> Bool {
        guard let selectedDateOnly = DateOnly(from: selectedDate) else {
            return false
        }
        return dateOnly == selectedDateOnly
    }
}

struct CurrentTimeLine: View {
    let timeLabelWidth: CGFloat
    let columnWidth: CGFloat
    let cellsCount: Int
    let hourHeight: CGFloat
    let selectedIndex: Int

    var body: some View {
        let now = Date()
        let components = Calendar.current.dateComponents([.hour, .minute], from: now)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let totalMinutes = hour * 60 + minute
        let lineHeight = CGFloat(totalMinutes) * hourHeight / 60
        let lineY = CGFloat(totalMinutes) * hourHeight / 60

        VStack(spacing: 0) {
            Spacer()
                .frame(height: lineY)

            HStack(spacing: 0) {
                // 左侧空白（跳过小时刻度列）
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: timeLabelWidth)

                // 左侧空白（跳过前面的日期列）
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: columnWidth * CGFloat(selectedIndex))

                // 时间指示器圆点（在日期列左边界）
                Circle()
                    .fill(ShiftCalendarColors.sundayRed)
                    .frame(width: 6, height: 6)

                // 红线（贯穿当前日期列到最后一列）
                Rectangle()
                    .fill(ShiftCalendarColors.sundayRed)
                    .frame(height: 2)
                    .frame(width: columnWidth * CGFloat(cellsCount - selectedIndex))
            }
            .frame(height: 2)

            // 剩余空间
            Spacer()
        }
        .frame(height: hourHeight * 24)
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

            // 为今天添加六曜和事件
            var shiftType: String? = nil
            var events: [EventOccurrence] = []
            if offset == 0 {
                shiftType = "先勝"
                events = [
                    EventOccurrence(
                        id: "test_event_1",
                        eventID: UUID(),
                        occurrenceDate: dateOnly,
                        startDate: date,
                        endDate: nil,
                        title: "测试事件",
                        categoryID: nil
                    )
                ]
            }

            cells.append(CalendarDayCell(
                id: dateOnly.id,
                date: dateOnly,
                dayText: "\(dateOnly.day)",
                weekdayText: weekdaySymbols[weekdayIndex],
                holidays: [],
                events: events,
                isToday: offset == 0,
                isWeekend: weekdayIndex == 0 || weekdayIndex == 6,
                isInCurrentMonth: true,
                shiftType: shiftType,
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
