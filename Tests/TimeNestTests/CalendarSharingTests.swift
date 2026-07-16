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

    func testOrdinaryEventIsClassifiedOnlyAsSharedEvent() throws {
        let event = makeEvent(title: "Appointment")

        XCTAssertNotNil(SharedEventMapper.snapshot(from: event))
        XCTAssertNil(SharedShiftMapper.snapshot(from: event))
        XCTAssertTrue(SharedWorkRecordMapper.snapshots(from: [event]).isEmpty)
    }

    func testTwoOrdinaryEventsProduceTwoSharedEventSnapshots() {
        let events = [
            makeEvent(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                title: "Appointment A"
            ),
            makeEvent(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                title: "Appointment B"
            )
        ]

        XCTAssertEqual(events.compactMap(SharedEventMapper.snapshot(from:)).count, 2)
    }

    func testCompleteWorkRecordDoesNotProduceSharedEventSnapshots() {
        let sessionID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        let start = Date(timeIntervalSince1970: 1_767_225_600)
        let clockIn = makeEvent(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
            title: "Work record",
            workInfo: WorkInfo(
                workInTime: start,
                workDate: start,
                workSessionId: sessionID,
                isWorkOutTimeSet: true
            )
        )
        let clockOut = makeEvent(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000003")!,
            title: "Work record",
            workInfo: WorkInfo(
                workOutTime: start.addingTimeInterval(28_800),
                workDate: start,
                workSessionId: sessionID,
                isWorkOutTimeSet: true
            )
        )

        XCTAssertNil(SharedEventMapper.snapshot(from: clockIn))
        XCTAssertNil(SharedEventMapper.snapshot(from: clockOut))
        XCTAssertTrue(SharedWorkRecordMapper.isCandidate(clockIn))
        XCTAssertTrue(SharedWorkRecordMapper.isCandidate(clockOut))
        XCTAssertEqual(SharedWorkRecordMapper.snapshots(from: [clockIn, clockOut]).count, 1)
    }

    func testInconsistentWorkInfoHasExplicitExclusionAndIsNotAWorkRecordCandidate() {
        let start = Date(timeIntervalSince1970: 1_767_225_600)
        let event = makeEvent(
            title: "Appointment",
            workInfo: WorkInfo(
                workInTime: start,
                workOutTime: start.addingTimeInterval(3_600),
                workDate: start,
                workSessionId: UUID()
            )
        )

        XCTAssertNil(event.workClockKind)
        XCTAssertEqual(SharedEventMapper.exclusionReason(for: event), .inconsistentWorkInfo)
        XCTAssertNil(SharedEventMapper.snapshot(from: event))
        XCTAssertFalse(SharedWorkRecordMapper.isCandidate(event))
    }

    private func makeEvent(
        id: UUID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
        title: String,
        note: String? = nil,
        reminderOffsetMinutes: Int? = nil,
        notificationID: String? = nil,
        shiftTemplateID: ShiftTimeTemplateID? = nil,
        workInfo: WorkInfo? = nil
    ) -> CalendarEvent {
        let start = Date(timeIntervalSince1970: 1_767_225_600)
        return CalendarEvent(
            id: id,
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
    func testOneTimeInvitationAddsUniqueReadOnlyPrivateParticipants() {
        let share = CalendarSharingCloudRecordFactory.makeZoneWideShare(
            recordZoneID: CKRecordZone.ID(
                zoneName: CalendarSharingCloudSchema.zoneName,
                ownerName: CKCurrentUserDefaultName
            )
        )

        let first = OneTimeSharingInvitation.prepare(on: share)
        let second = OneTimeSharingInvitation.prepare(on: share)
        let invitees = share.participants.filter { $0.role != .owner }

        XCTAssertEqual(share.publicPermission, .none)
        XCTAssertEqual(invitees.count, 2)
        XCTAssertTrue(invitees.allSatisfy { $0.permission == .readOnly })
        XCTAssertNotEqual(first.participantID, second.participantID)
        XCTAssertNil(first.url(in: share))
        XCTAssertNil(second.url(in: share))
    }

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

    func testFactoryReplacesLegacyInstancesAndPreservesIdentityZoneTypeAndUpdatedFields() throws {
        let zoneID = CKRecordZone.ID(
            zoneName: CalendarSharingCloudSchema.zoneName,
            ownerName: CKCurrentUserDefaultName
        )
        let firstTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let secondTimestamp = firstTimestamp.addingTimeInterval(3_600)
        let eventID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let shiftID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let workID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let eventRecordID = CKRecord.ID(recordName: "event-test", zoneID: zoneID)
        let shiftRecordID = CKRecord.ID(recordName: "shift-test", zoneID: zoneID)
        let workRecordID = CKRecord.ID(recordName: "work-test", zoneID: zoneID)

        let existingEvent = CalendarSharingCloudRecordFactory.makeEventRecord(
            snapshot: SharedEventSnapshot(
                id: eventID,
                title: "First event",
                startDate: firstTimestamp,
                endDate: firstTimestamp.addingTimeInterval(1_800),
                isAllDay: false,
                updatedAt: firstTimestamp
            ),
            recordID: eventRecordID
        )
        let existingShift = CalendarSharingCloudRecordFactory.makeShiftRecord(
            snapshot: SharedShiftSnapshot(
                id: shiftID,
                registeredDate: firstTimestamp,
                displayName: "First shift",
                startDate: firstTimestamp,
                endDate: firstTimestamp.addingTimeInterval(1_800),
                spansMidnight: false,
                colorHex: "#111111",
                updatedAt: firstTimestamp
            ),
            recordID: shiftRecordID
        )
        let existingWork = CalendarSharingCloudRecordFactory.makeWorkRecord(
            snapshot: SharedWorkRecordSnapshot(
                id: workID,
                workDate: firstTimestamp,
                workInTime: firstTimestamp,
                workOutTime: nil,
                isWorkOutTimeSet: false,
                restHours: 0,
                updatedAt: firstTimestamp
            ),
            recordID: workRecordID
        )
        let legacyParent = CKRecord.Reference(
            recordID: CKRecord.ID(
                recordName: CalendarSharingCloudSchema.calendarRecordName,
                zoneID: zoneID
            ),
            action: .none
        )
        [existingEvent, existingShift, existingWork].forEach { $0.parent = legacyParent }

        let updatedEvent = CalendarSharingCloudRecordFactory.makeEventRecord(
            snapshot: SharedEventSnapshot(
                id: eventID,
                title: "Updated event",
                startDate: secondTimestamp,
                endDate: secondTimestamp.addingTimeInterval(7_200),
                isAllDay: true,
                updatedAt: secondTimestamp
            ),
            recordID: eventRecordID,
            existingRecord: existingEvent
        )
        let updatedShift = CalendarSharingCloudRecordFactory.makeShiftRecord(
            snapshot: SharedShiftSnapshot(
                id: shiftID,
                registeredDate: secondTimestamp,
                displayName: "Updated shift",
                startDate: secondTimestamp,
                endDate: secondTimestamp.addingTimeInterval(7_200),
                spansMidnight: true,
                colorHex: "#ABCDEF",
                updatedAt: secondTimestamp
            ),
            recordID: shiftRecordID,
            existingRecord: existingShift
        )
        let updatedWork = CalendarSharingCloudRecordFactory.makeWorkRecord(
            snapshot: SharedWorkRecordSnapshot(
                id: workID,
                workDate: secondTimestamp,
                workInTime: secondTimestamp,
                workOutTime: secondTimestamp.addingTimeInterval(7_200),
                isWorkOutTimeSet: true,
                restHours: 1.25,
                updatedAt: secondTimestamp
            ),
            recordID: workRecordID,
            existingRecord: existingWork
        )

        XCTAssertFalse(updatedEvent === existingEvent)
        XCTAssertFalse(updatedShift === existingShift)
        XCTAssertFalse(updatedWork === existingWork)
        for (record, expectedID, expectedType) in [
            (updatedEvent, eventRecordID, CalendarSharingCloudSchema.eventRecordType),
            (updatedShift, shiftRecordID, CalendarSharingCloudSchema.shiftRecordType),
            (updatedWork, workRecordID, CalendarSharingCloudSchema.workRecordType)
        ] {
            XCTAssertNil(record.parent)
            XCTAssertEqual(record.recordID, expectedID)
            XCTAssertEqual(record.recordID.zoneID, zoneID)
            XCTAssertEqual(record.recordType, expectedType)
        }
        XCTAssertEqual(
            updatedEvent[CalendarSharingCloudSchema.EventField.eventID] as? String,
            eventID.uuidString
        )
        XCTAssertEqual(
            updatedEvent[CalendarSharingCloudSchema.EventField.title] as? String,
            "Updated event"
        )
        XCTAssertEqual(
            updatedEvent[CalendarSharingCloudSchema.EventField.startDate] as? Date,
            secondTimestamp
        )
        XCTAssertEqual(
            (updatedEvent[CalendarSharingCloudSchema.EventField.isAllDay] as? NSNumber)?.boolValue,
            true
        )
        XCTAssertEqual(
            updatedShift[CalendarSharingCloudSchema.ShiftField.shiftID] as? String,
            shiftID.uuidString
        )
        XCTAssertEqual(
            updatedShift[CalendarSharingCloudSchema.ShiftField.displayName] as? String,
            "Updated shift"
        )
        XCTAssertEqual(
            updatedShift[CalendarSharingCloudSchema.ShiftField.colorHex] as? String,
            "#ABCDEF"
        )
        XCTAssertEqual(
            (updatedShift[CalendarSharingCloudSchema.ShiftField.spansMidnight] as? NSNumber)?.boolValue,
            true
        )
        XCTAssertEqual(
            updatedWork[CalendarSharingCloudSchema.WorkRecordField.workRecordID] as? String,
            workID.uuidString
        )
        XCTAssertEqual(
            updatedWork[CalendarSharingCloudSchema.WorkRecordField.workOutTime] as? Date,
            secondTimestamp.addingTimeInterval(7_200)
        )
        XCTAssertEqual(
            (updatedWork[CalendarSharingCloudSchema.WorkRecordField.isWorkOutTimeSet] as? NSNumber)?.boolValue,
            true
        )
        XCTAssertEqual(
            (updatedWork[CalendarSharingCloudSchema.WorkRecordField.restHours] as? NSNumber)?.doubleValue,
            1.25
        )
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

final class OwnedCalendarParticipantSnapshotAssemblerTests: XCTestCase {
    func testOwnerPendingAndRemovedParticipantsAreExcluded() {
        XCTAssertNil(makeSnapshot(role: .owner, status: .accepted))
        XCTAssertNil(makeSnapshot(role: .privateUser, status: .pending))
        XCTAssertNil(makeSnapshot(role: .privateUser, status: .removed))
        XCTAssertNil(makeSnapshot(role: .privateUser, status: .unknown))
    }

    func testAcceptedParticipantPrefersFormattedName() throws {
        var name = PersonNameComponents()
        name.givenName = "A"
        name.familyName = "Participant"

        let snapshot = try XCTUnwrap(makeSnapshot(
            status: .accepted,
            nameComponents: name,
            emailAddress: "fallback@example.com"
        ))

        XCTAssertTrue(try XCTUnwrap(snapshot.displayName).contains("A"))
        XCTAssertFalse(try XCTUnwrap(snapshot.displayName).contains("@"))
        XCTAssertTrue(snapshot.isAccepted)
        XCTAssertEqual(snapshot.permission, .readOnly)
    }

    func testAcceptedParticipantUsesEmailWhenNameIsUnavailable() throws {
        let snapshot = try XCTUnwrap(makeSnapshot(
            status: .accepted,
            emailAddress: "participant@example.com"
        ))

        XCTAssertEqual(snapshot.displayName, "participant@example.com")
    }

    func testAcceptedParticipantUsesLocalizedFallbackWhenIdentityIsUnavailable() throws {
        let snapshot = try XCTUnwrap(makeSnapshot(status: .accepted))

        XCTAssertNil(snapshot.displayName)
        XCTAssertEqual(snapshot.resolvedDisplayName(fallback: "Participant"), "Participant")
    }

    func testParticipantSnapshotUsesStableAnonymizedIdentifier() throws {
        let first = try XCTUnwrap(makeSnapshot(status: .accepted, participantID: "participant-source-id"))
        let second = try XCTUnwrap(makeSnapshot(status: .accepted, participantID: "participant-source-id"))

        XCTAssertEqual(first.id, second.id)
        XCTAssertNotEqual(first.id, "participant-source-id")
    }

    func testPendingOneTimeParticipantIsCountedButNotDisplayed() {
        let share = CalendarSharingCloudRecordFactory.makeZoneWideShare(
            recordZoneID: CKRecordZone.ID(
                zoneName: CalendarSharingCloudSchema.zoneName,
                ownerName: CKCurrentUserDefaultName
            )
        )
        _ = OneTimeSharingInvitation.prepare(on: share)

        let summary = OwnedCalendarParticipantSnapshotAssembler.make(from: share)

        XCTAssertEqual(summary.pendingCount, 1)
        XCTAssertTrue(summary.snapshots.isEmpty)
        XCTAssertEqual(summary.acceptedCount, 0)
    }

    private func makeSnapshot(
        role: CKShare.ParticipantRole = .privateUser,
        status: CKShare.ParticipantAcceptanceStatus,
        permission: CKShare.ParticipantPermission = .readOnly,
        nameComponents: PersonNameComponents? = nil,
        emailAddress: String? = nil,
        participantID: CKShare.Participant.ID = "test-participant-id"
    ) -> SharedCalendarParticipantSnapshot? {
        OwnedCalendarParticipantSnapshotAssembler.makeSnapshot(
            participantID: participantID,
            role: role,
            acceptanceStatus: status,
            permission: permission,
            nameComponents: nameComponents,
            emailAddress: emailAddress
        )
    }
}

@MainActor
final class CalendarSharingContentRecordMigrationTests: XCTestCase {
    func testLegacySharedEventEntersDeleteAndFreshRecreatePlan() throws {
        try assertLegacyPlan(for: .event)
    }

    func testLegacySharedShiftEntersDeleteAndFreshRecreatePlan() throws {
        try assertLegacyPlan(for: .shift)
    }

    func testLegacySharedWorkRecordEntersDeleteAndFreshRecreatePlan() throws {
        try assertLegacyPlan(for: .workRecord)
    }

    func testLegacyRecordMissingFromSnapshotIsDeletedWithoutRecreation() {
        for kind in ContentKind.allCases {
            let legacy = makeExistingRecord(kind, hasParent: true)
            let plan = makePlan(kind, existingRecords: [legacy], snapshotCopies: 0)

            XCTAssertEqual(plan.legacyRecordIDsToDelete, [legacy.recordID])
            XCTAssertTrue(plan.recordsToRecreate.isEmpty)
            XCTAssertTrue(plan.recordsToSave.isEmpty)
            XCTAssertTrue(plan.ordinaryRecordIDsToDelete.isEmpty)
        }
    }

    func testOrdinaryExistingRecordsAreReusedWithoutMigrationAndFieldsAreUpdated() throws {
        for kind in ContentKind.allCases {
            let existing = makeExistingRecord(kind, hasParent: false)
            let plan = makePlan(kind, existingRecords: [existing])
            let saved = try XCTUnwrap(plan.recordsToSave.first)

            XCTAssertTrue(saved === existing)
            XCTAssertTrue(plan.legacyRecordIDsToDelete.isEmpty)
            XCTAssertTrue(plan.recordsToRecreate.isEmpty)
            XCTAssertTrue(plan.ordinaryRecordIDsToDelete.isEmpty)
            XCTAssertEqual(saved.recordID, recordID(for: kind))
            XCTAssertEqual(saved.recordID.zoneID, zoneID)
            XCTAssertEqual(saved.recordType, kind.recordType)
            XCTAssertNil(saved.parent)
            assertUpdatedField(on: saved, kind: kind)
        }
    }

    func testOrdinaryRecordMissingFromSnapshotUsesNormalDeleteOnly() {
        for kind in ContentKind.allCases {
            let existing = makeExistingRecord(kind, hasParent: false)
            let plan = makePlan(kind, existingRecords: [existing], snapshotCopies: 0)

            XCTAssertTrue(plan.legacyRecordIDsToDelete.isEmpty)
            XCTAssertTrue(plan.recordsToRecreate.isEmpty)
            XCTAssertTrue(plan.recordsToSave.isEmpty)
            XCTAssertEqual(plan.ordinaryRecordIDsToDelete, [existing.recordID])
        }
    }

    func testDuplicateSnapshotIDsProduceOnlyOneRecord() {
        for kind in ContentKind.allCases {
            let plan = makePlan(kind, existingRecords: [], snapshotCopies: 2)
            let allRecordIDs = (plan.recordsToRecreate + plan.recordsToSave).map(\.recordID)

            XCTAssertEqual(allRecordIDs.count, 1)
            XCTAssertEqual(Set(allRecordIDs).count, 1)
        }
    }

    func testTwoRoundMigrationOrderAndIdempotencyForAllContentTypes() async throws {
        for kind in ContentKind.allCases {
            let legacy = makeExistingRecord(kind, hasParent: true)
            let firstPlan = makePlan(kind, existingRecords: [legacy])
            let firstDatabase = FakeContentRecordDatabase()

            try await CalendarSharingContentRecordPlanExecutor(database: firstDatabase).execute(
                firstPlan,
                migrationStageName: kind.stageName
            )

            XCTAssertEqual(firstDatabase.calls, [
                .delete([kind.recordName]),
                .save([kind.recordName])
            ])
            let recreated = try XCTUnwrap(firstPlan.recordsToRecreate.first)
            let secondPlan = makePlan(kind, existingRecords: [recreated])
            let secondDatabase = FakeContentRecordDatabase()

            try await CalendarSharingContentRecordPlanExecutor(database: secondDatabase).execute(
                secondPlan,
                migrationStageName: kind.stageName
            )

            XCTAssertTrue(secondPlan.legacyRecordIDsToDelete.isEmpty)
            XCTAssertTrue(secondPlan.recordsToRecreate.isEmpty)
            XCTAssertEqual(secondDatabase.calls, [.save([kind.recordName])])
        }
    }

    func testDeleteFailurePreventsRecreation() async {
        let kind = ContentKind.shift
        let legacy = makeExistingRecord(kind, hasParent: true)
        let plan = makePlan(kind, existingRecords: [legacy])
        let database = FakeContentRecordDatabase()
        database.failDeleteCall = 1

        do {
            try await CalendarSharingContentRecordPlanExecutor(database: database).execute(
                plan,
                migrationStageName: kind.stageName
            )
            XCTFail("Expected the injected delete failure")
        } catch {
            XCTAssertEqual(database.calls, [.delete([kind.recordName])])
            XCTAssertFalse(database.calls.contains(.save([kind.recordName])))
        }
    }

    func testRecreateFailureCanRetryAsNewNoParentRecord() async throws {
        let kind = ContentKind.workRecord
        let legacy = makeExistingRecord(kind, hasParent: true)
        let firstPlan = makePlan(kind, existingRecords: [legacy])
        let firstDatabase = FakeContentRecordDatabase()
        firstDatabase.failSaveCall = 1

        do {
            try await CalendarSharingContentRecordPlanExecutor(database: firstDatabase).execute(
                firstPlan,
                migrationStageName: kind.stageName
            )
            XCTFail("Expected the injected recreate failure")
        } catch {
            XCTAssertEqual(firstDatabase.calls, [
                .delete([kind.recordName]),
                .save([kind.recordName])
            ])
        }

        let retryPlan = makePlan(kind, existingRecords: [])
        let retryDatabase = FakeContentRecordDatabase()
        try await CalendarSharingContentRecordPlanExecutor(database: retryDatabase).execute(
            retryPlan,
            migrationStageName: kind.stageName
        )

        XCTAssertTrue(retryPlan.legacyRecordIDsToDelete.isEmpty)
        XCTAssertTrue(retryPlan.recordsToRecreate.isEmpty)
        XCTAssertEqual(retryPlan.recordsToSave.count, 1)
        XCTAssertNil(retryPlan.recordsToSave.first?.parent)
        XCTAssertEqual(retryDatabase.calls, [.save([kind.recordName])])
    }

    private func assertLegacyPlan(for kind: ContentKind) throws {
        let legacy = makeExistingRecord(kind, hasParent: true)
        let plan = makePlan(kind, existingRecords: [legacy])
        let recreated = try XCTUnwrap(plan.recordsToRecreate.first)

        XCTAssertEqual(plan.legacyRecordIDsToDelete, [legacy.recordID])
        XCTAssertTrue(plan.recordsToSave.isEmpty)
        XCTAssertTrue(plan.ordinaryRecordIDsToDelete.isEmpty)
        XCTAssertFalse(recreated === legacy)
        XCTAssertNil(recreated.parent)
        XCTAssertEqual(recreated.recordID, legacy.recordID)
        XCTAssertEqual(recreated.recordID.zoneID, zoneID)
        XCTAssertEqual(recreated.recordType, kind.recordType)
        assertUpdatedField(on: recreated, kind: kind)
    }

    private func makePlan(
        _ kind: ContentKind,
        existingRecords: [CKRecord],
        snapshotCopies: Int = 1
    ) -> CalendarSharingContentRecordPlan {
        switch kind {
        case .event:
            let snapshots = Array(repeating: updatedEventSnapshot, count: snapshotCopies)
            return CalendarSharingContentRecordPlan(
                recordType: kind.recordType,
                existingRecords: existingRecords,
                snapshots: snapshots,
                recordID: { _ in self.recordID(for: kind) },
                makeRecord: { snapshot, recordID, existingRecord in
                    CalendarSharingCloudRecordFactory.makeEventRecord(
                        snapshot: snapshot,
                        recordID: recordID,
                        existingRecord: existingRecord
                    )
                }
            )
        case .shift:
            let snapshots = Array(repeating: updatedShiftSnapshot, count: snapshotCopies)
            return CalendarSharingContentRecordPlan(
                recordType: kind.recordType,
                existingRecords: existingRecords,
                snapshots: snapshots,
                recordID: { _ in self.recordID(for: kind) },
                makeRecord: { snapshot, recordID, existingRecord in
                    CalendarSharingCloudRecordFactory.makeShiftRecord(
                        snapshot: snapshot,
                        recordID: recordID,
                        existingRecord: existingRecord
                    )
                }
            )
        case .workRecord:
            let snapshots = Array(repeating: updatedWorkRecordSnapshot, count: snapshotCopies)
            return CalendarSharingContentRecordPlan(
                recordType: kind.recordType,
                existingRecords: existingRecords,
                snapshots: snapshots,
                recordID: { _ in self.recordID(for: kind) },
                makeRecord: { snapshot, recordID, existingRecord in
                    CalendarSharingCloudRecordFactory.makeWorkRecord(
                        snapshot: snapshot,
                        recordID: recordID,
                        existingRecord: existingRecord
                    )
                }
            )
        }
    }

    private func makeExistingRecord(_ kind: ContentKind, hasParent: Bool) -> CKRecord {
        let record: CKRecord
        switch kind {
        case .event:
            record = CalendarSharingCloudRecordFactory.makeEventRecord(
                snapshot: originalEventSnapshot,
                recordID: recordID(for: kind)
            )
        case .shift:
            record = CalendarSharingCloudRecordFactory.makeShiftRecord(
                snapshot: originalShiftSnapshot,
                recordID: recordID(for: kind)
            )
        case .workRecord:
            record = CalendarSharingCloudRecordFactory.makeWorkRecord(
                snapshot: originalWorkRecordSnapshot,
                recordID: recordID(for: kind)
            )
        }
        if hasParent {
            record.parent = CKRecord.Reference(
                recordID: CKRecord.ID(
                    recordName: CalendarSharingCloudSchema.calendarRecordName,
                    zoneID: zoneID
                ),
                action: .none
            )
        }
        return record
    }

    private func assertUpdatedField(on record: CKRecord, kind: ContentKind) {
        switch kind {
        case .event:
            XCTAssertEqual(
                record[CalendarSharingCloudSchema.EventField.title] as? String,
                updatedEventSnapshot.title
            )
        case .shift:
            XCTAssertEqual(
                record[CalendarSharingCloudSchema.ShiftField.displayName] as? String,
                updatedShiftSnapshot.displayName
            )
        case .workRecord:
            XCTAssertEqual(
                (record[CalendarSharingCloudSchema.WorkRecordField.restHours] as? NSNumber)?.doubleValue,
                updatedWorkRecordSnapshot.restHours
            )
        }
    }

    private func recordID(for kind: ContentKind) -> CKRecord.ID {
        CKRecord.ID(recordName: kind.recordName, zoneID: zoneID)
    }

    private enum ContentKind: CaseIterable {
        case event
        case shift
        case workRecord

        var recordName: String {
            switch self {
            case .event: "event-test"
            case .shift: "shift-test"
            case .workRecord: "work-test"
            }
        }

        var recordType: CKRecord.RecordType {
            switch self {
            case .event: CalendarSharingCloudSchema.eventRecordType
            case .shift: CalendarSharingCloudSchema.shiftRecordType
            case .workRecord: CalendarSharingCloudSchema.workRecordType
            }
        }

        var stageName: String {
            switch self {
            case .event: "events"
            case .shift: "shifts"
            case .workRecord: "work_records"
            }
        }
    }

    private let zoneID = CKRecordZone.ID(
        zoneName: CalendarSharingCloudSchema.zoneName,
        ownerName: CKCurrentUserDefaultName
    )
    private let originalTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
    private let updatedTimestamp = Date(timeIntervalSince1970: 1_700_003_600)

    private var originalEventSnapshot: SharedEventSnapshot {
        SharedEventSnapshot(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Original event",
            startDate: originalTimestamp,
            endDate: originalTimestamp.addingTimeInterval(1_800),
            isAllDay: false,
            updatedAt: originalTimestamp
        )
    }

    private var updatedEventSnapshot: SharedEventSnapshot {
        SharedEventSnapshot(
            id: originalEventSnapshot.id,
            title: "Updated event",
            startDate: updatedTimestamp,
            endDate: updatedTimestamp.addingTimeInterval(3_600),
            isAllDay: true,
            updatedAt: updatedTimestamp
        )
    }

    private var originalShiftSnapshot: SharedShiftSnapshot {
        SharedShiftSnapshot(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            registeredDate: originalTimestamp,
            displayName: "Original shift",
            startDate: originalTimestamp,
            endDate: originalTimestamp.addingTimeInterval(1_800),
            spansMidnight: false,
            colorHex: "#111111",
            updatedAt: originalTimestamp
        )
    }

    private var updatedShiftSnapshot: SharedShiftSnapshot {
        SharedShiftSnapshot(
            id: originalShiftSnapshot.id,
            registeredDate: updatedTimestamp,
            displayName: "Updated shift",
            startDate: updatedTimestamp,
            endDate: updatedTimestamp.addingTimeInterval(3_600),
            spansMidnight: true,
            colorHex: "#ABCDEF",
            updatedAt: updatedTimestamp
        )
    }

    private var originalWorkRecordSnapshot: SharedWorkRecordSnapshot {
        SharedWorkRecordSnapshot(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            workDate: originalTimestamp,
            workInTime: originalTimestamp,
            workOutTime: nil,
            isWorkOutTimeSet: false,
            restHours: 0,
            updatedAt: originalTimestamp
        )
    }

    private var updatedWorkRecordSnapshot: SharedWorkRecordSnapshot {
        SharedWorkRecordSnapshot(
            id: originalWorkRecordSnapshot.id,
            workDate: updatedTimestamp,
            workInTime: updatedTimestamp,
            workOutTime: updatedTimestamp.addingTimeInterval(3_600),
            isWorkOutTimeSet: true,
            restHours: 1.25,
            updatedAt: updatedTimestamp
        )
    }
}

@MainActor
private final class FakeContentRecordDatabase: CalendarSharingContentRecordDatabase {
    enum Call: Equatable {
        case save([String])
        case delete([String])
    }

    var calls: [Call] = []
    var failSaveCall: Int?
    var failDeleteCall: Int?
    private var saveCallCount = 0
    private var deleteCallCount = 0

    func save(_ records: [CKRecord]) async throws {
        saveCallCount += 1
        calls.append(.save(records.map(\.recordID.recordName)))
        if saveCallCount == failSaveCall {
            throw CKError(.networkFailure)
        }
    }

    func delete(_ recordIDs: [CKRecord.ID]) async throws {
        deleteCallCount += 1
        calls.append(.delete(recordIDs.map(\.recordName)))
        if deleteCallCount == failDeleteCall {
            throw CKError(.networkFailure)
        }
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

    func testFirstShareAllowsOneCharacterNamesAndPreparesActivitySheet() async throws {
        let client = CalendarSharingClientStub()
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }

        let invitationURL = try await context.store.createShare(displayName: "A", calendarName: "B")

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
        XCTAssertEqual(invitationURL, client.createdInvitationURL)

        var presentation = SharingManagementPresentationState()
        presentation.showAlert(.message("stale"))
        presentation.present(invitationURL: invitationURL)
        XCTAssertEqual(presentation.presentedInvitation?.url, invitationURL)
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

    func testFirstShareMissingInvitationURLKeepsSavedShareState() async throws {
        let client = CalendarSharingClientStub()
        client.createdInvitationURL = nil
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }

        do {
            _ = try await context.store.createShare(calendarName: "Shared calendar")
            XCTFail("Expected the missing invitation URL to be reported")
        } catch let error as CalendarSharingError {
            XCTAssertEqual(error, .invitationURLUnavailable)
        }

        XCTAssertEqual(client.createCallCount, 1)
        XCTAssertEqual(context.store.ownedCalendar, client.createdState.calendar)
        XCTAssertEqual(context.store.lastError, .invitationURLUnavailable)
    }

    func testAddPeopleReusesExistingShareAndReturnsANewInvitationForEachTap() async throws {
        let client = CalendarSharingClientStub()
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }
        _ = try await context.store.createShare(calendarName: "Shared calendar")

        client.additionalInvitationURL = URL(string: "https://example.com/invite/additional-1")!
        let first = try await context.store.createOwnedInvitation()
        client.additionalInvitationURL = URL(string: "https://example.com/invite/additional-2")!
        let second = try await context.store.createOwnedInvitation()

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(client.createCallCount, 1)
        XCTAssertEqual(client.invitationCallCount, 2)
        XCTAssertEqual(context.store.ownedCalendar?.participantCount, 0)
    }

    func testAddPeopleSaveFailurePreservesExistingShare() async throws {
        let client = CalendarSharingClientStub()
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }
        _ = try await context.store.createShare(calendarName: "Shared calendar")
        client.invitationError = CKError(.unknownItem)

        do {
            _ = try await context.store.createOwnedInvitation()
            XCTFail("Expected invitation creation to fail")
        } catch let error as CalendarSharingError {
            XCTAssertEqual(error, .invitationCreationFailed)
        }

        XCTAssertEqual(client.createCallCount, 1)
        XCTAssertEqual(client.invitationCallCount, 1)
        XCTAssertEqual(context.store.ownedCalendar, client.createdState.calendar)
    }

    func testAddPeopleMissingInvitationURLPreservesExistingShare() async throws {
        let client = CalendarSharingClientStub()
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }
        _ = try await context.store.createShare(calendarName: "Shared calendar")
        client.additionalInvitationURL = nil

        do {
            _ = try await context.store.createOwnedInvitation()
            XCTFail("Expected the missing invitation URL to be reported")
        } catch let error as CalendarSharingError {
            XCTAssertEqual(error, .invitationURLUnavailable)
        }

        XCTAssertEqual(client.createCallCount, 1)
        XCTAssertEqual(context.store.ownedCalendar?.participantCount, 0)
    }

    func testConcurrentAddPeopleRequestsUseSingleInvitationMutation() async throws {
        let client = CalendarSharingClientStub()
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }
        _ = try await context.store.createShare(calendarName: "Shared calendar")
        client.suspendInvitationCreation = true

        let firstTask = Task { try await context.store.createOwnedInvitation() }
        await client.waitUntilInvitationCreationStarts()

        do {
            _ = try await context.store.createOwnedInvitation()
            XCTFail("Expected the concurrent request to be rejected")
        } catch let error as CalendarSharingError {
            XCTAssertEqual(error, .invitationCreationFailed)
        }

        client.resumeInvitationCreation()
        _ = try await firstTask.value
        XCTAssertEqual(client.createCallCount, 1)
        XCTAssertEqual(client.invitationCallCount, 1)
    }

    func testConcurrentStartSharingRequestsUseSingleShareMutation() async throws {
        let client = CalendarSharingClientStub()
        client.suspendShareCreation = true
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }

        let firstTask = Task {
            try await context.store.createShare(calendarName: "Shared calendar")
        }
        await client.waitUntilShareCreationStarts()

        do {
            _ = try await context.store.createShare(calendarName: "Shared calendar")
            XCTFail("Expected the concurrent request to be rejected")
        } catch let error as CalendarSharingError {
            XCTAssertEqual(error, .shareCreationFailed)
        }

        client.resumeShareCreation()
        _ = try await firstTask.value
        XCTAssertEqual(client.createCallCount, 1)
    }

    @MainActor
    func testTwoOrdinaryEventSavesClearInconsistentWorkInfoAndShareTwoEvents() async throws {
        let repository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(repository: repository)
        let client = CalendarSharingClientStub()
        let context = try makeStore(
            client: client,
            selection: .mine,
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
        let firstStart = Date(timeIntervalSince1970: 1_768_000_000)
        let firstEnd = firstStart.addingTimeInterval(3_600)
        let inconsistentWorkInfo = WorkInfo(
            workInTime: firstStart,
            workOutTime: firstEnd,
            workDate: firstStart,
            workSessionId: UUID()
        )

        _ = try await viewModel.createEvent(
            title: "Appointment A",
            note: nil,
            startDate: firstStart,
            endDate: firstEnd,
            isAllDay: false,
            reminderOffsetMinutes: nil,
            shiftTemplateID: nil,
            workInfo: inconsistentWorkInfo
        )
        _ = try await viewModel.createEvent(
            title: "Appointment B",
            note: nil,
            startDate: firstStart.addingTimeInterval(7_200),
            endDate: firstEnd.addingTimeInterval(7_200),
            isAllDay: false,
            reminderOffsetMinutes: nil,
            shiftTemplateID: nil,
            workInfo: nil
        )

        let eventsBeforeUpdate = try await repository.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        let firstSavedEvent = try XCTUnwrap(
            eventsBeforeUpdate.first { $0.title == "Appointment A" }
        )
        _ = try await viewModel.updateEvent(
            id: firstSavedEvent.id,
            title: firstSavedEvent.title,
            note: firstSavedEvent.note,
            startDate: firstSavedEvent.startDate,
            endDate: firstSavedEvent.endDate,
            isAllDay: firstSavedEvent.isAllDay,
            reminderOffsetMinutes: firstSavedEvent.reminderOffsetMinutes,
            shiftTemplateID: nil,
            workInfo: inconsistentWorkInfo
        )

        let savedEvents = try await repository.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        XCTAssertEqual(savedEvents.count, 2)
        XCTAssertTrue(savedEvents.allSatisfy { $0.shiftTemplateID == nil })
        XCTAssertTrue(savedEvents.allSatisfy { $0.workInfo == nil })
        XCTAssertTrue(savedEvents.allSatisfy { $0.workClockKind == nil })

        _ = try await context.store.createShare(calendarName: "Shared calendar")

        XCTAssertEqual(client.createdSnapshots.count, 2)
        XCTAssertTrue(client.createdShifts.isEmpty)
        XCTAssertTrue(client.createdWorkRecords.isEmpty)
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

    func testParticipantRefreshPreservesExistingListWhenFetchFails() async throws {
        let client = CalendarSharingClientStub()
        let participant = makeParticipant(displayName: "Accepted participant")
        client.ownedState = makeOwnedState(participants: [participant])
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }

        await context.store.refreshOwnedParticipants()
        client.ownedStateError = CalendarSharingError.networkUnavailable
        await context.store.refreshOwnedParticipants()

        XCTAssertEqual(context.store.ownedParticipants, [participant])
        XCTAssertTrue(context.store.participantRefreshFailed)
    }

    func testParticipantRefreshShowsNewAcceptedParticipantAfterNextFetch() async throws {
        let client = CalendarSharingClientStub()
        client.ownedState = makeOwnedState(participants: [])
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }

        await context.store.refreshOwnedParticipants()
        XCTAssertTrue(context.store.ownedParticipants.isEmpty)

        let participant = makeParticipant(displayName: "New participant")
        client.ownedState = makeOwnedState(participants: [participant])
        await context.store.refreshOwnedParticipants()

        XCTAssertEqual(context.store.ownedParticipants, [participant])
        XCTAssertEqual(context.store.ownedCalendar?.participantCount, 1)
    }

    func testParticipantRefreshOnlyFetchesOwnedStateWithoutCreatingOrUploading() async throws {
        let client = CalendarSharingClientStub()
        client.ownedState = makeOwnedState(participants: [makeParticipant(displayName: nil)])
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }

        await context.store.refreshOwnedParticipants()

        XCTAssertEqual(client.ownedStateCallCount, 1)
        XCTAssertEqual(client.createCallCount, 0)
        XCTAssertEqual(client.invitationCallCount, 0)
        XCTAssertEqual(client.updateCallCount, 0)
        XCTAssertTrue(client.synchronizedSnapshots.isEmpty)
        XCTAssertTrue(client.synchronizedShifts.isEmpty)
        XCTAssertTrue(client.synchronizedWorkRecords.isEmpty)
    }

    func testAppActivationWhileParticipantManagementIsActiveUsesLightweightRefresh() async throws {
        let client = CalendarSharingClientStub()
        client.ownedState = makeOwnedState(participants: [makeParticipant(displayName: nil)])
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }
        context.store.setParticipantManagementActive(true)

        await context.store.synchronizeOnAppActivation()

        XCTAssertEqual(client.ownedStateCallCount, 1)
        XCTAssertEqual(client.createCallCount, 0)
        XCTAssertEqual(client.updateCallCount, 0)
        XCTAssertTrue(client.synchronizedSnapshots.isEmpty)
        XCTAssertTrue(client.synchronizedShifts.isEmpty)
        XCTAssertTrue(client.synchronizedWorkRecords.isEmpty)
    }

    func testConcurrentParticipantRefreshesUseSingleOwnedStateFetch() async throws {
        let client = CalendarSharingClientStub()
        client.ownedState = makeOwnedState(participants: [])
        client.suspendOwnedStateFetch = true
        let context = try makeStore(client: client, selection: .mine)
        defer { context.cleanup() }

        let firstTask = Task { await context.store.refreshOwnedParticipants() }
        await client.waitUntilOwnedStateFetchStarts()
        await context.store.refreshOwnedParticipants()

        XCTAssertEqual(client.ownedStateCallCount, 1)
        client.resumeOwnedStateFetch()
        await firstTask.value
        XCTAssertEqual(client.ownedStateCallCount, 1)
    }

    func testErrorPresentationClearsInvitationToAvoidSheetAlertCompetition() {
        var presentation = SharingManagementPresentationState()
        presentation.present(invitationURL: URL(string: "https://example.com/invite")!)

        presentation.showAlert(.message("failure"))

        XCTAssertNil(presentation.presentedInvitation)
        XCTAssertNotNil(presentation.alertState)
    }

    func testActivityCancellationDismissesInvitationWithoutError() {
        var presentation = SharingManagementPresentationState()
        presentation.present(invitationURL: URL(string: "https://example.com/invite")!)

        presentation.dismissInvitation()

        XCTAssertNil(presentation.presentedInvitation)
        XCTAssertNil(presentation.alertState)
    }

    private func makeParticipant(displayName: String?) -> SharedCalendarParticipantSnapshot {
        SharedCalendarParticipantSnapshot(
            id: UUID().uuidString,
            displayName: displayName,
            isAccepted: true,
            permission: .readOnly
        )
    }

    private func makeOwnedState(
        participants: [SharedCalendarParticipantSnapshot]
    ) -> OwnedSharedCalendarCloudState {
        OwnedSharedCalendarCloudState(
            calendar: OwnedSharedCalendarDescriptor(
                displayName: "Owner",
                calendarName: "Shared calendar",
                participantCount: participants.count,
                contentConfiguration: .newShareDefault
            ),
            share: CalendarSharingClientStub.makeShare(),
            participants: participants
        )
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
    var ownedStateError: Error?
    var receivedResult: Result<[ReceivedSharedCalendarPayload], Error> = .success([])
    var createError: Error?
    var invitationError: Error?
    var updateError: Error?
    var createCallCount = 0
    var ownedStateCallCount = 0
    var invitationCallCount = 0
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
    var suspendOwnedStateFetch = false
    var suspendShareCreation = false
    var suspendInvitationCreation = false
    var createdInvitationURL: URL? = URL(string: "https://example.com/invite/first")!
    var additionalInvitationURL: URL? = URL(string: "https://example.com/invite/additional")!

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
    private var ownedStateFetchStarted = false
    private var ownedStateFetchStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var ownedStateFetchContinuation: CheckedContinuation<Void, Never>?
    private var shareCreationStarted = false
    private var shareCreationStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var shareCreationContinuation: CheckedContinuation<Void, Never>?
    private var invitationCreationStarted = false
    private var invitationCreationStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var invitationCreationContinuation: CheckedContinuation<Void, Never>?

    func ownedCalendarState() async throws -> OwnedSharedCalendarCloudState? {
        ownedStateCallCount += 1
        ownedStateFetchStarted = true
        let waiters = ownedStateFetchStartWaiters
        ownedStateFetchStartWaiters.removeAll()
        waiters.forEach { $0.resume() }
        if suspendOwnedStateFetch {
            await withCheckedContinuation { continuation in
                ownedStateFetchContinuation = continuation
            }
        }
        if let ownedStateError { throw ownedStateError }
        return ownedState
    }

    func createShare(
        displayName: String,
        calendarName: String,
        content: SharedContentConfiguration,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws -> OwnedSharingInvitationResult {
        createCallCount += 1
        createdDisplayName = displayName
        createdCalendarName = calendarName
        createdContent = content
        createdSnapshots = events
        createdShifts = shifts
        createdWorkRecords = workRecords
        shareCreationStarted = true
        let waiters = shareCreationStartWaiters
        shareCreationStartWaiters.removeAll()
        waiters.forEach { $0.resume() }
        if suspendShareCreation {
            await withCheckedContinuation { continuation in
                shareCreationContinuation = continuation
            }
        }
        if let createError { throw createError }
        ownedState = createdState
        return OwnedSharingInvitationResult(
            state: createdState,
            invitationURL: createdInvitationURL
        )
    }

    func createOwnedInvitation() async throws -> OwnedSharingInvitationResult {
        invitationCallCount += 1
        invitationCreationStarted = true
        let waiters = invitationCreationStartWaiters
        invitationCreationStartWaiters.removeAll()
        waiters.forEach { $0.resume() }
        if suspendInvitationCreation {
            await withCheckedContinuation { continuation in
                invitationCreationContinuation = continuation
            }
        }
        if let invitationError { throw invitationError }
        let currentState = try XCTUnwrap(ownedState)
        let state = OwnedSharedCalendarCloudState(
            calendar: currentState.calendar,
            share: currentState.share,
            participants: currentState.participants
        )
        ownedState = state
        return OwnedSharingInvitationResult(
            state: state,
            invitationURL: additionalInvitationURL
        )
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
        let state = OwnedSharedCalendarCloudState(
            calendar: calendar,
            share: createdState.share,
            participants: createdState.participants
        )
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

    func waitUntilOwnedStateFetchStarts() async {
        guard !ownedStateFetchStarted else { return }
        await withCheckedContinuation { continuation in
            ownedStateFetchStartWaiters.append(continuation)
        }
    }

    func resumeOwnedStateFetch() {
        suspendOwnedStateFetch = false
        ownedStateFetchContinuation?.resume()
        ownedStateFetchContinuation = nil
    }

    func resumeReceivedFetch() {
        suspendReceivedFetch = false
        receivedFetchContinuation?.resume()
        receivedFetchContinuation = nil
    }

    func waitUntilShareCreationStarts() async {
        guard !shareCreationStarted else { return }
        await withCheckedContinuation { continuation in
            shareCreationStartWaiters.append(continuation)
        }
    }

    func resumeShareCreation() {
        suspendShareCreation = false
        shareCreationContinuation?.resume()
        shareCreationContinuation = nil
    }

    func waitUntilInvitationCreationStarts() async {
        guard !invitationCreationStarted else { return }
        await withCheckedContinuation { continuation in
            invitationCreationStartWaiters.append(continuation)
        }
    }

    func resumeInvitationCreation() {
        suspendInvitationCreation = false
        invitationCreationContinuation?.resume()
        invitationCreationContinuation = nil
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
