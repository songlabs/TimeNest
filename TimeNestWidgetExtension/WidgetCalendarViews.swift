import SwiftUI

struct WidgetMonthGridView: View {
    let snapshot: WidgetSnapshot
    let month: WidgetSnapshotMonth
    let referenceDate: Date
    var showsEventLabel = false
    var compact = false

    var body: some View {
        GeometryReader { proxy in
            let rows = weekRows
            let rowCount = max(rows.count, 1)
            let metrics = gridMetrics
            let rowHeight = calculatedRowHeight(
                availableHeight: proxy.size.height,
                rowCount: rowCount,
                metrics: metrics
            )

            VStack(spacing: metrics.weekdayGridSpacing) {
                HStack(spacing: metrics.columnSpacing) {
                    ForEach(Array(snapshot.weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                        Text(symbol)
                            .font(.system(size: metrics.weekdayFontSize, weight: .semibold))
                            .foregroundStyle(headerColor(at: index))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: metrics.weekdayHeight)

                VStack(spacing: metrics.rowSpacing) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: metrics.columnSpacing) {
                            ForEach(row) { day in
                                Link(destination: TimeNestWidgetDeepLink.url(for: day.date)!) {
                                    dayCell(day, rowHeight: rowHeight, metrics: metrics)
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                                .frame(height: rowHeight)
                            }

                            ForEach(0..<max(0, 7 - row.count), id: \.self) { _ in
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .frame(height: rowHeight)
                            }
                        }
                        .frame(height: rowHeight)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }

    @ViewBuilder
    private func dayCell(
        _ day: WidgetSnapshotDay,
        rowHeight: CGFloat,
        metrics: WidgetMonthGridMetrics
    ) -> some View {
        if showsEventLabel {
            ZStack(alignment: .top) {
                dayNumber(day, metrics: metrics)
                    .frame(maxWidth: .infinity, alignment: .top)

                if let event = day.events.first {
                    WidgetEventTag(event: event, compact: compact, height: eventTagHeight(for: rowHeight, metrics: metrics))
                        .padding(.horizontal, 1)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: rowHeight, alignment: .top)
            .opacity(day.isInDisplayedMonth ? 1 : 0.32)
        } else {
            VStack(spacing: metrics.markerSpacing) {
                dayNumber(day, metrics: metrics)
                eventDots(day, metrics: metrics)
            }
            .frame(maxWidth: .infinity)
            .frame(height: rowHeight, alignment: .center)
            .opacity(day.isInDisplayedMonth ? 1 : 0.32)
        }
    }

    @ViewBuilder
    private func dayNumber(_ day: WidgetSnapshotDay, metrics: WidgetMonthGridMetrics) -> some View {
        ZStack {
            if isToday(day.date) {
                Circle().fill(WidgetStyle.today)
            }
            Text("\(day.day)")
                .font(.system(size: metrics.dayFontSize, weight: isToday(day.date) ? .semibold : .regular))
                .foregroundStyle(dayTextColor(day))
                .minimumScaleFactor(0.75)
        }
        .frame(width: metrics.todaySize, height: metrics.todaySize)
    }

    private func eventDots(_ day: WidgetSnapshotDay, metrics: WidgetMonthGridMetrics) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(day.events.prefix(2))) { event in
                Circle()
                    .fill(Color(widgetHex: event.colorHex))
                    .frame(width: metrics.dotSize, height: metrics.dotSize)
            }
        }
        .frame(height: metrics.dotTrackHeight)
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar(identifier: .gregorian).isDate(date, inSameDayAs: referenceDate)
    }

    private func dayTextColor(_ day: WidgetSnapshotDay) -> Color {
        if isToday(day.date) { return .white }
        return WidgetStyle.weekdayColor(day.weekday)
    }

    private func headerColor(at index: Int) -> Color {
        guard month.days.count >= 7 else { return .secondary }
        return WidgetStyle.weekdayColor(month.days[index].weekday)
    }

    private var weekRows: [[WidgetSnapshotDay]] {
        stride(from: 0, to: month.days.count, by: 7).map { startIndex in
            let endIndex = min(startIndex + 7, month.days.count)
            return Array(month.days[startIndex..<endIndex])
        }
    }

    private var gridMetrics: WidgetMonthGridMetrics {
        WidgetMonthGridMetrics(compact: compact, showsEventLabel: showsEventLabel)
    }

    private func calculatedRowHeight(
        availableHeight: CGFloat,
        rowCount: Int,
        metrics: WidgetMonthGridMetrics
    ) -> CGFloat {
        let verticalSpacing = metrics.weekdayGridSpacing + metrics.rowSpacing * CGFloat(max(rowCount - 1, 0))
        let availableForRows = availableHeight - metrics.weekdayHeight - verticalSpacing
        return max(1, floor(availableForRows / CGFloat(rowCount)))
    }

    private func eventTagHeight(for rowHeight: CGFloat, metrics: WidgetMonthGridMetrics) -> CGFloat {
        min(metrics.eventTagHeight, max(metrics.minimumEventTagHeight, floor(rowHeight * 0.5)))
    }
}

struct WidgetMonthHeader: View {
    let title: String
    var compact = false

    var body: some View {
        Text(title)
            .font(WidgetLayout.monthHeaderFont(compact: compact))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WidgetMonthGridMetrics {
    let columnSpacing = WidgetLayout.MonthGrid.columnSpacing
    let weekdayGridSpacing = WidgetLayout.MonthGrid.weekdayGridSpacing
    let rowSpacing: CGFloat
    let weekdayHeight: CGFloat
    let weekdayFontSize: CGFloat
    let dayFontSize: CGFloat
    let todaySize: CGFloat
    let markerSpacing: CGFloat
    let dotSize: CGFloat
    let dotTrackHeight: CGFloat
    let eventTagHeight: CGFloat
    let minimumEventTagHeight: CGFloat

    init(compact: Bool, showsEventLabel: Bool) {
        rowSpacing = compact ? WidgetLayout.MonthGrid.compactRowSpacing : WidgetLayout.MonthGrid.regularRowSpacing
        weekdayHeight = compact ? WidgetLayout.MonthGrid.compactWeekdayHeight : WidgetLayout.MonthGrid.regularWeekdayHeight
        weekdayFontSize = compact ? WidgetLayout.MonthGrid.compactWeekdayFontSize : WidgetLayout.MonthGrid.regularWeekdayFontSize
        dayFontSize = showsEventLabel && compact
            ? WidgetLayout.MonthGrid.compactEventDayFontSize
            : (compact ? WidgetLayout.MonthGrid.compactDayFontSize : WidgetLayout.MonthGrid.regularDayFontSize)
        todaySize = showsEventLabel && compact
            ? WidgetLayout.MonthGrid.compactEventTodaySize
            : (compact ? WidgetLayout.MonthGrid.compactTodaySize : WidgetLayout.MonthGrid.regularTodaySize)
        markerSpacing = compact ? 0 : 1
        dotSize = compact ? WidgetLayout.MonthGrid.compactDotSize : WidgetLayout.MonthGrid.regularDotSize
        dotTrackHeight = compact ? WidgetLayout.MonthGrid.compactDotTrackHeight : WidgetLayout.MonthGrid.regularDotTrackHeight
        eventTagHeight = compact ? WidgetLayout.MonthGrid.compactEventTagHeight : WidgetLayout.MonthGrid.regularEventTagHeight
        minimumEventTagHeight = compact ? 8 : 10
    }
}
