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

    func testDeletingUnusedTemplateCleansOnlyItsFavoriteAndKeepsOtherTemplate() throws {
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
        let template = ShiftBatchTemplateSnapshot(
            id: templateID,
            displayName: "History Snapshot Template",
            note: "History template note",
            colorHex: "#AF52DEFF",
            startTime: "22:30",
            endTime: "06:45",
            enabled: true
        )
        storeTemplate(
            id: templateID,
            name: template.displayName,
            note: template.note,
            colorHex: template.colorHex,
            startTime: template.startTime,
            endTime: template.endTime
        )
        let favorites = ShiftTemplateFavoritesStore(defaults: defaults)
        favorites.setFavorite(true, id: templateID)
        defaults.set([templateID.id, "missing-shift-template"], forKey: ShiftTemplateFavoritesStore.storageKey)

        let repository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(repository: repository)
        let useCase = ShiftBatchOperationUseCase(
            eventUseCase: eventUseCase,
            calendar: calendar,
            now: { self.date(2026, 7, 20, 12) }
        )
        let request = ShiftBatchRequest(
            dates: [date(2026, 7, 21)],
            mode: .template(templateID),
            calendarID: TimeNestCalendar.personalID,
            templates: [template]
        )
        let plan = try await useCase.makePlan(for: request)
        let result = try await useCase.execute(plan: plan, currentTemplates: [template])
        let before = try XCTUnwrap(result.undoSnapshot.createdEvents.first)
        let colorBeforeDeletion = try XCTUnwrap(before.shiftTemplateID).colorHex(from: defaults)

        defaults.set(true, forKey: deletedKey(for: templateID))
        let remainingIDs = ShiftTimeTemplate.all(from: defaults).map(\.id)
        let reconciledFavorites = favorites.reconcile(validTemplateIDs: remainingIDs)

        let storedAfterDeletion = try await repository.event(id: before.id)
        let after = try XCTUnwrap(storedAfterDeletion)
        let colorAfterDeletion = try XCTUnwrap(after.shiftTemplateID).colorHex(from: defaults)
        let storedEvents = try await repository.events(in: dayInterval(after.startDate))

        XCTAssertEqual(after.id, before.id)
        XCTAssertEqual(after.title, before.title)
        XCTAssertEqual(after.note, before.note)
        XCTAssertEqual(after.startDate, before.startDate)
        XCTAssertEqual(after.endDate, before.endDate)
        XCTAssertEqual(after.shiftTemplateID, before.shiftTemplateID)
        XCTAssertEqual(after.calendarID, before.calendarID)
        XCTAssertEqual(after.workInfo, before.workInfo)
        XCTAssertEqual(after.title, "History Snapshot Template")
        XCTAssertEqual(after.note, "History template note")
        XCTAssertEqual(timeComponents(after.startDate), [22, 30])
        XCTAssertEqual(timeComponents(after.endDate), [6, 45])
        XCTAssertEqual(calendar.dateComponents([.day], from: calendar.startOfDay(for: after.startDate), to: calendar.startOfDay(for: after.endDate)).day, 1)
        XCTAssertEqual(colorBeforeDeletion, "#AF52DEFF")
        XCTAssertEqual(colorAfterDeletion, colorBeforeDeletion)
        XCTAssertTrue(ShiftTimeTemplate.all(from: defaults).allSatisfy { $0.id != templateID })
        XCTAssertFalse(reconciledFavorites.contains(templateID.id))
        XCTAssertFalse(reconciledFavorites.contains("missing-shift-template"))
        XCTAssertEqual(storedEvents.map(\.id), [before.id])
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
        defaults.set(uuid.uuidString, forKey: id.uuidStorageKey)
        defaults.set(name, forKey: id.displayNameKey)
        defaults.set(note, forKey: id.noteKey)
        defaults.set(colorHex, forKey: id.colorHexKey)
        defaults.set(startTime, forKey: id.startTimeKey)
        defaults.set(endTime, forKey: id.endTimeKey)
        defaults.set(true, forKey: id.enabledKey)
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

final class ShiftBatchOperationTests: XCTestCase {
    private var calendar: Calendar!
    private var template: ShiftBatchTemplateSnapshot!
    private let calendarID = TimeNestCalendar.personalID

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        template = ShiftBatchTemplateSnapshot(
            id: .day,
            displayName: "Day",
            note: "template note",
            colorHex: "#FFD54F",
            startTime: "08:30",
            endTime: "17:30",
            enabled: true
        )
    }

    func testTemplatePlanSupportsContinuousNonContinuousAndDuplicateDates() async throws {
        let repository = InMemoryEventRepository()
        let useCase = makeUseCase(repository: repository)
        let first = date(2026, 7, 1)
        let second = date(2026, 7, 2)
        let fourth = date(2026, 7, 4)

        let continuous = try await useCase.makePlan(for: request(
            dates: [first, second],
            mode: .template(.day)
        ))
        let nonContinuous = try await useCase.makePlan(for: request(
            dates: [first, fourth, first],
            mode: .template(.day)
        ))

        XCTAssertEqual(continuous.selectedDateCount, 2)
        XCTAssertEqual(continuous.createCount, 2)
        XCTAssertEqual(nonContinuous.selectedDateCount, 2)
        XCTAssertEqual(nonContinuous.createCount, 2)
        XCTAssertEqual(nonContinuous.items.map(\.targetDate), [first, fourth])
    }

    func testEmptySelectionProducesBlockingPlan() async throws {
        let useCase = makeUseCase(repository: InMemoryEventRepository())
        let plan = try await useCase.makePlan(for: request(
            dates: [],
            mode: .template(.day)
        ))

        XCTAssertTrue(plan.issues.contains(.emptySelection))
        XCTAssertFalse(plan.canExecute)
        XCTAssertEqual(plan.createCount, 0)
    }

    func testTemplatePlanSkipsExistingShiftAndDoesNotTreatOrdinaryEventAsConflict() async throws {
        let repository = InMemoryEventRepository()
        let ordinaryDate = date(2026, 7, 3)
        let shiftDate = date(2026, 7, 4)
        try await repository.create(makeEvent(on: ordinaryDate, title: "Meeting", templateID: nil))
        try await repository.create(makeEvent(on: shiftDate, title: "Night", templateID: .night))
        let useCase = makeUseCase(repository: repository)

        let plan = try await useCase.makePlan(for: request(
            dates: [ordinaryDate, shiftDate],
            mode: .template(.day)
        ))

        XCTAssertEqual(plan.createCount, 1)
        XCTAssertEqual(plan.conflictCount, 1)
        XCTAssertEqual(plan.items.first(where: { $0.targetDate == ordinaryDate })?.status, .create)
        XCTAssertEqual(plan.items.first(where: { $0.targetDate == shiftDate })?.status, .conflict)
    }

    func testCopyPreviousDayPreservesBusinessFieldsAndMapsOvernightAcrossYear() async throws {
        let repository = InMemoryEventRepository()
        let sourceStart = date(2025, 12, 31, 22, 15)
        let sourceEnd = date(2026, 1, 1, 6, 45)
        let source = makeEvent(
            start: sourceStart,
            end: sourceEnd,
            title: "Night",
            note: "handover",
            templateID: .night,
            reminderOffsetMinutes: 30,
            notificationID: "original-notification"
        )
        try await repository.create(source)
        try await repository.create(makeEvent(
            on: date(2025, 12, 31, 9),
            title: "Clock In",
            templateID: nil,
            workInfo: WorkInfo(workInTime: date(2025, 12, 31, 9))
        ))
        let useCase = makeUseCase(repository: repository)
        let target = date(2026, 1, 1)

        let plan = try await useCase.makePlan(for: request(
            dates: [target],
            mode: .copyPreviousDay
        ))
        let copied = try XCTUnwrap(plan.eventsToCreate.first)

        XCTAssertNotEqual(copied.id, source.id)
        XCTAssertEqual(copied.title, source.title)
        XCTAssertEqual(copied.note, source.note)
        XCTAssertEqual(copied.shiftTemplateID, source.shiftTemplateID)
        XCTAssertEqual(copied.reminderOffsetMinutes, 30)
        XCTAssertNil(copied.notificationID)
        XCTAssertNil(copied.workInfo)
        XCTAssertEqual(components(copied.startDate), [2026, 1, 1, 22, 15])
        XCTAssertEqual(components(copied.endDate), [2026, 1, 2, 6, 45])
    }

    func testCopyPreviousDayShowsNoSourceAndConflictSeparately() async throws {
        let repository = InMemoryEventRepository()
        let source = date(2026, 6, 30)
        let target = date(2026, 7, 1)
        let emptyTarget = date(2026, 7, 3)
        try await repository.create(makeEvent(on: source, title: "Day", templateID: .day))
        try await repository.create(makeEvent(on: target, title: "Night", templateID: .night))
        let useCase = makeUseCase(repository: repository)

        let plan = try await useCase.makePlan(for: request(
            dates: [target, emptyTarget],
            mode: .copyPreviousDay
        ))

        XCTAssertEqual(plan.conflictCount, 1)
        XCTAssertEqual(plan.noSourceCount, 1)
        XCTAssertEqual(plan.createCount, 0)
        XCTAssertFalse(plan.canExecute)
    }

    func testCopyPreviousWeekKeepsWeekdayAcrossMonthAndWeekStartPolicies() async throws {
        let sourceDate = date(2025, 12, 29, 8, 30)
        let targetDate = date(2026, 1, 5)
        let repository = InMemoryEventRepository()
        try await repository.create(makeEvent(start: sourceDate, end: date(2025, 12, 29, 17, 30)))

        var sundayCalendar = calendar!
        sundayCalendar.firstWeekday = 1
        var mondayCalendar = calendar!
        mondayCalendar.firstWeekday = 2
        let sundayUseCase = ShiftBatchOperationUseCase(
            eventUseCase: EventUseCase(repository: repository),
            calendar: sundayCalendar
        )
        let mondayUseCase = ShiftBatchOperationUseCase(
            eventUseCase: EventUseCase(repository: repository),
            calendar: mondayCalendar
        )

        let sundayPlan = try await sundayUseCase.makePlan(for: request(
            dates: [targetDate], mode: .copyPreviousWeek
        ))
        let mondayPlan = try await mondayUseCase.makePlan(for: request(
            dates: [targetDate], mode: .copyPreviousWeek
        ))

        XCTAssertEqual(sundayPlan.items.first?.sourceDate, calendar.startOfDay(for: sourceDate))
        XCTAssertEqual(mondayPlan.items.first?.sourceDate, calendar.startOfDay(for: sourceDate))
        XCTAssertEqual(components(try XCTUnwrap(sundayPlan.eventsToCreate.first).startDate), [2026, 1, 5, 8, 30])
        XCTAssertEqual(sundayPlan.eventsToCreate.first?.startDate, mondayPlan.eventsToCreate.first?.startDate)
    }

    func testCopyPreviousWeekHandlesPartialSourcesAndConflicts() async throws {
        let repository = InMemoryEventRepository()
        let targetOne = date(2026, 7, 8)
        let targetTwo = date(2026, 7, 9)
        let targetThree = date(2026, 7, 10)
        try await repository.create(makeEvent(on: date(2026, 7, 1), templateID: .day))
        try await repository.create(makeEvent(on: date(2026, 7, 3), templateID: .night))
        try await repository.create(makeEvent(on: targetThree, templateID: .day))
        let plan = try await makeUseCase(repository: repository).makePlan(for: request(
            dates: [targetOne, targetTwo, targetThree],
            mode: .copyPreviousWeek
        ))

        XCTAssertEqual(plan.createCount, 1)
        XCTAssertEqual(plan.noSourceCount, 1)
        XCTAssertEqual(plan.conflictCount, 1)
    }

    func testRotationRepeatsWithRestDaysAndStartOffset() async throws {
        let night = ShiftBatchTemplateSnapshot(
            id: .night,
            displayName: "Night",
            note: "",
            colorHex: "#5C6BC0",
            startTime: "17:00",
            endTime: "09:00",
            enabled: true
        )
        let dates = (0..<8).compactMap {
            calendar.date(byAdding: .day, value: $0, to: date(2026, 7, 1))
        }
        let items = [
            ShiftRotationItem(selection: .template(.day)),
            ShiftRotationItem(selection: .restDay),
            ShiftRotationItem(selection: .template(.night))
        ]
        let request = ShiftBatchRequest(
            dates: dates,
            mode: .rotation(items: items, startOffset: 1),
            calendarID: calendarID,
            templates: [template, night]
        )

        let plan = try await makeUseCase(repository: InMemoryEventRepository()).makePlan(for: request)

        XCTAssertEqual(plan.items.map(\.status), [
            .restDay, .create, .create, .restDay, .create, .create, .restDay, .create
        ])
        XCTAssertEqual(plan.restDayCount, 3)
        XCTAssertEqual(plan.createCount, 5)
        XCTAssertEqual(plan.items[1].displayName, "Night")
        XCTAssertEqual(plan.items[2].displayName, "Day")
    }

    func testRotationLengthOneShortRangeLongRangeAndConflictDoNotDelete() async throws {
        let repository = InMemoryEventRepository()
        let first = date(2026, 7, 1)
        let existing = makeEvent(on: first, title: "Night", templateID: .night)
        try await repository.create(existing)
        let dates = (0..<5).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
        let plan = try await makeUseCase(repository: repository).makePlan(for: request(
            dates: dates,
            mode: .rotation(
                items: [ShiftRotationItem(selection: .template(.day))],
                startOffset: 0
            )
        ))

        XCTAssertEqual(plan.items.count, 5)
        XCTAssertEqual(plan.conflictCount, 1)
        XCTAssertEqual(plan.createCount, 4)
        XCTAssertTrue(plan.eventsToCreate.allSatisfy { $0.shiftTemplateID == .day })
        let storedExisting = try await repository.event(id: existing.id)
        XCTAssertNotNil(storedExisting)
    }

    func testRotationInvalidTemplateAndReversedRangeBlockExecution() async throws {
        let missingID = ShiftTimeTemplateID.custom(UUID())
        let invalidPlan = try await makeUseCase(repository: InMemoryEventRepository()).makePlan(
            for: request(
                dates: [date(2026, 7, 1)],
                mode: .rotation(
                    items: [ShiftRotationItem(selection: .template(missingID))],
                    startOffset: 0
                )
            )
        )
        let reversedRangePlan = try await makeUseCase(repository: InMemoryEventRepository()).makePlan(
            for: request(dates: [], mode: .rotation(items: [], startOffset: 0))
        )

        XCTAssertTrue(invalidPlan.issues.contains(.invalidTemplate))
        XCTAssertFalse(invalidPlan.canExecute)
        XCTAssertTrue(reversedRangePlan.issues.contains(.emptySelection))
    }

    func testDateMappingUsesBusinessGregorianCalendarForJapaneseCalendarAndDST() async throws {
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = japanese.timeZone
        let repository = InMemoryEventRepository()
        let sourceStart = gregorian.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1, minute: 30))!
        let sourceEnd = gregorian.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 4, minute: 30))!
        try await repository.create(makeEvent(start: sourceStart, end: sourceEnd))
        let target = gregorian.date(from: DateComponents(year: 2026, month: 3, day: 9))!
        let useCase = ShiftBatchOperationUseCase(
            eventUseCase: EventUseCase(repository: repository),
            calendar: japanese
        )

        let plan = try await useCase.makePlan(for: ShiftBatchRequest(
            dates: [target],
            mode: .copyPreviousDay,
            calendarID: calendarID,
            templates: [template]
        ))
        let event = try XCTUnwrap(plan.eventsToCreate.first)
        let start = gregorian.dateComponents([.year, .month, .day, .hour, .minute], from: event.startDate)
        let end = gregorian.dateComponents([.year, .month, .day, .hour, .minute], from: event.endDate)

        XCTAssertEqual([start.year, start.month, start.day, start.hour, start.minute], [2026, 3, 9, 1, 30])
        XCTAssertEqual([end.year, end.month, end.day, end.hour, end.minute], [2026, 3, 9, 4, 30])
    }

    func testExecuteUsesOneBatchCallAndOneChangeCallback() async throws {
        let repository = BatchEventRepositorySpy()
        let eventUseCase = EventUseCase(repository: repository)
        var callbackCount = 0
        eventUseCase.onEventsChanged = { callbackCount += 1 }
        let useCase = ShiftBatchOperationUseCase(eventUseCase: eventUseCase, calendar: calendar)
        let plan = try await useCase.makePlan(for: request(
            dates: [date(2026, 8, 1), date(2026, 8, 3)],
            mode: .template(.day)
        ))

        let result = try await useCase.execute(plan: plan, currentTemplates: [template])

        let batchCallCount = await repository.createBatchCallCount()
        let eventCount = await repository.eventCount()

        XCTAssertEqual(result.createdCount, 2)
        XCTAssertEqual(batchCallCount, 1)
        XCTAssertEqual(eventCount, 2)
        XCTAssertEqual(callbackCount, 1)
    }

    func testBatchSaveFailureLeavesNoPartialDataAndNoChangeCallback() async throws {
        let repository = BatchEventRepositorySpy()
        await repository.failNextBatchCreate()
        let eventUseCase = EventUseCase(repository: repository)
        var callbackCount = 0
        eventUseCase.onEventsChanged = { callbackCount += 1 }
        let useCase = ShiftBatchOperationUseCase(eventUseCase: eventUseCase, calendar: calendar)
        let plan = try await useCase.makePlan(for: request(
            dates: [date(2026, 8, 1), date(2026, 8, 2)],
            mode: .template(.day)
        ))

        do {
            _ = try await useCase.execute(plan: plan, currentTemplates: [template])
            XCTFail("Expected injected failure")
        } catch BatchTestError.injected {
            // Expected.
        }

        let eventCount = await repository.eventCount()
        XCTAssertEqual(eventCount, 0)
        XCTAssertEqual(callbackCount, 0)
    }

    func testExecutionStopsWhenTargetOrTemplateChangedAfterPreview() async throws {
        let repository = InMemoryEventRepository()
        let useCase = makeUseCase(repository: repository)
        let target = date(2026, 8, 1)
        let plan = try await useCase.makePlan(for: request(
            dates: [target],
            mode: .template(.day)
        ))
        try await repository.create(makeEvent(on: target, title: "Night", templateID: .night))

        await XCTAssertThrowsErrorAsync {
            _ = try await useCase.execute(plan: plan, currentTemplates: [self.template])
        } verify: { error in
            XCTAssertEqual(error as? ShiftBatchOperationError, .stalePlan)
        }

        let repositoryTwo = InMemoryEventRepository()
        let useCaseTwo = makeUseCase(repository: repositoryTwo)
        let planTwo = try await useCaseTwo.makePlan(for: request(
            dates: [target], mode: .template(.day)
        ))
        var changed = template!
        changed = ShiftBatchTemplateSnapshot(
            id: changed.id,
            displayName: changed.displayName,
            note: changed.note,
            colorHex: changed.colorHex,
            startTime: "09:00",
            endTime: changed.endTime,
            enabled: changed.enabled
        )
        await XCTAssertThrowsErrorAsync {
            _ = try await useCaseTwo.execute(plan: planTwo, currentTemplates: [changed])
        } verify: { error in
            XCTAssertEqual(error as? ShiftBatchOperationError, .stalePlan)
        }
    }

    func testUndoDeletesOnlyUneditedBatchEventsAndKeepsExistingRecords() async throws {
        let repository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(repository: repository)
        let useCase = ShiftBatchOperationUseCase(eventUseCase: eventUseCase, calendar: calendar)
        let existing = makeEvent(on: date(2026, 7, 20), title: "Existing", templateID: nil)
        try await repository.create(existing)
        let plan = try await useCase.makePlan(for: request(
            dates: [date(2026, 8, 1), date(2026, 8, 2)],
            mode: .template(.day)
        ))
        let result = try await useCase.execute(plan: plan, currentTemplates: [template])
        var edited = result.undoSnapshot.createdEvents[0]
        edited.note = "user edited"
        edited.updatedAt = date(2026, 8, 5)
        try await repository.update(edited)

        let undoResult = try await useCase.undo(snapshot: result.undoSnapshot)
        let storedEdited = try await repository.event(id: edited.id)
        let storedExisting = try await repository.event(id: existing.id)
        let storedDeleted = try await repository.event(id: result.undoSnapshot.createdEvents[1].id)

        XCTAssertEqual(undoResult.deletedCount, 1)
        XCTAssertEqual(undoResult.editedCount, 1)
        XCTAssertNotNil(storedEdited)
        XCTAssertNotNil(storedExisting)
        XCTAssertNil(storedDeleted)
    }

    func testUndoCancelsBatchNotificationsAndTriggersRefreshAgain() async throws {
        let repository = InMemoryEventRepository()
        let scheduler = EventNotificationSchedulerSpy()
        let eventUseCase = EventUseCase(
            repository: repository,
            notificationScheduler: scheduler
        )
        var callbackCount = 0
        eventUseCase.onEventsChanged = { callbackCount += 1 }
        let useCase = ShiftBatchOperationUseCase(
            eventUseCase: eventUseCase,
            calendar: calendar,
            now: { self.date(2026, 7, 20, 12) }
        )
        let source = makeEvent(
            start: date(2026, 8, 1, 8, 30),
            end: date(2026, 8, 1, 17, 30),
            reminderOffsetMinutes: 30
        )
        try await repository.create(source)
        let plan = try await useCase.makePlan(for: request(
            dates: [date(2026, 8, 2)],
            mode: .copyPreviousDay
        ))

        let result = try await useCase.execute(plan: plan, currentTemplates: [template])
        let savedEvent = try XCTUnwrap(result.undoSnapshot.createdEvents.first)
        let notificationID = try XCTUnwrap(savedEvent.notificationID)

        XCTAssertEqual(scheduler.scheduledEvents.map(\.id), [savedEvent.id])
        XCTAssertEqual(callbackCount, 1)

        let undoResult = try await useCase.undo(snapshot: result.undoSnapshot)
        let storedEvent = try await repository.event(id: savedEvent.id)

        XCTAssertEqual(undoResult.deletedCount, 1)
        XCTAssertEqual(scheduler.cancelledIDs, [notificationID])
        XCTAssertEqual(callbackCount, 2)
        XCTAssertNil(storedEvent)
    }

    func testEachSuccessfulBatchReturnsDistinctRuntimeUndoSnapshot() async throws {
        let repository = InMemoryEventRepository()
        let useCase = makeUseCase(repository: repository)
        let firstPlan = try await useCase.makePlan(for: request(
            dates: [date(2026, 8, 1)], mode: .template(.day)
        ))
        let first = try await useCase.execute(plan: firstPlan, currentTemplates: [template])
        let secondPlan = try await useCase.makePlan(for: request(
            dates: [date(2026, 8, 2)], mode: .template(.day)
        ))
        let second = try await useCase.execute(plan: secondPlan, currentTemplates: [template])

        XCTAssertNotEqual(first.undoSnapshot.batchID, second.undoSnapshot.batchID)
        XCTAssertNotEqual(first.undoSnapshot.createdEvents.map(\.id), second.undoSnapshot.createdEvents.map(\.id))
    }

    private func makeUseCase(repository: EventRepository) -> ShiftBatchOperationUseCase {
        ShiftBatchOperationUseCase(
            eventUseCase: EventUseCase(repository: repository),
            calendar: calendar,
            now: { self.date(2026, 7, 20, 12) }
        )
    }

    private func request(dates: [Date], mode: ShiftBatchMode) -> ShiftBatchRequest {
        ShiftBatchRequest(
            dates: dates,
            mode: mode,
            calendarID: calendarID,
            templates: [template]
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private func components(_ value: Date) -> [Int] {
        let result = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: value)
        return [result.year!, result.month!, result.day!, result.hour!, result.minute!]
    }

    private func dayInterval(_ value: Date) -> DateInterval {
        let start = calendar.startOfDay(for: value)
        return DateInterval(
            start: start,
            end: calendar.date(byAdding: .day, value: 1, to: start)!
        )
    }

    private func makeEvent(
        on date: Date,
        title: String = "Day",
        templateID: ShiftTimeTemplateID? = .day,
        workInfo: WorkInfo? = nil
    ) -> CalendarEvent {
        makeEvent(
            start: date,
            end: calendar.date(byAdding: .hour, value: 8, to: date)!,
            title: title,
            templateID: templateID,
            workInfo: workInfo
        )
    }

    private func makeEvent(
        start: Date,
        end: Date,
        title: String = "Day",
        note: String? = nil,
        templateID: ShiftTimeTemplateID? = .day,
        reminderOffsetMinutes: Int? = nil,
        notificationID: String? = nil,
        workInfo: WorkInfo? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: UUID(),
            calendarID: calendarID,
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
            updatedAt: start,
            shiftTemplateID: templateID,
            workInfo: workInfo
        )
    }
}

private enum BatchTestError: Error {
    case injected
}

private actor BatchEventRepositorySpy: EventRepository {
    private var storage: [UUID: CalendarEvent] = [:]
    private var batchCreateCalls = 0
    private var shouldFailBatchCreate = false

    func create(_ event: CalendarEvent) {
        storage[event.id] = event
    }

    func createBatch(_ events: [CalendarEvent], ifUnchanged expectedEvents: [CalendarEvent]) throws {
        batchCreateCalls += 1
        if shouldFailBatchCreate {
            shouldFailBatchCreate = false
            throw BatchTestError.injected
        }
        guard expectedEvents.allSatisfy({ storage[$0.id] == $0 }) else {
            throw EventRepositoryBatchError.staleData
        }
        events.forEach { storage[$0.id] = $0 }
    }

    func applyBatch(
        upserting events: [CalendarEvent],
        deleting eventsToDelete: [CalendarEvent],
        ifUnchanged expectedEvents: [CalendarEvent]
    ) throws {
        try EventRepositoryBatchValidator.validateApplyBatch(
            currentEvents: Array(storage.values),
            upserting: events,
            deleting: eventsToDelete,
            ifUnchanged: expectedEvents
        )
        var updated = storage
        events.forEach { updated[$0.id] = $0 }
        for event in eventsToDelete {
            updated[event.id] = nil
        }
        storage = updated
    }

    func update(_ event: CalendarEvent) {
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
        storage.values.filter { $0.startDate < range.end && $0.endDate > range.start }
    }

    func event(id: UUID) -> CalendarEvent? {
        storage[id]
    }

    func reassignEvents(from sourceCalendarID: UUID, to targetCalendarID: UUID) {
        for (id, var event) in storage where event.calendarID == sourceCalendarID {
            event.calendarID = targetCalendarID
            storage[id] = event
        }
    }

    func failNextBatchCreate() {
        shouldFailBatchCreate = true
    }

    func createBatchCallCount() -> Int { batchCreateCalls }
    func eventCount() -> Int { storage.count }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: () async throws -> T,
    verify: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {
        verify(error)
    }
}
