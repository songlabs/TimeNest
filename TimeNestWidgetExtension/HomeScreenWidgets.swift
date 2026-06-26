import SwiftUI
import WidgetKit

struct TimeNestMonthWidget: Widget {
    let kind = "TimeNestMonthWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimeNestTimelineProvider()) { entry in
            MonthWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("widget.calendar.title")
        .description("widget.calendar.description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct MonthWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TimeNestWidgetEntry

    var body: some View {
        if let month = entry.snapshot.displayedMonth(at: entry.date) {
            VStack(spacing: WidgetLayout.titleSpacing(for: family)) {
                WidgetMonthHeader(title: month.title, compact: family != .systemLarge)
                WidgetMonthGridView(
                    snapshot: entry.snapshot,
                    month: month,
                    referenceDate: entry.date,
                    compact: family != .systemLarge
                )
            }
            .padding(WidgetLayout.contentPadding(for: family))
            .widgetURL(TimeNestWidgetDeepLink.url(for: entry.date))
        }
    }
}

struct TimeNestMonthScheduleWidget: Widget {
    let kind = "TimeNestMonthScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimeNestTimelineProvider()) { entry in
            MonthScheduleWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("widget.monthSchedule.title")
        .description("widget.monthSchedule.description")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct MonthScheduleWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TimeNestWidgetEntry

    var body: some View {
        if let month = entry.snapshot.displayedMonth(at: entry.date) {
            VStack(spacing: WidgetLayout.titleSpacing(for: family)) {
                WidgetMonthHeader(title: month.title, compact: family == .systemMedium)
                WidgetMonthGridView(
                    snapshot: entry.snapshot,
                    month: month,
                    referenceDate: entry.date,
                    showsEventLabel: true,
                    compact: family == .systemMedium
                )
            }
            .padding(WidgetLayout.contentPadding(for: family))
            .widgetURL(TimeNestWidgetDeepLink.url(for: entry.date))
        }
    }
}

struct TimeNestTwoMonthsWidget: Widget {
    let kind = "TimeNestTwoMonthsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimeNestTimelineProvider()) { entry in
            TwoMonthsWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("widget.twoMonths.title")
        .description("widget.twoMonths.description")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct TwoMonthsWidgetView: View {
    let entry: TimeNestWidgetEntry

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(entry.snapshot.months.prefix(2).enumerated()), id: \.element.id) { index, month in
                if index > 0 { Divider() }
                VStack(spacing: 5) {
                    Text(month.title)
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    WidgetMonthGridView(
                        snapshot: entry.snapshot,
                        month: month,
                        referenceDate: entry.date,
                        compact: true
                    )
                }
            }
        }
        .padding(12)
        .widgetURL(TimeNestWidgetDeepLink.url(for: entry.date))
    }
}

struct TimeNestWeekScheduleWidget: Widget {
    let kind = "TimeNestWeekScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimeNestTimelineProvider()) { entry in
            WeekScheduleWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("widget.weekSchedule.title")
        .description("widget.weekSchedule.description")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct WeekScheduleWidgetView: View {
    let entry: TimeNestWidgetEntry
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 10) {
            WidgetMonthHeader(title: entry.snapshot.dateText(for: entry.date, format: "yyyy MMMM"))
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekDates, id: \.self) { date in
                    Link(destination: TimeNestWidgetDeepLink.url(for: date)!) {
                        VStack(spacing: 5) {
                            Text(entry.snapshot.dateText(for: date, format: "E"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(WidgetStyle.weekdayColor(calendar.component(.weekday, from: date)))
                            Text(entry.snapshot.dateText(for: date, format: "d"))
                                .font(.callout.weight(isToday(date) ? .bold : .regular))
                                .foregroundStyle(isToday(date) ? .white : .primary)
                                .frame(width: 26, height: 26)
                                .background(isToday(date) ? WidgetStyle.today : .clear, in: Circle())
                            if let event = event(on: date) {
                                WidgetEventTag(event: event)
                            } else {
                                Spacer(minLength: 17)
                            }
                        }
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity, minHeight: 92, alignment: .top)
                        .background(isToday(date) ? WidgetStyle.secondaryFill : .clear, in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
    }

    private var calendar: Calendar { Calendar(identifier: .gregorian) }

    private var weekDates: [Date] {
        let firstWeekday: Int
        switch entry.snapshot.weekStartPolicy {
        case "sunday": firstWeekday = 1
        case "monday": firstWeekday = 2
        case "saturday": firstWeekday = 7
        default: firstWeekday = Calendar.current.firstWeekday
        }
        let start = calendar.startOfDay(for: entry.date)
        let offset = (calendar.component(.weekday, from: start) - firstWeekday + 7) % 7
        let weekStart = calendar.date(byAdding: .day, value: -offset, to: start) ?? start
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private func event(on date: Date) -> WidgetSnapshotEvent? {
        entry.snapshot.weekEvents.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: entry.date)
    }
}

struct TimeNestUpcomingWidget: Widget {
    let kind = "TimeNestUpcomingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimeNestTimelineProvider()) { entry in
            UpcomingWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("widget.upcoming.title")
        .description("widget.upcoming.description")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct UpcomingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TimeNestWidgetEntry

    var body: some View {
        HStack(spacing: WidgetLayout.upcomingColumnSpacing) {
            VStack(alignment: .leading, spacing: 7) {
                Text(WidgetL10n.text("widget.upcoming.title", snapshot: entry.snapshot))
                    .font(WidgetLayout.titleFont(for: family))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if entry.snapshot.upcomingEvents.isEmpty {
                    Text(WidgetL10n.text("widget.noEventsToday", snapshot: entry.snapshot))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(entry.snapshot.upcomingEvents.prefix(upcomingEventLimit))) { event in
                        Link(destination: TimeNestWidgetDeepLink.url(for: event.date)!) {
                            HStack(alignment: .top, spacing: 6) {
                                Capsule()
                                    .fill(Color(widgetHex: event.colorHex))
                                    .frame(width: 3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.snapshot.relativeDateText(for: event.date, relativeTo: entry.date))
                                        .font(.caption2.weight(.semibold))
                                        .lineLimit(1)
                                    Text(eventTime(event))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Text(event.title)
                                        .font(.caption.weight(.medium))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                }
                                .layoutPriority(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let month = entry.snapshot.displayedMonth(at: entry.date) {
                WidgetMonthGridView(
                    snapshot: entry.snapshot,
                    month: month,
                    referenceDate: entry.date,
                    compact: true
                )
                .frame(width: family == .systemMedium ? WidgetLayout.upcomingCalendarMediumWidth : nil)
                .frame(maxWidth: family == .systemMedium ? nil : .infinity)
            }
        }
        .padding(WidgetLayout.contentPadding(for: family))
    }

    private var upcomingEventLimit: Int {
        family == .systemMedium ? WidgetLayout.mediumUpcomingEventLimit : WidgetLayout.defaultUpcomingEventLimit
    }

    private func eventTime(_ event: WidgetSnapshotEvent) -> String {
        if event.isAllDay { return WidgetL10n.text("widget.allDay", snapshot: entry.snapshot) }
        return [event.startText, event.endText].compactMap { $0 }.joined(separator: "-")
    }
}
