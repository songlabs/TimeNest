import Foundation

struct EventOccurrence: Identifiable, Hashable {
    let id: String
    let eventID: UUID
    let occurrenceDate: DateOnly
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let title: String
    let note: String?
    let categoryID: UUID?
    let reminderOffsetMinutes: Int?
    let notificationID: String?
    let shiftTemplateID: ShiftTimeTemplateID?
    let workInfo: WorkInfo?
}

enum WorkClockKind: Hashable {
    case clockIn
    case clockOut
}

extension EventOccurrence {
    var workClockKind: WorkClockKind? {
        if let kind = WorkClockTitleMatcher.kind(for: workInfo) {
            return kind
        }
        return WorkClockTitleMatcher.kind(for: title)
    }

    var isClockInEvent: Bool {
        workClockKind == .clockIn
    }

    var isClockOutEvent: Bool {
        workClockKind == .clockOut
    }

    var isWorkClockEvent: Bool {
        isClockInEvent || isClockOutEvent
    }

    var workDate: Date {
        workInfo?.workDate ?? startDate
    }

    var actualWorkClockDate: Date {
        if isClockInEvent {
            return workInfo?.workInTime ?? startDate
        }
        if isClockOutEvent {
            return workInfo?.workOutTime ?? startDate
        }
        return startDate
    }

    var isWorkOutTimeSet: Bool {
        workInfo?.isWorkOutTimeSet ?? false
    }

    func matchesWorkClockKind(_ kind: WorkClockKind) -> Bool {
        switch kind {
        case .clockIn:
            return isClockInEvent
        case .clockOut:
            return isClockOutEvent
        }
    }
}

extension CalendarEvent {
    var workClockKind: WorkClockKind? {
        if let kind = WorkClockTitleMatcher.kind(for: workInfo) {
            return kind
        }
        return WorkClockTitleMatcher.kind(for: title)
    }

    var isClockInEvent: Bool {
        workClockKind == .clockIn
    }

    var isClockOutEvent: Bool {
        workClockKind == .clockOut
    }

    var workDate: Date {
        workInfo?.workDate ?? startDate
    }

    var actualWorkClockDate: Date {
        if isClockInEvent {
            return workInfo?.workInTime ?? startDate
        }
        if isClockOutEvent {
            return workInfo?.workOutTime ?? startDate
        }
        return startDate
    }

    var isWorkOutTimeSet: Bool {
        workInfo?.isWorkOutTimeSet ?? false
    }
}

enum WorkClockTitleMatcher {
    private static let clockInTitles: Set<String> = ["出勤", "Clock In", "上班", "출근"]
    private static let clockOutTitles: Set<String> = ["退勤", "Clock Out", "下班", "퇴근"]

    static func kind(for title: String) -> WorkClockKind? {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if clockInTitles.contains(normalizedTitle) {
            return .clockIn
        }
        if clockOutTitles.contains(normalizedTitle) {
            return .clockOut
        }
        return nil
    }

    static func kind(for workInfo: WorkInfo?) -> WorkClockKind? {
        guard let workInfo else { return nil }
        if workInfo.workInTime != nil, workInfo.workOutTime == nil {
            return .clockIn
        }
        if workInfo.workOutTime != nil, workInfo.workInTime == nil {
            return .clockOut
        }
        return nil
    }

    static func isClockInTitle(_ title: String) -> Bool {
        kind(for: title) == .clockIn
    }

    static func isClockOutTitle(_ title: String) -> Bool {
        kind(for: title) == .clockOut
    }
}
