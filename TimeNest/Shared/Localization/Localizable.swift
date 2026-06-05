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
    case weekStartSaturday = "week_start.saturday"

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

    case calendarFirstDay = "calendar.first_day"

    // MARK: - Common

    case notImplemented = "common.not_implemented"
    case save = "common.save"
    case cancel = "common.cancel"
    case ok = "common.ok"
    case adPlaceholder = "common.ad_placeholder"
    case detail = "common.detail"
    case done = "common.done"
    case reset = "common.reset"
    case today = "common.today"
    
    // MARK: - Year Month Picker
    
    case selectYearMonth = "picker.select_year_month"
    case yearLabel = "picker.year_label"
    case monthLabel = "picker.month_label"

    // MARK: - Holiday Region Selection

    case holidayRegionSelectionTitle = "holiday_region.selection_title"
    case holidayRegionMaxLimit = "holiday_region.max_limit"
    case holidayRegionMinLimit = "holiday_region.min_limit"

    // MARK: - Holiday Subscription

    case holidaySubscriptionSettingsTitle = "holiday_subscription.settings_title"
    case holidaySubscriptionListHeader = "holiday_subscription.list_header"
    case holidaySubscriptionSourceSettings = "holiday_subscription.source_settings"
    case holidaySubscriptionRefresh = "holiday_subscription.refresh"
    case holidaySubscriptionMaxLimitNote = "holiday_subscription.max_limit_note"
    case holidaySubscriptionNone = "holiday_subscription.none"
    case holidaySubscriptionNoSubscriptions = "holiday_subscription.no_subscriptions"
    case holidaySubscriptionNoSubscriptionsDescription = "holiday_subscription.no_subscriptions_description"
    case holidaySubscriptionSynced = "holiday_subscription.synced"
    case holidaySubscriptionSyncFailed = "holiday_subscription.sync_failed"
    case holidaySubscriptionNotSynced = "holiday_subscription.not_synced"
    case holidaySubscriptionSyncError = "holiday_subscription.sync_error"
    case holidaySubscriptionNoURL = "holiday_subscription.no_url"
    case holidaySubscriptionSyncSuccessTitle = "holiday_subscription.sync_success_title"
    case holidaySubscriptionSyncSuccessMessage = "holiday_subscription.sync_success_message"
    case holidaySubscriptionSyncFailedTitle = "holiday_subscription.sync_failed_title"

    // MARK: - Holiday Source Settings

    case holidaySourceURLHeader = "holiday_source.url_header"
    case holidaySourceURLFooter = "holiday_source.url_footer"
    case holidaySourceCurrentURL = "holiday_source.current_url"
    case holidaySourceResetDefault = "holiday_source.reset_default"
    case holidaySourceTestSync = "holiday_source.test_sync"
    case holidaySourceError = "holiday_source.error"
    case holidaySourceResetConfirm = "holiday_source.reset_confirm"
    case holidaySourceResetMessage = "holiday_source.reset_message"
    case holidaySourceEnableFirst = "holiday_source.enable_first"
    case holidaySourceNoEvents = "holiday_source.no_events"
    case holidaySourceTestSuccess = "holiday_source.test_success"
    case holidaySourceTestSuccessTitle = "holiday_source.test_success_title"
    
    // MARK: - Holiday Recommended Sources

    case holidaySourceRecommendedSection = "holiday_source.recommended_section"
    case holidaySourceNoRecommendedSources = "holiday_source.no_recommended_sources"
    case holidaySourceThirdPartyNotice = "holiday_source.third_party_notice"
    case holidaySourceUseRecommendedSourceTitle = "holiday_source.use_recommended_source_title"
    case holidaySourceUseRecommendedSourceMessage = "holiday_source.use_recommended_source_message"
    case holidaySourceUseRecommendedSourceConfirm = "holiday_source.use_recommended_source_confirm"
    case holidaySourceOfficeHolidaysDescription = "holiday_source.office_holidays_description"
    case holidaySourceOfficeHolidaysCleanDescription = "holiday_source.office_holidays_clean_description"
    case holidaySubscriptionSourceNotFound = "holiday_subscription.source_not_found"

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

    // MARK: - File Sharing

    case fileSharingTitle = "file_sharing.title"
    case fileSharingExport = "file_sharing.export"
    case fileSharingExportHeader = "file_sharing.export_header"
    case fileSharingExportFooter = "file_sharing.export_footer"
    case fileSharingImport = "file_sharing.import"
    case fileSharingImportHeader = "file_sharing.import_header"
    case fileSharingImportFooter = "file_sharing.import_footer"
    case fileSharingImportResult = "file_sharing.import_result"
    case fileSharingImportedCount = "file_sharing.imported_count"
    case fileSharingSkippedCount = "file_sharing.skipped_count"
    case fileSharingInfo = "file_sharing.info"
    case fileSharingShare = "file_sharing.share"

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
