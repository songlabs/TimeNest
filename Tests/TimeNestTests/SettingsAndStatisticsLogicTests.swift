import XCTest
@testable import TimeNest

final class ShiftTimeTemplateLogicTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "ShiftTimeTemplateLogicTests"

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

    func testDefaultTemplatesLoadWithExpectedTimesAndEnabledState() {
        let templates = ShiftTimeTemplate.all(from: defaults)

        XCTAssertEqual(templates.map(\.id), [.day, .night])
        XCTAssertEqual(templates.first(where: { $0.id == .day })?.startTime, "08:30")
        XCTAssertEqual(templates.first(where: { $0.id == .day })?.endTime, "17:30")
        XCTAssertEqual(templates.first(where: { $0.id == .night })?.startTime, "17:00")
        XCTAssertEqual(templates.first(where: { $0.id == .night })?.endTime, "09:00")
        XCTAssertTrue(templates.allSatisfy(\.enabled))
    }

    func testStoredFixedTemplateValuesAreLoadedAndEnabledFiltersDisabledTemplates() {
        defaults.set("早班", forKey: ShiftTimeTemplateID.day.displayNameKey)
        defaults.set("07:15", forKey: ShiftTimeTemplateID.day.startTimeKey)
        defaults.set("16:45", forKey: ShiftTimeTemplateID.day.endTimeKey)
        defaults.set(false, forKey: ShiftTimeTemplateID.night.enabledKey)

        let templates = ShiftTimeTemplate.all(from: defaults)
        let enabledTemplates = ShiftTimeTemplate.enabled(from: defaults)

        let day = templates.first(where: { $0.id == .day })
        XCTAssertEqual(day?.displayName, "早班")
        XCTAssertEqual(day?.startTime, "07:15")
        XCTAssertEqual(day?.endTime, "16:45")
        XCTAssertEqual(enabledTemplates.map(\.id), [.day])
    }

    func testCustomTemplateIsDiscoveredFromUserDefaults() throws {
        let uuid = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let id = ShiftTimeTemplateID.custom(uuid)
        defaults.set(uuid.uuidString, forKey: id.uuidStorageKey)
        defaults.set("深夜班", forKey: id.displayNameKey)
        defaults.set("22:00", forKey: id.startTimeKey)
        defaults.set("06:00", forKey: id.endTimeKey)
        defaults.set(false, forKey: id.enabledKey)

        let custom = try XCTUnwrap(ShiftTimeTemplate.all(from: defaults).first(where: { $0.id == id }))

        XCTAssertEqual(custom.displayName, "深夜班")
        XCTAssertEqual(custom.startHourMinute?.hour, 22)
        XCTAssertEqual(custom.endHourMinute?.hour, 6)
        XCTAssertFalse(custom.enabled)
    }

    func testDeletingBothBuiltInTemplatesProducesLoadedEmptyCollection() {
        defaults.set(true, forKey: "shiftTemplate.deleted.day")
        defaults.set(true, forKey: "shiftTemplate.deleted.night")

        XCTAssertTrue(ShiftTimeTemplate.all(from: defaults).isEmpty)
    }

    func testHourMinuteRejectsInvalidTimes() {
        XCTAssertEqual(ShiftTimeTemplate.hourMinute(from: "23:59")?.hour, 23)
        XCTAssertNil(ShiftTimeTemplate.hourMinute(from: "24:00"))
        XCTAssertNil(ShiftTimeTemplate.hourMinute(from: "09:60"))
        XCTAssertNil(ShiftTimeTemplate.hourMinute(from: "bad"))
    }
}

@MainActor
final class WorkStatisticsViewModelLogicTests: XCTestCase {
    func testSetDateRangeClampsEndDateWhenEndMonthIsBeforeStartMonth() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1)))
        let viewModel = WorkStatisticsViewModel(
            calendarID: TimeNestCalendar.personalID,
            startDate: start,
            endDate: start
        )

        viewModel.setDateRange(start: start, end: end)

        XCTAssertEqual(viewModel.endDate, start)
    }

    func testDefaultRangeUsesAnchorMonth() throws {
        let calendar = Calendar(identifier: .gregorian)
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 2, day: 14, hour: 12)))
        let viewModel = WorkStatisticsViewModel(
            calendarID: TimeNestCalendar.personalID,
            startDate: anchor,
            endDate: anchor
        )

        viewModel.setDefaultRange(for: .month, anchorDate: anchor)

        XCTAssertEqual(calendar.component(.year, from: viewModel.startDate), 2026)
        XCTAssertEqual(calendar.component(.month, from: viewModel.startDate), 2)
        XCTAssertEqual(calendar.component(.day, from: viewModel.startDate), 1)
        XCTAssertEqual(calendar.component(.month, from: viewModel.endDate), 2)
        XCTAssertEqual(calendar.component(.day, from: viewModel.endDate), 28)
    }

    func testLoadedEmptyStatisticsStateResetsTotals() {
        let viewModel = WorkStatisticsViewModel(calendarID: TimeNestCalendar.personalID)

        viewModel.loadEmptyStatisticsState()

        XCTAssertEqual(viewModel.statisticsData, [])
        XCTAssertEqual(viewModel.totalHours, "00:00")
        XCTAssertEqual(
            viewModel.totalAmount,
            JPYCurrencyFormatter.string(
                amount: 0,
                locale: LocalizationManager.shared.currentLocale
            )
        )
    }

    func testJPYCurrencyFormattingUsesGroupingWithoutFractionDigits() {
        let formatted = JPYCurrencyFormatter.string(
            amount: 1_234_567,
            locale: Locale(identifier: "ja_JP")
        )

        XCTAssertTrue(formatted.contains("1,234,567"))
        XCTAssertFalse(formatted.contains(".00"))
        XCTAssertTrue(formatted.contains("¥") || formatted.contains("￥"))
    }

    func testStatisticsUsesExplicitPersonalAndOwnedCalendarScopes() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 18))
        )
        let ownedCalendarID = UUID()
        let repository = InMemoryEventRepository()
        for event in makeStatisticsPair(
            calendarID: TimeNestCalendar.personalID,
            day: day,
            clockOutHour: 17,
            hourlyRate: 1_000
        ) + makeStatisticsPair(
            calendarID: ownedCalendarID,
            day: day,
            clockOutHour: 13,
            hourlyRate: 3_000
        ) {
            try await repository.create(event)
        }
        let viewModel = WorkStatisticsViewModel(
            eventUseCase: EventUseCase(repository: repository),
            calendarID: TimeNestCalendar.personalID,
            startDate: day,
            endDate: day
        )

        viewModel.calculateStatistics()
        await waitForStatisticsToSettle(viewModel)
        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertEqual(viewModel.totalHours, "08:00")
        XCTAssertEqual(viewModel.statisticsData.count, 1)

        viewModel.setCalendarScope(calendarID: ownedCalendarID)
        viewModel.calculateStatistics()
        await waitForStatisticsToSettle(viewModel)
        XCTAssertEqual(viewModel.calendarID, ownedCalendarID)
        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertEqual(viewModel.totalHours, "04:00")
        XCTAssertEqual(viewModel.statisticsData.count, 1)
    }

    func testStatisticsFailureIsDistinctFromEmptyAndCanRetry() async throws {
        let repository = StatisticsEventRepositoryStub(
            responses: [[]],
            shouldFail: true
        )
        let viewModel = WorkStatisticsViewModel(
            eventUseCase: EventUseCase(repository: repository),
            calendarID: TimeNestCalendar.personalID
        )

        viewModel.calculateStatistics()
        await waitForStatisticsToSettle(viewModel)

        guard case .failed(let message) = viewModel.loadState else {
            return XCTFail("Expected failed statistics state")
        }
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(viewModel.statisticsData.isEmpty)

        await repository.setShouldFail(false)
        viewModel.calculateStatistics()
        await waitForStatisticsToSettle(viewModel)

        XCTAssertEqual(viewModel.loadState, .empty)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testStaleCancelledStatisticsRequestCannotOverwriteNewScope() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 18))
        )
        let ownedCalendarID = UUID()
        let personalEvents = makeStatisticsPair(
            calendarID: TimeNestCalendar.personalID,
            day: day,
            clockOutHour: 17,
            hourlyRate: 1_000
        )
        let ownedEvents = makeStatisticsPair(
            calendarID: ownedCalendarID,
            day: day,
            clockOutHour: 12,
            hourlyRate: 2_000
        )
        let repository = StatisticsEventRepositoryStub(
            responses: [personalEvents, ownedEvents],
            suspendFirstResponse: true
        )
        let viewModel = WorkStatisticsViewModel(
            eventUseCase: EventUseCase(repository: repository),
            calendarID: TimeNestCalendar.personalID,
            startDate: day,
            endDate: day
        )

        viewModel.calculateStatistics()
        await waitForRepositoryCalls(repository, count: 1)
        viewModel.setCalendarScope(calendarID: ownedCalendarID)
        viewModel.calculateStatistics()
        await waitForRepositoryCalls(repository, count: 2)
        await waitForStatisticsToSettle(viewModel)

        XCTAssertEqual(viewModel.totalHours, "03:00")
        XCTAssertEqual(viewModel.calendarID, ownedCalendarID)

        await repository.releaseFirstResponse()
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(viewModel.totalHours, "03:00")
        XCTAssertEqual(viewModel.loadState, .loaded)
    }

    func testStatisticsDatesUseSharedUserVisibleFormatter() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 18))
        )
        let viewModel = WorkStatisticsViewModel(
            calendarID: TimeNestCalendar.personalID,
            startDate: day,
            endDate: day
        )

        XCTAssertEqual(
            viewModel.formattedStartDate,
            LocalizationManager.shared.formattedUserVisibleDate(for: day)
        )
        XCTAssertEqual(
            viewModel.formattedEndDate,
            LocalizationManager.shared.formattedUserVisibleDate(for: day)
        )
    }

    private func makeStatisticsPair(
        calendarID: UUID,
        day: Date,
        clockOutHour: Int,
        hourlyRate: Int
    ) -> [CalendarEvent] {
        let calendar = Calendar(identifier: .gregorian)
        let clockInDate = calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: day
        )!
        let clockOutDate = calendar.date(
            bySettingHour: clockOutHour,
            minute: 0,
            second: 0,
            of: day
        )!
        let sessionID = UUID()

        return [
            CalendarEvent(
                id: UUID(),
                calendarID: calendarID,
                title: "Work",
                note: nil,
                startDate: clockInDate,
                endDate: clockInDate.addingTimeInterval(3_600),
                isAllDay: false,
                categoryID: nil,
                recurrenceRule: .none,
                reminderTemplateID: nil,
                importSource: nil,
                createdAt: clockInDate,
                updatedAt: clockInDate,
                workInfo: WorkInfo(
                    workInTime: clockInDate,
                    restHours: 0,
                    workDate: day,
                    hourlyRate: hourlyRate,
                    workSessionId: sessionID,
                    isWorkOutTimeSet: true
                )
            ),
            CalendarEvent(
                id: UUID(),
                calendarID: calendarID,
                title: "Work",
                note: nil,
                startDate: clockOutDate,
                endDate: clockOutDate.addingTimeInterval(3_600),
                isAllDay: false,
                categoryID: nil,
                recurrenceRule: .none,
                reminderTemplateID: nil,
                importSource: nil,
                createdAt: clockOutDate,
                updatedAt: clockOutDate,
                workInfo: WorkInfo(
                    workOutTime: clockOutDate,
                    restHours: 0,
                    workDate: day,
                    hourlyRate: hourlyRate,
                    workSessionId: sessionID,
                    isWorkOutTimeSet: true
                )
            )
        ]
    }

    private func waitForStatisticsToSettle(
        _ viewModel: WorkStatisticsViewModel
    ) async {
        for _ in 0..<200 {
            if !viewModel.isLoading {
                return
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("Statistics calculation did not settle")
    }

    private func waitForRepositoryCalls(
        _ repository: StatisticsEventRepositoryStub,
        count: Int
    ) async {
        for _ in 0..<200 {
            if await repository.eventRequestCount >= count {
                return
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("Repository did not receive \(count) requests")
    }
}

private enum StatisticsRepositoryError: Error {
    case fetchFailed
}

private actor StatisticsEventRepositoryStub: EventRepository {
    private let responses: [[CalendarEvent]]
    private let suspendFirstResponse: Bool
    private var shouldFail: Bool
    private var requestCount = 0
    private var mutationStorage: [UUID: CalendarEvent]
    private var firstResponseContinuation: CheckedContinuation<[CalendarEvent], Never>?

    init(
        responses: [[CalendarEvent]],
        shouldFail: Bool = false,
        suspendFirstResponse: Bool = false
    ) {
        self.responses = responses
        self.shouldFail = shouldFail
        self.suspendFirstResponse = suspendFirstResponse
        self.mutationStorage = (responses.first ?? []).reduce(into: [:]) {
            $0[$1.id] = $1
        }
    }

    var eventRequestCount: Int {
        requestCount
    }

    func setShouldFail(_ shouldFail: Bool) {
        self.shouldFail = shouldFail
    }

    func releaseFirstResponse() {
        firstResponseContinuation?.resume(returning: responses.first ?? [])
        firstResponseContinuation = nil
    }

    func create(_ event: CalendarEvent) async throws {}

    func applyBatch(
        upserting events: [CalendarEvent],
        deleting eventsToDelete: [CalendarEvent],
        ifUnchanged expectedEvents: [CalendarEvent]
    ) async throws {
        try EventRepositoryBatchValidator.validateApplyBatch(
            currentEvents: Array(mutationStorage.values),
            upserting: events,
            deleting: eventsToDelete,
            ifUnchanged: expectedEvents
        )
        var updated = mutationStorage
        events.forEach { updated[$0.id] = $0 }
        eventsToDelete.forEach { updated[$0.id] = nil }
        mutationStorage = updated
    }

    func update(_ event: CalendarEvent) async throws {}
    func delete(id: UUID) async throws {}
    func deleteBatch(_ expectedEvents: [CalendarEvent]) async throws {}

    func events(in range: DateInterval) async throws -> [CalendarEvent] {
        requestCount += 1
        let currentRequest = requestCount
        if shouldFail {
            throw StatisticsRepositoryError.fetchFailed
        }
        let responseIndex = min(currentRequest - 1, max(responses.count - 1, 0))
        let response = responses.isEmpty ? [] : responses[responseIndex]
        if suspendFirstResponse, currentRequest == 1 {
            return await withCheckedContinuation { continuation in
                firstResponseContinuation = continuation
            }
        }
        return response
    }

    func event(id: UUID) async throws -> CalendarEvent? {
        mutationStorage[id]
    }

    func reassignEvents(from sourceCalendarID: UUID, to targetCalendarID: UUID) async throws {}
}

final class EventEditorDateNormalizerTests: XCTestCase {
    func testAllDayDatesNormalizeToStartOfDayAndExclusiveNextDayEnd() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 15, minute: 30)))
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 8)))

        let normalized = EventEditorDateNormalizer.persistenceDates(startDate: start, inclusiveEndDate: end, isAllDay: true)

        XCTAssertEqual(normalized.start, calendar.startOfDay(for: start))
        XCTAssertEqual(normalized.end, calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)))
    }

    func testTimedDatesAreKeptUnchanged() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 9)))
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 18)))

        let normalized = EventEditorDateNormalizer.persistenceDates(startDate: start, inclusiveEndDate: end, isAllDay: false)

        XCTAssertEqual(normalized.start, start)
        XCTAssertEqual(normalized.end, end)
    }

    func testTurningAllDayOffUsesDefaultOneHourEndWhenEndIsNotAfterStart() throws {
        let calendar = Calendar(identifier: .gregorian)
        let midnight = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10)))

        let normalized = EventEditorDateNormalizer.normalizedForAllDayChange(
            allDay: false,
            startDate: midnight,
            endDate: midnight
        )

        XCTAssertEqual(calendar.component(.hour, from: normalized.startDate), 9)
        XCTAssertEqual(normalized.endDate, CalendarEvent.defaultEndDate(for: normalized.startDate, isAllDay: false))
    }
}

final class WorkClockTitleMatcherTests: XCTestCase {
    func testKindRecognizesSupportedLocalizedTitlesAndWhitespace() {
        for title in ["出勤", "Clock In", "上班", "출근", "  Clock In\n"] {
            XCTAssertEqual(WorkClockTitleMatcher.kind(for: title), .clockIn)
        }
        for title in ["退勤", "Clock Out", "下班", "퇴근", "\t退勤 "] {
            XCTAssertEqual(WorkClockTitleMatcher.kind(for: title), .clockOut)
        }
        XCTAssertNil(WorkClockTitleMatcher.kind(for: "Custom shift"))
    }
}

final class CalendarTimelineEventMetricsTests: XCTestCase {
    func testTimelineCalculationsUseSharedHourScale() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 20, hour: 9, minute: 30)))
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 20, hour: 11)))

        XCTAssertEqual(CalendarTimelineEventMetrics.minutesFromStartOfDay(start), 9 * 60 + 30)
        XCTAssertEqual(CalendarTimelineEventMetrics.minutesBetween(start, end), 90)
        XCTAssertEqual(CalendarTimelineEventMetrics.verticalOffset(for: start), 9.5 * CalendarTimelineLayout.hourHeight)
        XCTAssertEqual(
            CalendarTimelineEventMetrics.eventHeight(from: start, to: end, minimumHeight: 24),
            1.5 * CalendarTimelineLayout.hourHeight
        )
    }

    func testTimelineEventGroupingAndOrdering() throws {
        let calendar = Calendar(identifier: .gregorian)
        let morning = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 20, hour: 9)))
        let afternoon = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 20, hour: 15)))
        let events = [
            occurrence(title: "B", startDate: morning, isAllDay: true),
            occurrence(title: "Later", startDate: afternoon, isAllDay: false),
            occurrence(title: "A", startDate: morning, isAllDay: true),
            occurrence(title: "Earlier", startDate: morning, isAllDay: false)
        ]

        XCTAssertEqual(CalendarTimelineEventMetrics.allDayEvents(in: events).map(\.title), ["A", "B"])
        XCTAssertEqual(CalendarTimelineEventMetrics.timedEvents(in: events).map(\.title), ["Earlier", "Later"])
        XCTAssertEqual(CalendarTimelineEventMetrics.allDayEventCount(in: events), 2)
    }

    private func occurrence(title: String, startDate: Date, isAllDay: Bool) -> EventOccurrence {
        EventOccurrence(
            id: UUID().uuidString,
            eventID: UUID(),
            occurrenceDate: DateOnly(from: startDate)!,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(60 * 60),
            isAllDay: isAllDay,
            title: title,
            note: nil,
            categoryID: nil,
            reminderOffsetMinutes: nil,
            notificationID: nil,
            shiftTemplateID: nil,
            workInfo: nil
        )
    }
}
