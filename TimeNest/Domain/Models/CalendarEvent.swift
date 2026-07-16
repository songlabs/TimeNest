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
