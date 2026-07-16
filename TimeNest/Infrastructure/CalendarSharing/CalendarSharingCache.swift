import Foundation

struct CalendarSharingCacheData: Codable {
    static let currentVersion = 3

    var version: Int
    var receivedCalendars: [SharedCalendarDescriptor]
    var eventsByCalendarID: [UUID: [SharedEventSnapshot]]
    var shiftsByCalendarID: [UUID: [SharedShiftSnapshot]]
    var workRecordsByCalendarID: [UUID: [SharedWorkRecordSnapshot]]

    static let empty = CalendarSharingCacheData(
        version: currentVersion,
        receivedCalendars: [],
        eventsByCalendarID: [:],
        shiftsByCalendarID: [:],
        workRecordsByCalendarID: [:]
    )

    init(
        version: Int = currentVersion,
        receivedCalendars: [SharedCalendarDescriptor],
        eventsByCalendarID: [UUID: [SharedEventSnapshot]],
        shiftsByCalendarID: [UUID: [SharedShiftSnapshot]] = [:],
        workRecordsByCalendarID: [UUID: [SharedWorkRecordSnapshot]] = [:]
    ) {
        self.version = version
        self.receivedCalendars = receivedCalendars
        self.eventsByCalendarID = eventsByCalendarID
        self.shiftsByCalendarID = shiftsByCalendarID
        self.workRecordsByCalendarID = workRecordsByCalendarID
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case receivedCalendars
        case eventsByCalendarID
        case shiftsByCalendarID
        case workRecordsByCalendarID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        receivedCalendars = try container.decodeIfPresent(
            [SharedCalendarDescriptor].self,
            forKey: .receivedCalendars
        ) ?? []
        eventsByCalendarID = try container.decodeIfPresent(
            [UUID: [SharedEventSnapshot]].self,
            forKey: .eventsByCalendarID
        ) ?? [:]
        shiftsByCalendarID = try container.decodeIfPresent(
            [UUID: [SharedShiftSnapshot]].self,
            forKey: .shiftsByCalendarID
        ) ?? [:]
        workRecordsByCalendarID = try container.decodeIfPresent(
            [UUID: [SharedWorkRecordSnapshot]].self,
            forKey: .workRecordsByCalendarID
        ) ?? [:]
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
