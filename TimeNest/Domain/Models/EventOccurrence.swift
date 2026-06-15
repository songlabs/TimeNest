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
    var isClockInEvent: Bool {
        WorkClockTitleMatcher.isClockInTitle(title)
    }

    var isClockOutEvent: Bool {
        WorkClockTitleMatcher.isClockOutTitle(title)
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
    var workDate: Date {
        workInfo?.workDate ?? startDate
    }

    var actualWorkClockDate: Date {
        if WorkClockTitleMatcher.isClockInTitle(title) {
            return workInfo?.workInTime ?? startDate
        }
        if WorkClockTitleMatcher.isClockOutTitle(title) {
            return workInfo?.workOutTime ?? startDate
        }
        return startDate
    }
}

enum WorkClockTitleMatcher {
    private static let clockInTitles: Set<String> = ["出勤", "Clock In", "上班", "출근"]
    private static let clockOutTitles: Set<String> = ["退勤", "Clock Out", "下班", "퇴근"]

    static func isClockInTitle(_ title: String) -> Bool {
        clockInTitles.contains(title.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func isClockOutTitle(_ title: String) -> Bool {
        clockOutTitles.contains(title.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
