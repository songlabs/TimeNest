import SwiftUI

// MARK: - Localized String Key

/// 本地化字符串 Key 枚举
enum LocalizedString: String {
    // MARK: - Tab Titles
    case listCalendar = "tab.list_calendar"
    case shiftInput = "tab.shift_input"
    case shiftShare = "tab.shift_share"

    // MARK: - Settings

    case settingsTitle = "settings.title"
    case settingsLanguage = "settings.language"
    case settingsNotification = "settings.notification"
    case settingsCalendar = "settings.calendar"
    case settingsTheme = "settings.theme"
    case settingsAbout = "settings.about"
    case settingsHolidayRegion = "settings.holiday_region"
    case settingsWeekStart = "settings.week_start"

    // MARK: - Language Options

    case languageSystem = "language.system"
    case languageSimplifiedChinese = "language.zh_hans"
    case languageJapanese = "language.ja"
    case languageKorean = "language.ko"
    case languageEnglish = "language.en_us"

    // MARK: - Holiday Region

    case regionJapan = "region.japan"
    case regionChina = "region.china"
    case regionKorea = "region.korea"
    case regionUnitedStates = "region.united_states"

    // MARK: - Week Start

    case weekStartSystem = "week_start.system"
    case weekStartSunday = "week_start.sunday"
    case weekStartMonday = "week_start.monday"

    // MARK: - Theme

    case themeLight = "theme.light"
    case themeDark = "theme.dark"
    case themeSystem = "theme.system"

    // MARK: - About

    case aboutVersion = "about.version"
    case aboutDeveloper = "about.developer"
    case aboutPrivacy = "about.privacy"
    case aboutTerms = "about.terms"

    // MARK: - Notification

    case notificationEnabled = "notification.enabled"
    case notificationTime = "notification.time"
    case notificationSound = "notification.sound"

    // MARK: - Calendar

    case calendarSettings = "calendar.settings"
    case calendarFirstDay = "calendar.first_day"
    case calendarShowWeekNumbers = "calendar.show_week_numbers"

    // MARK: - Common

    case notImplemented = "common.not_implemented"
    case save = "common.save"
    case cancel = "common.cancel"
    case ok = "common.ok"

    // MARK: - Placeholder

    case placeholderComingSoon = "placeholder.coming_soon"
    case placeholderFeatureNotImplemented = "placeholder.feature_not_implemented"
}

// MARK: - Localized String Extension

extension LocalizedString {
    var localized: String {
        return NSLocalizedString(rawValue, comment: "")
    }

    var localizedText: Text {
        return Text(LocalizedStringKey(rawValue))
    }
}

// MARK: - SwiftUI Text Extension

extension Text {
    static func localized(_ key: LocalizedString) -> Text {
        return Text(LocalizedStringKey(key.rawValue))
    }
}
