// swiftlint:disable:this file_name
// swiftlint:disable all
// swift-format-ignore-file
// swiftformat:disable all
// Generated using tuist — https://github.com/tuist/tuist

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name
public enum TimeNestStrings: Sendable {
  public enum InfoPlist {
    /// TimeNest
    public static let cfBundleDisplayName = TimeNestStrings.tr("InfoPlist", "CFBundleDisplayName")
    /// TimeNest
    public static let cfBundleName = TimeNestStrings.tr("InfoPlist", "CFBundleName")
  }
  public enum Localizable {
    /// Statistics
    public static let workStatistics = TimeNestStrings.tr("Localizable", "work_statistics")

    public enum About: Sendable {
      /// Developer
      public static let developer = TimeNestStrings.tr("Localizable", "about.developer")
      /// TimeNest Team
      public static let developerName = TimeNestStrings.tr("Localizable", "about.developer_name")
      /// Privacy Policy
      public static let privacy = TimeNestStrings.tr("Localizable", "about.privacy")
      /// Terms of Service
      public static let terms = TimeNestStrings.tr("Localizable", "about.terms")
      /// Version
      public static let version = TimeNestStrings.tr("Localizable", "about.version")
    }

    public enum AppError: Sendable {
      /// Failed to fetch holiday data
      public static let holidayData = TimeNestStrings.tr("Localizable", "app_error.holiday_data")
      /// Notification operation failed
      public static let notification = TimeNestStrings.tr("Localizable", "app_error.notification")
      /// Permission denied
      public static let permissionDenied = TimeNestStrings.tr("Localizable", "app_error.permission_denied")
      /// Persistence operation failed
      public static let persistence = TimeNestStrings.tr("Localizable", "app_error.persistence")
      /// Unknown error
      public static let unknown = TimeNestStrings.tr("Localizable", "app_error.unknown")
      /// Validation failed
      public static let validation = TimeNestStrings.tr("Localizable", "app_error.validation")
    }

    public enum Calendar: Sendable {
      /// Add new event
      public static let addEvent = TimeNestStrings.tr("Localizable", "calendar.add_event")
      /// +%d
      public static func moreEventsCount(_ p1: Int) -> String {
        return TimeNestStrings.tr("Localizable", "calendar.more_events_count",p1)
      }
    }

    public enum Common: Sendable {
      /// AD / Ad Space
      public static let adPlaceholder = TimeNestStrings.tr("Localizable", "common.ad_placeholder")
      /// Cancel
      public static let cancel = TimeNestStrings.tr("Localizable", "common.cancel")
      /// Details
      public static let detail = TimeNestStrings.tr("Localizable", "common.detail")
      /// Done
      public static let done = TimeNestStrings.tr("Localizable", "common.done")
      /// More menu
      public static let moreMenu = TimeNestStrings.tr("Localizable", "common.more_menu")
      /// Not Implemented
      public static let notImplemented = TimeNestStrings.tr("Localizable", "common.not_implemented")
      /// OK
      public static let ok = TimeNestStrings.tr("Localizable", "common.ok")
      /// Reset to Default
      public static let reset = TimeNestStrings.tr("Localizable", "common.reset")
      /// Save
      public static let save = TimeNestStrings.tr("Localizable", "common.save")
      /// Today
      public static let today = TimeNestStrings.tr("Localizable", "common.today")
    }

    public enum DayDetail: Sendable {
      /// Add Event
      public static let addEvent = TimeNestStrings.tr("Localizable", "day_detail.add_event")
      /// No events
      public static let noEvents = TimeNestStrings.tr("Localizable", "day_detail.no_events")
      /// Events
      public static let title = TimeNestStrings.tr("Localizable", "day_detail.title")
    }

    public enum Editor: Sendable {
      /// All Day
      public static let allDay = TimeNestStrings.tr("Localizable", "editor.all_day")
      /// Basic Info
      public static let basicInfo = TimeNestStrings.tr("Localizable", "editor.basic_info")
      /// Cancel
      public static let cancel = TimeNestStrings.tr("Localizable", "editor.cancel")
      /// Yuan
      public static let currencyUnit = TimeNestStrings.tr("Localizable", "editor.currencyUnit")
      /// Date
      public static let date = TimeNestStrings.tr("Localizable", "editor.date")
      /// Edit Event
      public static let editEvent = TimeNestStrings.tr("Localizable", "editor.edit_event")
      /// End
      public static let end = TimeNestStrings.tr("Localizable", "editor.end")
      /// Error
      public static let error = TimeNestStrings.tr("Localizable", "editor.error")
      /// Hourly Rate
      public static let hourlyRate = TimeNestStrings.tr("Localizable", "editor.hourlyRate")
      /// End time must be after start time.
      public static let invalidDateRange = TimeNestStrings.tr("Localizable", "editor.invalid_date_range")
      /// New Event
      public static let newEvent = TimeNestStrings.tr("Localizable", "editor.new_event")
      /// Note
      public static let note = TimeNestStrings.tr("Localizable", "editor.note")
      /// Reminder
      public static let reminder = TimeNestStrings.tr("Localizable", "editor.reminder")
      /// Break Time
      public static let restTime = TimeNestStrings.tr("Localizable", "editor.restTime")
      /// Save
      public static let save = TimeNestStrings.tr("Localizable", "editor.save")
      /// Start
      public static let start = TimeNestStrings.tr("Localizable", "editor.start")
      /// Time
      public static let time = TimeNestStrings.tr("Localizable", "editor.time")
      /// Title
      public static let title = TimeNestStrings.tr("Localizable", "editor.title")
      /// Transport Fee
      public static let transportFee = TimeNestStrings.tr("Localizable", "editor.transportFee")
      /// Clock-in data already exists for this day. Overwrite it with the current time?
      public static let workInOverwriteMessage = TimeNestStrings.tr("Localizable", "editor.work_in_overwrite_message")
      /// Overwrite clock-in data?
      public static let workInOverwriteTitle = TimeNestStrings.tr("Localizable", "editor.work_in_overwrite_title")
      /// Clock-out data already exists for this day. Overwrite it with the current time?
      public static let workOutOverwriteMessage = TimeNestStrings.tr("Localizable", "editor.work_out_overwrite_message")
      /// Overwrite clock-out data?
      public static let workOutOverwriteTitle = TimeNestStrings.tr("Localizable", "editor.work_out_overwrite_title")
      /// Overwrite
      public static let workOverwriteButton = TimeNestStrings.tr("Localizable", "editor.work_overwrite_button")
      /// Cancel
      public static let workOverwriteCancelButton = TimeNestStrings.tr("Localizable", "editor.work_overwrite_cancel_button")
      /// Clock In
      public static let workIn = TimeNestStrings.tr("Localizable", "editor.workIn")
      /// Clock Out
      public static let workOut = TimeNestStrings.tr("Localizable", "editor.workOut")
    }

    public enum Event: Sendable {
      /// Event not found.
      public static let notFound = TimeNestStrings.tr("Localizable", "event.not_found")
    }

    public enum EventMarker: Sendable {
      /// Day off
      public static let dayOff = TimeNestStrings.tr("Localizable", "event_marker.day_off")
      /// Event
      public static let event = TimeNestStrings.tr("Localizable", "event_marker.event")
      /// Health
      public static let health = TimeNestStrings.tr("Localizable", "event_marker.health")
      /// Memo
      public static let memo = TimeNestStrings.tr("Localizable", "event_marker.memo")
      /// Transport
      public static let transport = TimeNestStrings.tr("Localizable", "event_marker.transport")
    }

    public enum FileSharing: Sendable {
      /// Export Schedule
      public static let export = TimeNestStrings.tr("Localizable", "file_sharing.export")
      /// Export current schedule as .timenest file
      public static let exportFooter = TimeNestStrings.tr("Localizable", "file_sharing.export_footer")
      /// Export
      public static let exportHeader = TimeNestStrings.tr("Localizable", "file_sharing.export_header")
      /// TimeNest Schedule
      public static let exportTitle = TimeNestStrings.tr("Localizable", "file_sharing.export_title")
      /// Import Schedule
      public static let `import` = TimeNestStrings.tr("Localizable", "file_sharing.import")
      /// Import events from .timenest file
      public static let importFooter = TimeNestStrings.tr("Localizable", "file_sharing.import_footer")
      /// Import
      public static let importHeader = TimeNestStrings.tr("Localizable", "file_sharing.import_header")
      /// Import Result
      public static let importResult = TimeNestStrings.tr("Localizable", "file_sharing.import_result")
      /// Imported
      public static let importedCount = TimeNestStrings.tr("Localizable", "file_sharing.imported_count")
      /// Exported files can be shared with other devices via AirDrop, LINE, Mail, etc. Importing will append events to the existing list without overwriting existing events.
      public static let info = TimeNestStrings.tr("Localizable", "file_sharing.info")
      /// Skipped/Failed
      public static let skippedCount = TimeNestStrings.tr("Localizable", "file_sharing.skipped_count")
      /// Data Sharing
      public static let title = TimeNestStrings.tr("Localizable", "file_sharing.title")

      public enum Error: Sendable {
        /// Failed to parse file
        public static let decodeFailed = TimeNestStrings.tr("Localizable", "file_sharing.error.decode_failed")
        /// File not found
        public static let fileNotFound = TimeNestStrings.tr("Localizable", "file_sharing.error.file_not_found")
        /// Failed to import events
        public static let importFailed = TimeNestStrings.tr("Localizable", "file_sharing.error.import_failed")
        /// Invalid file format
        public static let invalidData = TimeNestStrings.tr("Localizable", "file_sharing.error.invalid_data")
        /// No importable events found in the file
        public static let noEvents = TimeNestStrings.tr("Localizable", "file_sharing.error.no_events")
        /// Failed to parse file
        public static let parseFailed = TimeNestStrings.tr("Localizable", "file_sharing.error.parse_failed")
        /// Some events failed to import
        public static let partialImportFailed = TimeNestStrings.tr("Localizable", "file_sharing.error.partial_import_failed")
        /// Unsupported file version
        public static let schemaVersionMismatch = TimeNestStrings.tr("Localizable", "file_sharing.error.schema_version_mismatch")
        /// Failed to format export file
        public static let serializationFailed = TimeNestStrings.tr("Localizable", "file_sharing.error.serialization_failed")
        /// Failed to write file
        public static let writeFailed = TimeNestStrings.tr("Localizable", "file_sharing.error.write_failed")
      }
    }

    public enum HolidayRegion: Sendable {
      /// You can select up to 2 holiday regions.
      public static let maxLimit = TimeNestStrings.tr("Localizable", "holiday_region.max_limit")
      /// At least one holiday region must be selected.
      public static let minLimit = TimeNestStrings.tr("Localizable", "holiday_region.min_limit")
      /// Select Holiday Regions
      public static let selectionTitle = TimeNestStrings.tr("Localizable", "holiday_region.selection_title")
    }

    public enum HolidaySource: Sendable {
      /// Please enable this subscription first
      public static let enableFirst = TimeNestStrings.tr("Localizable", "holiday_source.enable_first")
      /// Error
      public static let error = TimeNestStrings.tr("Localizable", "holiday_source.error")
      /// No events in the downloaded ICS
      public static let noEvents = TimeNestStrings.tr("Localizable", "holiday_source.no_events")
      /// No recommended sources available
      public static let noRecommendedSources = TimeNestStrings.tr("Localizable", "holiday_source.no_recommended_sources")
      /// Provided by Office Holidays (Clean) (officeholidays.com)
      public static let officeHolidaysCleanDescription = TimeNestStrings.tr("Localizable", "holiday_source.office_holidays_clean_description")
      /// Provided by Office Holidays (officeholidays.com)
      public static let officeHolidaysDescription = TimeNestStrings.tr("Localizable", "holiday_source.office_holidays_description")
      /// Recommended Sources
      public static let recommendedSection = TimeNestStrings.tr("Localizable", "holiday_source.recommended_section")
      /// Successfully parsed %d events
      public static func testSuccess(_ p1: Int) -> String {
        return TimeNestStrings.tr("Localizable", "holiday_source.test_success",p1)
      }
      /// Sync Test Successful
      public static let testSuccessTitle = TimeNestStrings.tr("Localizable", "holiday_source.test_success_title")
      /// Test Sync
      public static let testSync = TimeNestStrings.tr("Localizable", "holiday_source.test_sync")
      /// This subscription source is provided by a third party. Accuracy and availability depend on the provider.
      public static let thirdPartyNotice = TimeNestStrings.tr("Localizable", "holiday_source.third_party_notice")
      /// Please enter a valid HTTPS URL
      public static let urlFooter = TimeNestStrings.tr("Localizable", "holiday_source.url_footer")
      /// ICS URL
      public static let urlHeader = TimeNestStrings.tr("Localizable", "holiday_source.url_header")
      /// Use
      public static let useRecommendedSourceConfirm = TimeNestStrings.tr("Localizable", "holiday_source.use_recommended_source_confirm")
      /// This subscription source is provided by a third party. Accuracy and availability depend on the provider.
      public static let useRecommendedSourceMessage = TimeNestStrings.tr("Localizable", "holiday_source.use_recommended_source_message")
      /// Use This Recommended Source?
      public static let useRecommendedSourceTitle = TimeNestStrings.tr("Localizable", "holiday_source.use_recommended_source_title")
    }

    public enum HolidaySubscription: Sendable {
      /// Subscribed Regions
      public static let listHeader = TimeNestStrings.tr("Localizable", "holiday_subscription.list_header")
      /// Up to 2 subscriptions can be enabled
      public static let maxLimitNote = TimeNestStrings.tr("Localizable", "holiday_subscription.max_limit_note")
      /// No Subscriptions
      public static let noSubscriptions = TimeNestStrings.tr("Localizable", "holiday_subscription.no_subscriptions")
      /// Please add a subscription source
      public static let noSubscriptionsDescription = TimeNestStrings.tr("Localizable", "holiday_subscription.no_subscriptions_description")
      /// Not Set
      public static let noUrl = TimeNestStrings.tr("Localizable", "holiday_subscription.no_url")
      /// None
      public static let `none` = TimeNestStrings.tr("Localizable", "holiday_subscription.none")
      /// Not Synced
      public static let notSynced = TimeNestStrings.tr("Localizable", "holiday_subscription.not_synced")
      /// Refresh
      public static let refresh = TimeNestStrings.tr("Localizable", "holiday_subscription.refresh")
      /// Holiday Subscriptions
      public static let settingsTitle = TimeNestStrings.tr("Localizable", "holiday_subscription.settings_title")
      /// Subscription source not found
      public static let sourceNotFound = TimeNestStrings.tr("Localizable", "holiday_subscription.source_not_found")
      /// Source Settings
      public static let sourceSettings = TimeNestStrings.tr("Localizable", "holiday_subscription.source_settings")
      /// Sync Error
      public static let syncError = TimeNestStrings.tr("Localizable", "holiday_subscription.sync_error")
      /// Sync Failed
      public static let syncFailed = TimeNestStrings.tr("Localizable", "holiday_subscription.sync_failed")
      /// Sync Failed
      public static let syncFailedTitle = TimeNestStrings.tr("Localizable", "holiday_subscription.sync_failed_title")
      /// Holiday subscriptions were refreshed successfully.
      public static let syncSuccessMessage = TimeNestStrings.tr("Localizable", "holiday_subscription.sync_success_message")
      /// Sync Succeeded
      public static let syncSuccessTitle = TimeNestStrings.tr("Localizable", "holiday_subscription.sync_success_title")
      /// Synced
      public static let synced = TimeNestStrings.tr("Localizable", "holiday_subscription.synced")

      public enum Error: Sendable {
        /// Download failed: %@
        public static func downloadFailed(_ p1: Any) -> String {
          return TimeNestStrings.tr("Localizable", "holiday_subscription.error.download_failed",String(describing: p1))
        }
        /// Invalid URL
        public static let invalidUrl = TimeNestStrings.tr("Localizable", "holiday_subscription.error.invalid_url")
        /// You can enable up to 2 subscriptions
        public static let maxLimitExceeded = TimeNestStrings.tr("Localizable", "holiday_subscription.error.max_limit_exceeded")
        /// Parse failed: %@
        public static func parseFailed(_ p1: Any) -> String {
          return TimeNestStrings.tr("Localizable", "holiday_subscription.error.parse_failed",String(describing: p1))
        }
        /// Sync is already in progress
        public static let syncInProgress = TimeNestStrings.tr("Localizable", "holiday_subscription.error.sync_in_progress")
      }
    }

    public enum Ics: Sendable {
    
      public enum Error: Sendable {
        /// ICS data is empty.
        public static let emptyResponse = TimeNestStrings.tr("Localizable", "ics.error.empty_response")
        /// The downloaded data is not valid iCalendar content.
        public static let invalidContent = TimeNestStrings.tr("Localizable", "ics.error.invalid_content")
        /// Could not read the ICS data encoding.
        public static let invalidEncoding = TimeNestStrings.tr("Localizable", "ics.error.invalid_encoding")
        /// Failed to fetch ICS. HTTP status: %d
        public static func invalidHttpStatus(_ p1: Int) -> String {
          return TimeNestStrings.tr("Localizable", "ics.error.invalid_http_status",p1)
        }
        /// Invalid URL.
        public static let invalidUrl = TimeNestStrings.tr("Localizable", "ics.error.invalid_url")
        /// Failed to fetch ICS: %@
        public static func network(_ p1: Any) -> String {
          return TimeNestStrings.tr("Localizable", "ics.error.network",String(describing: p1))
        }
        /// The downloaded ICS has no holiday data. Please try another URL.
        public static let noEvents = TimeNestStrings.tr("Localizable", "ics.error.no_events")
        /// Failed to parse ICS: %@
        public static func parseFailed(_ p1: Any) -> String {
          return TimeNestStrings.tr("Localizable", "ics.error.parse_failed",String(describing: p1))
        }
        /// ICS size is too large (%d bytes > %d bytes)
        public static func tooLarge(_ p1: Int, _ p2: Int) -> String {
          return TimeNestStrings.tr("Localizable", "ics.error.too_large",p1, p2)
        }
        /// Please enter an HTTPS or HTTP URL.
        public static let unsupportedScheme = TimeNestStrings.tr("Localizable", "ics.error.unsupported_scheme")
      }
    }

    public enum IcsParse: Sendable {
    
      public enum Error: Sendable {
        /// ICS content is empty
        public static let emptyContent = TimeNestStrings.tr("Localizable", "ics_parse.error.empty_content")
        /// Invalid date format: %@
        public static func invalidDate(_ p1: Any) -> String {
          return TimeNestStrings.tr("Localizable", "ics_parse.error.invalid_date",String(describing: p1))
        }
        /// Invalid ICS format
        public static let invalidFormat = TimeNestStrings.tr("Localizable", "ics_parse.error.invalid_format")
        /// Missing required field: %@
        public static func missingRequiredField(_ p1: Any) -> String {
          return TimeNestStrings.tr("Localizable", "ics_parse.error.missing_required_field",String(describing: p1))
        }
        /// Failed to parse line %d: %@
        public static func parseFailed(_ p1: Int, _ p2: Any) -> String {
          return TimeNestStrings.tr("Localizable", "ics_parse.error.parse_failed",p1, String(describing: p2))
        }
      }
    }

    public enum Language: Sendable {
      /// English
      public static let enUs = TimeNestStrings.tr("Localizable", "language.en_us")
      /// 日本語
      public static let ja = TimeNestStrings.tr("Localizable", "language.ja")
      /// 한국어
      public static let ko = TimeNestStrings.tr("Localizable", "language.ko")
      /// System Default
      public static let system = TimeNestStrings.tr("Localizable", "language.system")
      /// 简体中文
      public static let zhHans = TimeNestStrings.tr("Localizable", "language.zh_hans")
    }

    public enum Notification: Sendable {
      /// Check today’s schedule
      public static let dailyScheduleCheck = TimeNestStrings.tr("Localizable", "notification.daily_schedule_check")
      /// Enable Notifications
      public static let enabled = TimeNestStrings.tr("Localizable", "notification.enabled")
      /// Event starting soon
      public static let eventStartingSoon = TimeNestStrings.tr("Localizable", "notification.event_starting_soon")
      /// Notification Time
      public static let time = TimeNestStrings.tr("Localizable", "notification.time")
    }

    public enum Picker: Sendable {
      /// Month
      public static let monthLabel = TimeNestStrings.tr("Localizable", "picker.month_label")
      /// Select Year-Month
      public static let selectYearMonth = TimeNestStrings.tr("Localizable", "picker.select_year_month")
      /// Year
      public static let yearLabel = TimeNestStrings.tr("Localizable", "picker.year_label")
    }

    public enum Placeholder: Sendable {
      /// Coming Soon
      public static let comingSoon = TimeNestStrings.tr("Localizable", "placeholder.coming_soon")
    }

    public enum Region: Sendable {
      /// China
      public static let china = TimeNestStrings.tr("Localizable", "region.china")
      /// Japan
      public static let japan = TimeNestStrings.tr("Localizable", "region.japan")
      /// Korea
      public static let korea = TimeNestStrings.tr("Localizable", "region.korea")
      /// United States
      public static let unitedStates = TimeNestStrings.tr("Localizable", "region.united_states")
    }

    public enum Reminder: Sendable {
      /// At start
      public static let atStart = TimeNestStrings.tr("Localizable", "reminder.at_start")
      /// 15 minutes before
      public static let fifteenMinutesBefore = TimeNestStrings.tr("Localizable", "reminder.fifteen_minutes_before")
      /// 5 minutes before
      public static let fiveMinutesBefore = TimeNestStrings.tr("Localizable", "reminder.five_minutes_before")
      /// None
      public static let `none` = TimeNestStrings.tr("Localizable", "reminder.none")
      /// 1 day before
      public static let oneDayBefore = TimeNestStrings.tr("Localizable", "reminder.one_day_before")
      /// 1 hour before
      public static let oneHourBefore = TimeNestStrings.tr("Localizable", "reminder.one_hour_before")
      /// 10 minutes before
      public static let tenMinutesBefore = TimeNestStrings.tr("Localizable", "reminder.ten_minutes_before")
      /// 30 minutes before
      public static let thirtyMinutesBefore = TimeNestStrings.tr("Localizable", "reminder.thirty_minutes_before")
    }

    public enum Settings: Sendable {
      /// About
      public static let about = TimeNestStrings.tr("Localizable", "settings.about")
      /// Holiday Region
      public static let holidayRegion = TimeNestStrings.tr("Localizable", "settings.holiday_region")
      /// Language
      public static let language = TimeNestStrings.tr("Localizable", "settings.language")
      /// Notification
      public static let notification = TimeNestStrings.tr("Localizable", "settings.notification")
      /// Theme
      public static let theme = TimeNestStrings.tr("Localizable", "settings.theme")
      /// Settings
      public static let title = TimeNestStrings.tr("Localizable", "settings.title")
      /// Week Start
      public static let weekStart = TimeNestStrings.tr("Localizable", "settings.week_start")
    }

    public enum Shift: Sendable {
      /// Common Shifts
      public static let common = TimeNestStrings.tr("Localizable", "shift.common")
      /// Day Shift
      public static let day = TimeNestStrings.tr("Localizable", "shift.day")
      /// Day shift end time
      public static let dayEnd = TimeNestStrings.tr("Localizable", "shift.day_end")
      /// Day shift start time
      public static let dayStart = TimeNestStrings.tr("Localizable", "shift.day_start")
      /// Disabled
      public static let disabled = TimeNestStrings.tr("Localizable", "shift.disabled")
      /// Enabled
      public static let enabled = TimeNestStrings.tr("Localizable", "shift.enabled")
      /// End
      public static let end = TimeNestStrings.tr("Localizable", "shift.end")
      /// Night Shift
      public static let night = TimeNestStrings.tr("Localizable", "shift.night")
      /// Night shift end time
      public static let nightEnd = TimeNestStrings.tr("Localizable", "shift.night_end")
      /// Night shift start time
      public static let nightStart = TimeNestStrings.tr("Localizable", "shift.night_start")
      /// Start
      public static let start = TimeNestStrings.tr("Localizable", "shift.start")
    }

    public enum ShiftInput: Sendable {
      /// No enabled shifts
      public static let empty = TimeNestStrings.tr("Localizable", "shift_input.empty")
      /// Shift Input
      public static let title = TimeNestStrings.tr("Localizable", "shift_input.title")
    }

    public enum ShiftTime: Sendable {
      /// Add Shift
      public static let addButton = TimeNestStrings.tr("Localizable", "shift_time.add_button")
      /// Color
      public static let color = TimeNestStrings.tr("Localizable", "shift_time.color")
      /// Delete
      public static let deleteButton = TimeNestStrings.tr("Localizable", "shift_time.delete_button")
      /// Display Name
      public static let displayName = TimeNestStrings.tr("Localizable", "shift_time.display_name")
      /// Set the start and end times. For night shifts that span across midnight, the end time can be earlier than the start time.
      public static let editFooter = TimeNestStrings.tr("Localizable", "shift_time.edit_footer")
      /// Edit Shift
      public static let editShiftTitle = TimeNestStrings.tr("Localizable", "shift_time.edit_shift_title")
      /// End Time
      public static let endTime = TimeNestStrings.tr("Localizable", "shift_time.end_time")
      /// New Shift
      public static let newShiftName = TimeNestStrings.tr("Localizable", "shift_time.new_shift_name")
      /// Note
      public static let note = TimeNestStrings.tr("Localizable", "shift_time.note")
      /// Customize Shift Times
      public static let settingsTitle = TimeNestStrings.tr("Localizable", "shift_time.settings_title")
      /// Start Time
      public static let startTime = TimeNestStrings.tr("Localizable", "shift_time.start_time")
    }

    public enum Tab: Sendable {
      /// Calendar
      public static let calendar = TimeNestStrings.tr("Localizable", "tab.calendar")
      /// List
      public static let listCalendar = TimeNestStrings.tr("Localizable", "tab.list_calendar")
      /// Shift
      public static let shiftInput = TimeNestStrings.tr("Localizable", "tab.shift_input")
      /// Share
      public static let shiftShare = TimeNestStrings.tr("Localizable", "tab.shift_share")
    }

    public enum Theme: Sendable {
      /// Dark
      public static let dark = TimeNestStrings.tr("Localizable", "theme.dark")
      /// Light
      public static let light = TimeNestStrings.tr("Localizable", "theme.light")
      /// System Default
      public static let system = TimeNestStrings.tr("Localizable", "theme.system")
    }

    public enum ViewMode: Sendable {
      /// Day
      public static let day = TimeNestStrings.tr("Localizable", "view_mode.day")
      /// Month
      public static let month = TimeNestStrings.tr("Localizable", "view_mode.month")
      /// Week
      public static let week = TimeNestStrings.tr("Localizable", "view_mode.week")
    }

    public enum WeekStart: Sendable {
      /// Monday
      public static let monday = TimeNestStrings.tr("Localizable", "week_start.monday")
      /// Saturday
      public static let saturday = TimeNestStrings.tr("Localizable", "week_start.saturday")
      /// Sunday
      public static let sunday = TimeNestStrings.tr("Localizable", "week_start.sunday")
      /// System Default
      public static let system = TimeNestStrings.tr("Localizable", "week_start.system")
    }

    public enum Work: Sendable {
      /// Next day
      public static let nextDayPrefix = TimeNestStrings.tr("Localizable", "work.nextDayPrefix")
    }

    public enum WorkStatistics: Sendable {
      /// Amount
      public static let columnAmount = TimeNestStrings.tr("Localizable", "work_statistics.column_amount")
      /// Date
      public static let columnDate = TimeNestStrings.tr("Localizable", "work_statistics.column_date")
      /// Time
      public static let columnTime = TimeNestStrings.tr("Localizable", "work_statistics.column_time")
      /// Total
      public static let columnTotal = TimeNestStrings.tr("Localizable", "work_statistics.column_total")
      /// Adjust the filters and tap the statistics button
      public static let emptyMessage = TimeNestStrings.tr("Localizable", "work_statistics.empty_message")
      /// No statistics yet
      public static let emptyTitle = TimeNestStrings.tr("Localizable", "work_statistics.empty_title")
      /// End Date
      public static let endDateMonth = TimeNestStrings.tr("Localizable", "work_statistics.end_date_month")
      /// Loading...
      public static let loading = TimeNestStrings.tr("Localizable", "work_statistics.loading")
      /// Start Date
      public static let startDateMonth = TimeNestStrings.tr("Localizable", "work_statistics.start_date_month")
      /// Work Statistics
      public static let title = TimeNestStrings.tr("Localizable", "work_statistics.title")
      /// Total Amount
      public static let totalAmount = TimeNestStrings.tr("Localizable", "work_statistics.total_amount")
      /// Total Hours
      public static let totalHours = TimeNestStrings.tr("Localizable", "work_statistics.total_hours")
    }
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name

// MARK: - Implementation Details

extension TimeNestStrings {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = Bundle.module.localizedString(forKey: key, value: nil, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
// swiftformat:enable all
// swiftlint:enable all
