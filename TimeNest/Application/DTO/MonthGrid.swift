import Foundation

struct MonthGrid: Hashable {
    let title: String
    let weekdaySymbols: [String]
    let days: [CalendarDayCell]
}

struct CalendarDayCell: Identifiable, Hashable {
    let id: String
    let date: DateOnly
    let dayText: String
    let weekdayText: String
    let holidays: [Holiday]
    let events: [EventOccurrence]
    let isToday: Bool
    let isWeekend: Bool
    let isInCurrentMonth: Bool
}
