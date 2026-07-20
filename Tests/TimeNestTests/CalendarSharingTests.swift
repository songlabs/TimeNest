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

        XCTAssertEqual(labels, ["id", "title", "startDate", "endDate", "isAllDay", "updatedAt"])
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

    func testProjectKeepsMarketingVersionOnePointFiveAndBuildEleven() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let project = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Project.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(project.contains("let marketingVersion = \"1.5\""))
        XCTAssertTrue(project.contains("let buildNumber = \"11\""))
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
            subscriptionManager: subscriptionManager
        )
        viewModel.selectedDate = sharedEventStart

        await viewModel.reloadMonth()

        let monthCell = try XCTUnwrap(
            viewModel.grid?.days.first { $0.date == holidayDate }
        )
        XCTAssertEqual(monthCell.holidays.map(\.localizedNames.ja), ["海の日"])
        XCTAssertEqual(monthCell.holidays.map(\.localizedNames.zhHans), ["海の日"])
        XCTAssertEqual(monthCell.events.map(\.eventID), [sharedEventID])
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
            subscriptionManager: subscriptionManager
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

    func testWorkRecordMidSaveFailureRetriesWithoutDuplicateClocksOrCalendarDrift() async throws {
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
        let context = WorkRecordEditorSaveContext(
            title: "Work",
            workDate: workDate,
            workInDate: workDate,
            workOutDate: workDate.addingTimeInterval(28_800),
            restTime: 1,
            transportFee: "900",
            hourlyRate: "2500",
            workSessionId: sessionID,
            isWorkOutTimeSet: true,
            editInitialSession: nil
        )
        let create: EventEditorSaveAction = { title, note, start, end, isAllDay,
            reminder, shift, workInfo, calendarID in
            try await viewModel.createEvent(
                title: title,
                note: note,
                startDate: start,
                endDate: end,
                isAllDay: isAllDay,
                reminderOffsetMinutes: reminder,
                shiftTemplateID: shift,
                workInfo: workInfo,
                calendarID: calendarID
            )
        }
        let save = {
            try await WorkRecordEditorSaveLogic.save(
                context: context,
                defaultTitle: "Work",
                onCreateEvent: { title, note, start, end, isAllDay, reminder, shift, workInfo in
                    try await create(
                        title, note, start, end, isAllDay, reminder, shift, workInfo, owned.id
                    )
                },
                onUpdateEvent: nil
            )
        }
        await eventRepository.failWrite(afterSuccessfulWrites: 2)

        do {
            _ = try await save()
            XCTFail("The injected failure must interrupt after the clock-in is durable")
        } catch {}

        var saved = try await eventUseCase.events(
            in: DateInterval(start: .distantPast, end: .distantFuture),
            calendarID: owned.id
        )
        XCTAssertEqual(saved.filter { $0.workClockKind == .clockIn }.count, 1)
        XCTAssertEqual(saved.filter { $0.workClockKind == .clockOut }.count, 0)

        _ = try await save()
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

    private func makeStore(
        client: MockCalendarSharingClient,
        calendars: [TimeNestCalendar],
        eventUseCase: EventUseCase = EventUseCase(repository: InMemoryEventRepository()),
        calendarRepository: (any CalendarRepository)? = nil,
        invitationRouter: CalendarSharingInvitationRouter? = nil
    ) -> CalendarSharingStore {
        let defaults = UserDefaults(suiteName: "CalendarSharingStoreTests-\(UUID().uuidString)")!
        let cache = CalendarSharingCache(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("CalendarSharingStoreTests-\(UUID().uuidString).json")
        )
        let resolvedCalendarRepository: any CalendarRepository = calendarRepository
            ?? InMemoryCalendarRepository(calendars: calendars)
        return CalendarSharingStore(
            client: client,
            eventUseCase: eventUseCase,
            calendarRepository: resolvedCalendarRepository,
            cache: cache,
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
                id: calendar.id
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
                id: calendar.id
            ),
            participants: participants
        )
        replaceOwnedState(state)
        revokedParticipantIDs.append(participantID)
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

    func create(_ event: CalendarEvent) throws {
        try failWriteIfNeeded()
        storage[event.id] = event
    }

    func createBatch(_ events: [CalendarEvent], ifUnchanged expectedEvents: [CalendarEvent]) throws {
        try failWriteIfNeeded()
        let ids = events.map(\.id)
        guard Set(ids).count == ids.count,
              ids.allSatisfy({ storage[$0] == nil }) else {
            throw EventRepositoryBatchError.duplicateEvent
        }
        guard expectedEvents.allSatisfy({ storage[$0.id] == $0 }) else {
            throw EventRepositoryBatchError.staleData
        }
        var updated = storage
        events.forEach { updated[$0.id] = $0 }
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
            shareRecordName: CKRecordNameZoneWideShare
        ),
        share: share,
        participants: participants
    )
}

private func makeCalendar(
    kind: TimeNestCalendarKind,
    name: String,
    id: UUID = UUID()
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

private func makeReceivedPayload(calendar: TimeNestCalendar) -> ReceivedSharedCalendarPayload {
    let zoneName = calendar.zoneName ?? CalendarSharingCloudSchema.zoneName(for: calendar.id)
    let ownerName = calendar.ownerName ?? "owner"
    return ReceivedSharedCalendarPayload(
        calendar: SharedCalendarDescriptor(
            id: calendar.id,
            zoneName: zoneName,
            ownerName: ownerName,
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
    title: String,
    calendarID: UUID = TimeNestCalendar.personalID,
    note: String? = nil,
    reminderOffsetMinutes: Int? = nil,
    notificationID: String? = nil,
    shiftTemplateID: ShiftTimeTemplateID? = nil,
    workInfo: WorkInfo? = nil
) -> CalendarEvent {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    return CalendarEvent(
        id: UUID(),
        calendarID: calendarID,
        title: title,
        note: note,
        startDate: start,
        endDate: start.addingTimeInterval(3_600),
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
