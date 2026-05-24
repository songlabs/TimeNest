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
            return "无效的 ICS 格式"
        case .emptyContent:
            return "ICS 内容为空"
        case .parseFailed(let line, let content):
            return "第 \(line) 行解析失败：\(content)"
        case .invalidDate(let dateStr):
            return "无效的日期格式：\(dateStr)"
        case .missingRequiredField(let field):
            return "缺少必填字段：\(field)"
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
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw ICSParseError.emptyContent
        }

        // 检查 VCALENDAR 开始和结束标记
        guard trimmedContent.contains("BEGIN:VCALENDAR"),
              trimmedContent.contains("END:VCALENDAR") else {
            throw ICSParseError.invalidFormat
        }

        var events: [HolidayEvent] = []
        let lines = trimmedContent.components(separatedBy: .newlines)

        var inVEvent = false
        var currentEvent: [String: String] = [:]
        var lineIndex = 0

        for line in lines {
            lineIndex += 1

            // 处理行折叠（以空格开头的行是上一行的延续）
            let unfoldedLine = handleLineFold(lines: lines, startIndex: &lineIndex, currentLine: line)

            if unfoldedLine.hasPrefix("BEGIN:VEVENT") {
                inVEvent = true
                currentEvent = [:]
            } else if unfoldedLine.hasPrefix("END:VEVENT") {
                inVEvent = false
                if let event = try parseVEvent(currentEvent, region: region, sourceURL: sourceURL) {
                    events.append(event)
                }
                currentEvent = [:]
            } else if inVEvent {
                parseVEventProperty(line: unfoldedLine, into: &currentEvent)
            }

            // 检查事件数量限制
            if events.count >= maxEventCount {
                break
            }
        }

        return events
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

    /// 解析 VEVENT 属性
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

    /// 解析单个 VEVENT
    private func parseVEvent(_ properties: [String: String], region: HolidayRegion, sourceURL: String) throws -> HolidayEvent? {
        // 必填字段
        guard let summary = properties["SUMMARY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !summary.isEmpty else {
            return nil  // 没有 SUMMARY 的事件跳过
        }

        // 解析日期
        guard let date = parseDate(from: properties) else {
            return nil  // 无法解析日期则跳过
        }

        // 生成唯一 ID
        let uid = properties["UID"] ?? "\(region.rawValue)_\(date.year)_\(date.month)_\(date.day)_\(summary.hashValue)"

        // 解析事件类型
        let type = parseEventType(from: properties, summary: summary)

        return HolidayEvent(
            id: uid,
            region: region,
            date: date,
            name: summary,
            translatedNames: [:],  // ICS 通常不包含多语言翻译，后续可根据需要扩展
            type: type,
            sourceURL: sourceURL
        )
    }

    /// 解析日期（支持 DATE 和 DATE-TIME 格式）
    private func parseDate(from properties: [String: String]) -> DateOnly? {
        // 优先使用 DTSTART;VALUE=DATE 格式
        if let dateStr = properties["DTSTART;VALUE=DATE"] ?? properties["DTSTART"] {
            return parseDateFromICSText(dateStr)
        }

        // 尝试从 RRULE 解析（跳过重复事件）
        return nil
    }

    /// 从 ICS 文本解析日期
    private func parseDateFromICSText(_ text: String) -> DateOnly? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 格式：YYYYMMDD (DATE 格式)
        if cleaned.count == 8,
           let year = Int(cleaned.prefix(4)),
           let monthStr = cleaned.substring(from: 4, length: 2),
           let month = Int(monthStr),
           let day = Int(String(cleaned.suffix(4))),
           month >= 1 && month <= 12 && day >= 1 && day <= 31 {
            return DateOnly(year: year, month: month, day: day)
        }

        // 格式：YYYYMMDDTHHMMSSZ (DATE-TIME 格式)
        if cleaned.count >= 15,
           let year = Int(cleaned.prefix(4)),
           let monthStr = cleaned.substring(from: 4, length: 2),
           let month = Int(monthStr),
           let dayStr = cleaned.substring(from: 6, length: 2),
           let day = Int(dayStr) {
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
