import SwiftUI

/// 日视图 - 时间轴样式日历
/// 布局结构：
/// 1. 全天事件区域：显示当天全天事件紫色条
/// 2. 时间轴区域：左侧小时刻度列 + 右侧单日内容列 + 当前时间红线
///
/// 列宽计算：
/// - timeLabelWidth: 左侧小时刻度列宽度（固定 52pt）
/// - contentWidth: 容器宽度 - timeLabelWidth
struct DayCalendarView: View {
    @EnvironmentObject private var localization: LocalizationManager
    let selectedDate: Date
    let cell: CalendarDayCell?
    let onTitleTapped: () -> Void

    private let timeLabelWidth: CGFloat = 52  // 左侧小时刻度列固定宽度

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let contentWidth = totalWidth - timeLabelWidth
            let height = geometry.size.height
            let allDayHeight = cell?.events.isEmpty == true && (cell?.shiftType ?? "").isEmpty ? 0 : 60
            let timeAxisHeight = height - CGFloat(allDayHeight)

            VStack(spacing: 0) {
                // 全天事件区域
                if allDayHeight > 0 {
                    AllDayEventsSectionDay(
                        cell: cell,
                        timeLabelWidth: timeLabelWidth,
                        contentWidth: contentWidth
                    )
                    .frame(height: CGFloat(allDayHeight))
                }

                // 时间轴区域
                DayTimeAxisView(
                    cell: cell,
                    timeLabelWidth: timeLabelWidth,
                    contentWidth: contentWidth,
                    timeAxisHeight: timeAxisHeight
                )
                .frame(height: timeAxisHeight)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 全天事件区域（日视图）

struct AllDayEventsSectionDay: View {
    let cell: CalendarDayCell?
    let timeLabelWidth: CGFloat
    let contentWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            // 左侧空白占位列（与小时刻度列对齐）
            Rectangle()
                .fill(Color(red: 0.96, green: 0.96, blue: 0.98))
                .frame(width: timeLabelWidth)

            // 内容区域
            VStack(spacing: 4) {
                // 标题
                Text("全天事件")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ShiftCalendarColors.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                // 事件列表
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // 六曜事件
                        if let shiftType = cell?.shiftType, !shiftType.isEmpty {
                            AllDayEventChip(title: shiftType, isYoho: true)
                        }
                        
                        // 其他全天事件
                        ForEach(cell?.events ?? [], id: \.id) { event in
                            AllDayEventChip(event: event)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                Spacer()
            }
            .frame(width: contentWidth, alignment: .topLeading)
        }
        .background(Color(red: 0.96, green: 0.96, blue: 0.98))
    }
}

struct AllDayEventChip: View {
    let event: EventOccurrence
    let isYoho: Bool

    init(event: EventOccurrence) {
        self.event = event
        self.isYoho = false
    }
    
    init(title: String, isYoho: Bool) {
        self.isYoho = isYoho
        self.event = EventOccurrence(
            id: "yoho_temp",
            eventID: UUID(),
            occurrenceDate: DateOnly(from: Date())!,
            startDate: Date(),
            endDate: nil,
            title: title,
            categoryID: nil
        )
    }

    var body: some View {
        HStack(spacing: 4) {
            // 左侧蓝色竖条
            Rectangle()
                .fill(ShiftCalendarColors.primaryBlue)
                .frame(width: 3, height: 16)
                .cornerRadius(1.5)

            Text(event.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ShiftCalendarColors.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white)
        .cornerRadius(6)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 时间轴区域（日视图）

struct DayTimeAxisView: View {
    let cell: CalendarDayCell?
    let timeLabelWidth: CGFloat
    let contentWidth: CGFloat
    let timeAxisHeight: CGFloat

    private var hourHeight: CGFloat {
        timeAxisHeight / 24.0
    }

    var body: some View {
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

            // 内容区域
            VStack(spacing: 0) {
                // 横向小时网格线
                ForEach(0..<24, id: \.self) { hour in
                    Rectangle()
                        .fill(ShiftCalendarColors.separatorColor)
                        .frame(height: 0.5)
                        .frame(maxWidth: .infinity)
                        .frame(height: hourHeight)
                }
            }
            .frame(width: contentWidth)

            // 当前时间红线（仅在当前日期显示）
            if let cell = cell {
                let today = DateOnly(from: Date())
                let cellDate = cell.date

                if today == cellDate {
                    CurrentTimeLineDay(
                        timeLabelWidth: timeLabelWidth,
                        contentWidth: contentWidth,
                        timeAxisHeight: timeAxisHeight,
                        hourHeight: hourHeight
                    )
                }
            }
        }
    }
}

struct CurrentTimeLineDay: View {
    let timeLabelWidth: CGFloat
    let contentWidth: CGFloat
    let timeAxisHeight: CGFloat
    let hourHeight: CGFloat

    var body: some View {
        let now = Date()
        let components = Calendar.current.dateComponents([.hour, .minute], from: now)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let totalMinutes = hour * 60 + minute
        let lineY = CGFloat(totalMinutes) * hourHeight / 60

        VStack(spacing: 0) {
            Spacer()
                .frame(height: lineY)

            HStack(spacing: 0) {
                // 左侧空白（跳过小时刻度列）
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: timeLabelWidth)

                // 时间指示器圆点（在内容列左边界）
                Circle()
                    .fill(ShiftCalendarColors.sundayRed)
                    .frame(width: 6, height: 6)

                // 红线（贯穿整个内容区域）
                Rectangle()
                    .fill(ShiftCalendarColors.sundayRed)
                    .frame(height: 2)
                    .frame(width: contentWidth)

                // 当前时间文本
                Text(String(format: "%02d:%02d", hour, minute))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(ShiftCalendarColors.sundayRed)
                    .padding(.leading, 4)
            }
            .frame(height: 2)

            Spacer()
        }
        .frame(height: timeAxisHeight)
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
        shiftType: "先勝",
        eventMarkers: []
    )
}

#Preview {
    DayCalendarView(
        selectedDate: Date(),
        cell: makePreviewCell(),
        onTitleTapped: {}
    )
    .environmentObject(LocalizationManager.preview(languageCode: "ja"))
}
#endif
