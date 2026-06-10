import Foundation

/// ICS 解析错误
enum ICSParseError: Error, LocalizedError {
    case invalidFormat
    case emptyContent
    case parseFailed(line: Int, content: String)
    case invalidDate(String)
    case missingRequiredField(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return LocalizationManager.shared.localized(.icsParseErrorInvalidFormat)
        case .emptyContent:
            return LocalizationManager.shared.localized(.icsParseErrorEmptyContent)
        case .parseFailed(let line, let content):
            return String(format: LocalizationManager.shared.localized(.icsParseErrorParseFailed), line, content)
        case .invalidDate(let dateStr):
            return String(format: LocalizationManager.shared.localized(.icsParseErrorInvalidDate), dateStr)
        case .missingRequiredField(let field):
            return String(format: LocalizationManager.shared.localized(.icsParseErrorMissingRequiredField), field)
        }
    }
}

/// ICS 解析服务
protocol ICSParsing {
    func parse(data: Data, region: HolidayRegion, sourceURL: String) throws -> [HolidayEvent]
    func parse(content: String, region: HolidayRegion, sourceURL: String) throws -> [HolidayEvent]
}

class ICSParseService: ICSParsing {

    // ICS 最大文件大小限制 (10MB)
    private let maxFileSize: Int = 10 * 1024 * 1024

    // 最大事件数量限制
    private let maxEventCount: Int = 1000

    func parse(data: Data, region: HolidayRegion, sourceURL: String) throws -> [HolidayEvent] {

        guard let content = String(data: data, encoding: .utf8) else {
            throw ICSParseError.invalidFormat
        }
        return try parse(content: content, region: region, sourceURL: sourceURL)
    }

    func parse(content: String, region: HolidayRegion, sourceURL: String) throws -> [HolidayEvent] {

        // 1. Normalize line endings: CRLF/CR -> LF
        let normalizedContent = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let trimmedContent = normalizedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw ICSParseError.emptyContent
        }

        // 检查 VCALENDAR 开始和结束标记
        guard trimmedContent.contains("BEGIN:VCALENDAR"),
              trimmedContent.contains("END:VCALENDAR") else {
            throw ICSParseError.invalidFormat
        }

        // 2. Unfold lines (RFC5545: lines starting with space/tab are continuation)
        let unfoldedLines = unfoldICSLines(text: trimmedContent)

        // DEBUG: body 级别日志

        var events: [HolidayEvent] = []
        var inVEvent = false
        var currentEventLines: [String] = []
        var vEventCount = 0

        // 3. Parse by VEVENT blocks

        for line in unfoldedLines {
            if line == "BEGIN:VEVENT" {
                inVEvent = true
                vEventCount += 1
                currentEventLines = []
            } else if line == "END:VEVENT" {
                inVEvent = false
                if let event = try parseVEventLines(lines: currentEventLines, region: region, sourceURL: sourceURL) {
                    events.append(event)
                }
                currentEventLines = []
            } else if inVEvent {
                currentEventLines.append(line)
            }

            // 检查事件数量限制
            if events.count >= maxEventCount {
                break
            }
        }

        // 4. DEBUG logs

        return events
    }

    /// Unfold ICS lines according to RFC5545
    /// Lines starting with space or tab are continuation of the previous line
    private func unfoldICSLines(text: String) -> [String] {
        var result: [String] = []

        for rawLine in text.components(separatedBy: "\n") {
            if rawLine.hasPrefix(" ") || rawLine.hasPrefix("\t") {
                if !result.isEmpty {
                    result[result.count - 1] += String(rawLine.dropFirst())
                }
            } else {
                result.append(rawLine)
            }
        }

        return result
    }

    /// 处理 ICS 行折叠
    private func handleLineFold(lines: [String], startIndex: inout Int, currentLine: String) -> String {
        var result = currentLine

        // 检查后续行是否有行折叠（以空格或制表符开头）
        var nextIndex = startIndex + 1
        while nextIndex < lines.count {
            let nextLine = lines[nextIndex]
            if nextLine.hasPrefix(" ") || nextLine.hasPrefix("\t") {
                result += String(nextLine.dropFirst())
                startIndex = nextIndex
                nextIndex += 1
            } else {
                break
            }
        }

        return result
    }

    /// 解析 VEVENT 属性（旧方法，保留用于兼容）
    private func parseVEventProperty(line: String, into dict: inout [String: String]) {
        // 处理带参数的属性：DTSTART;VALUE=DATE:20260101
        let components = line.split(separator: ":", maxSplits: 1)
        guard components.count == 2 else { return }

        let keyPart = String(components[0])
        let value = String(components[1])

        // 提取属性名（去掉参数部分）
        let key = keyPart.split(separator: ";").first.map(String.init) ?? keyPart

        // 存储值
        dict[key] = (dict[key] ?? "") + value
    }

    /// 解析 VEVENT 属性（新方法，支持完整 RFC5545 格式）
    private func parseVEventPropertyAdvanced(line: String, into dict: inout [String: String]) {
        // 必须包含冒号
        guard let colonIndex = line.firstIndex(of: ":") else { return }

        let keyPart = String(line[..<colonIndex])
        let value = String(line[line.index(after: colonIndex)...])

        // 提取属性名（去掉参数部分，如 DTSTART;VALUE=DATE -> DTSTART）
        let key = keyPart.split(separator: ";").first.map(String.init) ?? keyPart

        // 存储值（累加，以防值被拆分）
        dict[key] = (dict[key] ?? "") + value
    }

    /// 解析单个 VEVENT（新方法，基于 lines）
    private func parseVEventLines(lines: [String], region: HolidayRegion, sourceURL: String) throws -> HolidayEvent? {
        var properties: [String: String] = [:]

        for line in lines {
            parseVEventPropertyAdvanced(line: line, into: &properties)
        }

        return try parseVEvent(properties: properties, region: region, sourceURL: sourceURL)
    }

    /// 解析单个 VEVENT
    private func parseVEvent(properties: [String: String], region: HolidayRegion, sourceURL: String) throws -> HolidayEvent? {
        // 必填字段
        guard let summary = properties["SUMMARY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !summary.isEmpty else {
            return nil  // 没有 SUMMARY 的事件跳过
        }

        // 解析日期 - 支持多种 DTSTART 格式
        guard let date = parseDate(from: properties) else {
            return nil  // 无法解析日期则跳过
        }

        // 生成唯一 ID
        let uid = properties["UID"] ?? "\(region.rawValue)_\(date.year)_\(date.month)_\(date.day)_\(summary.hashValue)"

        // 解析事件类型
        let type = parseEventType(from: properties, summary: summary)

        // 5. Unescape SUMMARY (ICS escape sequences)
        let unescapedSummary = unescapeICSString(summary)

        return HolidayEvent(
            id: uid,
            region: region,
            date: date,
            name: unescapedSummary,
            translatedNames: [:],  // ICS 通常不包含多语言翻译，后续可根据需要扩展
            type: type,
            sourceURL: sourceURL
        )
    }

    /// Unescape ICS string according to RFC5545
    /// Supports: \\n, \\,, \\;, \\\\
    private func unescapeICSString(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    /// 解析日期（支持 DATE 和 DATE-TIME 格式）
    private func parseDate(from properties: [String: String]) -> DateOnly? {
        // 尝试多种 DTSTART 键名（按优先级）
        // Office Holidays 使用：DTSTART;VALUE=DATE
        // Google Calendar 使用：DTSTART
        let possibleKeys = ["DTSTART;VALUE=DATE", "DTSTART"]

        for key in possibleKeys {
            if let dateStr = properties[key] {
                let date = parseICSDate(dateStr)
                if date != nil {
                    return date
                }
            }
        }


        // 尝试从 RRULE 解析（跳过重复事件）
        return nil
    }

    /// 从 ICS 文本解析日期（支持多种格式）
    private func parseICSDate(_ text: String) -> DateOnly? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)


        // 1. 格式：YYYYMMDD (DATE 格式) - Office Holidays 标准格式
        if cleaned.count == 8, cleaned.allSatisfy({ $0.isNumber }) {
            if let year = Int(cleaned.prefix(4)),
               let month = Int(cleaned.substring(from: 4, length: 2) ?? ""),
               let day = Int(cleaned.substring(from: 6, length: 2) ?? ""),
               month >= 1 && month <= 12 && day >= 1 && day <= 31 {
                return DateOnly(year: year, month: month, day: day)
            }
        }

        // 2. 格式：YYYYMMDDTHHMMSSZ (DATE-TIME 格式 with Z)
        if cleaned.count == 16,
           cleaned.hasSuffix("Z"),
           cleaned.contains("T"),
           let year = Int(cleaned.prefix(4)),
           let month = Int(cleaned.substring(from: 4, length: 2) ?? ""),
           let day = Int(cleaned.substring(from: 6, length: 2) ?? ""),
           month >= 1 && month <= 12 && day >= 1 && day <= 31 {
            return DateOnly(year: year, month: month, day: day)
        }

        // 3. 格式：YYYYMMDDTHHMMSS (DATE-TIME 格式 without Z)
        if cleaned.count == 15,
           cleaned.contains("T"),
           let year = Int(cleaned.prefix(4)),
           let month = Int(cleaned.substring(from: 4, length: 2) ?? ""),
           let day = Int(cleaned.substring(from: 6, length: 2) ?? ""),
           month >= 1 && month <= 12 && day >= 1 && day <= 31 {
            return DateOnly(year: year, month: month, day: day)
        }

        // 4. 格式：YYYY-MM-DD (带连字符)
        if cleaned.count == 10,
           cleaned.contains("-"),
           let year = Int(cleaned.prefix(4)),
           let month = Int(cleaned.substring(from: 5, length: 2) ?? ""),
           let day = Int(cleaned.substring(from: 8, length: 2) ?? ""),
           month >= 1 && month <= 12 && day >= 1 && day <= 31 {
            return DateOnly(year: year, month: month, day: day)
        }

        return nil
    }

    /// 从属性或摘要推断事件类型
    private func parseEventType(from properties: [String: String], summary: String) -> HolidayEventType {
        let lowerSummary = summary.lowercased()

        // 根据关键词判断类型
        if lowerSummary.contains("observance") || lowerSummary.contains("memorial") || lowerSummary.contains("commemoration") {
            return .observance
        }

        // 传统节假日（根据地区判断）
        switch properties["X-WR-CALNAME"]?.lowercased() {
        case "china", "chinese":
            if lowerSummary.contains("lunar") || lowerSummary.contains("spring festival") ||
               lowerSummary.contains("dragon boat") || lowerSummary.contains("mid-autumn") {
                return .traditional
            }
        case "korea", "korean":
            if lowerSummary.contains("lunar") || lowerSummary.contains("설날") ||
               lowerSummary.contains("추석") {
                return .traditional
            }
        default:
            break
        }

        return .publicHoliday
    }
}

// MARK: - String 扩展

private extension String {
    func substring(from: Int, length: Int) -> String? {
        guard from >= 0 && from + length <= count else { return nil }
        let start = index(startIndex, offsetBy: from)
        let end = index(start, offsetBy: length)
        return String(self[start..<end])
    }
}
