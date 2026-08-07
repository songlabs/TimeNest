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
    /// TimeNest uses the microphone only to enter memo text by voice.
    public static let nsMicrophoneUsageDescription = TimeNestStrings.tr("InfoPlist", "NSMicrophoneUsageDescription")
    /// TimeNest uses speech recognition only to convert your voice into memo text.
    public static let nsSpeechRecognitionUsageDescription = TimeNestStrings.tr("InfoPlist", "NSSpeechRecognitionUsageDescription")
    /// We use the device identifier to deliver and measure advertising.
    public static let nsUserTrackingUsageDescription = TimeNestStrings.tr("InfoPlist", "NSUserTrackingUsageDescription")
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

    public enum Ads: Sendable {
      /// Purchase completed
      public static let purchaseCompleted = TimeNestStrings.tr("Localizable", "ads.purchase_completed")
      /// Purchase could not be completed. Please try again later.
      public static let purchaseFailed = TimeNestStrings.tr("Localizable", "ads.purchase_failed")
      /// Purchase is pending approval. Ads will be hidden after it completes.
      public static let purchasePending = TimeNestStrings.tr("Localizable", "ads.purchase_pending")
      /// Purchases are temporarily unavailable. Please try again later.
      public static let purchaseUnavailable = TimeNestStrings.tr("Localizable", "ads.purchase_unavailable")
      /// Remove Ads
      public static let remove = TimeNestStrings.tr("Localizable", "ads.remove")
      /// Ads Removed
      public static let removed = TimeNestStrings.tr("Localizable", "ads.removed")
      /// Purchases restored
      public static let restoreCompleted = TimeNestStrings.tr("Localizable", "ads.restore_completed")
      /// Could not restore purchases. Please try again later.
      public static let restoreFailed = TimeNestStrings.tr("Localizable", "ads.restore_failed")
      /// No restorable purchase was found.
      public static let restoreNotFound = TimeNestStrings.tr("Localizable", "ads.restore_not_found")
      /// Restore Purchases
      public static let restorePurchases = TimeNestStrings.tr("Localizable", "ads.restore_purchases")
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

    public enum CalendarSharing: Sendable {
      /// Add People
      public static let addPeople = TimeNestStrings.tr("Localizable", "calendar_sharing.add_people")
      /// Shared Calendar Name
      public static let calendarName = TimeNestStrings.tr("Localizable", "calendar_sharing.calendar_name")
      /// Create
      public static let createAction = TimeNestStrings.tr("Localizable", "calendar_sharing.create_action")
      /// Create Shared Calendar
      public static let createCalendar = TimeNestStrings.tr("Localizable", "calendar_sharing.create_calendar")
      /// %1$@ to %2$@
      public static func dateRangeFormat(_ p1: Any, _ p2: Any) -> String {
        return TimeNestStrings.tr("Localizable", "calendar_sharing.date_range_format",String(describing: p1), String(describing: p2))
      }
      /// My Shared Calendar
      public static let defaultCalendarName = TimeNestStrings.tr("Localizable", "calendar_sharing.default_calendar_name")
      /// %@'s Shared Calendar
      public static func defaultNameWithOwner(_ p1: Any) -> String {
        return TimeNestStrings.tr("Localizable", "calendar_sharing.default_name_with_owner",String(describing: p1))
      }
      /// Delete
      public static let deleteAction = TimeNestStrings.tr("Localizable", "calendar_sharing.delete_action")
      /// Delete Shared Calendar
      public static let deleteCalendar = TimeNestStrings.tr("Localizable", "calendar_sharing.delete_calendar")
      /// Invited members will no longer be able to view this calendar.
      public static let deleteConfirmationMessage = TimeNestStrings.tr("Localizable", "calendar_sharing.delete_confirmation_message")
      /// Delete this shared calendar?
      public static let deleteConfirmationTitle = TimeNestStrings.tr("Localizable", "calendar_sharing.delete_confirmation_title")
      /// Edit Shared Calendar
      public static let editCalendar = TimeNestStrings.tr("Localizable", "calendar_sharing.edit_calendar")
      /// Can Edit
      public static let editable = TimeNestStrings.tr("Localizable", "calendar_sharing.editable")
      /// After creating the shared calendar,\nyou can invite people from the iCloud sharing sheet.
      public static let inviteAfterCreation = TimeNestStrings.tr("Localizable", "calendar_sharing.invite_after_creation")
      /// People to Invite
      public static let invitePeople = TimeNestStrings.tr("Localizable", "calendar_sharing.invite_people")
      /// Last Successful Sync
      public static let lastSuccessfulSync = TimeNestStrings.tr("Localizable", "calendar_sharing.last_successful_sync")
      /// Leave Share
      public static let leave = TimeNestStrings.tr("Localizable", "calendar_sharing.leave")
      /// This shared calendar will be removed from TimeNest. The owner's data will not be affected.
      public static let leaveConfirmation = TimeNestStrings.tr("Localizable", "calendar_sharing.leave_confirmation")
      /// My Calendar
      public static let myCalendar = TimeNestStrings.tr("Localizable", "calendar_sharing.my_calendar")
      /// No shared calendars yet
      public static let noSharedCalendars = TimeNestStrings.tr("Localizable", "calendar_sharing.no_shared_calendars")
      /// Create read-only sharing so family or coworkers can view events and shifts.
      public static let noSharedCalendarsMessage = TimeNestStrings.tr("Localizable", "calendar_sharing.no_shared_calendars_message")
      /// Shared Calendars
      public static let ownedCalendars = TimeNestStrings.tr("Localizable", "calendar_sharing.owned_calendars")
      /// Owner
      public static let owner = TimeNestStrings.tr("Localizable", "calendar_sharing.owner")
      /// View Only
      public static let readOnly = TimeNestStrings.tr("Localizable", "calendar_sharing.read_only")
      /// Shared Calendar Details
      public static let receivedDetails = TimeNestStrings.tr("Localizable", "calendar_sharing.received_details")
      /// Retry
      public static let retry = TimeNestStrings.tr("Localizable", "calendar_sharing.retry")
      /// Save
      public static let saveAction = TimeNestStrings.tr("Localizable", "calendar_sharing.save_action")
      /// Choose Calendar
      public static let selectCalendar = TimeNestStrings.tr("Localizable", "calendar_sharing.select_calendar")
      /// Shared by an iCloud user
      public static let sharedByIcloudUser = TimeNestStrings.tr("Localizable", "calendar_sharing.shared_by_icloud_user")
      /// Shared by %@
      public static func sharedByOwner(_ p1: Any) -> String {
        return TimeNestStrings.tr("Localizable", "calendar_sharing.shared_by_owner",String(describing: p1))
      }
      /// People You Share With
      public static let sharedPeople = TimeNestStrings.tr("Localizable", "calendar_sharing.shared_people")
      /// %1$@ · View Only
      public static func statusFormat(_ p1: Any) -> String {
        return TimeNestStrings.tr("Localizable", "calendar_sharing.status_format",String(describing: p1))
      }
      /// Sync Again Now
      public static let syncNow = TimeNestStrings.tr("Localizable", "calendar_sharing.sync_now")
      /// Shared Calendar
      public static let unknownCalendar = TimeNestStrings.tr("Localizable", "calendar_sharing.unknown_calendar")
      /// Participant
      public static let unknownPerson = TimeNestStrings.tr("Localizable", "calendar_sharing.unknown_person")
      /// You
      public static let you = TimeNestStrings.tr("Localizable", "calendar_sharing.you")

      public enum Content: Sendable {
        /// Events, shifts, and work records in this calendar are shared automatically. Memos, notifications, hourly rates, transport costs, and pay information are not shared. Recipients have read-only access.
        public static let privacyNote = TimeNestStrings.tr("Localizable", "calendar_sharing.content.privacy_note")
      }

      public enum Error: Sendable {
        /// This invitation belongs to a different TimeNest iCloud container or build environment.
        public static let cloudEnvironmentMismatch = TimeNestStrings.tr("Localizable", "calendar_sharing.error.cloud_environment_mismatch")
        /// This is not a TimeNest sharing link.
        public static let containerMismatch = TimeNestStrings.tr("Localizable", "calendar_sharing.error.container_mismatch")
        /// Sharing could not be started. Try again later.
        public static let creationFailed = TimeNestStrings.tr("Localizable", "calendar_sharing.error.creation_failed")
        /// Calendar data could not be migrated. The original data was not deleted. Restart the app to try again.
        public static let dataMigrationFailed = TimeNestStrings.tr("Localizable", "calendar_sharing.error.data_migration_failed")
        /// iCloud sharing is not available on this device.
        public static let icloudRestricted = TimeNestStrings.tr("Localizable", "calendar_sharing.error.icloud_restricted")
        /// Sign in to iCloud to use calendar sharing.
        public static let icloudSignInRequired = TimeNestStrings.tr("Localizable", "calendar_sharing.error.icloud_sign_in_required")
        /// The iCloud status cannot be determined right now. Try again later.
        public static let icloudStatusUnavailable = TimeNestStrings.tr("Localizable", "calendar_sharing.error.icloud_status_unavailable")
        /// The shared calendar could not be added. Try again later.
        public static let invitationAcceptanceFailed = TimeNestStrings.tr("Localizable", "calendar_sharing.error.invitation_acceptance_failed")
        /// The shared calendar was created, but the invitation could not be completed in the sharing sheet. You can invite again from Edit Shared Calendar.
        public static let invitationActivityFailed = TimeNestStrings.tr("Localizable", "calendar_sharing.error.invitation_activity_failed")
        /// The invitation could not be revoked. Try again later.
        public static let invitationCancellationFailed = TimeNestStrings.tr("Localizable", "calendar_sharing.error.invitation_cancellation_failed")
        /// Couldn't create the sharing invitation. Try again later.
        public static let invitationCreationFailed = TimeNestStrings.tr("Localizable", "calendar_sharing.error.invitation_creation_failed")
        /// This sharing invitation is invalid or can no longer be opened.
        public static let invitationInvalid = TimeNestStrings.tr("Localizable", "calendar_sharing.error.invitation_invalid")
        /// The sharing invitation has not been accepted yet.
        public static let invitationPending = TimeNestStrings.tr("Localizable", "calendar_sharing.error.invitation_pending")
        /// The owner revoked this sharing invitation.
        public static let invitationRevoked = TimeNestStrings.tr("Localizable", "calendar_sharing.error.invitation_revoked")
        /// This sharing link is unavailable or has been revoked.
        public static let invitationUnavailable = TimeNestStrings.tr("Localizable", "calendar_sharing.error.invitation_unavailable")
        /// Enter an iCloud sharing link.
        public static let invitationUrlEmpty = TimeNestStrings.tr("Localizable", "calendar_sharing.error.invitation_url_empty")
        /// The shared link format is invalid.
        public static let invitationUrlInvalid = TimeNestStrings.tr("Localizable", "calendar_sharing.error.invitation_url_invalid")
        /// Couldn't get the sharing link. Try again later.
        public static let invitationUrlUnavailable = TimeNestStrings.tr("Localizable", "calendar_sharing.error.invitation_url_unavailable")
        /// Your existing data could not be moved to the current storage location. The original data is still safe. Close and reopen the app to retry; editing is disabled until migration succeeds.
        public static let legacyStoreMigrationFailed = TimeNestStrings.tr("Localizable", "calendar_sharing.error.legacy_store_migration_failed")
        /// The sharing link could not be verified. Try again later.
        public static let metadataFetchFailed = TimeNestStrings.tr("Localizable", "calendar_sharing.error.metadata_fetch_failed")
        /// The network is unavailable. Check your connection and try again.
        public static let networkUnavailable = TimeNestStrings.tr("Localizable", "calendar_sharing.error.network_unavailable")
        /// Check that this is an iCloud sharing link.
        public static let notCloudkitShare = TimeNestStrings.tr("Localizable", "calendar_sharing.error.not_cloudkit_share")
        /// You do not have permission to access this shared calendar.
        public static let permissionDenied = TimeNestStrings.tr("Localizable", "calendar_sharing.error.permission_denied")
        /// The invitation was accepted, but the shared calendar could not be refreshed. TimeNest will retry when it becomes active.
        public static let receivedCalendarRefreshFailed = TimeNestStrings.tr("Localizable", "calendar_sharing.error.received_calendar_refresh_failed")
        /// iCloud sharing is temporarily unavailable.
        public static let serviceTemporarilyUnavailable = TimeNestStrings.tr("Localizable", "calendar_sharing.error.service_temporarily_unavailable")
        /// This shared calendar is no longer available. TimeNest returned to My Calendar.
        public static let shareUnavailable = TimeNestStrings.tr("Localizable", "calendar_sharing.error.share_unavailable")
        /// Another participant deleted this event.
        public static let sharedEventDeleted = TimeNestStrings.tr("Localizable", "calendar_sharing.error.shared_event_deleted")
        /// Event editing permission was revoked. Your draft remains on this device.
        public static let sharedEventPermissionRevoked = TimeNestStrings.tr("Localizable", "calendar_sharing.error.shared_event_permission_revoked")
        /// Calendar sync failed. Try again later.
        public static let syncFailed = TimeNestStrings.tr("Localizable", "calendar_sharing.error.sync_failed")
        /// Sharing Error
        public static let title = TimeNestStrings.tr("Localizable", "calendar_sharing.error.title")
      }

      public enum EventEditing: Sendable {
        /// Allow Event Editing
        public static let allowed = TimeNestStrings.tr("Localizable", "calendar_sharing.event_editing.allowed")
        /// Event Editing
        public static let permission = TimeNestStrings.tr("Localizable", "calendar_sharing.event_editing.permission")
      }

      public enum EventSync: Sendable {
        /// Another Participant Deleted This Event
        public static let deleted = TimeNestStrings.tr("Localizable", "calendar_sharing.event_sync.deleted")
        /// Sync Failed
        public static let failed = TimeNestStrings.tr("Localizable", "calendar_sharing.event_sync.failed")
        /// The most recently saved version takes priority.
        public static let lastWriteWins = TimeNestStrings.tr("Localizable", "calendar_sharing.event_sync.last_write_wins")
        /// Waiting to Sync
        public static let pending = TimeNestStrings.tr("Localizable", "calendar_sharing.event_sync.pending")
        /// Editing Permission Was Revoked
        public static let permissionRevoked = TimeNestStrings.tr("Localizable", "calendar_sharing.event_sync.permission_revoked")
        /// Saving
        public static let saving = TimeNestStrings.tr("Localizable", "calendar_sharing.event_sync.saving")
        /// Synced
        public static let synced = TimeNestStrings.tr("Localizable", "calendar_sharing.event_sync.synced")
      }

      public enum IcloudStatus: Sendable {
        /// Available
        public static let available = TimeNestStrings.tr("Localizable", "calendar_sharing.icloud_status.available")
        /// Checking
        public static let checking = TimeNestStrings.tr("Localizable", "calendar_sharing.icloud_status.checking")
        /// Not signed in to iCloud
        public static let noAccount = TimeNestStrings.tr("Localizable", "calendar_sharing.icloud_status.no_account")
        /// Open System Settings
        public static let openSettings = TimeNestStrings.tr("Localizable", "calendar_sharing.icloud_status.open_settings")
        /// Network or iCloud check failed
        public static let requestFailed = TimeNestStrings.tr("Localizable", "calendar_sharing.icloud_status.request_failed")
        /// Account restricted
        public static let restricted = TimeNestStrings.tr("Localizable", "calendar_sharing.icloud_status.restricted")
        /// Temporarily unavailable
        public static let temporarilyUnavailable = TimeNestStrings.tr("Localizable", "calendar_sharing.icloud_status.temporarily_unavailable")
        /// iCloud Status
        public static let title = TimeNestStrings.tr("Localizable", "calendar_sharing.icloud_status.title")
        /// Cannot be determined right now
        public static let unknown = TimeNestStrings.tr("Localizable", "calendar_sharing.icloud_status.unknown")
      }

      public enum Invitation: Sendable {
        /// Shared calendar added.
        public static let accepted = TimeNestStrings.tr("Localizable", "calendar_sharing.invitation.accepted")
        /// This shared calendar has already been added.
        public static let alreadyAccepted = TimeNestStrings.tr("Localizable", "calendar_sharing.invitation.already_accepted")
        /// Preparing Sharing Invitation
        public static let preparing = TimeNestStrings.tr("Localizable", "calendar_sharing.invitation.preparing")
        /// Revoke Invitation
        public static let revokeAction = TimeNestStrings.tr("Localizable", "calendar_sharing.invitation.revoke_action")

        public enum LinkInput: Sendable {
          /// Copy and paste the iCloud sharing link you received in LINE or another app.
          public static let hint = TimeNestStrings.tr("Localizable", "calendar_sharing.invitation.link_input.hint")
          /// iCloud sharing link
          public static let placeholder = TimeNestStrings.tr("Localizable", "calendar_sharing.invitation.link_input.placeholder")
          /// Add
          public static let submit = TimeNestStrings.tr("Localizable", "calendar_sharing.invitation.link_input.submit")
          /// Enter Shared Link
          public static let title = TimeNestStrings.tr("Localizable", "calendar_sharing.invitation.link_input.title")
        }

        public enum RevokeConfirmation: Sendable {
          /// The pending invitation will stop working. This does not stop sharing with people who already accepted.
          public static let message = TimeNestStrings.tr("Localizable", "calendar_sharing.invitation.revoke_confirmation.message")
          /// Revoke This Invitation?
          public static let title = TimeNestStrings.tr("Localizable", "calendar_sharing.invitation.revoke_confirmation.title")
        }
      }

      public enum LastSuccessfulSync: Sendable {
        /// Not yet synced
        public static let never = TimeNestStrings.tr("Localizable", "calendar_sharing.last_successful_sync.never")
      }

      public enum ReadOnlyAdd: Sendable {
        /// This shared calendar is read-only. To add an event or work record, switch to a calendar you can edit.
        public static let message = TimeNestStrings.tr("Localizable", "calendar_sharing.read_only_add.message")
        /// Read-Only Calendar
        public static let title = TimeNestStrings.tr("Localizable", "calendar_sharing.read_only_add.title")
      }

      public enum Settings: Sendable {
        /// Shared Calendars
        public static let title = TimeNestStrings.tr("Localizable", "calendar_sharing.settings.title")
      }

      public enum SharedEvent: Sendable {
        /// Edit Event
        public static let editTitle = TimeNestStrings.tr("Localizable", "calendar_sharing.shared_event.edit_title")
        /// Add Event
        public static let newTitle = TimeNestStrings.tr("Localizable", "calendar_sharing.shared_event.new_title")
      }

      public enum State: Sendable {
        /// Sync failed
        public static let failed = TimeNestStrings.tr("Localizable", "calendar_sharing.state.failed")
        /// Not shared
        public static let notShared = TimeNestStrings.tr("Localizable", "calendar_sharing.state.not_shared")
        /// Shared
        public static let shared = TimeNestStrings.tr("Localizable", "calendar_sharing.state.shared")
        /// Syncing
        public static let syncing = TimeNestStrings.tr("Localizable", "calendar_sharing.state.syncing")
        /// Sharing unavailable
        public static let unavailable = TimeNestStrings.tr("Localizable", "calendar_sharing.state.unavailable")
        /// Invitation created, awaiting acceptance
        public static let waiting = TimeNestStrings.tr("Localizable", "calendar_sharing.state.waiting")
      }

      public enum Switch: Sendable {
        /// Double-tap to switch calendars
        public static let accessibilityHint = TimeNestStrings.tr("Localizable", "calendar_sharing.switch.accessibility_hint")
        /// Displayed calendar
        public static let accessibilityLabel = TimeNestStrings.tr("Localizable", "calendar_sharing.switch.accessibility_label")
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

    public enum DataManagement: Sendable {
    
      public enum Backup: Sendable {
        /// Create Backup
        public static let create = TimeNestStrings.tr("Localizable", "data_management.backup.create")
        /// The backup could not be created.
        public static let createFailed = TimeNestStrings.tr("Localizable", "data_management.backup.create_failed")
        /// This file is not a valid TimeNest backup.
        public static let invalidFile = TimeNestStrings.tr("Localizable", "data_management.backup.invalid_file")
        /// Restore from Backup
        public static let restore = TimeNestStrings.tr("Localizable", "data_management.backup.restore")
        /// The backup could not be restored. Your current data was not changed.
        public static let restoreFailed = TimeNestStrings.tr("Localizable", "data_management.backup.restore_failed")
      }

      public enum Csv: Sendable {
        /// Export Work Records as CSV
        public static let export = TimeNestStrings.tr("Localizable", "data_management.csv.export")
        /// Export
        public static let exportAction = TimeNestStrings.tr("Localizable", "data_management.csv.export_action")
        /// The work records could not be exported.
        public static let exportFailed = TimeNestStrings.tr("Localizable", "data_management.csv.export_failed")
        /// Export Work Records
        public static let exportTitle = TimeNestStrings.tr("Localizable", "data_management.csv.export_title")
        /// Month
        public static let month = TimeNestStrings.tr("Localizable", "data_management.csv.month")
        /// There are no work records to export for the selected month.
        public static let noData = TimeNestStrings.tr("Localizable", "data_management.csv.no_data")

        public enum Column: Sendable {
          /// Date
          public static let date = TimeNestStrings.tr("Localizable", "data_management.csv.column.date")
          /// End Time
          public static let endTime = TimeNestStrings.tr("Localizable", "data_management.csv.column.end_time")
          /// Notes
          public static let note = TimeNestStrings.tr("Localizable", "data_management.csv.column.note")
          /// Work Record Name
          public static let recordName = TimeNestStrings.tr("Localizable", "data_management.csv.column.record_name")
          /// Break Time
          public static let restTime = TimeNestStrings.tr("Localizable", "data_management.csv.column.rest_time")
          /// Start Time
          public static let startTime = TimeNestStrings.tr("Localizable", "data_management.csv.column.start_time")
          /// Actual Work Time
          public static let workedTime = TimeNestStrings.tr("Localizable", "data_management.csv.column.worked_time")
        }
      }

      public enum Restore: Sendable {
        /// The backup was restored.
        public static let success = TimeNestStrings.tr("Localizable", "data_management.restore.success")

        public enum Confirmation: Sendable {
          /// Replace and Restore
          public static let action = TimeNestStrings.tr("Localizable", "data_management.restore.confirmation.action")
          /// Your current events, shifts, and work records will be replaced with the backup. This cannot be undone.
          public static let message = TimeNestStrings.tr("Localizable", "data_management.restore.confirmation.message")
          /// Replace Current Data?
          public static let title = TimeNestStrings.tr("Localizable", "data_management.restore.confirmation.title")
        }
      }
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
      /// JPY
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
      /// Clock In
      public static let workIn = TimeNestStrings.tr("Localizable", "editor.workIn")
      /// Clock Out
      public static let workOut = TimeNestStrings.tr("Localizable", "editor.workOut")
    }

    public enum Entry: Sendable {
    
      public enum Add: Sendable {
        /// Add Event
        public static let event = TimeNestStrings.tr("Localizable", "entry.add.event")
        /// Add Work Record
        public static let workRecord = TimeNestStrings.tr("Localizable", "entry.add.work_record")
      }

      public enum Create: Sendable {
        /// New Entry
        public static let title = TimeNestStrings.tr("Localizable", "entry.create.title")
      }

      public enum Edit: Sendable {
        /// Edit Entry
        public static let title = TimeNestStrings.tr("Localizable", "entry.edit.title")
      }

      public enum Kind: Sendable {
        /// Event
        public static let event = TimeNestStrings.tr("Localizable", "entry.kind.event")
        /// Work Record
        public static let workRecord = TimeNestStrings.tr("Localizable", "entry.kind.work_record")
      }

      public enum Linked: Sendable {
        /// The linked entry contains duplicate records.
        public static let duplicateRecords = TimeNestStrings.tr("Localizable", "entry.linked.duplicate_records")
        /// The linked event couldn’t be loaded.
        public static let eventLoadFailed = TimeNestStrings.tr("Localizable", "entry.linked.event_load_failed")
        /// The linked entry data is invalid.
        public static let invalidGroup = TimeNestStrings.tr("Localizable", "entry.linked.invalid_group")
        /// The entry changed. Reopen it and try again.
        public static let reopen = TimeNestStrings.tr("Localizable", "entry.linked.reopen")
        /// The linked work record couldn’t be loaded.
        public static let workRecordLoadFailed = TimeNestStrings.tr("Localizable", "entry.linked.work_record_load_failed")
      }

      public enum Save: Sendable {
        /// Couldn’t save the entry: %@
        public static func failedFormat(_ p1: Any) -> String {
          return TimeNestStrings.tr("Localizable", "entry.save.failed_format",String(describing: p1))
        }
      }

      public enum Validation: Sendable {
        /// Enable an event or work record before saving.
        public static let enableAtLeastOne = TimeNestStrings.tr("Localizable", "entry.validation.enable_at_least_one")
      }
    }

    public enum Event: Sendable {
      /// Event
      public static let defaultTitle = TimeNestStrings.tr("Localizable", "event.default_title")
      /// Event not found.
      public static let notFound = TimeNestStrings.tr("Localizable", "event.not_found")

      public enum Memo: Sendable {
        /// Memo
        public static let title = TimeNestStrings.tr("Localizable", "event.memo.title")

        public enum Voice: Sendable {
          /// Microphone and speech recognition permission are required to use voice input for memos.
          public static let permissionDenied = TimeNestStrings.tr("Localizable", "event.memo.voice.permission_denied")
          /// Enter a memo by voice
          public static let placeholder = TimeNestStrings.tr("Localizable", "event.memo.voice.placeholder")
          /// Voice input in progress...
          public static let recognizing = TimeNestStrings.tr("Localizable", "event.memo.voice.recognizing")
          /// Start voice input
          public static let start = TimeNestStrings.tr("Localizable", "event.memo.voice.start")
          /// Stop voice input
          public static let stop = TimeNestStrings.tr("Localizable", "event.memo.voice.stop")
          /// Voice input is not available on this device or for this language.
          public static let unavailable = TimeNestStrings.tr("Localizable", "event.memo.voice.unavailable")
        }
      }
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

    public enum Help: Sendable {
      /// Contact Us
      public static let contact = TimeNestStrings.tr("Localizable", "help.contact")
      /// Copy Email Address
      public static let copyEmail = TimeNestStrings.tr("Localizable", "help.copy_email")
      /// Frequently Asked Questions
      public static let frequentlyAskedQuestions = TimeNestStrings.tr("Localizable", "help.frequently_asked_questions")
      /// Help
      public static let title = TimeNestStrings.tr("Localizable", "help.title")

      public enum Ads: Sendable {
      
        public enum About: Sendable {
          /// TimeNest may display ads when the consent flow permits ad requests. Use Remove Ads in Settings for a one-time purchase, and Restore Purchases to check the Apple purchase state.
          public static let answer = TimeNestStrings.tr("Localizable", "help.ads.about.answer")
          /// About ads
          public static let question = TimeNestStrings.tr("Localizable", "help.ads.about.question")
        }
      }

      public enum Category: Sendable {
        /// Ads
        public static let ads = TimeNestStrings.tr("Localizable", "help.category.ads")
        /// Adding and Editing Events
        public static let events = TimeNestStrings.tr("Localizable", "help.category.events")
        /// Holidays and Days Off
        public static let holidays = TimeNestStrings.tr("Localizable", "help.category.holidays")
        /// Data and Privacy
        public static let privacy = TimeNestStrings.tr("Localizable", "help.category.privacy")
        /// Shared Calendars
        public static let sharing = TimeNestStrings.tr("Localizable", "help.category.sharing")
        /// Shifts and Work Records
        public static let shifts = TimeNestStrings.tr("Localizable", "help.category.shifts")
        /// Month, Week, and Day Views
        public static let views = TimeNestStrings.tr("Localizable", "help.category.views")
      }

      public enum Contact: Sendable {
        /// \n\n---\nApp version: %@\nBuild number: %@\niOS version: %@\nLanguage: %@
        public static func emailBody(_ p1: Any, _ p2: Any, _ p3: Any, _ p4: Any) -> String {
          return TimeNestStrings.tr("Localizable", "help.contact.email_body",String(describing: p1), String(describing: p2), String(describing: p3), String(describing: p4))
        }
        /// TimeNest Support Request
        public static let emailSubject = TimeNestStrings.tr("Localizable", "help.contact.email_subject")
      }

      public enum Events: Sendable {
      
        public enum Add: Sendable {
          /// Tap the add button at the bottom right of a calendar you can edit, enter the details, and save. The displayed calendar is assigned automatically, and editing keeps the entry in its original calendar. The memo field also supports voice input on supported devices and languages.
          public static let answer = TimeNestStrings.tr("Localizable", "help.events.add.answer")
          /// How do I add an event?
          public static let question = TimeNestStrings.tr("Localizable", "help.events.add.question")
        }

        public enum AllDay: Sendable {
          /// It is shown for the whole day without a specific start or end time.
          public static let answer = TimeNestStrings.tr("Localizable", "help.events.all_day.answer")
          /// What is an all-day event?
          public static let question = TimeNestStrings.tr("Localizable", "help.events.all_day.question")
        }

        public enum EditDelete: Sendable {
          /// Open the day's event details, tap an event to edit it, or use the delete button.
          public static let answer = TimeNestStrings.tr("Localizable", "help.events.edit_delete.answer")
          /// How do I edit or delete an event?
          public static let question = TimeNestStrings.tr("Localizable", "help.events.edit_delete.question")
        }
      }

      public enum Holidays: Sendable {
      
        public enum Language: Sendable {
          /// Holiday names are shown in the language associated with the selected region.
          public static let answer = TimeNestStrings.tr("Localizable", "help.holidays.language.answer")
          /// What language are holiday names shown in?
          public static let question = TimeNestStrings.tr("Localizable", "help.holidays.language.question")
        }

        public enum Missing: Sendable {
          /// Check the region's subscription status and refresh it on the holiday settings screen.
          public static let answer = TimeNestStrings.tr("Localizable", "help.holidays.missing.answer")
          /// What if holidays do not appear?
          public static let question = TimeNestStrings.tr("Localizable", "help.holidays.missing.question")
        }

        public enum Show: Sendable {
          /// Enable the region you want to display under Holidays in Settings.
          public static let answer = TimeNestStrings.tr("Localizable", "help.holidays.show.answer")
          /// How do I show holidays?
          public static let question = TimeNestStrings.tr("Localizable", "help.holidays.show.question")
        }
      }

      public enum MailUnavailable: Sendable {
        /// Mail could not be opened. Copy %@ and contact us manually.
        public static func message(_ p1: Any) -> String {
          return TimeNestStrings.tr("Localizable", "help.mail_unavailable.message",String(describing: p1))
        }
        /// Unable to Open Mail
        public static let title = TimeNestStrings.tr("Localizable", "help.mail_unavailable.title")
      }

      public enum Privacy: Sendable {
      
        public enum Account: Sendable {
          /// You do not need to register an account or sign in to use TimeNest. TimeNest has no developer-operated cloud sync; shared calendars use Apple's iCloud (CloudKit).
          public static let answer = TimeNestStrings.tr("Localizable", "help.privacy.account.answer")
          /// Do I need an account?
          public static let question = TimeNestStrings.tr("Localizable", "help.privacy.account.question")
        }

        public enum DeleteApp: Sendable {
          /// Deleting the app also removes TimeNest data stored on the device under normal iOS behavior.
          public static let answer = TimeNestStrings.tr("Localizable", "help.privacy.delete_app.answer")
          /// What happens to data if I delete the app?
          public static let question = TimeNestStrings.tr("Localizable", "help.privacy.delete_app.question")
        }

        public enum Options: Sendable {
          /// Manage Ad Privacy Options
          public static let action = TimeNestStrings.tr("Localizable", "help.privacy.options.action")
          /// Review or change the advertising privacy choices for this device.
          public static let description = TimeNestStrings.tr("Localizable", "help.privacy.options.description")
          /// Please try again later.
          public static let errorMessage = TimeNestStrings.tr("Localizable", "help.privacy.options.error_message")
          /// Privacy Options Unavailable
          public static let errorTitle = TimeNestStrings.tr("Localizable", "help.privacy.options.error_title")
        }

        public enum Storage: Sendable {
          /// Events, shifts, work records, display settings, and holiday settings are stored on this device. Calendar information needed for Widgets is shared only on this device through the App Group.
          public static let answer = TimeNestStrings.tr("Localizable", "help.privacy.storage.answer")
          /// Where is my data stored?
          public static let question = TimeNestStrings.tr("Localizable", "help.privacy.storage.question")
        }
      }

      public enum Sharing: Sendable {
      
        public enum Accept: Sendable {
          /// Open the invitation link on a device signed in to iCloud and accept the share. A device without usable iCloud or CloudKit access may not be able to accept it. Accepted or refreshed data can take a short time to appear.
          public static let answer = TimeNestStrings.tr("Localizable", "help.sharing.accept.answer")
          /// How do I accept a sharing invitation?
          public static let question = TimeNestStrings.tr("Localizable", "help.sharing.accept.question")
        }

        public enum Content: Sendable {
          /// Events, shifts, and work records in that shared calendar are currently shared automatically and cannot be disabled by category. Event titles and times, plus work-record clock-in, clock-out, and break times, are shared. Memos, reminders and notifications, voice-input content, hourly rates, pay, transport costs, shift templates, settings, and Remove Ads purchase state are not shared.
          public static let answer = TimeNestStrings.tr("Localizable", "help.sharing.content.answer")
          /// What is and is not shared?
          public static let question = TimeNestStrings.tr("Localizable", "help.sharing.content.question")
        }

        public enum Create: Sendable {
          /// Tap the calendar icon at the top left, then choose Create Shared Calendar. Enter a name and tap Create to open the iCloud sharing sheet. After creation, use the pencil button to rename it and Add People to send another invitation.
          public static let answer = TimeNestStrings.tr("Localizable", "help.sharing.create.answer")
          /// How do I create or edit a shared calendar?
          public static let question = TimeNestStrings.tr("Localizable", "help.sharing.create.question")
        }

        public enum ReadOnlyHolidays: Sendable {
          /// Recipients can view shared events, shifts, and work records but cannot add or edit them. If you try to add an entry, switch to a calendar you can edit. Holidays are not shared through CloudKit; they come from the regions enabled and cached locally on the recipient's device.
          public static let answer = TimeNestStrings.tr("Localizable", "help.sharing.read_only_holidays.answer")
          /// Can I edit a shared calendar, and how are holidays shown?
          public static let question = TimeNestStrings.tr("Localizable", "help.sharing.read_only_holidays.question")
        }

        public enum Stop: Sendable {
          /// When the owner stops sharing or deletes the shared calendar, recipients can no longer view it. Leaving a share only removes it from the recipient's device and does not affect the owner's data. If a change has not appeared yet, refresh from the calendar chooser.
          public static let answer = TimeNestStrings.tr("Localizable", "help.sharing.stop.answer")
          /// What happens when sharing is stopped or deleted?
          public static let question = TimeNestStrings.tr("Localizable", "help.sharing.stop.question")
        }

        public enum Switch: Sendable {
          /// Tap the calendar icon at the top left and choose My Calendar or one shared calendar. The checkmark identifies the calendar currently displayed. Only one calendar is displayed at a time.
          public static let answer = TimeNestStrings.tr("Localizable", "help.sharing.switch.answer")
          /// How do I switch the displayed calendar?
          public static let question = TimeNestStrings.tr("Localizable", "help.sharing.switch.question")
        }
      }

      public enum Shifts: Sendable {
      
        public enum Add: Sendable {
          /// Open Shift Input from the menu at the top of the calendar, select a date, and tap a shift button. The shift will appear in the month, week, and day views.
          public static let answer = TimeNestStrings.tr("Localizable", "help.shifts.add.answer")
          /// How do I add a shift?
          public static let question = TimeNestStrings.tr("Localizable", "help.shifts.add.question")
        }

        public enum ChangeTime: Sendable {
          /// Under Customize Shift Times in Settings, you can change the name, start time, end time, and color for day, night, and custom shifts. The changes apply to shifts created afterward.
          public static let answer = TimeNestStrings.tr("Localizable", "help.shifts.change_time.answer")
          /// How do I customize shift times?
          public static let question = TimeNestStrings.tr("Localizable", "help.shifts.change_time.question")
        }

        public enum Difference: Sendable {
          /// A shift is a planned work schedule, such as a day or night shift. Work records contain actual clock-in and clock-out times, breaks, hourly rates, and transport costs used for work statistics.
          public static let answer = TimeNestStrings.tr("Localizable", "help.shifts.difference.answer")
          /// What is the difference between shifts and work records?
          public static let question = TimeNestStrings.tr("Localizable", "help.shifts.difference.question")
        }

        public enum Multiple: Sendable {
          /// Only one shift is kept for each day. Selecting another shift replaces the existing shift for that day, but does not delete regular events or clock-in and clock-out records.
          public static let answer = TimeNestStrings.tr("Localizable", "help.shifts.multiple.answer")
          /// Can I add multiple shifts on the same day?
          public static let question = TimeNestStrings.tr("Localizable", "help.shifts.multiple.question")
        }

        public enum Overnight: Sendable {
          /// For overnight work such as a night shift, the clock-out time can be recorded on the following day. Statistics use the actual time from clock-in to the next-day clock-out, minus break time.
          public static let answer = TimeNestStrings.tr("Localizable", "help.shifts.overnight.answer")
          /// How is an overnight clock-out handled?
          public static let question = TimeNestStrings.tr("Localizable", "help.shifts.overnight.question")
        }

        public enum Record: Sendable {
          /// From a day detail, tap New Work Record, or choose Work Record on the new-entry screen. Enter clock-in and clock-out times, break time, hourly rate, and transport cost; saved records are used in work statistics.
          public static let answer = TimeNestStrings.tr("Localizable", "help.shifts.record.answer")
          /// How do I record clock-in and clock-out times?
          public static let question = TimeNestStrings.tr("Localizable", "help.shifts.record.question")
        }

        public enum Replace: Sendable {
          /// Open Shift Input again, select the same date, and tap the new shift to replace it. Cancel only deletes the shift on the selected date and does not affect other events.
          public static let answer = TimeNestStrings.tr("Localizable", "help.shifts.replace.answer")
          /// How do I change the shift for a day?
          public static let question = TimeNestStrings.tr("Localizable", "help.shifts.replace.question")
        }

        public enum Statistics: Sendable {
          /// Work statistics use recorded clock-in and clock-out times, break time, hourly rate, and transport cost. All amounts are in Japanese yen (JPY). The basic rules are: work time = clock-out - clock-in - break; pay = work time × hourly rate; total = pay + transport cost.
          public static let answer = TimeNestStrings.tr("Localizable", "help.shifts.statistics.answer")
          /// How are work statistics calculated?
          public static let question = TimeNestStrings.tr("Localizable", "help.shifts.statistics.question")
        }

        public enum StatisticsMissing: Sendable {
          /// Check that clock-in and clock-out records were saved within the selected period and that required information such as the hourly rate was entered. A shift alone does not create pay statistics.
          public static let answer = TimeNestStrings.tr("Localizable", "help.shifts.statistics_missing.answer")
          /// Why are no statistics shown?
          public static let question = TimeNestStrings.tr("Localizable", "help.shifts.statistics_missing.question")
        }
      }

      public enum Views: Sendable {
      
        public enum Move: Sendable {
          /// Use the previous and next buttons at the top, or swipe the calendar left or right.
          public static let answer = TimeNestStrings.tr("Localizable", "help.views.move.answer")
          /// How do I move between months or weeks?
          public static let question = TimeNestStrings.tr("Localizable", "help.views.move.question")
        }

        public enum Switch: Sendable {
          /// Select Month, Week, or Day at the bottom of the calendar.
          public static let answer = TimeNestStrings.tr("Localizable", "help.views.switch.answer")
          /// How do I switch views?
          public static let question = TimeNestStrings.tr("Localizable", "help.views.switch.question")
        }

        public enum Today: Sendable {
          /// Tap Today at the bottom of the calendar.
          public static let answer = TimeNestStrings.tr("Localizable", "help.views.today.answer")
          /// How do I return to today?
          public static let question = TimeNestStrings.tr("Localizable", "help.views.today.question")
        }
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
      /// Default
      public static let `default` = TimeNestStrings.tr("Localizable", "holiday_source.default")
      /// The default URL is provided by Office Holidays (officeholidays.com)
      public static let defaultUrlProvider = TimeNestStrings.tr("Localizable", "holiday_source.default_url_provider")
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
      /// Recommended Subscription Source
      public static let recommendedSection = TimeNestStrings.tr("Localizable", "holiday_source.recommended_section")
      /// Successfully parsed %d events
      public static func testSuccess(_ p1: Int) -> String {
        return TimeNestStrings.tr("Localizable", "holiday_source.test_success",p1)
      }
      /// Sync Test Successful
      public static let testSuccessTitle = TimeNestStrings.tr("Localizable", "holiday_source.test_success_title")
      /// Test
      public static let testSync = TimeNestStrings.tr("Localizable", "holiday_source.test_sync")
      /// This subscription source is provided by a third party. Accuracy and availability depend on the provider.
      public static let thirdPartyNotice = TimeNestStrings.tr("Localizable", "holiday_source.third_party_notice")
      /// Please enter a valid HTTPS URL
      public static let urlFooter = TimeNestStrings.tr("Localizable", "holiday_source.url_footer")
      /// Subscription URL
      public static let urlHeader = TimeNestStrings.tr("Localizable", "holiday_source.url_header")
      /// Use
      public static let useRecommendedSourceConfirm = TimeNestStrings.tr("Localizable", "holiday_source.use_recommended_source_confirm")
      /// This subscription source is provided by a third party. Accuracy and availability depend on the provider.
      public static let useRecommendedSourceMessage = TimeNestStrings.tr("Localizable", "holiday_source.use_recommended_source_message")
      /// Use This Recommended Source?
      public static let useRecommendedSourceTitle = TimeNestStrings.tr("Localizable", "holiday_source.use_recommended_source_title")
    }

    public enum HolidaySubscription: Sendable {
      /// Last successful sync: %@
      public static func lastSuccessfulSyncFormat(_ p1: Any) -> String {
        return TimeNestStrings.tr("Localizable", "holiday_subscription.last_successful_sync_format",String(describing: p1))
      }
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
      /// Syncing
      public static let syncing = TimeNestStrings.tr("Localizable", "holiday_subscription.syncing")
      /// Using last successful data
      public static let usingCachedData = TimeNestStrings.tr("Localizable", "holiday_subscription.using_cached_data")

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
      /// 繁體中文
      public static let zhHant = TimeNestStrings.tr("Localizable", "language.zh_hant")
    }

    public enum Notification: Sendable {
      /// Check today’s schedule
      public static let dailyScheduleCheck = TimeNestStrings.tr("Localizable", "notification.daily_schedule_check")
      /// Enable Notifications
      public static let enabled = TimeNestStrings.tr("Localizable", "notification.enabled")
      /// Event starting soon
      public static let eventStartingSoon = TimeNestStrings.tr("Localizable", "notification.event_starting_soon")
      /// Open Settings
      public static let openSettings = TimeNestStrings.tr("Localizable", "notification.open_settings")
      /// Notification Time
      public static let time = TimeNestStrings.tr("Localizable", "notification.time")

      public enum PermissionDenied: Sendable {
        /// TimeNest needs notification permission to send event reminders. Turn on notifications in iOS Settings.
        public static let message = TimeNestStrings.tr("Localizable", "notification.permission_denied.message")
        /// Notifications Are Off
        public static let title = TimeNestStrings.tr("Localizable", "notification.permission_denied.title")
      }

      public enum ReminderTimePast: Sendable {
        /// The event was saved, but the reminder time has already passed, so no notification was set.
        public static let message = TimeNestStrings.tr("Localizable", "notification.reminder_time_past.message")
        /// Reminder Time Has Passed
        public static let title = TimeNestStrings.tr("Localizable", "notification.reminder_time_past.title")
      }

      public enum ScheduleFailed: Sendable {
        /// The event was saved, but the reminder setup failed.
        public static let message = TimeNestStrings.tr("Localizable", "notification.schedule_failed.message")
        /// Reminder Setup Failed
        public static let title = TimeNestStrings.tr("Localizable", "notification.schedule_failed.title")
      }
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
      /// Taiwan
      public static let taiwan = TimeNestStrings.tr("Localizable", "region.taiwan")
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
      /// Customize Calendar Display
      public static let calendarDisplayCustomize = TimeNestStrings.tr("Localizable", "settings.calendar_display_customize")
      /// Data Management
      public static let dataManagement = TimeNestStrings.tr("Localizable", "settings.data_management")
      /// Holiday Region
      public static let holidayRegion = TimeNestStrings.tr("Localizable", "settings.holiday_region")
      /// Language
      public static let language = TimeNestStrings.tr("Localizable", "settings.language")
      /// Notification
      public static let notification = TimeNestStrings.tr("Localizable", "settings.notification")
      /// Support
      public static let support = TimeNestStrings.tr("Localizable", "settings.support")
      /// Theme
      public static let theme = TimeNestStrings.tr("Localizable", "settings.theme")
      /// Settings
      public static let title = TimeNestStrings.tr("Localizable", "settings.title")
      /// Traditional Calendars
      public static let traditionalCalendar = TimeNestStrings.tr("Localizable", "settings.traditional_calendar")
      /// Week Start
      public static let weekStart = TimeNestStrings.tr("Localizable", "settings.week_start")

      public enum CalendarDisplayCustomize: Sendable {
        /// Event Background
        public static let eventBackground = TimeNestStrings.tr("Localizable", "settings.calendar_display_customize.event_background")
        /// Reset Defaults
        public static let resetDefaults = TimeNestStrings.tr("Localizable", "settings.calendar_display_customize.reset_defaults")
        /// Work Record Background
        public static let workRecordBackground = TimeNestStrings.tr("Localizable", "settings.calendar_display_customize.work_record_background")
      }

      public enum TraditionalCalendar: Sendable {
        /// Show Chinese Lunar Calendar
        public static let showLunar = TimeNestStrings.tr("Localizable", "settings.traditional_calendar.show_lunar")
        /// Show Rokuyo
        public static let showRokuyo = TimeNestStrings.tr("Localizable", "settings.traditional_calendar.show_rokuyo")
        /// Show 24 Solar Terms
        public static let showSolarTerms = TimeNestStrings.tr("Localizable", "settings.traditional_calendar.show_solar_terms")
      }
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

    public enum ShiftTemplate: Sendable {
      /// Add to favorites
      public static let favorite = TimeNestStrings.tr("Localizable", "shift_template.favorite")
      /// Favorite Shifts
      public static let favorites = TimeNestStrings.tr("Localizable", "shift_template.favorites")
      /// Remove from favorites
      public static let unfavorite = TimeNestStrings.tr("Localizable", "shift_template.unfavorite")

      public enum DeleteConfirmation: Sendable {
        /// This template is used by %d existing shifts. The shifts will remain with their saved details.
        public static func referenced(_ p1: Int) -> String {
          return TimeNestStrings.tr("Localizable", "shift_template.delete_confirmation.referenced",p1)
        }
        /// Delete Shift Template?
        public static let title = TimeNestStrings.tr("Localizable", "shift_template.delete_confirmation.title")
        /// Existing shifts will not be deleted.
        public static let unused = TimeNestStrings.tr("Localizable", "shift_template.delete_confirmation.unused")
      }

      public enum Empty: Sendable {
        /// Create common day or night shift templates to schedule multiple dates faster.
        public static let message = TimeNestStrings.tr("Localizable", "shift_template.empty.message")
        /// No shift templates yet
        public static let title = TimeNestStrings.tr("Localizable", "shift_template.empty.title")
      }
    }

    public enum ShiftTime: Sendable {
      /// Add Shift
      public static let addButton = TimeNestStrings.tr("Localizable", "shift_time.add_button")
      /// Color
      public static let color = TimeNestStrings.tr("Localizable", "shift_time.color")
      /// Delete
      public static let deleteButton = TimeNestStrings.tr("Localizable", "shift_time.delete_button")
      /// Detailed Settings
      public static let details = TimeNestStrings.tr("Localizable", "shift_time.details")
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

      public enum Details: Sendable {
        /// Collapse detailed settings
        public static let collapse = TimeNestStrings.tr("Localizable", "shift_time.details.collapse")
        /// Expand detailed settings
        public static let expand = TimeNestStrings.tr("Localizable", "shift_time.details.expand")
      }
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

    public enum ThirdPartyLicenses: Sendable {
      /// Apache-2.0
      public static let apache2 = TimeNestStrings.tr("Localizable", "third_party_licenses.apache_2")
      /// TimeNest uses the following third-party components. Full notices remain available in the project's ThirdPartyNotices document.
      public static let description = TimeNestStrings.tr("Localizable", "third_party_licenses.description")
      /// Copyright 2021 Google LLC
      public static let googleCopyright = TimeNestStrings.tr("Localizable", "third_party_licenses.google_copyright")
      /// Google Mobile Ads Swift Package Manager wrapper
      public static let googleMobileAds = TimeNestStrings.tr("Localizable", "third_party_licenses.google_mobile_ads")
      /// License
      public static let licenseType = TimeNestStrings.tr("Localizable", "third_party_licenses.license_type")
      /// View Source Repository
      public static let repository = TimeNestStrings.tr("Localizable", "third_party_licenses.repository")
      /// Third-party Licenses
      public static let title = TimeNestStrings.tr("Localizable", "third_party_licenses.title")
      /// Google User Messaging Platform Swift Package Manager wrapper
      public static let userMessagingPlatform = TimeNestStrings.tr("Localizable", "third_party_licenses.user_messaging_platform")
    }

    public enum TraditionalCalendar: Sendable {

      public enum Lunar: Sendable {
        /// D1|D2|D3|D4|D5|D6|D7|D8|D9|D10|D11|D12|D13|D14|D15|D16|D17|D18|D19|D20|D21|D22|D23|D24|D25|D26|D27|D28|D29|D30
        public static let dayNames = TimeNestStrings.tr("Localizable", "traditional_calendar.lunar.day_names")
        /// Leap·
        public static let leapPrefix = TimeNestStrings.tr("Localizable", "traditional_calendar.lunar.leap_prefix")
        /// L1|L2|L3|L4|L5|L6|L7|L8|L9|L10|L11|L12
        public static let monthNames = TimeNestStrings.tr("Localizable", "traditional_calendar.lunar.month_names")
      }

      public enum Rokuyo: Sendable {
        /// Tai|Sha|Sho|Tomo|Sen|Butsu
        public static let names = TimeNestStrings.tr("Localizable", "traditional_calendar.rokuyo.names")
      }

      public enum SolarTerm: Sendable {
        /// SprBeg|Rain|Awake|SprEq|Clear|Grain|SumBeg|Full|Ear|SumSol|MinHt|MajHt|AutBeg|EndHt|W.Dew|AutEq|C.Dew|Frost|WinBeg|MinSn|MajSn|WinSol|MinCl|MajCl
        public static let names = TimeNestStrings.tr("Localizable", "traditional_calendar.solar_term.names")
      }
    }

    public enum Validation: Sendable {
      /// Please enter a title
      public static let titleRequired = TimeNestStrings.tr("Localizable", "validation.title_required")
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

    public enum Widget: Sendable {
      /// All day
      public static let allDay = TimeNestStrings.tr("Localizable", "widget.allDay")
      /// Holiday
      public static let holiday = TimeNestStrings.tr("Localizable", "widget.holiday")
      /// Next
      public static let nextEvent = TimeNestStrings.tr("Localizable", "widget.nextEvent")
      /// No events today
      public static let noEventsToday = TimeNestStrings.tr("Localizable", "widget.noEventsToday")
      /// Shift
      public static let shift = TimeNestStrings.tr("Localizable", "widget.shift")
      /// Today
      public static let today = TimeNestStrings.tr("Localizable", "widget.today")
      /// Tomorrow
      public static let tomorrow = TimeNestStrings.tr("Localizable", "widget.tomorrow")

      public enum Accessory: Sendable {
        /// Shows today's summary on the Lock Screen, StandBy, and Apple Watch.
        public static let description = TimeNestStrings.tr("Localizable", "widget.accessory.description")
        /// Today Summary
        public static let title = TimeNestStrings.tr("Localizable", "widget.accessory.title")
      }

      public enum Calendar: Sendable {
        /// Shows the current month.
        public static let description = TimeNestStrings.tr("Localizable", "widget.calendar.description")
        /// Calendar
        public static let title = TimeNestStrings.tr("Localizable", "widget.calendar.title")
      }

      public enum MonthSchedule: Sendable {
        /// Shows a short schedule for each day this month.
        public static let description = TimeNestStrings.tr("Localizable", "widget.monthSchedule.description")
        /// This Month
        public static let title = TimeNestStrings.tr("Localizable", "widget.monthSchedule.title")
      }

      public enum TwoMonths: Sendable {
        /// Shows two months side by side.
        public static let description = TimeNestStrings.tr("Localizable", "widget.twoMonths.description")
        /// This and Next Month
        public static let title = TimeNestStrings.tr("Localizable", "widget.twoMonths.title")
      }

      public enum Upcoming: Sendable {
        /// Shows upcoming events with the current month.
        public static let description = TimeNestStrings.tr("Localizable", "widget.upcoming.description")
        /// Upcoming and Calendar
        public static let title = TimeNestStrings.tr("Localizable", "widget.upcoming.title")
      }

      public enum WeekSchedule: Sendable {
        /// Shows this week's shifts, holidays, and events.
        public static let description = TimeNestStrings.tr("Localizable", "widget.weekSchedule.description")
        /// This Week
        public static let title = TimeNestStrings.tr("Localizable", "widget.weekSchedule.title")
      }
    }

    public enum Work: Sendable {
      /// Next day
      public static let nextDayPrefix = TimeNestStrings.tr("Localizable", "work.nextDayPrefix")
    }

    public enum WorkClock: Sendable {
      /// In
      public static let shortIn = TimeNestStrings.tr("Localizable", "work_clock.short_in")
      /// Out
      public static let shortOut = TimeNestStrings.tr("Localizable", "work_clock.short_out")
    }

    public enum WorkRecord: Sendable {
      /// New Work Record
      public static let add = TimeNestStrings.tr("Localizable", "work_record.add")
      /// Work
      public static let defaultTitle = TimeNestStrings.tr("Localizable", "work_record.default_title")
      /// Edit Work Record
      public static let edit = TimeNestStrings.tr("Localizable", "work_record.edit")
      /// No work records yet
      public static let empty = TimeNestStrings.tr("Localizable", "work_record.empty")
      /// Record actual clock-in, clock-out, and break times for this date.
      public static let emptyMessage = TimeNestStrings.tr("Localizable", "work_record.empty_message")
      /// No clock-in
      public static let missingClockIn = TimeNestStrings.tr("Localizable", "work_record.missing_clock_in")
      /// No clock-out
      public static let missingClockOut = TimeNestStrings.tr("Localizable", "work_record.missing_clock_out")
      /// Work Records
      public static let sectionTitle = TimeNestStrings.tr("Localizable", "work_record.section_title")
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
      /// Received shared calendars do not include hourly rates or transport costs, so TimeNest cannot calculate reliable work statistics. Switch to My Calendar or an owned shared calendar.
      public static let receivedUnavailableMessage = TimeNestStrings.tr("Localizable", "work_statistics.received_unavailable_message")
      /// Work Statistics Unavailable
      public static let receivedUnavailableTitle = TimeNestStrings.tr("Localizable", "work_statistics.received_unavailable_title")
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
