import Foundation

struct WorkInfo: Codable, Hashable {
    var workInTime: Date?
    var workOutTime: Date?
    var restHours: Double
    var workDate: Date?
    var transportFee: Int?
    var hourlyRate: Int?
    var workSessionId: UUID?
    var isWorkOutTimeSet: Bool

    init(workInTime: Date? = nil, workOutTime: Date? = nil, restHours: Double = 1.0, workDate: Date? = nil, transportFee: Int? = nil, hourlyRate: Int? = nil, workSessionId: UUID? = nil, isWorkOutTimeSet: Bool? = nil) {
        self.workInTime = workInTime
        self.workOutTime = workOutTime
        self.restHours = restHours
        self.workDate = workDate
        self.transportFee = transportFee
        self.hourlyRate = hourlyRate
        self.workSessionId = workSessionId
        self.isWorkOutTimeSet = isWorkOutTimeSet ?? (workOutTime != nil)
    }

    private enum CodingKeys: String, CodingKey {
        case workInTime
        case workOutTime
        case restHours
        case workDate
        case transportFee
        case hourlyRate
        case workSessionId
        case isWorkOutTimeSet
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workInTime = try container.decodeIfPresent(Date.self, forKey: .workInTime)
        workOutTime = try container.decodeIfPresent(Date.self, forKey: .workOutTime)
        restHours = try container.decodeIfPresent(Double.self, forKey: .restHours) ?? 1.0
        workDate = try container.decodeIfPresent(Date.self, forKey: .workDate)
        transportFee = try container.decodeIfPresent(Int.self, forKey: .transportFee)
        hourlyRate = try container.decodeIfPresent(Int.self, forKey: .hourlyRate)
        workSessionId = try container.decodeIfPresent(UUID.self, forKey: .workSessionId)
        isWorkOutTimeSet = try container.decodeIfPresent(Bool.self, forKey: .isWorkOutTimeSet)
            ?? WorkInfo.legacyIsWorkOutTimeSet(for: workOutTime)
    }

    static func legacyIsWorkOutTimeSet(for workOutTime: Date?) -> Bool {
        guard let workOutTime else { return false }
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: workOutTime)
        return (components.hour ?? 0) != 0
            || (components.minute ?? 0) != 0
            || (components.second ?? 0) != 0
    }

    static func makeNewWorkSessionId() -> UUID {
        UUID()
    }
}

enum WorkRecordSourceID: Hashable {
    case event(UUID)
    case occurrence(String)
}

struct WorkRecordClockEntry: Hashable {
    let sourceID: WorkRecordSourceID
    let eventID: UUID
    let calendarID: UUID
    let sessionID: UUID?
    let kind: WorkClockKind
    let clockDate: Date
    let workDate: Date
    let isWorkOutTimeSet: Bool
    let restHours: Double
    let transportFee: Int?
    let hourlyRate: Int?
    let title: String
    let note: String?
    let updatedAt: Date

    init?(event: CalendarEvent) {
        guard let kind = event.workClockKind else { return nil }
        sourceID = .event(event.id)
        eventID = event.id
        calendarID = event.calendarID
        sessionID = event.workInfo?.workSessionId
        self.kind = kind
        clockDate = event.actualWorkClockDate
        workDate = event.workDate
        isWorkOutTimeSet = event.isWorkOutTimeSet
        restHours = event.workInfo?.restHours ?? 0
        transportFee = event.workInfo?.transportFee
        hourlyRate = event.workInfo?.hourlyRate
        title = event.title
        note = event.note
        updatedAt = event.updatedAt
    }

    init?(occurrence: EventOccurrence) {
        guard let kind = occurrence.workClockKind else { return nil }
        sourceID = .occurrence(occurrence.id)
        eventID = occurrence.eventID
        calendarID = occurrence.calendarID
        sessionID = occurrence.workInfo?.workSessionId
        self.kind = kind
        clockDate = occurrence.actualWorkClockDate
        workDate = occurrence.workDate
        isWorkOutTimeSet = occurrence.isWorkOutTimeSet
        restHours = occurrence.workInfo?.restHours ?? 0
        transportFee = occurrence.workInfo?.transportFee
        hourlyRate = occurrence.workInfo?.hourlyRate
        title = occurrence.title
        note = occurrence.note
        updatedAt = .distantPast
    }
}

struct AssembledWorkRecordSession: Hashable {
    let sessionID: UUID?
    let calendarID: UUID
    let workDate: Date
    let clockIn: WorkRecordClockEntry?
    let clockOut: WorkRecordClockEntry?

    var isComplete: Bool {
        clockIn != nil && clockOut?.isWorkOutTimeSet == true
    }

    var sortDate: Date {
        clockIn?.clockDate ?? clockOut?.clockDate ?? workDate
    }
}

enum WorkRecordSessionAssembler {
    private struct ModernKey: Hashable {
        let calendarID: UUID
        let sessionID: UUID
    }

    private struct LegacyKey: Hashable {
        let calendarID: UUID
        let workDay: Date
    }

    static func sessions(
        from entries: [WorkRecordClockEntry],
        calendar: Calendar = .current
    ) -> [AssembledWorkRecordSession] {
        var modernGroups: [ModernKey: [WorkRecordClockEntry]] = [:]
        var legacyGroups: [LegacyKey: [WorkRecordClockEntry]] = [:]

        for entry in entries {
            if let sessionID = entry.sessionID {
                modernGroups[
                    ModernKey(calendarID: entry.calendarID, sessionID: sessionID),
                    default: []
                ].append(entry)
            } else {
                legacyGroups[
                    LegacyKey(
                        calendarID: entry.calendarID,
                        workDay: calendar.startOfDay(for: entry.workDate)
                    ),
                    default: []
                ].append(entry)
            }
        }

        var result = modernGroups.map { key, values in
            let clockIn = values
                .filter { $0.kind == .clockIn }
                .sorted(by: clockEntryComesBefore)
                .first
            let clockOut = preferredClockOut(
                from: values.filter { $0.kind == .clockOut },
                clockIn: clockIn,
                calendar: calendar
            )
            return AssembledWorkRecordSession(
                sessionID: key.sessionID,
                calendarID: key.calendarID,
                workDate: calendar.startOfDay(
                    for: clockIn?.workDate
                        ?? clockOut?.workDate
                        ?? clockIn?.clockDate
                        ?? clockOut?.clockDate
                        ?? .distantPast
                ),
                clockIn: clockIn,
                clockOut: clockOut
            )
        }

        for (key, values) in legacyGroups {
            result.append(contentsOf: makeLegacySessions(
                values,
                key: key,
                calendar: calendar
            ))
        }

        return result.sorted {
            if $0.workDate != $1.workDate { return $0.workDate < $1.workDate }
            if $0.sortDate != $1.sortDate { return $0.sortDate < $1.sortDate }
            return stableID(for: $0) < stableID(for: $1)
        }
    }

    static func effectiveClockOutDate(
        _ clockOut: WorkRecordClockEntry,
        clockInDate: Date,
        calendar: Calendar = .current
    ) -> Date {
        let outDate = clockOut.clockDate
        let clockInDay = calendar.startOfDay(for: clockInDate)
        guard calendar.isDate(outDate, inSameDayAs: clockInDay) else {
            return outDate
        }

        // A same-day clock-out is never inferred to be the following day from
        // its time alone. An explicit later workDate remains a valid legacy
        // signal and preserves the selected time on that declared date.
        let declaredClockOutDay = calendar.startOfDay(for: clockOut.workDate)
        guard declaredClockOutDay > clockInDay else { return outDate }
        let time = calendar.dateComponents([.hour, .minute, .second], from: outDate)
        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: declaredClockOutDay
        ) ?? outDate
    }

    private static func preferredClockOut(
        from values: [WorkRecordClockEntry],
        clockIn: WorkRecordClockEntry?,
        calendar: Calendar
    ) -> WorkRecordClockEntry? {
        let explicitlySet = values
            .filter(\.isWorkOutTimeSet)
            .sorted(by: latestClockEntryComesBefore)
        guard let clockIn else {
            return explicitlySet.first
                ?? values.filter { !$0.isWorkOutTimeSet }.sorted(by: latestClockEntryComesBefore).first
        }
        return explicitlySet.first {
            isValidPair(clockIn: clockIn, clockOut: $0, calendar: calendar)
        } ?? values
            .filter { !$0.isWorkOutTimeSet }
            .sorted(by: latestClockEntryComesBefore)
            .first
    }

    private static func makeLegacySessions(
        _ values: [WorkRecordClockEntry],
        key: LegacyKey,
        calendar: Calendar
    ) -> [AssembledWorkRecordSession] {
        let clockIns = values
            .filter { $0.kind == .clockIn }
            .sorted(by: clockEntryComesBefore)
        let clockOuts = values
            .filter { $0.kind == .clockOut }
            .sorted(by: clockOutEntryComesBefore)
        let realClockOuts = clockOuts.filter(\.isWorkOutTimeSet)
        let placeholderClockOuts = clockOuts.filter { !$0.isWorkOutTimeSet }
        var usedClockOutIDs = Set<WorkRecordSourceID>()
        var sessions: [AssembledWorkRecordSession] = []

        for (index, clockIn) in clockIns.enumerated() {
            let nextClockInDate = clockIns.dropFirst(index + 1).first?.clockDate
            let matches: (WorkRecordClockEntry) -> Bool = { candidate in
                guard !usedClockOutIDs.contains(candidate.sourceID) else { return false }
                guard isValidPair(
                    clockIn: clockIn,
                    clockOut: candidate,
                    calendar: calendar
                ) else {
                    return false
                }
                let effectiveEnd = effectiveClockOutDate(
                    candidate,
                    clockInDate: clockIn.clockDate,
                    calendar: calendar
                )
                if let nextClockInDate, effectiveEnd > nextClockInDate { return false }
                return true
            }
            let clockOut = realClockOuts.first(where: matches)
                ?? placeholderClockOuts.first(where: matches)
            if let clockOut {
                usedClockOutIDs.insert(clockOut.sourceID)
            }
            sessions.append(
                AssembledWorkRecordSession(
                    sessionID: nil,
                    calendarID: key.calendarID,
                    workDate: key.workDay,
                    clockIn: clockIn,
                    clockOut: clockOut
                )
            )
        }

        for clockOut in clockOuts where !usedClockOutIDs.contains(clockOut.sourceID) {
            sessions.append(
                AssembledWorkRecordSession(
                    sessionID: nil,
                    calendarID: key.calendarID,
                    workDate: key.workDay,
                    clockIn: nil,
                    clockOut: clockOut
                )
            )
        }
        return sessions
    }

    private static func isValidPair(
        clockIn: WorkRecordClockEntry,
        clockOut: WorkRecordClockEntry,
        calendar: Calendar
    ) -> Bool {
        let effectiveEnd = effectiveClockOutDate(
            clockOut,
            clockInDate: clockIn.clockDate,
            calendar: calendar
        )
        let duration = effectiveEnd.timeIntervalSince(clockIn.clockDate)
        return duration > 0 && duration <= 24 * 3_600
    }

    private static func clockEntryComesBefore(
        _ lhs: WorkRecordClockEntry,
        _ rhs: WorkRecordClockEntry
    ) -> Bool {
        if lhs.clockDate != rhs.clockDate { return lhs.clockDate < rhs.clockDate }
        return stableSourceID(for: lhs) < stableSourceID(for: rhs)
    }

    private static func clockOutEntryComesBefore(
        _ lhs: WorkRecordClockEntry,
        _ rhs: WorkRecordClockEntry
    ) -> Bool {
        if lhs.clockDate != rhs.clockDate { return lhs.clockDate < rhs.clockDate }
        if lhs.isWorkOutTimeSet != rhs.isWorkOutTimeSet {
            return lhs.isWorkOutTimeSet
        }
        return stableSourceID(for: lhs) < stableSourceID(for: rhs)
    }

    private static func latestClockEntryComesBefore(
        _ lhs: WorkRecordClockEntry,
        _ rhs: WorkRecordClockEntry
    ) -> Bool {
        if lhs.clockDate != rhs.clockDate { return lhs.clockDate > rhs.clockDate }
        return stableSourceID(for: lhs) < stableSourceID(for: rhs)
    }

    private static func stableSourceID(for entry: WorkRecordClockEntry) -> String {
        switch entry.sourceID {
        case .event(let id):
            return "event:\(id.uuidString.lowercased())"
        case .occurrence(let id):
            return "occurrence:\(id)"
        }
    }

    private static func stableID(for session: AssembledWorkRecordSession) -> String {
        if let sessionID = session.sessionID {
            return sessionID.uuidString
        }
        return [session.clockIn, session.clockOut]
            .compactMap { entry -> String? in
                entry.map(stableSourceID)
            }
            .joined(separator: "-")
    }
}

struct WorkRecordPairSaveRequest: Hashable {
    let clockInEventID: UUID?
    let clockOutEventID: UUID?
    let calendarID: UUID
    let title: String
    let workDate: Date
    let clockInDate: Date
    let clockOutDate: Date
    let restHours: Double
    let transportFee: Int?
    let hourlyRate: Int?
    let sessionID: UUID
    let isWorkOutTimeSet: Bool
}

struct CalendarEvent: Identifiable, Codable, Hashable {
    let id: UUID
    var calendarID: UUID
    var title: String
    var note: String?
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    let categoryID: UUID?
    var recurrenceRule: RecurrenceRule
    let reminderTemplateID: UUID?
    var reminderOffsetMinutes: Int?
    var notificationID: String?
    let importSource: ImportSource?
    let createdAt: Date
    var updatedAt: Date
    var shiftTemplateID: ShiftTimeTemplateID?
    var workInfo: WorkInfo?

    init(
        id: UUID,
        calendarID: UUID = TimeNestCalendar.personalID,
        title: String,
        note: String?,
        startDate: Date,
        endDate: Date?,
        isAllDay: Bool,
        categoryID: UUID?,
        recurrenceRule: RecurrenceRule,
        reminderTemplateID: UUID?,
        reminderOffsetMinutes: Int? = nil,
        notificationID: String? = nil,
        importSource: ImportSource?,
        createdAt: Date,
        updatedAt: Date,
        shiftTemplateID: ShiftTimeTemplateID? = nil,
        workInfo: WorkInfo? = nil
    ) {
        self.id = id
        self.calendarID = calendarID
        self.title = title
        self.note = note
        self.startDate = startDate
        self.endDate = endDate ?? CalendarEvent.defaultEndDate(for: startDate, isAllDay: isAllDay)
        self.isAllDay = isAllDay
        self.categoryID = categoryID
        self.recurrenceRule = recurrenceRule
        self.reminderTemplateID = reminderTemplateID
        self.reminderOffsetMinutes = reminderOffsetMinutes
        self.notificationID = notificationID
        self.importSource = importSource
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.shiftTemplateID = shiftTemplateID
        self.workInfo = workInfo
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case calendarID
        case title
        case note
        case startDate
        case endDate
        case isAllDay
        case categoryID
        case recurrenceRule
        case reminderTemplateID
        case reminderOffsetMinutes
        case notificationID
        case importSource
        case createdAt
        case updatedAt
        case shiftTemplateID
        case workInfo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        calendarID = try container.decodeIfPresent(UUID.self, forKey: .calendarID)
            ?? TimeNestCalendar.personalID
        title = try container.decode(String.self, forKey: .title)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        startDate = try container.decode(Date.self, forKey: .startDate)
        isAllDay = try container.decode(Bool.self, forKey: .isAllDay)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate) ?? CalendarEvent.defaultEndDate(for: startDate, isAllDay: isAllDay)
        categoryID = try container.decodeIfPresent(UUID.self, forKey: .categoryID)
        recurrenceRule = try container.decodeIfPresent(RecurrenceRule.self, forKey: .recurrenceRule) ?? .none
        reminderTemplateID = try container.decodeIfPresent(UUID.self, forKey: .reminderTemplateID)
        reminderOffsetMinutes = try container.decodeIfPresent(Int.self, forKey: .reminderOffsetMinutes)
        notificationID = try container.decodeIfPresent(String.self, forKey: .notificationID)
        importSource = try container.decodeIfPresent(ImportSource.self, forKey: .importSource)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        shiftTemplateID = try container.decodeIfPresent(ShiftTimeTemplateID.self, forKey: .shiftTemplateID)
        workInfo = try container.decodeIfPresent(WorkInfo.self, forKey: .workInfo)
    }

    static func defaultEndDate(for startDate: Date, isAllDay: Bool) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        if isAllDay {
            let dayStart = calendar.startOfDay(for: startDate)
            return calendar.date(byAdding: .day, value: 1, to: dayStart) ?? startDate
        }
        return calendar.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
    }
}
