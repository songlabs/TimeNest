import Foundation

struct EventEntrySaveRequest: Hashable {
    let eventID: UUID?
    let calendarID: UUID
    let title: String
    let note: String?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let reminderOffsetMinutes: Int?
    let shiftTemplateID: ShiftTimeTemplateID?
    let workInfo: WorkInfo?
}

struct UnifiedEntrySaveRequest: Hashable {
    let unifiedEntryID: UUID?
    let event: EventEntrySaveRequest?
    let workRecord: WorkRecordPairSaveRequest?

    init(
        unifiedEntryID: UUID? = nil,
        event: EventEntrySaveRequest?,
        workRecord: WorkRecordPairSaveRequest?
    ) {
        self.unifiedEntryID = unifiedEntryID
        self.event = event
        self.workRecord = workRecord
    }

    var hasEnabledEntry: Bool {
        event != nil || workRecord != nil
    }
}

enum UnifiedEntryLoadRequest: Hashable {
    case event(eventID: UUID)
    case workRecord(
        clockInEventID: UUID?,
        clockOutEventID: UUID?,
        workSessionID: UUID?
    )
}

struct UnifiedEntrySaveResolution: Hashable {
    let unifiedEntryID: UUID
    let existingEvent: CalendarEvent?
    let existingWorkRecord: UnifiedEntryWorkRecord?
}

enum UnifiedEntrySaveError: Error, Equatable, LocalizedError {
    case noEnabledEntry

    var errorDescription: String? {
        LocalizationManager.shared.localized(.entryEnableAtLeastOne)
    }
}
