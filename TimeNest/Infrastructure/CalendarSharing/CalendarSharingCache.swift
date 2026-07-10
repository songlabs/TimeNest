import Foundation

struct CalendarSharingCacheData: Codable {
    static let currentVersion = 2

    var version: Int
    var receivedCalendars: [SharedCalendarDescriptor]
    var eventsByCalendarID: [String: [SharedEventSnapshot]]
    var shiftsByCalendarID: [String: [SharedShiftSnapshot]]
    var workRecordsByCalendarID: [String: [SharedWorkRecordSnapshot]]
    var ownedCalendar: OwnedSharedCalendarDescriptor?

    static let empty = CalendarSharingCacheData(
        version: currentVersion,
        receivedCalendars: [],
        eventsByCalendarID: [:],
        shiftsByCalendarID: [:],
        workRecordsByCalendarID: [:],
        ownedCalendar: nil
    )

    init(
        version: Int = currentVersion,
        receivedCalendars: [SharedCalendarDescriptor],
        eventsByCalendarID: [String: [SharedEventSnapshot]],
        shiftsByCalendarID: [String: [SharedShiftSnapshot]] = [:],
        workRecordsByCalendarID: [String: [SharedWorkRecordSnapshot]] = [:],
        ownedCalendar: OwnedSharedCalendarDescriptor?
    ) {
        self.version = version
        self.receivedCalendars = receivedCalendars
        self.eventsByCalendarID = eventsByCalendarID
        self.shiftsByCalendarID = shiftsByCalendarID
        self.workRecordsByCalendarID = workRecordsByCalendarID
        self.ownedCalendar = ownedCalendar
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case receivedCalendars
        case eventsByCalendarID
        case shiftsByCalendarID
        case workRecordsByCalendarID
        case ownedCalendar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        receivedCalendars = try container.decodeIfPresent(
            [SharedCalendarDescriptor].self,
            forKey: .receivedCalendars
        ) ?? []
        eventsByCalendarID = try container.decodeIfPresent(
            [String: [SharedEventSnapshot]].self,
            forKey: .eventsByCalendarID
        ) ?? [:]
        shiftsByCalendarID = try container.decodeIfPresent(
            [String: [SharedShiftSnapshot]].self,
            forKey: .shiftsByCalendarID
        ) ?? [:]
        workRecordsByCalendarID = try container.decodeIfPresent(
            [String: [SharedWorkRecordSnapshot]].self,
            forKey: .workRecordsByCalendarID
        ) ?? [:]
        ownedCalendar = try container.decodeIfPresent(
            OwnedSharedCalendarDescriptor.self,
            forKey: .ownedCalendar
        )
    }
}

struct CalendarSharingCache {
    let fileURL: URL

    init(fileURL: URL = Self.defaultFileURL()) {
        self.fileURL = fileURL
    }

    func load() -> CalendarSharingCacheData {
        guard let data = try? Data(contentsOf: fileURL),
              let cache = try? JSONDecoder().decode(CalendarSharingCacheData.self, from: data) else {
            return .empty
        }
        return cache
    }

    func save(_ cache: CalendarSharingCacheData) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(cache)
        try data.write(to: fileURL, options: .atomic)
    }

    static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseURL
            .appendingPathComponent("TimeNestCalendarSharing", isDirectory: true)
            .appendingPathComponent("ReadOnlyCache.json", isDirectory: false)
    }
}
