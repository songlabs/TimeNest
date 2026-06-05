import Foundation

/// 时间表文件导出 UseCase
/// 负责将本地事件导出为 .timenest 文件
class TimeNestFileExportUseCase {

    private let eventRepository: EventRepository
    private let fileEncoder: TimeNestFileEncoder

    init(
        eventRepository: EventRepository,
        fileEncoder: TimeNestFileEncoder = TimeNestFileEncoder()
    ) {
        self.eventRepository = eventRepository
        self.fileEncoder = fileEncoder
    }

    /// 导出指定时间范围内的事件
    /// - Parameters:
    ///   - range: 要导出的时间范围
    ///   - title: 导出文件的标题
    /// - Returns: 生成的文件 URL
    func exportEvents(in range: DateInterval, title: String) async throws -> URL {
        let events = try await eventRepository.events(in: range)
        return try fileEncoder.encode(events: events, title: title)
    }

    /// 导出所有事件（无时间限制）
    /// - Parameter title: 导出文件的标题
    /// - Returns: 生成的文件 URL
    func exportAllEvents(title: String) async throws -> URL {
        // 导出从 1970 年到 2100 年的所有事件
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 4102444800) // 2100-01-01
        let range = DateInterval(start: start, end: end)
        return try await exportEvents(in: range, title: title)
    }
}
