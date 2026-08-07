import Foundation
import SQLite3
import SwiftData
import XCTest
@testable import TimeNest

@MainActor
final class UnifiedEntryStoreMigrationTests: XCTestCase {
    func testCurrentSchemaOpensPreUnifiedStoreAndLinksHistoricalRows() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "UnifiedEntryStoreMigration-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        defer {
            do {
                try FileManager.default.removeItem(at: directoryURL)
            } catch {
                XCTFail("Failed to remove migration test directory: \(error)")
            }
        }
        let storeURL = directoryURL.appendingPathComponent("TimeNest.store")

        let legacySchema = makeLegacySchema()
        let currentSchema = makeCurrentSchema()
        let legacyEntity = try XCTUnwrap(
            legacySchema.entity(
                for: PreUnifiedStoreSchema.SwiftDataCalendarEventEntity.self
            )
        )
        let currentEntity = try XCTUnwrap(
            currentSchema.entity(for: TimeNest.SwiftDataCalendarEventEntity.self)
        )
        XCTAssertEqual(legacyEntity.name, currentEntity.name)
        XCTAssertNil(legacyEntity.attributesByName["unifiedEntryID"])
        XCTAssertNotNil(currentEntity.attributesByName["unifiedEntryID"])

        try createLegacyStore(at: storeURL, schema: legacySchema)

        let legacyColumns = try sqliteColumns(
            in: storeURL,
            table: "ZSWIFTDATACALENDAREVENTENTITY"
        )
        XCTAssertFalse(legacyColumns.isEmpty)
        XCTAssertFalse(legacyColumns.contains("ZUNIFIEDENTRYID"))

        try await verifyUpgradeAndHistoricalLinking(
            at: storeURL,
            schema: currentSchema
        )
    }

    private func makeLegacySchema() -> Schema {
        Schema([
            PreUnifiedStoreSchema.SwiftDataCalendarEventEntity.self,
            TimeNest.SwiftDataReminderEntity.self,
            TimeNest.SwiftDataCalendarEntity.self
        ])
    }

    private func makeCurrentSchema() -> Schema {
        Schema([
            TimeNest.SwiftDataCalendarEventEntity.self,
            TimeNest.SwiftDataReminderEntity.self,
            TimeNest.SwiftDataCalendarEntity.self,
            TimeNest.SwiftDataOwnerSharedEventMutationEntity.self
        ])
    }

    private func createLegacyStore(
        at storeURL: URL,
        schema: Schema
    ) throws {
        let configuration = ModelConfiguration(
            "PreUnifiedEntry",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let calendar = TimeNest.SwiftDataCalendarEntity(
            id: TimeNestCalendar.personalID,
            name: "Pre-unified calendar",
            kindRawValue: TimeNestCalendarKind.personal.rawValue,
            createdAt: Fixture.eventStart,
            updatedAt: Fixture.eventStart
        )
        let event = makeLegacyEvent(
            id: Fixture.eventID,
            title: Fixture.eventTitle,
            note: Fixture.eventNote,
            startDate: Fixture.eventStart,
            endDate: Fixture.eventEnd
        )
        let clockIn = makeLegacyEvent(
            id: Fixture.clockInID,
            title: Fixture.workTitle,
            note: nil,
            startDate: Fixture.clockInDate,
            endDate: Fixture.clockInEndDate
        )
        clockIn.hasWorkInfo = true
        clockIn.workInTime = Fixture.clockInDate
        clockIn.restHours = Fixture.restHours
        clockIn.workDate = Fixture.workDate
        clockIn.transportFee = Fixture.transportFee
        clockIn.hourlyRate = Fixture.hourlyRate
        clockIn.workSessionID = Fixture.workSessionID
        clockIn.isWorkOutTimeSet = true

        let clockOut = makeLegacyEvent(
            id: Fixture.clockOutID,
            title: Fixture.workTitle,
            note: nil,
            startDate: Fixture.clockOutDate,
            endDate: Fixture.clockOutEndDate
        )
        clockOut.hasWorkInfo = true
        clockOut.workOutTime = Fixture.clockOutDate
        clockOut.restHours = Fixture.restHours
        clockOut.workDate = Fixture.workDate
        clockOut.transportFee = Fixture.transportFee
        clockOut.hourlyRate = Fixture.hourlyRate
        clockOut.workSessionID = Fixture.workSessionID
        clockOut.isWorkOutTimeSet = true

        context.insert(calendar)
        context.insert(event)
        context.insert(clockIn)
        context.insert(clockOut)
        try context.save()

        let stored = try context.fetch(
            FetchDescriptor<
                PreUnifiedStoreSchema.SwiftDataCalendarEventEntity
            >()
        )
        XCTAssertEqual(stored.count, 3)
        XCTAssertEqual(Set(stored.map(\.id)), Fixture.eventIDs)
        XCTAssertEqual(
            Set(stored.compactMap(\.workSessionID)),
            [Fixture.workSessionID]
        )
    }

    private func makeLegacyEvent(
        id: UUID,
        title: String,
        note: String?,
        startDate: Date,
        endDate: Date
    ) -> PreUnifiedStoreSchema.SwiftDataCalendarEventEntity {
        let entity = PreUnifiedStoreSchema.SwiftDataCalendarEventEntity(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: false,
            recurrenceRuleRawValue: RecurrenceRule.none.rawValue,
            createdAt: Fixture.createdAt,
            updatedAt: Fixture.updatedAt
        )
        entity.calendarID = TimeNestCalendar.personalID
        entity.note = note
        return entity
    }

    private func verifyUpgradeAndHistoricalLinking(
        at storeURL: URL,
        schema: Schema
    ) async throws {
        let configuration = ModelConfiguration(
            "CurrentUnifiedEntry",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let migrated = try context.fetch(
            FetchDescriptor<TimeNest.SwiftDataCalendarEventEntity>()
        )
        let ownerMutations = try context.fetch(
            FetchDescriptor<TimeNest.SwiftDataOwnerSharedEventMutationEntity>()
        )

        XCTAssertEqual(migrated.count, 3)
        XCTAssertTrue(ownerMutations.isEmpty)
        XCTAssertEqual(Set(migrated.map(\.id)), Fixture.eventIDs)
        XCTAssertTrue(migrated.allSatisfy { $0.unifiedEntryID == nil })

        let event = try XCTUnwrap(
            migrated.first { $0.id == Fixture.eventID }
        )
        assertMigratedEvent(event)
        let clockIn = try XCTUnwrap(
            migrated.first { $0.id == Fixture.clockInID }
        )
        let clockOut = try XCTUnwrap(
            migrated.first { $0.id == Fixture.clockOutID }
        )
        assertMigratedWorkClock(
            clockIn,
            expectedWorkInTime: Fixture.clockInDate,
            expectedWorkOutTime: nil,
            expectedStartDate: Fixture.clockInDate,
            expectedEndDate: Fixture.clockInEndDate
        )
        assertMigratedWorkClock(
            clockOut,
            expectedWorkInTime: nil,
            expectedWorkOutTime: Fixture.clockOutDate,
            expectedStartDate: Fixture.clockOutDate,
            expectedEndDate: Fixture.clockOutEndDate
        )

        let repository = SwiftDataEventRepository(modelContainer: container)
        let useCase = EventUseCase(repository: repository)
        let fetchedHistoricalEvent = try await repository.event(
            id: Fixture.eventID
        )
        let historicalEvent = try XCTUnwrap(
            fetchedHistoricalEvent
        )
        let request = UnifiedEntrySaveRequest(
            event: makeEventRequest(from: historicalEvent),
            workRecord: WorkRecordPairSaveRequest(
                clockInEventID: Fixture.clockInID,
                clockOutEventID: Fixture.clockOutID,
                calendarID: TimeNestCalendar.personalID,
                title: Fixture.workTitle,
                workDate: Fixture.workDate,
                clockInDate: Fixture.clockInDate,
                clockOutDate: Fixture.clockOutDate,
                restHours: Fixture.restHours,
                transportFee: Fixture.transportFee,
                hourlyRate: Fixture.hourlyRate,
                sessionID: Fixture.workSessionID,
                isWorkOutTimeSet: true
            )
        )
        let resolution = try await useCase.resolveUnifiedEntrySave(request)
        var eventToSave = historicalEvent
        eventToSave.unifiedEntryID = resolution.unifiedEntryID
        let workRecord = try XCTUnwrap(request.workRecord)
            .resolvingExistingWorkRecord(
                resolution.existingWorkRecord,
                unifiedEntryID: resolution.unifiedEntryID
            )

        _ = try await useCase.saveEventAndWorkRecordAtomically(
            event: eventToSave,
            existingEvent: resolution.existingEvent,
            workRecord: workRecord
        )

        let saved = try await repository.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        XCTAssertEqual(saved.count, 3)
        XCTAssertEqual(Set(saved.map(\.id)), Fixture.eventIDs)
        XCTAssertTrue(saved.allSatisfy {
            $0.unifiedEntryID == resolution.unifiedEntryID
        })
        XCTAssertNotEqual(resolution.unifiedEntryID, Fixture.workSessionID)

        let savedEvent = try XCTUnwrap(
            saved.first { $0.id == Fixture.eventID }
        )
        XCTAssertEqual(savedEvent.title, Fixture.eventTitle)
        XCTAssertEqual(savedEvent.note, Fixture.eventNote)
        XCTAssertEqual(savedEvent.startDate, Fixture.eventStart)
        XCTAssertEqual(savedEvent.endDate, Fixture.eventEnd)

        let savedClockIn = try XCTUnwrap(
            saved.first { $0.id == Fixture.clockInID }
        )
        let savedClockOut = try XCTUnwrap(
            saved.first { $0.id == Fixture.clockOutID }
        )
        assertSavedWorkClock(
            savedClockIn,
            expectedWorkInTime: Fixture.clockInDate,
            expectedWorkOutTime: nil
        )
        assertSavedWorkClock(
            savedClockOut,
            expectedWorkInTime: nil,
            expectedWorkOutTime: Fixture.clockOutDate
        )

        let groupFromEvent = try await useCase.unifiedEntryGroup(
            for: .event(eventID: Fixture.eventID)
        )
        let groupFromWork = try await useCase.unifiedEntryGroup(
            for: .workRecord(
                clockInEventID: Fixture.clockInID,
                clockOutEventID: Fixture.clockOutID,
                workSessionID: Fixture.workSessionID
            )
        )
        XCTAssertEqual(groupFromEvent, groupFromWork)
        XCTAssertEqual(groupFromEvent.allEvents.count, 3)
    }

    private func assertMigratedEvent(
        _ event: TimeNest.SwiftDataCalendarEventEntity
    ) {
        XCTAssertEqual(event.id, Fixture.eventID)
        XCTAssertEqual(event.calendarID, TimeNestCalendar.personalID)
        XCTAssertEqual(event.title, Fixture.eventTitle)
        XCTAssertEqual(event.note, Fixture.eventNote)
        XCTAssertEqual(event.startDate, Fixture.eventStart)
        XCTAssertEqual(event.endDate, Fixture.eventEnd)
        XCTAssertFalse(event.isAllDay)
        XCTAssertEqual(event.recurrenceRuleRawValue, RecurrenceRule.none.rawValue)
        XCTAssertEqual(event.createdAt, Fixture.createdAt)
        XCTAssertEqual(event.updatedAt, Fixture.updatedAt)
        XCTAssertFalse(event.hasWorkInfo)
    }

    private func assertMigratedWorkClock(
        _ event: TimeNest.SwiftDataCalendarEventEntity,
        expectedWorkInTime: Date?,
        expectedWorkOutTime: Date?,
        expectedStartDate: Date,
        expectedEndDate: Date
    ) {
        XCTAssertEqual(event.calendarID, TimeNestCalendar.personalID)
        XCTAssertEqual(event.title, Fixture.workTitle)
        XCTAssertNil(event.note)
        XCTAssertEqual(event.startDate, expectedStartDate)
        XCTAssertEqual(event.endDate, expectedEndDate)
        XCTAssertEqual(event.workInTime, expectedWorkInTime)
        XCTAssertEqual(event.workOutTime, expectedWorkOutTime)
        XCTAssertEqual(event.workDate, Fixture.workDate)
        XCTAssertEqual(event.restHours, Fixture.restHours)
        XCTAssertEqual(event.transportFee, Fixture.transportFee)
        XCTAssertEqual(event.hourlyRate, Fixture.hourlyRate)
        XCTAssertEqual(event.workSessionID, Fixture.workSessionID)
        XCTAssertEqual(event.isWorkOutTimeSet, true)
        XCTAssertEqual(event.createdAt, Fixture.createdAt)
        XCTAssertEqual(event.updatedAt, Fixture.updatedAt)
    }

    private func assertSavedWorkClock(
        _ event: CalendarEvent,
        expectedWorkInTime: Date?,
        expectedWorkOutTime: Date?
    ) {
        XCTAssertEqual(event.title, Fixture.workTitle)
        XCTAssertNil(event.note)
        XCTAssertEqual(event.workInfo?.workInTime, expectedWorkInTime)
        XCTAssertEqual(event.workInfo?.workOutTime, expectedWorkOutTime)
        XCTAssertEqual(event.workInfo?.workDate, Fixture.workDate)
        XCTAssertEqual(event.workInfo?.restHours, Fixture.restHours)
        XCTAssertEqual(event.workInfo?.transportFee, Fixture.transportFee)
        XCTAssertEqual(event.workInfo?.hourlyRate, Fixture.hourlyRate)
        XCTAssertEqual(event.workInfo?.workSessionId, Fixture.workSessionID)
        XCTAssertEqual(event.workInfo?.isWorkOutTimeSet, true)
    }

    private func makeEventRequest(
        from event: CalendarEvent
    ) -> EventEntrySaveRequest {
        EventEntrySaveRequest(
            eventID: event.id,
            calendarID: event.calendarID,
            title: event.title,
            note: event.note,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            reminderOffsetMinutes: event.reminderOffsetMinutes,
            shiftTemplateID: event.shiftTemplateID,
            workInfo: event.workInfo
        )
    }

    private func sqliteColumns(
        in storeURL: URL,
        table: String
    ) throws -> Set<String> {
        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            storeURL.path,
            &database,
            SQLITE_OPEN_READONLY,
            nil
        )
        guard openResult == SQLITE_OK, let database else {
            defer { sqlite3_close(database) }
            throw sqliteError(
                code: openResult,
                message: "Unable to open old Store for schema inspection."
            )
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        let sql = "PRAGMA table_info(\(table))"
        let prepareResult = sqlite3_prepare_v2(
            database,
            sql,
            -1,
            &statement,
            nil
        )
        guard prepareResult == SQLITE_OK, let statement else {
            defer { sqlite3_finalize(statement) }
            throw sqliteError(
                code: prepareResult,
                message: "Unable to read old Store table columns."
            )
        }
        defer { sqlite3_finalize(statement) }

        var columns: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let columnName = sqlite3_column_text(statement, 1) else {
                continue
            }
            columns.insert(String(cString: columnName))
        }
        return columns
    }

    private func sqliteError(code: Int32, message: String) -> NSError {
        NSError(
            domain: "UnifiedEntryStoreMigrationTests.SQLite",
            code: Int(code),
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private enum Fixture {
        static let eventID = UUID(
            uuidString: "11111111-2222-3333-4444-555555555555"
        )!
        static let clockInID = UUID(
            uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA"
        )!
        static let clockOutID = UUID(
            uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF"
        )!
        static let workSessionID = UUID(
            uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        )!
        static let eventIDs: Set<UUID> = [
            eventID,
            clockInID,
            clockOutID
        ]
        static let eventTitle = "Pre-unified event"
        static let eventNote = "Must survive migration"
        static let workTitle = "Historical work"
        static let createdAt = Date(timeIntervalSince1970: 1_779_900_000)
        static let updatedAt = Date(timeIntervalSince1970: 1_779_950_000)
        static let eventStart = Date(timeIntervalSince1970: 1_780_000_000)
        static let eventEnd = eventStart.addingTimeInterval(90 * 60)
        static let workDate = eventStart.addingTimeInterval(86_400)
        static let clockInDate = workDate.addingTimeInterval(9 * 3_600)
        static let clockOutDate = clockInDate.addingTimeInterval(8 * 3_600)
        static let clockInEndDate = clockInDate.addingTimeInterval(3_600)
        static let clockOutEndDate = clockOutDate.addingTimeInterval(3_600)
        static let restHours = 1.25
        static let transportFee = 730
        static let hourlyRate = 2_650
    }
}

/// Test-only copy of the last production model before `unifiedEntryID` existed.
///
/// Its simple name intentionally matches the production entity so SwiftData creates
/// the same persistent entity while the module keeps the fixture isolated to tests.
enum PreUnifiedStoreSchema {
    @Model
    final class SwiftDataCalendarEventEntity {
        @Attribute(.unique) var id: UUID
        var calendarID: UUID?
        var title: String
        var note: String?
        var startDate: Date
        var endDate: Date
        var isAllDay: Bool
        var categoryID: UUID?
        var recurrenceRuleRawValue: String
        var reminderTemplateID: UUID?
        var reminderOffsetMinutes: Int?
        var notificationID: String?
        var importSourceTypeRawValue: String?
        var importExternalEventIdentifier: String?
        var importExternalCalendarIdentifier: String?
        var importExternalCalendarTitle: String?
        var importedAt: Date?
        var createdAt: Date
        var updatedAt: Date
        var shiftTemplateKind: String?
        var shiftTemplateCustomID: UUID?
        var hasWorkInfo: Bool
        var workInTime: Date?
        var workOutTime: Date?
        var restHours: Double?
        var workDate: Date?
        var transportFee: Int?
        var hourlyRate: Int?
        var workSessionID: UUID?
        var isWorkOutTimeSet: Bool?

        init(
            id: UUID,
            title: String,
            startDate: Date,
            endDate: Date,
            isAllDay: Bool,
            recurrenceRuleRawValue: String,
            createdAt: Date,
            updatedAt: Date
        ) {
            self.id = id
            self.title = title
            self.startDate = startDate
            self.endDate = endDate
            self.isAllDay = isAllDay
            self.recurrenceRuleRawValue = recurrenceRuleRawValue
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.hasWorkInfo = false
        }
    }
}
