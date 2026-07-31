import Foundation

/// .timenest 导出文件格式
struct TimeNestExportFile: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let title: String
    let events: [TimeNestExportEvent]
}

/// .timenest 导出文件中的单个事件
struct TimeNestExportEvent: Codable {
    let id: UUID
    let unifiedEntryID: UUID?
    let title: String
    let note: String?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let categoryID: UUID?
    let recurrenceRule: String?
    let reminderOffsetMinutes: Int?
    let notificationID: String?
    let shiftTemplateID: ShiftTimeTemplateID?
    let workInfo: WorkInfo?

    private enum CodingKeys: String, CodingKey {
        case id
        case unifiedEntryID
        case title
        case note
        case startDate
        case endDate
        case isAllDay
        case categoryID
        case recurrenceRule
        case reminderOffsetMinutes
        case notificationID
        case shiftTemplateID
        case workInfo
    }

    init(
        id: UUID,
        unifiedEntryID: UUID? = nil,
        title: String,
        note: String?,
        startDate: Date,
        endDate: Date?,
        isAllDay: Bool,
        categoryID: UUID?,
        recurrenceRule: String?,
        reminderOffsetMinutes: Int?,
        notificationID: String?,
        shiftTemplateID: ShiftTimeTemplateID? = nil,
        workInfo: WorkInfo? = nil
    ) {
        self.id = id
        self.unifiedEntryID = unifiedEntryID
        self.title = title
        self.note = note
        self.startDate = startDate
        self.endDate = endDate ?? CalendarEvent.defaultEndDate(for: startDate, isAllDay: isAllDay)
        self.isAllDay = isAllDay
        self.categoryID = categoryID
        self.recurrenceRule = recurrenceRule
        self.reminderOffsetMinutes = reminderOffsetMinutes
        self.notificationID = notificationID
        self.shiftTemplateID = shiftTemplateID
        self.workInfo = workInfo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        unifiedEntryID = try container.decodeIfPresent(
            UUID.self,
            forKey: .unifiedEntryID
        )
        title = try container.decode(String.self, forKey: .title)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        startDate = try container.decode(Date.self, forKey: .startDate)
        isAllDay = try container.decodeIfPresent(Bool.self, forKey: .isAllDay) ?? false
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate) ?? CalendarEvent.defaultEndDate(for: startDate, isAllDay: isAllDay)
        categoryID = try container.decodeIfPresent(UUID.self, forKey: .categoryID)
        recurrenceRule = try container.decodeIfPresent(String.self, forKey: .recurrenceRule)
        reminderOffsetMinutes = try container.decodeIfPresent(Int.self, forKey: .reminderOffsetMinutes)
        notificationID = try container.decodeIfPresent(String.self, forKey: .notificationID)
        shiftTemplateID = try container.decodeIfPresent(ShiftTimeTemplateID.self, forKey: .shiftTemplateID)
        workInfo = try container.decodeIfPresent(WorkInfo.self, forKey: .workInfo)
    }
}

extension TimeNestExportFile {
    static let currentSchemaVersion = 1
}

extension TimeNestExportEvent {
    /// 从 CalendarEvent 转换为导出事件
    init(from event: CalendarEvent) {
        self.init(
            id: event.id,
            unifiedEntryID: event.unifiedEntryID,
            title: event.title,
            note: event.note,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            categoryID: event.categoryID,
            recurrenceRule: event.recurrenceRule.rawValue,
            reminderOffsetMinutes: event.reminderOffsetMinutes,
            notificationID: event.notificationID,
            shiftTemplateID: event.shiftTemplateID,
            workInfo: event.workInfo
        )
    }

    /// 转换为 CalendarEvent（导入时使用）
    func toCalendarEvent() -> CalendarEvent {
        CalendarEvent(
            id: id,
            unifiedEntryID: unifiedEntryID,
            title: title,
            note: note,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            categoryID: categoryID,
            recurrenceRule: RecurrenceRule(rawValue: recurrenceRule ?? "none") ?? .none,
            reminderTemplateID: nil,
            reminderOffsetMinutes: reminderOffsetMinutes,
            notificationID: nil,
            importSource: nil,
            createdAt: Date(),
            updatedAt: Date(),
            shiftTemplateID: shiftTemplateID,
            workInfo: workInfo
        )
    }
}
