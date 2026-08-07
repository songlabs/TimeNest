import Foundation

enum CalendarSelection: Codable, Equatable, Hashable {
    case calendar(UUID)

    static var mine: CalendarSelection { .calendar(TimeNestCalendar.personalID) }

    var calendarID: UUID {
        switch self {
        case .calendar(let id): id
        }
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

    func load(validCalendarIDs: Set<UUID>) -> CalendarSelection {
        Self.resolved(load(), validCalendarIDs: validCalendarIDs)
    }

    func save(_ selection: CalendarSelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: key)
    }

    static func resolved(
        _ selection: CalendarSelection,
        validCalendarIDs: Set<UUID>
    ) -> CalendarSelection {
        validCalendarIDs.contains(selection.calendarID) ? selection : .mine
    }
}

enum CalendarSharingICloudStatus: Equatable {
    case unknown
    case checking
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine
    case requestFailed(CalendarSharingError)

    var blocksSharingOperation: Bool {
        switch self {
        case .available:
            false
        case .unknown, .checking, .noAccount, .restricted,
             .temporarilyUnavailable, .couldNotDetermine, .requestFailed:
            true
        }
    }

    var operationError: CalendarSharingError? {
        switch self {
        case .available:
            nil
        case .noAccount:
            .noICloudAccount
        case .restricted:
            .iCloudRestricted
        case .temporarilyUnavailable:
            .serviceTemporarilyUnavailable
        case .unknown, .checking, .couldNotDetermine:
            .iCloudStatusUnavailable
        case .requestFailed(let error):
            error
        }
    }
}

enum CalendarSharingDisplayStatus: Equatable {
    case notShared
    case waitingForAcceptance
    case shared
    case syncing
    case failed
    case unavailable
}

extension CalendarSharingICloudStatus {
    var localizedKey: LocalizedString {
        switch self {
        case .checking:
            .calendarSharingICloudStatusChecking
        case .available:
            .calendarSharingICloudStatusAvailable
        case .noAccount:
            .calendarSharingICloudStatusNoAccount
        case .restricted:
            .calendarSharingICloudStatusRestricted
        case .temporarilyUnavailable:
            .calendarSharingICloudStatusTemporarilyUnavailable
        case .requestFailed:
            .calendarSharingICloudStatusRequestFailed
        case .unknown, .couldNotDetermine:
            .calendarSharingICloudStatusUnknown
        }
    }
}

extension CalendarSharingDisplayStatus {
    var localizedKey: LocalizedString {
        switch self {
        case .notShared:
            .calendarSharingStateNotShared
        case .waitingForAcceptance:
            .calendarSharingStateWaiting
        case .shared:
            .calendarSharingStateShared
        case .syncing:
            .calendarSharingStateSyncing
        case .failed:
            .calendarSharingStateFailed
        case .unavailable:
            .calendarSharingStateUnavailable
        }
    }
}

struct CalendarSharingSyncMetadataPersistence {
    static let defaultKey = "calendarSharing.lastSuccessfulSyncAt"

    let defaults: UserDefaults
    let key: String

    init(defaults: UserDefaults = .standard, key: String = Self.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    func loadLastSuccessfulSyncAt() -> Date? {
        defaults.object(forKey: key) as? Date
    }

    func saveLastSuccessfulSyncAt(_ date: Date?) {
        if let date {
            defaults.set(date, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

struct SharedCalendarDescriptor: Codable, Identifiable, Hashable {
    let id: UUID
    let zoneName: String
    let ownerName: String
    var ownerDisplayName: String? = nil
    var calendarName: String
    var participantCount: Int
    let kind: TimeNestCalendarKind
    var rootRecordName: String
    var shareRecordName: String
    var eventEditingAllowed: Bool
    /// Version 0 uses the legacy owner-only SharedEvent snapshot protocol.
    /// Version 1 stores jointly editable events in CollaborativeEvent records.
    var collaborationProtocolVersion: Int
    var participantPermission: SharedCalendarParticipantPermission

    init(
        id: UUID,
        zoneName: String,
        ownerName: String,
        ownerDisplayName: String? = nil,
        calendarName: String,
        participantCount: Int,
        kind: TimeNestCalendarKind,
        rootRecordName: String,
        shareRecordName: String,
        eventEditingAllowed: Bool = false,
        collaborationProtocolVersion: Int = 0,
        participantPermission: SharedCalendarParticipantPermission = .unknown
    ) {
        self.id = id
        self.zoneName = zoneName
        self.ownerName = ownerName
        self.ownerDisplayName = ownerDisplayName
        self.calendarName = calendarName
        self.participantCount = participantCount
        self.kind = kind
        self.rootRecordName = rootRecordName
        self.shareRecordName = shareRecordName
        self.eventEditingAllowed = eventEditingAllowed
        self.collaborationProtocolVersion = collaborationProtocolVersion
        self.participantPermission = participantPermission
    }

    func resolvedCalendarName(fallback: String) -> String {
        Self.nonempty(calendarName) ?? fallback
    }

    var isReadOnly: Bool {
        kind == .sharedReceived
            && (collaborationProtocolVersion < 1
                || !eventEditingAllowed
                || participantPermission != .readWrite)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case zoneName
        case ownerName
        case ownerDisplayName
        case calendarName
        case participantCount
        case kind
        case rootRecordName
        case shareRecordName
        case eventEditingAllowed
        case collaborationProtocolVersion
        case participantPermission
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            zoneName: try container.decode(String.self, forKey: .zoneName),
            ownerName: try container.decode(String.self, forKey: .ownerName),
            ownerDisplayName: try container.decodeIfPresent(String.self, forKey: .ownerDisplayName),
            calendarName: try container.decode(String.self, forKey: .calendarName),
            participantCount: try container.decode(Int.self, forKey: .participantCount),
            kind: try container.decode(TimeNestCalendarKind.self, forKey: .kind),
            rootRecordName: try container.decode(String.self, forKey: .rootRecordName),
            shareRecordName: try container.decode(String.self, forKey: .shareRecordName),
            eventEditingAllowed: try container.decodeIfPresent(
                Bool.self,
                forKey: .eventEditingAllowed
            ) ?? false,
            collaborationProtocolVersion: try container.decodeIfPresent(
                Int.self,
                forKey: .collaborationProtocolVersion
            ) ?? 0,
            participantPermission: try container.decodeIfPresent(
                SharedCalendarParticipantPermission.self,
                forKey: .participantPermission
            ) ?? .unknown
        )
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
    let id: UUID
    let zoneName: String
    let ownerName: String
    var calendarName: String
    var participantCount: Int
    var rootRecordName: String
    var shareRecordName: String
    var eventEditingAllowed: Bool = false
    var collaborationProtocolVersion: Int = 0

    init(
        id: UUID,
        zoneName: String,
        ownerName: String,
        calendarName: String,
        participantCount: Int,
        rootRecordName: String,
        shareRecordName: String,
        eventEditingAllowed: Bool = false,
        collaborationProtocolVersion: Int = 0
    ) {
        self.id = id
        self.zoneName = zoneName
        self.ownerName = ownerName
        self.calendarName = calendarName
        self.participantCount = participantCount
        self.rootRecordName = rootRecordName
        self.shareRecordName = shareRecordName
        self.eventEditingAllowed = eventEditingAllowed
        self.collaborationProtocolVersion = collaborationProtocolVersion
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case zoneName
        case ownerName
        case calendarName
        case participantCount
        case rootRecordName
        case shareRecordName
        case eventEditingAllowed
        case collaborationProtocolVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            zoneName: try container.decode(String.self, forKey: .zoneName),
            ownerName: try container.decode(String.self, forKey: .ownerName),
            calendarName: try container.decode(String.self, forKey: .calendarName),
            participantCount: try container.decode(Int.self, forKey: .participantCount),
            rootRecordName: try container.decode(String.self, forKey: .rootRecordName),
            shareRecordName: try container.decode(String.self, forKey: .shareRecordName),
            eventEditingAllowed: try container.decodeIfPresent(
                Bool.self,
                forKey: .eventEditingAllowed
            ) ?? false,
            collaborationProtocolVersion: try container.decodeIfPresent(
                Int.self,
                forKey: .collaborationProtocolVersion
            ) ?? 0
        )
    }
}

enum SharedCalendarParticipantPermission: String, Codable, Equatable, Hashable {
    case unknown
    case none
    case readOnly
    case readWrite
}

struct SharedCalendarParticipantSnapshot: Identifiable, Equatable {
    let id: String
    let displayName: String?
    let isAccepted: Bool
    let permission: SharedCalendarParticipantPermission
    let revocationToken: String?

    init(
        id: String,
        displayName: String?,
        isAccepted: Bool,
        permission: SharedCalendarParticipantPermission,
        revocationToken: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.isAccepted = isAccepted
        self.permission = permission
        self.revocationToken = revocationToken
    }

    func resolvedDisplayName(fallback: String) -> String {
        guard let displayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !displayName.isEmpty else {
            return fallback
        }
        return displayName
    }
}

/// A deliberately small transfer object. No private CalendarEvent fields are represented here.
struct SharedEventSnapshot: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let updatedAt: Date
    let isDeleted: Bool
    let deletedAt: Date?

    init(
        id: UUID,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        updatedAt: Date,
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case startDate
        case endDate
        case isAllDay
        case updatedAt
        case isDeleted
        case deletedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            startDate: try container.decode(Date.self, forKey: .startDate),
            endDate: try container.decode(Date.self, forKey: .endDate),
            isAllDay: try container.decode(Bool.self, forKey: .isAllDay),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt),
            isDeleted: try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false,
            deletedAt: try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        )
    }
}

enum SharedEventSyncStatus: String, Codable, Equatable, Hashable {
    case saving
    case pending
    case synced
    case failed
    case permissionRevoked
    case deletedRemotely
}

enum SharedEventMutationStatus: String, Codable, Equatable, Hashable, CaseIterable {
    case prepared
    case sending
    case awaitingReconciliation
    case completed
    case superseded
    case failed
    case permissionRevoked
    case deletedRemotely

    var isTerminal: Bool {
        switch self {
        case .completed, .superseded, .failed, .deletedRemotely:
            true
        case .prepared, .sending, .awaitingReconciliation, .permissionRevoked:
            false
        }
    }

    var visibleSyncStatus: SharedEventSyncStatus {
        switch self {
        case .prepared, .sending:
            .saving
        case .awaitingReconciliation:
            .pending
        case .completed, .superseded:
            .synced
        case .failed:
            .failed
        case .permissionRevoked:
            .permissionRevoked
        case .deletedRemotely:
            .deletedRemotely
        }
    }
}

/// A write that was rejected before the CloudKit mutation request was issued. Unlike an
/// ordinary transport error, this is the only failure that may safely return to `prepared`
/// without first comparing the server's `lastMutationID`.
enum SharedEventWriteError: Error, Equatable {
    case confirmedNotSent(CalendarSharingError)
}

struct OwnerSharedEventMutation: Identifiable, Equatable, Sendable {
    let id: UUID
    let calendarID: UUID
    let eventID: UUID
    var operation: SharedEventMutationOperation
    var payload: SharedEventSnapshot
    let createdAt: Date
    /// Assigned by the persistence actor inside the same transaction as the event write.
    var sequence: Int64
    var status: SharedEventMutationStatus
    var retryCount: Int
    var lastErrorCode: String?
}

struct SharedEventEnvelope: Codable, Identifiable, Hashable {
    var id: UUID { snapshot.id }
    let calendarID: UUID
    let zoneName: String
    let ownerName: String
    let recordName: String
    var snapshot: SharedEventSnapshot
    var recordChangeTag: String?
    var modificationDate: Date?
    var creatorIdentifierHash: String?
    var lastModifierIdentifierHash: String?
    var syncStatus: SharedEventSyncStatus
    var pendingMutationID: UUID?
    var lastMutationID: UUID? = nil

    var isDeleted: Bool { snapshot.isDeleted }
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
        return snapshots.filter { !$0.isDeleted }.flatMap { snapshot in
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
        let entries = events
            .filter(isCandidate)
            .compactMap(WorkRecordClockEntry.init(event:))
        return WorkRecordSessionAssembler.sessions(from: entries)
            .compactMap(makeSnapshot(from:))
            .sorted { lhs, rhs in
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

    private static func makeSnapshot(
        from session: AssembledWorkRecordSession
    ) -> SharedWorkRecordSnapshot? {
        guard let source = session.clockIn ?? session.clockOut else { return nil }
        let stableID = session.sessionID ?? source.eventID
        let clockOutIsSet = session.clockOut?.isWorkOutTimeSet
            ?? session.clockIn?.isWorkOutTimeSet
            ?? false
        return SharedWorkRecordSnapshot(
            id: stableID,
            workDate: session.workDate,
            workInTime: session.clockIn?.clockDate,
            workOutTime: session.clockOut?.clockDate,
            isWorkOutTimeSet: clockOutIsSet,
            restHours: session.clockIn?.restHours ?? session.clockOut?.restHours ?? 0,
            updatedAt: [session.clockIn, session.clockOut]
                .compactMap { $0?.updatedAt }
                .max() ?? source.updatedAt
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
    let selectedCalendar: TimeNestCalendar

    var isReadOnly: Bool { !selectedCalendar.canCreateSharedEvent }
    var canCreate: Bool { selectedCalendar.canCreateSharedEvent }
    var canEdit: Bool { selectedCalendar.canEditSharedEvent }
    var canDelete: Bool { selectedCalendar.canDeleteSharedEvent }
    var canCreateSharedEvent: Bool { selectedCalendar.canCreateSharedEvent }
    var canEditSharedEvent: Bool { selectedCalendar.canEditSharedEvent }
    var canDeleteSharedEvent: Bool { selectedCalendar.canDeleteSharedEvent }
    var canEditShifts: Bool { selectedCalendar.canEditContent }
    var canEditWorkRecords: Bool { selectedCalendar.canEditContent }
    var canManageShare: Bool { selectedCalendar.canManageShare }
    /// Keep the affordance visible for read-only calendars so a tap can explain why creation is blocked.
    var showsAddButton: Bool { true }
}

enum CalendarAvatarInitial {
    static func make(displayName: String?, fallback: String) -> String {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let source = trimmed.isEmpty ? fallback : trimmed
        return source.first.map(String.init) ?? "?"
    }
}

enum CalendarSharingError: Error, Equatable, LocalizedError {
    case noICloudAccount
    case iCloudRestricted
    case iCloudStatusUnavailable
    case networkUnavailable
    case serviceTemporarilyUnavailable
    case invitationPending
    case invitationInvalid
    case invitationRevoked
    case invitationURLInputEmpty
    case invitationURLInvalid
    case notCloudKitShare
    case metadataFetchFailed
    case invitationContainerMismatch
    case invitationUnavailable
    case invitationAcceptanceFailed
    case invitationCreationFailed
    case invitationURLUnavailable
    case invitationActivityFailed
    case shareCreationFailed
    case shareUnavailable
    case permissionDenied
    case sharedEventDeleted
    case sharedEventPermissionRevoked
    case cloudEnvironmentMismatch
    case receivedCalendarRefreshFailed
    case calendarDataMigrationFailed
    case invitationCancellationFailed
    case localPersistenceFailed
    case syncFailed

    var errorDescription: String? {
        switch self {
        case .noICloudAccount:
            LocalizationManager.shared.localized(.calendarSharingICloudSignInRequired)
        case .iCloudRestricted:
            LocalizationManager.shared.localized(.calendarSharingICloudRestricted)
        case .iCloudStatusUnavailable:
            LocalizationManager.shared.localized(.calendarSharingICloudStatusUnavailable)
        case .networkUnavailable:
            LocalizationManager.shared.localized(.calendarSharingNetworkUnavailable)
        case .serviceTemporarilyUnavailable:
            LocalizationManager.shared.localized(.calendarSharingServiceTemporarilyUnavailable)
        case .invitationPending:
            LocalizationManager.shared.localized(.calendarSharingInvitationPending)
        case .invitationInvalid:
            LocalizationManager.shared.localized(.calendarSharingInvitationInvalid)
        case .invitationRevoked:
            LocalizationManager.shared.localized(.calendarSharingInvitationRevoked)
        case .invitationURLInputEmpty:
            LocalizationManager.shared.localized(.calendarSharingInvitationURLEmpty)
        case .invitationURLInvalid:
            LocalizationManager.shared.localized(.calendarSharingInvitationURLInvalid)
        case .notCloudKitShare:
            LocalizationManager.shared.localized(.calendarSharingNotCloudKitShare)
        case .metadataFetchFailed:
            LocalizationManager.shared.localized(.calendarSharingMetadataFetchFailed)
        case .invitationContainerMismatch:
            LocalizationManager.shared.localized(.calendarSharingInvitationContainerMismatch)
        case .invitationUnavailable:
            LocalizationManager.shared.localized(.calendarSharingInvitationUnavailable)
        case .invitationAcceptanceFailed:
            LocalizationManager.shared.localized(.calendarSharingInvitationAcceptanceFailed)
        case .invitationCreationFailed:
            LocalizationManager.shared.localized(.calendarSharingInvitationCreationFailed)
        case .invitationURLUnavailable:
            LocalizationManager.shared.localized(.calendarSharingInvitationURLUnavailable)
        case .invitationActivityFailed:
            LocalizationManager.shared.localized(.calendarSharingInvitationActivityFailed)
        case .shareCreationFailed:
            LocalizationManager.shared.localized(.calendarSharingCreationFailed)
        case .shareUnavailable:
            LocalizationManager.shared.localized(.calendarSharingShareUnavailable)
        case .permissionDenied:
            LocalizationManager.shared.localized(.calendarSharingPermissionDenied)
        case .sharedEventDeleted:
            LocalizationManager.shared.localized(.calendarSharingSharedEventDeleted)
        case .sharedEventPermissionRevoked:
            LocalizationManager.shared.localized(.calendarSharingSharedEventPermissionRevoked)
        case .cloudEnvironmentMismatch:
            LocalizationManager.shared.localized(.calendarSharingCloudEnvironmentMismatch)
        case .receivedCalendarRefreshFailed:
            LocalizationManager.shared.localized(.calendarSharingReceivedCalendarRefreshFailed)
        case .calendarDataMigrationFailed:
            LocalizationManager.shared.localized(.calendarSharingDataMigrationFailed)
        case .invitationCancellationFailed:
            LocalizationManager.shared.localized(.calendarSharingInvitationCancellationFailed)
        case .localPersistenceFailed:
            LocalizationManager.shared.localized(.calendarSharingSyncFailed)
        case .syncFailed:
            LocalizationManager.shared.localized(.calendarSharingSyncFailed)
        }
    }
}
