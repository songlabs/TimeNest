import Foundation

/// 时间表文件导入 UseCase
/// 负责从 .timenest 文件导入事件到本地
class TimeNestFileImportUseCase {

    private let eventRepository: EventRepository
    private let fileDecoder: TimeNestFileDecoder

    enum ImportError: Error, LocalizedError {
        case decodeFailed
        case importFailed
        case noEvents

        var errorDescription: String? {
            switch self {
            case .decodeFailed:
                return LocalizationManager.shared.localized(.fileSharingErrorDecodeFailed)
            case .importFailed:
                return LocalizationManager.shared.localized(.fileSharingErrorImportFailed)
            case .noEvents:
                return LocalizationManager.shared.localized(.fileSharingErrorNoEvents)
            }
        }
    }

    /// 导入结果
    struct ImportResult {
        let importedCount: Int
        let skippedCount: Int
        let errorMessage: String?
    }

    init(
        eventRepository: EventRepository,
        fileDecoder: TimeNestFileDecoder = TimeNestFileDecoder()
    ) {
        self.eventRepository = eventRepository
        self.fileDecoder = fileDecoder
    }

    /// 从文件导入事件
    /// - Parameter url: .timenest 文件 URL
    /// - Returns: 导入结果
    func importEvents(from url: URL) async throws -> ImportResult {
        let events: [CalendarEvent]
        do {
            events = try fileDecoder.decode(from: url)
        } catch {
            throw ImportError.decodeFailed
        }

        guard !events.isEmpty else {
            throw ImportError.noEvents
        }

        var importedCount = 0
        var skippedCount = 0

        for event in events {
            // 重新生成 ID 避免冲突
            let newEvent = CalendarEvent(
                id: UUID(),
                title: event.title,
                note: event.note,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                categoryID: event.categoryID,
                recurrenceRule: event.recurrenceRule,
                reminderTemplateID: event.reminderTemplateID,
                importSource: event.importSource,
                createdAt: event.createdAt,
                updatedAt: event.updatedAt
            )
            do {
                try await eventRepository.create(newEvent)
                importedCount += 1
            } catch {
                skippedCount += 1
            }
        }

        return ImportResult(
            importedCount: importedCount,
            skippedCount: skippedCount,
            errorMessage: skippedCount > 0 ? LocalizationManager.shared.localized(.fileSharingErrorPartialImportFailed) : nil
        )
    }
}
