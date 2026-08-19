import XCTest
@testable import TimeNest

final class ShiftTemplateFavoritesStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "ShiftTemplateFavoritesStoreTests"

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

    func testFavoriteUnfavoriteAndEmptyState() {
        let store = ShiftTemplateFavoritesStore(defaults: defaults)
        XCTAssertTrue(store.favoriteIDs().isEmpty)

        store.setFavorite(true, id: .day)
        XCTAssertTrue(store.isFavorite(.day))
        XCTAssertEqual(store.favoriteIDs(), [ShiftTimeTemplateID.day.id])

        store.setFavorite(false, id: .day)
        XCTAssertFalse(store.isFavorite(.day))
        XCTAssertTrue(store.favoriteIDs().isEmpty)
    }

    func testReconcileRemovesDeletedTemplateIdentifiersWithoutChangingValidOrder() {
        let custom = ShiftTimeTemplateID.custom(UUID())
        let store = ShiftTemplateFavoritesStore(defaults: defaults)
        store.setFavorite(true, id: .day)
        store.setFavorite(true, id: custom)
        store.setFavorite(true, id: .night)

        let result = store.reconcile(validTemplateIDs: [.day, .night])

        XCTAssertEqual(result, [ShiftTimeTemplateID.day.id, ShiftTimeTemplateID.night.id])
        XCTAssertFalse(result.contains(custom.id))
    }
}

final class ShiftTemplatePersistenceGateTests: XCTestCase {
    private var defaults: UserDefaults!
    private var calendar: Calendar!
    private let suiteName = "ShiftTemplatePersistenceGateTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        calendar = nil
        super.tearDown()
    }

    func testCustomTemplateReloadsMultilineNoteTimesAndColor() throws {
        let id = ShiftTimeTemplateID.custom(
            UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        )
        storeTemplate(
            id: id,
            name: "UITest Early Shift",
            note: "模板备注，\"quoted\"\n2 行目",
            colorHex: "#34C759FF",
            startTime: "07:30",
            endTime: "16:15"
        )

        let reloaded = try XCTUnwrap(
            ShiftTimeTemplate.all(from: defaults).first(where: { $0.id == id })
        )

        XCTAssertEqual(reloaded.displayName, "UITest Early Shift")
        XCTAssertEqual(reloaded.note, "模板备注，\"quoted\"\n2 行目")
        XCTAssertEqual(reloaded.startTime, "07:30")
        XCTAssertEqual(reloaded.endTime, "16:15")
        XCTAssertEqual(reloaded.colorHex, "#34C759FF")
        XCTAssertNotEqual(reloaded.colorHex, id.defaultColorHex)
    }

    func testDeletingUnusedTemplateCleansOnlyItsFavoriteAndKeepsOtherTemplate() {
        let deletedID = ShiftTimeTemplateID.custom(
            UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        )
        let retainedID = ShiftTimeTemplateID.custom(
            UUID(uuidString: "99999999-8888-7777-6666-555555555555")!
        )
        storeTemplate(id: deletedID, name: "Delete Me")
        storeTemplate(id: retainedID, name: "Keep Me")
        let favorites = ShiftTemplateFavoritesStore(defaults: defaults)
        favorites.setFavorite(true, id: deletedID)
        favorites.setFavorite(true, id: retainedID)

        defaults.set(true, forKey: deletedKey(for: deletedID))
        let remaining = ShiftTimeTemplate.all(from: defaults)
        let reconciled = favorites.reconcile(validTemplateIDs: remaining.map(\.id))

        XCTAssertFalse(remaining.contains(where: { $0.id == deletedID }))
        XCTAssertTrue(remaining.contains(where: { $0.id == retainedID }))
        XCTAssertEqual(reconciled, [retainedID.id])
    }

    func testDeletingReferencedTemplatePreservesHistoricalShiftSnapshotAndColor() async throws {
        let templateID = ShiftTimeTemplateID.custom(
            UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF")!
        )
        let start = date(2026, 7, 21, 22, 30)
        let end = date(2026, 7, 22, 6, 45)
        storeTemplate(
            id: templateID,
            name: "History Snapshot Template",
            note: "History template note",
            colorHex: "#AF52DEFF",
            startTime: "22:30",
            endTime: "06:45"
        )
        let favorites = ShiftTemplateFavoritesStore(defaults: defaults)
        favorites.setFavorite(true, id: templateID)
        defaults.set(
            [templateID.id, "missing-shift-template"],
            forKey: ShiftTemplateFavoritesStore.storageKey
        )

        let repository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(repository: repository)
        let historicalShift = CalendarEvent(
            id: UUID(uuidString: "33333333-4444-5555-6666-777777777777")!,
            title: "History Snapshot Template",
            note: "History template note",
            startDate: start,
            endDate: end,
            isAllDay: false,
            categoryID: nil,
            recurrenceRule: .none,
            reminderTemplateID: nil,
            importSource: nil,
            createdAt: start,
            updatedAt: start,
            shiftTemplateID: templateID
        )
        try await eventUseCase.createEvent(historicalShift)
        let colorBeforeDeletion = templateID.colorHex(from: defaults)

        defaults.set(true, forKey: deletedKey(for: templateID))
        let remainingIDs = ShiftTimeTemplate.all(from: defaults).map(\.id)
        let reconciledFavorites = favorites.reconcile(validTemplateIDs: remainingIDs)

        let storedAfterDeletion = try await repository.event(id: historicalShift.id)
        let after = try XCTUnwrap(storedAfterDeletion)
        let colorAfterDeletion = templateID.colorHex(from: defaults)
        let storedEvents = try await repository.events(in: dayInterval(start))

        XCTAssertEqual(after, historicalShift)
        XCTAssertEqual(after.title, "History Snapshot Template")
        XCTAssertEqual(after.note, "History template note")
        XCTAssertEqual(timeComponents(after.startDate), [22, 30])
        XCTAssertEqual(timeComponents(after.endDate), [6, 45])
        XCTAssertEqual(
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: after.startDate),
                to: calendar.startOfDay(for: after.endDate)
            ).day,
            1
        )
        XCTAssertEqual(colorBeforeDeletion, "#AF52DEFF")
        XCTAssertEqual(colorAfterDeletion, colorBeforeDeletion)
        XCTAssertTrue(ShiftTimeTemplate.all(from: defaults).allSatisfy { $0.id != templateID })
        XCTAssertFalse(reconciledFavorites.contains(templateID.id))
        XCTAssertFalse(reconciledFavorites.contains("missing-shift-template"))
        XCTAssertEqual(storedEvents.map(\.id), [historicalShift.id])
    }

    func testSharedShiftCopyPersistsIndependentCustomTemplateWithSnapshotColorAndTimes() async throws {
        let start = date(2026, 8, 10, 13, 30)
        let end = date(2026, 8, 10, 22, 15)
        let snapshot = SharedShiftSnapshot(
            id: UUID(),
            registeredDate: calendar.startOfDay(for: start),
            displayName: "Late Shift",
            startDate: start,
            endDate: end,
            spansMidnight: false,
            colorHex: "#AF52DEFF",
            updatedAt: start
        )
        let repository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(
            repository: repository,
            shiftTemplateDefaults: defaults
        )

        let copies = try await eventUseCase.overwritePersonalCalendar(
            targetCalendarID: TimeNestCalendar.personalID,
            sharedEvents: [],
            sharedShifts: [snapshot],
            sharedWorkRecords: [],
            scope: .all,
            calendar: calendar
        )

        let copiedShift = try XCTUnwrap(copies.first)
        let copiedTemplateID = try XCTUnwrap(copiedShift.shiftTemplateID)
        guard case .custom(let copiedTemplateUUID) = copiedTemplateID else {
            XCTFail("An unmatched shared shift must create a custom template.")
            return
        }
        XCTAssertNotEqual(copiedTemplateUUID, snapshot.id)
        XCTAssertEqual(copiedShift.title, "Late Shift")

        let reloaded = try XCTUnwrap(
            ShiftTimeTemplate.all(from: defaults).first(where: { $0.id == copiedTemplateID })
        )
        XCTAssertEqual(reloaded.displayName, "Late Shift")
        XCTAssertEqual(reloaded.note, "")
        XCTAssertEqual(reloaded.colorHex, "#AF52DEFF")
        XCTAssertEqual(reloaded.startTime, "13:30")
        XCTAssertEqual(reloaded.endTime, "22:15")
        XCTAssertTrue(reloaded.enabled)
        XCTAssertEqual(copiedTemplateID.colorHex(from: defaults), "#AF52DEFF")

        let storedCopy = try await repository.event(id: copiedShift.id)
        XCTAssertEqual(storedCopy?.shiftTemplateID, copiedTemplateID)
        XCTAssertEqual(storedCopy?.startDate, snapshot.startDate)
        XCTAssertEqual(storedCopy?.endDate, snapshot.endDate)
    }

    func testSharedShiftCopyDoesNotReuseSameNameTemplateWithDifferentColor() async throws {
        let existingTemplateID = ShiftTimeTemplateID.custom(UUID())
        storeTemplate(
            id: existingTemplateID,
            name: "Late Shift",
            colorHex: "#34C759FF",
            startTime: "08:00",
            endTime: "16:00"
        )
        let start = date(2026, 8, 11, 13, 30)
        let end = date(2026, 8, 11, 22, 15)
        let snapshot = SharedShiftSnapshot(
            id: UUID(),
            registeredDate: calendar.startOfDay(for: start),
            displayName: "Late Shift",
            startDate: start,
            endDate: end,
            spansMidnight: false,
            colorHex: "#AF52DEFF",
            updatedAt: start
        )
        let repository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(
            repository: repository,
            shiftTemplateDefaults: defaults
        )

        let copies = try await eventUseCase.overwritePersonalCalendar(
            targetCalendarID: TimeNestCalendar.personalID,
            sharedEvents: [],
            sharedShifts: [snapshot],
            sharedWorkRecords: [],
            scope: .all,
            calendar: calendar
        )

        let copiedTemplateID = try XCTUnwrap(copies.first?.shiftTemplateID)
        XCTAssertNotEqual(copiedTemplateID, existingTemplateID)
        guard case .custom(_) = copiedTemplateID else {
            XCTFail("A color mismatch must use a new custom template.")
            return
        }
        let templates = ShiftTimeTemplate.all(from: defaults)
        let existingTemplate = try XCTUnwrap(
            templates.first(where: { $0.id == existingTemplateID })
        )
        let copiedTemplate = try XCTUnwrap(
            templates.first(where: { $0.id == copiedTemplateID })
        )
        XCTAssertEqual(existingTemplate.colorHex, "#34C759FF")
        XCTAssertEqual(existingTemplate.startTime, "08:00")
        XCTAssertEqual(existingTemplate.endTime, "16:00")
        XCTAssertEqual(copiedTemplate.displayName, "Late Shift")
        XCTAssertEqual(copiedTemplate.colorHex, "#AF52DEFF")
        XCTAssertEqual(copiedTemplate.startTime, "13:30")
        XCTAssertEqual(copiedTemplate.endTime, "22:15")
    }

    func testMultipleMatchingSharedShiftsCreateOnlyOneCustomTemplate() async throws {
        let snapshots = (10...12).map { day -> SharedShiftSnapshot in
            let start = date(2026, 8, day, 13, 30)
            return SharedShiftSnapshot(
                id: UUID(),
                registeredDate: calendar.startOfDay(for: start),
                displayName: "Late Shift",
                startDate: start,
                endDate: date(2026, 8, day, 22, 15),
                spansMidnight: false,
                colorHex: "#AF52DEFF",
                updatedAt: start
            )
        }
        let repository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(
            repository: repository,
            shiftTemplateDefaults: defaults
        )

        let copies = try await eventUseCase.overwritePersonalCalendar(
            targetCalendarID: TimeNestCalendar.personalID,
            sharedEvents: [],
            sharedShifts: snapshots,
            sharedWorkRecords: [],
            scope: .all,
            calendar: calendar
        )

        XCTAssertEqual(copies.count, 3)
        let copiedTemplateIDs = Set(copies.compactMap(\.shiftTemplateID))
        XCTAssertEqual(copiedTemplateIDs.count, 1)
        let copiedTemplateID = try XCTUnwrap(copiedTemplateIDs.first)
        let customTemplates = ShiftTimeTemplate.all(from: defaults).filter {
            if case .custom = $0.id { return true }
            return false
        }
        XCTAssertEqual(customTemplates.count, 1)
        let template = try XCTUnwrap(customTemplates.first)
        XCTAssertEqual(template.id, copiedTemplateID)
        XCTAssertEqual(template.displayName, "Late Shift")
        XCTAssertEqual(template.colorHex, "#AF52DEFF")
        XCTAssertEqual(template.startTime, "13:30")
        XCTAssertEqual(template.endTime, "22:15")
    }

    private func storeTemplate(
        id: ShiftTimeTemplateID,
        name: String,
        note: String = "",
        colorHex: String = "#FFD54FFF",
        startTime: String = "08:30",
        endTime: String = "17:30"
    ) {
        guard case .custom(let uuid) = id else {
            XCTFail("Gate fixtures must use custom template identifiers")
            return
        }
        ShiftTimeTemplate(
            id: .custom(uuid),
            nameKey: id.nameKey,
            displayName: name,
            note: note,
            colorHex: colorHex,
            startTime: startTime,
            endTime: endTime,
            enabled: true
        ).persist(to: defaults)
    }

    private func deletedKey(for id: ShiftTimeTemplateID) -> String {
        "shiftTemplate.deleted.\(id.id)"
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private func timeComponents(_ date: Date) -> [Int] {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return [components.hour!, components.minute!]
    }

    private func dayInterval(_ date: Date) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        return DateInterval(
            start: start,
            end: calendar.date(byAdding: .day, value: 1, to: start)!
        )
    }
}
