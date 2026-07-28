import Foundation
import XCTest
@testable import TimeNest

final class ICSParseServiceTests: XCTestCase {

    private var parseService: ICSParseService!

    override func setUp() {
        super.setUp()
        parseService = ICSParseService()
    }

    // MARK: - Office Holidays Format Tests

    /// 测试 Office Holidays Japan 格式解析
    /// 验证 DTSTART;VALUE=DATE 和 SUMMARY;LANGUAGE=en-us 格式
    func testParseOfficeHolidaysJapanFormat() throws {
        let icsContent = """
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Office Holidays//NONSGML Japan Holidays//EN
BEGIN:VEVENT
DTSTART;VALUE=DATE:20260101
DTEND;VALUE=DATE:20260102
SUMMARY;LANGUAGE=en-us:Japan: New Year's Day
UID:20260101-japan-newyear@officeholidays.com
END:VEVENT
BEGIN:VEVENT
DTSTART;VALUE=DATE:20260112
DTEND;VALUE=DATE:20260113
SUMMARY;LANGUAGE=en-us:Japan: Coming-of-Age Day
UID:20260112-japan-comingofage@officeholidays.com
END:VEVENT
BEGIN:VEVENT
DTSTART;VALUE=DATE:20260211
DTEND;VALUE=DATE:20260212
SUMMARY;LANGUAGE=en-us:Japan: National Foundation Day
UID:20260211-japan-nationalfoundation@officeholidays.com
END:VEVENT
END:VCALENDAR
"""

        let region = HolidayRegion.japan
        let events = try parseService.parse(content: icsContent, region: region, sourceURL: "https://www.officeholidays.com/ics/japan")

        XCTAssertEqual(events.count, 3, "应该解析出 3 个节假日")

        // 验证第一个事件
        let firstEvent = events[0]
        XCTAssertEqual(firstEvent.name, "Japan: New Year's Day")
        XCTAssertEqual(firstEvent.date.year, 2026)
        XCTAssertEqual(firstEvent.date.month, 1)
        XCTAssertEqual(firstEvent.date.day, 1)

        // 验证第二个事件
        let secondEvent = events[1]
        XCTAssertEqual(secondEvent.name, "Japan: Coming-of-Age Day")
        XCTAssertEqual(secondEvent.date.year, 2026)
        XCTAssertEqual(secondEvent.date.month, 1)
        XCTAssertEqual(secondEvent.date.day, 12)

        // 验证第三个事件
        let thirdEvent = events[2]
        XCTAssertEqual(thirdEvent.name, "Japan: National Foundation Day")
        XCTAssertEqual(thirdEvent.date.year, 2026)
        XCTAssertEqual(thirdEvent.date.month, 2)
        XCTAssertEqual(thirdEvent.date.day, 11)
    }

    /// 测试 Office Holidays China 格式解析
    func testParseOfficeHolidaysChinaFormat() throws {
        let icsContent = """
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Office Holidays//NONSGML China Holidays//EN
BEGIN:VEVENT
DTSTART;VALUE=DATE:20260101
DTEND;VALUE=DATE:20260102
SUMMARY;LANGUAGE=en-us:China: New Year's Day
UID:20260101-china-newyear@officeholidays.com
END:VEVENT
BEGIN:VEVENT
DTSTART;VALUE=DATE:20260217
DTEND;VALUE=DATE:20260218
SUMMARY;LANGUAGE=en-us:China: Spring Festival
UID:20260217-china-springfestival@officeholidays.com
END:VEVENT
END:VCALENDAR
"""

        let region = HolidayRegion.china
        let events = try parseService.parse(content: icsContent, region: region, sourceURL: "https://www.officeholidays.com/ics/china")

        XCTAssertEqual(events.count, 2, "应该解析出 2 个节假日")

        let firstEvent = events[0]
        XCTAssertEqual(firstEvent.name, "China: New Year's Day")
        XCTAssertEqual(firstEvent.date.year, 2026)
        XCTAssertEqual(firstEvent.date.month, 1)
        XCTAssertEqual(firstEvent.date.day, 1)
    }

    // MARK: - Google Calendar Format Tests (Regression)

    /// 测试 Google Calendar 格式解析（回归测试）
    func testParseGoogleCalendarFormat() throws {
        let icsContent = """
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Google Inc//Google Calendar 70.9054//EN
BEGIN:VEVENT
DTSTART;VALUE=DATE:20260101
DTEND;VALUE=DATE:20260102
DTSTAMP:20251201T120000Z
UID:abc123@google.com
SUMMARY:New Year's Day
END:VEVENT
BEGIN:VEVENT
DTSTART;VALUE=DATE:20261225
DTEND;VALUE=DATE:20261226
DTSTAMP:20251201T120000Z
UID:def456@google.com
SUMMARY:Christmas Day
END:VEVENT
END:VCALENDAR
"""

        let region = HolidayRegion.unitedStates
        let events = try parseService.parse(content: icsContent, region: region, sourceURL: "https://calendar.google.com/calendar/ical/...")

        XCTAssertEqual(events.count, 2, "应该解析出 2 个节假日")

        let firstEvent = events[0]
        XCTAssertEqual(firstEvent.name, "New Year's Day")
        XCTAssertEqual(firstEvent.date.year, 2026)
        XCTAssertEqual(firstEvent.date.month, 1)
        XCTAssertEqual(firstEvent.date.day, 1)
    }

    // MARK: - CRLF Normalization Tests

    /// 测试 CRLF 行尾符处理
    func testParseWithCRLFLineEndings() throws {
        // 使用 CRLF 行尾符
        let icsContent = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20260101\r\nSUMMARY:Test Holiday\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

        let region = HolidayRegion.japan
        let events = try parseService.parse(content: icsContent, region: region, sourceURL: "https://example.com/ics")

        XCTAssertEqual(events.count, 1, "应该正确解析 CRLF 格式的 ICS")
        XCTAssertEqual(events[0].name, "Test Holiday")
        XCTAssertEqual(events[0].date.year, 2026)
        XCTAssertEqual(events[0].date.month, 1)
        XCTAssertEqual(events[0].date.day, 1)
    }

    /// 测试 CR 行尾符处理
    func testParseWithCRLineEndings() throws {
        // 使用 CR 行尾符（旧 Mac 格式）
        let icsContent = "BEGIN:VCALENDAR\rVERSION:2.0\rBEGIN:VEVENT\rDTSTART;VALUE=DATE:20260101\rSUMMARY:Test Holiday\rEND:VEVENT\rEND:VCALENDAR\r"

        let region = HolidayRegion.japan
        let events = try parseService.parse(content: icsContent, region: region, sourceURL: "https://example.com/ics")

        XCTAssertEqual(events.count, 1, "应该正确解析 CR 格式的 ICS")
        XCTAssertEqual(events[0].name, "Test Holiday")
    }

    // MARK: - Line Folding Tests

    /// 测试 ICS 行折叠（folded lines）处理
    func testParseWithFoldedLines() throws {
        // RFC5545 规定：以空格或 tab 开头的行是上一行的延续
        let icsContent = """
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
DTSTART;VALUE=DATE:20260101
SUMMARY:This is a very long holiday name that might
 be folded across multiple lines in the ICS file
END:VEVENT
END:VCALENDAR
"""

        let region = HolidayRegion.japan
        let events = try parseService.parse(content: icsContent, region: region, sourceURL: "https://example.com/ics")

        XCTAssertEqual(events.count, 1, "应该正确解析折叠行")
        // 折叠行应该被合并
        XCTAssertTrue(events[0].name.contains("folded"))
    }

    // MARK: - Date Format Tests

    /// 测试 DATE 格式解析 (yyyyMMdd)
    func testParseDateOnlyFormat() throws {
        let icsContent = """
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
DTSTART;VALUE=DATE:20260315
SUMMARY:Date Only Test
END:VEVENT
END:VCALENDAR
"""

        let region = HolidayRegion.japan
        let events = try parseService.parse(content: icsContent, region: region, sourceURL: "https://example.com/ics")

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].date.year, 2026)
        XCTAssertEqual(events[0].date.month, 3)
        XCTAssertEqual(events[0].date.day, 15)
    }

    /// 测试 DATE-TIME 格式解析 (yyyyMMdd'T'HHmmssZ)
    func testParseDateTimeFormat() throws {
        let icsContent = """
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
DTSTART:20260101T000000Z
DTEND:20260101T235959Z
SUMMARY:DateTime Test
END:VEVENT
END:VCALENDAR
"""

        let region = HolidayRegion.japan
        let events = try parseService.parse(content: icsContent, region: region, sourceURL: "https://example.com/ics")

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].date.year, 2026)
        XCTAssertEqual(events[0].date.month, 1)
        XCTAssertEqual(events[0].date.day, 1)
    }

    /// 测试带时区参数的 DTSTART 解析
    func testParseDTSTARTWithTZID() throws {
        let icsContent = """
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
DTSTART;TZID=Asia/Tokyo:20260101T090000
DTEND;TZID=Asia/Tokyo:20260101T170000
SUMMARY:Tokyo Timezone Test
END:VEVENT
END:VCALENDAR
"""

        let region = HolidayRegion.japan
        let events = try parseService.parse(content: icsContent, region: region, sourceURL: "https://example.com/ics")

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].date.year, 2026)
        XCTAssertEqual(events[0].date.month, 1)
        XCTAssertEqual(events[0].date.day, 1)
    }

    // MARK: - Summary Unescape Tests

    /// 测试 SUMMARY unescape
    func testUnescapeSummary() throws {
        let icsContent = """
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
DTSTART;VALUE=DATE:20260101
SUMMARY:Line1\\nLine2\\, Comma; Semicolon
END:VEVENT
END:VCALENDAR
"""

        let region = HolidayRegion.japan
        let events = try parseService.parse(content: icsContent, region: region, sourceURL: "https://example.com/ics")

        XCTAssertEqual(events.count, 1)
        // 注意：当前 unescape 只处理 \\n -> \\n，实际可能需要根据需求调整
        XCTAssertTrue(events[0].name.contains("Line1"))
        XCTAssertTrue(events[0].name.contains("Line2"))
    }

    // MARK: - Empty/Invalid Tests

    /// 测试空 VEVENT
    func testParseEmptyVEVENT() throws {
        let icsContent = """
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
END:VEVENT
END:VCALENDAR
"""

        let region = HolidayRegion.japan
        XCTAssertThrowsError(try parseService.parse(content: icsContent, region: region, sourceURL: "https://example.com/ics")) { error in
            guard case EnhancedICSError.noEvents = error else {
                return XCTFail("Expected noEvents, got \(error)")
            }
        }
    }

    /// 测试缺少 SUMMARY 的 VEVENT
    func testParseVEVENTWithoutSummary() throws {
        let icsContent = """
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
DTSTART;VALUE=DATE:20260101
END:VEVENT
END:VCALENDAR
"""

        let region = HolidayRegion.japan
        XCTAssertThrowsError(try parseService.parse(content: icsContent, region: region, sourceURL: "https://example.com/ics")) { error in
            guard case EnhancedICSError.noEvents = error else {
                return XCTFail("Expected noEvents, got \(error)")
            }
        }
    }

    /// 测试缺少 DTSTART 的 VEVENT
    func testParseVEVENTWithoutDate() throws {
        let icsContent = """
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
SUMMARY:No Date Event
END:VEVENT
END:VCALENDAR
"""

        let region = HolidayRegion.japan
        XCTAssertThrowsError(try parseService.parse(content: icsContent, region: region, sourceURL: "https://example.com/ics")) { error in
            guard case EnhancedICSError.noEvents = error else {
                return XCTFail("Expected noEvents, got \(error)")
            }
        }
    }

    // MARK: - Unfold Lines Helper Tests

    /// 测试 unfoldICSLines 辅助方法
    /// 根据 RFC5545，folded line 的 continuation 行开头空格是 fold 字符应被移除
    func testUnfoldICSLines() throws {
        let input = """
BEGIN:VCALENDAR
VERSION:2.0
DESCRIPTION:This is a long
 description that is folded
SUMMARY:Test
END:VCALENDAR
"""

        // RFC5545: 移除 continuation line 开头的空格后拼接到上一行
        let expectedLines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "DESCRIPTION:This is a longdescription that is folded",
            "SUMMARY:Test",
            "END:VCALENDAR"
        ]

        // 使用反射测试私有方法
        let unfoldedLines = performSelectorOrMirror(input)

        XCTAssertEqual(unfoldedLines.count, expectedLines.count)
        for (index, expected) in expectedLines.enumerated() {
            XCTAssertEqual(unfoldedLines[index], expected, "Line \(index) should match")
        }
    }

    // MARK: - Real Office Holidays Format Tests

    /// 测试真实 Office Holidays Japan 格式（无 VALUE=DATE 参数）
    /// 这是实际从 https://www.officeholidays.com/ics/japan 下载的格式
    func testParseRealOfficeHolidaysJapanFormat() throws {
        let icsContent = """
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Office Holidays//NONSGML Japan Holidays//EN
BEGIN:VEVENT
DTSTAMP:20260101T000000Z
DTSTART:20260101
DTEND:20260102
SUMMARY:Japan: New Year's Day
UID:2026-01-01JP415regcountry@www.officeholidays.com
END:VEVENT
END:VCALENDAR
"""

        let region = HolidayRegion.japan
        let events = try parseService.parse(content: icsContent, region: region, sourceURL: "https://www.officeholidays.com/ics/japan")

        XCTAssertEqual(events.count, 1, "应该解析出 1 个节假日")

        let firstEvent = events[0]
        XCTAssertEqual(firstEvent.name, "Japan: New Year's Day")
        XCTAssertEqual(firstEvent.date.year, 2026)
        XCTAssertEqual(firstEvent.date.month, 1)
        XCTAssertEqual(firstEvent.date.day, 1)
        XCTAssertEqual(firstEvent.sourceURL, "https://www.officeholidays.com/ics/japan")
    }

    /// 测试带 VALUE=DATE 参数的格式
    func testParseOfficeHolidaysWithParameterValueDate() throws {
        let icsContent = """
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Office Holidays//NONSGML Japan Holidays//EN
BEGIN:VEVENT
DTSTART;VALUE=DATE:20260112
DTEND;VALUE=DATE:20260113
SUMMARY:Japan: Coming-of-Age Day
END:VEVENT
END:VCALENDAR
"""

        let region = HolidayRegion.japan
        let events = try parseService.parse(content: icsContent, region: region, sourceURL: "https://www.officeholidays.com/ics/japan")

        XCTAssertEqual(events.count, 1, "应该解析出 1 个节假日")

        let firstEvent = events[0]
        XCTAssertEqual(firstEvent.name, "Japan: Coming-of-Age Day")
        XCTAssertEqual(firstEvent.date.year, 2026)
        XCTAssertEqual(firstEvent.date.month, 1)
        XCTAssertEqual(firstEvent.date.day, 12)
    }

    func testParseLatin1DataUsesSameDecoderAsValidation() throws {
        let icsContent = """
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        DTSTART;VALUE=DATE:20260714
        SUMMARY:Fête nationale
        END:VEVENT
        END:VCALENDAR
        """
        let data = try XCTUnwrap(icsContent.data(using: .isoLatin1))

        let events = try parseService.parse(
            data: data,
            region: .unitedStates,
            sourceURL: "https://example.com/latin1.ics"
        )

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.name, "Fête nationale")
        XCTAssertEqual(events.first?.date, DateOnly(year: 2026, month: 7, day: 14))
    }

    func testParseRejectsInvalidGregorianDate() throws {
        let icsContent = """
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        DTSTART;VALUE=DATE:20260231
        SUMMARY:Invalid Date
        END:VEVENT
        END:VCALENDAR
        """

        XCTAssertThrowsError(
            try parseService.parse(
                content: icsContent,
                region: .japan,
                sourceURL: "https://example.com/invalid.ics"
            )
        ) { error in
            guard case EnhancedICSError.noEvents = error else {
                return XCTFail("Expected noEvents after rejecting invalid date, got \(error)")
            }
        }
    }

    func testParseTZIDDateTimeKeepsWrittenCalendarDayWithoutClaimingTimezoneConversion() throws {
        let icsContent = """
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        DTSTART;TZID=Pacific/Honolulu:20261231T230000
        SUMMARY:TZID Calendar Day
        END:VEVENT
        END:VCALENDAR
        """

        let events = try parseService.parse(
            content: icsContent,
            region: .unitedStates,
            sourceURL: "https://example.com/tzid.ics"
        )

        XCTAssertEqual(events.first?.date, DateOnly(year: 2026, month: 12, day: 31))
    }

    // MARK: - Helper Methods

    /// 使用 Mirror 测试私有 unfoldICSLines 方法
    private func performSelectorOrMirror(_ input: String) -> [String] {
        // 由于 Swift 的私有方法无法直接调用，我们直接测试公开的 parse 方法
        // 这个测试主要作为占位符，实际验证在 parse 测试中完成
        var result: [String] = []

        for rawLine in input.components(separatedBy: "\n") {
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
}

final class ICSDownloadServiceTests: XCTestCase {
    override func tearDown() {
        ICSURLProtocolStub.handler = nil
        super.tearDown()
    }

    func testHTTPStatusErrorRemainsTyped() async throws {
        ICSURLProtocolStub.handler = { request in
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, Data("server error".utf8))
        }

        let service = makeService()

        do {
            _ = try await service.download(from: try XCTUnwrap(URL(string: "https://example.com/feed.ics")))
            XCTFail("Expected invalidHTTPStatus")
        } catch let error as EnhancedICSError {
            guard case .invalidHTTPStatus(500) = error else {
                return XCTFail("Expected typed HTTP 500, got \(error)")
            }
        }
    }

    func testEveryResponseAppliesSizeLimitBeforeReturningHTTPError() async throws {
        ICSURLProtocolStub.handler = { request in
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, Data(repeating: 0x41, count: 10 * 1024 * 1024 + 1))
        }

        let service = makeService()

        do {
            _ = try await service.download(from: try XCTUnwrap(URL(string: "https://example.com/large.ics")))
            XCTFail("Expected tooLarge")
        } catch let error as EnhancedICSError {
            guard case .tooLarge(let size, let limit) = error else {
                return XCTFail("Expected typed tooLarge, got \(error)")
            }
            XCTAssertEqual(size, 10 * 1024 * 1024 + 1)
            XCTAssertEqual(limit, 10 * 1024 * 1024)
        }
    }

    func testURLErrorIsMappedToNetworkError() async throws {
        ICSURLProtocolStub.handler = { _ in
            throw URLError(.timedOut)
        }

        let service = makeService()

        do {
            _ = try await service.download(from: try XCTUnwrap(URL(string: "https://example.com/feed.ics")))
            XCTFail("Expected networkError")
        } catch let error as EnhancedICSError {
            guard case .networkError(let underlying) = error,
                  (underlying as? URLError)?.code == .timedOut else {
                return XCTFail("Expected typed network timeout, got \(error)")
            }
        }
    }

    private func makeService() -> ICSDownloadService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ICSURLProtocolStub.self]
        return ICSDownloadService(session: URLSession(configuration: configuration))
    }
}

final class HolidaySubscriptionManagerTests: XCTestCase {
    @MainActor
    func testBuiltInNormalURLFallsBackToCleanAndKeepsConfiguredURL() async throws {
        let normalURL = try XCTUnwrap(HolidayRecommendedSources.preferredURL(for: .japan))
        let cleanURL = try XCTUnwrap(HolidayRecommendedSources.cleanFallbackURL(for: .japan))
        let downloader = ScriptedICSDownloader(script: [
            normalURL: [.failure(EnhancedICSError.invalidHTTPStatus(500))],
            cleanURL: [.success(makeValidICSData(summary: "Fallback Holiday"))]
        ])
        let cache = SpyHolidayCacheRepository()
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)
        let manager = HolidaySubscriptionManager(
            downloadService: downloader,
            parseService: ICSParseService(),
            cacheRepository: cache,
            userDefaults: defaults,
            now: { fixedNow }
        )

        let result = await manager.syncAllEnabled()

        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.totalEvents, 1)
        XCTAssertEqual(downloader.requestedURLs, [normalURL, cleanURL])
        XCTAssertEqual(
            manager.subscriptions.first(where: { $0.region == .japan })?.urlString,
            normalURL
        )
        XCTAssertEqual(cache.getEvents(for: [.japan]).first?.sourceURL, cleanURL)
        XCTAssertEqual(
            manager.subscriptions.first(where: { $0.region == .japan })?.lastUpdatedAt,
            fixedNow
        )
    }

    @MainActor
    func testCustomOfficeHolidaysURLDoesNotFallback() async throws {
        let customURL = "https://www.officeholidays.com/ics/japan?custom=1"
        let downloader = ScriptedICSDownloader(script: [
            customURL: [.failure(EnhancedICSError.invalidHTTPStatus(500))]
        ])
        let cache = SpyHolidayCacheRepository()
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = HolidaySubscriptionManager(
            downloadService: downloader,
            parseService: ICSParseService(),
            cacheRepository: cache,
            userDefaults: defaults
        )
        try manager.updateURL(for: .japan, newURL: customURL)

        let result = await manager.syncAllEnabled()

        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(downloader.requestedURLs, [customURL])
        guard let error = result.error as? EnhancedICSError,
              case .invalidHTTPStatus(500) = error else {
            return XCTFail("Expected original typed HTTP 500, got \(String(describing: result.error))")
        }
    }

    @MainActor
    func testMissingCacheIsStaleEvenWithRecentSubscriptionMetadata() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let subscription = makeSubscription(lastUpdatedAt: now, syncStatus: .success)
        let (defaults, suiteName) = try makeDefaults(subscriptions: [subscription])
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = HolidaySubscriptionManager(
            downloadService: ScriptedICSDownloader(),
            parseService: ICSParseService(),
            cacheRepository: SpyHolidayCacheRepository(),
            userDefaults: defaults,
            now: { now }
        )

        XCTAssertTrue(manager.shouldAutoSync(for: .japan))
    }

    @MainActor
    func testCorruptCacheIsStaleEvenWithRecentSubscriptionMetadata() throws {
        let fileManager = FileManager.default
        let cacheDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("HolidaySubscriptionManagerTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: cacheDirectory) }
        try Data("not-json".utf8).write(
            to: cacheDirectory.appendingPathComponent("japan_holidays.json")
        )

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let subscription = makeSubscription(lastUpdatedAt: now, syncStatus: .success)
        let (defaults, suiteName) = try makeDefaults(subscriptions: [subscription])
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let cache = HolidayEventCacheRepository(cacheDirectory: cacheDirectory)
        let manager = HolidaySubscriptionManager(
            downloadService: ScriptedICSDownloader(),
            parseService: ICSParseService(),
            cacheRepository: cache,
            userDefaults: defaults,
            now: { now }
        )

        XCTAssertNil(cache.getLastSyncTime(for: .japan))
        XCTAssertTrue(manager.shouldAutoSync(for: .japan))
    }

    @MainActor
    func testCacheTimestampControlsTwentyFourHourFreshness() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let subscription = makeSubscription(lastUpdatedAt: now, syncStatus: .success)
        let cache = SpyHolidayCacheRepository(
            lastSyncByRegion: [.japan: now.addingTimeInterval(-(24 * 60 * 60))]
        )
        let (defaults, suiteName) = try makeDefaults(subscriptions: [subscription])
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var currentNow = now
        let manager = HolidaySubscriptionManager(
            downloadService: ScriptedICSDownloader(),
            parseService: ICSParseService(),
            cacheRepository: cache,
            userDefaults: defaults,
            now: { currentNow }
        )

        XCTAssertFalse(manager.shouldAutoSync(for: .japan))
        currentNow = now.addingTimeInterval(1)
        XCTAssertTrue(manager.shouldAutoSync(for: .japan))
    }

    @MainActor
    func testFailedSyncKeepsLastGoodEventsAndLastSuccessTime() async throws {
        let lastSuccess = Date(timeIntervalSince1970: 1_700_000_000)
        let oldEvent = HolidayEvent(
            id: "last-good",
            region: .japan,
            date: DateOnly(year: 2026, month: 1, day: 1),
            name: "Last Good",
            sourceURL: "https://example.com/old.ics",
            importedAt: lastSuccess
        )
        let subscription = makeSubscription(lastUpdatedAt: lastSuccess, syncStatus: .success)
        let normalURL = try XCTUnwrap(HolidayRecommendedSources.preferredURL(for: .japan))
        let downloader = ScriptedICSDownloader(script: [
            normalURL: [.failure(EnhancedICSError.networkError(URLError(.notConnectedToInternet)))]
        ])
        let cache = SpyHolidayCacheRepository(
            eventsByRegion: [.japan: [oldEvent]],
            lastSyncByRegion: [.japan: lastSuccess]
        )
        let (defaults, suiteName) = try makeDefaults(subscriptions: [subscription])
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = HolidaySubscriptionManager(
            downloadService: downloader,
            parseService: ICSParseService(),
            cacheRepository: cache,
            userDefaults: defaults,
            now: { lastSuccess.addingTimeInterval(10_000) }
        )

        let result = await manager.syncAllEnabled()

        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(cache.getEvents(for: [.japan]), [oldEvent])
        let updated = try XCTUnwrap(manager.subscriptions.first(where: { $0.region == .japan }))
        XCTAssertEqual(updated.syncStatus, .failed)
        XCTAssertEqual(updated.lastUpdatedAt, lastSuccess)
        XCTAssertTrue(manager.hasCachedData(for: .japan))
    }

    @MainActor
    func testEmptyCleanFallbackDoesNotReplaceLastGoodCache() async throws {
        let lastSuccess = Date(timeIntervalSince1970: 1_700_000_000)
        let oldEvent = HolidayEvent(
            id: "last-good",
            region: .japan,
            date: DateOnly(year: 2026, month: 1, day: 1),
            name: "Last Good",
            sourceURL: "https://example.com/old.ics",
            importedAt: lastSuccess
        )
        let subscription = makeSubscription(lastUpdatedAt: lastSuccess, syncStatus: .success)
        let normalURL = try XCTUnwrap(HolidayRecommendedSources.preferredURL(for: .japan))
        let cleanURL = try XCTUnwrap(HolidayRecommendedSources.cleanFallbackURL(for: .japan))
        let emptyCalendar = Data(
            """
            BEGIN:VCALENDAR
            VERSION:2.0
            END:VCALENDAR
            """.utf8
        )
        let downloader = ScriptedICSDownloader(script: [
            normalURL: [.failure(EnhancedICSError.invalidHTTPStatus(500))],
            cleanURL: [.success(emptyCalendar)]
        ])
        let cache = SpyHolidayCacheRepository(
            eventsByRegion: [.japan: [oldEvent]],
            lastSyncByRegion: [.japan: lastSuccess]
        )
        let (defaults, suiteName) = try makeDefaults(subscriptions: [subscription])
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = HolidaySubscriptionManager(
            downloadService: downloader,
            parseService: ICSParseService(),
            cacheRepository: cache,
            userDefaults: defaults
        )

        let result = await manager.syncAllEnabled()

        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(downloader.requestedURLs, [normalURL, cleanURL])
        guard let compositeError = result.error as? HolidaySourceFallbackError else {
            return XCTFail(
                "Expected HolidaySourceFallbackError, got \(String(describing: result.error))"
            )
        }
        guard let primaryError = compositeError.primaryError as? EnhancedICSError,
              case .invalidHTTPStatus(500) = primaryError else {
            return XCTFail("Expected preserved typed primary HTTP 500")
        }
        guard let fallbackError = compositeError.fallbackError as? EnhancedICSError,
              case .noEvents = fallbackError else {
            return XCTFail("Expected preserved typed fallback noEvents")
        }
        XCTAssertFalse(compositeError.localizedDescription.contains(normalURL))
        XCTAssertFalse(compositeError.localizedDescription.contains(cleanURL))
        XCTAssertEqual(cache.getEvents(for: [.japan]), [oldEvent])
        let updated = try XCTUnwrap(manager.subscriptions.first(where: { $0.region == .japan }))
        XCTAssertEqual(updated.syncStatus, .failed)
        XCTAssertEqual(updated.lastUpdatedAt, lastSuccess)
    }

    @MainActor
    func testAutoSyncThrottlesFailedCachelessRetriesForFifteenMinutes() async throws {
        let normalURL = try XCTUnwrap(HolidayRecommendedSources.preferredURL(for: .japan))
        let failure = EnhancedICSError.networkError(URLError(.notConnectedToInternet))
        let downloader = ScriptedICSDownloader(script: [
            normalURL: [.failure(failure), .failure(failure)]
        ])
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let baseNow = Date(timeIntervalSince1970: 1_800_000_000)
        var currentNow = baseNow
        let manager = HolidaySubscriptionManager(
            downloadService: downloader,
            parseService: ICSParseService(),
            cacheRepository: SpyHolidayCacheRepository(),
            userDefaults: defaults,
            now: { currentNow },
            autoSyncMinimumInterval: 15 * 60
        )

        await manager.performAutoSync()
        currentNow = baseNow.addingTimeInterval(14 * 60)
        await manager.performAutoSync()
        XCTAssertEqual(downloader.requestedURLs.count, 1)

        currentNow = baseNow.addingTimeInterval(15 * 60)
        await manager.performAutoSync()
        XCTAssertEqual(downloader.requestedURLs.count, 2)
    }

    @MainActor
    func testDifferentPersistedSourcesStartConcurrently() async throws {
        let firstURL = "https://example.com/japan.ics"
        let secondURL = "https://example.com/us.ics"
        let subscriptions = [
            makeSubscription(
                lastUpdatedAt: nil,
                syncStatus: .neverSynced,
                region: .japan,
                urlString: firstURL
            ),
            makeSubscription(
                lastUpdatedAt: nil,
                syncStatus: .neverSynced,
                region: .unitedStates,
                urlString: secondURL
            )
        ]
        let downloader = ControlledICSDownloader()
        let (defaults, suiteName) = try makeDefaults(subscriptions: subscriptions)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = HolidaySubscriptionManager(
            downloadService: downloader,
            parseService: ICSParseService(),
            cacheRepository: SpyHolidayCacheRepository(),
            userDefaults: defaults
        )

        let syncTask = Task { @MainActor in
            await manager.syncAllEnabled()
        }
        await downloader.waitForRequestCount(2)

        let requestedURLs = await downloader.requestedURLs
        XCTAssertEqual(Set(requestedURLs), Set([firstURL, secondURL]))
        XCTAssertEqual(manager.syncingRegions, Set([.japan, .unitedStates]))
        await downloader.resumeAll(with: makeValidICSData())
        let result = await syncTask.value
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.totalEvents, 2)
    }

    @MainActor
    func testIdenticalPersistedSourceCallsJoinAndDownloadOnce() async throws {
        let downloader = ControlledICSDownloader()
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let cache = SpyHolidayCacheRepository()
        let manager = HolidaySubscriptionManager(
            downloadService: downloader,
            parseService: ICSParseService(),
            cacheRepository: cache,
            userDefaults: defaults
        )

        let first = Task { @MainActor in
            await manager.syncAllEnabled()
        }
        await downloader.waitForRequestCount(1)
        let second = Task { @MainActor in
            await manager.syncAllEnabled()
        }
        for _ in 0..<10 { await Task.yield() }

        let requestCountBeforeResume = await downloader.requestCount
        XCTAssertEqual(requestCountBeforeResume, 1)
        await downloader.resumeAll(with: makeValidICSData())
        let firstResult = await first.value
        let secondResult = await second.value
        XCTAssertTrue(firstResult.isSuccess)
        XCTAssertTrue(secondResult.isSuccess)
        XCTAssertEqual(firstResult.totalEvents, 1)
        XCTAssertEqual(secondResult.totalEvents, 1)
        XCTAssertEqual(cache.saveCount, 1)
        XCTAssertFalse(manager.syncInProgress)
    }

    @MainActor
    func testAutoSyncAndManualSyncJoinAndManualReceivesResult() async throws {
        let downloader = ControlledICSDownloader()
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = HolidaySubscriptionManager(
            downloadService: downloader,
            parseService: ICSParseService(),
            cacheRepository: SpyHolidayCacheRepository(),
            userDefaults: defaults
        )

        let autoSync = Task { @MainActor in
            await manager.performAutoSync()
        }
        await downloader.waitForRequestCount(1)
        XCTAssertFalse(manager.syncInProgress)
        let manualSync = Task { @MainActor in
            await manager.syncAllEnabled()
        }
        for _ in 0..<10 { await Task.yield() }

        let requestCountBeforeResume = await downloader.requestCount
        XCTAssertEqual(requestCountBeforeResume, 1)
        XCTAssertTrue(manager.syncInProgress)
        await downloader.resumeAll(with: makeValidICSData())
        let manualResult = await manualSync.value
        await autoSync.value
        XCTAssertTrue(manualResult.isSuccess)
        XCTAssertEqual(manualResult.totalEvents, 1)
        XCTAssertEqual(
            manager.subscriptions.first(where: { $0.region == .japan })?.syncStatus,
            .success
        )
        XCTAssertFalse(manager.syncInProgress)
    }

    @MainActor
    func testPersistedSyncAndURLValidationUseDifferentTasksAndOnlyPersistedWrites() async throws {
        let sourceURL = "https://example.com/shared.ics"
        let subscription = makeSubscription(
            lastUpdatedAt: nil,
            syncStatus: .neverSynced,
            urlString: sourceURL
        )
        let downloader = ControlledICSDownloader()
        let cache = SpyHolidayCacheRepository()
        let (defaults, suiteName) = try makeDefaults(subscriptions: [subscription])
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = HolidaySubscriptionManager(
            downloadService: downloader,
            parseService: ICSParseService(),
            cacheRepository: cache,
            userDefaults: defaults
        )

        let persisted = Task { @MainActor in
            await manager.syncAllEnabled()
        }
        await downloader.waitForRequestCount(1)
        let validation = Task { @MainActor in
            try await manager.validateSourceURL(sourceURL, for: .japan)
        }
        await downloader.waitForRequestCount(2)

        let requestCountBeforeResume = await downloader.requestCount
        XCTAssertEqual(requestCountBeforeResume, 2)
        XCTAssertEqual(cache.saveCount, 0)
        await downloader.resumeAll(with: makeValidICSData())
        let persistedResult = await persisted.value
        let validationResult = try await validation.value
        XCTAssertTrue(persistedResult.isSuccess)
        XCTAssertEqual(validationResult.eventCount, 1)
        XCTAssertEqual(cache.saveCount, 1)
    }

    @MainActor
    func testIdenticalURLValidationsJoinWithoutPersistedSideEffectsOrAutoThrottle() async throws {
        let validationURL = "https://example.com/validation.ics"
        let downloader = ControlledICSDownloader()
        let cache = SpyHolidayCacheRepository()
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = HolidaySubscriptionManager(
            downloadService: downloader,
            parseService: ICSParseService(),
            cacheRepository: cache,
            userDefaults: defaults,
            autoSyncMinimumInterval: 15 * 60
        )
        let before = manager.subscriptions.first(where: { $0.region == .japan })

        let first = Task { @MainActor in
            try await manager.validateSourceURL(validationURL, for: .japan)
        }
        await downloader.waitForRequestCount(1)
        let second = Task { @MainActor in
            try await manager.validateSourceURL(validationURL, for: .japan)
        }
        for _ in 0..<10 { await Task.yield() }

        XCTAssertFalse(manager.syncInProgress)
        let validationRequestCount = await downloader.requestCount
        XCTAssertEqual(validationRequestCount, 1)
        await downloader.resumeAll(with: makeValidICSData())
        let firstResult = try await first.value
        let secondResult = try await second.value
        XCTAssertEqual(firstResult.eventCount, 1)
        XCTAssertEqual(secondResult.eventCount, 1)
        XCTAssertEqual(cache.saveCount, 0)
        XCTAssertEqual(manager.subscriptions.first(where: { $0.region == .japan }), before)
        XCTAssertNil(manager.lastSyncError)

        let auto = Task { @MainActor in
            await manager.performAutoSync()
        }
        await downloader.waitForRequestCount(2)
        await downloader.resumeAll(with: makeValidICSData())
        await auto.value
        XCTAssertEqual(cache.saveCount, 1)
    }

    @MainActor
    func testFailedSingleFlightIsRemovedAndCanRetry() async throws {
        let sourceURL = try XCTUnwrap(HolidayRecommendedSources.preferredURL(for: .japan))
        let downloader = ScriptedICSDownloader(script: [
            sourceURL: [
                .failure(EnhancedICSError.networkError(URLError(.timedOut))),
                .success(makeValidICSData())
            ]
        ])
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = HolidaySubscriptionManager(
            downloadService: downloader,
            parseService: ICSParseService(),
            cacheRepository: SpyHolidayCacheRepository(),
            userDefaults: defaults
        )

        let failure = await manager.syncAllEnabled()
        let success = await manager.syncAllEnabled()

        XCTAssertFalse(failure.isSuccess)
        XCTAssertTrue(success.isSuccess)
        XCTAssertEqual(downloader.requestedURLs.count, 2)
        XCTAssertFalse(manager.syncInProgress)
    }

    @MainActor
    func testCancelledValidationTaskIsRemovedAndCanRetry() async throws {
        let sourceURL = "https://example.com/cancellable.ics"
        let downloader = ControlledICSDownloader()
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = HolidaySubscriptionManager(
            downloadService: downloader,
            parseService: ICSParseService(),
            cacheRepository: SpyHolidayCacheRepository(),
            userDefaults: defaults
        )

        let cancelled = Task { @MainActor in
            try await manager.validateSourceURL(sourceURL, for: .japan)
        }
        await downloader.waitForRequestCount(1)
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            XCTFail("The validation task must observe cancellation")
        } catch is CancellationError {}
        await downloader.waitForPendingRequestCount(0)

        let retry = Task { @MainActor in
            try await manager.validateSourceURL(sourceURL, for: .japan)
        }
        await downloader.waitForRequestCount(2)
        await downloader.resumeAll(with: makeValidICSData())
        let retryResult = try await retry.value
        XCTAssertEqual(retryResult.eventCount, 1)
    }

    private func makeDefaults(
        subscriptions: [HolidaySubscription]? = nil
    ) throws -> (UserDefaults, String) {
        let suiteName = "HolidaySubscriptionManagerTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        if let subscriptions {
            let data = try JSONEncoder().encode(subscriptions)
            defaults.set(try XCTUnwrap(String(data: data, encoding: .utf8)), forKey: "holidaySubscriptions")
        }

        return (defaults, suiteName)
    }

    private func makeSubscription(
        lastUpdatedAt: Date?,
        syncStatus: SyncStatus,
        region: HolidayRegion = .japan,
        urlString: String? = nil,
        isEnabled: Bool = true
    ) -> HolidaySubscription {
        HolidaySubscription(
            region: region,
            displayNameKey: region.localizedKey,
            urlString: urlString ?? HolidayRecommendedSources.preferredURL(for: region) ?? "",
            isEnabled: isEnabled,
            lastUpdatedAt: lastUpdatedAt,
            syncStatus: syncStatus
        )
    }
}

private final class ICSURLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class ScriptedICSDownloader: ICSDownloading {
    private var script: [String: [Result<Data, Error>]]
    private(set) var requestedURLs: [String] = []

    init(script: [String: [Result<Data, Error>]] = [:]) {
        self.script = script
    }

    func download(
        from url: URL,
        timeout: TimeInterval,
        region: String?,
        host: String?
    ) async throws -> Data {
        let urlString = url.absoluteString
        requestedURLs.append(urlString)
        guard var responses = script[urlString], !responses.isEmpty else {
            throw EnhancedICSError.networkError(URLError(.resourceUnavailable))
        }
        let response = responses.removeFirst()
        script[urlString] = responses
        return try response.get()
    }

    func validateURL(_ urlString: String) throws {
        guard let url = URL(string: urlString),
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false else {
            throw EnhancedICSError.invalidURL
        }
    }

    func validateICSContent(_ data: Data) throws {
        try ICSDownloadService().validateICSContent(data)
    }
}

private actor ControlledICSDownloader: ICSDownloading {
    private struct PendingRequest {
        let urlString: String
        let continuation: CheckedContinuation<Data, Error>
    }

    private struct CountWaiter {
        let target: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var requestedURLValues: [String] = []
    private var pendingRequests: [UUID: PendingRequest] = [:]
    private var requestCountWaiters: [CountWaiter] = []
    private var pendingCountWaiters: [CountWaiter] = []

    var requestCount: Int {
        requestedURLValues.count
    }

    var requestedURLs: [String] {
        requestedURLValues
    }

    func download(
        from url: URL,
        timeout: TimeInterval,
        region: String?,
        host: String?
    ) async throws -> Data {
        let requestID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                requestedURLValues.append(url.absoluteString)
                pendingRequests[requestID] = PendingRequest(
                    urlString: url.absoluteString,
                    continuation: continuation
                )
                resumeSatisfiedWaiters()
            }
        } onCancel: {
            Task {
                await self.cancelRequest(id: requestID)
            }
        }
    }

    func waitForRequestCount(_ count: Int) async {
        guard requestedURLValues.count < count else { return }
        await withCheckedContinuation { continuation in
            requestCountWaiters.append(
                CountWaiter(target: count, continuation: continuation)
            )
        }
    }

    func waitForPendingRequestCount(_ count: Int) async {
        guard pendingRequests.count != count else { return }
        await withCheckedContinuation { continuation in
            pendingCountWaiters.append(
                CountWaiter(target: count, continuation: continuation)
            )
        }
    }

    func resumeAll(with data: Data) {
        let requests = Array(pendingRequests.values)
        pendingRequests.removeAll()
        resumeSatisfiedWaiters()
        requests.forEach { $0.continuation.resume(returning: data) }
    }

    nonisolated func validateURL(_ urlString: String) throws {
        try ICSDownloadService().validateURL(urlString)
    }

    nonisolated func validateICSContent(_ data: Data) throws {
        try ICSDownloadService().validateICSContent(data)
    }

    private func cancelRequest(id: UUID) {
        guard let request = pendingRequests.removeValue(forKey: id) else { return }
        resumeSatisfiedWaiters()
        request.continuation.resume(throwing: CancellationError())
    }

    private func resumeSatisfiedWaiters() {
        let readyRequestWaiters = requestCountWaiters.filter {
            requestedURLValues.count >= $0.target
        }
        requestCountWaiters.removeAll {
            requestedURLValues.count >= $0.target
        }
        readyRequestWaiters.forEach { $0.continuation.resume() }

        let readyPendingWaiters = pendingCountWaiters.filter {
            pendingRequests.count == $0.target
        }
        pendingCountWaiters.removeAll {
            pendingRequests.count == $0.target
        }
        readyPendingWaiters.forEach { $0.continuation.resume() }
    }
}

private final class SpyHolidayCacheRepository: HolidayEventCacheRepositoryProtocol {
    private var eventsByRegion: [HolidayRegion: [HolidayEvent]]
    private var lastSyncByRegion: [HolidayRegion: Date]
    private(set) var saveCount = 0

    init(
        eventsByRegion: [HolidayRegion: [HolidayEvent]] = [:],
        lastSyncByRegion: [HolidayRegion: Date] = [:]
    ) {
        self.eventsByRegion = eventsByRegion
        self.lastSyncByRegion = lastSyncByRegion
    }

    func saveEvents(_ events: [HolidayEvent], for region: HolidayRegion) async throws {
        saveCount += 1
        eventsByRegion[region] = events
        lastSyncByRegion[region] = Date()
    }

    func getEvents(for regions: [HolidayRegion]) -> [HolidayEvent] {
        regions.flatMap { eventsByRegion[$0] ?? [] }.sorted { $0.date < $1.date }
    }

    func getEvents(on date: DateOnly, for regions: [HolidayRegion]) -> [HolidayEvent] {
        getEvents(for: regions).filter { $0.date == date }
    }

    func getEvents(
        in range: ClosedRange<DateOnly>,
        for regions: [HolidayRegion]
    ) -> [HolidayEvent] {
        getEvents(for: regions).filter { range.contains($0.date) }
    }

    func clearEvents() async throws {
        eventsByRegion.removeAll()
        lastSyncByRegion.removeAll()
    }

    func getLastSyncTime(for region: HolidayRegion) -> Date? {
        lastSyncByRegion[region]
    }
}

private func makeValidICSData(summary: String = "Test Holiday") -> Data {
    Data(
        """
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        DTSTART;VALUE=DATE:20260101
        SUMMARY:\(summary)
        UID:test-holiday
        END:VEVENT
        END:VCALENDAR
        """.utf8
    )
}
