import Foundation

// MARK: - 排班标签类型

// ShiftType 改为用户输入的字符串，UI 只负责显示
typealias ShiftType = String

// MARK: - 事件标记类型

enum EventMarkerType {
    case clover
    case memo
    case car
    case health
    case dot
}

// MARK: - Month Grid Models

/// Date text priority shared by the month calendar and monthly input/review.
enum CalendarDateDisplayKind: Equatable {
    case normal
    case saturday
    case sundayOrHoliday

    static func resolve(weekday: Int, isHoliday: Bool) -> Self {
        if isHoliday || weekday == 1 { return .sundayOrHoliday }
        return weekday == 7 ? .saturday : .normal
    }
}

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

    // 排班相关字段
    let shiftType: ShiftType?
    let eventMarkers: [EventMarkerType]
    let traditionalCalendar: TraditionalCalendarDisplay

    init(
        id: String,
        date: DateOnly,
        dayText: String,
        weekdayText: String,
        holidays: [Holiday],
        events: [EventOccurrence],
        isToday: Bool,
        isWeekend: Bool,
        isInCurrentMonth: Bool,
        shiftType: ShiftType?,
        eventMarkers: [EventMarkerType],
        traditionalCalendar: TraditionalCalendarDisplay = .empty
    ) {
        self.id = id
        self.date = date
        self.dayText = dayText
        self.weekdayText = weekdayText
        self.holidays = holidays
        self.events = events
        self.isToday = isToday
        self.isWeekend = isWeekend
        self.isInCurrentMonth = isInCurrentMonth
        self.shiftType = shiftType
        self.eventMarkers = eventMarkers
        self.traditionalCalendar = traditionalCalendar
    }

    // 空 cell（用于占位）
    static let empty = CalendarDayCell(
        id: "empty",
        date: DateOnly(year: 2000, month: 1, day: 1),
        dayText: "",
        weekdayText: "",
        holidays: [],
        events: [],
        isToday: false,
        isWeekend: false,
        isInCurrentMonth: false,
        shiftType: nil,
        eventMarkers: []
    )
}
