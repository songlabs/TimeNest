import CloudKit
import XCTest
@testable import TimeNest

final class CalendarSharingSelectionTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "CalendarSharingSelectionTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testMineAndOneSharedCalendarAreSingleSelections() {
        let persistence = CalendarSelectionPersistence(defaults: defaults)
        persistence.save(.shared("calendar-a"))

        XCTAssertEqual(
            persistence.load(validSharedCalendarIDs: ["calendar-a", "calendar-b"]),
            .shared("calendar-a")
        )

        persistence.save(.mine)
        XCTAssertEqual(
            persistence.load(validSharedCalendarIDs: ["calendar-a", "calendar-b"]),
            .mine
        )
    }

    func testSelectionModelHasNoAllCalendarsOption() throws {
        let encodedMine = try JSONEncoder().encode(CalendarSelection.mine)
        let encodedShared = try JSONEncoder().encode(CalendarSelection.shared("calendar-a"))
        let encodedText = String(decoding: encodedMine + encodedShared, as: UTF8.self)

        XCTAssertFalse(encodedText.localizedCaseInsensitiveContains("all"))
        XCTAssertNil(CalendarSelection.mine.sharedCalendarID)
        XCTAssertEqual(CalendarSelection.shared("calendar-a").sharedCalendarID, "calendar-a")
    }

    func testInvalidSharedSelectionFallsBackToMine() {
        XCTAssertEqual(
            CalendarSelectionPersistence.resolved(
                .shared("revoked-calendar"),
                validSharedCalendarIDs: ["remaining-calendar"]
            ),
            .mine
        )
    }

    func testStoredSharedSelectionIsPreservedUntilARefreshCanValidateIt() {
        let persistence = CalendarSelectionPersistence(defaults: defaults)
        persistence.save(.shared("calendar-awaiting-refresh"))

        XCTAssertEqual(persistence.load(), .shared("calendar-awaiting-refresh"))
    }
}

final class SharedEventMappingTests: XCTestCase {
    func testSharedSnapshotContainsOnlyAllowedFields() throws {
        let event = makeEvent(
            title: "Private-note event",
            note: "never share this",
            reminderOffsetMinutes: 15,
            notificationID: "private-notification"
        )

        let snapshot = try XCTUnwrap(SharedEventMapper.snapshot(from: event))
        let labels = Set(Mirror(reflecting: snapshot).children.compactMap(\.label))

        XCTAssertEqual(labels, ["id", "title", "startDate", "endDate", "isAllDay", "updatedAt"])
        XCTAssertEqual(snapshot.id, event.id)
        XCTAssertEqual(snapshot.title, event.title)
    }

    func testShiftWorkRecordMemoAndReminderDoNotEnterSharedData() throws {
        let normalEvent = makeEvent(
            title: "Appointment",
            note: "private memo",
            reminderOffsetMinutes: 30,
            notificationID: "private-id"
        )
        let normalSnapshot = try XCTUnwrap(SharedEventMapper.snapshot(from: normalEvent))
        XCTAssertEqual(normalSnapshot.title, "Appointment")

        let shift = makeEvent(title: "Shift", shiftTemplateID: .day)
        XCTAssertNil(SharedEventMapper.snapshot(from: shift))

        let workRecord = makeEvent(
            title: "Clock In",
            workInfo: WorkInfo(workInTime: Date(), hourlyRate: 2_000)
        )
        XCTAssertNil(SharedEventMapper.snapshot(from: workRecord))

        let occurrence = try XCTUnwrap(
            SharedEventMapper.occurrences(
                from: [normalSnapshot],
                in: DateInterval(start: normalSnapshot.startDate.addingTimeInterval(-60), end: normalSnapshot.endDate.addingTimeInterval(60))
            ).first
        )
        XCTAssertNil(occurrence.note)
        XCTAssertNil(occurrence.reminderOffsetMinutes)
        XCTAssertNil(occurrence.notificationID)
        XCTAssertNil(occurrence.shiftTemplateID)
        XCTAssertNil(occurrence.workInfo)
    }

    private func makeEvent(
        title: String,
        note: String? = nil,
        reminderOffsetMinutes: Int? = nil,
        notificationID: String? = nil,
        shiftTemplateID: ShiftTimeTemplateID? = nil,
        workInfo: WorkInfo? = nil
    ) -> CalendarEvent {
        let start = Date(timeIntervalSince1970: 1_767_225_600)
        return CalendarEvent(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            title: title,
            note: note,
            startDate: start,
            endDate: start.addingTimeInterval(3_600),
            isAllDay: false,
            categoryID: UUID(),
            recurrenceRule: .none,
            reminderTemplateID: UUID(),
            reminderOffsetMinutes: reminderOffsetMinutes,
            notificationID: notificationID,
            importSource: nil,
            createdAt: start,
            updatedAt: start,
            shiftTemplateID: shiftTemplateID,
            workInfo: workInfo
        )
    }
}

final class SharedContentConfigurationTests: XCTestCase {
    func testNewShareDefaultsToEventsAndShiftsOnly() {
        let content = SharedContentConfiguration.newShareDefault

        XCTAssertTrue(content.sharesEvents)
        XCTAssertTrue(content.sharesShifts)
        XCTAssertFalse(content.sharesWorkRecords)
        XCTAssertTrue(content.hasSelectedContent)
        XCTAssertEqual(content.schemaVersion, SharedContentConfiguration.currentSchemaVersion)
    }

    func testLegacyCacheWithoutFlagsUsesEventsOnlyAndDoesNotCrash() throws {
        let json = #"""
        {
          "receivedCalendars": [{
            "id": "legacy-calendar",
            "zoneName": "legacy-zone",
            "ownerName": "legacy-owner",
            "displayName": "Owner",
            "calendarName": "Calendar",
            "participantCount": 1
          }],
          "eventsByCalendarID": {},
          "ownedCalendar": {
            "displayName": "Owner",
            "calendarName": "Calendar",
            "participantCount": 1
          }
        }
        """#.data(using: .utf8)!

        let cache = try JSONDecoder().decode(CalendarSharingCacheData.self, from: json)

        XCTAssertEqual(cache.version, 1)
        XCTAssertTrue(cache.shiftsByCalendarID.isEmpty)
        XCTAssertTrue(cache.workRecordsByCalendarID.isEmpty)
        XCTAssertEqual(cache.receivedCalendars.first?.sharedContent, .legacyDefault)
        XCTAssertEqual(cache.ownedCalendar?.sharedContent, .legacyDefault)
    }

    func testLegacyCloudRootWithoutFlagsUsesEventsOnly() {
        let root = CKRecord(recordType: CalendarSharingCloudSchema.calendarRecordType)

        XCTAssertEqual(
            CalendarSharingCloudSchema.contentConfiguration(from: root),
            .legacyDefault
        )
    }

    func testNoContentSelectionIsInvalid() {
        let content = SharedContentConfiguration(
            sharesEvents: false,
            sharesShifts: false,
            sharesWorkRecords: false,
            schemaVersion: SharedContentConfiguration.currentSchemaVersion
        )

        XCTAssertFalse(content.hasSelectedContent)
    }

    func testRootFlagsAndReconciliationPlanDeleteOnlyDisabledType() throws {
        let content = SharedContentConfiguration(
            sharesEvents: true,
            sharesShifts: false,
            sharesWorkRecords: true,
            schemaVersion: SharedContentConfiguration.currentSchemaVersion
        )
        let root = CKRecord(recordType: CalendarSharingCloudSchema.calendarRecordType)
        CalendarSharingCloudSchema.apply(content, to: root)

        XCTAssertEqual(
            (root[CalendarSharingCloudSchema.CalendarField.sharesEvents] as? NSNumber)?.boolValue,
            true
        )
        XCTAssertEqual(
            (root[CalendarSharingCloudSchema.CalendarField.sharesShifts] as? NSNumber)?.boolValue,
            false
        )
        XCTAssertEqual(
            (root[CalendarSharingCloudSchema.CalendarField.sharesWorkRecords] as? NSNumber)?.boolValue,
            true
        )
        XCTAssertEqual(
            (root[CalendarSharingCloudSchema.CalendarField.schemaVersion] as? NSNumber)?.intValue,
            SharedContentConfiguration.currentSchemaVersion
        )

        let now = Date(timeIntervalSince1970: 1_767_225_600)
        let shift = SharedShiftSnapshot(
            id: UUID(uuidString: "BBBBBBBB-1111-2222-3333-CCCCCCCCCCCC")!,
            registeredDate: now,
            displayName: "Shift",
            startDate: now,
            endDate: now.addingTimeInterval(3_600),
            spansMidnight: false,
            colorHex: "#123456",
            updatedAt: now
        )
        let plan = CalendarSharingContentReconciliationPlan(content: content)

        XCTAssertFalse(plan.deletesAllEventRecords)
        XCTAssertTrue(plan.deletesAllShiftRecords)
        XCTAssertFalse(plan.deletesAllWorkRecords)
        XCTAssertTrue(plan.shiftsToSave([shift]).isEmpty)

        var reenabled = content
        reenabled.sharesShifts = true
        let reenabledPlan = CalendarSharingContentReconciliationPlan(content: reenabled)
        XCTAssertFalse(reenabledPlan.deletesAllShiftRecords)
        XCTAssertEqual(reenabledPlan.shiftsToSave([shift]).map(\.id), [shift.id])
    }
}

final class CalendarSharingCloudRecordFactoryTests: XCTestCase {
    func testContentRecordsUseSharedZoneAndFieldsWithoutHierarchicalParents() {
        let zoneID = CKRecordZone.ID(
            zoneName: CalendarSharingCloudSchema.zoneName,
            ownerName: CKCurrentUserDefaultName
        )
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let eventID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let shiftID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let workID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

        let event = CalendarSharingCloudRecordFactory.makeEventRecord(
            snapshot: SharedEventSnapshot(
                id: eventID,
                title: "Event",
                startDate: timestamp,
                endDate: timestamp.addingTimeInterval(3_600),
                isAllDay: false,
                updatedAt: timestamp
            ),
            recordID: CKRecord.ID(recordName: "event-test", zoneID: zoneID)
        )
        let shift = CalendarSharingCloudRecordFactory.makeShiftRecord(
            snapshot: SharedShiftSnapshot(
                id: shiftID,
                registeredDate: timestamp,
                displayName: "Day",
                startDate: timestamp,
                endDate: timestamp.addingTimeInterval(3_600),
                spansMidnight: false,
                colorHex: "#3366CC",
                updatedAt: timestamp
            ),
            recordID: CKRecord.ID(recordName: "shift-test", zoneID: zoneID)
        )
        let work = CalendarSharingCloudRecordFactory.makeWorkRecord(
            snapshot: SharedWorkRecordSnapshot(
                id: workID,
                workDate: timestamp,
                workInTime: timestamp,
                workOutTime: timestamp.addingTimeInterval(3_600),
                isWorkOutTimeSet: true,
                restHours: 0.5,
                updatedAt: timestamp
            ),
            recordID: CKRecord.ID(recordName: "work-test", zoneID: zoneID)
        )

        XCTAssertEqual(
            [event.recordType, shift.recordType, work.recordType],
            [
                CalendarSharingCloudSchema.eventRecordType,
                CalendarSharingCloudSchema.shiftRecordType,
                CalendarSharingCloudSchema.workRecordType
            ]
        )
        for record in [event, shift, work] {
            XCTAssertNil(record.parent)
            XCTAssertEqual(record.recordID.zoneID, zoneID)
        }
        XCTAssertEqual(Set(event.allKeys()), Set([
            CalendarSharingCloudSchema.EventField.eventID,
            CalendarSharingCloudSchema.EventField.title,
            CalendarSharingCloudSchema.EventField.startDate,
            CalendarSharingCloudSchema.EventField.endDate,
            CalendarSharingCloudSchema.EventField.isAllDay,
            CalendarSharingCloudSchema.EventField.updatedAt
        ]))
        XCTAssertEqual(Set(shift.allKeys()), Set([
            CalendarSharingCloudSchema.ShiftField.shiftID,
            CalendarSharingCloudSchema.ShiftField.registeredDate,
            CalendarSharingCloudSchema.ShiftField.displayName,
            CalendarSharingCloudSchema.ShiftField.startDate,
            CalendarSharingCloudSchema.ShiftField.endDate,
            CalendarSharingCloudSchema.ShiftField.spansMidnight,
            CalendarSharingCloudSchema.ShiftField.colorHex,
            CalendarSharingCloudSchema.ShiftField.updatedAt
        ]))
        XCTAssertEqual(Set(work.allKeys()), Set([
            CalendarSharingCloudSchema.WorkRecordField.workRecordID,
            CalendarSharingCloudSchema.WorkRecordField.workDate,
            CalendarSharingCloudSchema.WorkRecordField.workInTime,
            CalendarSharingCloudSchema.WorkRecordField.workOutTime,
            CalendarSharingCloudSchema.WorkRecordField.isWorkOutTimeSet,
            CalendarSharingCloudSchema.WorkRecordField.restHours,
            CalendarSharingCloudSchema.WorkRecordField.updatedAt
        ]))
        XCTAssertEqual(event[CalendarSharingCloudSchema.EventField.eventID] as? String, eventID.uuidString)
        XCTAssertEqual(shift[CalendarSharingCloudSchema.ShiftField.shiftID] as? String, shiftID.uuidString)
        XCTAssertEqual(work[CalendarSharingCloudSchema.WorkRecordField.workRecordID] as? String, workID.uuidString)
    }

    func testShareFactoryCreatesZoneWideShareInSharedZone() {
        let zoneID = CKRecordZone.ID(
            zoneName: CalendarSharingCloudSchema.zoneName,
            ownerName: CKCurrentUserDefaultName
        )

        let share = CalendarSharingCloudRecordFactory.makeZoneWideShare(recordZoneID: zoneID)

        XCTAssertEqual(share.recordType, CKRecord.SystemType.share)
        XCTAssertEqual(share.recordID.zoneID, zoneID)
    }
}

final class SharedShiftMappingTests: XCTestCase {
    func testShiftSnapshotContainsOnlyDisplayFieldsAndKeepsOvernightColor() throws {
        let calendar = Calendar(identifier: .gregorian)
        let registeredDate = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 10)
        ))
        let start = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 10, hour: 22)
        ))
        let end = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 11, hour: 7)
        ))
        let templateID = ShiftTimeTemplateID.custom(
            UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        )
        let template = ShiftTimeTemplate(
            id: templateID,
            nameKey: .shiftCommon,
            displayName: "Blue Night",
            note: "private template note",
            colorHex: "#3366CC",
            startTime: "22:00",
            endTime: "07:00",
            enabled: true
        )
        let event = makeSharingEvent(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            title: "Blue Night",
            note: "private shift memo",
            start: start,
            end: end,
            shiftTemplateID: templateID
        )

        let snapshot = try XCTUnwrap(
            SharedShiftMapper.snapshot(from: event, templates: [template])
        )
        let labels = Set(Mirror(reflecting: snapshot).children.compactMap(\.label))

        XCTAssertEqual(labels, [
            "id", "registeredDate", "displayName", "startDate", "endDate",
            "spansMidnight", "colorHex", "updatedAt"
        ])
        XCTAssertEqual(snapshot.registeredDate, registeredDate)
        XCTAssertEqual(snapshot.displayName, "Blue Night")
        XCTAssertEqual(snapshot.startDate, start)
        XCTAssertEqual(snapshot.endDate, end)
        XCTAssertTrue(snapshot.spansMidnight)
        XCTAssertEqual(snapshot.colorHex, "#3366CC")

        let occurrences = SharedShiftMapper.occurrences(
            from: [snapshot],
            in: DateInterval(
                start: registeredDate,
                end: try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: registeredDate))
            )
        )
        XCTAssertEqual(occurrences.count, 1)
        XCTAssertEqual(occurrences.first?.occurrenceDate, DateOnly(from: registeredDate))
        XCTAssertEqual(occurrences.first?.sharedShiftColorHex, "#3366CC")
        XCTAssertNil(occurrences.first?.note)
        XCTAssertNil(occurrences.first?.workInfo)
    }
}

final class SharedWorkRecordMappingTests: XCTestCase {
    func testWorkRecordSnapshotExcludesPayMemoAndNotifications() throws {
        let calendar = Calendar(identifier: .gregorian)
        let workDate = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 10)
        ))
        let workIn = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 10, hour: 9)
        ))
        let workOut = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 10, hour: 18)
        ))
        let sessionID = UUID(uuidString: "AAAAAAAA-1111-2222-3333-BBBBBBBBBBBB")!
        let clockIn = makeSharingEvent(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            title: "Private workplace title",
            note: "private work memo",
            start: workIn,
            end: workIn.addingTimeInterval(3_600),
            reminderOffsetMinutes: 10,
            notificationID: "private-notification",
            workInfo: WorkInfo(
                workInTime: workIn,
                restHours: 1.25,
                workDate: workDate,
                transportFee: 900,
                hourlyRate: 3_000,
                workSessionId: sessionID,
                isWorkOutTimeSet: true
            )
        )
        let clockOut = makeSharingEvent(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            title: "Private workplace title",
            note: "private work memo",
            start: workOut,
            end: workOut.addingTimeInterval(3_600),
            workInfo: WorkInfo(
                workOutTime: workOut,
                restHours: 1.25,
                workDate: workDate,
                transportFee: 900,
                hourlyRate: 3_000,
                workSessionId: sessionID,
                isWorkOutTimeSet: true
            )
        )

        let snapshot = try XCTUnwrap(
            SharedWorkRecordMapper.snapshots(from: [clockIn, clockOut]).first
        )
        let labels = Set(Mirror(reflecting: snapshot).children.compactMap(\.label))

        XCTAssertEqual(labels, [
            "id", "workDate", "workInTime", "workOutTime",
            "isWorkOutTimeSet", "restHours", "updatedAt"
        ])
        XCTAssertEqual(snapshot.id, sessionID)
        XCTAssertEqual(snapshot.workInTime, workIn)
        XCTAssertEqual(snapshot.workOutTime, workOut)
        XCTAssertTrue(snapshot.isWorkOutTimeSet)
        XCTAssertEqual(snapshot.restHours, 1.25)

        let occurrences = SharedWorkRecordMapper.occurrences(
            from: [snapshot],
            in: DateInterval(
                start: workDate,
                end: try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: workDate))
            )
        )
        XCTAssertEqual(occurrences.count, 2)
        XCTAssertTrue(occurrences.allSatisfy { $0.note == nil })
        XCTAssertTrue(occurrences.allSatisfy { $0.notificationID == nil })
        XCTAssertTrue(occurrences.allSatisfy { $0.workInfo?.hourlyRate == nil })
        XCTAssertTrue(occurrences.allSatisfy { $0.workInfo?.transportFee == nil })
    }
}

final class CalendarSharingPolicyTests: XCTestCase {
    func testSharedCalendarIsReadOnlyAndHidesCreationAndEditing() {
        let policy = CalendarAccessPolicy(selection: .shared("calendar-a"))

        XCTAssertTrue(policy.isReadOnly)
        XCTAssertFalse(policy.canCreate)
        XCTAssertFalse(policy.canEdit)
        XCTAssertFalse(policy.canDelete)
        XCTAssertFalse(policy.showsAddButton)
    }

    func testMyCalendarRestoresCreationAndEditing() {
        let policy = CalendarAccessPolicy(selection: .mine)

        XCTAssertFalse(policy.isReadOnly)
        XCTAssertTrue(policy.canCreate)
        XCTAssertTrue(policy.canEdit)
        XCTAssertTrue(policy.canDelete)
        XCTAssertTrue(policy.showsAddButton)
    }

    func testStoppingShareDoesNotDeleteZoneOrLocalEvents() {
        let plan = OwnedSharingStopPlan()

        XCTAssertTrue(plan.deletesShareRecord)
        XCTAssertFalse(plan.deletesRecordZone)
        XCTAssertFalse(plan.deletesLocalEvents)
    }
}

final class CalendarSharingPresentationLogicTests: XCTestCase {
    func testAvatarUsesFirstCharacterAndFallback() {
        XCTAssertEqual(CalendarAvatarInitial.make(displayName: "田中", fallback: "共"), "田")
        XCTAssertEqual(CalendarAvatarInitial.make(displayName: "  Alice", fallback: "S"), "A")
        XCTAssertEqual(CalendarAvatarInitial.make(displayName: "   ", fallback: "共有"), "共")
    }

    func testMissingNamesUseLocalizedFallbackInputsInsteadOfRecordID() {
        let calendar = SharedCalendarDescriptor(
            id: "opaque-id",
            zoneName: "private-zone",
            ownerName: "private-owner",
            displayName: " ",
            calendarName: nil,
            participantCount: 0
        )

        XCTAssertEqual(calendar.resolvedDisplayName(fallback: "Shared User"), "Shared User")
        XCTAssertEqual(calendar.resolvedCalendarName(fallback: "Shared Calendar"), "Shared Calendar")
        XCTAssertNotEqual(calendar.resolvedCalendarName(fallback: "Shared Calendar"), calendar.id)
    }

    func testLegacyDisplayNameAndCalendarOnlyRecordsResolveCompatibly() {
        let zoneID = CKRecordZone.ID(zoneName: "legacy-zone", ownerName: "legacy-owner")
        let legacyRecord = CKRecord(
            recordType: CalendarSharingCloudSchema.calendarRecordType,
            recordID: CKRecord.ID(recordName: "legacy", zoneID: zoneID)
        )
        legacyRecord[CalendarSharingCloudSchema.CalendarField.displayName] = " Legacy calendar " as CKRecordValue

        let legacyNames = CalendarSharingCloudSchema.compatibleNames(from: legacyRecord)
        XCTAssertEqual(legacyNames.displayName, "Legacy calendar")
        XCTAssertEqual(legacyNames.calendarName, "Legacy calendar")

        let calendarOnlyRecord = CKRecord(
            recordType: CalendarSharingCloudSchema.calendarRecordType,
            recordID: CKRecord.ID(recordName: "calendar-only", zoneID: zoneID)
        )
        calendarOnlyRecord[CalendarSharingCloudSchema.CalendarField.calendarName] = " Family " as CKRecordValue

        let calendarOnlyNames = CalendarSharingCloudSchema.compatibleNames(from: calendarOnlyRecord)
        XCTAssertEqual(calendarOnlyNames.displayName, "Family")
        XCTAssertEqual(calendarOnlyNames.calendarName, "Family")
    }

    func testDisplayNameIsOnlyShownWhenDistinctFromCalendarName() {
        var calendar = SharedCalendarDescriptor(
            id: "shared-id",
            zoneName: "shared-zone",
            ownerName: "private-owner",
            displayName: "Owner",
            calendarName: "Shared Calendar",
            participantCount: 0
        )

        XCTAssertEqual(calendar.distinctDisplayName, "Owner")

        calendar.displayName = " Shared Calendar "
        XCTAssertNil(calendar.distinctDisplayName)
    }

    func testCloudKitErrorsMapToUnderstandableCategories() {
        XCTAssertEqual(CalendarSharingErrorMapper.map(code: .notAuthenticated), .noICloudAccount)
        XCTAssertEqual(CalendarSharingErrorMapper.map(code: .accountTemporarilyUnavailable), .networkUnavailable)
        XCTAssertEqual(CalendarSharingErrorMapper.map(code: .managedAccountRestricted), .iCloudRestricted)
        XCTAssertEqual(CalendarSharingErrorMapper.map(code: .missingEntitlement), .iCloudRestricted)
        XCTAssertEqual(CalendarSharingErrorMapper.map(code: .badContainer), .iCloudRestricted)
        XCTAssertEqual(CalendarSharingErrorMapper.map(code: .networkFailure), .networkUnavailable)
        XCTAssertEqual(CalendarSharingErrorMapper.map(code: .participantMayNeedVerification), .invitationPending)
        XCTAssertEqual(CalendarSharingErrorMapper.map(code: .unknownItem), .syncFailed)
        XCTAssertEqual(
            CalendarSharingErrorMapper.map(code: .unknownItem, context: .creatingShare),
            .shareCreationFailed
        )
        XCTAssertEqual(CalendarSharingErrorMapper.map(code: .permissionFailure), .permissionDenied)
        XCTAssertEqual(CalendarSharingErrorMapper.map(code: .internalError), .syncFailed)
        XCTAssertEqual(
            CalendarSharingErrorMapper.map(code: .serverRejectedRequest, context: .creatingShare),
            .shareCreationFailed
        )
        XCTAssertTrue(CalendarSharingErrorMapper.isCancellation(CancellationError()))
        XCTAssertTrue(CalendarSharingErrorMapper.isCancellation(CKError(.operationCancelled)))
    }

    func testMissingSharedEventRecordTypeIsEmptyButMissingZoneIsFailure() {
        XCTAssertTrue(
            CalendarSharingErrorMapper.shouldTreatMissingQueriedRecordTypeAsEmpty(
                CKError(.unknownItem)
            )
        )
        XCTAssertFalse(
            CalendarSharingErrorMapper.shouldTreatMissingQueriedRecordTypeAsEmpty(
                CKError(.zoneNotFound)
            )
        )
        XCTAssertFalse(
            CalendarSharingErrorMapper.isMissingOrInaccessibleSharedZone(
                CKError(.zoneNotFound)
            )
        )
        XCTAssertFalse(
            CalendarSharingErrorMapper.isMissingOrInaccessibleSharedZone(
                CKError(.permissionFailure)
            )
        )
    }

    func testPartialFailureKeepsItsActionableCloudKitCategory() {
        let partialErrors: [AnyHashable: Error] = [
            AnyHashable("network"): CKError(.networkFailure)
        ]
        let error = CKError(
            .partialFailure,
            userInfo: [CKPartialErrorsByItemIDKey: partialErrors]
        )

        XCTAssertEqual(CalendarSharingErrorMapper.map(error), .networkUnavailable)
    }

    func testCloudKitRawValueTwelveIsInvalidArguments() throws {
        let code = try XCTUnwrap(CKError.Code(rawValue: 12))

        XCTAssertEqual(code, .invalidArguments)
        XCTAssertEqual(CalendarSharingErrorMapper.cloudErrorCodeName(code), "invalidArguments")
        XCTAssertEqual(
            CalendarSharingErrorMapper.cloudErrorCodeSummary(CKError(.invalidArguments)),
            "invalidArguments(12)"
        )
    }

    func testPartialFailureExposesLeafErrorCodes() {
        let partialErrors: [AnyHashable: Error] = [
            AnyHashable("one"): CKError(.networkFailure),
            AnyHashable("two"): CKError(.zoneNotFound)
        ]
        let error = CKError(
            .partialFailure,
            userInfo: [CKPartialErrorsByItemIDKey: partialErrors]
        )

        let codes = CalendarSharingErrorMapper.cloudErrorCodes(in: error)

        XCTAssertTrue(codes.contains(.partialFailure))
        XCTAssertTrue(codes.contains(.networkFailure))
        XCTAssertTrue(codes.contains(.zoneNotFound))
    }

    func testDiagnosticSummaryOmitsServerMessagesAndUniqueIdentifiers() {
        let uniqueID = "11111111-2222-3333-4444-555555555555"
        let error = CKError(
            .invalidArguments,
            userInfo: [NSLocalizedDescriptionKey: "Invalid record \(uniqueID)"]
        )

        let summary = CalendarSharingErrorMapper.diagnosticSummary(error)

        XCTAssertTrue(summary.contains("errorDomain=CKErrorDomain"))
        XCTAssertTrue(summary.contains("invalidArguments(12)"))
        XCTAssertTrue(summary.contains("serverMessage=omitted"))
        XCTAssertFalse(summary.contains(uniqueID))
    }

    func testOnlyUnknownItemCanRepresentMissingQueriedRecordType() {
        let mixedLeafErrors: [AnyHashable: Error] = [
            AnyHashable("missing"): CKError(.unknownItem),
            AnyHashable("invalid"): CKError(.invalidArguments)
        ]
        let mixedError = CKError(
            .partialFailure,
            userInfo: [CKPartialErrorsByItemIDKey: mixedLeafErrors]
        )

        XCTAssertTrue(
            CalendarSharingErrorMapper.shouldTreatMissingQueriedRecordTypeAsEmpty(
                CKError(.unknownItem)
            )
        )
        XCTAssertFalse(
            CalendarSharingErrorMapper.shouldTreatMissingQueriedRecordTypeAsEmpty(mixedError)
        )
        XCTAssertFalse(
            CalendarSharingErrorMapper.shouldTreatMissingQueriedRecordTypeAsEmpty(
                CKError(.invalidArguments)
            )
        )
    }

    func testChangeTokenExpiredRestartsOnlyOnce() {
        let error = CKError(.changeTokenExpired)

        XCTAssertTrue(
            CalendarSharingErrorMapper.shouldRestartZoneChangesFromBeginning(
                error,
                alreadyRetried: false
            )
        )
        XCTAssertFalse(
            CalendarSharingErrorMapper.shouldRestartZoneChangesFromBeginning(
                error,
                alreadyRetried: true
            )
        )
        XCTAssertFalse(
            CalendarSharingErrorMapper.shouldRestartZoneChangesFromBeginning(
                CKError(.networkFailure),
                alreadyRetried: false
            )
        )
    }
}

final class ReceivedSharedCalendarPayloadAssemblerTests: XCTestCase {
    func testClassifiesSharedZoneRecordsAndBuildsPayload() throws {
        let zoneID = makeZoneID(name: "zone-a")
        var records = SharedZoneRecordCollection()
        let root = makeCalendarRecord(zoneID: zoneID)
        let event = makeEventRecord(zoneID: zoneID)
        let shift = makeShiftRecord(zoneID: zoneID)
        let work = makeWorkRecord(zoneID: zoneID)
        let legacyParent = CKRecord.Reference(recordID: root.recordID, action: .none)
        event.parent = legacyParent
        shift.parent = legacyParent
        work.parent = legacyParent
        records.apply([root, event, shift, work, CKShare(recordZoneID: zoneID)])

        let payload = try XCTUnwrap(
            ReceivedSharedCalendarPayloadAssembler.makePayload(zoneID: zoneID, records: records)
        )

        XCTAssertEqual(payload.calendar.calendarName, "Shared calendar")
        XCTAssertEqual(payload.events.map(\.id), [Self.eventID])
        XCTAssertEqual(payload.shifts.map(\.id), [Self.shiftID])
        XCTAssertEqual(payload.workRecords.map(\.id), [Self.workID])
        XCTAssertEqual(records.records(ofType: CKRecord.SystemType.share).count, 1)
        XCTAssertNotNil(event.parent)
        XCTAssertNotNil(shift.parent)
        XCTAssertNotNil(work.parent)
    }

    func testEmptyContentRecordsKeepCalendarRoot() throws {
        let zoneID = makeZoneID(name: "zone-empty")
        var records = SharedZoneRecordCollection()
        records.apply([makeCalendarRecord(zoneID: zoneID)])

        let payload = try XCTUnwrap(
            ReceivedSharedCalendarPayloadAssembler.makePayload(zoneID: zoneID, records: records)
        )

        XCTAssertTrue(payload.events.isEmpty)
        XCTAssertTrue(payload.shifts.isEmpty)
        XCTAssertTrue(payload.workRecords.isEmpty)
    }

    func testMissingCalendarRootDoesNotBuildInvalidPayload() {
        let zoneID = makeZoneID(name: "zone-without-root")
        var records = SharedZoneRecordCollection()
        records.apply([makeEventRecord(zoneID: zoneID)])

        XCTAssertNil(
            ReceivedSharedCalendarPayloadAssembler.makePayload(zoneID: zoneID, records: records)
        )
    }

    func testOneInvalidZoneDoesNotDiscardAnotherValidPayloadDuringAssembly() {
        let validZoneID = makeZoneID(name: "valid-zone")
        let invalidZoneID = makeZoneID(name: "invalid-zone")
        var validRecords = SharedZoneRecordCollection()
        validRecords.apply([makeCalendarRecord(zoneID: validZoneID)])
        let invalidRecords = SharedZoneRecordCollection()

        let payloads = [
            (validZoneID, validRecords),
            (invalidZoneID, invalidRecords)
        ].compactMap { zoneID, records in
            ReceivedSharedCalendarPayloadAssembler.makePayload(zoneID: zoneID, records: records)
        }

        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payloads.first?.calendar.zoneName, validZoneID.zoneName)
    }

    func testDeletionRemovesChangedRecordFromFullZoneSnapshot() {
        let zoneID = makeZoneID(name: "zone-delete")
        let event = makeEventRecord(zoneID: zoneID)
        var records = SharedZoneRecordCollection()
        records.apply([makeCalendarRecord(zoneID: zoneID), event])

        records.remove(event.recordID)

        let payload = ReceivedSharedCalendarPayloadAssembler.makePayload(zoneID: zoneID, records: records)
        XCTAssertTrue(payload?.events.isEmpty == true)
    }

    private static let eventID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static let shiftID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private static let workID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    private let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeZoneID(name: String) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: name, ownerName: "test-owner")
    }

    private func makeCalendarRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: CalendarSharingCloudSchema.calendarRecordName,
            zoneID: zoneID
        )
        let record = CKRecord(
            recordType: CalendarSharingCloudSchema.calendarRecordType,
            recordID: recordID
        )
        record[CalendarSharingCloudSchema.CalendarField.displayName] = "Owner" as CKRecordValue
        record[CalendarSharingCloudSchema.CalendarField.calendarName] = "Shared calendar" as CKRecordValue
        record[CalendarSharingCloudSchema.CalendarField.sharesEvents] = NSNumber(value: true)
        record[CalendarSharingCloudSchema.CalendarField.sharesShifts] = NSNumber(value: true)
        record[CalendarSharingCloudSchema.CalendarField.sharesWorkRecords] = NSNumber(value: true)
        record[CalendarSharingCloudSchema.CalendarField.schemaVersion] = NSNumber(value: 2)
        return record
    }

    private func makeEventRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(
            recordType: CalendarSharingCloudSchema.eventRecordType,
            recordID: CKRecord.ID(recordName: "event", zoneID: zoneID)
        )
        record[CalendarSharingCloudSchema.EventField.eventID] = Self.eventID.uuidString as CKRecordValue
        record[CalendarSharingCloudSchema.EventField.title] = "Event" as CKRecordValue
        record[CalendarSharingCloudSchema.EventField.startDate] = timestamp as CKRecordValue
        record[CalendarSharingCloudSchema.EventField.endDate] = timestamp.addingTimeInterval(3_600) as CKRecordValue
        record[CalendarSharingCloudSchema.EventField.isAllDay] = NSNumber(value: false)
        record[CalendarSharingCloudSchema.EventField.updatedAt] = timestamp as CKRecordValue
        return record
    }

    private func makeShiftRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(
            recordType: CalendarSharingCloudSchema.shiftRecordType,
            recordID: CKRecord.ID(recordName: "shift", zoneID: zoneID)
        )
        record[CalendarSharingCloudSchema.ShiftField.shiftID] = Self.shiftID.uuidString as CKRecordValue
        record[CalendarSharingCloudSchema.ShiftField.registeredDate] = timestamp as CKRecordValue
        record[CalendarSharingCloudSchema.ShiftField.displayName] = "Day" as CKRecordValue
        record[CalendarSharingCloudSchema.ShiftField.startDate] = timestamp as CKRecordValue
        record[CalendarSharingCloudSchema.ShiftField.endDate] = timestamp.addingTimeInterval(3_600) as CKRecordValue
        record[CalendarSharingCloudSchema.ShiftField.spansMidnight] = NSNumber(value: false)
        record[CalendarSharingCloudSchema.ShiftField.colorHex] = "#3366CC" as CKRecordValue
        record[CalendarSharingCloudSchema.ShiftField.updatedAt] = timestamp as CKRecordValue
        return record
    }

    private func makeWorkRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(
            recordType: CalendarSharingCloudSchema.workRecordType,
            recordID: CKRecord.ID(recordName: "work", zoneID: zoneID)
        )
        record[CalendarSharingCloudSchema.WorkRecordField.workRecordID] = Self.workID.uuidString as CKRecordValue
        record[CalendarSharingCloudSchema.WorkRecordField.workDate] = timestamp as CKRecordValue
        record[CalendarSharingCloudSchema.WorkRecordField.workInTime] = timestamp as CKRecordValue
        record[CalendarSharingCloudSchema.WorkRecordField.workOutTime] = timestamp.addingTimeInterval(3_600) as CKRecordValue
        record[CalendarSharingCloudSchema.WorkRecordField.isWorkOutTimeSet] = NSNumber(value: true)
        record[CalendarSharingCloudSchema.WorkRecordField.restHours] = NSNumber(value: 0.5)
        record[CalendarSharingCloudSchema.WorkRecordField.updatedAt] = timestamp as CKRecordValue
        return record
    }
}

@MainActor
final class CalendarSharingStoreRefreshTests: XCTestCase {
    func testMyCalendarAndEmptySharedZonesRefreshWithoutErrorOrFallback() async throws {
        let client = CalendarSharingClientStub()
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }

        await context.store.synchronizeAll()

        XCTAssertEqual(context.store.selection, .mine)
        XCTAssertTrue(context.store.receivedCalendars.isEmpty)
        XCTAssertNil(context.store.lastError)
        XCTAssertEqual(context.store.syncStatus, .synced)
    }

    func testExistingReceivedCalendarRemainsSelectedAfterSuccessfulRefresh() async throws {
        let calendar = makeReceivedCalendar(id: "received-a")
        let client = CalendarSharingClientStub()
        client.receivedResult = .success([
            ReceivedSharedCalendarPayload(calendar: calendar, events: [], shifts: [], workRecords: [])
        ])
        let context = try makeStore(
            client: client,
            selection: .shared(calendar.id),
            cachedCalendars: [calendar]
        )
        defer { context.cleanup() }

        await context.store.synchronizeAll()

        XCTAssertEqual(context.store.selection, .shared(calendar.id))
        XCTAssertNil(context.store.lastError)
        XCTAssertEqual(context.store.syncStatus, .synced)
    }

    func testMissingReceivedCalendarFallsBackOnlyAfterSuccessfulRefresh() async throws {
        let calendar = makeReceivedCalendar(id: "received-revoked")
        let client = CalendarSharingClientStub()
        client.receivedResult = .success([])
        let context = try makeStore(
            client: client,
            selection: .shared(calendar.id),
            cachedCalendars: [calendar]
        )
        defer { context.cleanup() }

        XCTAssertEqual(context.store.selection, .shared(calendar.id))
        await context.store.synchronizeAll()

        XCTAssertEqual(context.store.selection, .mine)
        XCTAssertEqual(context.store.lastError, .shareUnavailable)
        XCTAssertEqual(context.store.syncStatus, .synced)
    }

    func testFirstShareAllowsOneCharacterNamesZeroParticipantsAndPreparesController() async throws {
        let client = CalendarSharingClientStub()
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }

        let share = try await context.store.createShare(displayName: "A", calendarName: "B")

        XCTAssertEqual(client.createdDisplayName, "A")
        XCTAssertEqual(client.createdCalendarName, "B")
        XCTAssertEqual(client.createdContent, .newShareDefault)
        XCTAssertEqual(client.createdSnapshots, [])
        XCTAssertEqual(client.createdShifts, [])
        XCTAssertEqual(client.createdWorkRecords, [])
        XCTAssertEqual(context.store.selection, .mine)
        XCTAssertTrue(context.store.receivedCalendars.isEmpty)
        XCTAssertEqual(context.store.ownedCalendar?.participantCount, 0)
        XCTAssertNil(context.store.lastError)
        XCTAssertEqual(share.recordID, client.createdState.share.recordID)

        var presentation = SharingManagementPresentationState()
        presentation.showAlert(.message("stale"))
        presentation.present(share: share, title: "B")
        XCTAssertNotNil(presentation.presentedShare)
        XCTAssertNil(presentation.alertState)
    }

    func testShareUsesCalendarNameAsInternalDisplayNameWhenNotProvided() async throws {
        let client = CalendarSharingClientStub()
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }

        _ = try await context.store.createShare(calendarName: " Shared calendar ")

        XCTAssertEqual(client.createdDisplayName, "Shared calendar")
        XCTAssertEqual(client.createdCalendarName, "Shared calendar")
    }

    func testAllContentOffDoesNotCallCloudKit() async throws {
        let client = CalendarSharingClientStub()
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }
        let none = SharedContentConfiguration(
            sharesEvents: false,
            sharesShifts: false,
            sharesWorkRecords: false,
            schemaVersion: SharedContentConfiguration.currentSchemaVersion
        )

        do {
            _ = try await context.store.createShare(
                displayName: "A",
                calendarName: "B",
                content: none
            )
            XCTFail("Expected empty sharing content to be rejected")
        } catch let error as CalendarSharingError {
            XCTAssertEqual(error, .contentSelectionRequired)
        }

        XCTAssertEqual(client.createCallCount, 0)
        XCTAssertEqual(client.updateCallCount, 0)
    }

    func testWhitespaceCalendarNameDoesNotCallCloudKit() async throws {
        let client = CalendarSharingClientStub()
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }

        do {
            _ = try await context.store.createShare(calendarName: "   \n ")
            XCTFail("Expected a blank calendar name to be rejected")
        } catch let error as CalendarSharingError {
            XCTAssertEqual(error, .shareCreationFailed)
        }

        XCTAssertEqual(client.createCallCount, 0)
    }

    func testDisablingAndReenablingShiftKeepsLocalDataAndUsesStableSnapshot() async throws {
        let repository = InMemoryEventRepository()
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 10, hour: 8, minute: 30)
        ))
        let end = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 10, hour: 17, minute: 30)
        ))
        let event = makeSharingEvent(
            id: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
            title: ShiftTimeTemplateID.day.defaultDisplayName,
            note: "local-only memo",
            start: start,
            end: end,
            shiftTemplateID: .day
        )
        try await repository.create(event)

        let client = CalendarSharingClientStub()
        client.ownedState = client.createdState
        let context = try makeStore(
            client: client,
            selection: .mine,
            repository: repository
        )
        defer { context.cleanup() }

        let disabled = SharedContentConfiguration(
            sharesEvents: true,
            sharesShifts: false,
            sharesWorkRecords: false,
            schemaVersion: 1
        )
        try await context.store.updateOwnedSharing(content: disabled)

        XCTAssertEqual(client.updateCallCount, 1)
        XCTAssertFalse(try XCTUnwrap(client.updatedContent).sharesShifts)
        XCTAssertEqual(client.updatedContent?.schemaVersion, SharedContentConfiguration.currentSchemaVersion)
        XCTAssertEqual(client.synchronizedShifts.map(\.id), [event.id])
        let localEventAfterDisable = try await repository.event(id: event.id)
        XCTAssertEqual(localEventAfterDisable, event)

        let enabled = SharedContentConfiguration(
            sharesEvents: true,
            sharesShifts: true,
            sharesWorkRecords: false,
            schemaVersion: SharedContentConfiguration.currentSchemaVersion
        )
        try await context.store.updateOwnedSharing(content: enabled)

        XCTAssertEqual(client.updateCallCount, 2)
        XCTAssertTrue(try XCTUnwrap(client.updatedContent).sharesShifts)
        XCTAssertEqual(client.synchronizedShifts.map(\.id), [event.id])
        XCTAssertEqual(Set(client.synchronizedShifts.map(\.id)).count, client.synchronizedShifts.count)
        let localEventAfterEnable = try await repository.event(id: event.id)
        XCTAssertEqual(localEventAfterEnable, event)
    }

    func testPartialUpdateFailureKeepsSavedConfigurationAndIsNotShareRevocation() async throws {
        let client = CalendarSharingClientStub()
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }
        _ = try await context.store.createShare(displayName: "A", calendarName: "B")

        let partialErrors: [AnyHashable: Error] = [
            AnyHashable("shift-record"): CKError(.networkFailure)
        ]
        client.updateError = CKError(
            .partialFailure,
            userInfo: [CKPartialErrorsByItemIDKey: partialErrors]
        )
        var updated = SharedContentConfiguration.newShareDefault
        updated.sharesShifts = false

        do {
            try await context.store.updateOwnedSharing(content: updated)
            XCTFail("Expected partial update failure")
        } catch let error as CalendarSharingError {
            XCTAssertEqual(error, .networkUnavailable)
        }

        XCTAssertEqual(context.store.ownedCalendar?.sharedContent, .newShareDefault)
        XCTAssertEqual(context.store.lastError, .networkUnavailable)
        XCTAssertNotEqual(context.store.lastError, .shareUnavailable)
    }

    func testCreateFailureUsesCreationErrorAndDoesNotFallbackReceivedSelection() async throws {
        let calendar = makeReceivedCalendar(id: "received-still-valid")
        let client = CalendarSharingClientStub()
        client.createError = CKError(.unknownItem)
        let context = try makeStore(
            client: client,
            selection: .shared(calendar.id),
            cachedCalendars: [calendar]
        )
        defer { context.cleanup() }

        do {
            _ = try await context.store.createShare(displayName: "A", calendarName: "B")
            XCTFail("Expected share creation to fail")
        } catch let error as CalendarSharingError {
            XCTAssertEqual(error, .shareCreationFailed)
        }

        XCTAssertEqual(context.store.selection, .shared(calendar.id))
        XCTAssertEqual(context.store.lastError, .shareCreationFailed)
        XCTAssertEqual(context.store.syncStatus, .failed)
    }

    func testStartSharingWaitsForRefreshSoOlderRefreshCannotOverwriteNewState() async throws {
        let client = CalendarSharingClientStub()
        client.suspendReceivedFetch = true
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }

        let refreshTask = Task { await context.store.synchronizeAll() }
        await client.waitUntilReceivedFetchStarts()

        let createTask = Task {
            try await context.store.createShare(displayName: "A", calendarName: "B")
        }
        await Task.yield()
        XCTAssertEqual(client.createCallCount, 0)

        client.resumeReceivedFetch()
        await refreshTask.value
        _ = try await createTask.value

        XCTAssertEqual(client.createCallCount, 1)
        XCTAssertEqual(context.store.selection, .mine)
        XCTAssertEqual(context.store.ownedCalendar, client.createdState.calendar)
        XCTAssertNil(context.store.lastError)
    }

    func testNetworkFailurePreservesStaleSelectionAndValidCache() async throws {
        let calendar = makeReceivedCalendar(id: "received-cached")
        let client = CalendarSharingClientStub()
        client.receivedResult = .failure(CalendarSharingError.networkUnavailable)
        let context = try makeStore(
            client: client,
            selection: .shared(calendar.id),
            cachedCalendars: [calendar]
        )
        defer { context.cleanup() }

        await context.store.synchronizeAll()

        XCTAssertEqual(context.store.selection, .shared(calendar.id))
        XCTAssertEqual(context.store.receivedCalendars, [calendar])
        XCTAssertEqual(context.store.lastError, .networkUnavailable)
        XCTAssertEqual(context.store.syncStatus, .failed)
    }

    func testReadOnlySelectionBlocksShiftMutationEntryPoints() async throws {
        let repository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(repository: repository)
        let calendar = Calendar(identifier: .gregorian)
        let shiftDay = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 13)
        ))
        let shiftStart = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 13, hour: 9)
        ))
        let shiftEnd = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 13, hour: 17)
        ))
        let original = makeSharingEvent(
            id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
            title: "Day Shift",
            note: nil,
            start: shiftStart,
            end: shiftEnd,
            shiftTemplateID: .day
        )
        try await repository.create(original)

        let receivedCalendar = makeReceivedCalendar(id: "read-only-calendar")
        let client = CalendarSharingClientStub()
        let context = try makeStore(
            client: client,
            selection: .shared(receivedCalendar.id),
            cachedCalendars: [receivedCalendar],
            repository: repository
        )
        defer { context.cleanup() }

        let viewModel = MonthCalendarViewModel(
            calendarDisplayUseCase: CalendarDisplayUseCase(
                holidayUseCase: HolidayUseCase(holidayProvider: BundleHolidayProvider()),
                localizationUseCase: CalendarLocalizationUseCase(),
                eventUseCase: eventUseCase
            ),
            eventUseCase: eventUseCase,
            calendarSharingStore: context.store
        )
        let replacement = ShiftTimeTemplate(
            id: .night,
            nameKey: .shiftNight,
            displayName: "Night Shift",
            note: "",
            colorHex: "#5C6BC0",
            startTime: "17:00",
            endTime: "09:00",
            enabled: true
        )

        let didCreate = await viewModel.createShiftEvent(on: shiftDay, template: replacement)
        viewModel.selectedDate = shiftDay
        await viewModel.cancelShift()
        let storedEvent = try await repository.event(id: original.id)

        XCTAssertFalse(didCreate)
        XCTAssertEqual(storedEvent, original)
        XCTAssertEqual(
            viewModel.errorMessage,
            CalendarSharingError.permissionDenied.localizedDescription
        )
    }

    func testErrorPresentationClearsShareToAvoidSheetAlertCompetition() {
        var presentation = SharingManagementPresentationState()
        presentation.present(share: CalendarSharingClientStub.makeShare(), title: "Calendar")

        presentation.showAlert(.message("failure"))

        XCTAssertNil(presentation.presentedShare)
        XCTAssertNotNil(presentation.alertState)
    }

    private func makeStore(
        client: CalendarSharingClientStub,
        selection: CalendarSelection,
        cachedCalendars: [SharedCalendarDescriptor] = [],
        repository: EventRepository = InMemoryEventRepository()
    ) throws -> CalendarSharingTestContext {
        let identifier = UUID().uuidString
        let suiteName = "CalendarSharingStoreRefreshTests.\(identifier)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let persistence = CalendarSelectionPersistence(defaults: defaults)
        persistence.save(selection)

        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CalendarSharingStoreRefreshTests-\(identifier).json")
        let cache = CalendarSharingCache(fileURL: cacheURL)
        try cache.save(CalendarSharingCacheData(
            receivedCalendars: cachedCalendars,
            eventsByCalendarID: [:],
            ownedCalendar: nil
        ))

        let store = CalendarSharingStore(
            client: client,
            eventUseCase: EventUseCase(repository: repository),
            cache: cache,
            selectionPersistence: persistence
        )
        return CalendarSharingTestContext(
            store: store,
            defaults: defaults,
            suiteName: suiteName,
            cacheURL: cacheURL
        )
    }

    private func makeReceivedCalendar(id: String) -> SharedCalendarDescriptor {
        SharedCalendarDescriptor(
            id: id,
            zoneName: "received-zone",
            ownerName: "received-owner",
            displayName: "Owner",
            calendarName: "Calendar",
            participantCount: 1
        )
    }
}

private func makeSharingEvent(
    id: UUID,
    title: String,
    note: String?,
    start: Date,
    end: Date,
    reminderOffsetMinutes: Int? = nil,
    notificationID: String? = nil,
    shiftTemplateID: ShiftTimeTemplateID? = nil,
    workInfo: WorkInfo? = nil
) -> CalendarEvent {
    CalendarEvent(
        id: id,
        title: title,
        note: note,
        startDate: start,
        endDate: end,
        isAllDay: false,
        categoryID: nil,
        recurrenceRule: .none,
        reminderTemplateID: nil,
        reminderOffsetMinutes: reminderOffsetMinutes,
        notificationID: notificationID,
        importSource: nil,
        createdAt: start,
        updatedAt: end,
        shiftTemplateID: shiftTemplateID,
        workInfo: workInfo
    )
}

@MainActor
private final class CalendarSharingClientStub: CalendarSharingClientProtocol {
    var ownedState: OwnedSharedCalendarCloudState?
    var receivedResult: Result<[ReceivedSharedCalendarPayload], Error> = .success([])
    var createError: Error?
    var updateError: Error?
    var createCallCount = 0
    var updateCallCount = 0
    var updatedContent: SharedContentConfiguration?
    var createdDisplayName: String?
    var createdCalendarName: String?
    var createdContent: SharedContentConfiguration?
    var createdSnapshots: [SharedEventSnapshot] = []
    var createdShifts: [SharedShiftSnapshot] = []
    var createdWorkRecords: [SharedWorkRecordSnapshot] = []
    var synchronizedSnapshots: [SharedEventSnapshot] = []
    var synchronizedShifts: [SharedShiftSnapshot] = []
    var synchronizedWorkRecords: [SharedWorkRecordSnapshot] = []
    var suspendReceivedFetch = false

    let createdState = OwnedSharedCalendarCloudState(
        calendar: OwnedSharedCalendarDescriptor(
            displayName: "A",
            calendarName: "B",
            participantCount: 0,
            contentConfiguration: .newShareDefault
        ),
        share: CalendarSharingClientStub.makeShare()
    )

    private var receivedFetchStarted = false
    private var receivedFetchStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var receivedFetchContinuation: CheckedContinuation<Void, Never>?

    func ownedCalendarState() async throws -> OwnedSharedCalendarCloudState? {
        ownedState
    }

    func createShare(
        displayName: String,
        calendarName: String,
        content: SharedContentConfiguration,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws -> OwnedSharedCalendarCloudState {
        createCallCount += 1
        createdDisplayName = displayName
        createdCalendarName = calendarName
        createdContent = content
        createdSnapshots = events
        createdShifts = shifts
        createdWorkRecords = workRecords
        if let createError { throw createError }
        ownedState = createdState
        return createdState
    }

    func ownedShareForPresentation() async throws -> CKShare {
        try XCTUnwrap(ownedState?.share)
    }

    func synchronizeOwnedContent(
        content: SharedContentConfiguration,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws {
        synchronizedSnapshots = events
        synchronizedShifts = shifts
        synchronizedWorkRecords = workRecords
    }

    func updateOwnedSharing(
        content: SharedContentConfiguration,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws -> OwnedSharedCalendarCloudState {
        updateCallCount += 1
        updatedContent = content
        if let updateError { throw updateError }
        synchronizedSnapshots = events
        synchronizedShifts = shifts
        synchronizedWorkRecords = workRecords
        var calendar = createdState.calendar
        calendar.contentConfiguration = content
        let state = OwnedSharedCalendarCloudState(calendar: calendar, share: createdState.share)
        ownedState = state
        return state
    }

    func fetchReceivedCalendars() async throws -> [ReceivedSharedCalendarPayload] {
        receivedFetchStarted = true
        let waiters = receivedFetchStartWaiters
        receivedFetchStartWaiters.removeAll()
        waiters.forEach { $0.resume() }
        if suspendReceivedFetch {
            await withCheckedContinuation { continuation in
                receivedFetchContinuation = continuation
            }
        }
        return try receivedResult.get()
    }

    func accept(metadata: CKShare.Metadata) async throws -> String {
        "accepted-calendar"
    }

    func leaveSharedCalendar(_ calendar: SharedCalendarDescriptor) async throws {}

    func stopOwnedSharing(plan: OwnedSharingStopPlan) async throws {
        ownedState = nil
    }

    func waitUntilReceivedFetchStarts() async {
        guard !receivedFetchStarted else { return }
        await withCheckedContinuation { continuation in
            receivedFetchStartWaiters.append(continuation)
        }
    }

    func resumeReceivedFetch() {
        suspendReceivedFetch = false
        receivedFetchContinuation?.resume()
        receivedFetchContinuation = nil
    }

    static func makeShare() -> CKShare {
        CKShare(recordZoneID: CKRecordZone.ID(
            zoneName: "CalendarSharingTests",
            ownerName: CKCurrentUserDefaultName
        ))
    }
}

@MainActor
private struct CalendarSharingTestContext {
    let store: CalendarSharingStore
    let defaults: UserDefaults
    let suiteName: String
    let cacheURL: URL

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: cacheURL)
    }
}
