import Foundation

struct WorkInfo: Codable, Hashable {
    var workInTime: Date?
    var workOutTime: Date?
    var restHours: Double
    var workDate: Date?
    var transportFee: Int?
    var hourlyRate: Int?
    var workSessionId: UUID?

    init(workInTime: Date? = nil, workOutTime: Date? = nil, restHours: Double = 1.0, workDate: Date? = nil, transportFee: Int? = nil, hourlyRate: Int? = nil, workSessionId: UUID? = nil) {
        self.workInTime = workInTime
        self.workOutTime = workOutTime
        self.restHours = restHours
        self.workDate = workDate
        self.transportFee = transportFee
        self.hourlyRate = hourlyRate
        self.workSessionId = workSessionId
    }

    static func makeNewWorkSessionId() -> UUID {
        UUID()
    }
}

struct CalendarEvent: Identifiable, Codable, Hashable {
    let id: UUID
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
