import Foundation

@MainActor
final class WidgetSnapshotBuilder {
    private let calendarDisplayUseCase: CalendarDisplayUseCase
    private let eventUseCase: EventUseCase
    private let holidayUseCase: HolidayUseCase
    private let holidaySubscriptionManager: HolidaySubscriptionManager

    convenience init(
        calendarDisplayUseCase: CalendarDisplayUseCase,
        eventUseCase: EventUseCase,
        holidayUseCase: HolidayUseCase
    ) {
        self.init(
            calendarDisplayUseCase: calendarDisplayUseCase,
            eventUseCase: eventUseCase,
            holidayUseCase: holidayUseCase,
            holidaySubscriptionManager: .shared
        )
    }

    init(
        calendarDisplayUseCase: CalendarDisplayUseCase,
        eventUseCase: EventUseCase,
        holidayUseCase: HolidayUseCase,
        holidaySubscriptionManager: HolidaySubscriptionManager
    ) {
        self.calendarDisplayUseCase = calendarDisplayUseCase
        self.eventUseCase = eventUseCase
        self.holidayUseCase = holidayUseCase
        self.holidaySubscriptionManager = holidaySubscriptionManager
    }

    func build(now: Date = Date()) async throws -> WidgetSnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let language = LocalizationManager.shared.currentLanguage
        let weekStartPolicy = WeekStartPolicy(
            rawValue: UserDefaults.standard.string(forKey: "weekStart") ?? "system"
        ) ?? .system
        let setting = CalendarDisplaySetting(
            displayLanguage: language,
            selectedHolidayRegions: holidaySubscriptionManager.enabledRegions,
            weekStartPolicy: weekStartPolicy,
            showLunarCalendar: false
        )

        let currentMonthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) ?? calendar.startOfDay(for: now)
        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) ?? currentMonthStart
        let twoMonthEnd = calendar.date(byAdding: .month, value: 2, to: currentMonthStart) ?? nextMonthStart

        let currentGrid = try await monthGrid(for: currentMonthStart, setting: setting, calendar: calendar)
        let nextGrid = try await monthGrid(for: nextMonthStart, setting: setting, calendar: calendar)
        let months = [
            makeMonth(from: currentGrid, displayedDate: currentMonthStart, now: now),
            makeMonth(from: nextGrid, displayedDate: nextMonthStart, now: now)
        ]

        let weekStart = startOfWeek(containing: now, policy: weekStartPolicy, calendar: calendar)
        let queryStart = min(weekStart, currentMonthStart)
        let occurrences = try await eventUseCase.occurrences(
            in: DateInterval(start: queryStart, end: twoMonthEnd)
        )
        let events = occurrences.map(makeEvent)

        let holidays = try await holidayUseCase.holidaysInDateRange(
            from: DateOnly(from: queryStart) ?? DateOnly(year: 2000, month: 1, day: 1),
            to: DateOnly(from: calendar.date(byAdding: .day, value: -1, to: twoMonthEnd) ?? twoMonthEnd)
                ?? DateOnly(year: 2000, month: 1, day: 1),
            setting: setting
        )
        let holidayEvents = holidays.map(makeHolidayEvent)
        let allEvents = (events + holidayEvents).sorted(by: eventSort)

        let todayStart = calendar.startOfDay(for: now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        let todayEvents = allEvents.filter { $0.date >= todayStart && $0.date < tomorrowStart }
        let weekEvents = allEvents.filter { $0.date >= weekStart && $0.date < weekEnd }
        let monthEvents = allEvents.filter { $0.date >= currentMonthStart && $0.date < nextMonthStart }
        let upcoming = allEvents.filter { $0.date >= todayStart }.prefix(5)

        return WidgetSnapshot(
            generatedAt: now,
            currentDate: now,
            languageCode: LocalizationManager.shared.currentLanguageCode,
            weekStartPolicy: weekStartPolicy.rawValue,
            weekdaySymbols: currentGrid.weekdaySymbols,
            months: months,
            todayEvents: todayEvents,
            weekEvents: weekEvents,
            monthEvents: monthEvents,
            upcomingEvents: Array(upcoming),
            todayShift: todayEvents.first { $0.kind == .shift },
            todayHoliday: todayEvents.first { $0.kind == .holiday }
        )
    }

    private func monthGrid(
        for date: Date,
        setting: CalendarDisplaySetting,
        calendar: Calendar
    ) async throws -> MonthGrid {
        try await calendarDisplayUseCase.monthGrid(
            year: calendar.component(.year, from: date),
            month: calendar.component(.month, from: date),
            setting: setting
        )
    }

    private func makeMonth(from grid: MonthGrid, displayedDate: Date, now: Date) -> WidgetSnapshotMonth {
        let calendar = Calendar(identifier: .gregorian)
        return WidgetSnapshotMonth(
            year: calendar.component(.year, from: displayedDate),
            month: calendar.component(.month, from: displayedDate),
            title: grid.title,
            days: grid.days.map { cell in
                let date = cell.date.toDate()
                let dayEvents = cell.holidays.map(makeHolidayEvent) + cell.events.map(makeEvent)
                return WidgetSnapshotDay(
                    id: cell.id,
                    date: date,
                    day: cell.date.day,
                    weekday: calendar.component(.weekday, from: date),
                    isInDisplayedMonth: cell.isInCurrentMonth,
                    isToday: calendar.isDate(date, inSameDayAs: now),
                    events: dayEvents.sorted(by: eventSort)
                )
            }
        )
    }

    private func makeEvent(_ occurrence: EventOccurrence) -> WidgetSnapshotEvent {
        let isShift = occurrence.shiftTemplateID != nil
        let title = isShift
            ? ShiftTimeTemplate.localizedDisplayName(
                for: occurrence.title,
                templateID: occurrence.shiftTemplateID
            )
            : occurrence.title
        return WidgetSnapshotEvent(
            id: occurrence.id,
            date: occurrence.occurrenceDate.toDate(),
            title: title,
            kind: isShift ? .shift : .event,
            colorHex: isShift ? "#AF52DE" : "#0A84FF",
            isAllDay: occurrence.isAllDay,
            startText: occurrence.isAllDay ? nil : timeText(occurrence.startDate),
            endText: occurrence.isAllDay ? nil : timeText(occurrence.endDate)
        )
    }

    private func makeHolidayEvent(_ holiday: Holiday) -> WidgetSnapshotEvent {
        WidgetSnapshotEvent(
            id: "holiday-\(holiday.id)",
            date: holiday.date.toDate(),
            title: holiday.localizedNames.displayName(for: holiday.region),
            kind: .holiday,
            colorHex: "#FF3B30",
            isAllDay: true,
            startText: nil,
            endText: nil
        )
    }

    private func timeText(_ date: Date) -> String {
        LocalizationManager.shared.dateFormatter(dateFormat: "HH:mm").string(from: date)
    }

    private func startOfWeek(
        containing date: Date,
        policy: WeekStartPolicy,
        calendar: Calendar
    ) -> Date {
        let firstWeekday: Int
        switch policy {
        case .sunday: firstWeekday = 1
        case .monday: firstWeekday = 2
        case .saturday: firstWeekday = 7
        case .system: firstWeekday = Calendar.current.firstWeekday
        }
        let dayStart = calendar.startOfDay(for: date)
        let offset = (calendar.component(.weekday, from: dayStart) - firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: dayStart) ?? dayStart
    }

    private func eventSort(_ lhs: WidgetSnapshotEvent, _ rhs: WidgetSnapshotEvent) -> Bool {
        if lhs.date != rhs.date { return lhs.date < rhs.date }
        if lhs.kind != rhs.kind { return eventPriority(lhs.kind) < eventPriority(rhs.kind) }
        return (lhs.startText ?? "") < (rhs.startText ?? "")
    }

    private func eventPriority(_ kind: WidgetSnapshotEventKind) -> Int {
        switch kind {
        case .holiday: return 0
        case .shift: return 1
        case .event: return 2
        }
    }
}
