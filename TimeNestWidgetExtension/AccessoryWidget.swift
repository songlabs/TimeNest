import SwiftUI
import WidgetKit

struct TimeNestAccessoryWidget: Widget {
    let kind = "TimeNestAccessoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimeNestTimelineProvider()) { entry in
            AccessoryWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(TimeNestWidgetDeepLink.url(for: entry.date))
        }
        .configurationDisplayName("widget.accessory.title")
        .description("widget.accessory.description")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

private struct AccessoryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TimeNestWidgetEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(inlineSummary)
        case .accessoryCircular:
            VStack(spacing: 1) {
                Text(entry.snapshot.dateText(for: entry.date, format: "d"))
                    .font(.title2.weight(.bold))
                if let shift = entry.snapshot.todayShift {
                    Text(shift.title)
                        .font(.system(size: 8, weight: .semibold))
                        .lineLimit(1)
                } else {
                    HStack(spacing: 2) {
                        ForEach(Array(entry.snapshot.todayEvents.prefix(3))) { event in
                            Circle().fill(.primary).frame(width: 3, height: 3)
                        }
                    }
                }
            }
            .widgetAccentable()
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.snapshot.dateText(for: entry.date, format: "M/d (E)"))
                    .font(.headline)
                Text(primarySummary)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                if let secondary = secondaryEvent {
                    Text(eventSummary(secondary))
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            EmptyView()
        }
    }

    private var inlineSummary: String {
        if let shift = entry.snapshot.todayShift {
            return "\(WidgetL10n.text("widget.today", snapshot: entry.snapshot)) \(shift.title) \(timeRange(shift))"
                .trimmingCharacters(in: .whitespaces)
        }
        if let event = entry.snapshot.upcomingEvents.first {
            return "\(WidgetL10n.text("widget.nextEvent", snapshot: entry.snapshot)) \(eventSummary(event))"
        }
        return WidgetL10n.text("widget.noEventsToday", snapshot: entry.snapshot)
    }

    private var primarySummary: String {
        if let shift = entry.snapshot.todayShift { return eventSummary(shift) }
        if let holiday = entry.snapshot.todayHoliday { return holiday.title }
        if let event = entry.snapshot.upcomingEvents.first { return eventSummary(event) }
        return WidgetL10n.text("widget.noEventsToday", snapshot: entry.snapshot)
    }

    private var secondaryEvent: WidgetSnapshotEvent? {
        let primaryID = entry.snapshot.todayShift?.id
            ?? entry.snapshot.todayHoliday?.id
            ?? entry.snapshot.upcomingEvents.first?.id
        return entry.snapshot.upcomingEvents.first { $0.id != primaryID }
    }

    private func eventSummary(_ event: WidgetSnapshotEvent) -> String {
        let time = event.isAllDay
            ? WidgetL10n.text("widget.allDay", snapshot: entry.snapshot)
            : timeRange(event)
        return "\(time) \(event.title)".trimmingCharacters(in: .whitespaces)
    }

    private func timeRange(_ event: WidgetSnapshotEvent) -> String {
        [event.startText, event.endText].compactMap { $0 }.joined(separator: "-")
    }
}
