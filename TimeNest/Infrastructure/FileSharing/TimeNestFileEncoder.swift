import Foundation

/// 将事件列表编码为 .timenest 文件
struct TimeNestFileEncoder {

    enum EncodingError: Error, LocalizedError {
        case serializationFailed
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .serializationFailed:
                return LocalizationManager.shared.localized(.fileSharingErrorSerializationFailed)
            case .writeFailed:
                return LocalizationManager.shared.localized(.fileSharingErrorWriteFailed)
            }
        }
    }

    /// 将事件列表编码为 .timenest 文件 URL
    /// - Parameters:
    ///   - events: 要导出的事件列表
    ///   - title: 导出文件的标题
    ///   - directory: 写入目录（默认为临时目录）
    /// - Returns: 生成的文件 URL
    func encode(events: [CalendarEvent], title: String, directory: URL? = nil) throws -> URL {
        let exportFile = TimeNestExportFile(
            schemaVersion: TimeNestExportFile.currentSchemaVersion,
            exportedAt: Date(),
            title: title,
            events: events.map { TimeNestExportEvent(from: $0) }
        )

        let jsonData: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            jsonData = try encoder.encode(exportFile)
        } catch {
            throw EncodingError.serializationFailed
        }

        let fileURL: URL
        if let directory = directory {
            fileURL = directory.appendingPathComponent(filename(for: title))
        } else {
            let tempDir = FileManager.default.temporaryDirectory
            fileURL = tempDir.appendingPathComponent(filename(for: title))
        }

        do {
            try jsonData.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            throw EncodingError.writeFailed
        }
    }

    private func filename(for title: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let timestamp = formatter.string(from: Date())

        let sanitizedTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        let baseName = sanitizedTitle.isEmpty ? "TimeNest" : sanitizedTitle
        return "\(baseName)-\(timestamp).timenest"
    }
}
