import Foundation

/// 推荐节假日订阅源
/// 第三方提供的 ICS 订阅源，用户可主动选择使用
struct HolidayRecommendedSource: Identifiable, Codable, Equatable {
    let id: String
    let providerName: String
    let region: HolidayRegion
    let urlString: String
    let descriptionKey: String
    
    /// 获取 provider 的 host 名称（用于 UI 显示）
    var host: String {
        if let url = URL(string: urlString) {
            return url.host ?? ""
        }
        return ""
    }
}

/// 推荐订阅源配置
/// 包含经过验证的第三方 ICS 订阅源
enum HolidayRecommendedSources {
    
    // MARK: - Office Holidays 源（已验证可用）
    // 验证时间：2026-05-24
    // 验证结果：HTTP 200, 包含 BEGIN:VCALENDAR
    
    /// 日本节假日（Office Holidays）
    static let officeHolidaysJapan = HolidayRecommendedSource(
        id: "office_holidays_japan",
        providerName: "Office Holidays",
        region: .japan,
        urlString: "https://www.officeholidays.com/ics/japan",
        descriptionKey: "holiday_source.office_holidays_description"
    )
    
    /// 中国节假日（Office Holidays）
    static let officeHolidaysChina = HolidayRecommendedSource(
        id: "office_holidays_china",
        providerName: "Office Holidays",
        region: .china,
        urlString: "https://www.officeholidays.com/ics/china",
        descriptionKey: "holiday_source.office_holidays_description"
    )
    
    /// 韩国节假日（Office Holidays）
    static let officeHolidaysKorea = HolidayRecommendedSource(
        id: "office_holidays_korea",
        providerName: "Office Holidays",
        region: .korea,
        urlString: "https://www.officeholidays.com/ics/south-korea",
        descriptionKey: "holiday_source.office_holidays_description"
    )
    
    /// 美国节假日（Office Holidays）
    static let officeHolidaysUSA = HolidayRecommendedSource(
        id: "office_holidays_usa",
        providerName: "Office Holidays",
        region: .unitedStates,
        urlString: "https://www.officeholidays.com/ics/usa",
        descriptionKey: "holiday_source.office_holidays_description"
    )
    
    // MARK: - 获取推荐源
    
    /// 获取指定地区的推荐源列表
    static func sources(for region: HolidayRegion) -> [HolidayRecommendedSource] {
        switch region {
        case .japan:
            return [officeHolidaysJapan]
        case .china:
            return [officeHolidaysChina]
        case .korea:
            return [officeHolidaysKorea]
        case .unitedStates:
            return [officeHolidaysUSA]
        }
    }
    
    /// 获取所有推荐源
    static var allSources: [HolidayRecommendedSource] {
        [
            officeHolidaysJapan,
            officeHolidaysChina,
            officeHolidaysKorea,
            officeHolidaysUSA
        ]
    }
}
