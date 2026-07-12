import SwiftData
import XCTest
@testable import TimeNest

@MainActor
final class LegacyStoreMigrationTests: XCTestCase {
    private var directoryURL: URL!
    private var legacyStoreURL: URL!
    private var destinationStoreURL: URL!
    private var markerURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        legacyStoreURL = directoryURL.appendingPathComponent("legacy.store")
        destinationStoreURL = directoryURL.appendingPathComponent("current.store")
        markerURL = directoryURL.appendingPathComponent("migration.complete")
    }

    override func tearDownWithError() throws {
        if let directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        try super.tearDownWithError()
    }

    func testMissingLegacyStoreDoesNotMigrateAndCurrentStoreOpens() throws {
        let preparation = try prepareMigration()

        XCTAssertEqual(preparation.outcome, .legacyStoreMissing)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationStoreURL.path))
        XCTAssertEqual(try eventEntities(in: preparation.container).count, 0)
    }

    func testEmptyDestinationImportsEventsShiftsWorkRecordsAndReminders() throws {
        let legacy = try makeContainer(at: legacyStoreURL)
        let expected = try insertLegacyFixtures(into: legacy)

        let preparation = try prepareMigration()
        let events = try eventEntities(in: preparation.container)
        let reminders = try reminderEntities(in: preparation.container)

        XCTAssertEqual(
            preparation.outcome,
            .migrated(eventCount: expected.eventCount, reminderCount: expected.reminderCount)
        )
        XCTAssertEqual(Set(events.map(\.id)), expected.eventIDs)
        XCTAssertEqual(events.first(where: { $0.shiftTemplateKind == "day" })?.title, "Day Shift")
        XCTAssertEqual(events.first(where: \.hasWorkInfo)?.hourlyRate, 2_400)
        XCTAssertEqual(reminders.first?.message, "Reminder message")
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyStoreURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: markerURL.path))
    }

    func testExistingDestinationDataIsNeverOverwrittenOrMerged() throws {
        let legacy = try makeContainer(at: legacyStoreURL)
        _ = try insertLegacyFixtures(into: legacy)
        let destination = try makeContainer(at: destinationStoreURL)
        let existingID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        try insertEvent(id: existingID, title: "Current", into: destination)

        let preparation = try prepareMigration()
        let events = try eventEntities(in: preparation.container)

        XCTAssertEqual(
            preparation.outcome,
            .destinationHasData(eventCount: 1, reminderCount: 0)
        )
        XCTAssertEqual(events.map(\.id), [existingID])
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyStoreURL.path))
    }

    func testCompletedMigrationDoesNotImportTwice() throws {
        let legacy = try makeContainer(at: legacyStoreURL)
        let expected = try insertLegacyFixtures(into: legacy)

        let first = try prepareMigration()
        let second = try prepareMigration()

        XCTAssertEqual(
            first.outcome,
            .migrated(eventCount: expected.eventCount, reminderCount: expected.reminderCount)
        )
        XCTAssertEqual(second.outcome, .alreadyCompleted)
        XCTAssertEqual(try eventEntities(in: second.container).count, expected.eventCount)
        XCTAssertEqual(try reminderEntities(in: second.container).count, expected.reminderCount)
    }

    func testFailureBeforeSaveLeavesLegacyIntactAndDestinationEmpty() throws {
        let legacy = try makeContainer(at: legacyStoreURL)
        let expected = try insertLegacyFixtures(into: legacy)

        let preparation = try prepareMigration {
            throw InjectedFailure.beforeSave
        }

        XCTAssertEqual(preparation.outcome, .failed)
        XCTAssertEqual(try eventEntities(in: preparation.container).count, 0)
        XCTAssertEqual(try reminderEntities(in: preparation.container).count, 0)
        XCTAssertEqual(try eventEntities(in: legacy).count, expected.eventCount)
        XCTAssertEqual(try reminderEntities(in: legacy).count, expected.reminderCount)
        XCTAssertFalse(FileManager.default.fileExists(atPath: markerURL.path))
    }

    func testAppStoreAndWidgetSnapshotRemainInTheSameAppGroupContainer() {
        let groupRoot = URL(fileURLWithPath: "/group-container", isDirectory: true)
        let storeURL = LegacyStoreMigrator.destinationStoreURL(
            appGroupContainerURL: groupRoot
        )

        XCTAssertEqual(
            LegacyStoreMigrator.appGroupIdentifier,
            WidgetSnapshotStore.appGroupIdentifier
        )
        XCTAssertEqual(storeURL.lastPathComponent, LegacyStoreMigrator.storeFileName)
        XCTAssertEqual(storeURL.deletingLastPathComponent().lastPathComponent, "Application Support")
        XCTAssertEqual(WidgetSnapshotStore.fileName, "widget-snapshot.json")
    }

    private var schema: Schema {
        Schema([
            SwiftDataCalendarEventEntity.self,
            SwiftDataReminderEntity.self
        ])
    }

    private func prepareMigration(
        beforeSave: (() throws -> Void)? = nil
    ) throws -> LegacyStoreMigrator.Preparation {
        try LegacyStoreMigrator.prepareModelContainer(
            schema: schema,
            legacyStoreURL: legacyStoreURL,
            destinationStoreURL: destinationStoreURL,
            markerURL: markerURL,
            beforeSave: beforeSave
        )
    }

    private func makeContainer(at url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "MigrationTest",
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func insertLegacyFixtures(
        into container: ModelContainer
    ) throws -> (eventCount: Int, reminderCount: Int, eventIDs: Set<UUID>) {
        let eventID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let shiftID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let workID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        try insertEvent(id: eventID, title: "Schedule", note: "Private memo", into: container)

        let context = ModelContext(container)
        context.autosaveEnabled = false
        let start = Date(timeIntervalSince1970: 1_767_225_600)
        let shift = makeEvent(id: shiftID, title: "Day Shift", start: start)
        shift.shiftTemplateKind = "day"
        shift.shiftTemplateCustomID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")
        let work = makeEvent(id: workID, title: "Work Record", start: start)
        work.hasWorkInfo = true
        work.workInTime = start
        work.workOutTime = start.addingTimeInterval(8 * 3_600)
        work.restHours = 1
        work.workDate = start
        work.transportFee = 800
        work.hourlyRate = 2_400
        work.workSessionID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")
        work.isWorkOutTimeSet = true
        let reminder = SwiftDataReminderEntity(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            eventID: eventID,
            occurrenceID: "occurrence",
            occurrenceStartDate: start,
            title: "Reminder",
            scheduledDate: start.addingTimeInterval(-900),
            statusRawValue: ReminderStatus.scheduled.rawValue,
            createdAt: start,
            updatedAt: start
        )
        reminder.message = "Reminder message"
        reminder.systemNotificationID = "notification-id"
        reminder.alarmKitID = "alarm-id"
        context.insert(shift)
        context.insert(work)
        context.insert(reminder)
        try context.save()
        return (3, 1, [eventID, shiftID, workID])
    }

    private func insertEvent(
        id: UUID,
        title: String,
        note: String? = nil,
        into container: ModelContainer
    ) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let event = makeEvent(
            id: id,
            title: title,
            start: Date(timeIntervalSince1970: 1_767_225_600)
        )
        event.note = note
        context.insert(event)
        try context.save()
    }

    private func makeEvent(id: UUID, title: String, start: Date) -> SwiftDataCalendarEventEntity {
        SwiftDataCalendarEventEntity(
            id: id,
            title: title,
            startDate: start,
            endDate: start.addingTimeInterval(3_600),
            isAllDay: false,
            recurrenceRuleRawValue: RecurrenceRule.none.rawValue,
            createdAt: start,
            updatedAt: start
        )
    }

    private func eventEntities(
        in container: ModelContainer
    ) throws -> [SwiftDataCalendarEventEntity] {
        try ModelContext(container).fetch(FetchDescriptor<SwiftDataCalendarEventEntity>())
    }

    private func reminderEntities(
        in container: ModelContainer
    ) throws -> [SwiftDataReminderEntity] {
        try ModelContext(container).fetch(FetchDescriptor<SwiftDataReminderEntity>())
    }
}

private enum InjectedFailure: Error {
    case beforeSave
}
