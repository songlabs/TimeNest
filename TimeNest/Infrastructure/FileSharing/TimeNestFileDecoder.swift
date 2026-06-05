import Foundation

/// 从 .timenest 文件解码事件列表
struct TimeNestFileDecoder {

    enum DecodingError: Error, LocalizedError {
        case fileNotFound
        case invalidData
        case schemaVersionMismatch
        case parseFailed

        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "文件未找到"
            case .invalidData:
                return "文件格式无效"
            case .schemaVersionMismatch:
                return "不支持的文件版本"
            case .parseFailed:
                return "解析失败"
            }
        }
    }

    /// 从文件 URL 解码事件列表
    /// - Parameter url: .timenest 文件 URL
    /// - Returns: 解码后的事件列表
    func decode(from url: URL) throws -> [CalendarEvent] {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DecodingError.fileNotFound
        }

        let exportFile: TimeNestExportFile
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            exportFile = try decoder.decode(TimeNestExportFile.self, from: data)
        } catch {
            throw DecodingError.invalidData
        }

        // 校验 schema version
        guard exportFile.schemaVersion == TimeNestExportFile.currentSchemaVersion else {
            throw DecodingError.schemaVersionMismatch
        }

        return exportFile.events.map { $0.toCalendarEvent() }
    }
}
