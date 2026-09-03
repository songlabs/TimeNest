import Foundation
import SwiftUI

/// 应用内本地化管理器
/// 支持运行时动态切换语言，通过 @Published 触发 UI 刷新
final class LocalizationManager: ObservableObject {
    /// 共享单例
    static let shared = LocalizationManager()

    private let dateFormatterCache: NSCache<NSString, DateFormatter> = {
        let cache = NSCache<NSString, DateFormatter>()
        cache.countLimit = 32
        return cache
    }()

    /// 当前选择的语言代码
    /// 对应 DisplayLanguage 的 rawValue
    @Published var selectedLanguageCode: String

    /// 当前语言代码（只读）
    var currentLanguageCode: String {
        selectedLanguageCode
    }

    /// 当前对应的 DisplayLanguage 枚举
    var currentLanguage: DisplayLanguage {
        DisplayLanguage(rawValue: selectedLanguageCode) ?? .system
    }

    /// 当前对应的 Locale
    var currentLocale: Locale {
        locale(for: currentLanguage)
    }

    /// 日历 UI 使用的 Locale，必须跟随 App 内语言设置。
    var calendarLocale: Locale {
        currentLocale
    }

    /// 日历 UI 使用的 Gregorian Calendar，避免日期格式跟随系统历法。
    var calendar: Calendar {
        calendar(for: currentLanguage)
    }

    /// 初始化
    /// - Parameter savedCode: 已保存的语言代码，如不提供则从 UserDefaults 读取
    init(savedCode: String? = nil) {
        let code = savedCode ?? UserDefaults.standard.string(forKey: "preferredLanguageCode") ?? "system"
        self.selectedLanguageCode = code
    }

    /// 设置新语言
    /// - Parameter language: DisplayLanguage 枚举值
    func setLanguage(_ language: DisplayLanguage) {
        selectedLanguageCode = language.rawValue
        UserDefaults.standard.set(language.rawValue, forKey: "preferredLanguageCode")
    }

    func reloadFromPersistence() {
        selectedLanguageCode = UserDefaults.standard.string(
            forKey: "preferredLanguageCode"
        ) ?? "system"
        dateFormatterCache.removeAllObjects()
    }

    /// 获取本地化字符串（使用当前选择的语言）
    /// - Parameter key: 本地化字符串的 key
    /// - Returns: 本地化后的字符串
    func localized(_ key: String) -> String {
        localized(key, languageCode: selectedLanguageCode)
    }

    func localized(_ key: String, language: DisplayLanguage) -> String {
        localized(key, languageCode: language.rawValue)
    }

    private func localized(_ key: String, languageCode: String) -> String {
        let bundle = bundle(for: languageCode)
        return NSLocalizedString(key, tableName: "Localizable", bundle: bundle, value: "", comment: "")
    }

    /// 获取本地化字符串（使用 LocalizedString 枚举）
    /// - Parameter key: LocalizedString 枚举值
    /// - Returns: 本地化后的字符串
    func localized(_ key: LocalizedString) -> String {
        localized(key.rawValue)
    }

    func localized(_ key: LocalizedString, language: DisplayLanguage) -> String {
        localized(key.rawValue, language: language)
    }

    /// 根据语言代码获取对应的 Bundle 名称
    /// - Parameter languageCode: selectedLanguageCode 的值
    /// - Returns: 实际的 lproj 文件夹名称
    private func bundleName(for languageCode: String) -> String {
        switch languageCode {
        case "ja":
            return "ja"
        case "zhHans":
            return "zh-Hans"
        case "zh-Hant":
            return "zh-Hant"
        case "enUS":
            return "en"
        case "ko":
            return "ko"
        case "system":
            return systemBundleName()
        default:
            return languageCode
        }
    }

    private func systemBundleName() -> String {
        let locale = Locale.current
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        if languageCode == "zh" {
            return DisplayLanguage.system.resolved(systemLocale: locale) == .zhHant
                ? "zh-Hant"
                : "zh-Hans"
        }
        return languageCode
    }

    /// 根据语言代码获取对应的 Bundle
    /// - Parameter languageCode: selectedLanguageCode 的值
    /// - Returns: 对应的 Bundle，如果找不到则返回主 Bundle
    private func bundle(for languageCode: String) -> Bundle {
        let name = bundleName(for: languageCode)

        if let path = Bundle.main.path(forResource: name, ofType: "lproj") {
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }

        return Bundle.main
    }

    /// 根据指定语言获取 Locale。
    /// - Parameter language: App 内显示语言
    /// - Returns: 对应地区化 Locale
    func locale(for language: DisplayLanguage) -> Locale {
        switch language {
        case .system:
            return .current
        case .zhHans:
            return Locale(identifier: "zh_Hans_CN")
        case .zhHant:
            return Locale(identifier: "zh_Hant_TW")
        case .ja:
            return Locale(identifier: "ja_JP")
        case .ko:
            return Locale(identifier: "ko_KR")
        case .enUS:
            return Locale(identifier: "en_US")
        }
    }

    /// 根据指定语言获取 Gregorian Calendar。
    /// - Parameter language: App 内显示语言
    /// - Returns: 已绑定 Locale 的 Gregorian Calendar
    func calendar(for language: DisplayLanguage) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale(for: language)
        return calendar
    }

    /// 创建跟随 App 内语言的 DateFormatter。
    /// - Parameters:
    ///   - dateFormat: 固定日期格式
    ///   - language: App 内显示语言，默认使用当前语言
    /// - Returns: 已绑定 Gregorian Calendar 和 App Locale 的 formatter
    func dateFormatter(dateFormat: String, language: DisplayLanguage? = nil) -> DateFormatter {
        let displayLanguage = language ?? currentLanguage
        let locale = locale(for: displayLanguage)
        let calendar = calendar(for: displayLanguage)
        let cacheKey = "\(locale.identifier)|\(calendar.timeZone.identifier)|\(dateFormat)" as NSString

        if let cachedFormatter = dateFormatterCache.object(forKey: cacheKey) {
            return cachedFormatter
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.dateFormat = dateFormat
        dateFormatterCache.setObject(formatter, forKey: cacheKey)
        return formatter
    }

    /// 创建跟随 App 内语言排列年月日的 formatter。
    /// 与 `dateFormatter(dateFormat:)` 的固定格式用途分开，避免 UI 日期被锁定为单一地区顺序。
    func localizedDateFormatter(
        template: String,
        language: DisplayLanguage? = nil
    ) -> DateFormatter {
        let displayLanguage = language ?? currentLanguage
        let locale = locale(for: displayLanguage)
        let calendar = calendar(for: displayLanguage)
        let cacheKey = "\(locale.identifier)|\(calendar.timeZone.identifier)|template:\(template)" as NSString

        if let cachedFormatter = dateFormatterCache.object(forKey: cacheKey) {
            return cachedFormatter
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        dateFormatterCache.setObject(formatter, forKey: cacheKey)
        return formatter
    }

    /// 用户可见的完整日期。年月日顺序和分隔符跟随 App 内语言。
    func formattedUserVisibleDate(
        for date: Date,
        language: DisplayLanguage? = nil
    ) -> String {
        localizedDateFormatter(template: "yyyyMMdd", language: language).string(from: date)
    }

    /// 用户可见的日期与 24 小时时间。日期顺序本地化，时间继续遵守产品的 HH:mm 规则。
    func formattedUserVisibleDateTime(
        for date: Date,
        language: DisplayLanguage? = nil
    ) -> String {
        let dateText = formattedUserVisibleDate(for: date, language: language)
        let timeText = dateFormatter(dateFormat: "HH:mm", language: language).string(from: date)
        return "\(dateText) \(timeText)"
    }

    /// 获取当前语言对应的星期短符号
    /// - Parameter weekStartPolicy: 每周开始日策略
    /// - Returns: 7 个星期短符号数组
    func shortWeekdaySymbols(weekStartPolicy: WeekStartPolicy = .sunday) -> [String] {
        shortWeekdaySymbols(language: currentLanguage, weekStartPolicy: weekStartPolicy)
    }

    /// 获取指定语言对应的星期短符号
    /// - Parameters:
    ///   - language: App 内显示语言
    ///   - weekStartPolicy: 每周开始日策略
    /// - Returns: 7 个星期短符号数组
    func shortWeekdaySymbols(language: DisplayLanguage, weekStartPolicy: WeekStartPolicy = .sunday) -> [String] {
        let formatter = dateFormatter(dateFormat: "E", language: language)
        let symbols = shouldUseVeryShortWeekdaySymbols(for: language)
            ? formatter.veryShortWeekdaySymbols
            : formatter.shortWeekdaySymbols

        return orderedWeekdaySymbols(symbols ?? fallbackShortWeekdaySymbols(for: language), weekStartPolicy: weekStartPolicy)
    }

    /// 获取当前语言对应的完整星期符号
    /// - Parameter weekStartPolicy: 每周开始日策略
    /// - Returns: 7 个完整星期符号数组
    func fullWeekdaySymbols(weekStartPolicy: WeekStartPolicy = .sunday) -> [String] {
        fullWeekdaySymbols(language: currentLanguage, weekStartPolicy: weekStartPolicy)
    }

    /// 获取指定语言对应的完整星期符号
    /// - Parameters:
    ///   - language: App 内显示语言
    ///   - weekStartPolicy: 每周开始日策略
    /// - Returns: 7 个完整星期符号数组
    func fullWeekdaySymbols(language: DisplayLanguage, weekStartPolicy: WeekStartPolicy = .sunday) -> [String] {
        let formatter = dateFormatter(dateFormat: "EEEE", language: language)
        return orderedWeekdaySymbols(formatter.weekdaySymbols ?? fallbackFullWeekdaySymbols(for: language), weekStartPolicy: weekStartPolicy)
    }

    /// 获取月份标题
    /// - Parameter date: 用于提取年月
    /// - Returns: 本地化后的月份标题，如 "2026 年 5 月" 或 "May 2026"
    func monthTitle(for date: Date) -> String {
        let calendar = calendar(for: currentLanguage)
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        return monthTitle(year: year, month: month, language: currentLanguage)
    }

    /// 获取指定语言的月份标题
    /// - Parameters:
    ///   - year: 年
    ///   - month: 月
    ///   - language: App 内显示语言
    /// - Returns: 本地化后的月份标题
    func monthTitle(year: Int, month: Int, language: DisplayLanguage) -> String {
        switch effectiveCalendarLanguage(for: language) {
        case .zhHans, .zhHant:
            return "\(year)年\(month)月"
        case .ja:
            return "\(year)年\(month)月"
        case .ko:
            return "\(year)년 \(month)월"
        case .enUS:
            let formatter = dateFormatter(dateFormat: "MMMM yyyy", language: language)
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            guard let date = calendar(for: language).date(from: components) else {
                return "\(year)/\(month)"
            }
            return formatter.string(from: date)
        case .system:
            return "\(year)年\(month)月"
        }
    }

    /// 获取日期标题
    /// - Parameter date: 用于提取年月日
    /// - Returns: 本地化后的日期标题
    func dayTitle(for date: Date) -> String {
        let calendar = calendar(for: currentLanguage)
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let weekdayText = shortWeekdaySymbol(for: date, language: currentLanguage)

        switch effectiveCalendarLanguage(for: currentLanguage) {
        case .zhHans, .zhHant, .ja:
            return "\(year)年\(month)月\(day)日（\(weekdayText)）"
        case .ko:
            return "\(year)년 \(month)월 \(day)일 (\(weekdayText))"
        case .enUS:
            let formatter = dateFormatter(dateFormat: "MMM d, yyyy")
            return "\(formatter.string(from: date)) (\(weekdayText))"
        case .system:
            return "\(year)年\(month)月\(day)日（\(weekdayText)）"
        }
    }

    /// 获取单个月份名称
    /// - Parameter month: 月份 (1-12)
    /// - Returns: 本地化后的月份名称，如 "5 月" 或 "May"
    func monthName(for month: Int) -> String {
        monthName(for: month, language: currentLanguage)
    }

    /// 获取指定语言的单个月份名称
    /// - Parameters:
    ///   - month: 月份 (1-12)
    ///   - language: App 内显示语言
    /// - Returns: 本地化后的月份名称
    func monthName(for month: Int, language: DisplayLanguage) -> String {
        switch effectiveCalendarLanguage(for: language) {
        case .zhHans, .zhHant, .ja:
            return "\(month)月"
        case .ko:
            return "\(month)월"
        case .enUS:
            var components = DateComponents()
            components.month = month
            components.day = 1
            components.year = 2000
            guard let date = calendar(for: language).date(from: components) else {
                return "\(month)"
            }
            return dateFormatter(dateFormat: "MMMM", language: language).string(from: date)
        case .system:
            return "\(month)月"
        }
    }

    /// 获取日期字符串（用于选中日期信息条）
    /// - Parameter date: 日期
    /// - Returns: 本地化后的日期字符串，如 "5/22（金）" 或 "5/22 (Fri)"
    func formattedDateShort(for date: Date) -> String {
        formattedDateShort(for: date, language: currentLanguage)
    }

    /// 获取指定语言的短日期字符串
    /// - Parameters:
    ///   - date: 日期
    ///   - language: App 内显示语言
    /// - Returns: 本地化后的短日期字符串
    func formattedDateShort(for date: Date, language: DisplayLanguage) -> String {
        let calendar = calendar(for: language)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let weekdaySymbol = shortWeekdaySymbol(for: date, language: language)

        switch effectiveCalendarLanguage(for: language) {
        case .zhHans, .zhHant, .ja:
            return "\(month)/\(day)（\(weekdaySymbol)）"
        case .ko:
            return "\(month)월 \(day)일 (\(weekdaySymbol))"
        case .enUS:
            return "\(month)/\(day) (\(weekdaySymbol))"
        case .system:
            return "\(month)/\(day)（\(weekdaySymbol)）"
        }
    }

    /// 获取星期短符号（单个日期）
    /// - Parameter date: 日期
    /// - Returns: 星期短符号，如 "金" 或 "Fri"
    func shortWeekdaySymbol(for date: Date) -> String {
        shortWeekdaySymbol(for: date, language: currentLanguage)
    }

    /// 获取指定语言的星期短符号（单个日期）
    /// - Parameters:
    ///   - date: 日期
    ///   - language: App 内显示语言
    /// - Returns: 星期短符号
    func shortWeekdaySymbol(for date: Date, language: DisplayLanguage) -> String {
        let calendar = calendar(for: language)
        let weekdayIndex = calendar.component(.weekday, from: date)
        let symbols = shortWeekdaySymbols(language: language, weekStartPolicy: .sunday)
        return symbols[(weekdayIndex - 1 + 7) % 7]
    }

    private func effectiveCalendarLanguage(for language: DisplayLanguage) -> DisplayLanguage {
        language.resolved(systemLocale: .current)
    }

    private func shouldUseVeryShortWeekdaySymbols(for language: DisplayLanguage) -> Bool {
        switch effectiveCalendarLanguage(for: language) {
        case .zhHans, .zhHant:
            return true
        case .system, .ja, .ko, .enUS:
            return false
        }
    }

    private func orderedWeekdaySymbols(_ symbols: [String], weekStartPolicy: WeekStartPolicy) -> [String] {
        let normalizedSymbols = symbols.count == 7 ? symbols : fallbackShortWeekdaySymbols(for: .enUS)
        let startIndex = firstWeekday(for: weekStartPolicy) - 1
        guard startIndex > 0 else { return normalizedSymbols }
        return Array(normalizedSymbols[startIndex...]) + Array(normalizedSymbols[..<startIndex])
    }

    private func firstWeekday(for policy: WeekStartPolicy) -> Int {
        switch policy {
        case .sunday:
            return 1
        case .monday:
            return 2
        case .saturday:
            return 7
        case .system:
            return Calendar.current.firstWeekday
        }
    }

    private func fallbackShortWeekdaySymbols(for language: DisplayLanguage) -> [String] {
        let formatter = dateFormatter(dateFormat: "E", language: language == .system ? .enUS : language)
        if shouldUseVeryShortWeekdaySymbols(for: language) {
            return formatter.veryShortWeekdaySymbols ?? dateFormatter(dateFormat: "E", language: .enUS).shortWeekdaySymbols
        }
        return formatter.shortWeekdaySymbols ?? dateFormatter(dateFormat: "E", language: .enUS).shortWeekdaySymbols
    }

    private func fallbackFullWeekdaySymbols(for language: DisplayLanguage) -> [String] {
        let formatter = dateFormatter(dateFormat: "EEEE", language: language == .system ? .enUS : language)
        return formatter.weekdaySymbols ?? dateFormatter(dateFormat: "EEEE", language: .enUS).weekdaySymbols
    }
}
