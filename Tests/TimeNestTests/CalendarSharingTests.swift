import CloudKit
import UIKit
import XCTest
@testable import TimeNest

final class CalendarSelectionAndPolicyTests: XCTestCase {
    func testSelectionPersistsOneCalendarAndFallsBackToPersonal() {
        let suite = "CalendarSelectionAndPolicyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let persistence = CalendarSelectionPersistence(defaults: defaults)
        let ownedID = UUID()

        persistence.save(.calendar(ownedID))
        XCTAssertEqual(
            persistence.load(validCalendarIDs: [TimeNestCalendar.personalID, ownedID]),
            .calendar(ownedID)
        )
        XCTAssertEqual(
            CalendarSelectionPersistence.resolved(
                .calendar(UUID()),
                validCalendarIDs: [TimeNestCalendar.personalID]
            ),
            .mine
        )
    }

    func testCalendarKindsEnforceReceivedReadOnlyPolicy() {
        let now = Date()
        let received = TimeNestCalendar(
            id: UUID(),
            name: "Received",
            kind: .sharedReceived,
            zoneName: "zone",
            ownerName: "owner",
            rootRecordName: "calendar",
            shareRecordName: CKRecordNameZoneWideShare,
            createdAt: now,
            updatedAt: now
        )
        let policy = CalendarAccessPolicy(selectedCalendar: received)

        XCTAssertTrue(received.isReadOnly)
        XCTAssertTrue(policy.isReadOnly)
        XCTAssertFalse(policy.canCreate)
        XCTAssertFalse(policy.canEdit)
        XCTAssertFalse(policy.canDelete)
        XCTAssertTrue(TimeNestCalendarKind.personal.isCloudBacked == false)
        XCTAssertTrue(TimeNestCalendarKind.sharedOwned.isCloudBacked)
    }

    func testCreateEntryIsAvailableWithNoSharedCalendarsAndOpensCreateRoute() {
        let calendars = [TimeNestCalendar.personal(name: "My Calendar")]
        var state = CalendarSelectionActionState()

        XCTAssertTrue(calendars.allSatisfy { $0.kind == .personal })
        XCTAssertFalse(state.isCreating)

        state.requestCreate()

        XCTAssertTrue(state.isCreating)
    }

    func testCancellingCopyConfirmationDoesNotAuthorizeOverwrite() {
        var state = CalendarSharingCopyConfirmationState()

        state.request()
        XCTAssertTrue(state.isPresented)

        state.cancel()

        XCTAssertFalse(state.isPresented)
        XCTAssertFalse(state.beginConfirmedCopy())
    }

    func testSharedListStateShowsEmptyOnlyAfterSuccessfulRefresh() {
        XCTAssertEqual(
            CalendarSelectionSharedListState.resolve(
                iCloudStatus: .unknown,
                syncStatus: .idle,
                hasError: false,
                hasSharedCalendars: false
            ),
            .loading
        )
        XCTAssertEqual(
            CalendarSelectionSharedListState.resolve(
                iCloudStatus: .available,
                syncStatus: .syncing,
                hasError: false,
                hasSharedCalendars: false
            ),
            .loading
        )
        XCTAssertEqual(
            CalendarSelectionSharedListState.resolve(
                iCloudStatus: .available,
                syncStatus: .synced,
                hasError: false,
                hasSharedCalendars: false
            ),
            .empty
        )
    }

    func testSharedListStateKeepsErrorsAndUnavailableICloudOutOfEmptyState() {
        XCTAssertEqual(
            CalendarSelectionSharedListState.resolve(
                iCloudStatus: .noAccount,
                syncStatus: .failed,
                hasError: true,
                hasSharedCalendars: false
            ),
            .error
        )
        XCTAssertEqual(
            CalendarSelectionSharedListState.resolve(
                iCloudStatus: .available,
                syncStatus: .synced,
                hasError: true,
                hasSharedCalendars: false
            ),
            .error
        )
    }

    func testSharedListStatePreservesExistingContentDuringRefreshOrFailure() {
        for syncStatus in [CalendarSharingSyncStatus.syncing, .failed] {
            XCTAssertEqual(
                CalendarSelectionSharedListState.resolve(
                    iCloudStatus: .available,
                    syncStatus: syncStatus,
                    hasError: syncStatus == .failed,
                    hasSharedCalendars: true
                ),
                .content
            )
        }
    }

    func testManualInvitationEntryOpensItsOwnRoute() {
        var state = CalendarSelectionActionState()

        state.requestInvitationLinkInput()

        XCTAssertTrue(state.isEnteringInvitationLink)
        XCTAssertFalse(state.isCreating)
    }

    func testICloudShareURLValidationAcceptsSupportedPublicShape() throws {
        let url = try CalendarSharingInvitationURLValidator.validatedURL(
            from: "  https://www.icloud.com/share/example-token  "
        )

        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "www.icloud.com")
        XCTAssertEqual(url.path, "/share/example-token")
    }

    func testICloudShareURLValidationRejectsEmptyMalformedAndUnsupportedURLs() {
        assertInvitationURL("", throws: .invitationURLInputEmpty)
        assertInvitationURL("not a URL", throws: .invitationURLInvalid)
        assertInvitationURL(
            "http://www.icloud.com/share/example-token",
            throws: .invitationURLInvalid
        )
        assertInvitationURL(
            "https://user:password@www.icloud.com/share/example-token",
            throws: .invitationURLInvalid
        )
        assertInvitationURL(
            "https://example.com/share/example-token",
            throws: .notCloudKitShare
        )
        assertInvitationURL(
            "https://www.icloud.com/ordinary-page",
            throws: .notCloudKitShare
        )
        assertInvitationURL(
            "timenest://calendar?date=2026-07-18",
            throws: .invitationURLInvalid
        )
    }

    func testInvitationURLDiagnosticUsesOnlyDigest() throws {
        let token = "private-invitation-token"
        let url = try XCTUnwrap(
            URL(string: "https://www.icloud.com/share/\(token)")
        )

        let digest = CalendarSharingDiagnostics.urlHash(url)

        XCTAssertFalse(digest.contains(token))
        XCTAssertEqual(digest.count, 16)
    }

    func testWidgetCalendarDeepLinkRouteIsUnchanged() throws {
        let sourceDate = try XCTUnwrap(
            Calendar(identifier: .gregorian).date(
                from: DateComponents(year: 2026, month: 7, day: 18)
            )
        )
        let url = try XCTUnwrap(TimeNestWidgetDeepLink.url(for: sourceDate))
        let parsedDate = try XCTUnwrap(TimeNestWidgetDeepLink.date(from: url))

        XCTAssertEqual(url.scheme, "timenest")
        XCTAssertEqual(url.host, "calendar")
        XCTAssertEqual(
            Calendar.current.startOfDay(for: parsedDate),
            Calendar.current.startOfDay(for: sourceDate)
        )
    }

    private func assertInvitationURL(
        _ rawValue: String,
        throws expectedError: CalendarSharingError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try CalendarSharingInvitationURLValidator.validatedURL(from: rawValue),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(
                error as? CalendarSharingError,
                expectedError,
                file: file,
                line: line
            )
        }
    }

    func testOwnedRowShowsDirectEditAndDeleteWithoutOverflowMenu() {
        let actions = CalendarSelectionRowActions(
            calendar: makeCalendar(kind: .sharedOwned, name: "Family")
        )

        XCTAssertTrue(actions.showsEdit)
        XCTAssertTrue(actions.showsDelete)
        XCTAssertFalse(actions.showsReceivedDetails)
        XCTAssertTrue(actions.actionsAreEnabled)
    }

    func testReceivedRowStaysReadOnlyAndRoutesOnlyToDetailsForLeaving() {
        let received = makeCalendar(kind: .sharedReceived, name: "Received")
        let actions = CalendarSelectionRowActions(calendar: received)
        var state = CalendarSelectionActionState()

        XCTAssertFalse(actions.showsEdit)
        XCTAssertFalse(actions.showsDelete)
        XCTAssertTrue(actions.showsReceivedDetails)
        XCTAssertNil(state.handle(.edit, for: received))
        XCTAssertNil(state.handle(.delete, for: received))
        XCTAssertNil(state.handle(.receivedDetails, for: received))
        XCTAssertEqual(state.route, .receivedDetails(received.id))
    }

    func testAccessoryInteractionsNeverReturnRowSelectionAndEditUsesCorrectID() {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        var state = CalendarSelectionActionState()

        XCTAssertNil(state.handle(.edit, for: owned))
        XCTAssertEqual(state.route, .edit(owned.id))

        state.route = nil
        XCTAssertNil(state.handle(.delete, for: owned))
        XCTAssertEqual(state.deletionCandidateID, owned.id)

        XCTAssertEqual(state.handle(.select, for: owned), owned.id)
    }

    func testDeleteRequiresConfirmationCancelDoesNothingAndDuplicateBeginIsBlocked() {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        var state = CalendarSelectionActionState()

        _ = state.handle(.delete, for: owned)
        XCTAssertNil(state.deletionInProgressID)

        state.cancelDeletion()
        XCTAssertNil(state.beginConfirmedDeletion())

        _ = state.handle(.delete, for: owned)
        XCTAssertEqual(state.beginConfirmedDeletion(), owned.id)
        XCTAssertNil(state.beginConfirmedDeletion())
        XCTAssertEqual(state.deletionInProgressID, owned.id)

        state.finishDeletion(calendarID: owned.id)
        XCTAssertNil(state.deletionInProgressID)
    }

    func testStoppingOwnedRowDisablesSelectionEditAndDelete() {
        var owned = makeCalendar(kind: .sharedOwned, name: "Family")
        owned.stopPhase = .cloudDeletionPending
        let actions = CalendarSelectionRowActions(calendar: owned)
        var state = CalendarSelectionActionState()

        XCTAssertTrue(actions.showsEdit)
        XCTAssertTrue(actions.showsDelete)
        XCTAssertFalse(actions.actionsAreEnabled)
        XCTAssertNil(state.handle(.select, for: owned))
        XCTAssertNil(state.handle(.edit, for: owned))
        XCTAssertNil(state.handle(.delete, for: owned))
    }

    func testCreateAndEditRequireNonEmptyCalendarName() {
        XCTAssertFalse(CalendarSharingFormValidation.hasRequiredName(""))
        XCTAssertFalse(CalendarSharingFormValidation.hasRequiredName(" \n "))
        XCTAssertTrue(CalendarSharingFormValidation.hasRequiredName(" Family "))
    }

    func testCreateNameDraftKeepsUserEditedNameAfterInitialFallback() {
        var draft = CalendarSharingCreateNameDraft()

        draft.initialize(defaultName: "My Shared Calendar")
        XCTAssertEqual(draft.value, "My Shared Calendar")
        XCTAssertTrue(CalendarSharingFormValidation.hasRequiredName(draft.value))

        draft.updateFromUser("Family")
        XCTAssertFalse(draft.applyResolvedDefaultName("Alice's Shared Calendar"))

        XCTAssertEqual(draft.value, "Family")
        XCTAssertTrue(draft.hasUserEditedCalendarName)
        XCTAssertFalse(draft.hasAppliedResolvedDefaultName)
    }

    func testCreateNameDraftAppliesAvailableOwnerNameOnlyOnce() {
        var draft = CalendarSharingCreateNameDraft()
        draft.initialize(defaultName: "My Shared Calendar")

        XCTAssertTrue(draft.applyResolvedDefaultName("Sou's Shared Calendar"))
        XCTAssertFalse(draft.applyResolvedDefaultName("Other's Shared Calendar"))
        XCTAssertEqual(draft.value, "Sou's Shared Calendar")
        XCTAssertTrue(draft.hasAppliedResolvedDefaultName)
        XCTAssertFalse(draft.hasUserEditedCalendarName)
    }

    func testCreateNameDraftKeepsFallbackWhenOwnerNameIsUnavailable() {
        var draft = CalendarSharingCreateNameDraft()
        draft.initialize(defaultName: "My Shared Calendar")

        XCTAssertEqual(draft.value, "My Shared Calendar")
        XCTAssertFalse(draft.hasAppliedResolvedDefaultName)
    }

    func testLocalizedOwnerFormatsCoverAllFiveLanguages() {
        let cases: [(String, String, String, String)] = [
            ("ja", "Souの共有カレンダー", "Souさんから共有", "iCloudユーザーから共有"),
            ("zhHans", "Sou的共享日历", "由 Sou 共享", "由 iCloud 用户共享"),
            ("zh-Hant", "Sou的共享日曆", "由 Sou 共享", "由 iCloud 使用者共享"),
            ("enUS", "Sou's Shared Calendar", "Shared by Sou", "Shared by an iCloud user"),
            ("ko", "Sou의 공유 캘린더", "Sou님이 공유함", "iCloud 사용자가 공유함")
        ]

        for (languageCode, defaultName, sharedBy, fallback) in cases {
            let localization = LocalizationManager(savedCode: languageCode)
            XCTAssertEqual(
                CalendarSharingLocalizedOwnerText.defaultCalendarName(
                    ownerDisplayName: "Sou",
                    format: localization.localized(.calendarSharingDefaultNameWithOwner),
                    locale: localization.currentLocale
                ),
                defaultName
            )
            XCTAssertEqual(
                CalendarSharingLocalizedOwnerText.sharedByText(
                    ownerDisplayName: "Sou",
                    format: localization.localized(.calendarSharingSharedByOwner),
                    fallback: localization.localized(.calendarSharingSharedByICloudUser),
                    locale: localization.currentLocale
                ),
                sharedBy
            )
            XCTAssertEqual(
                CalendarSharingLocalizedOwnerText.sharedByText(
                    ownerDisplayName: nil,
                    format: localization.localized(.calendarSharingSharedByOwner),
                    fallback: localization.localized(.calendarSharingSharedByICloudUser),
                    locale: localization.currentLocale
                ),
                fallback
            )
        }
    }

    func testDirectActionAccessibilityLabelsUseRequestedLocalizedKeys() {
        XCTAssertEqual(
            CalendarSelectionAccessibilityLabels.edit,
            .calendarSharingEditCalendar
        )
        XCTAssertEqual(
            CalendarSelectionAccessibilityLabels.delete,
            .calendarSharingDeleteCalendar
        )
        XCTAssertEqual(
            CalendarSelectionAccessibilityLabels.receivedDetails,
            .calendarSharingReceivedDetails
        )
    }
}

final class SharedCalendarPrivacyAndRecordTests: XCTestCase {
    @MainActor
    func testCurrentUserDisplayNameProviderFormatsAvailableName() async {
        var components = PersonNameComponents()
        components.givenName = " Sou "
        let provider = CloudKitCurrentUserDisplayNameProvider {
            components
        }
        let displayName = await provider.displayName(
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(displayName, "Sou")
    }

    @MainActor
    func testCurrentUserDisplayNameProviderSilentlyReturnsNilForFailureOrEmptyName() async {
        let failingProvider = CloudKitCurrentUserDisplayNameProvider {
            throw CKError(.notAuthenticated)
        }
        var emptyComponents = PersonNameComponents()
        emptyComponents.givenName = " \n "
        let emptyProvider = CloudKitCurrentUserDisplayNameProvider {
            emptyComponents
        }
        let failedDisplayName = await failingProvider.displayName()
        let emptyDisplayName = await emptyProvider.displayName()

        XCTAssertNil(failedDisplayName)
        XCTAssertNil(emptyDisplayName)
    }

    func testEventSnapshotContainsNoMemoOrNotificationFields() throws {
        let event = makeEvent(
            title: "Appointment",
            note: "private memo",
            reminderOffsetMinutes: 15,
            notificationID: "private-notification"
        )
        let snapshot = try XCTUnwrap(SharedEventMapper.snapshot(from: event))
        let labels = Set(Mirror(reflecting: snapshot).children.compactMap(\.label))

        XCTAssertEqual(
            labels,
            [
                "id", "title", "startDate", "endDate", "isAllDay", "updatedAt",
                "isDeleted", "deletedAt",
            ]
        )
    }

    func testWorkRecordSnapshotExcludesFinancialFields() throws {
        let workDate = Date(timeIntervalSince1970: 1_700_000_000)
        let sessionID = UUID()
        let clockIn = makeEvent(
            title: "Clock In",
            workInfo: WorkInfo(
                workInTime: workDate,
                workOutTime: workDate.addingTimeInterval(28_800),
                restHours: 1,
                workDate: workDate,
                transportFee: 900,
                hourlyRate: 2_500,
                workSessionId: sessionID,
                isWorkOutTimeSet: true
            )
        )
        let snapshot = try XCTUnwrap(SharedWorkRecordMapper.snapshots(from: [clockIn]).first)
        let labels = Set(Mirror(reflecting: snapshot).children.compactMap(\.label))

        XCTAssertEqual(
            labels,
            ["id", "workDate", "workInTime", "workOutTime", "isWorkOutTimeSet", "restHours", "updatedAt"]
        )
        XCTAssertFalse(labels.contains("transportFee"))
        XCTAssertFalse(labels.contains("hourlyRate"))
    }

    func testContentRecordsHaveStableIDsAndNoHierarchicalParent() {
        let zoneID = CKRecordZone.ID(
            zoneName: CalendarSharingCloudSchema.zoneName(for: UUID()),
            ownerName: CKCurrentUserDefaultName
        )
        let event = makeEvent(title: "Event")
        let snapshot = SharedEventMapper.snapshot(from: event)!
        let recordID = CKRecord.ID(
            recordName: "event-\(snapshot.id.uuidString.lowercased())",
            zoneID: zoneID
        )
        let record = CalendarSharingCloudRecordFactory.makeEventRecord(
            snapshot: snapshot,
            recordID: recordID
        )

        XCTAssertEqual(record.recordID, recordID)
        XCTAssertNil(record.parent)
        XCTAssertEqual(
            record[CalendarSharingCloudSchema.EventField.eventID] as? String,
            snapshot.id.uuidString
        )
    }

    func testZoneWideShareCreatesReadOnlyPrivateInvitation() {
        let zoneID = CKRecordZone.ID(
            zoneName: CalendarSharingCloudSchema.zoneName(for: UUID()),
            ownerName: CKCurrentUserDefaultName
        )
        let share = CalendarSharingCloudRecordFactory.makeZoneWideShare(recordZoneID: zoneID)
        _ = OneTimeSharingInvitation.prepare(on: share)
        let invitees = share.participants.filter { $0.role != .owner }

        XCTAssertEqual(share.publicPermission, .none)
        XCTAssertEqual(invitees.count, 1)
        XCTAssertEqual(invitees.first?.permission, .readOnly)
    }

    @MainActor
    func testInvitationResultResolvesURLFromRefetchedShare() throws {
        let calendar = makeCalendar(kind: .sharedOwned, name: "Family")
        let refetchedState = makeOwnedState(calendar: calendar)
        let staleShare = CalendarSharingCloudRecordFactory.makeZoneWideShare(
            recordZoneID: refetchedState.share.recordID.zoneID
        )
        let invitation = OneTimeSharingInvitation.prepare(on: staleShare)
        let expectedURL = try XCTUnwrap(URL(string: "https://example.invalid/latest-share"))
        var resolvedShare: CKShare?

        let result = OwnedSharingInvitationResultFactory.make(
            state: refetchedState,
            invitation: invitation,
            resolveURL: { share, participantID in
                resolvedShare = share
                XCTAssertEqual(participantID, invitation.participantID)
                return expectedURL
            }
        )

        XCTAssertTrue(resolvedShare === refetchedState.share)
        XCTAssertEqual(result.invitationURL, expectedURL)
    }

    func testSharingActivityContainsOnlyOpenableInvitationURL() throws {
        let url = try XCTUnwrap(URL(string: "https://example.invalid/invitation"))
        let invitation = CalendarSharingInvitation(
            id: "participant-hash",
            calendarID: UUID(),
            url: url
        )

        let items = CalendarSharingInvitationActivityItems.make(for: invitation)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first as? URL, url)
        XCTAssertFalse(items.contains { $0 is String })
    }

    func testContainerMismatchAndParticipantStatusesMapExplicitly() throws {
        XCTAssertNoThrow(
            try CalendarSharingContainerValidator.validate(
                metadataContainerIdentifier: "iCloud.com.song.TimeNest",
                configuredContainerIdentifier: "iCloud.com.song.TimeNest"
            )
        )
        XCTAssertThrowsError(
            try CalendarSharingContainerValidator.validate(
                metadataContainerIdentifier: "iCloud.com.song.TimeNest.dev",
                configuredContainerIdentifier: "iCloud.com.song.TimeNest"
            )
        ) {
            XCTAssertEqual($0 as? CalendarSharingError, .cloudEnvironmentMismatch)
        }
        XCTAssertNil(CalendarSharingParticipantStatusValidator.error(for: .accepted))
        XCTAssertNil(CalendarSharingParticipantStatusValidator.error(for: .pending))
        XCTAssertEqual(
            CalendarSharingParticipantStatusValidator.error(for: .removed),
            .invitationRevoked
        )
        XCTAssertEqual(
            CalendarSharingParticipantStatusValidator.error(for: .unknown),
            .invitationInvalid
        )
        XCTAssertEqual(
            CalendarSharingErrorMapper.map(
                CKError(.unknownItem),
                context: .acceptingInvitation
            ),
            .invitationRevoked
        )
        XCTAssertEqual(
            CalendarSharingErrorMapper.map(
                CKError(.unknownItem),
                context: .fetchingInvitationMetadata
            ),
            .invitationUnavailable
        )
        XCTAssertEqual(
            CalendarSharingErrorMapper.map(
                CKError(.serviceUnavailable),
                context: .fetchingInvitationMetadata
            ),
            .serviceTemporarilyUnavailable
        )
        XCTAssertEqual(
            CalendarSharingErrorMapper.map(
                CKError(.networkFailure),
                context: .fetchingInvitationMetadata
            ),
            .networkUnavailable
        )
    }

    func testCloudKitBuildEnvironmentsAreExplicitAndEntitlementsUseMainBundleContainer() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let project = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Project.swift"),
            encoding: .utf8
        )
        let entitlements = try String(
            contentsOf: repositoryRoot.appendingPathComponent("TimeNest/TimeNest.entitlements"),
            encoding: .utf8
        )

        XCTAssertTrue(project.contains("\"PRODUCT_BUNDLE_IDENTIFIER\": \"com.song.TimeNest\""))
        XCTAssertTrue(project.contains("\"ICLOUD_CONTAINER_ENVIRONMENT\": \"Development\""))
        XCTAssertTrue(project.contains("\"ICLOUD_CONTAINER_ENVIRONMENT\": \"Production\""))
        XCTAssertTrue(entitlements.contains("iCloud.$(PRODUCT_BUNDLE_IDENTIFIER)"))
        XCTAssertTrue(entitlements.contains("$(ICLOUD_CONTAINER_ENVIRONMENT)"))
        XCTAssertTrue(entitlements.contains("<string>CloudKit</string>"))
    }

    func testLegacyParentRecordIsDeletedAndRecreated() {
        let zoneID = CKRecordZone.ID(zoneName: "zone", ownerName: CKCurrentUserDefaultName)
        let rootID = CKRecord.ID(recordName: "calendar", zoneID: zoneID)
        let id = UUID()
        let recordID = CKRecord.ID(recordName: "event-\(id)", zoneID: zoneID)
        let legacy = CKRecord(recordType: CalendarSharingCloudSchema.eventRecordType, recordID: recordID)
        legacy.parent = CKRecord.Reference(recordID: rootID, action: .none)
        let snapshot = SharedEventSnapshot(
            id: id,
            title: "Event",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3_600),
            isAllDay: false,
            updatedAt: Date()
        )
        let plan = CalendarSharingContentRecordPlan(
            recordType: CalendarSharingCloudSchema.eventRecordType,
            existingRecords: [legacy],
            snapshots: [snapshot],
            recordID: { _ in recordID },
            makeRecord: CalendarSharingCloudRecordFactory.makeEventRecord
        )

        XCTAssertEqual(plan.legacyRecordIDsToDelete, [recordID])
        XCTAssertEqual(plan.recordsToRecreate.count, 1)
        XCTAssertNil(plan.recordsToRecreate.first?.parent)
    }

    func testEmptyZonePayloadIsValidWhenRootExists() throws {
        let calendarID = UUID()
        let zoneID = CKRecordZone.ID(
            zoneName: CalendarSharingCloudSchema.zoneName(for: calendarID),
            ownerName: "owner"
        )
        let rootID = CKRecord.ID(
            recordName: CalendarSharingCloudSchema.calendarRecordName,
            zoneID: zoneID
        )
        let root = CKRecord(
            recordType: CalendarSharingCloudSchema.calendarRecordType,
            recordID: rootID
        )
        CalendarSharingCloudSchema.apply(calendarID: calendarID, name: "Empty", to: root)
        var records = SharedZoneRecordCollection()
        records.apply([root])

        let payload = try XCTUnwrap(
            ReceivedSharedCalendarPayloadAssembler.makePayload(zoneID: zoneID, records: records)
        )
        XCTAssertEqual(payload.calendar.id, calendarID)
        XCTAssertNil(payload.calendar.ownerDisplayName)
        XCTAssertTrue(payload.events.isEmpty)
        XCTAssertTrue(payload.shifts.isEmpty)
        XCTAssertTrue(payload.workRecords.isEmpty)
    }

    func testReceivedDescriptorCarriesFormattedShareOwnerNameWithoutCloudRecordField() throws {
        let calendarID = UUID()
        let zoneID = CKRecordZone.ID(
            zoneName: CalendarSharingCloudSchema.zoneName(for: calendarID),
            ownerName: "owner"
        )
        let root = CKRecord(
            recordType: CalendarSharingCloudSchema.calendarRecordType,
            recordID: CKRecord.ID(
                recordName: CalendarSharingCloudSchema.calendarRecordName,
                zoneID: zoneID
            )
        )
        CalendarSharingCloudSchema.apply(calendarID: calendarID, name: "Family", to: root)
        var components = PersonNameComponents()
        components.givenName = "Sou"
        let ownerDisplayName = CalendarSharingPersonNameFormatter.displayName(
            from: components,
            locale: Locale(identifier: "en_US")
        )

        let descriptor = try XCTUnwrap(
            CalendarSharingCloudSchema.receivedDescriptor(
                from: root,
                zoneID: zoneID,
                ownerDisplayName: ownerDisplayName,
                participantCount: 1
            )
        )

        XCTAssertEqual(descriptor.ownerDisplayName, "Sou")
        XCTAssertNil(root["ownerDisplayName"])
    }

    func testPersonNameFormatterReturnsNilForNonNilEmptyComponents() {
        XCTAssertNil(
            CalendarSharingPersonNameFormatter.displayName(
                from: PersonNameComponents(),
                locale: Locale(identifier: "en_US")
            )
        )
    }

    func testOldReceivedDescriptorCacheWithoutOwnerDisplayNameStillDecodes() throws {
        let calendarID = UUID()
        let json = """
        {
          "id": "\(calendarID.uuidString)",
          "zoneName": "zone",
          "ownerName": "owner",
          "calendarName": "Legacy",
          "participantCount": 1,
          "kind": "sharedReceived",
          "rootRecordName": "calendar",
          "shareRecordName": "\(CKRecordNameZoneWideShare)"
        }
        """

        let descriptor = try JSONDecoder().decode(
            SharedCalendarDescriptor.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(descriptor.calendarName, "Legacy")
        XCTAssertNil(descriptor.ownerDisplayName)
    }

    func testProjectKeepsMarketingVersionTwoPointOneAndBuildEighteen() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let project = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Project.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(project.contains("let marketingVersion = \"2.1\""))
        XCTAssertTrue(project.contains("let buildNumber = \"18\""))
    }

    func testEveryCalendarGetsAnIndependentZoneName() {
        let first = UUID()
        let second = UUID()

        XCTAssertNotEqual(
            CalendarSharingCloudSchema.zoneName(for: first),
            CalendarSharingCloudSchema.zoneName(for: second)
        )
        XCTAssertEqual(
            CalendarSharingCloudSchema.calendarID(
                from: CalendarSharingCloudSchema.zoneName(for: first)
            ),
            first
        )
    }
}

@MainActor
final class CalendarSharingAcceptanceCoordinatorTests: XCTestCase {
    func testBuiltHostBundleEnablesCloudKitSharingSystemRegistration() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "CKSharingSupported") as? Bool,
            true
        )
    }

    func testMainWindowSceneConfigurationRegistersCloudKitSceneDelegate() {
        let configuration = TimeNestAppDelegate.sceneConfiguration(for: .windowApplication)

        XCTAssertTrue(configuration.delegateClass === TimeNestSceneDelegate.self)
    }

    func testSharedCalendarSymbolExistsOnSupportedIOSRuntime() {
        XCTAssertNotNil(UIImage(systemName: "person.2.fill"))
    }

    func testTerminatedLaunchMetadataWaitsForStoreRegistration() async {
        let coordinator = CalendarSharingAcceptanceCoordinator()
        let metadata = makeFakeSharingMetadata()
        var acceptedCount = 0

        coordinator.receive(metadata, identifier: "terminated")
        XCTAssertEqual(coordinator.pendingCount, 1)

        coordinator.register { _ in
            acceptedCount += 1
            return .completed
        }
        await coordinator.waitUntilIdle()

        XCTAssertEqual(acceptedCount, 1)
        XCTAssertEqual(coordinator.pendingCount, 0)
    }

    func testForegroundMetadataProcessesImmediately() async {
        let coordinator = CalendarSharingAcceptanceCoordinator()
        let metadata = makeFakeSharingMetadata()
        var acceptedCount = 0
        coordinator.register { _ in
            acceptedCount += 1
            return .completed
        }

        coordinator.receive(metadata, identifier: "foreground")
        await coordinator.waitUntilIdle()

        XCTAssertEqual(acceptedCount, 1)
        XCTAssertEqual(coordinator.pendingCount, 0)
    }

    func testDuplicateMetadataIsAcceptedOnlyOnce() async {
        let coordinator = CalendarSharingAcceptanceCoordinator()
        let metadata = makeFakeSharingMetadata(status: .accepted)
        var acceptedCount = 0
        coordinator.register { _ in
            acceptedCount += 1
            return .completed
        }

        coordinator.receive(metadata, identifier: "duplicate")
        coordinator.receive(metadata, identifier: "duplicate")
        await coordinator.waitUntilIdle()
        coordinator.receive(metadata, identifier: "duplicate")
        await coordinator.waitUntilIdle()

        XCTAssertEqual(acceptedCount, 1)
        XCTAssertEqual(coordinator.pendingCount, 0)
    }

    func testRetryableMetadataRemainsQueuedUntilExplicitRetry() async {
        let coordinator = CalendarSharingAcceptanceCoordinator()
        let metadata = makeFakeSharingMetadata()
        var attempt = 0
        coordinator.register { _ in
            attempt += 1
            return attempt == 1 ? .retryLater : .completed
        }

        coordinator.receive(metadata, identifier: "retry")
        await coordinator.waitUntilIdle()
        XCTAssertEqual(coordinator.pendingCount, 1)

        coordinator.retryPending()
        await coordinator.waitUntilIdle()

        XCTAssertEqual(attempt, 2)
        XCTAssertEqual(coordinator.pendingCount, 0)
    }

    func testDifferentMetadataProcessesSequentiallyInArrivalOrder() async {
        let coordinator = CalendarSharingAcceptanceCoordinator()
        let first = makeFakeSharingMetadata(zoneName: "first-zone")
        let second = makeFakeSharingMetadata(zoneName: "second-zone")
        var acceptedZoneNames: [String] = []
        coordinator.register { metadata in
            acceptedZoneNames.append(metadata.share.recordID.zoneID.zoneName)
            return .completed
        }

        coordinator.receive(first, identifier: "first")
        coordinator.receive(second, identifier: "second")
        await coordinator.waitUntilIdle()

        XCTAssertEqual(acceptedZoneNames, ["first-zone", "second-zone"])
        XCTAssertEqual(coordinator.pendingCount, 0)
    }
}

@MainActor
final class CalendarSharingStoreTests: XCTestCase {
    func testMonthInputConfirmationDoesNotSaveAndFinalActionWritesOneBatch() async throws {
        let repository = InMemoryEventRepository()
        let useCase = MonthInputTestEventUseCase(repository: repository)
        let store = makeStore(client: MockCalendarSharingClient(), calendars: [.personal(name: "Mine")],
                              eventUseCase: useCase)
        let model = CalendarPhotoImportViewModel(eventUseCase: useCase, sharingStore: store, initialDate: Date())
        model.draft.rows[0].setTitle("  Appointment  ")
        model.draft.addRow(on: model.draft.rows[0].candidate.date)
        model.draft.rows[1].setTitle("Another appointment")
        let beforeConfirmation = await model.saveSelected()
        XCTAssertFalse(beforeConfirmation)
        XCTAssertEqual(useCase.batchCallCount, 0)
        model.prepareConfirmation()
        XCTAssertEqual(model.step, .review)
        XCTAssertEqual(model.draft.confirmationRows.count, 2)
        XCTAssertEqual(useCase.batchCallCount, 0)
        let beforeSave = try await repository.event(id: model.draft.rows[0].id)
        XCTAssertNil(beforeSave)
        let saved = await model.saveSelected()
        XCTAssertTrue(saved)
        XCTAssertEqual(useCase.batchCallCount, 1)
        let first = try await repository.event(id: model.draft.rows[0].id)
        let second = try await repository.event(id: model.draft.rows[1].id)
        XCTAssertEqual(first?.title, "Appointment")
        XCTAssertEqual(second?.title, "Another appointment")
        XCTAssertEqual(first?.calendarID, TimeNestCalendar.personalID)
        let repeatSave = await model.saveSelected()
        XCTAssertFalse(repeatSave)
        XCTAssertEqual(useCase.batchCallCount, 1, "Repeated taps must not submit a completed batch")
    }

    func testMonthInputSaveFailureRetainsWholeDraftAndBackRefreshesConfirmation() async throws {
        let repository = InMemoryEventRepository()
        let useCase = MonthInputTestEventUseCase(repository: repository)
        useCase.failNextBatch = true
        let store = makeStore(client: MockCalendarSharingClient(), calendars: [.personal(name: "Mine")],
                              eventUseCase: useCase)
        let model = CalendarPhotoImportViewModel(eventUseCase: useCase, sharingStore: store, initialDate: Date())
        model.draft.rows[0].setTitle("Original")
        model.prepareConfirmation()
        let original = model.draft
        let failed = await model.saveSelected()
        XCTAssertFalse(failed)
        XCTAssertEqual(model.step, .review)
        XCTAssertEqual(model.draft, original)
        XCTAssertNotNil(model.failureMessage)
        XCTAssertFalse(model.isSaving)
        XCTAssertFalse(model.didSave)
        let unsaved = try await repository.event(id: model.draft.rows[0].id)
        XCTAssertNil(unsaved)
        model.backToInput()
        model.draft.rows[0].setTitle("Corrected")
        model.prepareConfirmation()
        XCTAssertEqual(model.draft.confirmationRows.first?.candidate.title, "Corrected")
        let retried = await model.saveSelected()
        XCTAssertTrue(retried)
        XCTAssertEqual(useCase.batchCallCount, 2)
        let saved = try await repository.event(id: model.draft.rows[0].id)
        XCTAssertEqual(saved?.title, "Corrected")
    }

    func testMonthInputPreservesEventOnlyPermissionOfReceivedCalendar() {
        var received = makeCalendar(kind: .sharedReceived, name: "Received")
        received.eventEditingAllowed = true
        received.collaborationProtocolVersion = 1
        received.participantPermission = .readWrite
        let useCase = EventUseCase(repository: InMemoryEventRepository())
        let store = makeStore(client: MockCalendarSharingClient(),
                              calendars: [.personal(name: "Mine"), received], eventUseCase: useCase)
        let model = CalendarPhotoImportViewModel(eventUseCase: useCase, sharingStore: store, initialDate: Date())
        model.draft.rows[0].setTitle("Meeting")
        model.setTargetCalendarID(received.id)
        model.prepareConfirmation()
        XCTAssertTrue(model.canSave)
        model.backToInput()
        model.draft.rows[0].selectShift(ShiftTimeTemplate(
            id: .night, nameKey: .calendarPhotoImportSchedule, displayName: "Night",
            note: "", colorHex: "123456", startTime: "20:30", endTime: "08:30", enabled: true
        ))
        model.prepareConfirmation()
        XCTAssertFalse(model.canSave)
        XCTAssertEqual(model.commonTargetCalendarID, received.id, "Never silently change the destination")
        XCTAssertFalse(model.compatibleCalendars.contains { $0.id == received.id })
        XCTAssertTrue(store.eventWritableCalendars.contains { $0.id == received.id })
        model.setTargetCalendarID(TimeNestCalendar.personalID)
        XCTAssertTrue(model.canSave)
        XCTAssertEqual(model.draft.confirmationRows.first?.shiftTemplateID, .night)
    }

    func testSharingRevisionKeepsPresentedDayDetail() async {
        let eventUseCase = EventUseCase(repository: InMemoryEventRepository())
        let store = makeStore(
            client: MockCalendarSharingClient(),
            calendars: [.personal(name: "My Calendar")],
            eventUseCase: eventUseCase
        )
        let viewModel = makeViewModel(eventUseCase: eventUseCase, store: store)
        viewModel.showingDayDetail = true

        await store.synchronizeAll()
        let didReload = await waitUntil { viewModel.grid != nil }

        XCTAssertTrue(didReload, "Timed out waiting for the sharing revision reload")
        XCTAssertTrue(viewModel.showingDayDetail)
    }

    func testSharingRevisionKeepsPresentedEntryEditor() async {
        let eventUseCase = EventUseCase(repository: InMemoryEventRepository())
        let store = makeStore(
            client: MockCalendarSharingClient(),
            calendars: [.personal(name: "My Calendar")],
            eventUseCase: eventUseCase
        )
        let viewModel = makeViewModel(eventUseCase: eventUseCase, store: store)
        viewModel.showingEntryEditor = true

        await store.synchronizeAll()
        let didReload = await waitUntil { viewModel.grid != nil }

        XCTAssertTrue(didReload, "Timed out waiting for the sharing revision reload")
        XCTAssertTrue(viewModel.showingEntryEditor)
    }

    func testSharingRevisionStillReloadsMonthGrid() async throws {
        let eventUseCase = EventUseCase(repository: InMemoryEventRepository())
        let store = makeStore(
            client: MockCalendarSharingClient(),
            calendars: [.personal(name: "My Calendar")],
            eventUseCase: eventUseCase
        )
        let viewModel = makeViewModel(eventUseCase: eventUseCase, store: store)
        let eventDate = makeTestDate(year: 2026, month: 8, day: 21)
        viewModel.selectedDate = eventDate
        await viewModel.reloadMonth()
        XCTAssertTrue(viewModel.grid?.days.flatMap(\.events).isEmpty == true)

        try await eventUseCase.createEvent(makeEvent(title: "Synced", startDate: eventDate))
        await store.synchronizeAll()
        let didReloadSyncedEvent = await waitUntil {
            viewModel.grid?.days.flatMap(\.events).map(\.title) == ["Synced"]
        }

        XCTAssertTrue(didReloadSyncedEvent, "Timed out waiting for the synced event to appear")
        XCTAssertEqual(viewModel.grid?.days.flatMap(\.events).map(\.title), ["Synced"])
    }

    func testCalendarSelectionChangeClosesPresentations() async {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let eventUseCase = EventUseCase(repository: InMemoryEventRepository())
        let store = makeStore(
            client: MockCalendarSharingClient(ownedStates: [makeOwnedState(calendar: owned)]),
            calendars: [.personal(name: "My Calendar"), owned],
            eventUseCase: eventUseCase
        )
        let viewModel = makeViewModel(eventUseCase: eventUseCase, store: store)
        viewModel.showingDayDetail = true
        viewModel.showingEntryEditor = true

        store.select(.calendar(owned.id))
        let didClosePresentations = await waitUntil {
            !viewModel.showingDayDetail && !viewModel.showingEntryEditor
        }

        XCTAssertTrue(didClosePresentations, "Timed out waiting for the calendar selection observer")
        XCTAssertEqual(store.selection, .calendar(owned.id))
        XCTAssertFalse(viewModel.showingDayDetail)
        XCTAssertFalse(viewModel.showingEntryEditor)
    }

    func testICloudAccountStatusesAreDistinctAndBlockUnavailableRefreshes() async {
        let client = MockCalendarSharingClient()
        client.iCloudStatusResult = .noAccount
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")]
        )

        await store.synchronizeAll(forceICloudStatusRefresh: true)

        XCTAssertEqual(store.iCloudStatus, .noAccount)
        XCTAssertEqual(store.lastError, .noICloudAccount)
        XCTAssertEqual(store.syncStatus, .failed)
        XCTAssertEqual(client.iCloudStatusCallCount, 1)

        client.iCloudStatusResult = .restricted
        _ = await store.refreshICloudStatus(force: true)
        XCTAssertEqual(store.iCloudStatus, .restricted)
        XCTAssertEqual(store.iCloudStatus.operationError, .iCloudRestricted)

        client.iCloudStatusResult = .couldNotDetermine
        _ = await store.refreshICloudStatus(force: true)
        XCTAssertEqual(store.iCloudStatus, .couldNotDetermine)
        XCTAssertEqual(store.iCloudStatus.operationError, .iCloudStatusUnavailable)
    }

    func testSuccessfulRefreshUpdatesTimestampAndFailurePreservesIt() async {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let client = MockCalendarSharingClient(
            ownedStates: [makeOwnedState(calendar: owned)]
        )
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar"), owned]
        )

        await store.synchronizeAll()
        let successfulTimestamp = store.lastSuccessfulSyncAt
        XCTAssertNotNil(successfulTimestamp)

        client.failNextSync(calendarID: owned.id)
        await store.synchronizeAll()

        XCTAssertEqual(store.syncStatus, .failed)
        XCTAssertEqual(store.lastSuccessfulSyncAt, successfulTimestamp)
    }

    func testPendingInvitationRetryRefreshesAcceptedStateWithoutRevoking() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let pending = makeParticipant(id: "pending", isAccepted: false)
        let accepted = makeParticipant(id: "pending", isAccepted: true)
        let client = MockCalendarSharingClient(
            ownedStates: [makeOwnedState(calendar: owned, participants: [pending])]
        )
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar"), owned]
        )
        await store.synchronizeAll()
        let statusChecksBeforeRetry = client.iCloudStatusCallCount
        client.ownedStates = [makeOwnedState(calendar: owned, participants: [accepted])]

        try await store.refreshOwnedInvitationStatus(calendarID: owned.id)

        XCTAssertTrue(store.participants(for: owned.id).contains(where: \.isAccepted))
        XCTAssertTrue(client.revokedParticipantIDs.isEmpty)
        XCTAssertEqual(client.iCloudStatusCallCount, statusChecksBeforeRetry + 1)
        XCTAssertEqual(store.syncStatus, .synced)
    }

    func testPendingInvitationRetryCanRemainPendingWithoutDeletingParticipant() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let pending = makeParticipant(id: "pending", isAccepted: false)
        let client = MockCalendarSharingClient(
            ownedStates: [makeOwnedState(calendar: owned, participants: [pending])]
        )
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar"), owned]
        )

        try await store.refreshOwnedInvitationStatus(calendarID: owned.id)

        XCTAssertEqual(store.participants(for: owned.id).map(\.id), [pending.id])
        XCTAssertFalse(store.participants(for: owned.id)[0].isAccepted)
        XCTAssertTrue(client.revokedParticipantIDs.isEmpty)
    }

    func testPendingInvitationRefreshFailureUsesSyncErrorAndPreservesTimestamp() async {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let pending = makeParticipant(id: "pending", isAccepted: false)
        let client = MockCalendarSharingClient(
            ownedStates: [makeOwnedState(calendar: owned, participants: [pending])]
        )
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar"), owned]
        )
        await store.synchronizeAll()
        let successfulTimestamp = store.lastSuccessfulSyncAt
        client.failNextOwnedFetch()

        do {
            try await store.refreshOwnedInvitationStatus(calendarID: owned.id)
            XCTFail("Injected refresh failure must be surfaced")
        } catch {
            XCTAssertEqual(error as? CalendarSharingError, .syncFailed)
        }

        XCTAssertEqual(store.lastSuccessfulSyncAt, successfulTimestamp)
        XCTAssertEqual(store.lastError, .syncFailed)
        XCTAssertNotEqual(store.lastError, .invitationCancellationFailed)
        XCTAssertTrue(client.revokedParticipantIDs.isEmpty)
    }

    func testDisplayStatusDerivesFromExistingStoreState() async {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let accepted = makeParticipant(id: "accepted", isAccepted: true)
        let client = MockCalendarSharingClient(
            ownedStates: [makeOwnedState(calendar: owned, participants: [accepted])]
        )
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar"), owned]
        )

        await store.synchronizeAll()

        XCTAssertEqual(store.displayStatus(for: owned), .shared)
        XCTAssertEqual(store.displayStatus(for: store.personalCalendar), .notShared)
    }

    func testPersonalCalendarNeverEntersCloudUploadPath() async {
        let personal = TimeNestCalendar.personal(name: "My Calendar")
        let client = MockCalendarSharingClient()
        let store = makeStore(client: client, calendars: [personal])

        await store.synchronizeAll()

        XCTAssertTrue(client.synchronizedCalendarIDs.isEmpty)
    }

    func testCreateSharedCalendarCreatesOwnedCalendarThenReturnsSystemInvitation() async throws {
        let client = MockCalendarSharingClient()
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")]
        )

        let invitation = try await store.createSharedCalendar(name: " Family ")

        XCTAssertEqual(store.calendar(id: invitation.calendarID)?.kind, .sharedOwned)
        XCTAssertEqual(store.calendar(id: invitation.calendarID)?.name, "Family")
        XCTAssertEqual(store.selection, .calendar(invitation.calendarID))
        XCTAssertEqual(client.ownedStates.map(\.calendar.id), [invitation.calendarID])
        XCTAssertEqual(client.ownedStates.first?.participants.count, 1)
    }

    func testCreateSharedCalendarCanCopyPersonalEventsAndShiftsWithoutWorkRecords() async throws {
        let personal = TimeNestCalendar.personal(name: "My Calendar")
        let calendarRepository = InMemoryCalendarRepository(calendars: [personal])
        let eventRepository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let personalEvent = makeEvent(title: "Appointment")
        let personalShift = makeEvent(
            title: "Day Shift",
            shiftTemplateID: .day
        )
        let personalWorkRecord = makeWorkClockEvent(
            kind: .clockIn,
            calendarID: TimeNestCalendar.personalID,
            sessionID: UUID()
        )
        for event in [personalEvent, personalShift, personalWorkRecord] {
            try await eventRepository.create(event)
        }
        let client = MockCalendarSharingClient()
        let store = makeStore(
            client: client,
            calendars: [personal],
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )

        let invitation = try await store.createSharedCalendar(
            name: "Family",
            creationMode: .copyPersonalCalendar
        )

        let copiedEvents = try await eventUseCase.events(
            in: DateInterval(start: .distantPast, end: .distantFuture),
            calendarID: invitation.calendarID
        )
        XCTAssertEqual(Set(copiedEvents.map(\.title)), ["Appointment", "Day Shift"])
        XCTAssertTrue(copiedEvents.allSatisfy { $0.calendarID == invitation.calendarID })
        XCTAssertTrue(
            Set(copiedEvents.map(\.id)).isDisjoint(
                with: [personalEvent.id, personalShift.id, personalWorkRecord.id]
            )
        )
        let uploaded = try XCTUnwrap(client.lastPayloadByCalendarID[invitation.calendarID])
        XCTAssertEqual(uploaded.events.map(\.title), ["Appointment"])
        XCTAssertEqual(uploaded.shifts.map(\.displayName), ["Day Shift"])
        XCTAssertTrue(uploaded.workRecords.isEmpty)

        var updatedPersonalEvent = personalEvent
        updatedPersonalEvent.title = "Changed Later"
        updatedPersonalEvent.updatedAt = Date()
        try await eventUseCase.updateEvent(updatedPersonalEvent)
        await store.synchronizeOwnedEventsIfNeeded()

        let targetEventsAfterSourceUpdate = try await eventUseCase.events(
            in: DateInterval(start: .distantPast, end: .distantFuture),
            calendarID: invitation.calendarID
        )
        XCTAssertEqual(Set(targetEventsAfterSourceUpdate.map(\.title)), ["Appointment", "Day Shift"])
    }

    func testCopyModeStillCreatesSharedCalendarWhenPersonalCalendarIsEmpty() async throws {
        let client = MockCalendarSharingClient()
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")]
        )

        let invitation = try await store.createSharedCalendar(
            name: "Empty Copy",
            creationMode: .copyPersonalCalendar
        )

        XCTAssertEqual(store.calendar(id: invitation.calendarID)?.kind, .sharedOwned)
        XCTAssertEqual(store.calendar(id: invitation.calendarID)?.name, "Empty Copy")
        XCTAssertEqual(client.ownedStates.map(\.calendar.id), [invitation.calendarID])
    }

    func testOverwriteAllFromOwnedSharedCalendarReplacesAllThreeLocalDataTypes() async throws {
        let personal = TimeNestCalendar.personal(name: "My Calendar")
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let calendarRepository = InMemoryCalendarRepository(calendars: [personal, owned])
        let eventRepository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let sourceDate = makeTestDate(year: 2026, month: 8, day: 10, hour: 9)
        let sourceEvent = makeEvent(
            title: "Shared Appointment",
            calendarID: owned.id,
            startDate: sourceDate
        )
        let sourceShift = makeEvent(
            title: "Shared Day Shift",
            calendarID: owned.id,
            shiftTemplateID: .day,
            startDate: sourceDate.addingTimeInterval(2 * 3_600),
            endDate: sourceDate.addingTimeInterval(10 * 3_600)
        )
        let sourceSessionID = UUID()
        let sourceClockOutDate = sourceDate.addingTimeInterval(8 * 3_600)
        let sourceWorkEvents = makeWorkRecordEvents(
            title: "Shared Work",
            calendarID: owned.id,
            workDate: sourceDate,
            clockInDate: sourceDate,
            clockOutDate: sourceClockOutDate,
            sessionID: sourceSessionID,
            transportFee: 800,
            hourlyRate: 2_000
        )

        let targetEvent = makeEvent(title: "Old Appointment", startDate: sourceDate)
        let targetShift = makeEvent(
            title: "Old Shift",
            shiftTemplateID: .night,
            startDate: sourceDate
        )
        let targetSessionID = UUID()
        let targetWorkEvents = makeWorkRecordEvents(
            title: "Old Work",
            workDate: sourceDate,
            clockInDate: sourceDate,
            clockOutDate: sourceClockOutDate,
            sessionID: targetSessionID
        )
        let sourceEvents = [sourceEvent, sourceShift] + sourceWorkEvents
        let oldTargetEvents = [targetEvent, targetShift] + targetWorkEvents
        for event in sourceEvents + oldTargetEvents {
            try await eventRepository.create(event)
        }
        let store = makeStore(
            client: MockCalendarSharingClient(),
            calendars: [personal, owned],
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )

        let copies = try await store.overwritePersonalCalendar(
            from: owned.id,
            to: personal.id,
            scope: .all
        )

        let targetEvents = try await eventUseCase.events(
            in: DateInterval(start: .distantPast, end: .distantFuture),
            calendarID: personal.id
        )
        XCTAssertEqual(targetEvents.count, 4)
        XCTAssertEqual(
            targetEvents.filter(SharedEventMapper.isShareable).map(\.title),
            ["Shared Appointment"]
        )
        XCTAssertEqual(
            targetEvents.filter { $0.shiftTemplateID != nil }.map(\.title),
            ["Shared Day Shift"]
        )
        let copiedWorkEvents = targetEvents.filter(SharedWorkRecordMapper.isCandidate)
        XCTAssertEqual(copiedWorkEvents.count, 2)
        XCTAssertTrue(copiedWorkEvents.allSatisfy {
            $0.workInfo?.transportFee == nil && $0.workInfo?.hourlyRate == nil
        })
        XCTAssertNotEqual(copiedWorkEvents.first?.workInfo?.workSessionId, sourceSessionID)
        XCTAssertTrue(Set(oldTargetEvents.map(\.id)).isDisjoint(with: targetEvents.map(\.id)))
        XCTAssertTrue(Set(sourceEvents.map(\.id)).isDisjoint(with: copies.map(\.id)))

        var changedSourceEvent = sourceEvent
        changedSourceEvent.title = "Changed Later"
        changedSourceEvent.updatedAt = Date()
        try await eventUseCase.updateEvent(changedSourceEvent)

        let targetAfterSourceChange = try await eventUseCase.events(
            in: DateInterval(start: .distantPast, end: .distantFuture),
            calendarID: personal.id
        )
        XCTAssertEqual(
            targetAfterSourceChange.filter(SharedEventMapper.isShareable).map(\.title),
            ["Shared Appointment"]
        )
    }

    func testReceivedOverwriteRequiresEverySnapshotKeyAndPreservesPersonalData() async throws {
        for missingSnapshot in ["events", "shifts", "workRecords"] {
            let personal = TimeNestCalendar.personal(name: "My Calendar")
            let received = makeCalendar(kind: .sharedReceived, name: "Team")
            let calendarRepository = InMemoryCalendarRepository(calendars: [personal, received])
            let eventRepository = ControlledEventRepository()
            let eventUseCase = EventUseCase(
                repository: eventRepository,
                calendarRepository: calendarRepository
            )
            let date = makeTestDate(year: 2026, month: 8, day: 10, hour: 9)
            let personalEvent = makeEvent(title: "Keep Event", startDate: date)
            let personalShift = makeEvent(
                title: "Keep Shift",
                shiftTemplateID: .day,
                startDate: date.addingTimeInterval(2 * 3_600),
                endDate: date.addingTimeInterval(10 * 3_600)
            )
            let personalWorkRecords = makeWorkRecordEvents(
                title: "Keep Work",
                workDate: date,
                clockInDate: date,
                clockOutDate: date.addingTimeInterval(8 * 3_600),
                sessionID: UUID()
            )
            let originalEvents = [personalEvent, personalShift] + personalWorkRecords
            for event in originalEvents {
                try await eventRepository.create(event)
            }

            var eventsByCalendarID: [UUID: [SharedEventSnapshot]] = [received.id: []]
            var shiftsByCalendarID: [UUID: [SharedShiftSnapshot]] = [received.id: []]
            var workRecordsByCalendarID: [UUID: [SharedWorkRecordSnapshot]] = [received.id: []]
            switch missingSnapshot {
            case "events":
                eventsByCalendarID.removeValue(forKey: received.id)
            case "shifts":
                shiftsByCalendarID.removeValue(forKey: received.id)
            case "workRecords":
                workRecordsByCalendarID.removeValue(forKey: received.id)
            default:
                XCTFail("Unexpected snapshot fixture: \(missingSnapshot)")
            }
            let cache = CalendarSharingCache(
                fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(
                    "CalendarCopyReadinessTests-\(missingSnapshot)-\(UUID().uuidString).json"
                )
            )
            try cache.save(CalendarSharingCacheData(
                receivedCalendars: [makeReceivedPayload(calendar: received).calendar],
                eventsByCalendarID: eventsByCalendarID,
                shiftsByCalendarID: shiftsByCalendarID,
                workRecordsByCalendarID: workRecordsByCalendarID
            ))
            let store = makeStore(
                client: MockCalendarSharingClient(),
                calendars: [personal, received],
                eventUseCase: eventUseCase,
                calendarRepository: calendarRepository,
                cache: cache
            )

            do {
                _ = try await store.overwritePersonalCalendar(
                    from: received.id,
                    to: personal.id,
                    scope: .all
                )
                XCTFail("A missing \(missingSnapshot) snapshot key must block overwrite.")
            } catch {
                XCTAssertEqual(error as? CalendarSharingError, .syncFailed, missingSnapshot)
            }

            let applyBatchCallCount = await eventRepository.applyBatchCallCount()
            XCTAssertEqual(applyBatchCallCount, 0, missingSnapshot)
            let stored = await eventRepository.events(
                in: DateInterval(start: .distantPast, end: .distantFuture)
            )
            XCTAssertEqual(Set(stored.map(\.id)), Set(originalEvents.map(\.id)), missingSnapshot)
            for original in originalEvents {
                let storedOriginal = await eventRepository.event(id: original.id)
                XCTAssertEqual(storedOriginal, original, missingSnapshot)
            }
        }
    }

    func testReceivedOverwriteAcceptsMaterializedEmptySnapshotsAndClearsPersonalData() async throws {
        let personal = TimeNestCalendar.personal(name: "My Calendar")
        let received = makeCalendar(kind: .sharedReceived, name: "Team")
        let calendarRepository = InMemoryCalendarRepository(calendars: [personal, received])
        let eventRepository = ControlledEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let date = makeTestDate(year: 2026, month: 8, day: 10, hour: 9)
        let personalEvent = makeEvent(title: "Delete Event", startDate: date)
        let personalShift = makeEvent(
            title: "Delete Shift",
            shiftTemplateID: .night,
            startDate: date.addingTimeInterval(2 * 3_600),
            endDate: date.addingTimeInterval(10 * 3_600)
        )
        let personalWorkRecords = makeWorkRecordEvents(
            title: "Delete Work",
            workDate: date,
            clockInDate: date,
            clockOutDate: date.addingTimeInterval(8 * 3_600),
            sessionID: UUID()
        )
        for event in [personalEvent, personalShift] + personalWorkRecords {
            try await eventRepository.create(event)
        }
        let cache = CalendarSharingCache(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(
                "CalendarCopyEmptySnapshotsTests-\(UUID().uuidString).json"
            )
        )
        try cache.save(CalendarSharingCacheData(
            receivedCalendars: [makeReceivedPayload(calendar: received).calendar],
            eventsByCalendarID: [received.id: []],
            shiftsByCalendarID: [received.id: []],
            workRecordsByCalendarID: [received.id: []]
        ))
        let store = makeStore(
            client: MockCalendarSharingClient(),
            calendars: [personal, received],
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository,
            cache: cache
        )

        let copies = try await store.overwritePersonalCalendar(
            from: received.id,
            to: personal.id,
            scope: .all
        )

        XCTAssertTrue(copies.isEmpty)
        let applyBatchCallCount = await eventRepository.applyBatchCallCount()
        let stored = await eventRepository.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        XCTAssertEqual(applyBatchCallCount, 1)
        XCTAssertTrue(stored.isEmpty)
    }

    func testSpecifiedPeriodFromReceivedCalendarUsesInclusiveTypeSpecificDates() async throws {
        let personal = TimeNestCalendar.personal(name: "My Calendar")
        let received = makeCalendar(kind: .sharedReceived, name: "Team")
        let calendarRepository = InMemoryCalendarRepository(calendars: [personal, received])
        let eventRepository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let july31 = makeTestDate(year: 2026, month: 7, day: 31)
        let august1 = makeTestDate(year: 2026, month: 8, day: 1)
        let august15 = makeTestDate(year: 2026, month: 8, day: 15)
        let august31 = makeTestDate(year: 2026, month: 8, day: 31, hour: 23)
        let september1 = makeTestDate(year: 2026, month: 9, day: 1)

        let julyKeep = makeEvent(title: "July Keep", startDate: july31)
        let augustDelete = makeEvent(title: "August Delete", startDate: august15)
        let septemberKeep = makeEvent(title: "September Keep", startDate: september1)
        let julyOvernightShift = makeEvent(
            title: "July Overnight Keep",
            shiftTemplateID: .night,
            startDate: makeTestDate(year: 2026, month: 7, day: 31, hour: 23),
            endDate: makeTestDate(year: 2026, month: 8, day: 1, hour: 7)
        )
        let augustShiftDelete = makeEvent(
            title: "August Shift Delete",
            shiftTemplateID: .day,
            startDate: august15
        )
        let insideWorkSessionID = UUID()
        let insideWorkOutDate = september1.addingTimeInterval(7 * 3_600)
        let insideWorkEvents = makeWorkRecordEvents(
            title: "August Work Delete",
            workDate: august31,
            clockInDate: august31,
            clockOutDate: insideWorkOutDate,
            sessionID: insideWorkSessionID
        )
        let outsideWorkSessionID = UUID()
        let outsideWorkClockInDate = makeTestDate(
            year: 2026,
            month: 8,
            day: 31,
            hour: 23,
            minute: 30
        )
        let outsideWorkClockOutDate = september1.addingTimeInterval(8 * 3_600)
        let outsideWorkEvents = makeWorkRecordEvents(
            title: "September Work Keep",
            workDate: september1,
            clockInDate: outsideWorkClockInDate,
            clockOutDate: outsideWorkClockOutDate,
            sessionID: outsideWorkSessionID
        )
        let originalTargetEvents = [
            julyKeep,
            augustDelete,
            septemberKeep,
            julyOvernightShift,
            augustShiftDelete
        ] + insideWorkEvents + outsideWorkEvents
        for event in originalTargetEvents {
            try await eventRepository.create(event)
        }

        let descriptor = makeReceivedPayload(calendar: received).calendar
        let sharedEvents = [
            SharedEventSnapshot(
                id: UUID(),
                title: "Boundary Start Event",
                startDate: makeTestDate(year: 2026, month: 8, day: 1, hour: 0),
                endDate: makeTestDate(year: 2026, month: 8, day: 1, hour: 1),
                isAllDay: false,
                updatedAt: august1
            ),
            SharedEventSnapshot(
                id: UUID(),
                title: "Boundary End Event",
                startDate: august31,
                endDate: september1,
                isAllDay: false,
                updatedAt: august31
            ),
            SharedEventSnapshot(
                id: UUID(),
                title: "Outside Event",
                startDate: september1,
                endDate: september1.addingTimeInterval(3_600),
                isAllDay: false,
                updatedAt: september1
            )
        ]
        let sharedShifts = [
            SharedShiftSnapshot(
                id: UUID(),
                registeredDate: Calendar.current.startOfDay(for: august31),
                displayName: "Boundary End Shift",
                startDate: august31,
                endDate: september1.addingTimeInterval(7 * 3_600),
                spansMidnight: true,
                colorHex: "#5C6BC0",
                updatedAt: august31
            ),
            SharedShiftSnapshot(
                id: UUID(),
                registeredDate: Calendar.current.startOfDay(for: september1),
                displayName: "Outside Shift",
                startDate: september1,
                endDate: september1.addingTimeInterval(8 * 3_600),
                spansMidnight: false,
                colorHex: "#FFD54F",
                updatedAt: september1
            )
        ]
        let sharedWorkRecords = [
            SharedWorkRecordSnapshot(
                id: UUID(),
                workDate: Calendar.current.startOfDay(for: august1),
                workInTime: august1,
                workOutTime: august1.addingTimeInterval(8 * 3_600),
                isWorkOutTimeSet: true,
                restHours: 1,
                updatedAt: august1
            ),
            SharedWorkRecordSnapshot(
                id: UUID(),
                workDate: Calendar.current.startOfDay(for: september1),
                workInTime: september1,
                workOutTime: september1.addingTimeInterval(8 * 3_600),
                isWorkOutTimeSet: true,
                restHours: 1,
                updatedAt: september1
            )
        ]
        let cache = CalendarSharingCache(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(
                "CalendarCopyRangeTests-\(UUID().uuidString).json"
            )
        )
        try cache.save(CalendarSharingCacheData(
            receivedCalendars: [descriptor],
            eventsByCalendarID: [received.id: sharedEvents],
            shiftsByCalendarID: [received.id: sharedShifts],
            workRecordsByCalendarID: [received.id: sharedWorkRecords]
        ))
        let store = makeStore(
            client: MockCalendarSharingClient(),
            calendars: [personal, received],
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository,
            cache: cache
        )

        try await store.overwritePersonalCalendar(
            from: received.id,
            to: personal.id,
            scope: .inclusiveDateRange(startDate: august1, endDate: august31)
        )

        let targetEvents = try await eventUseCase.events(
            in: DateInterval(start: .distantPast, end: .distantFuture),
            calendarID: personal.id
        )
        let targetIDs = Set(targetEvents.map(\.id))
        XCTAssertTrue(targetIDs.contains(julyKeep.id))
        XCTAssertTrue(targetIDs.contains(septemberKeep.id))
        XCTAssertTrue(targetIDs.contains(julyOvernightShift.id))
        XCTAssertTrue(Set(outsideWorkEvents.map(\.id)).isSubset(of: targetIDs))
        XCTAssertFalse(targetIDs.contains(augustDelete.id))
        XCTAssertFalse(targetIDs.contains(augustShiftDelete.id))
        XCTAssertTrue(Set(insideWorkEvents.map(\.id)).isDisjoint(with: targetIDs))

        let ordinaryTitles = Set(targetEvents.filter(SharedEventMapper.isShareable).map(\.title))
        XCTAssertEqual(
            ordinaryTitles,
            ["July Keep", "September Keep", "Boundary Start Event", "Boundary End Event"]
        )
        let shiftTitles = Set(targetEvents.filter { $0.shiftTemplateID != nil }.map(\.title))
        XCTAssertEqual(shiftTitles, ["July Overnight Keep", "Boundary End Shift"])
        let workEvents = targetEvents.filter(SharedWorkRecordMapper.isCandidate)
        XCTAssertEqual(workEvents.count, 4)
        XCTAssertEqual(Set(workEvents.compactMap { $0.workInfo?.workSessionId }).count, 2)
        XCTAssertTrue(workEvents.allSatisfy {
            let workDate = $0.workInfo?.workDate
            return Calendar.current.isDate(workDate ?? .distantPast, inSameDayAs: august1)
                || Calendar.current.isDate(workDate ?? .distantPast, inSameDayAs: september1)
        })
    }

    func testEmptySharedRangeDeletesOnlyTargetRange() async throws {
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository)
        let july = makeEvent(
            title: "July Keep",
            startDate: makeTestDate(year: 2026, month: 7, day: 31)
        )
        let august = makeEvent(
            title: "August Delete",
            startDate: makeTestDate(year: 2026, month: 8, day: 15)
        )
        let september = makeEvent(
            title: "September Keep",
            startDate: makeTestDate(year: 2026, month: 9, day: 1)
        )
        for event in [july, august, september] {
            try await repository.create(event)
        }

        let copies = try await useCase.overwritePersonalCalendar(
            targetCalendarID: TimeNestCalendar.personalID,
            sharedEvents: [],
            sharedShifts: [],
            sharedWorkRecords: [],
            scope: .inclusiveDateRange(
                startDate: makeTestDate(year: 2026, month: 8, day: 1),
                endDate: makeTestDate(year: 2026, month: 8, day: 31)
            )
        )

        XCTAssertTrue(copies.isEmpty)
        let stored = try await useCase.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        XCTAssertEqual(Set(stored.map(\.id)), [july.id, september.id])
    }

    func testOrdinaryEventOverlapCopiesAndDeletesWholeEventsAcrossRangeBoundaries() async throws {
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository)
        let rangeStart = makeTestDate(year: 2026, month: 8, day: 1, hour: 0)
        let selectionEnd = makeTestDate(year: 2026, month: 8, day: 31)
        let rangeEnd = makeTestDate(year: 2026, month: 9, day: 1, hour: 0)
        let targetStartOverlap = makeEvent(
            title: "Delete Start Overlap",
            startDate: makeTestDate(year: 2026, month: 7, day: 31, hour: 22),
            endDate: makeTestDate(year: 2026, month: 8, day: 1, hour: 2)
        )
        let targetEndOverlap = makeEvent(
            title: "Delete End Overlap",
            startDate: makeTestDate(year: 2026, month: 8, day: 31, hour: 23),
            endDate: makeTestDate(year: 2026, month: 9, day: 1, hour: 2)
        )
        let targetBeforeRange = makeEvent(
            title: "Keep Before",
            startDate: makeTestDate(year: 2026, month: 7, day: 31, hour: 22),
            endDate: rangeStart
        )
        let targetAfterRange = makeEvent(
            title: "Keep After",
            startDate: rangeEnd,
            endDate: rangeEnd.addingTimeInterval(2 * 3_600)
        )
        for event in [
            targetStartOverlap,
            targetEndOverlap,
            targetBeforeRange,
            targetAfterRange
        ] {
            try await repository.create(event)
        }

        let sourceStartOverlap = SharedEventSnapshot(
            id: UUID(),
            title: "Copy Start Overlap",
            startDate: makeTestDate(year: 2026, month: 7, day: 31, hour: 22),
            endDate: makeTestDate(year: 2026, month: 8, day: 1, hour: 2),
            isAllDay: false,
            updatedAt: rangeStart
        )
        let sourceEndOverlap = SharedEventSnapshot(
            id: UUID(),
            title: "Copy End Overlap",
            startDate: makeTestDate(year: 2026, month: 8, day: 31, hour: 23),
            endDate: makeTestDate(year: 2026, month: 9, day: 1, hour: 2),
            isAllDay: false,
            updatedAt: rangeEnd
        )

        let copies = try await useCase.overwritePersonalCalendar(
            targetCalendarID: TimeNestCalendar.personalID,
            sharedEvents: [sourceStartOverlap, sourceEndOverlap],
            sharedShifts: [],
            sharedWorkRecords: [],
            scope: .inclusiveDateRange(startDate: rangeStart, endDate: selectionEnd)
        )

        XCTAssertEqual(copies.count, 2)
        let copiesByTitle = Dictionary(uniqueKeysWithValues: copies.map { ($0.title, $0) })
        let copiedStartOverlap = try XCTUnwrap(copiesByTitle[sourceStartOverlap.title])
        let copiedEndOverlap = try XCTUnwrap(copiesByTitle[sourceEndOverlap.title])
        XCTAssertEqual(copiedStartOverlap.startDate, sourceStartOverlap.startDate)
        XCTAssertEqual(copiedStartOverlap.endDate, sourceStartOverlap.endDate)
        XCTAssertEqual(copiedEndOverlap.startDate, sourceEndOverlap.startDate)
        XCTAssertEqual(copiedEndOverlap.endDate, sourceEndOverlap.endDate)

        let stored = try await useCase.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        let storedIDs = Set(stored.map(\.id))
        XCTAssertFalse(storedIDs.contains(targetStartOverlap.id))
        XCTAssertFalse(storedIDs.contains(targetEndOverlap.id))
        XCTAssertTrue(storedIDs.contains(targetBeforeRange.id))
        XCTAssertTrue(storedIDs.contains(targetAfterRange.id))
    }

    func testInvalidCopyRangeAndNonPersonalTargetDoNotWrite() async throws {
        let repository = ControlledEventRepository()
        let useCase = EventUseCase(repository: repository)
        let existing = makeEvent(title: "Keep")
        try await repository.create(existing)
        let start = makeTestDate(year: 2026, month: 8, day: 31)
        let end = makeTestDate(year: 2026, month: 8, day: 1)

        do {
            _ = try await useCase.overwritePersonalCalendar(
                targetCalendarID: TimeNestCalendar.personalID,
                sharedEvents: [],
                sharedShifts: [],
                sharedWorkRecords: [],
                scope: .inclusiveDateRange(startDate: start, endDate: end)
            )
            XCTFail("An invalid range must not execute the overwrite.")
        } catch {
            guard let useCaseError = error as? EventUseCaseError else {
                XCTFail("Expected invalidDateRange, got \(error)")
                return
            }
            guard case .invalidDateRange = useCaseError else {
                XCTFail("Expected invalidDateRange, got \(error)")
                return
            }
        }
        do {
            _ = try await useCase.overwritePersonalCalendar(
                targetCalendarID: UUID(),
                sharedEvents: [],
                sharedShifts: [],
                sharedWorkRecords: [],
                scope: .all
            )
            XCTFail("A shared calendar must not be accepted as the target.")
        } catch {
            XCTAssertEqual(error as? CalendarSharingError, .permissionDenied)
        }

        let applyBatchCallCount = await repository.applyBatchCallCount()
        let storedExisting = await repository.event(id: existing.id)
        XCTAssertEqual(applyBatchCallCount, 0)
        XCTAssertEqual(storedExisting, existing)
    }

    func testOverwriteBatchFailureKeepsOriginalTargetData() async throws {
        let repository = ControlledEventRepository()
        let useCase = EventUseCase(repository: repository)
        let existing = makeEvent(title: "Keep After Failure")
        try await repository.create(existing)
        await repository.failNextWrite()
        let sourceDate = makeTestDate(year: 2026, month: 8, day: 10)
        let source = SharedEventSnapshot(
            id: UUID(),
            title: "Replacement",
            startDate: sourceDate,
            endDate: sourceDate.addingTimeInterval(3_600),
            isAllDay: false,
            updatedAt: sourceDate
        )

        do {
            _ = try await useCase.overwritePersonalCalendar(
                targetCalendarID: TimeNestCalendar.personalID,
                sharedEvents: [source],
                sharedShifts: [],
                sharedWorkRecords: [],
                scope: .all
            )
            XCTFail("The injected batch failure must be surfaced.")
        } catch {
            XCTAssertTrue(error is InjectedSharingTestError)
        }

        let applyBatchCallCount = await repository.applyBatchCallCount()
        XCTAssertEqual(applyBatchCallCount, 1)
        let stored = await repository.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        XCTAssertEqual(stored, [existing])
    }

    func testSharedShiftTemplateIsNotPersistedWhenOverwriteBatchFails() async throws {
        let suiteName = "CalendarSharingTests-shift-template-failure-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.removePersistentDomain(forName: suiteName)

        let repository = ControlledEventRepository()
        let useCase = EventUseCase(
            repository: repository,
            shiftTemplateDefaults: defaults
        )
        let existing = makeEvent(title: "Keep After Shift Failure")
        try await repository.create(existing)
        await repository.failNextWrite()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let start = makeTestDate(year: 2026, month: 8, day: 10, hour: 13, minute: 30)
        let snapshot = SharedShiftSnapshot(
            id: UUID(),
            registeredDate: calendar.startOfDay(for: start),
            displayName: "Late Shift",
            startDate: start,
            endDate: makeTestDate(year: 2026, month: 8, day: 10, hour: 22, minute: 15),
            spansMidnight: false,
            colorHex: "#AF52DEFF",
            updatedAt: start
        )

        do {
            _ = try await useCase.overwritePersonalCalendar(
                targetCalendarID: TimeNestCalendar.personalID,
                sharedEvents: [],
                sharedShifts: [snapshot],
                sharedWorkRecords: [],
                scope: .all,
                calendar: calendar
            )
            XCTFail("The injected batch failure must be surfaced.")
        } catch {
            XCTAssertTrue(error is InjectedSharingTestError)
        }

        let stored = await repository.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        XCTAssertEqual(stored, [existing])
        let customTemplates = ShiftTimeTemplate.all(from: defaults).filter {
            if case .custom = $0.id { return true }
            return false
        }
        XCTAssertTrue(customTemplates.isEmpty)
        XCTAssertFalse(defaults.dictionaryRepresentation().keys.contains {
            $0.hasPrefix("shiftTime.custom.")
        })
    }

    func testSharedEventPermissionDefaultsReadOnlyAndCanCreateReadWriteInvitation() async throws {
        let readOnlyClient = MockCalendarSharingClient()
        let readOnlyStore = makeStore(
            client: readOnlyClient,
            calendars: [.personal(name: "My Calendar")]
        )

        let readOnlyInvitation = try await readOnlyStore.createSharedCalendar(name: "Read Only")

        XCTAssertFalse(
            try XCTUnwrap(readOnlyStore.ownedDescriptor(id: readOnlyInvitation.calendarID))
                .eventEditingAllowed
        )
        XCTAssertEqual(
            readOnlyStore.participants(for: readOnlyInvitation.calendarID).first?.permission,
            .readOnly
        )

        let readWriteClient = MockCalendarSharingClient()
        let readWriteStore = makeStore(
            client: readWriteClient,
            calendars: [.personal(name: "My Calendar")]
        )

        let readWriteInvitation = try await readWriteStore.createSharedCalendar(
            name: "Editable",
            eventEditingAllowed: true
        )

        XCTAssertTrue(
            try XCTUnwrap(readWriteStore.ownedDescriptor(id: readWriteInvitation.calendarID))
                .eventEditingAllowed
        )
        XCTAssertEqual(
            readWriteStore.participants(for: readWriteInvitation.calendarID).first?.permission,
            .readWrite
        )
    }

    func testOwnerCanToggleExistingParticipantPermissionAndCloudFailureDoesNotChangeLocalState() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let participant = makeParticipant(id: "accepted", isAccepted: true)
        let client = MockCalendarSharingClient(
            ownedStates: [makeOwnedState(calendar: owned, participants: [participant])]
        )
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar"), owned]
        )
        await store.synchronizeAll()

        try await store.setEventEditingAllowed(calendarID: owned.id, allowed: true)
        XCTAssertTrue(try XCTUnwrap(store.ownedDescriptor(id: owned.id)).eventEditingAllowed)
        XCTAssertEqual(store.participants(for: owned.id).first?.permission, .readWrite)

        try await store.setEventEditingAllowed(calendarID: owned.id, allowed: false)
        XCTAssertFalse(try XCTUnwrap(store.ownedDescriptor(id: owned.id)).eventEditingAllowed)
        XCTAssertEqual(store.participants(for: owned.id).first?.permission, .readOnly)

        client.eventEditingPermissionUpdateError = CalendarSharingError.syncFailed
        do {
            try await store.setEventEditingAllowed(calendarID: owned.id, allowed: true)
            XCTFail("Cloud failure must not update the local permission display")
        } catch {
            XCTAssertEqual(error as? CalendarSharingError, .syncFailed)
        }

        XCTAssertFalse(try XCTUnwrap(store.ownedDescriptor(id: owned.id)).eventEditingAllowed)
        XCTAssertEqual(store.participants(for: owned.id).first?.permission, .readOnly)
    }

    func testCancellingInvitationAfterCreationKeepsSharedCalendarAndShare() async throws {
        let client = MockCalendarSharingClient()
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")]
        )

        let invitation = try await store.createSharedCalendar(name: "Family")
        try await store.handleInvitationActivity(invitation, outcome: .cancelled)

        XCTAssertEqual(store.calendar(id: invitation.calendarID)?.kind, .sharedOwned)
        XCTAssertEqual(store.ownedDescriptor(id: invitation.calendarID)?.calendarName, "Family")
        XCTAssertEqual(client.ownedStates.map(\.calendar.id), [invitation.calendarID])
        XCTAssertTrue(store.participants(for: invitation.calendarID).isEmpty)

        let laterInvitation = try await store.createInvitation(for: invitation.calendarID)
        XCTAssertEqual(laterInvitation.calendarID, invitation.calendarID)
    }

    func testUnavailableInitialInvitationURLKeepsCreatedSharedCalendar() async {
        let client = MockCalendarSharingClient()
        client.invitationURL = nil
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")]
        )

        do {
            _ = try await store.createSharedCalendar(name: "Family")
            XCTFail("A missing invitation URL must be surfaced separately")
        } catch {
            XCTAssertEqual(error as? CalendarSharingError, .invitationURLUnavailable)
        }

        let created = store.calendars.first { $0.kind == .sharedOwned }
        XCTAssertEqual(created?.name, "Family")
        XCTAssertEqual(client.ownedStates.map(\.calendar.id), [created?.id].compactMap { $0 })
        XCTAssertTrue(created.map { store.participants(for: $0.id).isEmpty } ?? false)
    }

    func testCloudShareCreationFailureDoesNotKeepLocalCalendar() async {
        let client = MockCalendarSharingClient()
        client.createShareError = CalendarSharingError.shareCreationFailed
        let calendarRepository = InMemoryCalendarRepository(
            calendars: [.personal(name: "My Calendar")]
        )
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")],
            calendarRepository: calendarRepository
        )

        do {
            _ = try await store.createSharedCalendar(name: "Family")
            XCTFail("A CloudKit share creation failure must be surfaced")
        } catch {
            XCTAssertEqual(error as? CalendarSharingError, .shareCreationFailed)
        }

        XCTAssertFalse(store.calendars.contains { $0.kind == .sharedOwned })
        XCTAssertTrue(client.ownedStates.isEmpty)
    }

    func testConfirmedSelectorDeletionCallsExistingStopFlowExactlyOnce() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), owned]
        let calendarRepository = InMemoryCalendarRepository(calendars: calendars)
        let eventUseCase = EventUseCase(
            repository: InMemoryEventRepository(),
            calendarRepository: calendarRepository
        )
        let client = MockCalendarSharingClient(ownedStates: [makeOwnedState(calendar: owned)])
        let store = makeStore(
            client: client,
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        var state = CalendarSelectionActionState()

        _ = state.handle(.delete, for: owned)
        XCTAssertTrue(client.stoppedCalendarIDs.isEmpty)

        let confirmedID = try XCTUnwrap(state.beginConfirmedDeletion())
        try await store.stopOwnedSharing(id: confirmedID)

        XCTAssertNil(state.beginConfirmedDeletion())
        XCTAssertEqual(client.stoppedCalendarIDs, [owned.id])
        XCTAssertNil(store.calendar(id: owned.id))
    }

    func testRenameOwnedCalendarKeepsExistingStoreAndCloudRenamePath() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let client = MockCalendarSharingClient(ownedStates: [makeOwnedState(calendar: owned)])
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar"), owned]
        )
        await store.synchronizeAll()

        try await store.renameOwnedCalendar(id: owned.id, name: " Home ")

        XCTAssertEqual(client.renamedCalendarIDs, [owned.id])
        XCTAssertEqual(client.renamedCalendarNames, ["Home"])
        XCTAssertEqual(store.calendar(id: owned.id)?.name, "Home")
        XCTAssertEqual(store.ownedDescriptor(id: owned.id)?.calendarName, "Home")
    }

    func testNilInvitationURLNeverProducesShareableInvitation() async {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let client = MockCalendarSharingClient(ownedStates: [makeOwnedState(calendar: owned)])
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar"), owned]
        )
        await store.synchronizeAll()
        client.invitationURL = nil

        do {
            _ = try await store.createInvitation(for: owned.id)
            XCTFail("A nil one-time URL must stop before UIActivityViewController is presented")
        } catch {
            XCTAssertEqual(error as? CalendarSharingError, .invitationURLUnavailable)
        }

        XCTAssertEqual(client.revokedParticipantIDs.count, 1)
        XCTAssertTrue(store.participants(for: owned.id).isEmpty)
    }

    func testAcceptRefreshesAndSelectsReceivedCalendar() async {
        let received = makeCalendar(kind: .sharedReceived, name: "Family")
        let payload = makeReceivedPayload(calendar: received)
        let client = MockCalendarSharingClient()
        client.acceptedZoneName = payload.calendar.zoneName
        client.receivedPayloads = [payload]
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")]
        )
        let metadata = makeFakeSharingMetadata(zoneName: payload.calendar.zoneName)

        let result = await store.accept(metadata: metadata)

        XCTAssertEqual(result, .completed)
        XCTAssertEqual(client.acceptCallCount, 1)
        XCTAssertEqual(store.selection, .calendar(received.id))
        XCTAssertEqual(store.calendar(id: received.id)?.kind, .sharedReceived)
        XCTAssertEqual(store.calendars.filter { $0.id == received.id }.count, 1)
        XCTAssertNil(store.invitationAcceptanceError)
    }

    func testAcceptedMetadataOwnerNameImmediatelyFillsMissingReceivedOwnerName() async {
        let received = makeCalendar(kind: .sharedReceived, name: "Family")
        let payload = makeReceivedPayload(calendar: received)
        let client = MockCalendarSharingClient()
        client.acceptedZoneName = payload.calendar.zoneName
        client.receivedPayloads = [payload]
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")]
        )
        let metadata = makeFakeSharingMetadata(
            zoneName: payload.calendar.zoneName,
            ownerGivenName: "Sou"
        )

        let result = await store.accept(metadata: metadata)

        XCTAssertEqual(result, .completed)
        XCTAssertEqual(store.receivedDescriptor(id: received.id)?.ownerDisplayName, "Sou")
    }

    func testInvitationMetadataOwnerNameTakesPriorityDuringInitialAcceptRefresh() async {
        let received = makeCalendar(kind: .sharedReceived, name: "Family")
        var payload = makeReceivedPayload(calendar: received)
        var descriptor = payload.calendar
        descriptor.ownerDisplayName = "Refreshed Owner"
        payload = ReceivedSharedCalendarPayload(
            calendar: descriptor,
            events: payload.events,
            shifts: payload.shifts,
            workRecords: payload.workRecords
        )
        let client = MockCalendarSharingClient()
        client.receivedPayloads = [payload]
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")]
        )
        let metadata = makeFakeSharingMetadata(
            zoneName: payload.calendar.zoneName,
            ownerGivenName: "Metadata Owner"
        )

        let result = await store.accept(metadata: metadata)

        XCTAssertEqual(result, .completed)
        XCTAssertEqual(
            store.receivedDescriptor(id: received.id)?.ownerDisplayName,
            "Metadata Owner"
        )
    }

    func testRegularSharedDatabaseRefreshKeepsZoneWideShareOwnerName() async {
        let received = makeCalendar(kind: .sharedReceived, name: "Family")
        let initialPayload = makeReceivedPayload(calendar: received)
        var descriptor = initialPayload.calendar
        descriptor.ownerDisplayName = "Share Owner"
        let client = MockCalendarSharingClient()
        client.receivedPayloads = [
            ReceivedSharedCalendarPayload(
                calendar: descriptor,
                events: initialPayload.events,
                shifts: initialPayload.shifts,
                workRecords: initialPayload.workRecords
            )
        ]
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")]
        )

        await store.synchronizeAll()

        XCTAssertEqual(store.receivedDescriptor(id: received.id)?.ownerDisplayName, "Share Owner")
    }

    func testOwnerNameMergePreservesExistingNameWhenIncomingIsNil() {
        XCTAssertEqual(
            CalendarSharingOwnerDisplayNameResolver.resolve(
                incoming: nil,
                existing: "Owner A"
            ),
            "Owner A"
        )
    }

    func testOwnerNameMergePreservesExistingNameWhenIncomingIsEmpty() {
        XCTAssertEqual(
            CalendarSharingOwnerDisplayNameResolver.resolve(
                incoming: "",
                existing: "Owner A"
            ),
            "Owner A"
        )
    }

    func testOwnerNameMergePreservesExistingNameWhenIncomingIsWhitespace() {
        XCTAssertEqual(
            CalendarSharingOwnerDisplayNameResolver.resolve(
                incoming: " \n\t ",
                existing: " Owner A\n"
            ),
            "Owner A"
        )
    }

    func testOwnerNameMergeUsesNewValidName() {
        XCTAssertEqual(
            CalendarSharingOwnerDisplayNameResolver.resolve(
                incoming: " Owner B\n",
                existing: "Owner A"
            ),
            "Owner B"
        )
    }

    func testOwnerNameMergeKeepsNilWhenBothNamesAreMissing() {
        XCTAssertNil(
            CalendarSharingOwnerDisplayNameResolver.resolve(
                incoming: nil,
                existing: nil
            )
        )
    }

    func testRegularRefreshPreservesMetadataOwnerNameWhenIncomingNameIsMissing() async {
        let received = makeCalendar(kind: .sharedReceived, name: "Family")
        let client = MockCalendarSharingClient()
        client.receivedPayloads = [
            makeReceivedPayload(calendar: received, ownerDisplayName: "Owner A")
        ]
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")]
        )
        await store.synchronizeAll()

        client.receivedPayloads = [makeReceivedPayload(calendar: received)]
        await store.synchronizeAll()

        XCTAssertEqual(store.receivedDescriptor(id: received.id)?.ownerDisplayName, "Owner A")
    }

    func testUIFallbackIsNotPersistedInReceivedDescriptorCache() async {
        let received = makeCalendar(kind: .sharedReceived, name: "Family")
        let client = MockCalendarSharingClient()
        client.receivedPayloads = [makeReceivedPayload(calendar: received)]
        let cache = CalendarSharingCache(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("CalendarSharingStoreTests-\(UUID().uuidString).json")
        )
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")],
            cache: cache
        )

        await store.synchronizeAll()
        let renderedSubtitle = CalendarSharingLocalizedOwnerText.sharedByText(
            ownerDisplayName: store.receivedDescriptor(id: received.id)?.ownerDisplayName,
            format: "%@ shared",
            fallback: "Fallback",
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(renderedSubtitle, "Fallback")
        XCTAssertNil(store.receivedDescriptor(id: received.id)?.ownerDisplayName)
        XCTAssertNil(cache.load().receivedCalendars.first?.ownerDisplayName)
    }

    func testRemovedReceivedShareIsDeletedEvenWhenExistingOwnerNameCouldBePreserved() async {
        let received = makeCalendar(kind: .sharedReceived, name: "Family")
        let client = MockCalendarSharingClient()
        client.receivedPayloads = [
            makeReceivedPayload(calendar: received, ownerDisplayName: "Owner A")
        ]
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")]
        )
        await store.synchronizeAll()
        XCTAssertNotNil(store.receivedDescriptor(id: received.id))

        client.receivedPayloads = []
        await store.synchronizeAll()

        XCTAssertNil(store.receivedDescriptor(id: received.id))
        XCTAssertNil(store.calendar(id: received.id))
    }

    func testUnavailableCurrentUserNameDoesNotBlockSharedCalendarCreation() async throws {
        let client = MockCalendarSharingClient()
        client.currentUserDisplayNameResult = nil
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")]
        )

        let displayName = await store.currentUserDisplayName()
        XCTAssertNil(displayName)
        let invitation = try await store.createSharedCalendar(name: "My Shared Calendar")

        XCTAssertEqual(client.currentUserDisplayNameCallCount, 1)
        XCTAssertEqual(store.calendar(id: invitation.calendarID)?.name, "My Shared Calendar")
    }

    func testManualShareURLFetchesMetadataThenUsesExistingAcceptAndRefreshPath() async throws {
        let received = makeCalendar(kind: .sharedReceived, name: "Family")
        let payload = makeReceivedPayload(calendar: received)
        let metadata = makeFakeSharingMetadata(zoneName: payload.calendar.zoneName)
        let client = MockCalendarSharingClient()
        client.shareMetadata = metadata
        client.receivedPayloads = [payload]
        let router = makeInvitationRouter()
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")],
            invitationRouter: router
        )

        let result = try await store.acceptShareURL(
            " https://www.icloud.com/share/example-token "
        )

        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(client.shareMetadataFetchCallCount, 1)
        XCTAssertEqual(client.acceptCallCount, 1)
        XCTAssertEqual(client.cloudAcceptCallCount, 1)
        XCTAssertEqual(store.selection, .calendar(received.id))
        XCTAssertEqual(store.manualInvitationState, .accepted)
    }

    func testManualShareURLRejectsMetadataFromAnotherContainerBeforeAccept() async {
        let client = MockCalendarSharingClient()
        client.shareMetadata = makeFakeSharingMetadata(
            containerIdentifier: "iCloud.example.other"
        )
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")],
            invitationRouter: makeInvitationRouter()
        )

        do {
            _ = try await store.acceptShareURL(
                "https://www.icloud.com/share/example-token"
            )
            XCTFail("A foreign container must not reach the accept queue")
        } catch {
            XCTAssertEqual(
                error as? CalendarSharingError,
                .invitationContainerMismatch
            )
        }

        XCTAssertEqual(client.shareMetadataFetchCallCount, 1)
        XCTAssertEqual(client.acceptCallCount, 0)
        XCTAssertTrue(store.receivedCalendars.isEmpty)
    }

    func testConcurrentSameManualURLFetchesAndAcceptsOnlyOnce() async throws {
        let received = makeCalendar(kind: .sharedReceived, name: "Family")
        let payload = makeReceivedPayload(calendar: received)
        let client = MockCalendarSharingClient()
        client.shareMetadata = makeFakeSharingMetadata(
            zoneName: payload.calendar.zoneName
        )
        client.receivedPayloads = [payload]
        let gate = ControlledAsyncGate()
        client.shareMetadataFetchGate = gate
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")],
            invitationRouter: makeInvitationRouter()
        )
        let link = "https://www.icloud.com/share/example-token"

        async let first = store.acceptShareURL(link)
        await gate.waitUntilEntered()
        async let second = store.acceptShareURL(link)
        await Task.yield()

        XCTAssertEqual(client.shareMetadataFetchCallCount, 1)
        gate.release()
        let results = try await [first, second]

        XCTAssertEqual(results, [.accepted, .accepted])
        XCTAssertEqual(client.shareMetadataFetchCallCount, 1)
        XCTAssertEqual(client.cloudAcceptCallCount, 1)
        XCTAssertEqual(store.calendars.filter { $0.id == received.id }.count, 1)
    }

    func testManualURLAndSystemMetadataShareTheSameAcceptanceQueue() async throws {
        let received = makeCalendar(kind: .sharedReceived, name: "Family")
        let payload = makeReceivedPayload(calendar: received)
        let metadata = makeFakeSharingMetadata(zoneName: payload.calendar.zoneName)
        let client = MockCalendarSharingClient()
        client.shareMetadata = metadata
        client.receivedPayloads = [payload]
        let gate = ControlledAsyncGate()
        client.shareMetadataFetchGate = gate
        let coordinator = CalendarSharingAcceptanceCoordinator()
        let router = makeInvitationRouter(coordinator: coordinator)
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")],
            invitationRouter: router
        )

        async let manualResult = store.acceptShareURL(
            "https://www.icloud.com/share/example-token"
        )
        await gate.waitUntilEntered()
        router.receive(metadata, source: .scene)
        await coordinator.waitUntilIdle()
        gate.release()
        let resolvedManualResult = try await manualResult

        XCTAssertEqual(resolvedManualResult, .alreadyAccepted)
        XCTAssertEqual(client.cloudAcceptCallCount, 1)
        XCTAssertEqual(store.selection, .calendar(received.id))
        XCTAssertEqual(store.calendars.filter { $0.id == received.id }.count, 1)
    }

    func testAlreadyAcceptedManualMetadataSkipsCloudAcceptAndRefreshes() async throws {
        let received = makeCalendar(kind: .sharedReceived, name: "Family")
        let payload = makeReceivedPayload(calendar: received)
        let client = MockCalendarSharingClient()
        client.shareMetadata = makeFakeSharingMetadata(
            zoneName: payload.calendar.zoneName,
            status: .accepted
        )
        client.receivedPayloads = [payload]
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")],
            invitationRouter: makeInvitationRouter()
        )

        let result = try await store.acceptShareURL(
            "https://www.icloud.com/share/example-token"
        )

        XCTAssertEqual(result, .alreadyAccepted)
        XCTAssertEqual(client.acceptCallCount, 1)
        XCTAssertEqual(client.cloudAcceptCallCount, 0)
        XCTAssertEqual(store.selection, .calendar(received.id))
        XCTAssertEqual(store.manualInvitationState, .alreadyAccepted)
    }

    func testMetadataFetchFailureCreatesNothingAndCanBeRetried() async throws {
        let received = makeCalendar(kind: .sharedReceived, name: "Family")
        let payload = makeReceivedPayload(calendar: received)
        let client = MockCalendarSharingClient()
        client.shareMetadataError = InjectedSharingTestError.failure
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")],
            invitationRouter: makeInvitationRouter()
        )
        let link = "https://www.icloud.com/share/example-token"

        do {
            _ = try await store.acceptShareURL(link)
            XCTFail("Metadata fetch failure must remain visible to the input sheet")
        } catch {
            XCTAssertEqual(error as? CalendarSharingError, .metadataFetchFailed)
        }

        XCTAssertEqual(store.manualInvitationState, .failed(.metadataFetchFailed))
        XCTAssertTrue(store.receivedCalendars.isEmpty)
        XCTAssertEqual(client.acceptCallCount, 0)

        client.shareMetadataError = nil
        client.shareMetadata = makeFakeSharingMetadata(
            zoneName: payload.calendar.zoneName
        )
        client.receivedPayloads = [payload]
        let retryResult = try await store.acceptShareURL(link)

        XCTAssertEqual(retryResult, .accepted)
        XCTAssertEqual(client.shareMetadataFetchCallCount, 2)
        XCTAssertEqual(client.cloudAcceptCallCount, 1)
        XCTAssertEqual(store.selection, .calendar(received.id))
    }

    func testReceivedCalendarRetainsLocalHolidaysAcrossMonthWeekAndDayData() async throws {
        let received = makeCalendar(kind: .sharedReceived, name: "Family")
        let holidayDate = DateOnly(year: 2026, month: 7, day: 20)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let sharedEventStart = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 20,
            hour: 10
        )))
        let sharedEventID = UUID()
        let basePayload = makeReceivedPayload(calendar: received)
        let client = MockCalendarSharingClient()
        client.receivedPayloads = [
            ReceivedSharedCalendarPayload(
                calendar: basePayload.calendar,
                events: [
                    SharedEventSnapshot(
                        id: sharedEventID,
                        title: "Shared appointment",
                        startDate: sharedEventStart,
                        endDate: sharedEventStart.addingTimeInterval(3_600),
                        isAllDay: false,
                        updatedAt: sharedEventStart
                    )
                ],
                shifts: [],
                workRecords: []
            )
        ]
        let eventUseCase = EventUseCase(repository: InMemoryEventRepository())
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")],
            eventUseCase: eventUseCase
        )
        await store.synchronizeAll()
        store.select(.calendar(received.id))

        let holidayCache = InMemoryHolidayEventCacheRepository(events: [
            HolidayEvent(
                id: "japan-2026-07-20",
                region: .japan,
                date: holidayDate,
                name: "海の日",
                sourceURL: "https://example.invalid/japan.ics",
                importedAt: sharedEventStart
            )
        ])
        let defaults = UserDefaults(
            suiteName: "CalendarSharingHolidayTests-\(UUID().uuidString)"
        )!
        MonthSecondaryDisplayMode.save(.lunar, defaults: defaults)
        let subscriptionManager = HolidaySubscriptionManager(
            cacheRepository: holidayCache,
            userDefaults: defaults
        )
        let calendarDisplayUseCase = CalendarDisplayUseCase(
            holidayUseCase: HolidayUseCase(cacheRepository: holidayCache),
            localizationUseCase: CalendarLocalizationUseCase(),
            eventUseCase: eventUseCase
        )
        let viewModel = MonthCalendarViewModel(
            calendarDisplayUseCase: calendarDisplayUseCase,
            eventUseCase: eventUseCase,
            calendarSharingStore: store,
            subscriptionManager: subscriptionManager,
            userDefaults: defaults
        )
        viewModel.selectedDate = sharedEventStart

        await viewModel.reloadMonth()

        let monthCell = try XCTUnwrap(
            viewModel.grid?.days.first { $0.date == holidayDate }
        )
        XCTAssertEqual(monthCell.holidays.map(\.localizedNames.ja), ["海の日"])
        XCTAssertEqual(monthCell.holidays.map(\.localizedNames.zhHans), ["海の日"])
        XCTAssertEqual(monthCell.events.map(\.eventID), [sharedEventID])
        XCTAssertNotNil(monthCell.traditionalCalendar.lunarText)
        XCTAssertNil(monthCell.traditionalCalendar.rokuyoText)
        XCTAssertNil(monthCell.traditionalCalendar.solarTermText)
        XCTAssertEqual(
            viewModel.weekCells.first { $0.date == holidayDate }?.holidays.map(\.id),
            ["japan-2026-07-20"]
        )
        XCTAssertEqual(viewModel.dayCell?.holidays.map(\.id), ["japan-2026-07-20"])

        let japanSubscription = try XCTUnwrap(
            subscriptionManager.subscriptions.first { $0.region == .japan }
        )
        try subscriptionManager.disable(subscription: japanSubscription)
        let hiddenHolidayViewModel = MonthCalendarViewModel(
            calendarDisplayUseCase: calendarDisplayUseCase,
            eventUseCase: eventUseCase,
            calendarSharingStore: store,
            subscriptionManager: subscriptionManager,
            userDefaults: defaults
        )
        hiddenHolidayViewModel.selectedDate = sharedEventStart

        await hiddenHolidayViewModel.reloadMonth()

        let hiddenHolidayCell = try XCTUnwrap(
            hiddenHolidayViewModel.grid?.days.first { $0.date == holidayDate }
        )
        XCTAssertTrue(hiddenHolidayCell.holidays.isEmpty)
        XCTAssertEqual(hiddenHolidayCell.events.map(\.eventID), [sharedEventID])
    }

    func testAcceptFailureDoesNotCreateFakeReceivedCalendar() async {
        let client = MockCalendarSharingClient()
        client.acceptError = CalendarSharingError.invitationRevoked
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")]
        )

        let result = await store.accept(metadata: makeFakeSharingMetadata(status: .removed))

        XCTAssertEqual(result, .discarded)
        XCTAssertEqual(store.invitationAcceptanceError, .invitationRevoked)
        XCTAssertTrue(store.calendars.allSatisfy { $0.kind != .sharedReceived })
        XCTAssertTrue(store.receivedCalendars.isEmpty)
    }

    func testAcceptedShareWithFailedRefreshStaysRecoverable() async {
        let received = makeCalendar(kind: .sharedReceived, name: "Family")
        let payload = makeReceivedPayload(calendar: received)
        let metadata = makeFakeSharingMetadata(zoneName: payload.calendar.zoneName)
        let client = MockCalendarSharingClient()
        client.acceptedZoneName = payload.calendar.zoneName
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")]
        )
        let coordinator = CalendarSharingAcceptanceCoordinator()
        coordinator.register { metadata in
            await store.accept(metadata: metadata)
        }

        coordinator.receive(metadata, identifier: "recoverable-refresh")
        await coordinator.waitUntilIdle()

        XCTAssertEqual(coordinator.pendingCount, 1)
        XCTAssertEqual(client.acceptCallCount, 1)
        XCTAssertEqual(store.invitationAcceptanceError, .receivedCalendarRefreshFailed)
        XCTAssertTrue(store.receivedCalendars.isEmpty)

        client.receivedPayloads = [payload]
        coordinator.retryPending()
        await coordinator.waitUntilIdle()

        XCTAssertEqual(coordinator.pendingCount, 0)
        XCTAssertEqual(client.acceptCallCount, 1)
        XCTAssertEqual(store.selection, .calendar(received.id))
        XCTAssertNil(store.invitationAcceptanceError)
    }

    func testOwnedCalendarUploadsAllThreeBusinessTypes() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let state = makeOwnedState(calendar: owned)
        let client = MockCalendarSharingClient(ownedStates: [state])
        let eventRepository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(repository: eventRepository)
        try await eventUseCase.createEvent(makeEvent(title: "Appointment", calendarID: owned.id))
        try await eventUseCase.createEvent(
            makeEvent(title: "Day", calendarID: owned.id, shiftTemplateID: .day)
        )
        let workDate = Date(timeIntervalSince1970: 1_700_000_000)
        try await eventUseCase.createEvent(
            makeEvent(
                title: "Clock In",
                calendarID: owned.id,
                workInfo: WorkInfo(
                    workInTime: workDate,
                    restHours: 1,
                    workDate: workDate,
                    workSessionId: UUID()
                )
            )
        )
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar"), owned],
            eventUseCase: eventUseCase
        )

        await store.synchronizeAll()

        let uploaded = try XCTUnwrap(client.lastPayloadByCalendarID[owned.id])
        XCTAssertEqual(uploaded.events.count, 1)
        XCTAssertEqual(uploaded.shifts.count, 1)
        XCTAssertEqual(uploaded.workRecords.count, 1)
    }

    func testReceivedCalendarWriteIsRejectedAtStoreLayer() {
        let received = makeCalendar(kind: .sharedReceived, name: "Received")
        let store = makeStore(
            client: MockCalendarSharingClient(),
            calendars: [.personal(name: "My Calendar"), received]
        )

        XCTAssertThrowsError(try store.ensureCanWrite(calendarID: received.id)) {
            XCTAssertEqual($0 as? CalendarSharingError, .permissionDenied)
        }
    }

    func testStoppedReceivedShareIsRemovedAfterSuccessfulRefresh() async {
        let received = makeCalendar(kind: .sharedReceived, name: "Received")
        let store = makeStore(
            client: MockCalendarSharingClient(),
            calendars: [.personal(name: "My Calendar"), received]
        )
        store.select(.calendar(received.id))

        await store.synchronizeAll()

        XCTAssertNil(store.calendar(id: received.id))
        XCTAssertEqual(store.selection, .mine)
    }

    func testReceivedDetailsLeaveUsesExistingFlowAndKeepsOtherCalendars() async throws {
        let first = makeCalendar(kind: .sharedReceived, name: "First")
        let second = makeCalendar(kind: .sharedReceived, name: "Second")
        let client = MockCalendarSharingClient()
        client.receivedPayloads = [
            makeReceivedPayload(calendar: first),
            makeReceivedPayload(calendar: second)
        ]
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar")]
        )
        await store.synchronizeAll()
        store.select(.calendar(first.id))
        let descriptor = try XCTUnwrap(store.receivedCalendars.first { $0.id == first.id })

        try await store.leave(descriptor)

        XCTAssertEqual(client.leftCalendarIDs, [first.id])
        XCTAssertNil(store.calendar(id: first.id))
        XCTAssertNotNil(store.calendar(id: second.id))
        XCTAssertEqual(store.selection, .mine)
    }

    func testStoppingOwnedShareMovesLocalRowsToPersonalBeforeCalendarRemoval() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let client = MockCalendarSharingClient(ownedStates: [makeOwnedState(calendar: owned)])
        let eventRepository = InMemoryEventRepository()
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), owned]
        let calendarRepository = InMemoryCalendarRepository(calendars: calendars)
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let event = makeEvent(title: "Keep me", calendarID: owned.id)
        try await eventUseCase.createEvent(event)
        let store = makeStore(
            client: client,
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        await store.synchronizeAll()

        try await store.stopOwnedSharing(id: owned.id)

        let preservedEvent = try await eventUseCase.event(id: event.id)
        XCTAssertEqual(preservedEvent?.calendarID, TimeNestCalendar.personalID)
        XCTAssertNil(store.calendar(id: owned.id))
        XCTAssertEqual(client.stoppedCalendarIDs, [owned.id])
    }

    func testCrossZoneMoveCreatesTargetBeforeCleaningSource() async throws {
        let first = makeCalendar(kind: .sharedOwned, name: "First")
        let second = makeCalendar(kind: .sharedOwned, name: "Second")
        let client = MockCalendarSharingClient(
            ownedStates: [makeOwnedState(calendar: first), makeOwnedState(calendar: second)]
        )
        let eventRepository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(repository: eventRepository)
        let event = makeEvent(title: "Move", calendarID: first.id)
        try await eventUseCase.createEvent(event)
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar"), first, second],
            eventUseCase: eventUseCase
        )
        await store.synchronizeAll()
        client.synchronizedCalendarIDs.removeAll()

        try await store.moveEvent(event, to: second.id)

        XCTAssertEqual(client.synchronizedCalendarIDs, [second.id, first.id])
        let movedEvent = try await eventUseCase.event(id: event.id)
        XCTAssertEqual(movedEvent?.calendarID, second.id)
    }

    func testEventUseCaseFiltersEachLocalCalendar() async throws {
        let first = UUID()
        let second = UUID()
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository)
        try await useCase.createEvent(makeEvent(title: "First", calendarID: first))
        try await useCase.createEvent(makeEvent(title: "Second", calendarID: second))

        let result = try await useCase.events(
            in: DateInterval(start: .distantPast, end: .distantFuture),
            calendarID: first
        )

        XCTAssertEqual(result.map(\.title), ["First"])
    }

    func testEventUseCaseRejectsReceivedCalendarWriteAtApplicationLayer() async {
        let received = makeCalendar(kind: .sharedReceived, name: "Received")
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(
            repository: repository,
            calendarRepository: InMemoryCalendarRepository(
                calendars: [.personal(name: "My Calendar"), received]
            )
        )

        do {
            _ = try await useCase.createEvent(
                makeEvent(title: "Forbidden", calendarID: received.id)
            )
            XCTFail("Received calendars must reject writes")
        } catch {
            XCTAssertEqual(error as? CalendarSharingError, .permissionDenied)
        }
    }

    func testRapidChangesForOneCalendarStaySerialAndReplayLatestSnapshot() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), owned]
        let calendarRepository = InMemoryCalendarRepository(calendars: calendars)
        let eventRepository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        var event = makeEvent(title: "Initial", calendarID: owned.id)
        try await eventUseCase.createEvent(event)
        let client = MockCalendarSharingClient(ownedStates: [makeOwnedState(calendar: owned)])
        let store = makeStore(
            client: client,
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        await store.synchronizeAll()
        client.resetSyncHistory()

        let gate = client.pauseNextSync(calendarID: owned.id)
        let first = Task { @MainActor in await store.synchronizeOwnedEventsIfNeeded() }
        await gate.waitUntilEntered()

        event.title = "Latest"
        event.updatedAt = event.updatedAt.addingTimeInterval(1)
        try await eventUseCase.updateEvent(event)
        let second = Task { @MainActor in await store.synchronizeOwnedEventsIfNeeded() }
        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(client.payloadHistoryByCalendarID[owned.id]?.count, 1)
        XCTAssertEqual(client.maxConcurrentSyncsByCalendarID[owned.id], 1)

        gate.release()
        await first.value
        await second.value

        let history = try XCTUnwrap(client.payloadHistoryByCalendarID[owned.id])
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history.last?.events.map(\.title), ["Latest"])
        XCTAssertEqual(client.lastPayloadByCalendarID[owned.id]?.events.map(\.title), ["Latest"])
        XCTAssertEqual(client.maxConcurrentSyncsByCalendarID[owned.id], 1)
    }

    func testDeletionDuringPausedSyncCannotBeRecreatedByOlderSnapshot() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), owned]
        let calendarRepository = InMemoryCalendarRepository(calendars: calendars)
        let eventRepository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let event = makeEvent(title: "Delete me", calendarID: owned.id)
        try await eventUseCase.createEvent(event)
        let client = MockCalendarSharingClient(ownedStates: [makeOwnedState(calendar: owned)])
        let store = makeStore(
            client: client,
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        await store.synchronizeAll()
        client.resetSyncHistory()

        let gate = client.pauseNextSync(calendarID: owned.id)
        let first = Task { @MainActor in await store.synchronizeOwnedEventsIfNeeded() }
        await gate.waitUntilEntered()
        try await eventUseCase.deleteEvent(id: event.id)
        let second = Task { @MainActor in await store.synchronizeOwnedEventsIfNeeded() }
        gate.release()
        await first.value
        await second.value

        XCTAssertEqual(client.payloadHistoryByCalendarID[owned.id]?.count, 2)
        XCTAssertEqual(client.lastPayloadByCalendarID[owned.id]?.events, [])
        XCTAssertEqual(client.maxConcurrentSyncsByCalendarID[owned.id], 1)
    }

    func testFullRefreshOverlapReplaysEventChangeAfterCurrentUpload() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), owned]
        let calendarRepository = InMemoryCalendarRepository(calendars: calendars)
        let eventRepository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        var event = makeEvent(title: "Before", calendarID: owned.id)
        try await eventUseCase.createEvent(event)
        let client = MockCalendarSharingClient(ownedStates: [makeOwnedState(calendar: owned)])
        let store = makeStore(
            client: client,
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        let gate = client.pauseNextSync(calendarID: owned.id)

        let refresh = Task { @MainActor in await store.synchronizeAll() }
        await gate.waitUntilEntered()
        event.title = "During refresh"
        event.updatedAt = event.updatedAt.addingTimeInterval(1)
        try await eventUseCase.updateEvent(event)
        let eventSync = Task { @MainActor in await store.synchronizeOwnedEventsIfNeeded() }
        gate.release()
        await refresh.value
        await eventSync.value

        XCTAssertEqual(client.payloadHistoryByCalendarID[owned.id]?.count, 2)
        XCTAssertEqual(
            client.lastPayloadByCalendarID[owned.id]?.events.map(\.title),
            ["During refresh"]
        )
    }

    func testDifferentCalendarsUseIndependentWorkersAndGenerationState() async throws {
        let first = makeCalendar(kind: .sharedOwned, name: "First")
        let second = makeCalendar(kind: .sharedOwned, name: "Second")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), first, second]
        let calendarRepository = InMemoryCalendarRepository(calendars: calendars)
        let eventRepository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        try await eventUseCase.createEvent(makeEvent(title: "One", calendarID: first.id))
        try await eventUseCase.createEvent(makeEvent(title: "Two", calendarID: second.id))
        let client = MockCalendarSharingClient(
            ownedStates: [makeOwnedState(calendar: first), makeOwnedState(calendar: second)]
        )
        let store = makeStore(
            client: client,
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        await store.synchronizeAll()
        client.resetSyncHistory()
        let gate = client.pauseNextSync(calendarID: first.id)

        let sync = Task { @MainActor in await store.synchronizeOwnedEventsIfNeeded() }
        await gate.waitUntilEntered()
        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(client.completedCalendarIDs, [second.id])
        XCTAssertEqual(client.lastPayloadByCalendarID[second.id]?.events.map(\.title), ["Two"])
        XCTAssertNil(client.lastPayloadByCalendarID[first.id])

        gate.release()
        await sync.value
        XCTAssertEqual(client.lastPayloadByCalendarID[first.id]?.events.map(\.title), ["One"])
    }

    func testFailedSyncRemainsDirtyAndNextTriggerRecovers() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), owned]
        let calendarRepository = InMemoryCalendarRepository(calendars: calendars)
        let eventRepository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        var event = makeEvent(title: "Before", calendarID: owned.id)
        try await eventUseCase.createEvent(event)
        let client = MockCalendarSharingClient(ownedStates: [makeOwnedState(calendar: owned)])
        let store = makeStore(
            client: client,
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        await store.synchronizeAll()
        client.resetSyncHistory()
        client.failNextSync(calendarID: owned.id)

        await store.synchronizeOwnedEventsIfNeeded()
        XCTAssertEqual(store.lastError, .syncFailed)
        XCTAssertNil(client.lastPayloadByCalendarID[owned.id])

        event.title = "Recovered"
        event.updatedAt = event.updatedAt.addingTimeInterval(1)
        try await eventUseCase.updateEvent(event)
        await store.synchronizeOwnedEventsIfNeeded()

        XCTAssertEqual(client.lastPayloadByCalendarID[owned.id]?.events.map(\.title), ["Recovered"])
        XCTAssertNil(store.lastError)
    }

    func testCloudErrorRetryClassificationDistinguishesTransientAndPermissionFailures() {
        let transient = CKError(.serviceUnavailable)
        let permission = CKError(.permissionFailure)

        XCTAssertTrue(CalendarSharingErrorMapper.isRetryable(transient))
        XCTAssertFalse(CalendarSharingErrorMapper.isRetryable(permission))
        XCTAssertEqual(CalendarSharingErrorMapper.map(permission), .permissionDenied)
    }

    func testStoppingCancelsPausedSyncWithoutRestartingIt() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), owned]
        let calendarRepository = ControlledCalendarRepository(calendars: calendars)
        let eventRepository = ControlledEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        try await eventUseCase.createEvent(makeEvent(title: "Keep", calendarID: owned.id))
        let client = MockCalendarSharingClient(ownedStates: [makeOwnedState(calendar: owned)])
        let store = makeStore(
            client: client,
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        await store.synchronizeAll()
        client.resetSyncHistory()
        let gate = client.pauseNextSync(calendarID: owned.id)

        let sync = Task { @MainActor in
            await store.synchronizeOwnedEventsIfNeeded()
        }
        await gate.waitUntilEntered()
        try await store.stopOwnedSharing(id: owned.id)
        await sync.value

        XCTAssertEqual(client.synchronizedCalendarIDs, [owned.id])
        XCTAssertTrue(client.completedCalendarIDs.isEmpty)
        XCTAssertEqual(client.stoppedCalendarIDs, [owned.id])
        let removedCalendar = await calendarRepository.calendar(id: owned.id)
        XCTAssertNil(removedCalendar)
        let events = try await eventUseCase.events(
            in: DateInterval(start: .distantPast, end: .distantFuture),
            calendarID: TimeNestCalendar.personalID
        )
        XCTAssertEqual(events.map(\.title), ["Keep"])
    }

    func testStoppingDoesNotDeleteZoneWhenAtomicLocalReassignmentFails() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), owned]
        let calendarRepository = ControlledCalendarRepository(calendars: calendars)
        let eventRepository = ControlledEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let event = makeEvent(title: "Keep", calendarID: owned.id)
        try await eventUseCase.createEvent(event)
        await eventRepository.failNextReassignment()
        let client = MockCalendarSharingClient(ownedStates: [makeOwnedState(calendar: owned)])
        let store = makeStore(
            client: client,
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        store.select(.calendar(owned.id))

        do {
            try await store.stopOwnedSharing(id: owned.id)
            XCTFail("The injected local failure must stop before Cloud deletion")
        } catch {}

        let preservedEvent = try await eventUseCase.event(id: event.id)
        let stoppingCalendar = await calendarRepository.calendar(id: owned.id)
        XCTAssertTrue(client.stoppedCalendarIDs.isEmpty)
        XCTAssertEqual(preservedEvent?.calendarID, owned.id)
        XCTAssertEqual(stoppingCalendar?.stopPhase, .localReassignmentPending)
        XCTAssertEqual(store.selection, .mine)
        XCTAssertFalse(store.writableCalendars.contains { $0.id == owned.id })
    }

    func testLocalSuccessCloudFailurePersistsRetryableStoppingState() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), owned]
        let calendarRepository = ControlledCalendarRepository(calendars: calendars)
        let eventRepository = ControlledEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let event = makeEvent(title: "Keep", calendarID: owned.id)
        try await eventUseCase.createEvent(event)
        let client = MockCalendarSharingClient(ownedStates: [makeOwnedState(calendar: owned)])
        client.failNextStop()
        let store = makeStore(
            client: client,
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )

        do {
            try await store.stopOwnedSharing(id: owned.id)
            XCTFail("The injected Cloud failure must remain retryable")
        } catch {}

        let reassignedEvent = try await eventUseCase.event(id: event.id)
        let retryableCalendar = await calendarRepository.calendar(id: owned.id)
        XCTAssertEqual(reassignedEvent?.calendarID, TimeNestCalendar.personalID)
        XCTAssertEqual(retryableCalendar?.stopPhase, .cloudDeletionPending)
        XCTAssertNotNil(retryableCalendar)

        try await store.stopOwnedSharing(id: owned.id)
        let removedCalendar = await calendarRepository.calendar(id: owned.id)
        XCTAssertNil(removedCalendar)
        XCTAssertEqual(client.stoppedCalendarIDs, [owned.id, owned.id])
    }

    func testRestartResumesAfterLocalMigrationBeforeCloudDeletion() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), owned]
        let calendarRepository = ControlledCalendarRepository(calendars: calendars)
        let eventRepository = ControlledEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let event = makeEvent(title: "Keep", calendarID: owned.id)
        try await eventUseCase.createEvent(event)
        let client = MockCalendarSharingClient(ownedStates: [makeOwnedState(calendar: owned)])
        client.failNextStop()
        let firstStore = makeStore(
            client: client,
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        do { try await firstStore.stopOwnedSharing(id: owned.id) } catch {}

        let restartedStore = makeStore(
            client: client,
            calendars: await calendarRepository.calendars(),
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        await restartedStore.start()

        let removedCalendar = await calendarRepository.calendar(id: owned.id)
        let reassignedEvent = try await eventUseCase.event(id: event.id)
        XCTAssertNil(removedCalendar)
        XCTAssertEqual(reassignedEvent?.calendarID, TimeNestCalendar.personalID)
    }

    func testRestartFinishesAfterCloudDeletionBeforeLocalCalendarDeletion() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), owned]
        let calendarRepository = ControlledCalendarRepository(calendars: calendars)
        let eventRepository = ControlledEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let event = makeEvent(title: "Keep", calendarID: owned.id)
        try await eventUseCase.createEvent(event)
        await calendarRepository.failNextDelete()
        let client = MockCalendarSharingClient(ownedStates: [makeOwnedState(calendar: owned)])
        let firstStore = makeStore(
            client: client,
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        do { try await firstStore.stopOwnedSharing(id: owned.id) } catch {}

        let interruptedCalendar = await calendarRepository.calendar(id: owned.id)
        XCTAssertTrue(client.ownedStates.isEmpty)
        XCTAssertEqual(interruptedCalendar?.stopPhase, .cloudDeletionPending)

        let restartedStore = makeStore(
            client: client,
            calendars: await calendarRepository.calendars(),
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        await restartedStore.start()

        let removedCalendar = await calendarRepository.calendar(id: owned.id)
        let reassignedEvent = try await eventUseCase.event(id: event.id)
        XCTAssertNil(removedCalendar)
        XCTAssertEqual(reassignedEvent?.calendarID, TimeNestCalendar.personalID)
    }

    func testStoppingOneCalendarDoesNotMoveOrDeleteAnotherCalendarData() async throws {
        let first = makeCalendar(kind: .sharedOwned, name: "First")
        let second = makeCalendar(kind: .sharedOwned, name: "Second")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), first, second]
        let calendarRepository = ControlledCalendarRepository(calendars: calendars)
        let eventRepository = ControlledEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let firstEvent = makeEvent(title: "First", calendarID: first.id)
        let secondEvent = makeEvent(title: "Second", calendarID: second.id)
        try await eventUseCase.createEvent(firstEvent)
        try await eventUseCase.createEvent(secondEvent)
        let client = MockCalendarSharingClient(
            ownedStates: [makeOwnedState(calendar: first), makeOwnedState(calendar: second)]
        )
        let store = makeStore(
            client: client,
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )

        try await store.stopOwnedSharing(id: first.id)

        let movedFirstEvent = try await eventUseCase.event(id: firstEvent.id)
        let preservedSecondEvent = try await eventUseCase.event(id: secondEvent.id)
        let preservedSecondCalendar = await calendarRepository.calendar(id: second.id)
        XCTAssertEqual(movedFirstEvent?.calendarID, TimeNestCalendar.personalID)
        XCTAssertEqual(preservedSecondEvent?.calendarID, second.id)
        XCTAssertNotNil(preservedSecondCalendar)
        XCTAssertEqual(client.stoppedCalendarIDs, [first.id])
    }

    func testStoppingCalendarIsExcludedFromFurtherUploads() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), owned]
        let calendarRepository = ControlledCalendarRepository(calendars: calendars)
        let eventRepository = ControlledEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        try await eventUseCase.createEvent(makeEvent(title: "Keep", calendarID: owned.id))
        let client = MockCalendarSharingClient(ownedStates: [makeOwnedState(calendar: owned)])
        let store = makeStore(
            client: client,
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        await store.synchronizeAll()
        client.failNextStop()
        do { try await store.stopOwnedSharing(id: owned.id) } catch {}
        client.resetSyncHistory()

        await store.synchronizeOwnedEventsIfNeeded()

        XCTAssertTrue(client.synchronizedCalendarIDs.isEmpty)
    }

    func testUnknownItemIsRecognizedOnlyAsIdempotentMissingZoneEvidence() {
        XCTAssertTrue(
            CalendarSharingErrorMapper.isMissingOrInaccessibleSharedZone(
                CKError(.unknownItem)
            )
        )
        XCTAssertFalse(
            CalendarSharingErrorMapper.isMissingOrInaccessibleSharedZone(
                CKError(.networkFailure)
            )
        )
    }

    func testMissingZoneRetryStillCompletesLocalStoppingCleanup() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), owned]
        let calendarRepository = ControlledCalendarRepository(calendars: calendars)
        let eventRepository = ControlledEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let event = makeEvent(title: "Keep", calendarID: owned.id)
        try await eventUseCase.createEvent(event)
        let client = MockCalendarSharingClient(ownedStates: [makeOwnedState(calendar: owned)])
        client.failNextStop(error: CKError(.unknownItem))
        let store = makeStore(
            client: client,
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )

        try await store.stopOwnedSharing(id: owned.id)

        let removedCalendar = await calendarRepository.calendar(id: owned.id)
        let reassignedEvent = try await eventUseCase.event(id: event.id)
        XCTAssertNil(removedCalendar)
        XCTAssertEqual(reassignedEvent?.calendarID, TimeNestCalendar.personalID)
        XCTAssertEqual(client.stoppedCalendarIDs, [owned.id])
    }

    func testCompletedSharingActivityKeepsNewPendingParticipant() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let accepted = makeParticipant(id: "accepted", isAccepted: true)
        let client = MockCalendarSharingClient(
            ownedStates: [makeOwnedState(calendar: owned, participants: [accepted])]
        )
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar"), owned]
        )
        await store.synchronizeAll()
        let invitation = try await store.createInvitation(for: owned.id)

        try await store.handleInvitationActivity(invitation, outcome: .completed)

        XCTAssertTrue(client.revokedParticipantIDs.isEmpty)
        XCTAssertEqual(store.participants(for: owned.id).filter(\.isAccepted).count, 1)
        XCTAssertEqual(store.participants(for: owned.id).filter { !$0.isAccepted }.count, 1)
    }

    func testCancelledInvitationRevokesOnlyItsOwnPendingParticipant() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let accepted = makeParticipant(id: "accepted", isAccepted: true)
        let otherPending = makeParticipant(id: "other-pending", isAccepted: false)
        let client = MockCalendarSharingClient(
            ownedStates: [
                makeOwnedState(
                    calendar: owned,
                    participants: [accepted, otherPending]
                )
            ]
        )
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar"), owned]
        )
        await store.synchronizeAll()
        let invitation = try await store.createInvitation(for: owned.id)

        try await store.handleInvitationActivity(invitation, outcome: .cancelled)

        let remaining = store.participants(for: owned.id)
        XCTAssertTrue(remaining.contains { $0.id == accepted.id && $0.isAccepted })
        XCTAssertTrue(remaining.contains { $0.id == otherPending.id && !$0.isAccepted })
        XCTAssertFalse(remaining.contains { $0.id == invitation.id })
        XCTAssertEqual(client.revokedParticipantIDs.count, 1)
    }

    func testActivityErrorIsDistinctFromCancellationAndKeepsCalendar() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let client = MockCalendarSharingClient(
            ownedStates: [makeOwnedState(calendar: owned)]
        )
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar"), owned]
        )
        await store.synchronizeAll()
        let invitation = try await store.createInvitation(for: owned.id)

        do {
            try await store.handleInvitationActivity(invitation, outcome: .activityError)
            XCTFail("A system sharing activity error must not be treated as user cancellation")
        } catch {
            XCTAssertEqual(error as? CalendarSharingError, .invitationActivityFailed)
        }

        XCTAssertEqual(store.calendar(id: owned.id)?.kind, .sharedOwned)
        XCTAssertTrue(store.participants(for: owned.id).isEmpty)
        XCTAssertEqual(client.revokedParticipantIDs.count, 1)
    }

    func testRepeatedCancellationDoesNotAccumulatePendingParticipants() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let client = MockCalendarSharingClient(
            ownedStates: [makeOwnedState(calendar: owned)]
        )
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar"), owned]
        )
        await store.synchronizeAll()

        for _ in 0..<3 {
            let invitation = try await store.createInvitation(for: owned.id)
            try await store.handleInvitationActivity(invitation, outcome: .cancelled)
        }

        XCTAssertTrue(store.participants(for: owned.id).isEmpty)
        XCTAssertEqual(client.revokedParticipantIDs.count, 3)
    }

    func testFailedInvitationRevocationRemainsVisibleAndCanRetry() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let client = MockCalendarSharingClient(
            ownedStates: [makeOwnedState(calendar: owned)]
        )
        let store = makeStore(
            client: client,
            calendars: [.personal(name: "My Calendar"), owned]
        )
        await store.synchronizeAll()
        let invitation = try await store.createInvitation(for: owned.id)
        client.failNextRevoke()

        do {
            try await store.handleInvitationActivity(invitation, outcome: .cancelled)
            XCTFail("The injected revoke failure must be visible")
        } catch {
            XCTAssertEqual(error as? CalendarSharingError, .invitationCancellationFailed)
        }

        let pending = try XCTUnwrap(
            store.participants(for: owned.id).first { $0.id == invitation.id }
        )
        XCTAssertFalse(pending.isAccepted)
        XCTAssertNotNil(pending.revocationToken)
        XCTAssertEqual(store.lastError, .invitationCancellationFailed)

        try await store.revokePendingInvitation(
            calendarID: owned.id,
            participantSnapshotID: invitation.id
        )
        XCTAssertTrue(store.participants(for: owned.id).isEmpty)
    }

    func testCalendarDraftSaveKeepsGlobalSelectionAndEditorOpen() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), owned]
        let calendarRepository = InMemoryCalendarRepository(calendars: calendars)
        let eventRepository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let store = makeStore(
            client: MockCalendarSharingClient(),
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        let viewModel = makeViewModel(eventUseCase: eventUseCase, store: store)
        viewModel.showingEntryEditor = true
        let revision = store.revision
        let start = Date(timeIntervalSince1970: 1_700_100_000)

        _ = try await viewModel.createEvent(
            title: "Draft target",
            note: nil,
            startDate: start,
            endDate: start.addingTimeInterval(3_600),
            isAllDay: false,
            reminderOffsetMinutes: nil,
            shiftTemplateID: nil,
            workInfo: nil,
            calendarID: owned.id
        )

        let saved = try await eventUseCase.events(
            in: DateInterval(start: .distantPast, end: .distantFuture),
            calendarID: owned.id
        )
        XCTAssertEqual(saved.map(\.title), ["Draft target"])
        XCTAssertEqual(store.selection, .mine)
        XCTAssertEqual(store.revision, revision)
        XCTAssertTrue(viewModel.showingEntryEditor)
    }

    func testAppointmentsCanMovePersonalOwnedAndBetweenOwnedCalendars() async throws {
        let first = makeCalendar(kind: .sharedOwned, name: "First")
        let second = makeCalendar(kind: .sharedOwned, name: "Second")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), first, second]
        let calendarRepository = InMemoryCalendarRepository(calendars: calendars)
        let eventRepository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let client = MockCalendarSharingClient(
            ownedStates: [makeOwnedState(calendar: first), makeOwnedState(calendar: second)]
        )
        let store = makeStore(
            client: client,
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        await store.synchronizeAll()
        let viewModel = makeViewModel(eventUseCase: eventUseCase, store: store)
        let event = makeEvent(title: "Move", calendarID: TimeNestCalendar.personalID)
        try await eventUseCase.createEvent(event)

        for target in [first.id, second.id, TimeNestCalendar.personalID] {
            _ = try await viewModel.updateEvent(
                id: event.id,
                title: "Move",
                note: nil,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: false,
                reminderOffsetMinutes: nil,
                shiftTemplateID: nil,
                workInfo: nil,
                calendarID: target
            )
            let movedEvent = try await eventUseCase.event(id: event.id)
            XCTAssertEqual(movedEvent?.calendarID, target)
            XCTAssertEqual(store.selection, .mine)
        }
    }

    func testShiftAndWorkRecordUseExplicitDraftCalendar() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), owned]
        let calendarRepository = InMemoryCalendarRepository(calendars: calendars)
        let eventRepository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let store = makeStore(
            client: MockCalendarSharingClient(),
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        let viewModel = makeViewModel(eventUseCase: eventUseCase, store: store)
        let start = Date(timeIntervalSince1970: 1_700_200_000)
        _ = try await viewModel.createEvent(
            title: "Day",
            note: nil,
            startDate: start,
            endDate: start.addingTimeInterval(28_800),
            isAllDay: false,
            reminderOffsetMinutes: nil,
            shiftTemplateID: .day,
            workInfo: nil,
            calendarID: owned.id
        )
        let sessionID = UUID()
        _ = try await viewModel.createEvent(
            title: "Clock In",
            note: nil,
            startDate: start,
            endDate: start.addingTimeInterval(3_600),
            isAllDay: false,
            reminderOffsetMinutes: nil,
            shiftTemplateID: nil,
            workInfo: WorkInfo(
                workInTime: start,
                restHours: 1,
                workDate: start,
                workSessionId: sessionID
            ),
            calendarID: owned.id
        )
        _ = try await viewModel.createEvent(
            title: "Clock Out",
            note: nil,
            startDate: start.addingTimeInterval(28_800),
            endDate: start.addingTimeInterval(32_400),
            isAllDay: false,
            reminderOffsetMinutes: nil,
            shiftTemplateID: nil,
            workInfo: WorkInfo(
                workOutTime: start.addingTimeInterval(28_800),
                restHours: 1,
                workDate: start,
                workSessionId: sessionID,
                isWorkOutTimeSet: true
            ),
            calendarID: owned.id
        )

        let saved = try await eventUseCase.events(
            in: DateInterval(start: .distantPast, end: .distantFuture),
            calendarID: owned.id
        )
        XCTAssertEqual(saved.filter { $0.shiftTemplateID != nil }.count, 1)
        XCTAssertEqual(saved.filter { $0.workClockKind != nil }.count, 2)
        XCTAssertEqual(store.selection, .mine)
    }

    func testShiftAndWorkClocksCanMovePersonalOwnedAndBetweenOwnedCalendars() async throws {
        let first = makeCalendar(kind: .sharedOwned, name: "First")
        let second = makeCalendar(kind: .sharedOwned, name: "Second")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), first, second]
        let calendarRepository = InMemoryCalendarRepository(calendars: calendars)
        let eventRepository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let client = MockCalendarSharingClient(
            ownedStates: [makeOwnedState(calendar: first), makeOwnedState(calendar: second)]
        )
        let store = makeStore(
            client: client,
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        await store.synchronizeAll()
        let viewModel = makeViewModel(eventUseCase: eventUseCase, store: store)
        let start = Date(timeIntervalSince1970: 1_700_250_000)
        let sessionID = UUID()
        let fixtures = [
            makeEvent(
                title: "Day",
                calendarID: TimeNestCalendar.personalID,
                shiftTemplateID: .day
            ),
            makeEvent(
                title: "Clock In",
                calendarID: TimeNestCalendar.personalID,
                workInfo: WorkInfo(
                    workInTime: start,
                    restHours: 1,
                    workDate: start,
                    workSessionId: sessionID
                )
            ),
            makeEvent(
                title: "Clock Out",
                calendarID: TimeNestCalendar.personalID,
                workInfo: WorkInfo(
                    workOutTime: start.addingTimeInterval(28_800),
                    restHours: 1,
                    workDate: start,
                    workSessionId: sessionID,
                    isWorkOutTimeSet: true
                )
            )
        ]
        for fixture in fixtures {
            try await eventUseCase.createEvent(fixture)
        }

        for target in [first.id, second.id, TimeNestCalendar.personalID] {
            for fixture in fixtures {
                let currentValue = try await eventUseCase.event(id: fixture.id)
                let current = try XCTUnwrap(currentValue)
                _ = try await viewModel.updateEvent(
                    id: current.id,
                    title: current.title,
                    note: current.note,
                    startDate: current.startDate,
                    endDate: current.endDate,
                    isAllDay: current.isAllDay,
                    reminderOffsetMinutes: current.reminderOffsetMinutes,
                    shiftTemplateID: current.shiftTemplateID,
                    workInfo: current.workInfo,
                    calendarID: target
                )
            }

            for fixture in fixtures {
                let moved = try await eventUseCase.event(id: fixture.id)
                XCTAssertEqual(moved?.calendarID, target)
            }
            XCTAssertEqual(store.selection, .mine)
        }
    }

    func testReceivedCalendarCannotBeInjectedAsDraftSaveTarget() async throws {
        let received = makeCalendar(kind: .sharedReceived, name: "Received")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), received]
        let calendarRepository = InMemoryCalendarRepository(calendars: calendars)
        let eventRepository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let store = makeStore(
            client: MockCalendarSharingClient(),
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        let viewModel = makeViewModel(eventUseCase: eventUseCase, store: store)
        let start = Date(timeIntervalSince1970: 1_700_300_000)

        do {
            _ = try await viewModel.createEvent(
                title: "Forbidden",
                note: nil,
                startDate: start,
                endDate: start.addingTimeInterval(3_600),
                isAllDay: false,
                reminderOffsetMinutes: nil,
                shiftTemplateID: nil,
                workInfo: nil,
                calendarID: received.id
            )
            XCTFail("Received calendars must reject constructed save targets")
        } catch {
            XCTAssertEqual(error as? CalendarSharingError, .permissionDenied)
        }
        XCTAssertFalse(store.writableCalendars.contains { $0.id == received.id })
    }

    func testSaveFailureKeepsEditorPresentationAndGlobalCalendarState() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), owned]
        let calendarRepository = ControlledCalendarRepository(calendars: calendars)
        let eventRepository = ControlledEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let store = makeStore(
            client: MockCalendarSharingClient(),
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        let viewModel = makeViewModel(eventUseCase: eventUseCase, store: store)
        viewModel.showingEntryEditor = true
        await eventRepository.failNextWrite()
        let start = Date(timeIntervalSince1970: 1_700_400_000)

        do {
            _ = try await viewModel.createEvent(
                title: "Retained draft",
                note: nil,
                startDate: start,
                endDate: start.addingTimeInterval(3_600),
                isAllDay: false,
                reminderOffsetMinutes: nil,
                shiftTemplateID: nil,
                workInfo: nil,
                calendarID: owned.id
            )
            XCTFail("The injected save must fail")
        } catch {}

        XCTAssertTrue(viewModel.showingEntryEditor)
        XCTAssertEqual(store.selection, .mine)
        let savedEvents = try await eventUseCase.events(
            in: DateInterval(start: .distantPast, end: .distantFuture),
            calendarID: owned.id
        )
        XCTAssertNil(savedEvents.first)
    }

    func testWorkRecordPairFailureIsAtomicAndRetryDoesNotDuplicateClocks() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let calendars = [TimeNestCalendar.personal(name: "My Calendar"), owned]
        let calendarRepository = ControlledCalendarRepository(calendars: calendars)
        let eventRepository = ControlledEventRepository()
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            calendarRepository: calendarRepository
        )
        let store = makeStore(
            client: MockCalendarSharingClient(),
            calendars: calendars,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository
        )
        let viewModel = makeViewModel(eventUseCase: eventUseCase, store: store)
        let workDate = Date(timeIntervalSince1970: 1_700_500_000)
        let sessionID = UUID()
        let request = WorkRecordPairSaveRequest(
            clockInEventID: nil,
            clockOutEventID: nil,
            calendarID: owned.id,
            title: "Work",
            workDate: workDate,
            clockInDate: workDate,
            clockOutDate: workDate.addingTimeInterval(28_800),
            restHours: 1,
            transportFee: 900,
            hourlyRate: 2_500,
            sessionID: sessionID,
            isWorkOutTimeSet: true
        )
        await eventRepository.failNextWrite()

        do {
            try await viewModel.saveWorkRecordPair(request)
            XCTFail("The injected batch failure must reject the whole pair")
        } catch {}

        var saved = try await eventUseCase.events(
            in: DateInterval(start: .distantPast, end: .distantFuture),
            calendarID: owned.id
        )
        XCTAssertEqual(saved.filter { $0.workClockKind == .clockIn }.count, 0)
        XCTAssertEqual(saved.filter { $0.workClockKind == .clockOut }.count, 0)

        try await viewModel.saveWorkRecordPair(request)
        saved = try await eventUseCase.events(
            in: DateInterval(start: .distantPast, end: .distantFuture),
            calendarID: owned.id
        )
        let clocks = saved.filter { $0.workInfo?.workSessionId == sessionID }
        XCTAssertEqual(clocks.filter { $0.workClockKind == .clockIn }.count, 1)
        XCTAssertEqual(clocks.filter { $0.workClockKind == .clockOut }.count, 1)
        XCTAssertEqual(Set(clocks.map(\.id)).count, 2)
        XCTAssertTrue(clocks.allSatisfy { $0.calendarID == owned.id })
        XCTAssertEqual(store.selection, .mine)
    }

    func testWorkRecordPairRejectsOrdinaryEventsInEitherExplicitPositionWithoutSideEffects() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let repository = ControlledEventRepository()
        let scheduler = EventNotificationSchedulerSpy()
        let useCase = EventUseCase(
            repository: repository,
            notificationScheduler: scheduler,
            calendarRepository: ControlledCalendarRepository(
                calendars: [.personal(name: "My Calendar"), owned]
            )
        )
        let ordinary = makeEvent(
            id: UUID(),
            title: "Clock In",
            calendarID: owned.id,
            notificationID: "ordinary-notification"
        )
        try await repository.create(ordinary)
        var callbackCount = 0
        useCase.onEventsChanged = { callbackCount += 1 }

        for request in [
            makeWorkPairRequest(
                calendarID: owned.id,
                sessionID: UUID(),
                clockInEventID: ordinary.id
            ),
            makeWorkPairRequest(
                calendarID: owned.id,
                sessionID: UUID(),
                clockOutEventID: ordinary.id
            )
        ] {
            do {
                try await useCase.saveWorkRecordPair(request)
                XCTFail("An ordinary event must never be converted into a work clock")
            } catch {
                XCTAssertEqual(error as? WorkRecordPairSaveError, .notWorkRecord)
            }
        }

        let stored = await repository.event(id: ordinary.id)
        let applyBatchCallCount = await repository.applyBatchCallCount()
        XCTAssertEqual(applyBatchCallCount, 0)
        XCTAssertEqual(callbackCount, 0)
        XCTAssertTrue(scheduler.cancelledIDs.isEmpty)
        XCTAssertEqual(stored, ordinary)
    }

    func testWorkRecordPairRejectsSwappedKindsAndSameExplicitID() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let repository = ControlledEventRepository()
        let useCase = EventUseCase(
            repository: repository,
            calendarRepository: ControlledCalendarRepository(
                calendars: [.personal(name: "My Calendar"), owned]
            )
        )
        let sessionID = UUID()
        let clockIn = makeWorkClockEvent(
            kind: .clockIn,
            calendarID: owned.id,
            sessionID: sessionID
        )
        let clockOut = makeWorkClockEvent(
            kind: .clockOut,
            calendarID: owned.id,
            sessionID: sessionID
        )
        try await repository.create(clockIn)
        try await repository.create(clockOut)

        do {
            try await useCase.saveWorkRecordPair(
                makeWorkPairRequest(
                    calendarID: owned.id,
                    sessionID: sessionID,
                    clockInEventID: clockOut.id,
                    clockOutEventID: clockIn.id
                )
            )
            XCTFail("Swapped clock kinds must fail")
        } catch {
            XCTAssertEqual(error as? WorkRecordPairSaveError, .clockKindMismatch)
        }

        do {
            try await useCase.saveWorkRecordPair(
                makeWorkPairRequest(
                    calendarID: owned.id,
                    sessionID: sessionID,
                    clockInEventID: clockIn.id,
                    clockOutEventID: clockIn.id
                )
            )
            XCTFail("One event ID cannot fill both work-clock positions")
        } catch {
            XCTAssertEqual(error as? WorkRecordPairSaveError, .duplicateExplicitEventID)
        }

        let applyBatchCallCount = await repository.applyBatchCallCount()
        let storedClockIn = await repository.event(id: clockIn.id)
        let storedClockOut = await repository.event(id: clockOut.id)
        XCTAssertEqual(applyBatchCallCount, 0)
        XCTAssertEqual(storedClockIn, clockIn)
        XCTAssertEqual(storedClockOut, clockOut)
    }

    func testWorkRecordPairRejectsCalendarSessionAndMissingExplicitReferences() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let other = makeCalendar(kind: .sharedOwned, name: "Other")
        let repository = ControlledEventRepository()
        let useCase = EventUseCase(
            repository: repository,
            calendarRepository: ControlledCalendarRepository(
                calendars: [.personal(name: "My Calendar"), owned, other]
            )
        )
        let targetSessionID = UUID()
        let otherCalendarClockIn = makeWorkClockEvent(
            kind: .clockIn,
            calendarID: other.id,
            sessionID: targetSessionID
        )
        let otherSessionClockIn = makeWorkClockEvent(
            kind: .clockIn,
            calendarID: owned.id,
            sessionID: UUID()
        )
        let validClockIn = makeWorkClockEvent(
            kind: .clockIn,
            calendarID: owned.id,
            sessionID: targetSessionID
        )
        try await repository.create(otherCalendarClockIn)
        try await repository.create(otherSessionClockIn)
        try await repository.create(validClockIn)

        let cases: [(WorkRecordPairSaveRequest, WorkRecordPairSaveError)] = [
            (
                makeWorkPairRequest(
                    calendarID: owned.id,
                    sessionID: targetSessionID,
                    clockInEventID: otherCalendarClockIn.id
                ),
                .calendarMismatch
            ),
            (
                makeWorkPairRequest(
                    calendarID: owned.id,
                    sessionID: targetSessionID,
                    clockInEventID: otherSessionClockIn.id
                ),
                .sessionMismatch
            ),
            (
                makeWorkPairRequest(
                    calendarID: owned.id,
                    sessionID: targetSessionID,
                    clockInEventID: validClockIn.id,
                    clockOutEventID: UUID()
                ),
                .explicitEventNotFound
            )
        ]

        for (request, expectedError) in cases {
            do {
                try await useCase.saveWorkRecordPair(request)
                XCTFail("Invalid explicit work-clock ownership must fail")
            } catch {
                XCTAssertEqual(error as? WorkRecordPairSaveError, expectedError)
            }
        }
        let applyBatchCallCount = await repository.applyBatchCallCount()
        let storedValidClockIn = await repository.event(id: validClockIn.id)
        XCTAssertEqual(applyBatchCallCount, 0)
        XCTAssertEqual(storedValidClockIn, validClockIn)
    }

    func testCorrectExplicitWorkRecordPairUpdatesOnceAndFiresOneCallback() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let repository = ControlledEventRepository()
        let scheduler = EventNotificationSchedulerSpy()
        let useCase = EventUseCase(
            repository: repository,
            notificationScheduler: scheduler,
            calendarRepository: ControlledCalendarRepository(
                calendars: [.personal(name: "My Calendar"), owned]
            )
        )
        let sessionID = UUID()
        let clockIn = makeWorkClockEvent(
            kind: .clockIn,
            calendarID: owned.id,
            sessionID: sessionID,
            notificationID: "old-clock-in"
        )
        let clockOut = makeWorkClockEvent(
            kind: .clockOut,
            calendarID: owned.id,
            sessionID: sessionID,
            notificationID: "old-clock-out"
        )
        try await repository.create(clockIn)
        try await repository.create(clockOut)
        var callbackCount = 0
        useCase.onEventsChanged = { callbackCount += 1 }
        let request = makeWorkPairRequest(
            calendarID: owned.id,
            sessionID: sessionID,
            clockInEventID: clockIn.id,
            clockOutEventID: clockOut.id,
            title: "Updated Work"
        )

        try await useCase.saveWorkRecordPair(request)

        let storedClockInValue = await repository.event(id: clockIn.id)
        let storedClockOutValue = await repository.event(id: clockOut.id)
        let storedClockIn = try XCTUnwrap(storedClockInValue)
        let storedClockOut = try XCTUnwrap(storedClockOutValue)
        let applyBatchCallCount = await repository.applyBatchCallCount()
        XCTAssertEqual(storedClockIn.title, "Updated Work")
        XCTAssertEqual(storedClockOut.title, "Updated Work")
        XCTAssertEqual(storedClockIn.workInfo?.workSessionId, sessionID)
        XCTAssertEqual(storedClockOut.workInfo?.workSessionId, sessionID)
        XCTAssertEqual(applyBatchCallCount, 1)
        XCTAssertEqual(callbackCount, 1)
        XCTAssertEqual(Set(scheduler.cancelledIDs), ["old-clock-in", "old-clock-out"])
    }

    func testWorkRecordPairBatchFailureDoesNotFireCallback() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let repository = ControlledEventRepository()
        let useCase = EventUseCase(
            repository: repository,
            calendarRepository: ControlledCalendarRepository(
                calendars: [.personal(name: "My Calendar"), owned]
            )
        )
        var callbackCount = 0
        useCase.onEventsChanged = { callbackCount += 1 }
        await repository.failNextWrite()

        do {
            try await useCase.saveWorkRecordPair(
                makeWorkPairRequest(calendarID: owned.id, sessionID: UUID())
            )
            XCTFail("The injected batch failure must propagate")
        } catch {}

        XCTAssertEqual(callbackCount, 0)
        let applyBatchCallCount = await repository.applyBatchCallCount()
        XCTAssertEqual(applyBatchCallCount, 1)
        let stored = await repository.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        XCTAssertTrue(stored.isEmpty)
    }

    func testUnifiedEventAndWorkRecordCreateUsesOneAtomicBatch() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let repository = ControlledEventRepository()
        let useCase = EventUseCase(
            repository: repository,
            calendarRepository: ControlledCalendarRepository(
                calendars: [.personal(name: "My Calendar"), owned]
            )
        )
        let event = makeEvent(title: "Appointment", calendarID: owned.id)
        let sessionID = UUID()
        var callbackCount = 0
        useCase.onEventsChanged = { callbackCount += 1 }

        let result = try await useCase.saveEventAndWorkRecordAtomically(
            event: event,
            existingEvent: nil,
            workRecord: makeWorkPairRequest(
                calendarID: owned.id,
                sessionID: sessionID,
                title: "Work"
            )
        )

        let stored = await repository.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        let workClocks = stored.filter { $0.workInfo?.workSessionId == sessionID }
        let applyBatchCallCount = await repository.applyBatchCallCount()
        XCTAssertEqual(result, .noReminder)
        XCTAssertEqual(stored.count, 3)
        XCTAssertEqual(stored.first { $0.id == event.id }?.title, "Appointment")
        XCTAssertEqual(workClocks.filter { $0.workClockKind == .clockIn }.count, 1)
        XCTAssertEqual(workClocks.filter { $0.workClockKind == .clockOut }.count, 1)
        XCTAssertEqual(applyBatchCallCount, 1)
        XCTAssertEqual(callbackCount, 1)
    }

    func testUnifiedEventAndWorkRecordBatchFailureLeavesNeitherSideSaved() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let repository = ControlledEventRepository()
        let useCase = EventUseCase(
            repository: repository,
            calendarRepository: ControlledCalendarRepository(
                calendars: [.personal(name: "My Calendar"), owned]
            )
        )
        var callbackCount = 0
        useCase.onEventsChanged = { callbackCount += 1 }
        await repository.failNextWrite()

        do {
            _ = try await useCase.saveEventAndWorkRecordAtomically(
                event: makeEvent(title: "Appointment", calendarID: owned.id),
                existingEvent: nil,
                workRecord: makeWorkPairRequest(
                    calendarID: owned.id,
                    sessionID: UUID()
                )
            )
            XCTFail("The injected batch failure must reject the event and work record together")
        } catch {}

        let stored = await repository.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        let applyBatchCallCount = await repository.applyBatchCallCount()
        XCTAssertTrue(stored.isEmpty)
        XCTAssertEqual(applyBatchCallCount, 1)
        XCTAssertEqual(callbackCount, 0)
    }

    func testEditingExistingEventCanAddWorkRecordInSameBatch() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let repository = ControlledEventRepository()
        let useCase = EventUseCase(
            repository: repository,
            calendarRepository: ControlledCalendarRepository(
                calendars: [.personal(name: "My Calendar"), owned]
            )
        )
        let original = makeEvent(title: "Original", calendarID: owned.id)
        try await repository.create(original)
        var updated = original
        updated.title = "Updated"
        updated.updatedAt = original.updatedAt.addingTimeInterval(60)
        let sessionID = UUID()

        _ = try await useCase.saveEventAndWorkRecordAtomically(
            event: updated,
            existingEvent: original,
            workRecord: makeWorkPairRequest(
                calendarID: owned.id,
                sessionID: sessionID
            )
        )

        let stored = await repository.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        XCTAssertEqual(stored.first { $0.id == original.id }?.title, "Updated")
        XCTAssertEqual(
            stored.filter { $0.workInfo?.workSessionId == sessionID }.count,
            2
        )
    }

    func testEditingExistingWorkRecordCanAddEventWithoutReplacingClockIDs() async throws {
        let owned = makeCalendar(kind: .sharedOwned, name: "Family")
        let repository = ControlledEventRepository()
        let useCase = EventUseCase(
            repository: repository,
            calendarRepository: ControlledCalendarRepository(
                calendars: [.personal(name: "My Calendar"), owned]
            )
        )
        let sessionID = UUID()
        try await useCase.saveWorkRecordPair(
            makeWorkPairRequest(calendarID: owned.id, sessionID: sessionID)
        )
        let originalClocks = await repository.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        let clockInID = try XCTUnwrap(
            originalClocks.first { $0.workClockKind == .clockIn }?.id
        )
        let clockOutID = try XCTUnwrap(
            originalClocks.first { $0.workClockKind == .clockOut }?.id
        )
        let event = makeEvent(title: "Added Event", calendarID: owned.id)

        _ = try await useCase.saveEventAndWorkRecordAtomically(
            event: event,
            existingEvent: nil,
            workRecord: makeWorkPairRequest(
                calendarID: owned.id,
                sessionID: sessionID,
                clockInEventID: clockInID,
                clockOutEventID: clockOutID,
                title: "Updated Work"
            )
        )

        let stored = await repository.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        let storedClockIDs = Set(
            stored
                .filter { $0.workInfo?.workSessionId == sessionID }
                .map(\.id)
        )
        XCTAssertEqual(storedClockIDs, Set([clockInID, clockOutID]))
        XCTAssertEqual(stored.first { $0.id == event.id }?.title, "Added Event")
    }

    func testDeletingEventDoesNotDeleteWorkRecord() async throws {
        let repository = ControlledEventRepository()
        let useCase = EventUseCase(repository: repository)
        let event = makeEvent(title: "Appointment")
        let sessionID = UUID()
        _ = try await useCase.saveEventAndWorkRecordAtomically(
            event: event,
            existingEvent: nil,
            workRecord: makeWorkPairRequest(
                calendarID: TimeNestCalendar.personalID,
                sessionID: sessionID
            )
        )

        try await useCase.deleteEvent(id: event.id)

        let stored = await repository.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        XCTAssertNil(stored.first { $0.id == event.id })
        XCTAssertEqual(
            stored.filter { $0.workInfo?.workSessionId == sessionID }.count,
            2
        )
    }

    func testDeletingWorkRecordDoesNotDeleteEvent() async throws {
        let repository = ControlledEventRepository()
        let useCase = EventUseCase(repository: repository)
        let event = makeEvent(title: "Appointment")
        let sessionID = UUID()
        _ = try await useCase.saveEventAndWorkRecordAtomically(
            event: event,
            existingEvent: nil,
            workRecord: makeWorkPairRequest(
                calendarID: TimeNestCalendar.personalID,
                sessionID: sessionID
            )
        )
        let storedBeforeDelete = await repository.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        let workEvents = storedBeforeDelete.filter {
            $0.workInfo?.workSessionId == sessionID
        }

        _ = try await useCase.deleteEventsBatch(expectedEvents: workEvents)

        let stored = await repository.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        XCTAssertEqual(stored.first { $0.id == event.id }, event)
        XCTAssertTrue(
            stored.filter { $0.workInfo?.workSessionId == sessionID }.isEmpty
        )
    }

    private func makeWorkRecordEvents(
        title: String,
        calendarID: UUID = TimeNestCalendar.personalID,
        workDate: Date,
        clockInDate: Date,
        clockOutDate: Date,
        sessionID: UUID,
        transportFee: Int? = nil,
        hourlyRate: Int? = nil
    ) -> [CalendarEvent] {
        let clockIn = makeEvent(
            title: title,
            calendarID: calendarID,
            workInfo: WorkInfo(
                workInTime: clockInDate,
                restHours: 1,
                workDate: workDate,
                transportFee: transportFee,
                hourlyRate: hourlyRate,
                workSessionId: sessionID,
                isWorkOutTimeSet: true
            ),
            startDate: clockInDate
        )
        let clockOut = makeEvent(
            title: title,
            calendarID: calendarID,
            workInfo: WorkInfo(
                workOutTime: clockOutDate,
                restHours: 1,
                workDate: workDate,
                transportFee: transportFee,
                hourlyRate: hourlyRate,
                workSessionId: sessionID,
                isWorkOutTimeSet: true
            ),
            startDate: clockOutDate
        )
        return [clockIn, clockOut]
    }

    private func makeWorkClockEvent(
        kind: WorkClockKind,
        calendarID: UUID,
        sessionID: UUID?,
        notificationID: String? = nil
    ) -> CalendarEvent {
        let workDate = Date(timeIntervalSince1970: 1_700_500_000)
        let clockDate = kind == .clockIn
            ? workDate
            : workDate.addingTimeInterval(8 * 3_600)
        let workInfo: WorkInfo
        switch kind {
        case .clockIn:
            workInfo = WorkInfo(
                workInTime: clockDate,
                restHours: 1,
                workDate: workDate,
                workSessionId: sessionID,
                isWorkOutTimeSet: true
            )
        case .clockOut:
            workInfo = WorkInfo(
                workOutTime: clockDate,
                restHours: 1,
                workDate: workDate,
                workSessionId: sessionID,
                isWorkOutTimeSet: true
            )
        }
        return makeEvent(
            id: UUID(),
            title: "Work",
            calendarID: calendarID,
            notificationID: notificationID,
            workInfo: workInfo
        )
    }

    private func makeWorkPairRequest(
        calendarID: UUID,
        sessionID: UUID,
        clockInEventID: UUID? = nil,
        clockOutEventID: UUID? = nil,
        title: String = "Work"
    ) -> WorkRecordPairSaveRequest {
        let workDate = Date(timeIntervalSince1970: 1_700_500_000)
        return WorkRecordPairSaveRequest(
            clockInEventID: clockInEventID,
            clockOutEventID: clockOutEventID,
            calendarID: calendarID,
            title: title,
            workDate: workDate,
            clockInDate: workDate,
            clockOutDate: workDate.addingTimeInterval(8 * 3_600),
            restHours: 1,
            transportFee: 900,
            hourlyRate: 2_500,
            sessionID: sessionID,
            isWorkOutTimeSet: true
        )
    }

    private func makeStore(
        client: MockCalendarSharingClient,
        calendars: [TimeNestCalendar],
        eventUseCase: EventUseCase = EventUseCase(repository: InMemoryEventRepository()),
        calendarRepository: (any CalendarRepository)? = nil,
        invitationRouter: CalendarSharingInvitationRouter? = nil,
        cache: CalendarSharingCache? = nil
    ) -> CalendarSharingStore {
        let defaults = UserDefaults(suiteName: "CalendarSharingStoreTests-\(UUID().uuidString)")!
        let resolvedCache = cache ?? CalendarSharingCache(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("CalendarSharingStoreTests-\(UUID().uuidString).json")
        )
        let resolvedCalendarRepository: any CalendarRepository = calendarRepository
            ?? InMemoryCalendarRepository(calendars: calendars)
        return CalendarSharingStore(
            client: client,
            eventUseCase: eventUseCase,
            calendarRepository: resolvedCalendarRepository,
            cache: resolvedCache,
            sharedEventEditingPersistence: SharedEventEditingPersistence(
                fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(
                    "SharedEventEditingTests-\(UUID().uuidString).json"
                )
            ),
            selectionPersistence: CalendarSelectionPersistence(defaults: defaults),
            syncMetadataPersistence: CalendarSharingSyncMetadataPersistence(defaults: defaults),
            initialCalendars: calendars,
            invitationRouter: invitationRouter ?? .shared
        )
    }

    private func makeInvitationRouter() -> CalendarSharingInvitationRouter {
        makeInvitationRouter(
            coordinator: CalendarSharingAcceptanceCoordinator()
        )
    }

    private func makeInvitationRouter(
        coordinator: CalendarSharingAcceptanceCoordinator
    ) -> CalendarSharingInvitationRouter {
        CalendarSharingInvitationRouter(
            coordinator: coordinator,
            configuredContainerIdentifier: { "iCloud.com.song.TimeNest" }
        )
    }

    private func makeViewModel(
        eventUseCase: EventUseCase,
        store: CalendarSharingStore
    ) -> MonthCalendarViewModel {
        MonthCalendarViewModel(
            calendarDisplayUseCase: CalendarDisplayUseCase(
                holidayUseCase: HolidayUseCase(
                    cacheRepository: InMemoryHolidayEventCacheRepository()
                ),
                localizationUseCase: CalendarLocalizationUseCase(),
                eventUseCase: eventUseCase
            ),
            eventUseCase: eventUseCase,
            calendarSharingStore: store
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        condition: () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else { return false }
            await Task.yield()
        }
        return true
    }
}

@MainActor
private final class MockCalendarSharingClient: CalendarSharingClientProtocol {
    struct Payload: Equatable {
        let events: [SharedEventSnapshot]
        let shifts: [SharedShiftSnapshot]
        let workRecords: [SharedWorkRecordSnapshot]
    }

    var ownedStates: [OwnedSharedCalendarCloudState]
    var receivedPayloads: [ReceivedSharedCalendarPayload] = []
    var ownedEventEnvelopesByCalendarID: [UUID: [UUID: SharedEventEnvelope]] = [:]
    var synchronizedCalendarIDs: [UUID] = []
    var completedCalendarIDs: [UUID] = []
    var lastPayloadByCalendarID: [UUID: Payload] = [:]
    var payloadHistoryByCalendarID: [UUID: [Payload]] = [:]
    var stoppedCalendarIDs: [UUID] = []
    var renamedCalendarIDs: [UUID] = []
    var renamedCalendarNames: [String] = []
    var leftCalendarIDs: [UUID] = []
    var revokedParticipantIDs: [String] = []
    var invitationURL: URL? = URL(string: "https://example.invalid/share")
    var shareMetadata: (any CalendarSharingShareMetadata)?
    var shareMetadataError: Error?
    var shareMetadataFetchCallCount = 0
    var shareMetadataFetchGate: ControlledAsyncGate?
    var acceptError: Error?
    var createShareError: Error?
    var eventEditingPermissionUpdateError: Error?
    var currentUserDisplayNameResult: String?
    var currentUserDisplayNameCallCount = 0
    var iCloudStatusResult: CalendarSharingICloudStatus = .available
    var iCloudStatusCallCount = 0
    var fetchOwnedCalendarsCallCount = 0
    var acceptedZoneName: String?
    var acceptCallCount = 0
    var cloudAcceptCallCount = 0
    var maxConcurrentSyncsByCalendarID: [UUID: Int] = [:]
    private var activeSyncsByCalendarID: [UUID: Int] = [:]
    private var syncGatesByCalendarID: [UUID: [ControlledAsyncGate]] = [:]
    private var syncErrorsByCalendarID: [UUID: [Error]] = [:]
    private var stopErrors: [Error] = []
    private var revokeErrors: [Error] = []
    private var ownedFetchErrors: [Error] = []
    private var invitationCounter = 0

    init(ownedStates: [OwnedSharedCalendarCloudState] = []) {
        self.ownedStates = ownedStates
    }

    func iCloudAccountStatus() async -> CalendarSharingICloudStatus {
        iCloudStatusCallCount += 1
        return iCloudStatusResult
    }

    func currentUserDisplayName() async -> String? {
        currentUserDisplayNameCallCount += 1
        return currentUserDisplayNameResult
    }

    func fetchShareMetadata(
        from url: URL
    ) async throws -> any CalendarSharingShareMetadata {
        _ = CalendarSharingDiagnostics.urlHash(url)
        shareMetadataFetchCallCount += 1
        if let shareMetadataFetchGate {
            try await shareMetadataFetchGate.waitForRelease()
        }
        if let shareMetadataError { throw shareMetadataError }
        guard let shareMetadata else {
            throw CalendarSharingError.metadataFetchFailed
        }
        return shareMetadata
    }

    func fetchOwnedCalendars() async throws -> [OwnedSharedCalendarCloudState] {
        fetchOwnedCalendarsCallCount += 1
        if !ownedFetchErrors.isEmpty {
            throw ownedFetchErrors.removeFirst()
        }
        return ownedStates
    }

    func createShare(
        calendarID: UUID,
        calendarName: String,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws -> OwnedSharingInvitationResult {
        if let createShareError { throw createShareError }
        let calendar = makeCalendar(kind: .sharedOwned, name: calendarName, id: calendarID)
        let participantID = nextParticipantID()
        let state = makeOwnedState(
            calendar: calendar,
            participants: [makePendingParticipant(id: participantID)]
        )
        ownedStates.append(state)
        ownedEventEnvelopesByCalendarID[calendarID] = Dictionary(
            uniqueKeysWithValues: events.map { snapshot in
                let envelope = makeEnvelope(snapshot: snapshot, calendar: state.calendar)
                return (snapshot.id, envelope)
            }
        )
        return OwnedSharingInvitationResult(
            state: state,
            invitationURL: invitationURL,
            participantID: participantID
        )
    }

    func createInvitation(
        for calendar: OwnedSharedCalendarDescriptor
    ) async throws -> OwnedSharingInvitationResult {
        let participantID = nextParticipantID()
        let existing = ownedStates.first(where: { $0.calendar.id == calendar.id })!
        let state = makeOwnedState(
            calendar: makeCalendar(
                kind: .sharedOwned,
                name: existing.calendar.calendarName,
                id: calendar.id,
                eventEditingAllowed: existing.calendar.eventEditingAllowed
            ),
            participants: existing.participants + [makePendingParticipant(id: participantID)]
        )
        replaceOwnedState(state)
        return OwnedSharingInvitationResult(
            state: state,
            invitationURL: invitationURL,
            participantID: participantID
        )
    }

    func revokePendingInvitation(
        for calendar: OwnedSharedCalendarDescriptor,
        participantID: CKShare.Participant.ID
    ) async throws -> OwnedSharedCalendarCloudState {
        if !revokeErrors.isEmpty {
            throw revokeErrors.removeFirst()
        }
        let snapshotID = OwnedCalendarParticipantSnapshotAssembler.participantSnapshotID(
            participantID
        )
        let existing = ownedStates.first(where: { $0.calendar.id == calendar.id })!
        let participants = existing.participants.filter {
            $0.isAccepted || $0.id != snapshotID
        }
        let state = makeOwnedState(
            calendar: makeCalendar(
                kind: .sharedOwned,
                name: existing.calendar.calendarName,
                id: calendar.id,
                eventEditingAllowed: existing.calendar.eventEditingAllowed
            ),
            participants: participants
        )
        replaceOwnedState(state)
        revokedParticipantIDs.append(participantID)
        return state
    }

    func updateEventEditingPermission(
        for calendar: OwnedSharedCalendarDescriptor,
        allowed: Bool
    ) async throws -> OwnedSharedCalendarCloudState {
        if let eventEditingPermissionUpdateError {
            throw eventEditingPermissionUpdateError
        }
        guard let existing = ownedStates.first(where: { $0.calendar.id == calendar.id }) else {
            throw CalendarSharingError.shareUnavailable
        }
        let local = makeCalendar(
            kind: .sharedOwned,
            name: existing.calendar.calendarName,
            id: calendar.id,
            eventEditingAllowed: allowed
        )
        let permission: SharedCalendarParticipantPermission = allowed ? .readWrite : .readOnly
        let participants = existing.participants.map { participant in
            SharedCalendarParticipantSnapshot(
                id: participant.id,
                displayName: participant.displayName,
                isAccepted: participant.isAccepted,
                permission: permission,
                revocationToken: participant.revocationToken
            )
        }
        let state = makeOwnedState(calendar: local, participants: participants)
        replaceOwnedState(state)
        return state
    }

    func synchronizeOwnedContent(
        calendar: OwnedSharedCalendarDescriptor,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws {
        synchronizedCalendarIDs.append(calendar.id)
        let payload = Payload(
            events: events,
            shifts: shifts,
            workRecords: workRecords
        )
        payloadHistoryByCalendarID[calendar.id, default: []].append(payload)
        activeSyncsByCalendarID[calendar.id, default: 0] += 1
        maxConcurrentSyncsByCalendarID[calendar.id] = max(
            maxConcurrentSyncsByCalendarID[calendar.id, default: 0],
            activeSyncsByCalendarID[calendar.id, default: 0]
        )
        defer { activeSyncsByCalendarID[calendar.id, default: 0] -= 1 }

        if var gates = syncGatesByCalendarID[calendar.id], !gates.isEmpty {
            let gate = gates.removeFirst()
            syncGatesByCalendarID[calendar.id] = gates
            try await gate.waitForRelease()
        }
        if var errors = syncErrorsByCalendarID[calendar.id], !errors.isEmpty {
            let error = errors.removeFirst()
            syncErrorsByCalendarID[calendar.id] = errors
            throw error
        }
        completedCalendarIDs.append(calendar.id)
        lastPayloadByCalendarID[calendar.id] = payload
    }

    func renameOwnedCalendar(
        _ calendar: OwnedSharedCalendarDescriptor,
        name: String
    ) async throws {
        renamedCalendarIDs.append(calendar.id)
        renamedCalendarNames.append(name)
    }

    func fetchReceivedCalendars() async throws -> [ReceivedSharedCalendarPayload] {
        receivedPayloads
    }

    func fetchOwnedSharedEvents(
        in calendar: OwnedSharedCalendarDescriptor
    ) async throws -> [SharedEventEnvelope] {
        Array((ownedEventEnvelopesByCalendarID[calendar.id] ?? [:]).values)
    }

    func upsertOwnedSharedEvent(
        _ snapshot: SharedEventSnapshot,
        in calendar: OwnedSharedCalendarDescriptor
    ) async throws -> SharedEventEnvelope {
        let envelope = makeEnvelope(snapshot: snapshot, calendar: calendar)
        ownedEventEnvelopesByCalendarID[calendar.id, default: [:]][snapshot.id] = envelope
        return envelope
    }

    func deleteOwnedSharedEvent(
        eventID: UUID,
        in calendar: OwnedSharedCalendarDescriptor
    ) async throws -> SharedEventEnvelope? {
        guard let existing = ownedEventEnvelopesByCalendarID[calendar.id]?[eventID] else {
            return nil
        }
        let deleted = SharedEventSnapshot(
            id: existing.snapshot.id,
            title: existing.snapshot.title,
            startDate: existing.snapshot.startDate,
            endDate: existing.snapshot.endDate,
            isAllDay: existing.snapshot.isAllDay,
            updatedAt: Date(),
            isDeleted: true,
            deletedAt: Date()
        )
        let envelope = makeEnvelope(snapshot: deleted, calendar: calendar)
        ownedEventEnvelopesByCalendarID[calendar.id, default: [:]][eventID] = envelope
        return envelope
    }

    func accept(
        metadata: any CalendarSharingShareMetadata
    ) async throws -> AcceptedSharedCalendarCloudResult {
        acceptCallCount += 1
        if let acceptError { throw acceptError }
        if metadata.participantStatus == .pending {
            cloudAcceptCallCount += 1
        }
        return AcceptedSharedCalendarCloudResult(
            zoneName: acceptedZoneName ?? metadata.share.recordID.zoneID.zoneName,
            ownerDisplayName: CalendarSharingPersonNameFormatter.displayName(
                from: metadata.ownerNameComponents
            )
        )
    }

    func leaveSharedCalendar(_ calendar: SharedCalendarDescriptor) async throws {
        leftCalendarIDs.append(calendar.id)
    }

    func stopOwnedSharing(_ calendar: OwnedSharedCalendarDescriptor) async throws {
        stoppedCalendarIDs.append(calendar.id)
        if !stopErrors.isEmpty {
            let error = stopErrors.removeFirst()
            guard CalendarSharingErrorMapper.isMissingOrInaccessibleSharedZone(error) else {
                throw error
            }
        }
        ownedStates.removeAll { $0.calendar.id == calendar.id }
    }

    func pauseNextSync(calendarID: UUID) -> ControlledAsyncGate {
        let gate = ControlledAsyncGate()
        syncGatesByCalendarID[calendarID, default: []].append(gate)
        return gate
    }

    func failNextSync(calendarID: UUID, error: Error = InjectedSharingTestError.failure) {
        syncErrorsByCalendarID[calendarID, default: []].append(error)
    }

    func failNextStop(error: Error = InjectedSharingTestError.failure) {
        stopErrors.append(error)
    }

    func failNextRevoke(error: Error = InjectedSharingTestError.failure) {
        revokeErrors.append(error)
    }

    func failNextOwnedFetch(error: Error = CalendarSharingError.syncFailed) {
        ownedFetchErrors.append(error)
    }

    func resetSyncHistory() {
        synchronizedCalendarIDs.removeAll()
        completedCalendarIDs.removeAll()
        lastPayloadByCalendarID.removeAll()
        payloadHistoryByCalendarID.removeAll()
        maxConcurrentSyncsByCalendarID.removeAll()
    }

    private func nextParticipantID() -> String {
        invitationCounter += 1
        return "participant-\(invitationCounter)"
    }

    private func makePendingParticipant(id: String) -> SharedCalendarParticipantSnapshot {
        SharedCalendarParticipantSnapshot(
            id: OwnedCalendarParticipantSnapshotAssembler.participantSnapshotID(id),
            displayName: nil,
            isAccepted: false,
            permission: .readOnly,
            revocationToken: id
        )
    }

    private func replaceOwnedState(_ state: OwnedSharedCalendarCloudState) {
        ownedStates.removeAll { $0.calendar.id == state.calendar.id }
        ownedStates.append(state)
    }

    private func makeEnvelope(
        snapshot: SharedEventSnapshot,
        calendar: OwnedSharedCalendarDescriptor
    ) -> SharedEventEnvelope {
        SharedEventEnvelope(
            calendarID: calendar.id,
            zoneName: calendar.zoneName,
            ownerName: calendar.ownerName,
            recordName: "event-\(snapshot.id.uuidString.lowercased())",
            snapshot: snapshot,
            recordChangeTag: UUID().uuidString,
            modificationDate: Date(),
            creatorIdentifierHash: nil,
            lastModifierIdentifierHash: nil,
            syncStatus: snapshot.isDeleted ? .deletedRemotely : .synced,
            pendingMutationID: nil
        )
    }
}

@MainActor
private final class ControlledAsyncGate {
    private(set) var hasEntered = false
    private var isReleased = false

    func waitForRelease() async throws {
        hasEntered = true
        while !isReleased {
            try Task.checkCancellation()
            await Task.yield()
        }
    }

    func waitUntilEntered() async {
        while !hasEntered {
            await Task.yield()
        }
    }

    func release() {
        isReleased = true
    }
}

private enum InjectedSharingTestError: Error {
    case failure
}

private actor ControlledCalendarRepository: CalendarRepository {
    private var storage: [UUID: TimeNestCalendar]
    private var remainingDeleteFailures = 0

    init(calendars: [TimeNestCalendar]) {
        storage = Dictionary(uniqueKeysWithValues: calendars.map { ($0.id, $0) })
    }

    func calendars() -> [TimeNestCalendar] {
        Array(storage.values)
    }

    func calendar(id: UUID) -> TimeNestCalendar? {
        storage[id]
    }

    func save(_ calendar: TimeNestCalendar) {
        storage[calendar.id] = calendar
    }

    func delete(id: UUID) throws {
        if remainingDeleteFailures > 0 {
            remainingDeleteFailures -= 1
            throw InjectedSharingTestError.failure
        }
        guard id != TimeNestCalendar.personalID else { return }
        storage.removeValue(forKey: id)
    }

    func failNextDelete() {
        remainingDeleteFailures += 1
    }
}

private actor ControlledEventRepository: EventRepository {
    private var storage: [UUID: CalendarEvent] = [:]
    private var remainingReassignmentFailures = 0
    private var remainingWriteFailures = 0
    private var writesBeforeInjectedFailure: Int?
    private var applyBatchCalls = 0

    func create(_ event: CalendarEvent) throws {
        try failWriteIfNeeded()
        storage[event.id] = event
    }

    func applyBatch(
        upserting events: [CalendarEvent],
        deleting eventsToDelete: [CalendarEvent],
        ifUnchanged expectedEvents: [CalendarEvent]
    ) throws {
        applyBatchCalls += 1
        try EventRepositoryBatchValidator.validateApplyBatch(
            currentEvents: Array(storage.values),
            upserting: events,
            deleting: eventsToDelete,
            ifUnchanged: expectedEvents
        )
        try failWriteIfNeeded()
        var updated = storage
        events.forEach { updated[$0.id] = $0 }
        for event in eventsToDelete {
            updated[event.id] = nil
        }
        storage = updated
    }

    func update(_ event: CalendarEvent) throws {
        try failWriteIfNeeded()
        storage[event.id] = event
    }

    func delete(id: UUID) {
        storage[id] = nil
    }

    func deleteBatch(_ expectedEvents: [CalendarEvent]) throws {
        guard expectedEvents.allSatisfy({ storage[$0.id] != nil }) else {
            throw EventRepositoryBatchError.eventNotFound
        }
        guard expectedEvents.allSatisfy({ storage[$0.id] == $0 }) else {
            throw EventRepositoryBatchError.staleData
        }
        expectedEvents.forEach { storage[$0.id] = nil }
    }

    func events(in range: DateInterval) -> [CalendarEvent] {
        storage.values.filter {
            ($0.startDate < range.end && $0.endDate > range.start)
                || ($0.startDate >= range.start && $0.startDate < range.end)
        }
    }

    func event(id: UUID) -> CalendarEvent? {
        storage[id]
    }

    func events(unifiedEntryID: UUID) -> [CalendarEvent] {
        storage.values.filter {
            $0.unifiedEntryID == unifiedEntryID
        }
    }

    func workRecordEvents(workSessionID: UUID) -> [CalendarEvent] {
        storage.values.filter {
            $0.workInfo?.workSessionId == workSessionID
        }
    }

    func reassignEvents(from sourceCalendarID: UUID, to targetCalendarID: UUID) throws {
        if remainingReassignmentFailures > 0 {
            remainingReassignmentFailures -= 1
            throw InjectedSharingTestError.failure
        }
        let now = Date()
        for (id, var event) in storage where event.calendarID == sourceCalendarID {
            event.calendarID = targetCalendarID
            event.updatedAt = now
            storage[id] = event
        }
    }

    func failNextReassignment() {
        remainingReassignmentFailures += 1
    }

    func failNextWrite() {
        remainingWriteFailures += 1
    }

    func failWrite(afterSuccessfulWrites count: Int) {
        writesBeforeInjectedFailure = count
    }

    func applyBatchCallCount() -> Int {
        applyBatchCalls
    }

    private func failWriteIfNeeded() throws {
        if let remaining = writesBeforeInjectedFailure {
            if remaining == 0 {
                writesBeforeInjectedFailure = nil
                throw InjectedSharingTestError.failure
            }
            writesBeforeInjectedFailure = remaining - 1
        }
        if remainingWriteFailures > 0 {
            remainingWriteFailures -= 1
            throw InjectedSharingTestError.failure
        }
    }
}

@MainActor
private func makeOwnedState(
    calendar: TimeNestCalendar,
    participants: [SharedCalendarParticipantSnapshot] = []
) -> OwnedSharedCalendarCloudState {
    let zoneID = CKRecordZone.ID(
        zoneName: CalendarSharingCloudSchema.zoneName(for: calendar.id),
        ownerName: CKCurrentUserDefaultName
    )
    let share = CalendarSharingCloudRecordFactory.makeZoneWideShare(recordZoneID: zoneID)
    return OwnedSharedCalendarCloudState(
        calendar: OwnedSharedCalendarDescriptor(
            id: calendar.id,
            zoneName: zoneID.zoneName,
            ownerName: zoneID.ownerName,
            calendarName: calendar.name,
            participantCount: participants.filter(\.isAccepted).count,
            rootRecordName: CalendarSharingCloudSchema.calendarRecordName,
            shareRecordName: CKRecordNameZoneWideShare,
            eventEditingAllowed: calendar.eventEditingAllowed
        ),
        share: share,
        participants: participants
    )
}

private func makeCalendar(
    kind: TimeNestCalendarKind,
    name: String,
    id: UUID = UUID(),
    eventEditingAllowed: Bool = false,
    participantPermission: SharedCalendarParticipantPermission = .unknown
) -> TimeNestCalendar {
    let now = Date()
    return TimeNestCalendar(
        id: id,
        name: name,
        kind: kind,
        zoneName: kind.isCloudBacked ? CalendarSharingCloudSchema.zoneName(for: id) : nil,
        ownerName: kind.isCloudBacked ? CKCurrentUserDefaultName : nil,
        rootRecordName: kind.isCloudBacked ? CalendarSharingCloudSchema.calendarRecordName : nil,
        shareRecordName: kind.isCloudBacked ? CKRecordNameZoneWideShare : nil,
        eventEditingAllowed: eventEditingAllowed,
        participantPermission: participantPermission,
        createdAt: now,
        updatedAt: now
    )
}

private struct FakeCalendarSharingMetadata: CalendarSharingShareMetadata {
    let containerIdentifier: String
    let participantStatus: CKShare.ParticipantAcceptanceStatus
    let share: CKShare
    let ownerNameComponents: PersonNameComponents?
}

private func makeFakeSharingMetadata(
    zoneName: String = CalendarSharingCloudSchema.zoneName(for: UUID()),
    containerIdentifier: String = "iCloud.com.song.TimeNest",
    status: CKShare.ParticipantAcceptanceStatus = .pending,
    ownerGivenName: String? = nil
) -> FakeCalendarSharingMetadata {
    let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: "owner")
    var components = PersonNameComponents()
    components.givenName = ownerGivenName
    return FakeCalendarSharingMetadata(
        containerIdentifier: containerIdentifier,
        participantStatus: status,
        share: CalendarSharingCloudRecordFactory.makeZoneWideShare(recordZoneID: zoneID),
        ownerNameComponents: ownerGivenName == nil ? nil : components
    )
}

private func makeReceivedPayload(
    calendar: TimeNestCalendar,
    ownerDisplayName: String? = nil
) -> ReceivedSharedCalendarPayload {
    let zoneName = calendar.zoneName ?? CalendarSharingCloudSchema.zoneName(for: calendar.id)
    let ownerName = calendar.ownerName ?? "owner"
    return ReceivedSharedCalendarPayload(
        calendar: SharedCalendarDescriptor(
            id: calendar.id,
            zoneName: zoneName,
            ownerName: ownerName,
            ownerDisplayName: ownerDisplayName,
            calendarName: calendar.name,
            participantCount: 1,
            kind: .sharedReceived,
            rootRecordName: calendar.rootRecordName ?? CalendarSharingCloudSchema.calendarRecordName,
            shareRecordName: calendar.shareRecordName ?? CKRecordNameZoneWideShare
        ),
        events: [],
        shifts: [],
        workRecords: []
    )
}

private func makeParticipant(
    id: String,
    isAccepted: Bool
) -> SharedCalendarParticipantSnapshot {
    SharedCalendarParticipantSnapshot(
        id: OwnedCalendarParticipantSnapshotAssembler.participantSnapshotID(id),
        displayName: isAccepted ? "Accepted" : nil,
        isAccepted: isAccepted,
        permission: .readOnly,
        revocationToken: isAccepted ? nil : id
    )
}

private func makeEvent(
    id: UUID = UUID(),
    title: String,
    calendarID: UUID = TimeNestCalendar.personalID,
    note: String? = nil,
    reminderOffsetMinutes: Int? = nil,
    notificationID: String? = nil,
    shiftTemplateID: ShiftTimeTemplateID? = nil,
    workInfo: WorkInfo? = nil,
    startDate: Date? = nil,
    endDate: Date? = nil
) -> CalendarEvent {
    let start = startDate ?? Date(timeIntervalSince1970: 1_700_000_000)
    return CalendarEvent(
        id: id,
        calendarID: calendarID,
        title: title,
        note: note,
        startDate: start,
        endDate: endDate ?? start.addingTimeInterval(3_600),
        isAllDay: false,
        categoryID: nil,
        recurrenceRule: .none,
        reminderTemplateID: nil,
        reminderOffsetMinutes: reminderOffsetMinutes,
        notificationID: notificationID,
        importSource: nil,
        createdAt: start,
        updatedAt: start,
        shiftTemplateID: shiftTemplateID,
        workInfo: workInfo
    )
}

private func makeTestDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int = 12,
    minute: Int = 0
) -> Date {
    var components = DateComponents()
    components.calendar = .current
    components.timeZone = .current
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return components.date!
}

private final class MonthInputTestEventUseCase: EventUseCase {
    var batchCallCount = 0
    var failNextBatch = false

    override func createEventsAtomically(_ events: [CalendarEvent]) async throws {
        batchCallCount += 1
        if failNextBatch {
            failNextBatch = false
            throw EventUseCaseError.invalidDateRange
        }
        try await super.createEventsAtomically(events)
    }
}
