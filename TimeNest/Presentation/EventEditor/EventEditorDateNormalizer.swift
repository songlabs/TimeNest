import Foundation

struct EventEditorDateNormalizer {
    static func persistenceDates(startDate: Date, inclusiveEndDate: Date, isAllDay: Bool) -> (start: Date, end: Date) {
        let calendar = Calendar(identifier: .gregorian)
        if isAllDay {
            let start = calendar.startOfDay(for: startDate)
            let selectedEndDay = calendar.startOfDay(for: inclusiveEndDate)
            let safeEndDay = max(selectedEndDay, start)
            let end = calendar.date(byAdding: .day, value: 1, to: safeEndDay) ?? safeEndDay
            return (start, end)
        }
        return (startDate, inclusiveEndDate)
    }

    static func editorDates(startDate: Date, exclusiveEndDate: Date, isAllDay: Bool) -> (start: Date, end: Date) {
        guard isAllDay else {
            return (startDate, exclusiveEndDate)
        }

        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.startOfDay(for: startDate)
        let endBoundary = calendar.startOfDay(for: exclusiveEndDate)
        let inclusiveEnd: Date

        if exclusiveEndDate > endBoundary {
            inclusiveEnd = endBoundary
        } else {
            inclusiveEnd = calendar.date(byAdding: .day, value: -1, to: endBoundary) ?? start
        }

        return (start, max(inclusiveEnd, start))
    }

    static func normalizedForAllDayChange(allDay: Bool, startDate: Date, endDate: Date) -> (startDate: Date, endDate: Date) {
        let calendar = Calendar(identifier: .gregorian)
        var normalizedStartDate = startDate
        var normalizedEndDate = endDate

        if allDay {
            let startDay = calendar.startOfDay(for: normalizedStartDate)
            let endDay = calendar.startOfDay(for: normalizedEndDate)
            normalizedStartDate = startDay
            normalizedEndDate = max(endDay, startDay)
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
