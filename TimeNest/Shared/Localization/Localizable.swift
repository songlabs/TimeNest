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
    case settingsTheme = "settings.theme"
    case settingsAbout = "settings.about"
    case settingsSupport = "settings.support"
    case settingsHolidayRegion = "settings.holiday_region"
    case settingsWeekStart = "settings.week_start"
    case shiftTimeSettingsTitle = "shift_time.settings_title"

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
    case aboutDeveloperName = "about.developer_name"
    case aboutPrivacy = "about.privacy"
    case aboutTerms = "about.terms"

    // MARK: - Help

    case helpTitle = "help.title"
    case helpContact = "help.contact"
    case helpFrequentlyAskedQuestions = "help.frequently_asked_questions"
    case helpContactEmailSubject = "help.contact.email_subject"
    case helpContactEmailBody = "help.contact.email_body"
    case helpMailUnavailableTitle = "help.mail_unavailable.title"
    case helpMailUnavailableMessage = "help.mail_unavailable.message"
    case helpCopyEmail = "help.copy_email"

    case helpCategoryEvents = "help.category.events"
    case helpCategoryViews = "help.category.views"
    case helpCategoryHolidays = "help.category.holidays"
    case helpCategoryShifts = "help.category.shifts"
    case helpCategoryAds = "help.category.ads"
    case helpCategoryPrivacy = "help.category.privacy"

    case helpEventsAddQuestion = "help.events.add.question"
    case helpEventsAddAnswer = "help.events.add.answer"
    case helpEventsAllDayQuestion = "help.events.all_day.question"
    case helpEventsAllDayAnswer = "help.events.all_day.answer"
    case helpEventsEditDeleteQuestion = "help.events.edit_delete.question"
    case helpEventsEditDeleteAnswer = "help.events.edit_delete.answer"

    case helpViewsSwitchQuestion = "help.views.switch.question"
    case helpViewsSwitchAnswer = "help.views.switch.answer"
    case helpViewsTodayQuestion = "help.views.today.question"
    case helpViewsTodayAnswer = "help.views.today.answer"
    case helpViewsMoveQuestion = "help.views.move.question"
    case helpViewsMoveAnswer = "help.views.move.answer"

    case helpHolidaysShowQuestion = "help.holidays.show.question"
    case helpHolidaysShowAnswer = "help.holidays.show.answer"
    case helpHolidaysMissingQuestion = "help.holidays.missing.question"
    case helpHolidaysMissingAnswer = "help.holidays.missing.answer"
    case helpHolidaysLanguageQuestion = "help.holidays.language.question"
    case helpHolidaysLanguageAnswer = "help.holidays.language.answer"

    case helpShiftsAddQuestion = "help.shifts.add.question"
    case helpShiftsAddAnswer = "help.shifts.add.answer"
    case helpShiftsMultipleQuestion = "help.shifts.multiple.question"
    case helpShiftsMultipleAnswer = "help.shifts.multiple.answer"
    case helpShiftsReplaceQuestion = "help.shifts.replace.question"
    case helpShiftsReplaceAnswer = "help.shifts.replace.answer"
    case helpShiftsChangeTimeQuestion = "help.shifts.change_time.question"
    case helpShiftsChangeTimeAnswer = "help.shifts.change_time.answer"
    case helpShiftsDifferenceQuestion = "help.shifts.difference.question"
    case helpShiftsDifferenceAnswer = "help.shifts.difference.answer"
    case helpShiftsRecordQuestion = "help.shifts.record.question"
    case helpShiftsRecordAnswer = "help.shifts.record.answer"
    case helpShiftsOvernightQuestion = "help.shifts.overnight.question"
    case helpShiftsOvernightAnswer = "help.shifts.overnight.answer"
    case helpShiftsStatisticsQuestion = "help.shifts.statistics.question"
    case helpShiftsStatisticsAnswer = "help.shifts.statistics.answer"
    case helpShiftsStatisticsMissingQuestion = "help.shifts.statistics_missing.question"
    case helpShiftsStatisticsMissingAnswer = "help.shifts.statistics_missing.answer"

    case helpAdsAboutQuestion = "help.ads.about.question"
    case helpAdsAboutAnswer = "help.ads.about.answer"

    case helpPrivacyStorageQuestion = "help.privacy.storage.question"
    case helpPrivacyStorageAnswer = "help.privacy.storage.answer"
    case helpPrivacyAccountQuestion = "help.privacy.account.question"
    case helpPrivacyAccountAnswer = "help.privacy.account.answer"
    case helpPrivacyDeleteAppQuestion = "help.privacy.delete_app.question"
    case helpPrivacyDeleteAppAnswer = "help.privacy.delete_app.answer"
    case helpPrivacyOptionsAction = "help.privacy.options.action"
    case helpPrivacyOptionsDescription = "help.privacy.options.description"
    case helpPrivacyOptionsErrorTitle = "help.privacy.options.error_title"
    case helpPrivacyOptionsErrorMessage = "help.privacy.options.error_message"

    case thirdPartyLicensesTitle = "third_party_licenses.title"
    case thirdPartyLicensesDescription = "third_party_licenses.description"
    case thirdPartyLicenseType = "third_party_licenses.license_type"
    case thirdPartyLicenseRepository = "third_party_licenses.repository"
    case thirdPartyGoogleMobileAds = "third_party_licenses.google_mobile_ads"
    case thirdPartyUserMessagingPlatform = "third_party_licenses.user_messaging_platform"
    case thirdPartyLicenseApache = "third_party_licenses.apache_2"
    case thirdPartyCopyrightGoogle = "third_party_licenses.google_copyright"

    // MARK: - Notification

    case notificationEnabled = "notification.enabled"
    case notificationTime = "notification.time"
    case notificationEventStartingSoon = "notification.event_starting_soon"
    case notificationDailyScheduleCheck = "notification.daily_schedule_check"

    // MARK: - Reminder Options

    case reminderNone = "reminder.none"
    case reminderAtStart = "reminder.at_start"
    case reminderFiveMinutesBefore = "reminder.five_minutes_before"
    case reminderTenMinutesBefore = "reminder.ten_minutes_before"
    case reminderFifteenMinutesBefore = "reminder.fifteen_minutes_before"
    case reminderThirtyMinutesBefore = "reminder.thirty_minutes_before"
    case reminderOneHourBefore = "reminder.one_hour_before"
    case reminderOneDayBefore = "reminder.one_day_before"

    // MARK: - Calendar

    case calendarAddEvent = "calendar.add_event"
    case calendarMoreEventsCount = "calendar.more_events_count"

    // MARK: - Widgets

    case widgetCalendarTitle = "widget.calendar.title"
    case widgetMonthScheduleTitle = "widget.monthSchedule.title"
    case widgetTwoMonthsTitle = "widget.twoMonths.title"
    case widgetWeekScheduleTitle = "widget.weekSchedule.title"
    case widgetUpcomingTitle = "widget.upcoming.title"
    case widgetNoEventsToday = "widget.noEventsToday"
    case widgetNextEvent = "widget.nextEvent"
    case widgetAllDay = "widget.allDay"
    case widgetToday = "widget.today"
    case widgetTomorrow = "widget.tomorrow"
    case widgetShift = "widget.shift"
    case widgetHoliday = "widget.holiday"
    case eventNotFound = "event.not_found"

    // MARK: - Shift Input

    case shiftInputTitle = "shift_input.title"
    case shiftInputEmpty = "shift_input.empty"

    // MARK: - Event Marker

    case eventMarkerDayOff = "event_marker.day_off"
    case eventMarkerMemo = "event_marker.memo"
    case eventMarkerTransport = "event_marker.transport"
    case eventMarkerHealth = "event_marker.health"
    case eventMarkerEvent = "event_marker.event"

    // MARK: - View Mode

    case viewModeMonth = "view_mode.month"
    case viewModeWeek = "view_mode.week"
    case viewModeDay = "view_mode.day"

    // MARK: - Common

    case notImplemented = "common.not_implemented"
    case save = "common.save"
    case cancel = "common.cancel"
    case ok = "common.ok"
    case validationTitleRequired = "validation.title_required"
    case adPlaceholder = "common.ad_placeholder"
    case detail = "common.detail"
    case done = "common.done"
    case reset = "common.reset"
    case today = "common.today"
    case moreMenu = "common.more_menu"
    
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
    case holidaySourceDefault = "holiday_source.default"
    case holidaySourceDefaultURLProvider = "holiday_source.default_url_provider"
    case holidaySourceTestSync = "holiday_source.test_sync"
    case holidaySourceError = "holiday_source.error"
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
    case holidaySubscriptionErrorMaxLimitExceeded = "holiday_subscription.error.max_limit_exceeded"
    case holidaySubscriptionErrorInvalidURL = "holiday_subscription.error.invalid_url"
    case holidaySubscriptionErrorDownloadFailed = "holiday_subscription.error.download_failed"
    case holidaySubscriptionErrorParseFailed = "holiday_subscription.error.parse_failed"
    case holidaySubscriptionErrorSyncInProgress = "holiday_subscription.error.sync_in_progress"

    // MARK: - Event Editor

    case editorTitle = "editor.title"
    case editorNote = "editor.note"
    case editorBasicInfo = "editor.basic_info"
    case editorDate = "editor.date"
    case editorStart = "editor.start"
    case editorEnd = "editor.end"
    case editorTime = "editor.time"
    case editorAllDay = "editor.all_day"
    case editorReminder = "editor.reminder"
    case editorInvalidDateRange = "editor.invalid_date_range"
    case editorError = "editor.error"
    case editorSave = "editor.save"
    case editorCancel = "editor.cancel"
    case editorNewEvent = "editor.new_event"
    case editorEditEvent = "editor.edit_event"
    case editorWorkIn = "editor.workIn"
    case editorWorkOut = "editor.workOut"
    case editorWorkInOverwriteTitle = "editor.work_in_overwrite_title"
    case editorWorkInOverwriteMessage = "editor.work_in_overwrite_message"
    case editorWorkOutOverwriteTitle = "editor.work_out_overwrite_title"
    case editorWorkOutOverwriteMessage = "editor.work_out_overwrite_message"
    case editorWorkOverwriteButton = "editor.work_overwrite_button"
    case editorWorkOverwriteCancelButton = "editor.work_overwrite_cancel_button"
    case editorRestTime = "editor.restTime"
    case editorTransportFee = "editor.transportFee"
    case editorHourlyRate = "editor.hourlyRate"
    case editorCurrencyUnit = "editor.currencyUnit"
    case workNextDayPrefix = "work.nextDayPrefix"

    // MARK: - Shift Time

    case shiftCommon = "shift.common"
    case shiftDay = "shift.day"
    case shiftNight = "shift.night"
    case shiftStart = "shift.start"
    case shiftEnd = "shift.end"
    case shiftDayStart = "shift.day_start"
    case shiftDayEnd = "shift.day_end"
    case shiftNightStart = "shift.night_start"
    case shiftNightEnd = "shift.night_end"
    case shiftEnabled = "shift.enabled"
    case shiftDisabled = "shift.disabled"
    case shiftTimeStartTime = "shift_time.start_time"
    case shiftTimeEndTime = "shift_time.end_time"
    case shiftTimeEditTitle = "shift_time.edit_shift_title"
    case shiftTimeEditFooter = "shift_time.edit_footer"
    case shiftTimeDisplayName = "shift_time.display_name"
    case shiftTimeNote = "shift_time.note"
    case shiftTimeColor = "shift_time.color"
    case shiftTimeAddButton = "shift_time.add_button"
    case shiftTimeNewShiftName = "shift_time.new_shift_name"
    case shiftTimeDeleteButton = "shift_time.delete_button"

    // MARK: - Day Detail

    case dayDetailTitle = "day_detail.title"
    case dayDetailNoEvents = "day_detail.no_events"
    case dayDetailAddEvent = "day_detail.add_event"

    // MARK: - File Sharing

    case fileSharingTitle = "file_sharing.title"
    case fileSharingExport = "file_sharing.export"
    case fileSharingExportHeader = "file_sharing.export_header"
    case fileSharingExportFooter = "file_sharing.export_footer"
    case fileSharingExportTitle = "file_sharing.export_title"
    case fileSharingImport = "file_sharing.import"
    case fileSharingImportHeader = "file_sharing.import_header"
    case fileSharingImportFooter = "file_sharing.import_footer"
    case fileSharingImportResult = "file_sharing.import_result"
    case fileSharingImportedCount = "file_sharing.imported_count"
    case fileSharingSkippedCount = "file_sharing.skipped_count"
    case fileSharingInfo = "file_sharing.info"

    // MARK: - File Sharing Errors

    case fileSharingErrorDecodeFailed = "file_sharing.error.decode_failed"
    case fileSharingErrorImportFailed = "file_sharing.error.import_failed"
    case fileSharingErrorNoEvents = "file_sharing.error.no_events"
    case fileSharingErrorPartialImportFailed = "file_sharing.error.partial_import_failed"
    case fileSharingErrorFileNotFound = "file_sharing.error.file_not_found"
    case fileSharingErrorInvalidData = "file_sharing.error.invalid_data"
    case fileSharingErrorSchemaVersionMismatch = "file_sharing.error.schema_version_mismatch"
    case fileSharingErrorSerializationFailed = "file_sharing.error.serialization_failed"
    case fileSharingErrorWriteFailed = "file_sharing.error.write_failed"
    case fileSharingErrorParseFailed = "file_sharing.error.parse_failed"

    // MARK: - ICS Errors

    case icsErrorInvalidURL = "ics.error.invalid_url"
    case icsErrorUnsupportedScheme = "ics.error.unsupported_scheme"
    case icsErrorNetwork = "ics.error.network"
    case icsErrorInvalidHTTPStatus = "ics.error.invalid_http_status"
    case icsErrorEmptyResponse = "ics.error.empty_response"
    case icsErrorInvalidEncoding = "ics.error.invalid_encoding"
    case icsErrorInvalidContent = "ics.error.invalid_content"
    case icsErrorNoEvents = "ics.error.no_events"
    case icsErrorParseFailed = "ics.error.parse_failed"
    case icsErrorTooLarge = "ics.error.too_large"
    case icsParseErrorInvalidFormat = "ics_parse.error.invalid_format"
    case icsParseErrorEmptyContent = "ics_parse.error.empty_content"
    case icsParseErrorParseFailed = "ics_parse.error.parse_failed"
    case icsParseErrorInvalidDate = "ics_parse.error.invalid_date"
    case icsParseErrorMissingRequiredField = "ics_parse.error.missing_required_field"

    // MARK: - App Errors

    case appErrorPersistence = "app_error.persistence"
    case appErrorValidation = "app_error.validation"
    case appErrorPermissionDenied = "app_error.permission_denied"
    case appErrorNotification = "app_error.notification"
    case appErrorHolidayData = "app_error.holiday_data"
    case appErrorUnknown = "app_error.unknown"

    // MARK: - Placeholder

    case placeholderComingSoon = "placeholder.coming_soon"

    // MARK: - Work Statistics

    case workStatisticsTitle = "work_statistics.title"
    case workStatistics = "work_statistics"
    case startDateMonth = "work_statistics.start_date_month"
    case endDateMonth = "work_statistics.end_date_month"
    case columnDate = "work_statistics.column_date"
    case columnTime = "work_statistics.column_time"
    case columnAmount = "work_statistics.column_amount"
    case columnTotal = "work_statistics.column_total"
    case totalHours = "work_statistics.total_hours"
    case totalAmount = "work_statistics.total_amount"
    case workStatisticsLoading = "work_statistics.loading"
    case workStatisticsEmptyTitle = "work_statistics.empty_title"
    case workStatisticsEmptyMessage = "work_statistics.empty_message"
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
