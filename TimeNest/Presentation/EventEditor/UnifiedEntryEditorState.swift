import Foundation

typealias UnifiedEntryEditorLoadAction = (
    UnifiedEntryLoadRequest
) async throws -> UnifiedEntryEditorInitialState

struct UnifiedEntryEditorInitialState: Identifiable, Hashable {
    let unifiedEntryID: UUID?
    let event: CalendarEvent?
    let workRecord: WorkRecordEditorInitialSession?
    let initialEntryKind: EntryEditorKind

    init(
        unifiedEntryID: UUID?,
        event: CalendarEvent?,
        workRecord: WorkRecordEditorInitialSession?,
        initialEntryKind: EntryEditorKind? = nil
    ) {
        self.unifiedEntryID = unifiedEntryID
        self.event = event
        self.workRecord = workRecord
        self.initialEntryKind = initialEntryKind
            ?? Self.defaultEntryKind(event: event, workRecord: workRecord)
    }

    init(
        group: UnifiedEntryGroup,
        initialEntryKind: EntryEditorKind? = nil
    ) {
        let initialWorkRecord = group.workRecord.map(
            Self.makeWorkRecordInitialSession
        )
        unifiedEntryID = group.unifiedEntryID
        event = group.event
        workRecord = initialWorkRecord
        self.initialEntryKind = initialEntryKind
            ?? Self.defaultEntryKind(
                event: group.event,
                workRecord: initialWorkRecord
            )
    }

    var id: String {
        if let unifiedEntryID {
            return "unified-\(unifiedEntryID.uuidString)"
        }
        if let event {
            return "event-\(event.id.uuidString)"
        }
        if let workRecord {
            return "work-\(workRecord.id)"
        }
        return "new"
    }

    var existingEventID: UUID? {
        event?.id
    }

    var existingWorkSessionID: UUID? {
        workRecord?.workSessionId
    }

    var hasExistingEvent: Bool {
        event != nil
    }

    var hasExistingWorkRecord: Bool {
        workRecord != nil
    }

    private static func defaultEntryKind(
        event: CalendarEvent?,
        workRecord: WorkRecordEditorInitialSession?
    ) -> EntryEditorKind {
        event == nil && workRecord != nil ? .workRecord : .event
    }

    private static func makeWorkRecordInitialSession(
        _ workRecord: UnifiedEntryWorkRecord
    ) -> WorkRecordEditorInitialSession {
        let clockIn = workRecord.clockIn
        let clockOut = workRecord.clockOut
        let sourceWorkInfo = clockIn.workInfo ?? clockOut.workInfo
        return WorkRecordEditorInitialSession(
            clockInEventID: clockIn.id,
            clockOutEventID: clockOut.id,
            title: editorTitle(clockIn: clockIn, clockOut: clockOut),
            workDate: clockIn.workDate,
            workInTime: clockIn.actualWorkClockDate,
            workOutTime: clockOut.actualWorkClockDate,
            restHours: sourceWorkInfo?.restHours ?? 0,
            transportFee: sourceWorkInfo?.transportFee,
            hourlyRate: sourceWorkInfo?.hourlyRate,
            workSessionId: workRecord.sessionID,
            isWorkOutTimeSet: clockOut.isWorkOutTimeSet,
            calendarID: clockIn.calendarID
        )
    }

    private static func editorTitle(
        clockIn: CalendarEvent,
        clockOut: CalendarEvent
    ) -> String {
        for title in [clockIn.title, clockOut.title] {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return LocalizationManager.shared.localized(.workRecordDefaultTitle)
    }
}

extension UnifiedEntryLoadRequest {
    var initialEntryKind: EntryEditorKind {
        switch self {
        case .event:
            return .event
        case .workRecord:
            return .workRecord
        }
    }
}

struct UnifiedEntrySectionSelection: Equatable {
    private(set) var isEventEnabled: Bool
    private(set) var isWorkRecordEnabled: Bool
    let hasExistingEvent: Bool
    let hasExistingWorkRecord: Bool

    static func initial(
        for mode: EventEditorMode,
        initialEntryKind: EntryEditorKind
    ) -> UnifiedEntrySectionSelection {
        switch mode {
        case .create:
            return UnifiedEntrySectionSelection(
                isEventEnabled: initialEntryKind == .event,
                isWorkRecordEnabled: initialEntryKind == .workRecord
            )
        case .edit:
            return UnifiedEntrySectionSelection(
                isEventEnabled: true,
                isWorkRecordEnabled: false,
                hasExistingEvent: true
            )
        case .editWorkRecord:
            return UnifiedEntrySectionSelection(
                isEventEnabled: false,
                isWorkRecordEnabled: true,
                hasExistingWorkRecord: true
            )
        case .editUnified(let state):
            return UnifiedEntrySectionSelection(
                isEventEnabled: state.hasExistingEvent,
                isWorkRecordEnabled: state.hasExistingWorkRecord,
                hasExistingEvent: state.hasExistingEvent,
                hasExistingWorkRecord: state.hasExistingWorkRecord
            )
        }
    }

    init(
        isEventEnabled: Bool,
        isWorkRecordEnabled: Bool,
        hasExistingEvent: Bool = false,
        hasExistingWorkRecord: Bool = false
    ) {
        self.isEventEnabled = isEventEnabled || hasExistingEvent
        self.isWorkRecordEnabled = isWorkRecordEnabled || hasExistingWorkRecord
        self.hasExistingEvent = hasExistingEvent
        self.hasExistingWorkRecord = hasExistingWorkRecord
    }

    var hasEnabledEntry: Bool {
        isEventEnabled || isWorkRecordEnabled
    }

    mutating func setEventEnabled(_ enabled: Bool) {
        guard enabled || !hasExistingEvent else { return }
        isEventEnabled = enabled
    }

    mutating func setWorkRecordEnabled(_ enabled: Bool) {
        guard enabled || !hasExistingWorkRecord else { return }
        isWorkRecordEnabled = enabled
    }
}

struct UnifiedEntryEventLinkSource: Equatable {
    let title: String
    let startDate: Date
    let endDate: Date
}

struct UnifiedEntryWorkRecordLinkedValues: Equatable {
    var title: String
    var workDate: Date
    var clockInDate: Date
    var clockOutDate: Date
    var isClockOutTimeSet: Bool
}

struct UnifiedEntryWorkRecordDefaultLinker: Equatable {
    private(set) var hasInitialized: Bool

    init(hasInitialized: Bool = false) {
        self.hasInitialized = hasInitialized
    }

    mutating func valuesWhenEnabling(
        event: UnifiedEntryEventLinkSource,
        current: UnifiedEntryWorkRecordLinkedValues,
        calendar: Calendar = .current
    ) -> UnifiedEntryWorkRecordLinkedValues {
        guard !hasInitialized else { return current }
        hasInitialized = true
        return UnifiedEntryWorkRecordLinkedValues(
            title: event.title,
            workDate: calendar.startOfDay(for: event.startDate),
            clockInDate: event.startDate,
            clockOutDate: event.endDate,
            isClockOutTimeSet: true
        )
    }
}
