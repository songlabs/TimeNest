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

    // 最大事件数量限制
    private let maxEventCount: Int = 1000

    func parse(data: Data, region: HolidayRegion, sourceURL: String) throws -> [HolidayEvent] {
        let content = try ICSContentDecoder.decode(data)
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

        var events: [HolidayEvent] = []
        var inVEvent = false
        var currentEventLines: [String] = []

        // 3. Parse by VEVENT blocks

        for line in unfoldedLines {
            if line == "BEGIN:VEVENT" {
                inVEvent = true
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

        guard !events.isEmpty else {
            throw EnhancedICSError.noEvents
        }

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

    private struct ICSPropertyValue {
        let value: String
        let parameters: [String: String]
    }

    private typealias ICSProperties = [String: ICSPropertyValue]

    /// Parse a VEVENT property while retaining parameters such as
    /// VALUE=DATE and TZID=Asia/Tokyo.
    private func parseVEventPropertyAdvanced(line: String, into dict: inout ICSProperties) {
        // 必须包含冒号
        guard let colonIndex = line.firstIndex(of: ":") else { return }

        let keyPart = String(line[..<colonIndex])
        let value = String(line[line.index(after: colonIndex)...])
        let keyComponents = keyPart.split(separator: ";", omittingEmptySubsequences: false)

        guard let rawName = keyComponents.first, !rawName.isEmpty else { return }
        let key = rawName.uppercased()
        var parameters: [String: String] = [:]

        for component in keyComponents.dropFirst() {
            let pair = component.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { continue }
            parameters[String(pair[0]).uppercased()] = String(pair[1])
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }

        dict[key] = ICSPropertyValue(value: value, parameters: parameters)
    }

    /// 解析单个 VEVENT（新方法，基于 lines）
    private func parseVEventLines(lines: [String], region: HolidayRegion, sourceURL: String) throws -> HolidayEvent? {
        var properties: ICSProperties = [:]

        for line in lines {
            parseVEventPropertyAdvanced(line: line, into: &properties)
        }

        return try parseVEvent(properties: properties, region: region, sourceURL: sourceURL)
    }

    /// 解析单个 VEVENT
    private func parseVEvent(properties: ICSProperties, region: HolidayRegion, sourceURL: String) throws -> HolidayEvent? {
        // 必填字段
        guard let summary = properties["SUMMARY"]?.value.trimmingCharacters(in: .whitespacesAndNewlines),
              !summary.isEmpty else {
            return nil  // 没有 SUMMARY 的事件跳过
        }

        // 解析日期 - 支持多种 DTSTART 格式
        guard let date = parseDate(from: properties) else {
            return nil  // 无法解析日期则跳过
        }

        // 生成唯一 ID
        let uid = properties["UID"]?.value
            ?? "\(region.rawValue)_\(date.year)_\(date.month)_\(date.day)_\(summary.hashValue)"

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
    private func parseDate(from properties: ICSProperties) -> DateOnly? {
        guard let start = properties["DTSTART"] else {
            return nil
        }

        let valueType = start.parameters["VALUE"]?.uppercased()
        if valueType == "DATE" {
            return parseGregorianDate(start.value)
        }
        guard valueType == nil || valueType == "DATE-TIME" else {
            return nil
        }
        return parseICSDateTimeOrDate(start.value)
    }

    /// Parse DATE-TIME using its written calendar day.
    ///
    /// The TZID parameter is retained by the property parser, but this holiday
    /// cache stores DateOnly and does not claim full RFC 5545 VTIMEZONE,
    /// recurrence, alias, or historical DST support.
    private func parseICSDateTimeOrDate(_ text: String) -> DateOnly? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.count == 8 {
            return parseGregorianDate(cleaned)
        }

        if cleaned.count == 16, cleaned.hasSuffix("Z") {
            let localDateTime = String(cleaned.dropLast())
            guard isValidTime(in: localDateTime) else { return nil }
            return parseGregorianDate(String(localDateTime.prefix(8)))
        }

        if cleaned.count == 15 {
            guard isValidTime(in: cleaned) else { return nil }
            return parseGregorianDate(String(cleaned.prefix(8)))
        }

        if cleaned.count == 10,
           cleaned[cleaned.index(cleaned.startIndex, offsetBy: 4)] == "-",
           cleaned[cleaned.index(cleaned.startIndex, offsetBy: 7)] == "-" {
            return parseGregorianDate(cleaned.replacingOccurrences(of: "-", with: ""))
        }

        return nil
    }

    private func parseGregorianDate(_ text: String) -> DateOnly? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count == 8,
              cleaned.allSatisfy(\.isNumber),
              let year = Int(cleaned.prefix(4)),
              let month = Int(cleaned.substring(from: 4, length: 2) ?? ""),
              let day = Int(cleaned.substring(from: 6, length: 2) ?? "") else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day

        guard let date = calendar.date(from: components) else { return nil }
        let validated = calendar.dateComponents([.year, .month, .day], from: date)
        guard validated.year == year,
              validated.month == month,
              validated.day == day else {
            return nil
        }

        return DateOnly(year: year, month: month, day: day)
    }

    private func isValidTime(in text: String) -> Bool {
        guard text.count == 15,
              text[text.index(text.startIndex, offsetBy: 8)] == "T" else {
            return false
        }

        let timeText = String(text.suffix(6))
        guard timeText.allSatisfy(\.isNumber),
              let hour = Int(timeText.prefix(2)),
              let minute = Int(timeText.substring(from: 2, length: 2) ?? ""),
              let second = Int(timeText.substring(from: 4, length: 2) ?? "") else {
            return false
        }

        return (0...23).contains(hour)
            && (0...59).contains(minute)
            && (0...60).contains(second)
    }

    /// 从属性或摘要推断事件类型
    private func parseEventType(from properties: ICSProperties, summary: String) -> HolidayEventType {
        let lowerSummary = summary.lowercased()

        // 根据关键词判断类型
        if lowerSummary.contains("observance") || lowerSummary.contains("memorial") || lowerSummary.contains("commemoration") {
            return .observance
        }

        // 传统节假日（根据地区判断）
        switch properties["X-WR-CALNAME"]?.value.lowercased() {
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
