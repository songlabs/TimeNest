import SwiftUI
import WidgetKit

struct TimeNestWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TimeNestTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimeNestWidgetEntry {
        TimeNestWidgetEntry(date: Date(), snapshot: .empty())
    }

    func getSnapshot(in context: Context, completion: @escaping (TimeNestWidgetEntry) -> Void) {
        completion(TimeNestWidgetEntry(date: Date(), snapshot: WidgetSnapshotStore.load() ?? .empty()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimeNestWidgetEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSnapshotStore.load() ?? .empty(at: now)
        let calendar = Calendar(identifier: .gregorian)
        let nextRefresh = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(60 * 60)
        completion(Timeline(entries: [TimeNestWidgetEntry(date: now, snapshot: snapshot)], policy: .after(nextRefresh)))
    }
}

enum WidgetL10n {
    static func text(_ key: String, snapshot: WidgetSnapshot) -> String {
        let languageName: String
        switch snapshot.languageCode {
        case "zhHans": languageName = "zh-Hans"
        case "zh-Hant": languageName = "zh-Hant"
        case "ja": languageName = "ja"
        case "ko": languageName = "ko"
        case "enUS": languageName = "en"
        default:
            let systemCode = Locale.current.language.languageCode?.identifier ?? "en"
            languageName = systemCode == "zh" ? systemChineseBundleName() : systemCode
        }

        guard let path = Bundle.main.path(forResource: languageName, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, bundle: .main, comment: "")
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }

    static func locale(for snapshot: WidgetSnapshot) -> Locale {
        switch snapshot.languageCode {
        case "zhHans": return Locale(identifier: "zh_Hans_CN")
        case "zh-Hant": return Locale(identifier: "zh_Hant_TW")
        case "ja": return Locale(identifier: "ja_JP")
        case "ko": return Locale(identifier: "ko_KR")
        case "enUS": return Locale(identifier: "en_US")
        default: return .current
        }
    }

    private static func systemChineseBundleName() -> String {
        let identifier = Locale.current.identifier.lowercased()
        return identifier.contains("hant") || identifier.contains("_tw") || identifier.contains("_hk") || identifier.contains("_mo")
            ? "zh-Hant"
            : "zh-Hans"
    }
}

enum WidgetStyle {
    static let today = Color(red: 0.05, green: 0.39, blue: 0.78)
    static let sunday = Color(red: 1.0, green: 0.27, blue: 0.27)
    static let saturday = Color(red: 0.17, green: 0.45, blue: 0.91)
    static let secondaryFill = Color.primary.opacity(0.055)

    static func weekdayColor(_ weekday: Int) -> Color {
        if weekday == 1 { return sunday }
        if weekday == 7 { return saturday }
        return .primary
    }
}

enum WidgetLayout {
    static let mediumPadding = EdgeInsets(top: 15, leading: 16, bottom: 13, trailing: 16)
    static let smallPadding = EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
    static let largePadding = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    static let mediumTitleSpacing: CGFloat = 5
    static let largeTitleSpacing: CGFloat = 8
    static let mediumWidgetTitleFontSize: CGFloat = 15
    static let compactMonthTitleFontSize: CGFloat = 14
    static let upcomingColumnSpacing: CGFloat = 12
    static let mediumUpcomingEventLimit = 2
    static let defaultUpcomingEventLimit = 3
    static let upcomingCalendarMediumWidth: CGFloat = 148

    static func contentPadding(for family: WidgetFamily) -> EdgeInsets {
        switch family {
        case .systemSmall:
            return smallPadding
        case .systemMedium:
            return mediumPadding
        default:
            return largePadding
        }
    }

    static func titleSpacing(for family: WidgetFamily) -> CGFloat {
        family == .systemLarge ? largeTitleSpacing : mediumTitleSpacing
    }

    static func titleFont(for family: WidgetFamily) -> Font {
        family == .systemLarge ? .headline.weight(.bold) : .system(size: mediumWidgetTitleFontSize, weight: .bold)
    }

    static func monthHeaderFont(compact: Bool) -> Font {
        compact ? .system(size: compactMonthTitleFontSize, weight: .bold) : .headline.weight(.bold)
    }

    enum MonthGrid {
        static let columnSpacing: CGFloat = 1
        static let weekdayGridSpacing: CGFloat = 2
        static let compactRowSpacing: CGFloat = 1
        static let regularRowSpacing: CGFloat = 2
        static let compactWeekdayHeight: CGFloat = 10
        static let regularWeekdayHeight: CGFloat = 12
        static let compactWeekdayFontSize: CGFloat = 8
        static let regularWeekdayFontSize: CGFloat = 10
        static let compactDayFontSize: CGFloat = 10
        static let regularDayFontSize: CGFloat = 12
        static let compactEventDayFontSize: CGFloat = 9
        static let compactTodaySize: CGFloat = 17
        static let regularTodaySize: CGFloat = 22
        static let compactEventTodaySize: CGFloat = 15
        static let compactDotSize: CGFloat = 2.5
        static let regularDotSize: CGFloat = 3.5
        static let compactDotTrackHeight: CGFloat = 3
        static let regularDotTrackHeight: CGFloat = 4
        static let compactEventTagHeight: CGFloat = 10
        static let regularEventTagHeight: CGFloat = 14
        static let compactEventTagFontSize: CGFloat = 7
        static let regularEventTagFontSize: CGFloat = 8
    }
}

extension Color {
    init(widgetHex value: String) {
        let hex = value.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var integer: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&integer)
        let red = Double((integer >> 16) & 0xFF) / 255
        let green = Double((integer >> 8) & 0xFF) / 255
        let blue = Double(integer & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

extension WidgetSnapshot {
    func displayedMonth(at date: Date) -> WidgetSnapshotMonth? {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return months.first { $0.year == year && $0.month == month } ?? months.first
    }

    func dateText(for date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = WidgetL10n.locale(for: self)
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    func relativeDateText(for date: Date, relativeTo now: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        if calendar.isDate(date, inSameDayAs: now) {
            return WidgetL10n.text("widget.today", snapshot: self)
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return WidgetL10n.text("widget.tomorrow", snapshot: self)
        }
        return dateText(for: date, format: "M/d (E)")
    }
}

struct WidgetEventTag: View {
    let event: WidgetSnapshotEvent
    var compact = false
    var height: CGFloat? = nil

    private var resolvedHeight: CGFloat {
        height ?? (compact ? WidgetLayout.MonthGrid.compactEventTagHeight : WidgetLayout.MonthGrid.regularEventTagHeight)
    }

    private var fontSize: CGFloat {
        compact ? WidgetLayout.MonthGrid.compactEventTagFontSize : WidgetLayout.MonthGrid.regularEventTagFontSize
    }

    var body: some View {
        HStack(spacing: compact ? 2 : 3) {
            Capsule()
                .fill(Color(widgetHex: event.colorHex))
                .frame(width: compact ? 2.5 : 3, height: max(4, resolvedHeight - 4))
            Text(event.title)
                .font(.system(size: fontSize, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, compact ? 2 : 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: resolvedHeight)
        .background(Color(widgetHex: event.colorHex).opacity(0.14), in: RoundedRectangle(cornerRadius: 3))
    }
}
