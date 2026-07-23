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
        let viewModel = WorkStatisticsViewModel(startDate: start, endDate: start)

        viewModel.setDateRange(start: start, end: end)

        XCTAssertEqual(viewModel.endDate, start)
    }

    func testDefaultRangeUsesAnchorMonth() throws {
        let calendar = Calendar(identifier: .gregorian)
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 2, day: 14, hour: 12)))
        let viewModel = WorkStatisticsViewModel(startDate: anchor, endDate: anchor)

        viewModel.setDefaultRange(for: .month, anchorDate: anchor)

        XCTAssertEqual(calendar.component(.year, from: viewModel.startDate), 2026)
        XCTAssertEqual(calendar.component(.month, from: viewModel.startDate), 2)
        XCTAssertEqual(calendar.component(.day, from: viewModel.startDate), 1)
        XCTAssertEqual(calendar.component(.month, from: viewModel.endDate), 2)
        XCTAssertEqual(calendar.component(.day, from: viewModel.endDate), 28)
    }

    func testLoadedEmptyStatisticsStateResetsTotals() {
        let viewModel = WorkStatisticsViewModel()

        viewModel.loadEmptyStatisticsState()

        XCTAssertEqual(viewModel.statisticsData, [])
        XCTAssertEqual(viewModel.totalHours, "00:00")
        XCTAssertEqual(viewModel.totalAmount, "¥0")
    }
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
