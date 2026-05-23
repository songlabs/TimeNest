import SwiftUI

// MARK: - Localized String Key

/// 本地化字符串 Key 枚举
enum LocalizedString: String {
    // MARK: - Tab Titles
    case calendar = "tab.calendar"
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
    case adPlaceholder = "common.ad_placeholder"
    case detail = "common.detail"

    // MARK: - Event Editor

    case editorTitle = "editor.title"
    case editorBasicInfo = "editor.basic_info"
    case editorDate = "editor.date"
    case editorTime = "editor.time"
    case editorAllDay = "editor.all_day"
    case editorError = "editor.error"
    case editorSave = "editor.save"
    case editorCancel = "editor.cancel"
    case editorNewEvent = "editor.new_event"
    case editorEditEvent = "editor.edit_event"

    // MARK: - Day Detail

    case dayDetailTitle = "day_detail.title"
    case dayDetailNoEvents = "day_detail.no_events"

    // MARK: - Placeholder

    case placeholderComingSoon = "placeholder.coming_soon"
    case placeholderFeatureNotImplemented = "placeholder.feature_not_implemented"
}

// MARK: - EnvironmentObject Extension

extension EnvironmentValues {
    /// 自定义 environment key 用于访问 LocalizationManager
    var localization: LocalizationManager {
        get { self[LocalizationKey.self] }
        set { self[LocalizationKey.self] = newValue }
    }
    
    private struct LocalizationKey: EnvironmentKey {
        static let defaultValue: LocalizationManager = LocalizationManager.shared
    }
}
