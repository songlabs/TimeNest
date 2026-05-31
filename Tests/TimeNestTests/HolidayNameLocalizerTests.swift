import XCTest
@testable import TimeNest

final class HolidayNameLocalizerTests: XCTestCase {

    private var localizer: HolidayNameLocalizer!

    override func setUp() {
        super.setUp()
        localizer = HolidayNameLocalizer()
    }

    // MARK: - 访问所有语言/地区映射表不崩溃测试

    func testAccessAllRegionMappingsDoesNotCrash() {
        // 测试访问所有地区的 localizedMappings 不崩溃
        let regions: [HolidayRegion] = [.japan, .china, .korea, .unitedStates]
        
        for region in regions {
            // 这个访问应该不崩溃
            let _ = localizer.localizedDisplayName(for: "test", in: region)
        }
    }

    // MARK: - 中国节假日 alias 测试

    func testSpringFestivalAlias() {
        // Spring Festival Holiday 2 -> 春节
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Spring Festival Holiday 2", in: .china),
            "春节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "spring festival holiday 2", in: .china),
            "春节"
        )
    }

    func testChingMingFestivalAlias() {
        // Ching Ming Festival -> 清明节
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Ching Ming Festival", in: .china),
            "清明节"
        )
    }

    func testQingmingFestivalAlias() {
        // Qingming Festival -> 清明节
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Qingming Festival", in: .china),
            "清明节"
        )
    }

    func testTombSweepingDayAlias() {
        // Tomb Sweeping Day -> 清明节
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Tomb Sweeping Day", in: .china),
            "清明节"
        )
    }

    func testTombSweepingDayVariantAlias() {
        // Tomb-Sweeping Day -> 清明节
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Tomb-Sweeping Day", in: .china),
            "清明节"
        )
    }

    func testLabourDayAlias() {
        // Labour Day Holiday 2 -> 劳动节
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Labour Day Holiday 2", in: .china),
            "劳动节"
        )
    }

    func testNationalDayAlias() {
        // National Day Holiday 3 -> 国庆节
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "National Day Holiday 3", in: .china),
            "国庆节"
        )
    }

    // MARK: - 未知名称 fallback 测试

    func testUnknownNameFallbacksToOriginal() {
        // 未知名称应该返回清理前缀后的原始名称
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Unknown Holiday", in: .china),
            "Unknown Holiday"
        )
    }

    func testUnknownNameWithPrefixFallbacks() {
        // 带前缀的未知名称应该返回清理前缀后的名称
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "China: Unknown Holiday", in: .china),
            "Unknown Holiday"
        )
    }

    // MARK: - 日本节假日测试

    func testJapanGreeneryDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Greenery Day", in: .japan),
            "みどりの日"
        )
    }

    func testJapanGreeneryDayInLieu() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Greenery Day (in lieu)", in: .japan),
            "みどりの日 振替休日"
        )
    }

    // MARK: - 韩国节假日测试

    func testKoreaChildrensDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Children's Day", in: .korea),
            "어린이날"
        )
    }

    func testKoreaBuddhasBirthday() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Buddha's Birthday", in: .korea),
            "부처님 오신 날"
        )
    }

    // MARK: - 美国节假日测试

    func testUSANewYearsDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "New Year's Day", in: .unitedStates),
            "New Year's Day"
        )
    }

    func testUSALaborDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Labor Day", in: .unitedStates),
            "Labor Day"
        )
    }

    // MARK: - 地区前缀清理测试

    func testCleanChinaPrefix() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "China: Spring Festival", in: .china),
            "春节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "中国：劳动节", in: .china),
            "劳动节"
        )
    }

    func testCleanJapanPrefix() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Japan: Greenery Day", in: .japan),
            "みどりの日"
        )
    }

    func testCleanKoreaPrefix() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Korea: Children's Day", in: .korea),
            "어린이날"
        )
    }

    func testCleanUSAPrefix() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "US: Labor Day", in: .unitedStates),
            "Labor Day"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "USA: Labor Day", in: .unitedStates),
            "Labor Day"
        )
    }

    // MARK: - 数字变体测试

    func testLabourDayHolidayVariants() {
        // 验证各种数字变体都能正确映射到劳动节
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Labour Day Holiday 1", in: .china),
            "劳动节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Labour Day Holiday 2", in: .china),
            "劳动节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Labour Day Holiday 3", in: .china),
            "劳动节"
        )
    }

    func testNationalDayHolidayVariants() {
        // 验证各种数字变体都能正确映射到国庆节
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "National Day Holiday 1", in: .china),
            "国庆节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "National Day Holiday 2", in: .china),
            "国庆节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "National Day Holiday 3", in: .china),
            "国庆节"
        )
    }

    // MARK: - 特殊字符处理测试

    func testApostropheHandling() {
        // 验证 apostrophe 被正确移除后仍能匹配
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "New Year's Day", in: .china),
            "元旦"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "International Workers' Day", in: .china),
            "劳动节"
        )
    }

    // MARK: - 其他中国节假日测试

    func testDragonBoatFestival() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Dragon Boat Festival", in: .china),
            "端午节"
        )
    }

    func testMidAutumnFestival() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Mid-Autumn Festival", in: .china),
            "中秋节"
        )
    }

    func testLanternFestival() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Lantern Festival", in: .china),
            "元宵节"
        )
    }

    func testYouthDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Youth Day", in: .china),
            "青年节"
        )
    }

    // MARK: - 重复 alias 测试

    /// 测试重复 alias 映射到同一个值时不崩溃（如 "International Workers' Day" -> "international workers day"）
    func testDuplicateAliasSameValueDoesNotCrash() {
        // "International Workers' Day" 规范化后变成 "internationalworkersday"
        // 如果 alias 中有重复，应该静默处理，不崩溃
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "International Workers' Day", in: .china),
            "劳动节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "international workers day", in: .china),
            "劳动节"
        )
    }

    /// 测试 Workers' Day 也能正确映射
    func testWorkersDayAlias() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Workers' Day", in: .china),
            "劳动节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "workers day", in: .china),
            "劳动节"
        )
    }

    /// 测试所有地区所有节假日名称访问不崩溃
    func testAllHolidayNamesDoNotCrash() {
        let testCases: [(String, HolidayRegion)] = [
            // 中国
            ("Spring Festival", .china),
            ("Ching Ming Festival", .china),
            ("Qingming Festival", .china),
            ("Tomb Sweeping Day", .china),
            ("Labour Day", .china),
            ("Labor Day", .china),
            ("Dragon Boat Festival", .china),
            ("Mid-Autumn Festival", .china),
            ("National Day", .china),
            ("New Year's Day", .china),
            // 日本
            ("New Year's Day", .japan),
            ("Greenery Day", .japan),
            ("Children's Day", .japan),
            // 韩国
            ("Children's Day", .korea),
            ("Buddha's Birthday", .korea),
            // 美国
            ("New Year's Day", .unitedStates),
            ("Labor Day", .unitedStates),
            ("Martin Luther King Jr. Day", .unitedStates)
        ]

        for (name, region) in testCases {
            // 所有访问都不应崩溃
            let result = localizer.localizedDisplayName(for: name, in: region)
            XCTAssertNotNil(result)
        }
    }
}
