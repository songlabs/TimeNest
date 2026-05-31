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

    // MARK: - Japan Holiday - 更多变体测试

    func testJapanVernalEquinoxDayVariants() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Vernal Equinox Day", in: .japan),
            "春分の日"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Vernal Equinox Day (in lieu)", in: .japan),
            "春分の日 振替休日"
        )
    }

    func testJapanConstitutionMemorialDayInLieu() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Constitution Memorial Day (in lieu)", in: .japan),
            "憲法記念日 振替休日"
        )
    }

    func testJapanHealthSportsDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Health-Sports Day", in: .japan),
            "スポーツの日"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Health Sports Day", in: .japan),
            "スポーツの日"
        )
    }

    func testJapanLabourThanksgivingDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Labour Thanksgiving Day", in: .japan),
            "勤労感謝の日"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Labor Thanksgiving Day", in: .japan),
            "勤労感謝の日"
        )
    }

    func testJapanEmperorsBirthday() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "The Emperor's Birthday", in: .japan),
            "天皇誕生日"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Emperor's Birthday", in: .japan),
            "天皇誕生日"
        )
    }

    func testJapanSilverWeek() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Extra holiday for Silver Week", in: .japan),
            "シルバーウィーク 振替休日"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Silver Week", in: .japan),
            "シルバーウィーク"
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

    // MARK: - Korea Holiday - 更多变体测试

    func testKoreanNewYear() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Korean New Year", in: .korea),
            "설날"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Korean New Year Holiday", in: .korea),
            "설날"
        )
    }

    func testKoreaMarch1stMovement() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "March 1st Movement", in: .korea),
            "3·1 절"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "March 1st Movement (in lieu)", in: .korea),
            "3·1 절 振替休日"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Independence Movement Day", in: .korea),
            "3·1 절"
        )
    }

    func testKoreaConstitutionDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Constitution Day", in: .korea),
            "제헌절"
        )
    }

    func testKoreaLiberationDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Liberation Day", in: .korea),
            "광복절"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Liberation Day (in lieu)", in: .korea),
            "광복절 振替休日"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Victory Day", in: .korea),
            "광복절"
        )
    }

    func testKoreaMemorialDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Memorial Day", in: .korea),
            "현충일"
        )
    }

    func testKoreaNationalFoundationDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "National Foundation Day", in: .korea),
            "개천절"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "National Foundation Day (in lieu)", in: .korea),
            "개천절 振替休日"
        )
    }

    func testKoreaHangeulDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Hangeul Day", in: .korea),
            "한글날"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Hangul Day", in: .korea),
            "한글날"
        )
    }

    func testKoreaBuddhasBirthdayInLieu() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Buddha's Birthday (in lieu)", in: .korea),
            "부처님 오신 날 振替休日"
        )
    }

    func testKoreaHarvestFestival() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Harvest Festival", in: .korea),
            "추수감사절"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Harvest Festival Holiday", in: .korea),
            "추수감사절"
        )
    }

    func testKoreaChristmasDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Christmas Day", in: .korea),
            "크리스마스"
        )
    }

    func testKoreaLaborDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Labor Day", in: .korea),
            "노동절"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Labour Day", in: .korea),
            "노동절"
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

    // MARK: - USA Holiday - 更多变体测试

    func testUSAMartinLutherKingJrDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Martin Luther King Jr. Day", in: .unitedStates),
            "Martin Luther King Jr. Day"
        )
    }

    func testUSAMemorialDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Memorial Day", in: .unitedStates),
            "Memorial Day"
        )
    }

    func testUSAIndependenceDayVariants() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Independence Day", in: .unitedStates),
            "Independence Day"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Independence Day (in lieu)", in: .unitedStates),
            "Independence Day 振替休日"
        )
    }

    func testUSAPresidentsDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Presidents' Day", in: .unitedStates),
            "Presidents' Day"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "President's Day (Regional Holiday)", in: .unitedStates),
            "Presidents' Day"
        )
    }

    func testUSAColumbusDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Columbus Day", in: .unitedStates),
            "Columbus Day"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Columbus Day (Regional Holiday)", in: .unitedStates),
            "Columbus Day"
        )
    }

    func testUSAVeteransDayVariants() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Veterans Day", in: .unitedStates),
            "Veterans Day"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Veterans' Day", in: .unitedStates),
            "Veterans Day"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Veterans Day (Regional Holiday)", in: .unitedStates),
            "Veterans Day"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Veterans' Day (Regional Holiday)", in: .unitedStates),
            "Veterans Day"
        )
    }

    func testUSAThanksgivingVariants() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Thanksgiving", in: .unitedStates),
            "Thanksgiving"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Thanksgiving Day", in: .unitedStates),
            "Thanksgiving"
        )
    }

    func testUSADayAfterThanksgiving() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Day after Thanksgiving (Regional Holiday)", in: .unitedStates),
            "Black Friday"
        )
    }

    func testUSACrhistmasDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Christmas Day", in: .unitedStates),
            "Christmas"
        )
    }

    func testUSAJuneteenthVariants() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Juneteenth", in: .unitedStates),
            "Juneteenth"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Juneteenth (Regional Holiday)", in: .unitedStates),
            "Juneteenth"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Juneteenth (in lieu)", in: .unitedStates),
            "Juneteenth 振替休日"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Juneteenth (in lieu) (Regional Holiday)", in: .unitedStates),
            "Juneteenth 振替休日"
        )
    }

    func testUSAIndigenousPeopleDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "US Indigenous People's Day (Regional Holiday)", in: .unitedStates),
            "Indigenous People's Day"
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

    // MARK: - China Holiday - 春节变体测试

    func testChineseNewYearsEve() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Chinese New Year's Eve", in: .china),
            "春节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Lunar New Year's Eve", in: .china),
            "春节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Spring Festival Eve", in: .china),
            "春节"
        )
    }

    func testSpringFestivalGoldenWeek() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Spring Festival Golden Week Holiday", in: .china),
            "春节"
        )
    }

    func testChineseNewYearHolidayVariants() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Chinese New Year Holiday 2", in: .china),
            "春节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Chinese New Year Holiday 7", in: .china),
            "春节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Lunar New Year Holiday 5", in: .china),
            "春节"
        )
    }

    func testSpringFestivalHolidayVariants() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Spring Festival Holiday 6", in: .china),
            "春节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Spring Festival Holiday 7", in: .china),
            "春节"
        )
    }

    // MARK: - China Holiday - 清明节变体测试

    func testChingMingFestivalInLieu() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Ching Ming Festival (in lieu)", in: .china),
            "清明节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Qingming Festival (in lieu)", in: .china),
            "清明节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Tomb Sweeping Day (in lieu)", in: .china),
            "清明节"
        )
    }

    // MARK: - China Holiday - 劳动节变体测试

    func testLabourDayHolidayVariants4_5() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Labour Day Holiday 4", in: .china),
            "劳动节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Labour Day Holiday 5", in: .china),
            "劳动节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Labor Day Holiday 4", in: .china),
            "劳动节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Labor Day Holiday 5", in: .china),
            "劳动节"
        )
    }

    func testMayDayVariants() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "May Day", in: .china),
            "劳动节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "May Day Holiday", in: .china),
            "劳动节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "International Labour Day", in: .china),
            "劳动节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "International Labor Day", in: .china),
            "劳动节"
        )
    }

    // MARK: - China Holiday - 端午节变体测试

    func testDragonBoatFestivalVariants() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Dragon Boat Festival Holiday 1", in: .china),
            "端午节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Dragon Boat Festival Holiday 2", in: .china),
            "端午节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Dragon Boat Festival Holiday 3", in: .china),
            "端午节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Dragon Boat Holiday", in: .china),
            "端午节"
        )
    }

    // MARK: - China Holiday - 中秋节变体测试

    func testMidAutumnFestivalVariants() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Mid-Autumn Festival Holiday 1", in: .china),
            "中秋节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Mid-Autumn Festival Holiday 2", in: .china),
            "中秋节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Mid-Autumn Festival Holiday 3", in: .china),
            "中秋节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Mid Autumn Festival Holiday 1", in: .china),
            "中秋节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Mid Autumn Festival Holiday 2", in: .china),
            "中秋节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Moon Festival Holiday", in: .china),
            "中秋节"
        )
    }

    // MARK: - China Holiday - 国庆节变体测试

    func testNationalDayHolidayVariants4_7() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "National Day Holiday 4", in: .china),
            "国庆节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "National Day Holiday 5", in: .china),
            "国庆节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "National Day Holiday 6", in: .china),
            "国庆节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "National Day Holiday 7", in: .china),
            "国庆节"
        )
    }

    func testChineseNationalDayVariants() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Chinese National Day", in: .china),
            "国庆节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Chinese National Day Holiday", in: .china),
            "国庆节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Chinese National Day Holiday 1", in: .china),
            "国庆节"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Chinese National Day Holiday 7", in: .china),
            "国庆节"
        )
    }

    func testNationalDayGoldenWeek() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "National Day Golden Week Holiday", in: .china),
            "国庆节"
        )
    }

    // MARK: - China Holiday - 元旦变体测试

    func testDayAfterNewYearHoliday() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Day after New Year's Day Holiday", in: .china),
            "元旦"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Day after New Years Day Holiday", in: .china),
            "元旦"
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

    // MARK: - Office Holidays 实际数据源覆盖测试

    /// 测试 China Office Holidays 2026 的 SUMMARY 样本
    /// 验证所有实际数据源中的节假日名称都能正确本地化为中文
    func testChinaOfficeHolidays2026Sample() {
        // 从 https://www.officeholidays.com/ics/china 获取的实际 SUMMARY 列表
        let chinaOfficeHolidays2026: [(String, String)] = [
            ("China: New Year's Day", "元旦"),
            ("China: Day after New Year's Day Holiday", "元旦"),
            ("China: Spring Festival", "春节"),
            ("China: Spring Festival Holiday", "春节"),
            ("China: Ching Ming Festival", "清明节"),
            ("China: Ching Ming Festival (in lieu)", "清明节"),
            ("China: Labour Day", "劳动节"),
            ("China: Labour Day Holiday", "劳动节"),
            ("China: Dragon Boat Festival", "端午节"),
            ("China: Mid-Autumn Festival", "中秋节"),
            ("China: Chinese National Day", "国庆节"),
            ("China: Chinese National Day Holiday", "国庆节")
        ]

        for (summary, expectedChinese) in chinaOfficeHolidays2026 {
            let result = localizer.localizedDisplayName(for: summary, in: .china)
            XCTAssertEqual(
                result, expectedChinese,
                "China 节假日 \"\(summary)\" 应该本地化为 \"\(expectedChinese)\"，但得到 \"\(result)\""
            )
        }
    }

    /// 测试 Korea Office Holidays 2026 的 SUMMARY 样本
    func testKoreaOfficeHolidays2026Sample() {
        // 从 https://www.officeholidays.com/ics/south-korea 获取的实际 SUMMARY 列表
        let koreaOfficeHolidays2026: [(String, String)] = [
            ("South Korea: New Year's Day", "신정"),
            ("South Korea: Korean New Year", "설날"),
            ("South Korea: Korean New Year Holiday", "설날"),
            ("South Korea: March 1st Movement", "3·1 절"),
            ("South Korea: Constitution Day", "제헌절"),
            ("South Korea: Buddha's Birthday", "부처님 오신 날"),
            ("South Korea: Children's Day", "어린이날"),
            ("South Korea: Liberation Day", "광복절"),
            ("South Korea: Memorial Day", "현충일"),
            ("South Korea: National Foundation Day", "개천절"),
            ("South Korea: Harvest Festival", "추수감사절"),
            ("South Korea: Harvest Festival Holiday", "추수감사절"),
            ("South Korea: Hangeul Day", "한글날"),
            ("South Korea: Christmas Day", "크리스마스"),
            ("South Korea: Labor Day", "노동절")
        ]

        for (summary, expectedKorean) in koreaOfficeHolidays2026 {
            let result = localizer.localizedDisplayName(for: summary, in: .korea)
            XCTAssertEqual(
                result, expectedKorean,
                "Korea 节假日 \"\(summary)\" 应该本地化为 \"\(expectedKorean)\"，但得到 \"\(result)\""
            )
        }
    }

    /// 测试 Japan Office Holidays 2026 的 SUMMARY 样本
    func testJapanOfficeHolidays2026Sample() {
        // 从 https://www.officeholidays.com/ics/japan 获取的实际 SUMMARY 列表
        let japanOfficeHolidays2026: [(String, String)] = [
            ("Japan: New Year's Day", "元日"),
            ("Japan: Coming-of-Age Day", "成人の日"),
            ("Japan: National Foundation Day", "建国記念の日"),
            ("Japan: The Emperor's Birthday", "天皇誕生日"),
            ("Japan: Vernal Equinox Day", "春分の日"),
            ("Japan: Showa Day", "昭和の日"),
            ("Japan: Constitution Memorial Day (in lieu)", "憲法記念日 振替休日"),
            ("Japan: Greenery Day", "みどりの日"),
            ("Japan: Children's Day", "こどもの日"),
            ("Japan: Health-Sports Day", "スポーツの日"),
            ("Japan: Marine Day", "海の日"),
            ("Japan: Mountain Day", "山の日"),
            ("Japan: Respect for the Aged Day", "敬老の日"),
            ("Japan: Autumnal Equinox Day", "秋分の日"),
            ("Japan: Culture Day", "文化の日"),
            ("Japan: Labour Thanksgiving Day", "勤労感謝の日")
        ]

        for (summary, expectedJapanese) in japanOfficeHolidays2026 {
            let result = localizer.localizedDisplayName(for: summary, in: .japan)
            XCTAssertEqual(
                result, expectedJapanese,
                "Japan 节假日 \"\(summary)\" 应该本地化为 \"\(expectedJapanese)\"，但得到 \"\(result)\""
            )
        }
    }

    /// 测试 USA Office Holidays 2026 的 SUMMARY 样本
    func testUSAOofficeHolidays2026Sample() {
        // 从 https://www.officeholidays.com/ics/usa 获取的实际 SUMMARY 列表
        let usaOfficeHolidays2026: [(String, String)] = [
            ("USA: New Year's Day", "New Year's Day"),
            ("USA: Martin Luther King Jr. Day", "Martin Luther King Jr. Day"),
            ("USA: President's Day (Regional Holiday)", "Presidents' Day"),
            ("USA: Memorial Day", "Memorial Day"),
            ("USA: Independence Day", "Independence Day"),
            ("USA: Labor Day", "Labor Day"),
            ("USA: Columbus Day (Regional Holiday)", "Columbus Day"),
            ("USA: Juneteenth (Regional Holiday)", "Juneteenth"),
            ("USA: US Indigenous People's Day (Regional Holiday)", "Indigenous People's Day"),
            ("USA: Veterans Day (Regional Holiday)", "Veterans Day"),
            ("USA: Thanksgiving", "Thanksgiving"),
            ("USA: Day after Thanksgiving (Regional Holiday)", "Black Friday"),
            ("USA: Christmas Day", "Christmas")
        ]

        for (summary, expectedEnglish) in usaOfficeHolidays2026 {
            let result = localizer.localizedDisplayName(for: summary, in: .unitedStates)
            XCTAssertEqual(
                result, expectedEnglish,
                "USA 节假日 \"\(summary)\" 应该本地化为 \"\(expectedEnglish)\"，但得到 \"\(result)\""
            )
        }
    }
}
