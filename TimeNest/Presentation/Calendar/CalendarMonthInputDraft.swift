import Foundation

/// Transient editor state. OCR candidates retain their recognition evidence here;
/// neither editing nor making a confirmation snapshot writes calendar data.
struct CalendarMonthInputRow: Identifiable, Equatable {
    var candidate: CalendarImportCandidate
    let isBaseRow: Bool
    private(set) var shiftTemplateID: ShiftTimeTemplateID?
    private(set) var shiftColorHex: String?
    private(set) var ocrSource: CalendarImportCandidate?
    private(set) var isUserEdited = false

    var id: UUID { candidate.id }
    var spansMidnight: Bool {
        guard let start = candidate.startTimeMinutes,
              let end = candidate.endTimeMinutes else { return false }
        return end <= start
    }

    var isValidForSaving: Bool {
        guard !candidate.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let start = candidate.startTimeMinutes,
              let end = candidate.endTimeMinutes else { return false }
        return (0..<1440).contains(start) && (0..<1440).contains(end)
    }

    init(date: Date, calendarID: UUID, isBaseRow: Bool = true) {
        candidate = CalendarImportCandidate(
            id: UUID(), date: date, startTimeMinutes: 9 * 60,
            endTimeMinutes: 17 * 60 + 30, title: "", originalText: "",
            personToken: nil, confidence: 1, quality: .standard,
            isSelected: true, needsReview: false, targetCalendarID: calendarID,
            includesPersonTokenInTitle: false
        )
        self.isBaseRow = isBaseRow
    }

    init(candidate: CalendarImportCandidate, isBaseRow: Bool) {
        self.candidate = candidate
        self.isBaseRow = isBaseRow
        ocrSource = candidate
    }

    mutating func setTitle(_ title: String) {
        candidate.title = title
        // Typing is an explicit choice of an ordinary event, even if its name
        // happens to match a saved template.
        shiftTemplateID = nil
        shiftColorHex = nil
        isUserEdited = true
    }

    mutating func selectShift(_ template: ShiftTimeTemplate) {
        candidate.title = template.displayName
        candidate.includesPersonTokenInTitle = false
        shiftTemplateID = template.id
        shiftColorHex = template.colorHex
        if let start = template.startHourMinute {
            candidate.startTimeMinutes = start.hour * 60 + start.minute
        }
        if let end = template.endHourMinute {
            candidate.endTimeMinutes = end.hour * 60 + end.minute
        }
        isUserEdited = true
    }

    mutating func setTime(_ minutes: Int, isStart: Bool) {
        if isStart {
            candidate.startTimeMinutes = minutes
        } else {
            candidate.endTimeMinutes = minutes
        }
        isUserEdited = true
    }

    func makeEvent(calendar: Calendar = Calendar(identifier: .gregorian)) throws -> CalendarEvent {
        guard isValidForSaving,
              let startMinutes = candidate.startTimeMinutes,
              let endMinutes = candidate.endTimeMinutes else {
            throw EventUseCaseError.invalidDateRange
        }
        let day = calendar.startOfDay(for: candidate.date)
        // Match existing shift entry: an end at/before the start belongs to tomorrow.
        // Set wall-clock times on each date, rather than adding 24 hours across DST.
        guard let endDay = calendar.date(byAdding: .day, value: spansMidnight ? 1 : 0, to: day),
              let start = calendar.date(bySettingHour: startMinutes / 60,
                                        minute: startMinutes % 60, second: 0, of: day),
              let end = calendar.date(bySettingHour: endMinutes / 60,
                                      minute: endMinutes % 60, second: 0, of: endDay),
              end > start else { throw EventUseCaseError.invalidDateRange }
        let now = Date()
        return CalendarEvent(
            id: id, calendarID: candidate.targetCalendarID, title: candidate.effectiveTitle,
            note: nil, startDate: start, endDate: end, isAllDay: false,
            categoryID: nil, recurrenceRule: .none, reminderTemplateID: nil,
            reminderOffsetMinutes: nil, notificationID: nil, importSource: nil,
            createdAt: now, updatedAt: now, shiftTemplateID: shiftTemplateID, workInfo: nil
        )
    }
}

struct CalendarMonthInputDraft: Equatable {
    let month: Date
    var rows: [CalendarMonthInputRow]
    private(set) var confirmationRows: [CalendarMonthInputRow] = []

    init(month: Date, calendarID: UUID, calendar: Calendar = Calendar(identifier: .gregorian)) {
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
            ?? calendar.startOfDay(for: month)
        self.month = firstDay
        rows = (calendar.range(of: .day, in: .month, for: firstDay) ?? 1..<1).compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay).map {
                CalendarMonthInputRow(date: $0, calendarID: calendarID)
            }
        }
    }

    var validRows: [CalendarMonthInputRow] { rows.filter(\.isValidForSaving) }

    mutating func prepareConfirmation() {
        confirmationRows = validRows
    }

    mutating func setTargetCalendarID(_ id: UUID) {
        for index in rows.indices { rows[index].candidate.targetCalendarID = id }
        for index in confirmationRows.indices { confirmationRows[index].candidate.targetCalendarID = id }
    }

    mutating func addRow(on date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) {
        guard let lastIndex = rows.lastIndex(where: { calendar.isDate($0.candidate.date, inSameDayAs: date) }) else {
            return
        }
        rows.insert(CalendarMonthInputRow(
            date: rows[lastIndex].candidate.date,
            calendarID: rows[lastIndex].candidate.targetCalendarID, isBaseRow: false
        ), at: lastIndex + 1)
    }

    mutating func deleteRow(id: UUID) {
        rows.removeAll { $0.id == id && !$0.isBaseRow }
    }

    mutating func prefill(
        from candidates: [CalendarImportCandidate],
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        // Rescanning the same evidence must not duplicate rows or undo manual edits.
        // Match against the previous scan with multiplicity: two identical OCR
        // appointments in one scan are still two independent input rows.
        var previousSources = rows.compactMap(\.ocrSource)
        for candidate in candidates {
            guard calendar.isDate(candidate.date, equalTo: month, toGranularity: .month) else { continue }
            if let index = previousSources.firstIndex(where: { source in
                calendar.isDate(source.date, inSameDayAs: candidate.date)
                    && source.originalText == candidate.originalText
                    && source.title == candidate.title
                    && source.startTimeMinutes == candidate.startTimeMinutes
                    && source.endTimeMinutes == candidate.endTimeMinutes
            }) {
                previousSources.remove(at: index)
                continue
            }
            if let index = rows.firstIndex(where: {
                calendar.isDate($0.candidate.date, inSameDayAs: candidate.date)
                    && $0.candidate.title.isEmpty && !$0.isUserEdited && $0.ocrSource == nil
            }) {
                rows[index] = CalendarMonthInputRow(candidate: candidate, isBaseRow: rows[index].isBaseRow)
            } else if let index = rows.lastIndex(where: {
                calendar.isDate($0.candidate.date, inSameDayAs: candidate.date)
            }) {
                rows.insert(CalendarMonthInputRow(candidate: candidate, isBaseRow: false), at: index + 1)
            }
        }
    }

    static func dateText(
        _ date: Date, locale: Locale, calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "d（EEE）"
        return formatter.string(from: date)
    }
}
