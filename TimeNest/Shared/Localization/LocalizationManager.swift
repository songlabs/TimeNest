import Foundation
import SwiftUI

/// 应用内本地化管理器
/// 支持运行时动态切换语言，通过 @Published 触发 UI 刷新
final class LocalizationManager: ObservableObject {
    /// 共享单例
    static let shared = LocalizationManager()
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
        switch selectedLanguageCode {
        case "system":
            return .current
        case "zhHans":
            return Locale(identifier: "zh_Hans")
        case "ja":
            return Locale(identifier: "ja")
        case "ko":
            return Locale(identifier: "ko")
        case "enUS":
            return Locale(identifier: "en_US")
        default:
            return .current
        }
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

    /// 获取本地化字符串（使用当前选择的语言）
    /// - Parameter key: 本地化字符串的 key
    /// - Returns: 本地化后的字符串
    func localized(_ key: String) -> String {
        let bundle = bundle(for: selectedLanguageCode)
        return NSLocalizedString(key, tableName: "Localizable", bundle: bundle, value: "", comment: "")
    }

    /// 获取本地化字符串（使用 LocalizedString 枚举）
    /// - Parameter key: LocalizedString 枚举值
    /// - Returns: 本地化后的字符串
    func localized(_ key: LocalizedString) -> String {
        localized(key.rawValue)
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
        case "enUS":
            return "en"
        case "ko":
            return "ko"
        case "system":
            let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
            if languageCode == "zh" {
                return "zh-Hans"
            }
            return languageCode
        default:
            return languageCode
        }
    }

    /// 根据语言代码获取对应的 Bundle
    /// - Parameter languageCode: selectedLanguageCode 的值
    /// - Returns: 对应的 Bundle，如果找不到则返回主 Bundle
    private func bundle(for languageCode: String) -> Bundle {
        let name = bundleName(for: languageCode)

#if DEBUG
        print("[LocalizationManager] selectedLanguageCode = \(languageCode)")
        print("[LocalizationManager] bundleName = \(name)")
#endif

        if let path = Bundle.main.path(forResource: name, ofType: "lproj") {
#if DEBUG
            print("[LocalizationManager] bundlePath exists = \(FileManager.default.fileExists(atPath: path))")
#endif
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }

#if DEBUG
        print("[LocalizationManager] ⚠️ Missing bundle: \(name).lproj, falling back to main bundle")
#endif
        return Bundle.main
    }

    /// 获取当前语言对应的星期短符号
    /// - Parameter weekStartPolicy: 每周开始日策略
    /// - Returns: 7 个星期短符号数组
    func shortWeekdaySymbols(weekStartPolicy: WeekStartPolicy = .sunday) -> [String] {
        let language = currentLanguage
        let symbols: [DisplayLanguage: [String]] = [
            .zhHans: ["日", "一", "二", "三", "四", "五", "六"],
            .ja: ["日", "月", "火", "水", "木", "金", "土"],
            .ko: ["일", "월", "화", "수", "목", "금", "토"],
            .enUS: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
            .system: ["日", "一", "二", "三", "四", "五", "六"]
        ]

        var symbolsArray = symbols[language] ?? symbols[.zhHans]!

        // 根据 weekStartPolicy 调整顺序
        switch weekStartPolicy {
        case .sunday:
            // 默认顺序：日 一 二 三 四 五 六
            break
        case .monday:
            // 周一开始：一 二 三 四 五 六 日
            symbolsArray.append(symbolsArray.removeFirst())
        case .saturday:
            // 周六开始：六 日 一 二 三 四 五
            // 先移到周一开始，再反转逻辑
            // 原数组：日 一 二 三 四 五 六
            // 目标：六 日 一 二 三 四 五
            // 从末尾取出"六"放到开头
            let last = symbolsArray.removeLast()
            symbolsArray.insert(last, at: 0)
        case .system:
            // 系统默认，使用周日开始
            break
        }

        return symbolsArray
    }

    /// 获取当前语言对应的完整星期符号
    /// - Parameter weekStartPolicy: 每周开始日策略
    /// - Returns: 7 个完整星期符号数组
    func fullWeekdaySymbols(weekStartPolicy: WeekStartPolicy = .sunday) -> [String] {
        let language = currentLanguage
        let symbols: [DisplayLanguage: [String]] = [
            .zhHans: ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"],
            .ja: ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"],
            .ko: ["일요일", "월요일", "화요일", "수요일", "목요일", "금요일", "토요일"],
            .enUS: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
            .system: ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
        ]

        var symbolsArray = symbols[language] ?? symbols[.zhHans]!

        // 根据 weekStartPolicy 调整顺序
        switch weekStartPolicy {
        case .sunday:
            // 默认顺序：星期日 星期一 星期二 星期三 星期四 星期五 星期六
            break
        case .monday:
            // 周一开始：星期一 星期二 星期三 星期四 星期五 星期六 星期日
            symbolsArray.append(symbolsArray.removeFirst())
        case .saturday:
            // 周六开始：星期六 星期日 星期一 星期二 星期三 星期四 星期五
            let last = symbolsArray.removeLast()
            symbolsArray.insert(last, at: 0)
        case .system:
            // 系统默认，使用周日开始
            break
        }

        return symbolsArray
    }

    /// 获取月份标题
    /// - Parameter date: 用于提取年月
    /// - Returns: 本地化后的月份标题，如 "2026 年 5 月" 或 "May 2026"
    func monthTitle(for date: Date) -> String {
        let language = currentLanguage
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        switch language {
        case .zhHans, .system:
            return "\(year)年\(month)月"
        case .ja:
            return "\(year)年\(month)月"
        case .ko:
            return "\(year)년 \(month)월"
        case .enUS:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
    }

    /// 获取日期标题
    /// - Parameter date: 用于提取年月日
    /// - Returns: 本地化后的日期标题
    func dayTitle(for date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let weekdaySymbols = shortWeekdaySymbols(weekStartPolicy: .sunday)
        let weekdayIndex = calendar.component(.weekday, from: date) - 1
        let weekdayText = weekdaySymbols[weekdayIndex]

        switch currentLanguage {
        case .zhHans, .system, .ja:
            return "\(year)年\(month)月\(day)日（\(weekdayText)）"
        case .ko:
            return "\(year)년 \(month)월 \(day)일 (\(weekdayText))"
        case .enUS:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.calendar = calendar
            formatter.dateFormat = "MMM d, yyyy"
            return "\(formatter.string(from: date)) (\(weekdayText))"
        }
    }

    /// 获取单个月份名称
    /// - Parameter month: 月份 (1-12)
    /// - Returns: 本地化后的月份名称，如 "5 月" 或 "May"
    func monthName(for month: Int) -> String {
        let language = currentLanguage

        switch language {
        case .zhHans, .system, .ja:
            return "\(month)月"
        case .ko:
            return "\(month)월"
        case .enUS:
            let months = ["January", "February", "March", "April", "May", "June",
                         "July", "August", "September", "October", "November", "December"]
            return months[month - 1]
        }
    }

    /// 获取日期字符串（用于选中日期信息条）
    /// - Parameter date: 日期
    /// - Returns: 本地化后的日期字符串，如 "5/22（金）" 或 "5/22 (Fri)"
    func formattedDateShort(for date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let weekdayIndex = calendar.component(.weekday, from: date)

        // 获取星期符号（索引从 1 开始，Sunday=1）
        let symbols = shortWeekdaySymbols()
        let weekdaySymbol = symbols[(weekdayIndex - 1 + 7) % 7]

        switch currentLanguage {
        case .zhHans, .system:
            return "\(month)/\(day)（\(weekdaySymbol)）"
        case .ja:
            return "\(month)/\(day)（\(weekdaySymbol)）"
        case .ko:
            return "\(month)월 \(day)일 (\(weekdaySymbol))"
        case .enUS:
            return "\(month)/\(day) (\(weekdaySymbol))"
        }
    }

    /// 获取星期短符号（单个日期）
    /// - Parameter date: 日期
    /// - Returns: 星期短符号，如 "金" 或 "Fri"
    func shortWeekdaySymbol(for date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let weekdayIndex = calendar.component(.weekday, from: date)
        let symbols = shortWeekdaySymbols()
        return symbols[(weekdayIndex - 1 + 7) % 7]
    }
}

// MARK: - Preview Helper

#if DEBUG
extension LocalizationManager {
    static func preview(languageCode: String = "system") -> LocalizationManager {
        LocalizationManager(savedCode: languageCode)
    }
}
#endif
