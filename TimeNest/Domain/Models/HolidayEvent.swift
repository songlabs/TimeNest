import Foundation

/// 节假日事件类型
enum HolidayEventType: String, Codable, Hashable {
    case publicHoliday = "public_holiday"
    case traditional = "traditional"
    case observance = "observance"
    case other = "other"
}

/// 从 ICS 解析的节假日事件（本地缓存模型）
struct HolidayEvent: Identifiable, Codable, Hashable {
    let id: String
    let region: HolidayRegion
    let date: DateOnly
    var name: String  // ICS 中的 SUMMARY，原始语言
    var translatedNames: [String: String]  // 语言码 -> 翻译后的名称
    let type: HolidayEventType
    let sourceURL: String  // 来源 ICS URL
    let importedAt: Date
    
    init(
        id: String = UUID().uuidString,
        region: HolidayRegion,
        date: DateOnly,
        name: String,
        translatedNames: [String: String] = [:],
        type: HolidayEventType = .publicHoliday,
        sourceURL: String,
        importedAt: Date = Date()
    ) {
        self.id = id
        self.region = region
        self.date = date
        self.name = name
        self.translatedNames = translatedNames
        self.type = type
        self.sourceURL = sourceURL
        self.importedAt = importedAt
    }
    
    /// 获取指定语言的显示名称
    func displayName(for languageCode: String) -> String {
        translatedNames[languageCode] ?? name
    }
}

/// 本地节假日缓存存储
struct HolidayEventCache: Codable {
    var events: [HolidayEvent]
    var lastSyncedAt: Date
    
    init(events: [HolidayEvent] = [], lastSyncedAt: Date = Date()) {
        self.events = events
        self.lastSyncedAt = lastSyncedAt
    }
    
    /// 按地区过滤
    func events(for regions: [HolidayRegion]) -> [HolidayEvent] {
        events.filter { regions.contains($0.region) }
    }
    
    /// 按日期范围过滤
    func events(in range: ClosedRange<DateOnly>) -> [HolidayEvent] {
        events.filter { $0.date >= range.lowerBound && $0.date <= range.upperBound }
    }
    
    /// 按特定日期过滤
    func events(on date: DateOnly) -> [HolidayEvent] {
        events.filter { $0.date == date }
    }
}
