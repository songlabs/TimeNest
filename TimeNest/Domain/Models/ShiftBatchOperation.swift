import Foundation

struct ShiftBatchTemplateSnapshot: Equatable, Hashable {
    let id: ShiftTimeTemplateID
    let displayName: String
    let note: String
    let colorHex: String
    let startTime: String
    let endTime: String
    let enabled: Bool
}

enum ShiftBatchMode: Equatable, Hashable {
    case template(ShiftTimeTemplateID)
    case copyPreviousDay
    case copyPreviousWeek
    case rotation(items: [ShiftRotationItem], startOffset: Int)
}

struct ShiftRotationItem: Identifiable, Equatable, Hashable {
    enum Selection: Equatable, Hashable {
        case template(ShiftTimeTemplateID)
        case restDay
    }

    let id: UUID
    var selection: Selection

    init(id: UUID = UUID(), selection: Selection) {
        self.id = id
        self.selection = selection
    }
}

struct ShiftBatchRequest: Equatable {
    let dates: [Date]
    let mode: ShiftBatchMode
    let calendarID: UUID
    let templates: [ShiftBatchTemplateSnapshot]
}

enum ShiftBatchPlanIssue: String, Equatable, Hashable {
    case emptySelection
    case invalidTemplate
    case emptyRotation
}

enum ShiftBatchItemStatus: String, Equatable, Hashable {
    case create
    case restDay
    case noSource
    case conflict
    case invalidTemplate
}

struct ShiftBatchOperationItem: Identifiable, Equatable {
    let id: UUID
    let targetDate: Date
    let sourceDate: Date?
    let displayName: String?
    let status: ShiftBatchItemStatus
    let isRestDay: Bool
    let eventDrafts: [CalendarEvent]
    let sourceEventSnapshots: [CalendarEvent]

    init(
        id: UUID = UUID(),
        targetDate: Date,
        sourceDate: Date? = nil,
        displayName: String? = nil,
        status: ShiftBatchItemStatus,
        isRestDay: Bool = false,
        eventDrafts: [CalendarEvent] = [],
        sourceEventSnapshots: [CalendarEvent] = []
    ) {
        self.id = id
        self.targetDate = targetDate
        self.sourceDate = sourceDate
        self.displayName = displayName
        self.status = status
        self.isRestDay = isRestDay
        self.eventDrafts = eventDrafts
        self.sourceEventSnapshots = sourceEventSnapshots
    }
}

struct ShiftBatchOperationPlan: Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let calendarID: UUID
    let mode: ShiftBatchMode
    let items: [ShiftBatchOperationItem]
    let issues: Set<ShiftBatchPlanIssue>
    let requiredTemplateSnapshots: [ShiftBatchTemplateSnapshot]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        calendarID: UUID,
        mode: ShiftBatchMode,
        items: [ShiftBatchOperationItem],
        issues: Set<ShiftBatchPlanIssue> = [],
        requiredTemplateSnapshots: [ShiftBatchTemplateSnapshot] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.calendarID = calendarID
        self.mode = mode
        self.items = items
        self.issues = issues
        self.requiredTemplateSnapshots = requiredTemplateSnapshots
    }

    var eventsToCreate: [CalendarEvent] {
        items.flatMap(\.eventDrafts)
    }

    var selectedDateCount: Int { items.count }
    var createCount: Int { eventsToCreate.count }
    var restDayCount: Int { items.filter(\.isRestDay).count }
    var noSourceCount: Int { items.filter { $0.status == .noSource }.count }
    var conflictCount: Int { items.filter { $0.status == .conflict }.count }
    var invalidCount: Int { items.filter { $0.status == .invalidTemplate }.count }
    var canExecute: Bool { !eventsToCreate.isEmpty && issues.isEmpty }
}

struct ShiftBatchUndoSnapshot: Equatable {
    let batchID: UUID
    let createdEvents: [CalendarEvent]
}

struct ShiftBatchOperationResult: Equatable {
    let batchID: UUID
    let createdCount: Int
    let skippedCount: Int
    let auxiliaryFailureCount: Int
    let undoSnapshot: ShiftBatchUndoSnapshot
}

struct ShiftBatchUndoResult: Equatable {
    let deletedCount: Int
    let editedCount: Int
    let missingCount: Int
}
