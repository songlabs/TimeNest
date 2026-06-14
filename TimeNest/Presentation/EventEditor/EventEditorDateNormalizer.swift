import Foundation

struct EventEditorDateNormalizer {
    static func normalizedDates(startDate: Date, endDate: Date, isAllDay: Bool) -> (start: Date, end: Date) {
        let calendar = Calendar(identifier: .gregorian)
        if isAllDay {
            let start = calendar.startOfDay(for: startDate)
            let endDay = calendar.startOfDay(for: endDate)
            let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
            return (start, end)
        }
        return (startDate, endDate)
    }

    static func normalizedForAllDayChange(allDay: Bool, startDate: Date, endDate: Date) -> (startDate: Date, endDate: Date) {
        let calendar = Calendar(identifier: .gregorian)
        var normalizedStartDate = startDate
        var normalizedEndDate = endDate

        if allDay {
            normalizedStartDate = calendar.startOfDay(for: normalizedStartDate)
            if normalizedEndDate < normalizedStartDate {
                normalizedEndDate = normalizedStartDate
            }
        } else {
            let startDay = calendar.startOfDay(for: normalizedStartDate)
            if normalizedStartDate == startDay {
                normalizedStartDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: normalizedStartDate) ?? normalizedStartDate
            }
            if normalizedEndDate <= normalizedStartDate {
                normalizedEndDate = CalendarEvent.defaultEndDate(for: normalizedStartDate, isAllDay: false)
            }
        }

        return (normalizedStartDate, normalizedEndDate)
    }
}
