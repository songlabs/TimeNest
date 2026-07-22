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

  public enum Ads: Sendable {
    /// Purchase completed
    public static let purchaseCompleted = TimeNestWidgetExtensionStrings.tr("Localizable", "ads.purchase_completed")
    /// Purchase could not be completed. Please try again later.
    public static let purchaseFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "ads.purchase_failed")
    /// Purchase is pending approval. Ads will be hidden after it completes.
    public static let purchasePending = TimeNestWidgetExtensionStrings.tr("Localizable", "ads.purchase_pending")
    /// Purchases are temporarily unavailable. Please try again later.
    public static let purchaseUnavailable = TimeNestWidgetExtensionStrings.tr("Localizable", "ads.purchase_unavailable")
    /// Remove Ads
    public static let remove = TimeNestWidgetExtensionStrings.tr("Localizable", "ads.remove")
    /// Ads Removed
    public static let removed = TimeNestWidgetExtensionStrings.tr("Localizable", "ads.removed")
    /// Purchases restored
    public static let restoreCompleted = TimeNestWidgetExtensionStrings.tr("Localizable", "ads.restore_completed")
    /// Could not restore purchases. Please try again later.
    public static let restoreFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "ads.restore_failed")
    /// No restorable purchase was found.
    public static let restoreNotFound = TimeNestWidgetExtensionStrings.tr("Localizable", "ads.restore_not_found")
    /// Restore Purchases
    public static let restorePurchases = TimeNestWidgetExtensionStrings.tr("Localizable", "ads.restore_purchases")
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

  public enum CalendarSharing: Sendable {
    /// Add People
    public static let addPeople = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.add_people")
    /// Shared Calendar Name
    public static let calendarName = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.calendar_name")
    /// Create
    public static let createAction = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.create_action")
    /// Create Shared Calendar
    public static let createCalendar = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.create_calendar")
    /// %1$@ to %2$@
    public static func dateRangeFormat(_ p1: Any, _ p2: Any) -> String {
      return TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.date_range_format",String(describing: p1), String(describing: p2))
    }
    /// My Shared Calendar
    public static let defaultCalendarName = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.default_calendar_name")
    /// %@'s Shared Calendar
    public static func defaultNameWithOwner(_ p1: Any) -> String {
      return TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.default_name_with_owner",String(describing: p1))
    }
    /// Delete
    public static let deleteAction = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.delete_action")
    /// Delete Shared Calendar
    public static let deleteCalendar = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.delete_calendar")
    /// Invited members will no longer be able to view this calendar.
    public static let deleteConfirmationMessage = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.delete_confirmation_message")
    /// Delete this shared calendar?
    public static let deleteConfirmationTitle = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.delete_confirmation_title")
    /// Edit Shared Calendar
    public static let editCalendar = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.edit_calendar")
    /// After creating the shared calendar,\nyou can invite people from the iCloud sharing sheet.
    public static let inviteAfterCreation = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.invite_after_creation")
    /// People to Invite
    public static let invitePeople = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.invite_people")
    /// Last Successful Sync
    public static let lastSuccessfulSync = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.last_successful_sync")
    /// Leave Share
    public static let leave = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.leave")
    /// This shared calendar will be removed from TimeNest. The owner's data will not be affected.
    public static let leaveConfirmation = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.leave_confirmation")
    /// My Calendar
    public static let myCalendar = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.my_calendar")
    /// No shared calendars
    public static let noSharedCalendars = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.no_shared_calendars")
    /// Shared Calendars
    public static let ownedCalendars = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.owned_calendars")
    /// Owner
    public static let owner = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.owner")
    /// View Only
    public static let readOnly = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.read_only")
    /// Shared Calendar Details
    public static let receivedDetails = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.received_details")
    /// Retry
    public static let retry = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.retry")
    /// Save
    public static let saveAction = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.save_action")
    /// Choose Calendar
    public static let selectCalendar = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.select_calendar")
    /// Shared by an iCloud user
    public static let sharedByIcloudUser = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.shared_by_icloud_user")
    /// Shared by %@
    public static func sharedByOwner(_ p1: Any) -> String {
      return TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.shared_by_owner",String(describing: p1))
    }
    /// People You Share With
    public static let sharedPeople = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.shared_people")
    /// %1$@ · View Only
    public static func statusFormat(_ p1: Any) -> String {
      return TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.status_format",String(describing: p1))
    }
    /// Sync Again Now
    public static let syncNow = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.sync_now")
    /// Shared Calendar
    public static let unknownCalendar = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.unknown_calendar")
    /// Participant
    public static let unknownPerson = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.unknown_person")
    /// You
    public static let you = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.you")

    public enum Content: Sendable {
      /// Events, shifts, and work records in this calendar are shared automatically. Memos, notifications, hourly rates, transport costs, and pay information are not shared. Recipients have read-only access.
      public static let privacyNote = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.content.privacy_note")
    }

    public enum Error: Sendable {
      /// This invitation belongs to a different TimeNest iCloud container or build environment.
      public static let cloudEnvironmentMismatch = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.cloud_environment_mismatch")
      /// This is not a TimeNest sharing link.
      public static let containerMismatch = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.container_mismatch")
      /// Sharing could not be started. Try again later.
      public static let creationFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.creation_failed")
      /// Calendar data could not be migrated. The original data was not deleted. Restart the app to try again.
      public static let dataMigrationFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.data_migration_failed")
      /// iCloud sharing is not available on this device.
      public static let icloudRestricted = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.icloud_restricted")
      /// Sign in to iCloud to use calendar sharing.
      public static let icloudSignInRequired = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.icloud_sign_in_required")
      /// The iCloud status cannot be determined right now. Try again later.
      public static let icloudStatusUnavailable = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.icloud_status_unavailable")
      /// The shared calendar could not be added. Try again later.
      public static let invitationAcceptanceFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.invitation_acceptance_failed")
      /// The shared calendar was created, but the invitation could not be completed in the sharing sheet. You can invite again from Edit Shared Calendar.
      public static let invitationActivityFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.invitation_activity_failed")
      /// The invitation could not be revoked. Try again later.
      public static let invitationCancellationFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.invitation_cancellation_failed")
      /// Couldn't create the sharing invitation. Try again later.
      public static let invitationCreationFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.invitation_creation_failed")
      /// This sharing invitation is invalid or can no longer be opened.
      public static let invitationInvalid = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.invitation_invalid")
      /// The sharing invitation has not been accepted yet.
      public static let invitationPending = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.invitation_pending")
      /// The owner revoked this sharing invitation.
      public static let invitationRevoked = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.invitation_revoked")
      /// This sharing link is unavailable or has been revoked.
      public static let invitationUnavailable = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.invitation_unavailable")
      /// Enter an iCloud sharing link.
      public static let invitationUrlEmpty = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.invitation_url_empty")
      /// The shared link format is invalid.
      public static let invitationUrlInvalid = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.invitation_url_invalid")
      /// Couldn't get the sharing link. Try again later.
      public static let invitationUrlUnavailable = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.invitation_url_unavailable")
      /// Your existing data could not be moved to the current storage location. The original data is still safe. Close and reopen the app to retry; editing is disabled until migration succeeds.
      public static let legacyStoreMigrationFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.legacy_store_migration_failed")
      /// The sharing link could not be verified. Try again later.
      public static let metadataFetchFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.metadata_fetch_failed")
      /// The network is unavailable. Check your connection and try again.
      public static let networkUnavailable = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.network_unavailable")
      /// Check that this is an iCloud sharing link.
      public static let notCloudkitShare = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.not_cloudkit_share")
      /// You do not have permission to access this shared calendar.
      public static let permissionDenied = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.permission_denied")
      /// The invitation was accepted, but the shared calendar could not be refreshed. TimeNest will retry when it becomes active.
      public static let receivedCalendarRefreshFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.received_calendar_refresh_failed")
      /// iCloud sharing is temporarily unavailable.
      public static let serviceTemporarilyUnavailable = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.service_temporarily_unavailable")
      /// This shared calendar is no longer available. TimeNest returned to My Calendar.
      public static let shareUnavailable = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.share_unavailable")
      /// Calendar sync failed. Try again later.
      public static let syncFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.sync_failed")
      /// Sharing Error
      public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.error.title")
    }

    public enum IcloudStatus: Sendable {
      /// Available
      public static let available = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.icloud_status.available")
      /// Checking
      public static let checking = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.icloud_status.checking")
      /// Not signed in to iCloud
      public static let noAccount = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.icloud_status.no_account")
      /// Open System Settings
      public static let openSettings = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.icloud_status.open_settings")
      /// Network or iCloud check failed
      public static let requestFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.icloud_status.request_failed")
      /// Account restricted
      public static let restricted = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.icloud_status.restricted")
      /// Temporarily unavailable
      public static let temporarilyUnavailable = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.icloud_status.temporarily_unavailable")
      /// iCloud Status
      public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.icloud_status.title")
      /// Cannot be determined right now
      public static let unknown = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.icloud_status.unknown")
    }

    public enum Invitation: Sendable {
      /// Shared calendar added.
      public static let accepted = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.invitation.accepted")
      /// This shared calendar has already been added.
      public static let alreadyAccepted = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.invitation.already_accepted")
      /// Preparing Sharing Invitation
      public static let preparing = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.invitation.preparing")
      /// Revoke Invitation
      public static let revokeAction = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.invitation.revoke_action")

      public enum LinkInput: Sendable {
        /// Copy and paste the iCloud sharing link you received in LINE or another app.
        public static let hint = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.invitation.link_input.hint")
        /// iCloud sharing link
        public static let placeholder = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.invitation.link_input.placeholder")
        /// Add
        public static let submit = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.invitation.link_input.submit")
        /// Enter Shared Link
        public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.invitation.link_input.title")
      }

      public enum RevokeConfirmation: Sendable {
        /// The pending invitation will stop working. This does not stop sharing with people who already accepted.
        public static let message = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.invitation.revoke_confirmation.message")
        /// Revoke This Invitation?
        public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.invitation.revoke_confirmation.title")
      }
    }

    public enum LastSuccessfulSync: Sendable {
      /// Not yet synced
      public static let never = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.last_successful_sync.never")
    }

    public enum Settings: Sendable {
      /// Shared Calendars
      public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.settings.title")
    }

    public enum State: Sendable {
      /// Sync failed
      public static let failed = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.state.failed")
      /// Not shared
      public static let notShared = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.state.not_shared")
      /// Shared
      public static let shared = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.state.shared")
      /// Syncing
      public static let syncing = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.state.syncing")
      /// Sharing unavailable
      public static let unavailable = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.state.unavailable")
      /// Invitation created, awaiting acceptance
      public static let waiting = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.state.waiting")
    }

    public enum Switch: Sendable {
      /// Double-tap to switch calendars
      public static let accessibilityHint = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.switch.accessibility_hint")
      /// Displayed calendar
      public static let accessibilityLabel = TimeNestWidgetExtensionStrings.tr("Localizable", "calendar_sharing.switch.accessibility_label")
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

  public enum DataManagement: Sendable {
  
    public enum Backup: Sendable {
      /// Create Backup
      public static let create = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.backup.create")
      /// The backup could not be created.
      public static let createFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.backup.create_failed")
      /// This file is not a valid TimeNest backup.
      public static let invalidFile = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.backup.invalid_file")
      /// Restore from Backup
      public static let restore = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.backup.restore")
      /// The backup could not be restored. Your current data was not changed.
      public static let restoreFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.backup.restore_failed")
    }

    public enum Csv: Sendable {
      /// Export Work Records as CSV
      public static let export = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.csv.export")
      /// Export
      public static let exportAction = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.csv.export_action")
      /// The work records could not be exported.
      public static let exportFailed = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.csv.export_failed")
      /// Export Work Records
      public static let exportTitle = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.csv.export_title")
      /// Month
      public static let month = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.csv.month")
      /// There are no work records to export for the selected month.
      public static let noData = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.csv.no_data")

      public enum Column: Sendable {
        /// Date
        public static let date = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.csv.column.date")
        /// End Time
        public static let endTime = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.csv.column.end_time")
        /// Notes
        public static let note = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.csv.column.note")
        /// Work Record Name
        public static let recordName = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.csv.column.record_name")
        /// Break Time
        public static let restTime = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.csv.column.rest_time")
        /// Start Time
        public static let startTime = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.csv.column.start_time")
        /// Actual Work Time
        public static let workedTime = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.csv.column.worked_time")
      }
    }

    public enum Restore: Sendable {
      /// The backup was restored.
      public static let success = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.restore.success")

      public enum Confirmation: Sendable {
        /// Replace and Restore
        public static let action = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.restore.confirmation.action")
        /// Your current events, shifts, and work records will be replaced with the backup. This cannot be undone.
        public static let message = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.restore.confirmation.message")
        /// Replace Current Data?
        public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "data_management.restore.confirmation.title")
      }
    }
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
    /// Clock In
    public static let workIn = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.workIn")
    /// Clock Out
    public static let workOut = TimeNestWidgetExtensionStrings.tr("Localizable", "editor.workOut")
  }

  public enum Entry: Sendable {
  
    public enum Create: Sendable {
      /// New Entry
      public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "entry.create.title")
    }

    public enum Kind: Sendable {
      /// Event
      public static let event = TimeNestWidgetExtensionStrings.tr("Localizable", "entry.kind.event")
      /// Work Record
      public static let workRecord = TimeNestWidgetExtensionStrings.tr("Localizable", "entry.kind.work_record")
    }
  }

  public enum Event: Sendable {
    /// Event
    public static let defaultTitle = TimeNestWidgetExtensionStrings.tr("Localizable", "event.default_title")
    /// Event not found.
    public static let notFound = TimeNestWidgetExtensionStrings.tr("Localizable", "event.not_found")

    public enum Memo: Sendable {
      /// Memo
      public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "event.memo.title")

      public enum Voice: Sendable {
        /// Microphone and speech recognition permission are required to use voice input for memos.
        public static let permissionDenied = TimeNestWidgetExtensionStrings.tr("Localizable", "event.memo.voice.permission_denied")
        /// Enter a memo by voice
        public static let placeholder = TimeNestWidgetExtensionStrings.tr("Localizable", "event.memo.voice.placeholder")
        /// Voice input in progress...
        public static let recognizing = TimeNestWidgetExtensionStrings.tr("Localizable", "event.memo.voice.recognizing")
        /// Start voice input
        public static let start = TimeNestWidgetExtensionStrings.tr("Localizable", "event.memo.voice.start")
        /// Stop voice input
        public static let stop = TimeNestWidgetExtensionStrings.tr("Localizable", "event.memo.voice.stop")
        /// Voice input is not available on this device or for this language.
        public static let unavailable = TimeNestWidgetExtensionStrings.tr("Localizable", "event.memo.voice.unavailable")
      }
    }
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
        /// TimeNest may display ads when the consent flow permits ad requests. Use Remove Ads in Settings for a one-time purchase, and Restore Purchases to check the Apple purchase state.
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
      /// Shared Calendars
      public static let sharing = TimeNestWidgetExtensionStrings.tr("Localizable", "help.category.sharing")
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
        /// Tap the add button at the bottom right of the calendar, enter the details, and save. The memo field also supports voice input on supported devices and languages.
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
        /// You do not need to register an account or sign in to use TimeNest. TimeNest has no developer-operated cloud sync; shared calendars use Apple's iCloud (CloudKit).
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.privacy.account.answer")
        /// Do I need an account?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.privacy.account.question")
      }

      public enum DeleteApp: Sendable {
        /// Deleting the app also removes TimeNest data stored on the device under normal iOS behavior.
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
        /// Events, shifts, work records, display settings, and holiday settings are stored on this device. Calendar information needed for Widgets is shared only on this device through the App Group.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.privacy.storage.answer")
        /// Where is my data stored?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.privacy.storage.question")
      }
    }

    public enum Sharing: Sendable {
    
      public enum Accept: Sendable {
        /// Open the invitation link on a device signed in to iCloud and accept the share. A device without usable iCloud or CloudKit access may not be able to accept it. Accepted or refreshed data can take a short time to appear.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.sharing.accept.answer")
        /// How do I accept a sharing invitation?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.sharing.accept.question")
      }

      public enum Content: Sendable {
        /// Events, shifts, and work records in that shared calendar are currently shared automatically and cannot be disabled by category. Event titles and times, plus work-record clock-in, clock-out, and break times, are shared. Memos, reminders and notifications, voice-input content, hourly rates, pay, transport costs, shift templates, settings, and Remove Ads purchase state are not shared.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.sharing.content.answer")
        /// What is and is not shared?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.sharing.content.question")
      }

      public enum Create: Sendable {
        /// Tap the calendar icon at the top left, then choose Create Shared Calendar. Enter a name and tap Create to open the iCloud sharing sheet. After creation, use the pencil button to rename it and Add People to send another invitation.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.sharing.create.answer")
        /// How do I create or edit a shared calendar?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.sharing.create.question")
      }

      public enum ReadOnlyHolidays: Sendable {
        /// Recipients can view shared events, shifts, and work records but cannot edit them. Holidays are not shared through CloudKit; they come from the regions enabled and cached locally on the recipient's device.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.sharing.read_only_holidays.answer")
        /// Can I edit a shared calendar, and how are holidays shown?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.sharing.read_only_holidays.question")
      }

      public enum Stop: Sendable {
        /// When the owner stops sharing or deletes the shared calendar, recipients can no longer view it. Leaving a share only removes it from the recipient's device and does not affect the owner's data. If a change has not appeared yet, refresh from the calendar chooser.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.sharing.stop.answer")
        /// What happens when sharing is stopped or deleted?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.sharing.stop.question")
      }

      public enum Switch: Sendable {
        /// Tap the calendar icon at the top left and choose My Calendar or one shared calendar. The checkmark identifies the calendar currently displayed. Only one calendar is displayed at a time.
        public static let answer = TimeNestWidgetExtensionStrings.tr("Localizable", "help.sharing.switch.answer")
        /// How do I switch the displayed calendar?
        public static let question = TimeNestWidgetExtensionStrings.tr("Localizable", "help.sharing.switch.question")
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
        /// From a day detail, tap New Work Record, or choose Work Record on the new-entry screen. Enter clock-in and clock-out times, break time, hourly rate, and transport cost; saved records are used in work statistics.
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
    /// Open Settings
    public static let openSettings = TimeNestWidgetExtensionStrings.tr("Localizable", "notification.open_settings")
    /// Notification Time
    public static let time = TimeNestWidgetExtensionStrings.tr("Localizable", "notification.time")

    public enum PermissionDenied: Sendable {
      /// TimeNest needs notification permission to send event reminders. Turn on notifications in iOS Settings.
      public static let message = TimeNestWidgetExtensionStrings.tr("Localizable", "notification.permission_denied.message")
      /// Notifications Are Off
      public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "notification.permission_denied.title")
    }

    public enum ReminderTimePast: Sendable {
      /// The event was saved, but the reminder time has already passed, so no notification was set.
      public static let message = TimeNestWidgetExtensionStrings.tr("Localizable", "notification.reminder_time_past.message")
      /// Reminder Time Has Passed
      public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "notification.reminder_time_past.title")
    }

    public enum ScheduleFailed: Sendable {
      /// The event was saved, but the reminder setup failed.
      public static let message = TimeNestWidgetExtensionStrings.tr("Localizable", "notification.schedule_failed.message")
      /// Reminder Setup Failed
      public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "notification.schedule_failed.title")
    }
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
    /// Customize Calendar Display
    public static let calendarDisplayCustomize = TimeNestWidgetExtensionStrings.tr("Localizable", "settings.calendar_display_customize")
    /// Data Management
    public static let dataManagement = TimeNestWidgetExtensionStrings.tr("Localizable", "settings.data_management")
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

    public enum CalendarDisplayCustomize: Sendable {
      /// Event Background
      public static let eventBackground = TimeNestWidgetExtensionStrings.tr("Localizable", "settings.calendar_display_customize.event_background")
      /// Reset Defaults
      public static let resetDefaults = TimeNestWidgetExtensionStrings.tr("Localizable", "settings.calendar_display_customize.reset_defaults")
      /// Work Record Background
      public static let workRecordBackground = TimeNestWidgetExtensionStrings.tr("Localizable", "settings.calendar_display_customize.work_record_background")
    }
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

  public enum ShiftBatch: Sendable {
    /// Add Rotation Item
    public static let addRotationItem = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.add_rotation_item")
    /// Some reminders or refresh tasks could not be completed.
    public static let auxiliaryFailure = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.auxiliary_failure")
    /// Clear
    public static let clearSelection = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.clear_selection")
    /// %d shifts created
    public static func completed(_ p1: Int) -> String {
      return TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.completed",p1)
    }
    /// Confirm
    public static let confirm = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.confirm")
    /// Copy Previous Day
    public static let copyPreviousDay = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.copy_previous_day")
    /// Copy Previous Week
    public static let copyPreviousWeek = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.copy_previous_week")
    /// Select at least one date.
    public static let emptySelection = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.empty_selection")
    /// End Date
    public static let endDate = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.end_date")
    /// Existing Shift
    public static let existingShift = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.existing_shift")
    /// Invalid Template
    public static let invalidTemplate = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.invalid_template")
    /// Action
    public static let mode = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.mode")
    /// Next month
    public static let nextMonth = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.next_month")
    /// Nothing to Copy
    public static let noSource = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.no_source")
    /// Shift data changed after the preview. Preview again before confirming.
    public static let planChanged = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.plan_changed")
    /// Preview
    public static let preview = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.preview")
    /// Previous month
    public static let previousMonth = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.previous_month")
    /// Remove date
    public static let removeDate = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.remove_date")
    /// Day Off
    public static let restDay = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.rest_day")
    /// Shift Rotation
    public static let rotation = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.rotation")
    /// Starting Position
    public static let rotationStart = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.rotation_start")
    /// %d dates selected
    public static func selectedCount(_ p1: Int) -> String {
      return TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.selected_count",p1)
    }
    /// Skipped
    public static let skipped = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.skipped")
    /// Start Date
    public static let startDate = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.start_date")
    /// Set Shifts in Bulk
    public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.title")
    /// Undo
    public static let undo = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.undo")
    /// %d shifts removed
    public static func undoCompleted(_ p1: Int) -> String {
      return TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.undo_completed",p1)
    }
    /// %d edited shifts could not be undone.
    public static func undoEdited(_ p1: Int) -> String {
      return TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.undo_edited",p1)
    }
    /// Use Template
    public static let useTemplate = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.use_template")
    /// Will Create
    public static let willCreate = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_batch.will_create")
  }

  public enum ShiftInput: Sendable {
    /// No enabled shifts
    public static let empty = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_input.empty")
    /// Shift Input
    public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_input.title")
  }

  public enum ShiftTemplate: Sendable {
    /// Add to favorites
    public static let favorite = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_template.favorite")
    /// Favorite Shifts
    public static let favorites = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_template.favorites")
    /// Remove from favorites
    public static let unfavorite = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_template.unfavorite")

    public enum DeleteConfirmation: Sendable {
      /// This template is used by %d existing shifts. The shifts will remain with their saved details.
      public static func referenced(_ p1: Int) -> String {
        return TimeNestWidgetExtensionStrings.tr("Localizable", "shift_template.delete_confirmation.referenced",p1)
      }
      /// Delete Shift Template?
      public static let title = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_template.delete_confirmation.title")
      /// Existing shifts will not be deleted.
      public static let unused = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_template.delete_confirmation.unused")
    }
  }

  public enum ShiftTime: Sendable {
    /// Add Shift
    public static let addButton = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_time.add_button")
    /// Color
    public static let color = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_time.color")
    /// Delete
    public static let deleteButton = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_time.delete_button")
    /// Detailed Settings
    public static let details = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_time.details")
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

    public enum Details: Sendable {
      /// Collapse detailed settings
      public static let collapse = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_time.details.collapse")
      /// Expand detailed settings
      public static let expand = TimeNestWidgetExtensionStrings.tr("Localizable", "shift_time.details.expand")
    }
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

  public enum WorkClock: Sendable {
    /// In
    public static let shortIn = TimeNestWidgetExtensionStrings.tr("Localizable", "work_clock.short_in")
    /// Out
    public static let shortOut = TimeNestWidgetExtensionStrings.tr("Localizable", "work_clock.short_out")
  }

  public enum WorkRecord: Sendable {
    /// New Work Record
    public static let add = TimeNestWidgetExtensionStrings.tr("Localizable", "work_record.add")
    /// Work
    public static let defaultTitle = TimeNestWidgetExtensionStrings.tr("Localizable", "work_record.default_title")
    /// Edit Work Record
    public static let edit = TimeNestWidgetExtensionStrings.tr("Localizable", "work_record.edit")
    /// No work records
    public static let empty = TimeNestWidgetExtensionStrings.tr("Localizable", "work_record.empty")
    /// No clock-in
    public static let missingClockIn = TimeNestWidgetExtensionStrings.tr("Localizable", "work_record.missing_clock_in")
    /// No clock-out
    public static let missingClockOut = TimeNestWidgetExtensionStrings.tr("Localizable", "work_record.missing_clock_out")
    /// Work Records
    public static let sectionTitle = TimeNestWidgetExtensionStrings.tr("Localizable", "work_record.section_title")
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
