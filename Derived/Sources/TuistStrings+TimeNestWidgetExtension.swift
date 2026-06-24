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
public enum TimeNestWidgetExtensionStrings: Sendable {
  /// Statistics
  public static let workStatistics = TimeNestWidgetExtensionStrings.tr("Localizable", "work_statistics")

  public enum About: Sendable {
    /// Developer
    public static let developer = TimeNestWidgetExtensionStrings.tr("Localizable", "about.developer")
    /// TimeNest Team
    public static let developerName = TimeNestWidgetExtensionStrings.tr("Localizable", "about.developer_name")
    /// Privacy Policy
    public static let privacy = TimeNestWidgetExtensionStrings.tr("Localizable", "about.privacy")
    /// Terms of Service
    public static let terms = TimeNestWidgetExtensionStrings.tr("Localizable", "about.terms")
    /// Version
    public static let version = TimeNestWidgetExtensionStrings.tr("Localizable", "about.version")
  }

  public enum AppError: Sendable {
    /// Failed to fetch holiday data
    public static let holidayData = TimeNestWidgetExtensionStrings.tr("Localizable", "app_error.holiday_data")
    /// Notification operation failed
    public static let notification = TimeNestWidgetExtensionStrings.tr("Localizable", "app_error.notification")
    /// Permission denied
    public static let permissionDenied = TimeNestWidgetExtensionStrings.tr("Localizable", "app_error.permission_denied")
    /// Persistence operation failed
    public static let persistence = TimeNestWidgetExtensionStrings.tr("Localizable", "app_error.persistence")
    /// Unknown error
    public static let unknown = TimeNestWidgetExtensionStrings.tr("Localizable", "app_error.unknown")
    /// Validation failed
    public static let validation = TimeNestWidgetExtensionStrings.tr("Localizable", "app_error.validation")
  }

  public enum Calendar: Sendable {
    /// Add new event
    public static let addEvent = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar.add_event")
    /// +%d
    public static func moreEventsCount(_ p1: Int) -> String {
      return TimeNestWidgetExtensionStrings.tr("Localizable", "calendar.more_events_count",p1)
    }
  }

  public enum Common: Sendable {
    /// AD / Ad Space
    public static let adPlaceholder = TimeNestWidgetExtensionStrings.tr("Localizable", "common.ad_placeholder")
    /// Cancel
    public static let cancel = TimeNestWidgetExtensionStrings.tr("Localizable", "common.cancel")
    /// Details
    public static let detail = TimeNestWidgetExtensionStrings.tr("Localizable", "common.detail")
    /// Done
    public static let done = TimeNestWidgetExtensionStrings.tr("Localizable", "common.done")
    /// More menu
    public static let moreMenu = TimeNestWidgetExtensionStrings.tr("Localizable", "common.more_menu")
    /// Not Implemented
    public static let notImplemented = TimeNestWidgetExtensionStrings.tr("Localizable", "common.not_implemented")
    /// OK
    public static let ok = TimeNestWidgetExtensionStrings.tr("Localizable", "common.ok")
    /// Reset to Default
    public static let reset = TimeNestWidgetExtensionStrings.tr("Localizable", "common.reset")
    /// Save
    public static let save = TimeNestWidgetExtensionStrings.tr("Localizable", "common.save")
    /// Today
    public static let today = TimeNestWidgetExtensionStrings.tr("Localizable", "common.today")
  }

  public enum DayDetail: Sendable {
    /// Add Event
    public static let addEvent = TimeNestWidgetExtensionStrings.tr("Localizable", "day_detail.add_event")
    /// No events
    public static let noEvents = TimeNestWidgetExtensionStrings.tr("Localizable", "day_detail.no_events")
    /// Events
    public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "day_detail.title")
  }

  public enum Editor: Sendable {
    /// All Day
    public static let allDay = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.all_day")
    /// Basic Info
    public static let basicInfo = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.basic_info")
    /// Cancel
    public static let cancel = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.cancel")
    /// Yuan
    public static let currencyUnit = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.currencyUnit")
    /// Date
    public static let date = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.date")
    /// Edit Event
    public static let editEvent = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.edit_event")
    /// End
    public static let end = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.end")
    /// Error
    public static let error = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.error")
    /// Hourly Rate
    public static let hourlyRate = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.hourlyRate")
    /// End time must be after start time.
    public static let invalidDateRange = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.invalid_date_range")
    /// New Event
    public static let newEvent = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.new_event")
    /// Note
    public static let note = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.note")
    /// Reminder
    public static let reminder = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.reminder")
    /// Break Time
    public static let restTime = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.restTime")
    /// Save
    public static let save = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.save")
    /// Start
    public static let start = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.start")
    /// Time
    public static let time = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.time")
    /// Title
    public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.title")
    /// Transport Fee
    public static let transportFee = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.transportFee")
    /// Clock-in data already exists for this day. Overwrite it with the current time?
    public static let workInOverwriteMessage = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.work_in_overwrite_message")
    /// Overwrite clock-in data?
    public static let workInOverwriteTitle = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.work_in_overwrite_title")
    /// Clock-out data already exists for this day. Overwrite it with the current time?
    public static let workOutOverwriteMessage = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.work_out_overwrite_message")
    /// Overwrite clock-out data?
    public static let workOutOverwriteTitle = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.work_out_overwrite_title")
    /// Overwrite
    public static let workOverwriteButton = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.work_overwrite_button")
    /// Cancel
    public static let workOverwriteCancelButton = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.work_overwrite_cancel_button")
    /// Clock In
    public static let workIn = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.workIn")
    /// Clock Out
    public static let workOut = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.workOut")
  }

  public enum Event: Sendable {
    /// Event not found.
    public static let notFound = TimeNestWidgetExtensionStrings.tr("Localizable", "event.not_found")
  }

  public enum EventMarker: Sendable {
    /// Day off
    public static let dayOff = TimeNestWidgetExtensionStrings.tr("Localizable", "event_marker.day_off")
    /// Event
    public static let event = TimeNestWidgetExtensionStrings.tr("Localizable", "event_marker.event")
    /// Health
    public static let health = TimeNestWidgetExtensionStrings.tr("Localizable", "event_marker.health")
    /// Memo
    public static let memo = TimeNestWidgetExtensionStrings.tr("Localizable", "event_marker.memo")
    /// Transport
    public static let transport = TimeNestWidgetExtensionStrings.tr("Localizable", "event_marker.transport")
  }

  public enum FileSharing: Sendable {
    /// Export Schedule
    public static let export = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.export")
    /// Export current schedule as .timenest file
    public static let exportFooter = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.export_footer")
    /// Export
    public static let exportHeader = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.export_header")
    /// TimeNest Schedule
    public static let exportTitle = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.export_title")
    /// Import Schedule
    public static let `import` = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.import")
    /// Import events from .timenest file
    public static let importFooter = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.import_footer")
    /// Import
    public static let importHeader = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.import_header")
    /// Import Result
    public static let importResult = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.import_result")
    /// Imported
    public static let importedCount = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.imported_count")
    /// Exported files can be shared with other devices via AirDrop, LINE, Mail, etc. Importing will append events to the existing list without overwriting existing events.
    public static let info = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.info")
    /// Skipped/Failed
    public static let skippedCount = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.skipped_count")
    /// Data Sharing
    public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.title")

    public enum Error: Sendable {
      /// Failed to parse file
      public static let decodeFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.error.decode_failed")
      /// File not found
      public static let fileNotFound = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.error.file_not_found")
      /// Failed to import events
      public static let importFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.error.import_failed")
      /// Invalid file format
      public static let invalidData = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.error.invalid_data")
      /// No importable events found in the file
      public static let noEvents = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.error.no_events")
      /// Failed to parse file
      public static let parseFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.error.parse_failed")
      /// Some events failed to import
      public static let partialImportFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.error.partial_import_failed")
      /// Unsupported file version
      public static let schemaVersionMismatch = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.error.schema_version_mismatch")
      /// Failed to format export file
      public static let serializationFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.error.serialization_failed")
      /// Failed to write file
      public static let writeFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "file_sharing.error.write_failed")
    }
  }

  public enum Help: Sendable {
    /// Contact Us
    public static let contact = TimeNestWidgetExtensionStrings.tr("Localizable", "help.contact")
    /// Copy Email Address
    public static let copyEmail = TimeNestWidgetExtensionStrings.tr("Localizable", "help.copy_email")
    /// Frequently Asked Questions
    public static let frequentlyAskedQuestions = TimeNestWidgetExtensionStrings.tr("Localizable", "help.frequently_asked_questions")
    /// Help
    public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "help.title")

    public enum Ads: Sendable {

      public enum About: Sendable {
        /// TimeNest may display ads to support the operation of the app. The current version does not offer an ad-removal purchase.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.ads.about.answer")
        /// About ads
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.ads.about.question")
      }
    }

    public enum Category: Sendable {
      /// Ads
      public static let ads = TimeNestWidgetExtensionStrings.tr("Localizable", "help.category.ads")
      /// Adding and Editing Events
      public static let events = TimeNestWidgetExtensionStrings.tr("Localizable", "help.category.events")
      /// Holidays and Days Off
      public static let holidays = TimeNestWidgetExtensionStrings.tr("Localizable", "help.category.holidays")
      /// Data and Privacy
      public static let privacy = TimeNestWidgetExtensionStrings.tr("Localizable", "help.category.privacy")
      /// Shifts and Work Records
      public static let shifts = TimeNestWidgetExtensionStrings.tr("Localizable", "help.category.shifts")
      /// Month, Week, and Day Views
      public static let views = TimeNestWidgetExtensionStrings.tr("Localizable", "help.category.views")
    }

    public enum Contact: Sendable {
      /// \n\n---\nApp version: %@\nBuild number: %@\niOS version: %@\nLanguage: %@
      public static func emailBody(_ p1: Any, _ p2: Any, _ p3: Any, _ p4: Any) -> String {
        return TimeNestWidgetExtensionStrings.tr("Localizable", "help.contact.email_body",String(describing: p1), String(describing: p2), String(describing: p3), String(describing: p4))
      }
      /// TimeNest Support Request
      public static let emailSubject = TimeNestWidgetExtensionStrings.tr("Localizable", "help.contact.email_subject")
    }

    public enum Events: Sendable {

      public enum Add: Sendable {
        /// Tap the add button at the bottom right of the calendar, enter the details, and save.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.events.add.answer")
        /// How do I add an event?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.events.add.question")
      }

      public enum AllDay: Sendable {
        /// It is shown for the whole day without a specific start or end time.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.events.all_day.answer")
        /// What is an all-day event?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.events.all_day.question")
      }

      public enum EditDelete: Sendable {
        /// Open the day's event details, tap an event to edit it, or use the delete button.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.events.edit_delete.answer")
        /// How do I edit or delete an event?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.events.edit_delete.question")
      }
    }

    public enum Holidays: Sendable {

      public enum Language: Sendable {
        /// Holiday names are shown in the language associated with the selected region.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.holidays.language.answer")
        /// What language are holiday names shown in?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.holidays.language.question")
      }

      public enum Missing: Sendable {
        /// Check the region's subscription status and refresh it on the holiday settings screen.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.holidays.missing.answer")
        /// What if holidays do not appear?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.holidays.missing.question")
      }

      public enum Show: Sendable {
        /// Enable the region you want to display under Holidays in Settings.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.holidays.show.answer")
        /// How do I show holidays?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.holidays.show.question")
      }
    }

    public enum MailUnavailable: Sendable {
      /// Mail could not be opened. Copy %@ and contact us manually.
      public static func message(_ p1: Any) -> String {
        return TimeNestWidgetExtensionStrings.tr("Localizable", "help.mail_unavailable.message",String(describing: p1))
      }
      /// Unable to Open Mail
      public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "help.mail_unavailable.title")
    }

    public enum Privacy: Sendable {

      public enum Account: Sendable {
        /// You do not need to register an account to use TimeNest.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.privacy.account.answer")
        /// Do I need an account?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.privacy.account.question")
      }

      public enum DeleteApp: Sendable {
        /// Deleting the app also deletes TimeNest data stored on the device.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.privacy.delete_app.answer")
        /// What happens to data if I delete the app?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.privacy.delete_app.question")
      }

      public enum Options: Sendable {
        /// Manage Ad Privacy Options
        public static let action = TimeNestWidgetExtensionStrings.tr("Localizable", "help.privacy.options.action")
        /// Review or change the advertising privacy choices for this device.
        public static let description = TimeNestWidgetExtensionStrings.tr("Localizable", "help.privacy.options.description")
        /// Please try again later.
        public static let errorMessage = TimeNestWidgetExtensionStrings.tr("Localizable", "help.privacy.options.error_message")
        /// Privacy Options Unavailable
        public static let errorTitle = TimeNestWidgetExtensionStrings.tr("Localizable", "help.privacy.options.error_title")
      }

      public enum Storage: Sendable {
        /// Data such as events and shifts is stored on this device.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.privacy.storage.answer")
        /// Where is my data stored?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.privacy.storage.question")
      }
    }

    public enum Shifts: Sendable {

      public enum Add: Sendable {
        /// Open Shift Input from the menu at the top of the calendar, select a date, and tap a shift button. The shift will appear in the month, week, and day views.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.shifts.add.answer")
        /// How do I add a shift?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.shifts.add.question")
      }

      public enum ChangeTime: Sendable {
        /// Under Customize Shift Times in Settings, you can change the name, start time, end time, and color for day, night, and custom shifts. The changes apply to shifts created afterward.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.shifts.change_time.answer")
        /// How do I customize shift times?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.shifts.change_time.question")
      }

      public enum Difference: Sendable {
        /// A shift is a planned work schedule, such as a day or night shift. Work records contain actual clock-in and clock-out times, breaks, hourly rates, and transport costs used for work statistics.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.shifts.difference.answer")
        /// What is the difference between shifts and work records?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.shifts.difference.question")
      }

      public enum Multiple: Sendable {
        /// Only one shift is kept for each day. Selecting another shift replaces the existing shift for that day, but does not delete regular events or clock-in and clock-out records.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.shifts.multiple.answer")
        /// Can I add multiple shifts on the same day?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.shifts.multiple.question")
      }

      public enum Overnight: Sendable {
        /// For overnight work such as a night shift, the clock-out time can be recorded on the following day. Statistics use the actual time from clock-in to the next-day clock-out, minus break time.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.shifts.overnight.answer")
        /// How is an overnight clock-out handled?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.shifts.overnight.question")
      }

      public enum Record: Sendable {
        /// When adding or editing an event, you can enter clock-in and clock-out times, break time, hourly rate, and transport cost. After saving, this information is included in work statistics.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.shifts.record.answer")
        /// How do I record clock-in and clock-out times?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.shifts.record.question")
      }

      public enum Replace: Sendable {
        /// Open Shift Input again, select the same date, and tap the new shift to replace it. Cancel only deletes the shift on the selected date and does not affect other events.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.shifts.replace.answer")
        /// How do I change the shift for a day?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.shifts.replace.question")
      }

      public enum Statistics: Sendable {
        /// Work statistics use recorded clock-in and clock-out times, break time, hourly rate, and transport cost. The basic rules are: work time = clock-out - clock-in - break; pay = work time × hourly rate; total = pay + transport cost.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.shifts.statistics.answer")
        /// How are work statistics calculated?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.shifts.statistics.question")
      }

      public enum StatisticsMissing: Sendable {
        /// Check that clock-in and clock-out records were saved within the selected period and that required information such as the hourly rate was entered. A shift alone does not create pay statistics.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.shifts.statistics_missing.answer")
        /// Why are no statistics shown?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.shifts.statistics_missing.question")
      }
    }

    public enum Views: Sendable {

      public enum Move: Sendable {
        /// Use the previous and next buttons at the top, or swipe the calendar left or right.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.views.move.answer")
        /// How do I move between months or weeks?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.views.move.question")
      }

      public enum Switch: Sendable {
        /// Select Month, Week, or Day at the bottom of the calendar.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.views.switch.answer")
        /// How do I switch views?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.views.switch.question")
      }

      public enum Today: Sendable {
        /// Tap Today at the bottom of the calendar.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.views.today.answer")
        /// How do I return to today?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.views.today.question")
      }
    }
  }

  public enum HolidayRegion: Sendable {
    /// You can select up to 2 holiday regions.
    public static let maxLimit = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_region.max_limit")
    /// At least one holiday region must be selected.
    public static let minLimit = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_region.min_limit")
    /// Select Holiday Regions
    public static let selectionTitle = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_region.selection_title")
  }

  public enum HolidaySource: Sendable {
    /// Default
    public static let `default` = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_source.default")
    /// The default URL is provided by Office Holidays (officeholidays.com)
    public static let defaultUrlProvider = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_source.default_url_provider")
    /// Please enable this subscription first
    public static let enableFirst = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_source.enable_first")
    /// Error
    public static let error = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_source.error")
    /// No events in the downloaded ICS
    public static let noEvents = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_source.no_events")
    /// No recommended sources available
    public static let noRecommendedSources = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_source.no_recommended_sources")
    /// Provided by Office Holidays (Clean) (officeholidays.com)
    public static let officeHolidaysCleanDescription = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_source.office_holidays_clean_description")
    /// Provided by Office Holidays (officeholidays.com)
    public static let officeHolidaysDescription = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_source.office_holidays_description")
    /// Recommended Subscription Source
    public static let recommendedSection = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_source.recommended_section")
    /// Successfully parsed %d events
    public static func testSuccess(_ p1: Int) -> String {
      return TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_source.test_success",p1)
    }
    /// Sync Test Successful
    public static let testSuccessTitle = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_source.test_success_title")
    /// Test
    public static let testSync = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_source.test_sync")
    /// This subscription source is provided by a third party. Accuracy and availability depend on the provider.
    public static let thirdPartyNotice = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_source.third_party_notice")
    /// Please enter a valid HTTPS URL
    public static let urlFooter = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_source.url_footer")
    /// Subscription URL
    public static let urlHeader = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_source.url_header")
    /// Use
    public static let useRecommendedSourceConfirm = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_source.use_recommended_source_confirm")
    /// This subscription source is provided by a third party. Accuracy and availability depend on the provider.
    public static let useRecommendedSourceMessage = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_source.use_recommended_source_message")
    /// Use This Recommended Source?
    public static let useRecommendedSourceTitle = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_source.use_recommended_source_title")
  }

  public enum HolidaySubscription: Sendable {
    /// Subscribed Regions
    public static let listHeader = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.list_header")
    /// Up to 2 subscriptions can be enabled
    public static let maxLimitNote = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.max_limit_note")
    /// No Subscriptions
    public static let noSubscriptions = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.no_subscriptions")
    /// Please add a subscription source
    public static let noSubscriptionsDescription = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.no_subscriptions_description")
    /// Not Set
    public static let noUrl = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.no_url")
    /// None
    public static let `none` = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.none")
    /// Not Synced
    public static let notSynced = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.not_synced")
    /// Refresh
    public static let refresh = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.refresh")
    /// Holiday Subscriptions
    public static let settingsTitle = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.settings_title")
    /// Subscription source not found
    public static let sourceNotFound = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.source_not_found")
    /// Source Settings
    public static let sourceSettings = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.source_settings")
    /// Sync Error
    public static let syncError = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.sync_error")
    /// Sync Failed
    public static let syncFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.sync_failed")
    /// Sync Failed
    public static let syncFailedTitle = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.sync_failed_title")
    /// Holiday subscriptions were refreshed successfully.
    public static let syncSuccessMessage = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.sync_success_message")
    /// Sync Succeeded
    public static let syncSuccessTitle = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.sync_success_title")
    /// Synced
    public static let synced = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.synced")

    public enum Error: Sendable {
      /// Download failed: %@
      public static func downloadFailed(_ p1: Any) -> String {
        return TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.error.download_failed",String(describing: p1))
      }
      /// Invalid URL
      public static let invalidUrl = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.error.invalid_url")
      /// You can enable up to 2 subscriptions
      public static let maxLimitExceeded = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.error.max_limit_exceeded")
      /// Parse failed: %@
      public static func parseFailed(_ p1: Any) -> String {
        return TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.error.parse_failed",String(describing: p1))
      }
      /// Sync is already in progress
      public static let syncInProgress = TimeNestWidgetExtensionStrings.tr("Localizable", "holiday_subscription.error.sync_in_progress")
    }
  }

  public enum Ics: Sendable {

    public enum Error: Sendable {
      /// ICS data is empty.
      public static let emptyResponse = TimeNestWidgetExtensionStrings.tr("Localizable", "ics.error.empty_response")
      /// The downloaded data is not valid iCalendar content.
      public static let invalidContent = TimeNestWidgetExtensionStrings.tr("Localizable", "ics.error.invalid_content")
      /// Could not read the ICS data encoding.
      public static let invalidEncoding = TimeNestWidgetExtensionStrings.tr("Localizable", "ics.error.invalid_encoding")
      /// Failed to fetch ICS. HTTP status: %d
      public static func invalidHttpStatus(_ p1: Int) -> String {
        return TimeNestWidgetExtensionStrings.tr("Localizable", "ics.error.invalid_http_status",p1)
      }
      /// Invalid URL.
      public static let invalidUrl = TimeNestWidgetExtensionStrings.tr("Localizable", "ics.error.invalid_url")
      /// Failed to fetch ICS: %@
      public static func network(_ p1: Any) -> String {
        return TimeNestWidgetExtensionStrings.tr("Localizable", "ics.error.network",String(describing: p1))
      }
      /// The downloaded ICS has no holiday data. Please try another URL.
      public static let noEvents = TimeNestWidgetExtensionStrings.tr("Localizable", "ics.error.no_events")
      /// Failed to parse ICS: %@
      public static func parseFailed(_ p1: Any) -> String {
        return TimeNestWidgetExtensionStrings.tr("Localizable", "ics.error.parse_failed",String(describing: p1))
      }
      /// ICS size is too large (%d bytes > %d bytes)
      public static func tooLarge(_ p1: Int, _ p2: Int) -> String {
        return TimeNestWidgetExtensionStrings.tr("Localizable", "ics.error.too_large",p1, p2)
      }
      /// Please enter an HTTPS or HTTP URL.
      public static let unsupportedScheme = TimeNestWidgetExtensionStrings.tr("Localizable", "ics.error.unsupported_scheme")
    }
  }

  public enum IcsParse: Sendable {

    public enum Error: Sendable {
      /// ICS content is empty
      public static let emptyContent = TimeNestWidgetExtensionStrings.tr("Localizable", "ics_parse.error.empty_content")
      /// Invalid date format: %@
      public static func invalidDate(_ p1: Any) -> String {
        return TimeNestWidgetExtensionStrings.tr("Localizable", "ics_parse.error.invalid_date",String(describing: p1))
      }
      /// Invalid ICS format
      public static let invalidFormat = TimeNestWidgetExtensionStrings.tr("Localizable", "ics_parse.error.invalid_format")
      /// Missing required field: %@
      public static func missingRequiredField(_ p1: Any) -> String {
        return TimeNestWidgetExtensionStrings.tr("Localizable", "ics_parse.error.missing_required_field",String(describing: p1))
      }
      /// Failed to parse line %d: %@
      public static func parseFailed(_ p1: Int, _ p2: Any) -> String {
        return TimeNestWidgetExtensionStrings.tr("Localizable", "ics_parse.error.parse_failed",p1, String(describing: p2))
      }
    }
  }

  public enum Language: Sendable {
    /// English
    public static let enUs = TimeNestWidgetExtensionStrings.tr("Localizable", "language.en_us")
    /// 日本語
    public static let ja = TimeNestWidgetExtensionStrings.tr("Localizable", "language.ja")
    /// 한국어
    public static let ko = TimeNestWidgetExtensionStrings.tr("Localizable", "language.ko")
    /// System Default
    public static let system = TimeNestWidgetExtensionStrings.tr("Localizable", "language.system")
    /// 简体中文
    public static let zhHans = TimeNestWidgetExtensionStrings.tr("Localizable", "language.zh_hans")
    /// 繁體中文
    public static let zhHant = TimeNestWidgetExtensionStrings.tr("Localizable", "language.zh_hant")
  }

  public enum Notification: Sendable {
    /// Check today’s schedule
    public static let dailyScheduleCheck = TimeNestWidgetExtensionStrings.tr("Localizable", "notification.daily_schedule_check")
    /// Enable Notifications
    public static let enabled = TimeNestWidgetExtensionStrings.tr("Localizable", "notification.enabled")
    /// Event starting soon
    public static let eventStartingSoon = TimeNestWidgetExtensionStrings.tr("Localizable", "notification.event_starting_soon")
    /// Notification Time
    public static let time = TimeNestWidgetExtensionStrings.tr("Localizable", "notification.time")
  }

  public enum Picker: Sendable {
    /// Month
    public static let monthLabel = TimeNestWidgetExtensionStrings.tr("Localizable", "picker.month_label")
    /// Select Year-Month
    public static let selectYearMonth = TimeNestWidgetExtensionStrings.tr("Localizable", "picker.select_year_month")
    /// Year
    public static let yearLabel = TimeNestWidgetExtensionStrings.tr("Localizable", "picker.year_label")
  }

  public enum Placeholder: Sendable {
    /// Coming Soon
    public static let comingSoon = TimeNestWidgetExtensionStrings.tr("Localizable", "placeholder.coming_soon")
  }

  public enum Region: Sendable {
    /// China
    public static let china = TimeNestWidgetExtensionStrings.tr("Localizable", "region.china")
    /// Japan
    public static let japan = TimeNestWidgetExtensionStrings.tr("Localizable", "region.japan")
    /// Korea
    public static let korea = TimeNestWidgetExtensionStrings.tr("Localizable", "region.korea")
    /// Taiwan
    public static let taiwan = TimeNestWidgetExtensionStrings.tr("Localizable", "region.taiwan")
    /// United States
    public static let unitedStates = TimeNestWidgetExtensionStrings.tr("Localizable", "region.united_states")
  }

  public enum Reminder: Sendable {
    /// At start
    public static let atStart = TimeNestWidgetExtensionStrings.tr("Localizable", "reminder.at_start")
    /// 15 minutes before
    public static let fifteenMinutesBefore = TimeNestWidgetExtensionStrings.tr("Localizable", "reminder.fifteen_minutes_before")
    /// 5 minutes before
    public static let fiveMinutesBefore = TimeNestWidgetExtensionStrings.tr("Localizable", "reminder.five_minutes_before")
    /// None
    public static let `none` = TimeNestWidgetExtensionStrings.tr("Localizable", "reminder.none")
    /// 1 day before
    public static let oneDayBefore = TimeNestWidgetExtensionStrings.tr("Localizable", "reminder.one_day_before")
    /// 1 hour before
    public static let oneHourBefore = TimeNestWidgetExtensionStrings.tr("Localizable", "reminder.one_hour_before")
    /// 10 minutes before
    public static let tenMinutesBefore = TimeNestWidgetExtensionStrings.tr("Localizable", "reminder.ten_minutes_before")
    /// 30 minutes before
    public static let thirtyMinutesBefore = TimeNestWidgetExtensionStrings.tr("Localizable", "reminder.thirty_minutes_before")
  }

  public enum Settings: Sendable {
    /// About
    public static let about = TimeNestWidgetExtensionStrings.tr("Localizable", "settings.about")
    /// Holiday Region
    public static let holidayRegion = TimeNestWidgetExtensionStrings.tr("Localizable", "settings.holiday_region")
    /// Language
    public static let language = TimeNestWidgetExtensionStrings.tr("Localizable", "settings.language")
    /// Notification
    public static let notification = TimeNestWidgetExtensionStrings.tr("Localizable", "settings.notification")
    /// Support
    public static let support = TimeNestWidgetExtensionStrings.tr("Localizable", "settings.support")
    /// Theme
    public static let theme = TimeNestWidgetExtensionStrings.tr("Localizable", "settings.theme")
    /// Settings
    public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "settings.title")
    /// Week Start
    public static let weekStart = TimeNestWidgetExtensionStrings.tr("Localizable", "settings.week_start")
  }

  public enum Shift: Sendable {
    /// Common Shifts
    public static let common = TimeNestWidgetExtensionStrings.tr("Localizable", "shift.common")
    /// Day Shift
    public static let day = TimeNestWidgetExtensionStrings.tr("Localizable", "shift.day")
    /// Day shift end time
    public static let dayEnd = TimeNestWidgetExtensionStrings.tr("Localizable", "shift.day_end")
    /// Day shift start time
    public static let dayStart = TimeNestWidgetExtensionStrings.tr("Localizable", "shift.day_start")
    /// Disabled
    public static let disabled = TimeNestWidgetExtensionStrings.tr("Localizable", "shift.disabled")
    /// Enabled
    public static let enabled = TimeNestWidgetExtensionStrings.tr("Localizable", "shift.enabled")
    /// End
    public static let end = TimeNestWidgetExtensionStrings.tr("Localizable", "shift.end")
    /// Night Shift
    public static let night = TimeNestWidgetExtensionStrings.tr("Localizable", "shift.night")
    /// Night shift end time
    public static let nightEnd = TimeNestWidgetExtensionStrings.tr("Localizable", "shift.night_end")
    /// Night shift start time
    public static let nightStart = TimeNestWidgetExtensionStrings.tr("Localizable", "shift.night_start")
    /// Start
    public static let start = TimeNestWidgetExtensionStrings.tr("Localizable", "shift.start")
  }

  public enum ShiftInput: Sendable {
    /// No enabled shifts
    public static let empty = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_input.empty")
    /// Shift Input
    public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_input.title")
  }

  public enum ShiftTime: Sendable {
    /// Add Shift
    public static let addButton = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_time.add_button")
    /// Color
    public static let color = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_time.color")
    /// Delete
    public static let deleteButton = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_time.delete_button")
    /// Display Name
    public static let displayName = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_time.display_name")
    /// Set the start and end times. For night shifts that span across midnight, the end time can be earlier than the start time.
    public static let editFooter = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_time.edit_footer")
    /// Edit Shift
    public static let editShiftTitle = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_time.edit_shift_title")
    /// End Time
    public static let endTime = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_time.end_time")
    /// New Shift
    public static let newShiftName = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_time.new_shift_name")
    /// Note
    public static let note = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_time.note")
    /// Customize Shift Times
    public static let settingsTitle = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_time.settings_title")
    /// Start Time
    public static let startTime = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_time.start_time")
  }

  public enum Tab: Sendable {
    /// Calendar
    public static let calendar = TimeNestWidgetExtensionStrings.tr("Localizable", "tab.calendar")
    /// List
    public static let listCalendar = TimeNestWidgetExtensionStrings.tr("Localizable", "tab.list_calendar")
    /// Shift
    public static let shiftInput = TimeNestWidgetExtensionStrings.tr("Localizable", "tab.shift_input")
    /// Share
    public static let shiftShare = TimeNestWidgetExtensionStrings.tr("Localizable", "tab.shift_share")
  }

  public enum Theme: Sendable {
    /// Dark
    public static let dark = TimeNestWidgetExtensionStrings.tr("Localizable", "theme.dark")
    /// Light
    public static let light = TimeNestWidgetExtensionStrings.tr("Localizable", "theme.light")
    /// System Default
    public static let system = TimeNestWidgetExtensionStrings.tr("Localizable", "theme.system")
  }

  public enum ThirdPartyLicenses: Sendable {
    /// Apache-2.0
    public static let apache2 = TimeNestWidgetExtensionStrings.tr("Localizable", "third_party_licenses.apache_2")
    /// TimeNest uses the following third-party components. Full notices remain available in the project's ThirdPartyNotices document.
    public static let description = TimeNestWidgetExtensionStrings.tr("Localizable", "third_party_licenses.description")
    /// Copyright 2021 Google LLC
    public static let googleCopyright = TimeNestWidgetExtensionStrings.tr("Localizable", "third_party_licenses.google_copyright")
    /// Google Mobile Ads Swift Package Manager wrapper
    public static let googleMobileAds = TimeNestWidgetExtensionStrings.tr("Localizable", "third_party_licenses.google_mobile_ads")
    /// License
    public static let licenseType = TimeNestWidgetExtensionStrings.tr("Localizable", "third_party_licenses.license_type")
    /// View Source Repository
    public static let repository = TimeNestWidgetExtensionStrings.tr("Localizable", "third_party_licenses.repository")
    /// Third-party Licenses
    public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "third_party_licenses.title")
    /// Google User Messaging Platform Swift Package Manager wrapper
    public static let userMessagingPlatform = TimeNestWidgetExtensionStrings.tr("Localizable", "third_party_licenses.user_messaging_platform")
  }

  public enum Validation: Sendable {
    /// Please enter a title
    public static let titleRequired = TimeNestWidgetExtensionStrings.tr("Localizable", "validation.title_required")
  }

  public enum ViewMode: Sendable {
    /// Day
    public static let day = TimeNestWidgetExtensionStrings.tr("Localizable", "view_mode.day")
    /// Month
    public static let month = TimeNestWidgetExtensionStrings.tr("Localizable", "view_mode.month")
    /// Week
    public static let week = TimeNestWidgetExtensionStrings.tr("Localizable", "view_mode.week")
  }

  public enum WeekStart: Sendable {
    /// Monday
    public static let monday = TimeNestWidgetExtensionStrings.tr("Localizable", "week_start.monday")
    /// Saturday
    public static let saturday = TimeNestWidgetExtensionStrings.tr("Localizable", "week_start.saturday")
    /// Sunday
    public static let sunday = TimeNestWidgetExtensionStrings.tr("Localizable", "week_start.sunday")
    /// System Default
    public static let system = TimeNestWidgetExtensionStrings.tr("Localizable", "week_start.system")
  }

  public enum Widget: Sendable {
    /// All day
    public static let allDay = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.allDay")
    /// Holiday
    public static let holiday = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.holiday")
    /// Next
    public static let nextEvent = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.nextEvent")
    /// No events today
    public static let noEventsToday = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.noEventsToday")
    /// Shift
    public static let shift = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.shift")
    /// Today
    public static let today = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.today")
    /// Tomorrow
    public static let tomorrow = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.tomorrow")

    public enum Accessory: Sendable {
      /// Shows today's summary on the Lock Screen, StandBy, and Apple Watch.
      public static let description = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.accessory.description")
      /// Today Summary
      public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.accessory.title")
    }

    public enum Calendar: Sendable {
      /// Shows the current month.
      public static let description = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.calendar.description")
      /// Calendar
      public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.calendar.title")
    }

    public enum MonthSchedule: Sendable {
      /// Shows a short schedule for each day this month.
      public static let description = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.monthSchedule.description")
      /// This Month
      public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.monthSchedule.title")
    }

    public enum TwoMonths: Sendable {
      /// Shows two months side by side.
      public static let description = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.twoMonths.description")
      /// This and Next Month
      public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.twoMonths.title")
    }

    public enum Upcoming: Sendable {
      /// Shows upcoming events with the current month.
      public static let description = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.upcoming.description")
      /// Upcoming and Calendar
      public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.upcoming.title")
    }

    public enum WeekSchedule: Sendable {
      /// Shows this week's shifts, holidays, and events.
      public static let description = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.weekSchedule.description")
      /// This Week
      public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "widget.weekSchedule.title")
    }
  }

  public enum Work: Sendable {
    /// Next day
    public static let nextDayPrefix = TimeNestWidgetExtensionStrings.tr("Localizable", "work.nextDayPrefix")
  }

  public enum WorkStatistics: Sendable {
    /// Amount
    public static let columnAmount = TimeNestWidgetExtensionStrings.tr("Localizable", "work_statistics.column_amount")
    /// Date
    public static let columnDate = TimeNestWidgetExtensionStrings.tr("Localizable", "work_statistics.column_date")
    /// Time
    public static let columnTime = TimeNestWidgetExtensionStrings.tr("Localizable", "work_statistics.column_time")
    /// Total
    public static let columnTotal = TimeNestWidgetExtensionStrings.tr("Localizable", "work_statistics.column_total")
    /// Adjust the filters and tap the statistics button
    public static let emptyMessage = TimeNestWidgetExtensionStrings.tr("Localizable", "work_statistics.empty_message")
    /// No statistics yet
    public static let emptyTitle = TimeNestWidgetExtensionStrings.tr("Localizable", "work_statistics.empty_title")
    /// End Date
    public static let endDateMonth = TimeNestWidgetExtensionStrings.tr("Localizable", "work_statistics.end_date_month")
    /// Loading...
    public static let loading = TimeNestWidgetExtensionStrings.tr("Localizable", "work_statistics.loading")
    /// Start Date
    public static let startDateMonth = TimeNestWidgetExtensionStrings.tr("Localizable", "work_statistics.start_date_month")
    /// Work Statistics
    public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "work_statistics.title")
    /// Total Amount
    public static let totalAmount = TimeNestWidgetExtensionStrings.tr("Localizable", "work_statistics.total_amount")
    /// Total Hours
    public static let totalHours = TimeNestWidgetExtensionStrings.tr("Localizable", "work_statistics.total_hours")
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name

// MARK: - Implementation Details

extension TimeNestWidgetExtensionStrings {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = Bundle.module.localizedString(forKey: key, value: nil, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
// swiftformat:enable all
// swiftlint:enable all
