import Foundation

class CalendarDisplayUseCase {
    private let holidayUseCase: HolidayUseCase
    private let localizationUseCase: CalendarLocalizationUseCase
    private let eventUseCase: EventUseCase

    init(
        holidayUseCase: HolidayUseCase,
        localizationUseCase: CalendarLocalizationUseCase,
        eventUseCase: EventUseCase
    ) {
        self.holidayUseCase = holidayUseCase
        self.localizationUseCase = localizationUseCase
        self.eventUseCase = eventUseCase
    }

    func monthGrid(year: Int, month: Int, setting: CalendarDisplaySetting) async throws -> MonthGrid {
        
        // 使用 Gregorian calendar 确保日期计算使用西历
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = year
        components.month = month

        guard let firstDayOfMonth = calendar.date(from: components) else {
            throw AppError.unknown
        }

        let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth) ?? (1..<31)

        let weekdaySymbols = localizationUseCase.weekdaySymbols(
            language: setting.displayLanguage,
            weekStartPolicy: setting.weekStartPolicy
        )

        let monthTitle = localizationUseCase.monthTitle(
            year: year,
            month: month,
            language: setting.displayLanguage
        )

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let weekStartOffset = weekStartOffset(for: firstWeekday, weekStartPolicy: setting.weekStartPolicy)

        // 获取当月的事件
        let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? firstDayOfMonth
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let monthInterval = DateInterval(start: monthStart, end: monthEnd)
        let occurrences = try await eventUseCase.occurrences(in: monthInterval)

        var cells: [CalendarDayCell] = []

        let today = Date()
        let todayOnly = DateOnly(from: today)

        for offsetIndex in 0..<weekStartOffset {
            let daysBefore = weekStartOffset - offsetIndex
            let date = calendar.date(byAdding: .day, value: -daysBefore, to: firstDayOfMonth) ?? firstDayOfMonth
            let dateOnly = DateOnly(from: date) ?? DateOnly(year: year, month: 1, day: 1)
            let dayText = "\(dateOnly.day)"
            let weekdayIndex = (calendar.component(.weekday, from: date) - 1 + 7) % 7
            let weekdayText = weekdaySymbols[weekdayIndex]
            let isInCurrentMonth = dateOnly.month == month && dateOnly.year == year
            let isToday = todayOnly == dateOnly
            let isWeekend = isSaturdayOrSunday(date: date, calendar: calendar)

            let dayEvents = occurrences.filter { $0.occurrenceDate.id == dateOnly.id }

            cells.append(CalendarDayCell(
                id: dateOnly.id,
                date: dateOnly,
                dayText: dayText,
                weekdayText: weekdayText,
                holidays: [],
                events: dayEvents,
                isToday: isToday,
                isWeekend: isWeekend,
                isInCurrentMonth: isInCurrentMonth,
                shiftType: nil,
                eventMarkers: []
            ))
        }

        for day in range {
            let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) ?? firstDayOfMonth
            let dateOnly = DateOnly(from: date) ?? DateOnly(year: year, month: month, day: day)
            let dayText = "\(day)"
            let weekdayIndex = (calendar.component(.weekday, from: date) - 1 + 7) % 7
            let weekdayText = weekdaySymbols[weekdayIndex]
            let isToday = todayOnly == dateOnly
            let isWeekend = isSaturdayOrSunday(date: date, calendar: calendar)

            let holidays: [Holiday] = (try? await holidayUseCase.holidaysInDateRange(
                from: dateOnly,
                to: dateOnly,
                setting: setting
            )) ?? []

            let dayEvents = occurrences.filter { $0.occurrenceDate.id == dateOnly.id }

            cells.append(CalendarDayCell(
                id: dateOnly.id,
                date: dateOnly,
                dayText: dayText,
                weekdayText: weekdayText,
                holidays: holidays,
                events: dayEvents,
                isToday: isToday,
                isWeekend: isWeekend,
                isInCurrentMonth: true,
                shiftType: nil,
                eventMarkers: []
            ))
        }

        let remainingCells = 42 - cells.count
        if remainingCells > 0 {
            let lastDayInMonth = calendar.date(byAdding: .day, value: range.upperBound - 1, to: firstDayOfMonth) ?? firstDayOfMonth
            for i in 0..<remainingCells {
                let date = calendar.date(byAdding: .day, value: i + 1, to: lastDayInMonth) ?? lastDayInMonth
                let dateOnly = DateOnly(from: date) ?? DateOnly(year: year, month: month, day: 1)
                let dayText = "\(dateOnly.day)"
                let weekdayIndex = (calendar.component(.weekday, from: date) - 1 + 7) % 7
                let weekdayText = weekdaySymbols[weekdayIndex]
                let isToday = todayOnly == dateOnly
                let isWeekend = isSaturdayOrSunday(date: date, calendar: calendar)

                let dayEvents = occurrences.filter { $0.occurrenceDate.id == dateOnly.id }

                cells.append(CalendarDayCell(
                    id: dateOnly.id,
                    date: dateOnly,
                    dayText: dayText,
                    weekdayText: weekdayText,
                    holidays: [],
                    events: dayEvents,
                    isToday: isToday,
                    isWeekend: isWeekend,
                    isInCurrentMonth: false,
                    shiftType: nil,
                    eventMarkers: []
                ))
            }
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
