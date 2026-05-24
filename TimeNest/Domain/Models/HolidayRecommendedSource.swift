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

    /// 是否为备用/干净版本 URL
    var isCleanVersion: Bool {
        urlString.contains("/ics-clean/")
    }
}

/// 推荐订阅源配置
/// 包含经过验证的第三方 ICS 订阅源
enum HolidayRecommendedSources {

    // MARK: - Office Holidays 源（正常版本）

    /// 日本节假日（Office Holidays 正常版本）
    static let officeHolidaysJapan = HolidayRecommendedSource(
        id: "office_holidays_japan",
        providerName: "Office Holidays",
        region: .japan,
        urlString: "https://www.officeholidays.com/ics/japan",
        descriptionKey: "holiday_source.office_holidays_description"
    )

    /// 中国节假日（Office Holidays 正常版本）
    static let officeHolidaysChina = HolidayRecommendedSource(
        id: "office_holidays_china",
        providerName: "Office Holidays",
        region: .china,
        urlString: "https://www.officeholidays.com/ics/china",
        descriptionKey: "holiday_source.office_holidays_description"
    )

    /// 韩国节假日（Office Holidays 正常版本）
    static let officeHolidaysKorea = HolidayRecommendedSource(
        id: "office_holidays_korea",
        providerName: "Office Holidays",
        region: .korea,
        urlString: "https://www.officeholidays.com/ics/south-korea",
        descriptionKey: "holiday_source.office_holidays_description"
    )

    /// 美国节假日（Office Holidays 正常版本）
    static let officeHolidaysUSA = HolidayRecommendedSource(
        id: "office_holidays_usa",
        providerName: "Office Holidays",
        region: .unitedStates,
        urlString: "https://www.officeholidays.com/ics/usa",
        descriptionKey: "holiday_source.office_holidays_description"
    )

    // MARK: - Office Holidays 源（clean 版本，作为 fallback）

    /// 日本节假日（Office Holidays clean 版本）
    static let officeHolidaysJapanClean = HolidayRecommendedSource(
        id: "office_holidays_japan_clean",
        providerName: "Office Holidays (Clean)",
        region: .japan,
        urlString: "https://www.officeholidays.com/ics-clean/japan",
        descriptionKey: "holiday_source.office_holidays_clean_description"
    )

    /// 中国节假日（Office Holidays clean 版本）
    static let officeHolidaysChinaClean = HolidayRecommendedSource(
        id: "office_holidays_china_clean",
        providerName: "Office Holidays (Clean)",
        region: .china,
        urlString: "https://www.officeholidays.com/ics-clean/china",
        descriptionKey: "holiday_source.office_holidays_clean_description"
    )

    /// 韩国节假日（Office Holidays clean 版本）
    static let officeHolidaysKoreaClean = HolidayRecommendedSource(
        id: "office_holidays_korea_clean",
        providerName: "Office Holidays (Clean)",
        region: .korea,
        urlString: "https://www.officeholidays.com/ics-clean/south-korea",
        descriptionKey: "holiday_source.office_holidays_clean_description"
    )

    // MARK: - 获取推荐源

    /// 获取指定地区的推荐源列表
    /// 返回多个候选源，按优先级排序（normal 优先，clean 为 fallback）
    static func sources(for region: HolidayRegion) -> [HolidayRecommendedSource] {
        switch region {
        case .japan:
            return [officeHolidaysJapan, officeHolidaysJapanClean]
        case .china:
            return [officeHolidaysChina, officeHolidaysChinaClean]
        case .korea:
            return [officeHolidaysKorea, officeHolidaysKoreaClean]
        case .unitedStates:
            return [officeHolidaysUSA]
        }
    }

    /// 获取所有推荐源
    static var allSources: [HolidayRecommendedSource] {
        [
            officeHolidaysJapan,
            officeHolidaysJapanClean,
            officeHolidaysChina,
            officeHolidaysChinaClean,
            officeHolidaysKorea,
            officeHolidaysKoreaClean,
            officeHolidaysUSA
        ]
    }

    /// 获取指定地区的首选 URL（normal 版本）
    static func preferredURL(for region: HolidayRegion) -> String? {
        sources(for: region).first?.urlString
    }
}
