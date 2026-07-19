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
    private struct Group {
        var clockIn: CalendarEvent?
        var clockOut: CalendarEvent?
    }

    static func sessions(
        from events: [CalendarEvent],
        in selectedRange: DateInterval,
        calendar: Calendar = .current
    ) -> [CalculatedWorkRecordSession] {
        var sessions: [UUID: Group] = [:]
        var legacyClockInsByDay: [Date: [CalendarEvent]] = [:]
        var legacyClockOutsByDay: [Date: [CalendarEvent]] = [:]

        for event in events {
            guard let kind = workClockKind(for: event) else { continue }
            guard kind != .clockOut || event.isWorkOutTimeSet else { continue }
            let workDay = calendar.startOfDay(for: event.workInfo?.workDate ?? event.startDate)

            if let sessionID = event.workInfo?.workSessionId {
                var group = sessions[sessionID] ?? Group()
                switch kind {
                case .clockIn:
                    let time = event.workInfo?.workInTime ?? event.startDate
                    if group.clockIn.map({ time < ($0.workInfo?.workInTime ?? $0.startDate) }) ?? true {
                        group.clockIn = event
                    }
                case .clockOut:
                    let time = event.workInfo?.workOutTime ?? event.startDate
                    if group.clockOut.map({ time > ($0.workInfo?.workOutTime ?? $0.startDate) }) ?? true {
                        group.clockOut = event
                    }
                }
                sessions[sessionID] = group
            } else {
                switch kind {
                case .clockIn:
                    legacyClockInsByDay[workDay, default: []].append(event)
                case .clockOut:
                    legacyClockOutsByDay[workDay, default: []].append(event)
                }
            }
        }

        for group in sessions.values {
            if let clockIn = group.clockIn, group.clockOut == nil {
                let workDay = calendar.startOfDay(for: clockIn.workInfo?.workDate ?? clockIn.startDate)
                legacyClockInsByDay[workDay, default: []].append(clockIn)
            }
            if let clockOut = group.clockOut, group.clockIn == nil {
                let workDay = calendar.startOfDay(for: clockOut.workInfo?.workDate ?? clockOut.startDate)
                legacyClockOutsByDay[workDay, default: []].append(clockOut)
            }
        }

        let legacyGroups = makeLegacyGroups(
            clockInsByDay: legacyClockInsByDay,
            clockOutsByDay: legacyClockOutsByDay,
            calendar: calendar
        )

        return (Array(sessions.values) + legacyGroups).compactMap { group in
            guard let clockIn = group.clockIn, let clockOut = group.clockOut else { return nil }
            let startTime = clockIn.workInfo?.workInTime ?? clockIn.startDate
            let endTime = effectiveClockOutTime(
                for: clockOut,
                clockInTime: startTime,
                calendar: calendar
            )
            guard endTime > startTime else { return nil }
            let day = calendar.startOfDay(
                for: clockIn.workInfo?.workDate
                    ?? clockOut.workInfo?.workDate
                    ?? startTime
            )
            guard selectedRange.contains(day) else { return nil }
            let restHours = clockIn.workInfo?.restHours ?? clockOut.workInfo?.restHours ?? 0
            let workedSeconds = max(0, endTime.timeIntervalSince(startTime) - restHours * 3600)
            return CalculatedWorkRecordSession(
                day: day,
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

    private static func makeLegacyGroups(
        clockInsByDay: [Date: [CalendarEvent]],
        clockOutsByDay: [Date: [CalendarEvent]],
        calendar: Calendar
    ) -> [Group] {
        let clockIns = clockInsByDay.values.flatMap { $0 }.sorted {
            ($0.workInfo?.workInTime ?? $0.startDate) < ($1.workInfo?.workInTime ?? $1.startDate)
        }
        let clockOuts = clockOutsByDay.values.flatMap { $0 }.sorted {
            ($0.workInfo?.workOutTime ?? $0.startDate) < ($1.workInfo?.workOutTime ?? $1.startDate)
        }
        var usedClockOutIDs = Set<UUID>()
        var groups: [Group] = []

        for (index, clockIn) in clockIns.enumerated() {
            let startTime = clockIn.workInfo?.workInTime ?? clockIn.startDate
            let nextStartTime = clockIns.dropFirst(index + 1).first.map {
                $0.workInfo?.workInTime ?? $0.startDate
            }
            guard let clockOut = clockOuts.first(where: { candidate in
                guard !usedClockOutIDs.contains(candidate.id) else { return false }
                let endTime = effectiveClockOutTime(
                    for: candidate,
                    clockInTime: startTime,
                    calendar: calendar
                )
                guard endTime > startTime else { return false }
                if let nextStartTime, endTime >= nextStartTime { return false }
                return true
            }) else {
                continue
            }
            usedClockOutIDs.insert(clockOut.id)
            groups.append(Group(clockIn: clockIn, clockOut: clockOut))
        }
        return groups
    }

    private static func effectiveClockOutTime(
        for event: CalendarEvent,
        clockInTime: Date,
        calendar: Calendar
    ) -> Date {
        let endTime = event.workInfo?.workOutTime ?? event.startDate
        guard calendar.isDate(endTime, inSameDayAs: clockInTime) else { return endTime }
        let end = calendar.dateComponents([.hour, .minute], from: endTime)
        let start = calendar.dateComponents([.hour, .minute], from: clockInTime)
        let endMinutes = (end.hour ?? 0) * 60 + (end.minute ?? 0)
        let startMinutes = (start.hour ?? 0) * 60 + (start.minute ?? 0)
        guard endMinutes <= startMinutes else { return endTime }
        return calendar.date(byAdding: .day, value: 1, to: endTime) ?? endTime
    }

    private static func workClockKind(for event: CalendarEvent) -> WorkClockKind? {
        if let kind = event.workClockKind { return kind }
        if event.workInfo?.workInTime != nil, event.workInfo?.workOutTime == nil {
            return .clockIn
        }
        if event.workInfo?.workOutTime != nil, event.workInfo?.workInTime == nil {
            return .clockOut
        }
        return nil
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
