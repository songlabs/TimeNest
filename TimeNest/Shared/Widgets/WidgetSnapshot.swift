import Foundation

enum WidgetSnapshotEventKind: String, Codable {
    case event
    case shift
    case holiday
}

struct WidgetSnapshotEvent: Identifiable, Codable, Hashable {
    let id: String
    let date: Date
    let title: String
    let kind: WidgetSnapshotEventKind
    let colorHex: String
    let isAllDay: Bool
    let startText: String?
    let endText: String?
}

struct WidgetSnapshotDay: Identifiable, Codable, Hashable {
    let id: String
    let date: Date
    let day: Int
    let weekday: Int
    let isInDisplayedMonth: Bool
    let isToday: Bool
    let events: [WidgetSnapshotEvent]

    var hasShift: Bool { events.contains { $0.kind == .shift } }
    var hasHoliday: Bool { events.contains { $0.kind == .holiday } }
}

struct WidgetSnapshotMonth: Identifiable, Codable, Hashable {
    var id: String { "\(year)-\(month)" }

    let year: Int
    let month: Int
    let title: String
    let days: [WidgetSnapshotDay]
}

struct WidgetSnapshot: Codable, Hashable {
    let generatedAt: Date
    let currentDate: Date
    let languageCode: String
    let weekStartPolicy: String
    let weekdaySymbols: [String]
    let months: [WidgetSnapshotMonth]
    let todayEvents: [WidgetSnapshotEvent]
    let weekEvents: [WidgetSnapshotEvent]
    let monthEvents: [WidgetSnapshotEvent]
    let upcomingEvents: [WidgetSnapshotEvent]
    let todayShift: WidgetSnapshotEvent?
    let todayHoliday: WidgetSnapshotEvent?

    static func empty(at date: Date = Date()) -> WidgetSnapshot {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return WidgetSnapshot(
            generatedAt: date,
            currentDate: date,
            languageCode: "system",
            weekStartPolicy: "system",
            weekdaySymbols: calendar.veryShortWeekdaySymbols,
            months: [WidgetSnapshotMonth(year: year, month: month, title: "\(year)/\(month)", days: [])],
            todayEvents: [],
            weekEvents: [],
            monthEvents: [],
            upcomingEvents: [],
            todayShift: nil,
            todayHoliday: nil
        )
    }
}

enum WidgetSnapshotStore {
    static let appGroupIdentifier = "group.com.song.TimeNest"
    static let fileName = "widget-snapshot.json"

    static func save(_ snapshot: WidgetSnapshot) throws {
        let data = try JSONEncoder.widgetSnapshotEncoder.encode(snapshot)
        let url = try writableURL()
        try data.write(to: url, options: [.atomic])
    }

    static func load() -> WidgetSnapshot? {
        for url in candidateURLs() {
            guard let data = try? Data(contentsOf: url),
                  let snapshot = try? JSONDecoder.widgetSnapshotDecoder.decode(WidgetSnapshot.self, from: data) else {
                continue
            }
            return snapshot
        }
        return nil
    }

    private static func writableURL() throws -> URL {
        if let sharedURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            return sharedURL.appendingPathComponent(fileName, isDirectory: false)
        }

        let fallbackDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return fallbackDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    private static func candidateURLs() -> [URL] {
        var urls: [URL] = []
        if let sharedURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            urls.append(sharedURL.appendingPathComponent(fileName, isDirectory: false))
        }
        if let fallbackDirectory = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) {
            urls.append(fallbackDirectory.appendingPathComponent(fileName, isDirectory: false))
        }
        return urls
    }
}

enum TimeNestWidgetDeepLink {
    static func url(for date: Date) -> URL? {
        var components = URLComponents()
        components.scheme = "timenest"
        components.host = "calendar"
        components.queryItems = [
            URLQueryItem(name: "date", value: dateFormatter.string(from: date))
        ]
        return components.url
    }

    static func date(from url: URL) -> Date? {
        guard url.scheme == "timenest", url.host == "calendar",
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "date" })?.value else {
            return nil
        }
        return dateFormatter.date(from: value)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension JSONEncoder {
    static let widgetSnapshotEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}

private extension JSONDecoder {
    static let widgetSnapshotDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
