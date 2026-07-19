import SwiftData
import UserNotifications
import XCTest
@testable import TimeNest

@MainActor
final class TimeNestBackupServiceTests: XCTestCase {
    private var temporaryURLs: [URL] = []

    override func tearDown() {
        temporaryURLs.forEach { try? FileManager.default.removeItem(at: $0) }
        temporaryURLs.removeAll()
        super.tearDown()
    }

    func testEmptyDatabaseProducesVersionedValidBackup() throws {
        let context = try makeContext()
        let defaults = makeDefaults()
        let service = TimeNestBackupService(modelContext: context, defaults: defaults)

        let document = try service.makeDocument(
            createdAt: Date(timeIntervalSince1970: 1_752_883_200),
            appVersion: "1.4"
        )
        let decoded = try TimeNestBackupDocument.decoded(from: document.encoded())

        XCTAssertEqual(decoded.formatVersion, 1)
        XCTAssertEqual(decoded.appIdentifier, "TimeNest")
        XCTAssertEqual(decoded.data.calendars.map(\.id), [TimeNestCalendar.personalID])
        XCTAssertTrue(decoded.data.allEvents.isEmpty)
    }

    func testBackupSeparatesEventsShiftsAndWorkRecordsAndPreservesRelationships() throws {
        let context = try makeContext()
        let defaults = makeDefaults()
        let holidaySubscription = HolidaySubscription(
            region: .japan,
            displayNameKey: HolidayRegion.japan.localizedKey,
            urlString: "https://example.invalid/日本,休日.ics",
            isEnabled: true,
            lastUpdatedAt: Date(),
            syncStatus: .failed,
            errorMessage: "cached error"
        )
        storeHolidaySubscriptions([holidaySubscription], in: defaults)
        let personal = makeCalendarEntity(
            id: TimeNestCalendar.personalID,
            name: "My Calendar",
            kind: .personal
        )
        let ownedID = UUID()
        let owned = makeCalendarEntity(id: ownedID, name: "Family", kind: .sharedOwned)
        context.insert(personal)
        context.insert(owned)

        let ordinaryID = UUID()
        let ordinary = makeEvent(
            id: ordinaryID,
            calendarID: ownedID,
            title: "予定, \"重要\"\n다음",
            note: "备注,メモ\nNote",
            notificationID: "device-local-notification"
        )
        let shift = makeEvent(
            calendarID: TimeNestCalendar.personalID,
            title: "Night",
            shiftTemplateID: .night
        )
        let work = makeWorkRecordEvents(calendarID: TimeNestCalendar.personalID)
        [ordinary, shift, work.clockIn, work.clockOut].forEach {
            context.insert(SwiftDataEventMapper.makeEntity(from: $0))
        }
        try context.save()

        let document = try TimeNestBackupService(
            modelContext: context,
            defaults: defaults
        ).makeDocument(appVersion: "1.4")
        let encoded = try document.encoded()
        let decoded = try TimeNestBackupDocument.decoded(from: encoded)

        XCTAssertEqual(decoded.data.events.map(\.id), [ordinaryID])
        XCTAssertEqual(decoded.data.shifts.count, 1)
        XCTAssertEqual(decoded.data.workRecords.count, 2)
        XCTAssertEqual(decoded.data.events.first?.calendarID, ownedID)
        XCTAssertEqual(decoded.data.events.first?.note, ordinary.note)
        XCTAssertEqual(
            decoded.data.settings.holidaySubscriptions,
            [
                TimeNestBackupSettings.HolidaySubscriptionSetting(
                    id: holidaySubscription.id,
                    region: HolidayRegion.japan.rawValue,
                    urlString: holidaySubscription.urlString,
                    isEnabled: true
                )
            ]
        )
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("device-local-notification"))
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("cached error"))
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("shareRecordName"))
    }

    func testBackupExcludesReceivedSharedCacheWithoutDroppingPersonalData() throws {
        let context = try makeContext()
        let receivedID = UUID()
        context.insert(makeCalendarEntity(id: receivedID, name: "Received", kind: .sharedReceived))
        let personalEvent = makeEvent(title: "Personal")
        let receivedEvent = makeEvent(calendarID: receivedID, title: "Received cache")
        context.insert(SwiftDataEventMapper.makeEntity(from: personalEvent))
        context.insert(SwiftDataEventMapper.makeEntity(from: receivedEvent))
        try context.save()

        let document = try TimeNestBackupService(
            modelContext: context,
            defaults: makeDefaults()
        ).makeDocument(appVersion: "1.4")

        XCTAssertEqual(document.data.calendars.map(\.id), [TimeNestCalendar.personalID])
        XCTAssertEqual(document.data.allEvents.map(\.id), [personalEvent.id])
    }

    func testBackupRejectsUnknownCalendarRelationshipInsteadOfSilentlyDroppingEvent() throws {
        let context = try makeContext()
        context.insert(
            SwiftDataEventMapper.makeEntity(
                from: makeEvent(calendarID: UUID(), title: "Orphan")
            )
        )
        try context.save()

        XCTAssertThrowsError(
            try TimeNestBackupService(
                modelContext: context,
                defaults: makeDefaults()
            ).makeDocument(appVersion: "1.4")
        ) {
            XCTAssertEqual($0 as? TimeNestBackupError, .missingCalendarRelationship)
        }
    }

    func testRestoreReplacesDataAtomicallyAndConvertsSharedOwnedContentToPersonal() async throws {
        let sourceContext = try makeContext()
        let sourceDefaults = makeDefaults()
        let holidaySubscription = HolidaySubscription(
            region: .korea,
            displayNameKey: HolidayRegion.korea.localizedKey,
            urlString: "https://example.invalid/holidays.ics",
            isEnabled: true,
            lastUpdatedAt: Date(),
            syncStatus: .success
        )
        storeHolidaySubscriptions([holidaySubscription], in: sourceDefaults)
        let ownedID = UUID()
        sourceContext.insert(makeCalendarEntity(id: ownedID, name: "Family", kind: .sharedOwned))
        let sourceEvent = makeEvent(calendarID: ownedID, title: "Owned local data")
        sourceContext.insert(SwiftDataEventMapper.makeEntity(from: sourceEvent))
        try sourceContext.save()
        let document = try TimeNestBackupService(
            modelContext: sourceContext,
            defaults: sourceDefaults
        ).makeDocument(appVersion: "1.4")

        let destinationContext = try makeContext()
        destinationContext.insert(
            makeCalendarEntity(
                id: TimeNestCalendar.personalID,
                name: "Old",
                kind: .personal
            )
        )
        destinationContext.insert(
            SwiftDataEventMapper.makeEntity(
                from: makeEvent(
                    title: "Old event",
                    notificationID: "old-event-notification"
                )
            )
        )
        let reminder = SwiftDataReminderEntity(
            id: UUID(),
            eventID: UUID(),
            occurrenceID: "old-occurrence",
            occurrenceStartDate: Date(),
            title: "Old reminder",
            scheduledDate: Date(),
            statusRawValue: "pending",
            createdAt: Date(),
            updatedAt: Date()
        )
        reminder.systemNotificationID = "old-reminder-notification"
        destinationContext.insert(reminder)
        try destinationContext.save()
        var cleanedNotificationIDs: [String] = []
        let destinationDefaults = makeDefaults()

        _ = try await TimeNestBackupService(
            modelContext: destinationContext,
            defaults: destinationDefaults,
            notificationCleaner: { cleanedNotificationIDs = $0 }
        ).restore(document)

        let calendars = try destinationContext.fetch(FetchDescriptor<SwiftDataCalendarEntity>())
        let events = try destinationContext.fetch(FetchDescriptor<SwiftDataCalendarEventEntity>())
            .map(SwiftDataEventMapper.makeDomainModel)
        XCTAssertEqual(calendars.count, 1)
        XCTAssertEqual(calendars.first?.kindRawValue, TimeNestCalendarKind.personal.rawValue)
        XCTAssertNil(calendars.first?.zoneName)
        XCTAssertNil(calendars.first?.shareRecordName)
        XCTAssertEqual(events.map(\.id), [sourceEvent.id])
        XCTAssertTrue(events.allSatisfy { $0.calendarID == TimeNestCalendar.personalID })
        XCTAssertEqual(
            cleanedNotificationIDs,
            ["old-event-notification", "old-reminder-notification"]
        )
        let restoredSubscriptions = loadHolidaySubscriptions(from: destinationDefaults)
        XCTAssertEqual(restoredSubscriptions.map(\.id), [holidaySubscription.id])
        XCTAssertEqual(restoredSubscriptions.map(\.region), [.korea])
        XCTAssertEqual(restoredSubscriptions.map(\.urlString), [holidaySubscription.urlString])
        XCTAssertEqual(restoredSubscriptions.map(\.isEnabled), [true])
        XCTAssertEqual(restoredSubscriptions.map(\.syncStatus), [.neverSynced])
        XCTAssertTrue(restoredSubscriptions.allSatisfy { $0.lastUpdatedAt == nil })
    }

    func testInjectedRestoreFailureKeepsOriginalData() async throws {
        enum Injected: Error { case failure }
        let context = try makeContext()
        context.insert(
            makeCalendarEntity(
                id: TimeNestCalendar.personalID,
                name: "My Calendar",
                kind: .personal
            )
        )
        let original = makeEvent(
            title: "Original",
            notificationID: "original-notification"
        )
        context.insert(SwiftDataEventMapper.makeEntity(from: original))
        try context.save()
        let document = try TimeNestBackupService(
            modelContext: context,
            defaults: makeDefaults()
        ).makeDocument(appVersion: "1.4")
        var cleanedNotificationIDs: [String] = []
        let service = TimeNestBackupService(
            modelContext: context,
            defaults: makeDefaults(),
            beforeSaveForTesting: { throw Injected.failure },
            notificationCleaner: { cleanedNotificationIDs = $0 }
        )

        do {
            _ = try await service.restore(document)
            XCTFail("Injected save failure must fail the restore")
        } catch {
            XCTAssertTrue(error is Injected)
        }

        let remaining = try context.fetch(FetchDescriptor<SwiftDataCalendarEventEntity>())
            .map(SwiftDataEventMapper.makeDomainModel)
        XCTAssertEqual(remaining.map(\.id), [original.id])
        XCTAssertEqual(remaining.map(\.title), ["Original"])
        XCTAssertTrue(cleanedNotificationIDs.isEmpty)
    }

    func testDecoderRejectsInvalidJSONMissingFieldsInvalidDatesAndUnsupportedVersion() throws {
        XCTAssertThrowsError(try TimeNestBackupDocument.decoded(from: Data("not json".utf8)))
        XCTAssertThrowsError(
            try TimeNestBackupDocument.decoded(
                from: Data("{\"appIdentifier\":\"TimeNest\"}".utf8)
            )
        )

        let document = try TimeNestBackupService(
            modelContext: try makeContext(),
            defaults: makeDefaults()
        ).makeDocument(appVersion: "1.4")
        let invalidDate = String(decoding: try document.encoded(), as: UTF8.self)
            .replacingOccurrences(
                of: "\"createdAt\" : \"",
                with: "\"createdAt\" : \"not-a-date"
            )
        XCTAssertThrowsError(
            try TimeNestBackupDocument.decoded(from: Data(invalidDate.utf8))
        )

        let unsupported = TimeNestBackupDocument(
            formatVersion: 99,
            appIdentifier: document.appIdentifier,
            createdAt: document.createdAt,
            appVersion: document.appVersion,
            data: document.data
        )
        XCTAssertThrowsError(try TimeNestBackupValidator.validate(unsupported)) {
            XCTAssertEqual($0 as? TimeNestBackupError, .unsupportedFormatVersion(99))
        }
    }

    func testValidatorRejectsDuplicateEventUUID() throws {
        let context = try makeContext()
        context.insert(
            makeCalendarEntity(
                id: TimeNestCalendar.personalID,
                name: "My Calendar",
                kind: .personal
            )
        )
        let event = makeEvent(title: "Duplicate")
        context.insert(SwiftDataEventMapper.makeEntity(from: event))
        try context.save()
        let document = try TimeNestBackupService(
            modelContext: context,
            defaults: makeDefaults()
        ).makeDocument(appVersion: "1.4")
        let duplicateData = TimeNestBackupData(
            calendars: document.data.calendars,
            events: document.data.events + document.data.events,
            shifts: document.data.shifts,
            workRecords: document.data.workRecords,
            settings: document.data.settings
        )
        let duplicate = TimeNestBackupDocument(
            formatVersion: 1,
            appIdentifier: "TimeNest",
            createdAt: document.createdAt,
            appVersion: "1.4",
            data: duplicateData
        )

        XCTAssertThrowsError(try TimeNestBackupValidator.validate(duplicate)) {
            XCTAssertEqual($0 as? TimeNestBackupError, .duplicateEventID)
        }
    }

    func testValidatorRejectsWrongAppDuplicateCalendarAndMissingRelationship() throws {
        let document = try TimeNestBackupService(
            modelContext: try makeContext(),
            defaults: makeDefaults()
        ).makeDocument(appVersion: "1.4")

        let wrongApp = replacing(document, appIdentifier: "AnotherApp")
        XCTAssertThrowsError(try TimeNestBackupValidator.validate(wrongApp)) {
            XCTAssertEqual($0 as? TimeNestBackupError, .invalidAppIdentifier)
        }

        let duplicateCalendars = TimeNestBackupData(
            calendars: document.data.calendars + document.data.calendars,
            events: document.data.events,
            shifts: document.data.shifts,
            workRecords: document.data.workRecords,
            settings: document.data.settings
        )
        XCTAssertThrowsError(
            try TimeNestBackupValidator.validate(replacing(document, data: duplicateCalendars))
        ) {
            XCTAssertEqual($0 as? TimeNestBackupError, .duplicateCalendarID)
        }

        let missingCalendarEvent = TimeNestBackupEvent(
            event: makeEvent(calendarID: UUID(), title: "Orphan")
        )
        let missingRelationship = TimeNestBackupData(
            calendars: document.data.calendars,
            events: [missingCalendarEvent],
            shifts: [],
            workRecords: [],
            settings: document.data.settings
        )
        XCTAssertThrowsError(
            try TimeNestBackupValidator.validate(replacing(document, data: missingRelationship))
        ) {
            XCTAssertEqual($0 as? TimeNestBackupError, .missingCalendarRelationship)
        }
    }

    func testValidatorRejectsInvalidDateRangeRecurrenceWorkInfoAndSettings() throws {
        let context = try makeContext()
        context.insert(
            makeCalendarEntity(
                id: TimeNestCalendar.personalID,
                name: "My Calendar",
                kind: .personal
            )
        )
        context.insert(SwiftDataEventMapper.makeEntity(from: makeEvent(title: "Valid")))
        try context.save()
        let document = try TimeNestBackupService(
            modelContext: context,
            defaults: makeDefaults()
        ).makeDocument(appVersion: "1.4")
        _ = try XCTUnwrap(document.data.events.first)

        let invalidDateDocument = try mutatingEncodedDocument(document) { root in
            mutateFirstEvent(in: &root) { event in
                event["startDate"] = "2099-07-15T10:00:00Z"
                event["endDate"] = "2099-07-15T09:00:00Z"
            }
        }
        XCTAssertThrowsError(
            try TimeNestBackupValidator.validate(invalidDateDocument)
        ) {
            XCTAssertEqual($0 as? TimeNestBackupError, .invalidEventDateRange)
        }

        let invalidRecurrenceDocument = try mutatingEncodedDocument(document) { root in
            mutateFirstEvent(in: &root) { event in
                event["recurrenceRule"] = "not-a-rule"
            }
        }
        XCTAssertThrowsError(
            try TimeNestBackupValidator.validate(invalidRecurrenceDocument)
        ) {
            XCTAssertEqual($0 as? TimeNestBackupError, .invalidRecurrenceRule)
        }

        let invalidWorkDocument = try mutatingEncodedDocument(document) { root in
            mutateFirstEvent(in: &root) { event in
                event["workInfo"] = [
                    "restHours": -1,
                    "isWorkOutTimeSet": true
                ]
            }
        }
        XCTAssertThrowsError(
            try TimeNestBackupValidator.validate(invalidWorkDocument)
        ) {
            XCTAssertEqual($0 as? TimeNestBackupError, .invalidWorkInfo)
        }

        let invalidSettingsDocument = try mutatingEncodedDocument(document) { root in
            var data = root["data"] as! [String: Any]
            var settings = data["settings"] as! [String: Any]
            let duplicateID = UUID().uuidString
            let subscription: [String: Any] = [
                "id": duplicateID,
                "region": HolidayRegion.japan.rawValue,
                "urlString": "https://example.invalid/holidays.ics",
                "isEnabled": true
            ]
            settings["holidaySubscriptions"] = [subscription, subscription]
            data["settings"] = settings
            root["data"] = data
        }
        XCTAssertThrowsError(
            try TimeNestBackupValidator.validate(invalidSettingsDocument)
        ) {
            XCTAssertEqual($0 as? TimeNestBackupError, .invalidSettings)
        }
    }

    func testInvalidRestorePreflightLeavesExistingDataAndNotificationsUntouched() async throws {
        let context = try makeContext()
        context.insert(
            makeCalendarEntity(
                id: TimeNestCalendar.personalID,
                name: "Original Calendar",
                kind: .personal
            )
        )
        let original = makeEvent(title: "Original", notificationID: "original-notification")
        context.insert(SwiftDataEventMapper.makeEntity(from: original))
        try context.save()

        let valid = try TimeNestBackupService(
            modelContext: context,
            defaults: makeDefaults()
        ).makeDocument(appVersion: "1.4")
        let invalid = replacing(valid, appIdentifier: "WrongApp")
        var cleanedNotificationIDs: [String] = []

        do {
            _ = try await TimeNestBackupService(
                modelContext: context,
                defaults: makeDefaults(),
                notificationCleaner: { cleanedNotificationIDs = $0 }
            ).restore(invalid)
            XCTFail("Invalid backup must fail before replacement")
        } catch {
            XCTAssertEqual(error as? TimeNestBackupError, .invalidAppIdentifier)
        }

        let events = try context.fetch(FetchDescriptor<SwiftDataCalendarEventEntity>())
            .map(SwiftDataEventMapper.makeDomainModel)
        XCTAssertEqual(events.map(\.id), [original.id])
        XCTAssertEqual(events.map(\.title), ["Original"])
        XCTAssertEqual(events.map(\.notificationID), ["original-notification"])
        XCTAssertTrue(cleanedNotificationIDs.isEmpty)
    }

    func testRestoreReschedulesFutureReminderWithStableIdentifier() async throws {
        let sourceContext = try makeContext()
        sourceContext.insert(
            makeCalendarEntity(
                id: TimeNestCalendar.personalID,
                name: "My Calendar",
                kind: .personal
            )
        )
        let futureStart = Date().addingTimeInterval(3_600)
        let future = makeEvent(
            title: "Future reminder",
            startDate: futureStart,
            reminderOffsetMinutes: 10
        )
        sourceContext.insert(SwiftDataEventMapper.makeEntity(from: future))
        try sourceContext.save()
        let document = try TimeNestBackupService(
            modelContext: sourceContext,
            defaults: makeDefaults()
        ).makeDocument(appVersion: "1.4")

        let destinationContext = try makeContext()
        let scheduler = RestoreNotificationSchedulerSpy()
        let summary = try await TimeNestBackupService(
            modelContext: destinationContext,
            defaults: makeDefaults(),
            notificationCleaner: { _ in },
            notificationScheduler: scheduler
        ).restore(document)

        let restored = try destinationContext.fetch(
            FetchDescriptor<SwiftDataCalendarEventEntity>()
        ).map(SwiftDataEventMapper.makeDomainModel)
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored.first?.reminderOffsetMinutes, 10)
        XCTAssertEqual(
            restored.first?.notificationID,
            TimeNestBackupService.restoredNotificationIdentifier(for: future.id)
        )
        XCTAssertEqual(summary.scheduledCount, 1)
        XCTAssertEqual(scheduler.scheduledEvents.map(\.id), [future.id])
    }

    func testRestoreSkipsPastAndExpiredRemindersAndKeepsIdentifiersUnique() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sourceContext = try makeContext()
        sourceContext.insert(
            makeCalendarEntity(
                id: TimeNestCalendar.personalID,
                name: "My Calendar",
                kind: .personal
            )
        )
        let events = [
            makeEvent(title: "Future A", startDate: now.addingTimeInterval(3_600), reminderOffsetMinutes: 10),
            makeEvent(title: "Future B", startDate: now.addingTimeInterval(7_200), reminderOffsetMinutes: 30),
            makeEvent(title: "Past", startDate: now.addingTimeInterval(-60), reminderOffsetMinutes: 10),
            makeEvent(title: "Expired", startDate: now.addingTimeInterval(300), reminderOffsetMinutes: 10)
        ]
        for event in events {
            sourceContext.insert(SwiftDataEventMapper.makeEntity(from: event))
        }
        try sourceContext.save()
        let document = try TimeNestBackupService(
            modelContext: sourceContext,
            defaults: makeDefaults()
        ).makeDocument(appVersion: "1.4")
        let destinationContext = try makeContext()
        let scheduler = RestoreNotificationSchedulerSpy()

        let summary = try await TimeNestBackupService(
            modelContext: destinationContext,
            defaults: makeDefaults(),
            notificationCleaner: { _ in },
            notificationScheduler: scheduler,
            now: { now }
        ).restore(document)

        XCTAssertEqual(summary.scheduledCount, 2)
        XCTAssertEqual(summary.pastEventCount, 1)
        XCTAssertEqual(summary.expiredReminderCount, 1)
        XCTAssertEqual(scheduler.scheduledEvents.map(\.title).sorted(), ["Future A", "Future B"])
        XCTAssertEqual(Set(scheduler.scheduledIdentifiers).count, 2)
    }

    func testDeniedOrFailedNotificationSchedulingDoesNotUndoRestoredData() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sourceContext = try makeContext()
        sourceContext.insert(
            makeCalendarEntity(
                id: TimeNestCalendar.personalID,
                name: "My Calendar",
                kind: .personal
            )
        )
        let denied = makeEvent(title: "Denied", startDate: now.addingTimeInterval(3_600), reminderOffsetMinutes: 5)
        let failed = makeEvent(title: "Failed", startDate: now.addingTimeInterval(7_200), reminderOffsetMinutes: 5)
        sourceContext.insert(SwiftDataEventMapper.makeEntity(from: denied))
        sourceContext.insert(SwiftDataEventMapper.makeEntity(from: failed))
        try sourceContext.save()
        let document = try TimeNestBackupService(
            modelContext: sourceContext,
            defaults: makeDefaults()
        ).makeDocument(appVersion: "1.4")
        let destinationContext = try makeContext()
        let scheduler = RestoreNotificationSchedulerSpy()
        scheduler.resultsByEventID[denied.id] = .denied
        scheduler.resultsByEventID[failed.id] = .failed

        let summary = try await TimeNestBackupService(
            modelContext: destinationContext,
            defaults: makeDefaults(),
            notificationCleaner: { _ in },
            notificationScheduler: scheduler,
            now: { now }
        ).restore(document)

        let restored = try destinationContext.fetch(FetchDescriptor<SwiftDataCalendarEventEntity>())
            .map(SwiftDataEventMapper.makeDomainModel)
        XCTAssertEqual(Set(restored.map(\.id)), Set([denied.id, failed.id]))
        XCTAssertTrue(restored.allSatisfy { $0.reminderOffsetMinutes == 5 })
        XCTAssertTrue(restored.allSatisfy { $0.notificationID == nil })
        XCTAssertEqual(summary.deniedCount, 1)
        XCTAssertEqual(summary.failedCount, 1)
    }

    func testRepeatedRestoreReusesIdentifierAndCleansPreviousNotification() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sourceContext = try makeContext()
        sourceContext.insert(makeCalendarEntity(id: TimeNestCalendar.personalID, name: "Mine", kind: .personal))
        let future = makeEvent(title: "Future", startDate: now.addingTimeInterval(3_600), reminderOffsetMinutes: 5)
        sourceContext.insert(SwiftDataEventMapper.makeEntity(from: future))
        try sourceContext.save()
        let document = try TimeNestBackupService(
            modelContext: sourceContext,
            defaults: makeDefaults()
        ).makeDocument(appVersion: "1.4")
        let destinationContext = try makeContext()
        let scheduler = RestoreNotificationSchedulerSpy()
        var cleanedRuns: [[String]] = []
        let service = TimeNestBackupService(
            modelContext: destinationContext,
            defaults: makeDefaults(),
            notificationCleaner: { cleanedRuns.append($0) },
            notificationScheduler: scheduler,
            now: { now }
        )

        _ = try await service.restore(document)
        _ = try await service.restore(document)

        let expectedID = TimeNestBackupService.restoredNotificationIdentifier(for: future.id)
        XCTAssertEqual(scheduler.scheduledIdentifiers, [expectedID, expectedID])
        XCTAssertEqual(cleanedRuns, [[], [expectedID]])
    }

    private func replacing(
        _ document: TimeNestBackupDocument,
        appIdentifier: String? = nil,
        data: TimeNestBackupData? = nil
    ) -> TimeNestBackupDocument {
        TimeNestBackupDocument(
            formatVersion: document.formatVersion,
            appIdentifier: appIdentifier ?? document.appIdentifier,
            createdAt: document.createdAt,
            appVersion: document.appVersion,
            data: data ?? document.data
        )
    }

    private func mutatingEncodedDocument(
        _ document: TimeNestBackupDocument,
        mutation: (inout [String: Any]) -> Void
    ) throws -> TimeNestBackupDocument {
        var root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: document.encoded()) as? [String: Any]
        )
        mutation(&root)
        let data = try JSONSerialization.data(withJSONObject: root)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TimeNestBackupDocument.self, from: data)
    }

    private func mutateFirstEvent(
        in root: inout [String: Any],
        mutation: (inout [String: Any]) -> Void
    ) {
        var data = root["data"] as! [String: Any]
        var events = data["events"] as! [[String: Any]]
        var event = events[0]
        mutation(&event)
        events[0] = event
        data["events"] = events
        root["data"] = data
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            SwiftDataCalendarEventEntity.self,
            SwiftDataReminderEntity.self,
            SwiftDataCalendarEntity.self
        ])
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeNestBackupTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryURLs.append(directory)
        let configuration = ModelConfiguration(
            "TimeNestBackupTests",
            schema: schema,
            url: directory.appendingPathComponent("store.sqlite"),
            cloudKitDatabase: .none
        )
        let context = ModelContext(
            try ModelContainer(for: schema, configurations: [configuration])
        )
        context.autosaveEnabled = false
        return context
    }

    private func makeDefaults() -> UserDefaults {
        let name = "TimeNestBackupTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func storeHolidaySubscriptions(
        _ subscriptions: [HolidaySubscription],
        in defaults: UserDefaults
    ) {
        let data = try! JSONEncoder().encode(subscriptions)
        defaults.set(String(decoding: data, as: UTF8.self), forKey: "holidaySubscriptions")
    }

    private func loadHolidaySubscriptions(from defaults: UserDefaults) -> [HolidaySubscription] {
        guard let json = defaults.string(forKey: "holidaySubscriptions") else { return [] }
        return (try? JSONDecoder().decode(
            [HolidaySubscription].self,
            from: Data(json.utf8)
        )) ?? []
    }
}

final class WorkRecordCSVExporterTests: XCTestCase {
    func testNoDataDoesNotGenerateCSV() {
        XCTAssertThrowsError(
            try WorkRecordCSVExporter.makeExport(
                events: [],
                monthContaining: julyDate,
                headers: headers,
                locale: Locale(identifier: "en_US")
            )
        ) {
            XCTAssertEqual($0 as? WorkRecordCSVExportError, .noData)
        }
    }

    func testCSVUsesSharedCalculationAndEscapesCommasQuotesNewlinesAndUnicode() throws {
        let work = makeWorkRecordEvents(
            title: "夜勤, \"A\"\n근무",
            note: "备注,\"メモ\"\n다음"
        )
        let export = try WorkRecordCSVExporter.makeExport(
            events: [work.clockIn, work.clockOut],
            monthContaining: julyDate,
            headers: headers,
            locale: Locale(identifier: "en_US")
        )
        let text = String(decoding: export.data, as: UTF8.self)
        let range = Calendar.current.dateInterval(of: .month, for: julyDate)!
        let calculated = WorkRecordSessionCalculator.sessions(
            from: [work.clockIn, work.clockOut],
            in: range
        )

        XCTAssertEqual(export.recordCount, 1)
        XCTAssertEqual(calculated.first?.workedMinutes, 420)
        XCTAssertTrue(text.hasPrefix("\u{FEFF}"))
        XCTAssertTrue(text.contains("07:00"))
        XCTAssertTrue(text.contains("\"夜勤, \"\"A\"\"\n근무\""))
        XCTAssertTrue(text.contains("\"备注,\"\"メモ\"\"\n다음\""))
        XCTAssertEqual(export.fileName, "TimeNest_WorkRecords_2026-07.csv")
    }

    func testEscapeLeavesEmptyValueValidAndQuotesSpecialCharacters() {
        XCTAssertEqual(WorkRecordCSVExporter.escape(""), "")
        XCTAssertEqual(WorkRecordCSVExporter.escape("plain"), "plain")
        XCTAssertEqual(WorkRecordCSVExporter.escape("a,b"), "\"a,b\"")
        XCTAssertEqual(WorkRecordCSVExporter.escape("a\"b"), "\"a\"\"b\"")
        XCTAssertEqual(WorkRecordCSVExporter.escape("a\nb"), "\"a\nb\"")
    }

    func testCrossMidnightAndIncompleteWorkRecordsFollowCurrentRules() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 18))!
        let start = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day)!
        let end = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: day)!
        let sessionID = UUID()
        let clockIn = makeEvent(
            title: "Overnight",
            workInfo: WorkInfo(
                workInTime: start,
                restHours: 1,
                workDate: day,
                workSessionId: sessionID,
                isWorkOutTimeSet: true
            )
        )
        let clockOut = makeEvent(
            title: "Overnight",
            workInfo: WorkInfo(
                workOutTime: end,
                restHours: 1,
                workDate: day,
                workSessionId: sessionID,
                isWorkOutTimeSet: true
            )
        )
        let incomplete = makeEvent(
            title: "Incomplete",
            workInfo: WorkInfo(
                workInTime: start.addingTimeInterval(300),
                restHours: 0,
                workDate: day,
                workSessionId: UUID(),
                isWorkOutTimeSet: false
            )
        )

        let export = try WorkRecordCSVExporter.makeExport(
            events: [clockIn, clockOut, incomplete],
            monthContaining: julyDate,
            headers: headers,
            locale: Locale(identifier: "en_US"),
            calendar: calendar
        )
        let sessions = WorkRecordSessionCalculator.sessions(
            from: [clockIn, clockOut, incomplete],
            in: calendar.dateInterval(of: .month, for: julyDate)!,
            calendar: calendar
        )

        XCTAssertEqual(export.recordCount, 1)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.workedMinutes, 420)
        XCTAssertTrue(String(decoding: export.data, as: UTF8.self).contains("07:00"))
        XCTAssertFalse(String(decoding: export.data, as: UTF8.self).contains("Incomplete"))
    }

    func testCSVAlwaysUsesGregorianDateAnd24HourTimeAcrossSupportedLocales() throws {
        var japaneseCalendar = Calendar(identifier: .japanese)
        japaneseCalendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let gregorian = Calendar(identifier: .gregorian)
        let day = gregorian.date(from: DateComponents(year: 2026, month: 7, day: 9))!
        let work = makeWorkRecordEvents(day: day, startHour: 9, endHour: 17)

        for localeID in ["ja_JP", "en_US", "zh_CN", "zh_TW", "ko_KR"] {
            let export = try WorkRecordCSVExporter.makeExport(
                events: [work.clockIn, work.clockOut],
                monthContaining: day,
                headers: headers,
                locale: Locale(identifier: localeID),
                calendar: japaneseCalendar
            )
            let text = String(decoding: export.data, as: UTF8.self)
            XCTAssertTrue(text.contains("2026-07-09,09:00,17:00"), localeID)
            XCTAssertFalse(text.contains("AM"), localeID)
            XCTAssertFalse(text.contains("R8"), localeID)
            XCTAssertEqual(export.fileName, "TimeNest_WorkRecords_2026-07.csv")
        }
    }

    private var headers: WorkRecordCSVHeaders {
        WorkRecordCSVHeaders(
            date: "Date",
            startTime: "Start",
            endTime: "End",
            restTime: "Break",
            workedTime: "Worked",
            recordName: "Name",
            note: "Note"
        )
    }

    private var julyDate: Date {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 7, day: 15)
        )!
    }
}

private final class RestoreNotificationSchedulerSpy: LocalNotificationScheduling {
    var resultsByEventID: [UUID: EventNotificationScheduleResult] = [:]
    private(set) var scheduledEvents: [CalendarEvent] = []
    private(set) var scheduledIdentifiers: [String] = []

    func requestAuthorizationIfNeeded() async -> Bool { true }

    func scheduleEventNotification(event: CalendarEvent) async throws -> String? {
        await scheduleEventNotificationResult(event: event).notificationID
    }

    func scheduleEventNotificationResult(event: CalendarEvent) async -> EventNotificationScheduleResult {
        scheduledEvents.append(event)
        let result = resultsByEventID[event.id]
            ?? .scheduled(event.notificationID ?? "missing-notification-id")
        if case .scheduled(let identifier) = result {
            scheduledIdentifiers.append(identifier)
        }
        return result
    }

    func cancelNotification(id: String) {}
    func scheduleDailyScheduleCheck(hour: Int, minute: Int) async {}
    func cancelDailyScheduleCheck() {}
}

private func makeCalendarEntity(
    id: UUID,
    name: String,
    kind: TimeNestCalendarKind
) -> SwiftDataCalendarEntity {
    let now = Date(timeIntervalSince1970: 1_752_883_200)
    return SwiftDataCalendarEntity(
        id: id,
        name: name,
        kindRawValue: kind.rawValue,
        zoneName: kind == .sharedOwned ? "private-zone" : nil,
        ownerName: kind == .sharedOwned ? "owner" : nil,
        rootRecordName: kind == .sharedOwned ? "root" : nil,
        shareRecordName: kind == .sharedOwned ? "share" : nil,
        createdAt: now,
        updatedAt: now
    )
}

private func makeEvent(
    id: UUID = UUID(),
    calendarID: UUID = TimeNestCalendar.personalID,
    title: String,
    note: String? = nil,
    notificationID: String? = nil,
    shiftTemplateID: ShiftTimeTemplateID? = nil,
    workInfo: WorkInfo? = nil,
    startDate: Date? = nil,
    reminderOffsetMinutes: Int? = 15
) -> CalendarEvent {
    let defaultStart = Calendar(identifier: .gregorian).date(
        from: DateComponents(year: 2026, month: 7, day: 15, hour: 9)
    )!
    let start = startDate ?? defaultStart
    return CalendarEvent(
        id: id,
        calendarID: calendarID,
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

private func makeWorkRecordEvents(
    calendarID: UUID = TimeNestCalendar.personalID,
    title: String = "Night shift",
    note: String? = nil,
    day: Date? = nil,
    startHour: Int = 9,
    endHour: Int = 17
) -> (clockIn: CalendarEvent, clockOut: CalendarEvent) {
    let calendar = Calendar(identifier: .gregorian)
    let day = day ?? calendar.date(from: DateComponents(year: 2026, month: 7, day: 15))!
    let start = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: day)!
    let end = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: day)!
    let sessionID = UUID()
    let clockIn = makeEvent(
        calendarID: calendarID,
        title: title,
        note: note,
        workInfo: WorkInfo(
            workInTime: start,
            restHours: 1,
            workDate: day,
            workSessionId: sessionID,
            isWorkOutTimeSet: true
        ),
        startDate: start
    )
    let clockOut = makeEvent(
        calendarID: calendarID,
        title: title,
        note: note,
        workInfo: WorkInfo(
            workOutTime: end,
            restHours: 1,
            workDate: day,
            workSessionId: sessionID,
            isWorkOutTimeSet: true
        ),
        startDate: end
    )
    return (clockIn, clockOut)
}
