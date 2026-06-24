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

    var body: some View {
        HStack(spacing: 3) {
            Capsule()
                .fill(Color(widgetHex: event.colorHex))
                .frame(width: 3)
            Text(event.title)
                .font(.system(size: 8, weight: .medium))
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(widgetHex: event.colorHex).opacity(0.14), in: RoundedRectangle(cornerRadius: 3))
    }
}
