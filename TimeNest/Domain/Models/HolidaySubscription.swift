import Foundation

/// 同步状态
enum SyncStatus: String, Codable, Hashable {
    case neverSynced = "never_synced"
    case success = "success"
    case failed = "failed"
}

/// 节假日订阅配置
struct HolidaySubscription: Identifiable, Codable, Hashable {
    let id: UUID
    var region: HolidayRegion
    var displayNameKey: String
    var urlString: String
    var isEnabled: Bool
    var lastUpdatedAt: Date?
    var syncStatus: SyncStatus
    var errorMessage: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case region
        case displayNameKey
        case urlString
        case isEnabled
        case lastUpdatedAt
        case syncStatus
        case errorMessage
    }
    
    init(
        id: UUID = UUID(),
        region: HolidayRegion,
        displayNameKey: String,
        urlString: String,
        isEnabled: Bool = false,
        lastUpdatedAt: Date? = nil,
        syncStatus: SyncStatus = .neverSynced,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.region = region
        self.displayNameKey = displayNameKey
        self.urlString = urlString
        self.isEnabled = isEnabled
        self.lastUpdatedAt = lastUpdatedAt
        self.syncStatus = syncStatus
        self.errorMessage = errorMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedRegion = try container.decode(HolidayRegion.self, forKey: .region)

        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.region = decodedRegion
        self.displayNameKey = try container.decodeIfPresent(String.self, forKey: .displayNameKey) ?? decodedRegion.localizedKey
        self.urlString = try container.decodeIfPresent(String.self, forKey: .urlString) ?? ""
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        self.lastUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt)
        self.syncStatus = try container.decodeIfPresent(SyncStatus.self, forKey: .syncStatus) ?? .neverSynced
        self.errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
    }
}

/// 订阅源配置（用于用户自定义 URL）
struct ICSSourceConfig: Codable {
    var region: HolidayRegion
    var urlString: String
    
    init(region: HolidayRegion, urlString: String) {
        self.region = region
        self.urlString = urlString
    }
}

/// 默认 ICS 订阅源配置
/// 使用 Google 日历公开的节假日源作为默认订阅源
/// 注意：日本、中国、韩国的 Google 日历源目前返回 HTTP 500，因此默认 URL 为空
enum DefaultICSSources {
    // Google 日历节假日 ICS URL 模板
    // 语言代码参考：ja = 日语，zh-CN = 简体中文，ko = 韩语，en = 英语
    static let defaults: [ICSSourceConfig] = [
        // 日本节假日（日语）- Google 源返回 500，暂时留空
        ICSSourceConfig(
            region: .japan,
            urlString: ""
        ),
        // 中国节假日（简体中文）- Google 源返回 500，暂时留空
        ICSSourceConfig(
            region: .china,
            urlString: ""
        ),
        // 美国节假日（英语）- 可用
        ICSSourceConfig(
            region: .unitedStates,
            urlString: "https://calendar.google.com/calendar/ical/en.usa%23holiday%40group.v.calendar.google.com/public/basic.ics"
        ),
        // 韩国节假日（韩语）- Google 源返回 500，暂时留空
        ICSSourceConfig(
            region: .korea,
            urlString: ""
        ),
        // 台湾节假日（繁体中文）- Office Holidays
        ICSSourceConfig(
            region: .taiwan,
            urlString: "https://www.officeholidays.com/ics/taiwan"
        )
    ]
    
    /// 获取指定地区的默认 URL
    static func defaultURL(for region: HolidayRegion) -> String {
        defaults.first { $0.region == region }?.urlString ?? ""
    }
    
    /// 获取指定地区的显示名称 key
    static func displayNameKey(for region: HolidayRegion) -> String {
        region.localizedKey
    }
}
