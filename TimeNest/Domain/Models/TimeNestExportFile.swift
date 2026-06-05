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
    let title: String
    let note: String?
    let startDate: Date
    let endDate: Date?
    let isAllDay: Bool
    let categoryID: UUID?
    let recurrenceRule: String?
}

extension TimeNestExportFile {
    static let currentSchemaVersion = 1
}

extension TimeNestExportEvent {
    /// 从 CalendarEvent 转换为导出事件
    init(from event: CalendarEvent) {
        self.id = event.id
        self.title = event.title
        self.note = event.note
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.isAllDay = event.isAllDay
        self.categoryID = event.categoryID
        self.recurrenceRule = event.recurrenceRule.rawValue
    }

    /// 转换为 CalendarEvent（导入时使用）
    func toCalendarEvent() -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            note: note,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            categoryID: categoryID,
            recurrenceRule: RecurrenceRule(rawValue: recurrenceRule ?? "none") ?? .none,
            reminderTemplateID: nil,
            importSource: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
