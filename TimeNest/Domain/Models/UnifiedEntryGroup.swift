import Foundation

struct UnifiedEntryWorkRecord: Hashable {
    let sessionID: UUID?
    let clockIn: CalendarEvent
    let clockOut: CalendarEvent

    var events: [CalendarEvent] {
        [clockIn, clockOut]
    }
}

struct UnifiedEntryGroup: Hashable {
    let unifiedEntryID: UUID?
    let event: CalendarEvent?
    let workRecord: UnifiedEntryWorkRecord?

    var allEvents: [CalendarEvent] {
        [event].compactMap { $0 } + (workRecord?.events ?? [])
    }

    var hasExistingEvent: Bool {
        event != nil
    }

    var hasExistingWorkRecord: Bool {
        workRecord != nil
    }
}

enum UnifiedEntryGroupError: Error, Equatable, LocalizedError {
    case duplicateEvent
    case multipleWorkSessions
    case invalidWorkRecordPair
    case mismatchedUnifiedEntryID
    case calendarMismatch
    case linkedEventNotFound
    case linkedWorkRecordNotFound
    case staleEditorState

    var errorDescription: String? {
        switch self {
        case .duplicateEvent, .multipleWorkSessions:
            LocalizationManager.shared.localized(.entryLinkedDuplicateRecords)
        case .linkedEventNotFound:
            LocalizationManager.shared.localized(.entryLinkedEventLoadFailed)
        case .linkedWorkRecordNotFound:
            LocalizationManager.shared.localized(.entryLinkedWorkRecordLoadFailed)
        case .staleEditorState:
            LocalizationManager.shared.localized(.entryLinkedReopen)
        case .invalidWorkRecordPair, .mismatchedUnifiedEntryID, .calendarMismatch:
            LocalizationManager.shared.localized(.entryLinkedInvalidGroup)
        }
    }
}

enum UnifiedEntryGroupAssembler {
    static func assemble(
        unifiedEntryID expectedID: UUID?,
        events: [CalendarEvent]
    ) throws -> UnifiedEntryGroup {
        let eventIDs = events.map(\.id)
        guard Set(eventIDs).count == eventIDs.count else {
            throw UnifiedEntryGroupError.duplicateEvent
        }

        if !events.isEmpty,
           Set(events.map(\.calendarID)).count != 1 {
            throw UnifiedEntryGroupError.calendarMismatch
        }

        let persistedIDs = Set(events.compactMap(\.unifiedEntryID))
        if let expectedID {
            guard events.allSatisfy({ $0.unifiedEntryID == expectedID }),
                  events.isEmpty || persistedIDs == Set([expectedID]) else {
                throw UnifiedEntryGroupError.mismatchedUnifiedEntryID
            }
        } else {
            guard persistedIDs.count <= 1 else {
                throw UnifiedEntryGroupError.mismatchedUnifiedEntryID
            }
            if !persistedIDs.isEmpty,
               events.contains(where: { $0.unifiedEntryID == nil }) {
                throw UnifiedEntryGroupError.mismatchedUnifiedEntryID
            }
        }

        var ordinaryEvents: [CalendarEvent] = []
        var workEvents: [CalendarEvent] = []
        for event in events {
            switch (event.workInfo, event.workClockKind) {
            case (nil, nil):
                ordinaryEvents.append(event)
            case (.some, .some):
                workEvents.append(event)
            case (nil, .some), (.some, nil):
                throw UnifiedEntryGroupError.invalidWorkRecordPair
            }
        }

        guard ordinaryEvents.count <= 1 else {
            throw UnifiedEntryGroupError.duplicateEvent
        }

        let workRecord = try assembleWorkRecord(from: workEvents)
        return UnifiedEntryGroup(
            unifiedEntryID: expectedID ?? persistedIDs.first,
            event: ordinaryEvents.first,
            workRecord: workRecord
        )
    }

    static func assembleWorkRecord(
        from events: [CalendarEvent]
    ) throws -> UnifiedEntryWorkRecord? {
        guard !events.isEmpty else { return nil }
        let sessionIDs = events.map { $0.workInfo?.workSessionId }
        let nonNilSessionIDs = Set(sessionIDs.compactMap { $0 })
        guard nonNilSessionIDs.count <= 1 else {
            throw UnifiedEntryGroupError.multipleWorkSessions
        }
        if !nonNilSessionIDs.isEmpty,
           sessionIDs.contains(where: { $0 == nil }) {
            throw UnifiedEntryGroupError.invalidWorkRecordPair
        }
        guard events.count == 2 else {
            throw UnifiedEntryGroupError.invalidWorkRecordPair
        }
        let clockIns = events.filter { $0.workClockKind == .clockIn }
        let clockOuts = events.filter { $0.workClockKind == .clockOut }
        guard clockIns.count == 1, clockOuts.count == 1,
              let clockIn = clockIns.first,
              let clockOut = clockOuts.first else {
            throw UnifiedEntryGroupError.invalidWorkRecordPair
        }

        return UnifiedEntryWorkRecord(
            sessionID: nonNilSessionIDs.first,
            clockIn: clockIn,
            clockOut: clockOut
        )
    }
}
