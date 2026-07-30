import Foundation

class CalendarDisplayUseCase {
    private let holidayUseCase: HolidayUseCase
    private let localizationUseCase: CalendarLocalizationUseCase
    private let eventUseCase: EventUseCase
    private let traditionalCalendarProvider: TraditionalCalendarProvider

    init(
        holidayUseCase: HolidayUseCase,
        localizationUseCase: CalendarLocalizationUseCase,
        eventUseCase: EventUseCase,
        traditionalCalendarProvider: TraditionalCalendarProvider = TraditionalCalendarProvider()
    ) {
        self.holidayUseCase = holidayUseCase
        self.localizationUseCase = localizationUseCase
        self.eventUseCase = eventUseCase
        self.traditionalCalendarProvider = traditionalCalendarProvider
    }

    func monthGrid(
        year: Int,
        month: Int,
        setting: CalendarDisplaySetting,
        calendarID: UUID = TimeNestCalendar.personalID
    ) async throws -> MonthGrid {
        
        // 使用 Gregorian calendar 确保日期计算使用西历
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = year
        components.month = month

        guard let firstDayOfMonth = calendar.date(from: components) else {
            throw AppError.unknown
        }

        let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth) ?? (1..<31)
        let daysInMonth = range.count

        let weekdaySymbols = localizationUseCase.weekdaySymbols(
            language: setting.displayLanguage,
            weekStartPolicy: setting.weekStartPolicy
        )
        let dateWeekdaySymbols = localizationUseCase.weekdaySymbols(
            language: setting.displayLanguage,
            weekStartPolicy: .sunday
        )

        let monthTitle = localizationUseCase.monthTitle(
            year: year,
            month: month,
            language: setting.displayLanguage
        )

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let weekStartOffset = weekStartOffset(for: firstWeekday, weekStartPolicy: setting.weekStartPolicy)

        let totalCells = Int(ceil(Double(weekStartOffset + daysInMonth) / 7.0)) * 7
        let gridStartDate = calendar.date(byAdding: .day, value: -weekStartOffset, to: firstDayOfMonth) ?? firstDayOfMonth
        let gridEndDate = calendar.date(byAdding: .day, value: totalCells, to: gridStartDate) ?? gridStartDate

        // 按实际月历网格取事件，确保相邻月份日期和跨月周完整。
        let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? firstDayOfMonth
        let gridInterval = DateInterval(start: gridStartDate, end: gridEndDate)
        let occurrences = try await eventUseCase.occurrences(
            in: gridInterval,
            calendarID: calendarID
        )
        let occurrencesByDate = Dictionary(grouping: occurrences, by: { $0.occurrenceDate.id })

        let firstDate = DateOnly(from: monthStart) ?? DateOnly(year: year, month: month, day: 1)
        let lastDate = DateOnly(year: year, month: month, day: daysInMonth)
        let holidays = (try? await holidayUseCase.holidaysInDateRange(
            from: firstDate,
            to: lastDate,
            setting: setting
        )) ?? []
        let holidaysByDate = Dictionary(grouping: holidays, by: \.date)

        let gridDates: [(date: Date, dateOnly: DateOnly)] = (0..<totalCells).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: gridStartDate) ?? gridStartDate
            let dateOnly = DateOnly(from: date, in: calendar.timeZone)
                ?? DateOnly(year: year, month: month, day: 1)
            return (date, dateOnly)
        }

        let traditionalPreferences = TraditionalCalendarPreferences(
            showLunarCalendar: setting.showLunarCalendar,
            showRokuyo: setting.showRokuyo,
            showSolarTerms: setting.showSolarTerms
        )
        let currentMonthDates = gridDates
            .map(\.dateOnly)
            .filter { $0.year == year && $0.month == month }
        let traditionalDisplays = traditionalCalendarProvider.displays(
            for: currentMonthDates,
            preferences: traditionalPreferences,
            language: setting.displayLanguage,
            timeZone: calendar.timeZone
        )

        var cells: [CalendarDayCell] = []
        cells.reserveCapacity(totalCells)

        let today = Date()
        let todayOnly = DateOnly(from: today)

        for (date, dateOnly) in gridDates {
            let dayText = "\(dateOnly.day)"
            let weekdayIndex = (calendar.component(.weekday, from: date) - 1 + 7) % 7
            let weekdayText = dateWeekdaySymbols[weekdayIndex]
            let isInCurrentMonth = dateOnly.month == month && dateOnly.year == year
            let isToday = todayOnly == dateOnly
            let isWeekend = isSaturdayOrSunday(date: date, calendar: calendar)

            let holidays = isInCurrentMonth ? holidaysByDate[dateOnly] ?? [] : []

            let dayEvents = occurrencesByDate[dateOnly.id] ?? []

            cells.append(CalendarDayCell(
                id: dateOnly.id,
                date: dateOnly,
                dayText: dayText,
                weekdayText: weekdayText,
                holidays: holidays,
                events: dayEvents,
                isToday: isToday,
                isWeekend: isWeekend,
                isInCurrentMonth: isInCurrentMonth,
                shiftType: nil,
                eventMarkers: [],
                traditionalCalendar: traditionalDisplays[dateOnly] ?? .empty
            ))
        }

        return MonthGrid(
            title: monthTitle,
            weekdaySymbols: weekdaySymbols,
            days: cells
        )
    }

    private func weekStartOffset(for weekday: Int, weekStartPolicy: WeekStartPolicy) -> Int {
        let systemWeekStart = Calendar.current.firstWeekday

        let actualWeekStart: Int
        switch weekStartPolicy {
        case .sunday:
            actualWeekStart = 1
        case .monday:
            actualWeekStart = 2
        case .saturday:
            actualWeekStart = 7
        case .system:
            actualWeekStart = systemWeekStart
        }

        let offset = (weekday - actualWeekStart + 7) % 7
        return offset
    }

    private func isSaturdayOrSunday(date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
}
