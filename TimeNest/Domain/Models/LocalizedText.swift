import Foundation

struct LocalizedText: Codable, Hashable {
    let zhHans: String
    let ja: String
    let ko: String
    let enUS: String

    /// 根据节假日所属地区创建本地化文本
    /// - Parameters:
    ///   - region: 节假日所属地区
    ///   - displayName: 该地区语言的显示名称
    init(region: HolidayRegion, displayName: String) {
        switch region {
        case .japan:
            self.zhHans = displayName
            self.ja = displayName
            self.ko = displayName
            self.enUS = displayName
        case .china:
            self.zhHans = displayName
            self.ja = displayName
            self.ko = displayName
            self.enUS = displayName
        case .korea:
            self.zhHans = displayName
            self.ja = displayName
            self.ko = displayName
            self.enUS = displayName
        case .unitedStates:
            self.zhHans = displayName
            self.ja = displayName
            self.ko = displayName
            self.enUS = displayName
        }
    }

    /// 根据节假日所属地区获取显示名称
    /// - Parameter region: 节假日所属地区
    /// - Returns: 该地区对应的语言名称
    func displayName(for region: HolidayRegion) -> String {
        switch region {
        case .japan:
            return ja
        case .china:
            return zhHans
        case .korea:
            return ko
        case .unitedStates:
            return enUS
        }
    }

    func localized(for language: DisplayLanguage) -> String {
        switch language {
        case .system:
            return zhHans
        case .zhHans:
            return zhHans
        case .ja:
            return ja
        case .ko:
            return ko
        case .enUS:
            return enUS
        }
    }
}
