import Foundation

struct CalculatedWorkRecordSession {
    let day: Date
    let clockIn: CalendarEvent
    let clockOut: CalendarEvent
    let startTime: Date
    let endTime: Date
    let restHours: Double
    let workedSeconds: TimeInterval
    let workedMinutes: Int

    var recordName: String {
        for title in [clockIn.title, clockOut.title] {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, WorkClockTitleMatcher.kind(for: trimmed) == nil {
                return trimmed
            }
        }
        return LocalizationManager.shared.localized(.workRecordDefaultTitle)
    }

    var note: String {
        var values: [String] = []
        for value in [clockIn.note, clockOut.note].compactMap({ $0 }) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !values.contains(trimmed) {
                values.append(trimmed)
            }
        }
        return values.joined(separator: "\n")
    }
}

enum WorkRecordSessionCalculator {
    static func sessions(
        from events: [CalendarEvent],
        in selectedRange: DateInterval,
        calendar: Calendar = .current
    ) -> [CalculatedWorkRecordSession] {
        var eventsByID: [UUID: CalendarEvent] = [:]
        for event in events {
            eventsByID[event.id] = event
        }

        let entries = events.compactMap(WorkRecordClockEntry.init(event:))
        return WorkRecordSessionAssembler.sessions(from: entries, calendar: calendar)
            .compactMap { session in
                guard session.isComplete,
                      let clockInEntry = session.clockIn,
                      let clockOutEntry = session.clockOut,
                      case .event(let clockInID) = clockInEntry.sourceID,
                      case .event(let clockOutID) = clockOutEntry.sourceID,
                      let clockIn = eventsByID[clockInID],
                      let clockOut = eventsByID[clockOutID] else {
                    return nil
                }
                let startTime = clockInEntry.clockDate
                let endTime = WorkRecordSessionAssembler.effectiveClockOutDate(
                    clockOutEntry,
                    clockInDate: startTime,
                    calendar: calendar
                )
                guard endTime > startTime,
                      selectedRange.contains(session.workDate) else {
                    return nil
                }
                let restHours = clockInEntry.restHours
                let workedSeconds = max(
                    0,
                    endTime.timeIntervalSince(startTime) - restHours * 3_600
                )
                return CalculatedWorkRecordSession(
                    day: session.workDate,
                    clockIn: clockIn,
                    clockOut: clockOut,
                    startTime: startTime,
                    endTime: endTime,
                    restHours: restHours,
                    workedSeconds: workedSeconds,
                    workedMinutes: Int(workedSeconds / 60)
                )
            }
            .sorted {
                if $0.day != $1.day { return $0.day < $1.day }
                return $0.startTime < $1.startTime
            }
    }
}

enum WorkRecordCSVExportError: Error, Equatable {
    case noData
    case invalidMonth
}

struct WorkRecordCSVHeaders: Equatable {
    let date: String
    let startTime: String
    let endTime: String
    let restTime: String
    let workedTime: String
    let recordName: String
    let note: String

    var values: [String] {
        [date, startTime, endTime, restTime, workedTime, recordName, note]
    }
}

struct WorkRecordCSVExport {
    let data: Data
    let fileName: String
    let recordCount: Int
}

enum WorkRecordCSVExporter {
    static func makeExport(
        events: [CalendarEvent],
        monthContaining date: Date,
        headers: WorkRecordCSVHeaders,
        locale: Locale,
        calendar: Calendar = .current
    ) throws -> WorkRecordCSVExport {
        guard let monthRange = calendar.dateInterval(of: .month, for: date) else {
            throw WorkRecordCSVExportError.invalidMonth
        }
        let sessions = WorkRecordSessionCalculator.sessions(
            from: events,
            in: monthRange,
            calendar: calendar
        )
        guard !sessions.isEmpty else { throw WorkRecordCSVExportError.noData }

        let exportCalendar = gregorianCalendar(timeZone: calendar.timeZone)
        let dateFormatter = stableFormatter(
            format: "yyyy-MM-dd",
            calendar: exportCalendar
        )
        let timeFormatter = stableFormatter(
            format: "HH:mm",
            calendar: exportCalendar
        )

        let rows = sessions.map { session in
            [
                dateFormatter.string(from: session.day),
                timeFormatter.string(from: session.startTime),
                timeFormatter.string(from: session.endTime),
                duration(minutes: Int((session.restHours * 60).rounded())),
                duration(minutes: session.workedMinutes),
                session.recordName,
                session.note
            ]
        }
        let csv = ([headers.values] + rows)
            .map { $0.map(escape).joined(separator: ",") }
            .joined(separator: "\r\n") + "\r\n"
        let data = Data(("\u{FEFF}" + csv).utf8)
        let fileCalendar = exportCalendar
        let year = fileCalendar.component(.year, from: monthRange.start)
        let month = fileCalendar.component(.month, from: monthRange.start)
        return WorkRecordCSVExport(
            data: data,
            fileName: String(format: "TimeNest_WorkRecords_%04d-%02d.csv", year, month),
            recordCount: sessions.count
        )
    }

    static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"")
                || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func duration(minutes: Int) -> String {
        String(format: "%02d:%02d", max(0, minutes) / 60, max(0, minutes) % 60)
    }

    private static func gregorianCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar
    }

    private static func stableFormatter(format: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter
    }
}
