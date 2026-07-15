import Foundation

enum CalendarSelection: Codable, Equatable, Hashable {
    case mine
    case shared(String)

    var sharedCalendarID: String? {
        guard case .shared(let id) = self else { return nil }
        return id
    }
}

struct CalendarSelectionPersistence {
    static let defaultKey = "calendarSharing.selectedCalendar"

    let defaults: UserDefaults
    let key: String

    init(defaults: UserDefaults = .standard, key: String = Self.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> CalendarSelection {
        guard let data = defaults.data(forKey: key),
              let stored = try? JSONDecoder().decode(CalendarSelection.self, from: data) else {
            return .mine
        }
        return stored
    }

    func load(validSharedCalendarIDs: Set<String>) -> CalendarSelection {
        Self.resolved(load(), validSharedCalendarIDs: validSharedCalendarIDs)
    }

    func save(_ selection: CalendarSelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: key)
    }

    static func resolved(
        _ selection: CalendarSelection,
        validSharedCalendarIDs: Set<String>
    ) -> CalendarSelection {
        guard case .shared(let id) = selection,
              validSharedCalendarIDs.contains(id) else {
            return .mine
        }
        return .shared(id)
    }
}

struct SharedCalendarDescriptor: Codable, Identifiable, Hashable {
    let id: String
    let zoneName: String
    let ownerName: String
    var displayName: String?
    var calendarName: String?
    var participantCount: Int
    var contentConfiguration: SharedContentConfiguration? = nil

    var sharedContent: SharedContentConfiguration {
        contentConfiguration ?? .legacyDefault
    }

    func resolvedDisplayName(fallback: String) -> String {
        Self.nonempty(displayName) ?? Self.nonempty(calendarName) ?? fallback
    }

    func resolvedCalendarName(fallback: String) -> String {
        Self.nonempty(calendarName) ?? Self.nonempty(displayName) ?? fallback
    }

    var distinctDisplayName: String? {
        guard let displayName = Self.nonempty(displayName) else { return nil }
        let calendarName = Self.nonempty(calendarName) ?? displayName
        return displayName.localizedCaseInsensitiveCompare(calendarName) == .orderedSame
            ? nil
            : displayName
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}

struct OwnedSharedCalendarDescriptor: Codable, Hashable {
    var displayName: String
    var calendarName: String
    var participantCount: Int
    var contentConfiguration: SharedContentConfiguration? = nil

    var sharedContent: SharedContentConfiguration {
        contentConfiguration ?? .legacyDefault
    }
}

struct SharedContentConfiguration: Codable, Equatable, Hashable {
    static let currentSchemaVersion = 2

    var sharesEvents: Bool
    var sharesShifts: Bool
    var sharesWorkRecords: Bool
    var schemaVersion: Int

    var hasSelectedContent: Bool {
        sharesEvents || sharesShifts || sharesWorkRecords
    }

    static let newShareDefault = SharedContentConfiguration(
        sharesEvents: true,
        sharesShifts: true,
        sharesWorkRecords: false,
        schemaVersion: currentSchemaVersion
    )

    static let legacyDefault = SharedContentConfiguration(
        sharesEvents: true,
        sharesShifts: false,
        sharesWorkRecords: false,
        schemaVersion: 1
    )
}

/// A deliberately small transfer object. Deletions are synchronized by deleting the
/// corresponding CloudKit record, so no private CalendarEvent fields are represented here.
struct SharedEventSnapshot: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let updatedAt: Date
}

enum SharedEventMapper {
    enum ExclusionReason: String, Equatable {
        case shift
        case workRecord
        case inconsistentWorkInfo
        case workClockWithoutWorkInfo
        case legacyShift
    }

    static func snapshot(from event: CalendarEvent) -> SharedEventSnapshot? {
        guard isShareable(event) else { return nil }
        return SharedEventSnapshot(
            id: event.id,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            updatedAt: event.updatedAt
        )
    }

    static func isShareable(_ event: CalendarEvent) -> Bool {
        exclusionReason(for: event) == nil
    }

    static func exclusionReason(for event: CalendarEvent) -> ExclusionReason? {
        if event.shiftTemplateID != nil {
            return .shift
        }

        switch (event.workInfo != nil, event.workClockKind != nil) {
        case (true, true):
            return .workRecord
        case (true, false):
            return .inconsistentWorkInfo
        case (false, true):
            return .workClockWithoutWorkInfo
        case (false, false):
            break
        }

        // Legacy shifts may predate shiftTemplateID. Excluding known/template titles is the
        // privacy-safe choice; it prevents old shift data from entering the shared zone.
        let matchesConfiguredShift = ShiftTimeTemplate.all().contains { $0.displayName == event.title }
        if matchesConfiguredShift || ShiftTimeTemplate.isKnownDefaultDisplayName(event.title) {
            return .legacyShift
        }
        return nil
    }

    static func occurrences(
        from snapshots: [SharedEventSnapshot],
        in range: DateInterval
    ) -> [EventOccurrence] {
        let calendar = Calendar(identifier: .gregorian)
        return snapshots.flatMap { snapshot in
            coveredDates(for: snapshot, in: range, calendar: calendar).map { occurrenceDate in
                let dateOnly = DateOnly(from: occurrenceDate) ?? DateOnly(year: 2000, month: 1, day: 1)
                return EventOccurrence(
                    id: "shared-\(snapshot.id.uuidString)-\(dateOnly.id)",
                    eventID: snapshot.id,
                    occurrenceDate: dateOnly,
                    startDate: snapshot.startDate,
                    endDate: snapshot.endDate,
                    isAllDay: snapshot.isAllDay,
                    title: snapshot.title,
                    note: nil,
                    categoryID: nil,
                    reminderOffsetMinutes: nil,
                    notificationID: nil,
                    shiftTemplateID: nil,
                    workInfo: nil
                )
            }
        }
        .sorted {
            if $0.occurrenceDate != $1.occurrenceDate {
                return $0.occurrenceDate.id < $1.occurrenceDate.id
            }
            return $0.startDate < $1.startDate
        }
    }

    private static func coveredDates(
        for snapshot: SharedEventSnapshot,
        in range: DateInterval,
        calendar: Calendar
    ) -> [Date] {
        guard snapshot.endDate > snapshot.startDate else {
            guard snapshot.startDate >= range.start, snapshot.startDate < range.end else { return [] }
            return [calendar.startOfDay(for: snapshot.startDate)]
        }

        let coveredStart = max(snapshot.startDate, range.start)
        let coveredEnd = min(snapshot.endDate, range.end)
        guard coveredEnd > coveredStart else { return [] }

        var dates: [Date] = []
        var date = calendar.startOfDay(for: coveredStart)
        while date < coveredEnd {
            dates.append(date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date), next > date else {
                break
            }
            date = next
        }
        return dates
    }
}

/// Read-only shift data. Template settings and other device-local state are intentionally absent.
struct SharedShiftSnapshot: Codable, Identifiable, Hashable {
    let id: UUID
    let registeredDate: Date
    let displayName: String
    let startDate: Date
    let endDate: Date
    let spansMidnight: Bool
    let colorHex: String
    let updatedAt: Date
}

enum SharedShiftMapper {
    static func snapshot(
        from event: CalendarEvent,
        templates: [ShiftTimeTemplate] = ShiftTimeTemplate.all()
    ) -> SharedShiftSnapshot? {
        guard event.workInfo == nil, event.workClockKind == nil else { return nil }
        guard let template = resolvedTemplate(for: event, templates: templates) else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        let registeredDate = calendar.startOfDay(for: event.startDate)
        let endDay = calendar.startOfDay(for: event.endDate)
        return SharedShiftSnapshot(
            id: event.id,
            registeredDate: registeredDate,
            displayName: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            spansMidnight: endDay > registeredDate,
            colorHex: template.colorHex,
            updatedAt: event.updatedAt
        )
    }

    static func occurrences(
        from snapshots: [SharedShiftSnapshot],
        in range: DateInterval
    ) -> [EventOccurrence] {
        snapshots.compactMap { snapshot -> EventOccurrence? in
            guard snapshot.registeredDate >= range.start,
                  snapshot.registeredDate < range.end,
                  let dateOnly = DateOnly(from: snapshot.registeredDate) else {
                return nil
            }
            return EventOccurrence(
                id: "shared-shift-\(snapshot.id.uuidString)-\(dateOnly.id)",
                eventID: snapshot.id,
                occurrenceDate: dateOnly,
                startDate: snapshot.startDate,
                endDate: snapshot.endDate,
                isAllDay: false,
                title: snapshot.displayName,
                note: nil,
                categoryID: nil,
                reminderOffsetMinutes: nil,
                notificationID: nil,
                shiftTemplateID: .custom(snapshot.id),
                workInfo: nil,
                sharedShiftColorHex: snapshot.colorHex
            )
        }
        .sorted { $0.startDate < $1.startDate }
    }

    private static func resolvedTemplate(
        for event: CalendarEvent,
        templates: [ShiftTimeTemplate]
    ) -> ShiftTimeTemplate? {
        if let shiftTemplateID = event.shiftTemplateID {
            if let template = templates.first(where: { $0.id == shiftTemplateID }) {
                return template
            }
            return ShiftTimeTemplate(
                id: shiftTemplateID,
                nameKey: shiftTemplateID.nameKey,
                displayName: event.title,
                note: "",
                colorHex: shiftTemplateID.colorHex,
                startTime: shiftTemplateID.defaultStartTime,
                endTime: shiftTemplateID.defaultEndTime,
                enabled: true
            )
        }
        return templates.first(where: { $0.displayName == event.title })
            ?? legacyTemplate(for: event.title, templates: templates)
    }

    private static func legacyTemplate(
        for title: String,
        templates: [ShiftTimeTemplate]
    ) -> ShiftTimeTemplate? {
        for id in [ShiftTimeTemplateID.day, .night]
            where ShiftTimeTemplate.isKnownDefaultDisplayName(title, for: id) {
            return templates.first(where: { $0.id == id })
                ?? ShiftTimeTemplate(
                    id: id,
                    nameKey: id.nameKey,
                    displayName: title,
                    note: "",
                    colorHex: id.colorHex,
                    startTime: id.defaultStartTime,
                    endTime: id.defaultEndTime,
                    enabled: true
                )
        }
        return nil
    }
}

/// One shared work session. Pay, transport fees, memo and notifications never enter this DTO.
struct SharedWorkRecordSnapshot: Codable, Identifiable, Hashable {
    let id: UUID
    let workDate: Date
    let workInTime: Date?
    let workOutTime: Date?
    let isWorkOutTimeSet: Bool
    let restHours: Double
    let updatedAt: Date
}

enum SharedWorkRecordMapper {
    static func isCandidate(_ event: CalendarEvent) -> Bool {
        event.workClockKind != nil && event.workInfo != nil
    }

    static func snapshots(from events: [CalendarEvent]) -> [SharedWorkRecordSnapshot] {
        let workEvents = events.filter(isCandidate)
        let groups = Dictionary(grouping: workEvents, by: groupKey(for:))

        return groups.values.compactMap(makeSnapshot(from:)).sorted { lhs, rhs in
            if lhs.workDate != rhs.workDate { return lhs.workDate < rhs.workDate }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    static func occurrences(
        from snapshots: [SharedWorkRecordSnapshot],
        in range: DateInterval
    ) -> [EventOccurrence] {
        snapshots.flatMap { snapshot -> [EventOccurrence] in
            guard snapshot.workDate >= range.start,
                  snapshot.workDate < range.end,
                  let dateOnly = DateOnly(from: snapshot.workDate) else {
                return []
            }

            var occurrences: [EventOccurrence] = []
            if let workInTime = snapshot.workInTime {
                let info = WorkInfo(
                    workInTime: workInTime,
                    workOutTime: nil,
                    restHours: snapshot.restHours,
                    workDate: snapshot.workDate,
                    transportFee: nil,
                    hourlyRate: nil,
                    workSessionId: snapshot.id,
                    isWorkOutTimeSet: snapshot.isWorkOutTimeSet
                )
                occurrences.append(makeOccurrence(
                    snapshot: snapshot,
                    dateOnly: dateOnly,
                    kind: .clockIn,
                    clockDate: workInTime,
                    workInfo: info
                ))
            }

            let workOutTime = snapshot.workOutTime ?? snapshot.workDate
            let info = WorkInfo(
                workInTime: nil,
                workOutTime: workOutTime,
                restHours: snapshot.restHours,
                workDate: snapshot.workDate,
                transportFee: nil,
                hourlyRate: nil,
                workSessionId: snapshot.id,
                isWorkOutTimeSet: snapshot.isWorkOutTimeSet
            )
            occurrences.append(makeOccurrence(
                snapshot: snapshot,
                dateOnly: dateOnly,
                kind: .clockOut,
                clockDate: workOutTime,
                workInfo: info
            ))
            return occurrences
        }
        .sorted { $0.actualWorkClockDate < $1.actualWorkClockDate }
    }

    private static func groupKey(for event: CalendarEvent) -> String {
        if let sessionID = event.workInfo?.workSessionId {
            return "session-\(sessionID.uuidString)"
        }
        let date = event.workInfo?.workDate ?? event.startDate
        let dateOnly = DateOnly(from: date) ?? DateOnly(year: 2000, month: 1, day: 1)
        return "legacy-\(dateOnly.id)"
    }

    private static func makeSnapshot(from events: [CalendarEvent]) -> SharedWorkRecordSnapshot? {
        guard let source = events.first,
              let sourceInfo = source.workInfo else { return nil }
        let clockIn = events
            .filter(\.isClockInEvent)
            .sorted { $0.actualWorkClockDate < $1.actualWorkClockDate }
            .first
        let clockOut = events
            .filter(\.isClockOutEvent)
            .sorted { $0.actualWorkClockDate < $1.actualWorkClockDate }
            .last
        let stableID = sourceInfo.workSessionId ?? clockIn?.id ?? clockOut?.id ?? source.id
        let calendar = Calendar(identifier: .gregorian)
        let workDate = calendar.startOfDay(
            for: sourceInfo.workDate ?? clockIn?.workDate ?? clockOut?.workDate ?? source.startDate
        )
        let clockOutIsSet = clockOut?.workInfo?.isWorkOutTimeSet ?? sourceInfo.isWorkOutTimeSet
        return SharedWorkRecordSnapshot(
            id: stableID,
            workDate: workDate,
            workInTime: clockIn.map(\.actualWorkClockDate),
            workOutTime: clockOut?.workInfo?.workOutTime ?? clockOut.map(\.actualWorkClockDate),
            isWorkOutTimeSet: clockOutIsSet,
            restHours: sourceInfo.restHours,
            updatedAt: events.map(\.updatedAt).max() ?? source.updatedAt
        )
    }

    private static func makeOccurrence(
        snapshot: SharedWorkRecordSnapshot,
        dateOnly: DateOnly,
        kind: WorkClockKind,
        clockDate: Date,
        workInfo: WorkInfo
    ) -> EventOccurrence {
        let title: String
        let suffix: String
        switch kind {
        case .clockIn:
            title = LocalizationManager.shared.localized(.editorWorkIn)
            suffix = "in"
        case .clockOut:
            title = LocalizationManager.shared.localized(.editorWorkOut)
            suffix = "out"
        }
        return EventOccurrence(
            id: "shared-work-\(snapshot.id.uuidString)-\(suffix)",
            eventID: snapshot.id,
            occurrenceDate: dateOnly,
            startDate: clockDate,
            endDate: CalendarEvent.defaultEndDate(for: clockDate, isAllDay: false),
            isAllDay: false,
            title: title,
            note: nil,
            categoryID: nil,
            reminderOffsetMinutes: nil,
            notificationID: nil,
            shiftTemplateID: nil,
            workInfo: workInfo
        )
    }
}

struct CalendarAccessPolicy: Equatable {
    let selection: CalendarSelection

    var isReadOnly: Bool { selection.sharedCalendarID != nil }
    var canCreate: Bool { !isReadOnly }
    var canEdit: Bool { !isReadOnly }
    var canDelete: Bool { !isReadOnly }
    var showsAddButton: Bool { canCreate }
}

enum CalendarAvatarInitial {
    static func make(displayName: String?, fallback: String) -> String {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let source = trimmed.isEmpty ? fallback : trimmed
        return source.first.map(String.init) ?? "?"
    }
}

struct OwnedSharingStopPlan: Equatable {
    let deletesShareRecord = true
    let deletesRecordZone = false
    let deletesLocalEvents = false
}

enum CalendarSharingError: Error, Equatable, LocalizedError {
    case noICloudAccount
    case iCloudRestricted
    case networkUnavailable
    case invitationPending
    case shareCreationFailed
    case shareUnavailable
    case permissionDenied
    case contentSelectionRequired
    case syncFailed

    var errorDescription: String? {
        switch self {
        case .noICloudAccount:
            LocalizationManager.shared.localized(.calendarSharingICloudSignInRequired)
        case .iCloudRestricted:
            LocalizationManager.shared.localized(.calendarSharingICloudRestricted)
        case .networkUnavailable:
            LocalizationManager.shared.localized(.calendarSharingNetworkUnavailable)
        case .invitationPending:
            LocalizationManager.shared.localized(.calendarSharingInvitationPending)
        case .shareCreationFailed:
            LocalizationManager.shared.localized(.calendarSharingCreationFailed)
        case .shareUnavailable:
            LocalizationManager.shared.localized(.calendarSharingShareUnavailable)
        case .permissionDenied:
            LocalizationManager.shared.localized(.calendarSharingPermissionDenied)
        case .contentSelectionRequired:
            LocalizationManager.shared.localized(.calendarSharingContentSelectionRequired)
        case .syncFailed:
            LocalizationManager.shared.localized(.calendarSharingSyncFailed)
        }
    }
}
