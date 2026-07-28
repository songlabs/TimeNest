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
        let regions: [HolidayRegion] = [.japan, .china, .korea, .unitedStates, .taiwan]
        
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
            "3·1절 대체공휴일"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Independence Movement Day", in: .korea),
            "3·1절"
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
            "광복절 대체공휴일"
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
            "개천절 대체공휴일"
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
            "부처님 오신 날 대체공휴일"
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
            "Independence Day (Observed)"
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
            "Juneteenth (Observed)"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Juneteenth (in lieu) (Regional Holiday)", in: .unitedStates),
            "Juneteenth (Observed)"
        )
    }

    func testUSAIndigenousPeopleDay() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "US Indigenous People's Day (Regional Holiday)", in: .unitedStates),
            "Indigenous People's Day"
        )
    }

    // MARK: - Taiwan Holiday Tests

    func testTaiwanHolidayNamesUseTraditionalChinese() {
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Taiwan: National Day", in: .taiwan),
            "國慶日"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Lunar New Year's Eve", in: .taiwan),
            "除夕"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "Tomb Sweeping Day (in lieu)", in: .taiwan),
            "清明節補假"
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

    func testCleanSouthKoreaPrefix() {
        // 测试 Office Holidays 源的 "South Korea:" 前缀清理
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "South Korea: Children's Day", in: .korea),
            "어린이날"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "South Korea: New Year's Day", in: .korea),
            "신정"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "South Korea: Korean New Year", in: .korea),
            "설날"
        )
        XCTAssertEqual(
            localizer.localizedDisplayName(for: "South Korea: Liberation Day", in: .korea),
            "광복절"
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

    // MARK: - BundleHolidayProvider 2026-06 中国端午节测试

    func testBundleHolidayProviderChinaDragonBoat2026() async throws {
        let provider = BundleHolidayProvider()
        let from = DateOnly(year: 2026, month: 6, day: 19)
        let to = DateOnly(year: 2026, month: 6, day: 19)

        let holidays = try await provider.holidays(region: .china, from: from, to: to)

        XCTAssertEqual(holidays.count, 1, "2026-06-19 应该有 1 个中国节假日")
        XCTAssertEqual(holidays.first?.id, "cn-dragonboat-2026")
        XCTAssertEqual(holidays.first?.localizedNames.zhHans, "端午节")
    }

    func testBundleHolidayProviderChinaDragonBoatHolidayPeriod2026() async throws {
        let provider = BundleHolidayProvider()
        let from = DateOnly(year: 2026, month: 6, day: 19)
        let to = DateOnly(year: 2026, month: 6, day: 21)

        let holidays = try await provider.holidays(region: .china, from: from, to: to)

        XCTAssertEqual(holidays.count, 3, "2026-06-19 到 2026-06-21 应该有 3 个中国节假日")
        XCTAssertEqual(holidays[0].date, DateOnly(year: 2026, month: 6, day: 19))
        XCTAssertEqual(holidays[1].date, DateOnly(year: 2026, month: 6, day: 20))
        XCTAssertEqual(holidays[2].date, DateOnly(year: 2026, month: 6, day: 21))
    }

    func testBundleHolidayProviderJapanJune2026IsEmpty() async throws {
        let provider = BundleHolidayProvider()
        let from = DateOnly(year: 2026, month: 6, day: 1)
        let to = DateOnly(year: 2026, month: 6, day: 30)

        let holidays = try await provider.holidays(region: .japan, from: from, to: to)

        XCTAssertEqual(holidays.count, 0, "2026-06 日本没有节假日")
    }

    // MARK: - HolidayUseCase fallback 测试

    func testHolidayUseCaseFallbackToBundleProvider() async throws {
        let provider = BundleHolidayProvider()
        let cacheRepository = InMemoryHolidayEventCacheRepository() // 空缓存
        let useCase = HolidayUseCase(holidayProvider: provider, cacheRepository: cacheRepository)

        let from = DateOnly(year: 2026, month: 6, day: 19)
        let to = DateOnly(year: 2026, month: 6, day: 19)
        let setting = CalendarDisplaySetting(
            displayLanguage: .zhHans,
            selectedHolidayRegions: [.china, .japan],
            weekStartPolicy: .system,
            showLunarCalendar: false
        )

        let holidays = try await useCase.holidaysInDateRange(from: from, to: to, setting: setting)

        XCTAssertEqual(holidays.count, 1, "应该从 BundleHolidayProvider fallback 加载 1 个节假日")
        XCTAssertEqual(holidays.first?.localizedNames.zhHans, "端午节")
    }

    // MARK: - CalendarDisplayUseCase 测试

    func testCalendarDisplayUseCaseShowsChinaDragonBoat2026() async throws {
        let holidayUseCase = HolidayUseCase(holidayProvider: BundleHolidayProvider())
        let localizationUseCase = CalendarLocalizationUseCase()
        let eventUseCase = EventUseCase(repository: InMemoryEventRepository())
        let useCase = CalendarDisplayUseCase(
            holidayUseCase: holidayUseCase,
            localizationUseCase: localizationUseCase,
            eventUseCase: eventUseCase
        )

        let setting = CalendarDisplaySetting(
            displayLanguage: .zhHans,
            selectedHolidayRegions: [.china, .japan],
            weekStartPolicy: .system,
            showLunarCalendar: false
        )

        let grid = try await useCase.monthGrid(year: 2026, month: 6, setting: setting)

        // 查找 2026-06-19 的 cell
        let dragonBoatDay = grid.days.first { $0.date.year == 2026 && $0.date.month == 6 && $0.date.day == 19 }
        XCTAssertNotNil(dragonBoatDay, "应该找到 2026-06-19 的 cell")
        XCTAssertEqual(dragonBoatDay?.holidays.count, 1, "2026-06-19 应该有 1 个节假日")
        XCTAssertEqual(dragonBoatDay?.holidays.first?.region, .china, "节假日应该来自 .china")
        XCTAssertEqual(dragonBoatDay?.holidays.first?.localizedNames.zhHans, "端午节", "节假日名称应该是端午节")
    }

    func testCalendarDisplayUseCaseShowsChinaDragonBoatHolidayPeriod2026() async throws {
        let holidayUseCase = HolidayUseCase(holidayProvider: BundleHolidayProvider())
        let localizationUseCase = CalendarLocalizationUseCase()
        let eventUseCase = EventUseCase(repository: InMemoryEventRepository())
        let useCase = CalendarDisplayUseCase(
            holidayUseCase: holidayUseCase,
            localizationUseCase: localizationUseCase,
            eventUseCase: eventUseCase
        )

        let setting = CalendarDisplaySetting(
            displayLanguage: .zhHans,
            selectedHolidayRegions: [.china, .japan],
            weekStartPolicy: .system,
            showLunarCalendar: false
        )

        let grid = try await useCase.monthGrid(year: 2026, month: 6, setting: setting)

        // 验证 2026-06-19~21 都有节假日
        for day in 19...21 {
            let cell = grid.days.first { $0.date.year == 2026 && $0.date.month == 6 && $0.date.day == day }
            XCTAssertNotNil(cell, "应该找到 2026-06-\(day) 的 cell")
            XCTAssertEqual(cell?.holidays.count, 1, "2026-06-\(day) 应该有 1 个节假日")
            XCTAssertEqual(cell?.holidays.first?.localizedNames.zhHans, "端午节", "2026-06-\(day) 节假日名称应该是端午节")
        }
    }

    func testCalendarDisplayUseCaseLoadsHolidaysOnceForWholeMonth() async throws {
        let provider = RecordingHolidayProvider()
        let useCase = CalendarDisplayUseCase(
            holidayUseCase: HolidayUseCase(
                holidayProvider: provider,
                cacheRepository: InMemoryHolidayEventCacheRepository()
            ),
            localizationUseCase: CalendarLocalizationUseCase(),
            eventUseCase: EventUseCase(repository: InMemoryEventRepository())
        )
        let setting = CalendarDisplaySetting(
            displayLanguage: .enUS,
            selectedHolidayRegions: [.japan],
            weekStartPolicy: .sunday,
            showLunarCalendar: false
        )

        _ = try await useCase.monthGrid(year: 2026, month: 6, setting: setting)

        XCTAssertEqual(provider.requests.count, 1)
        XCTAssertEqual(provider.requests.first?.region, .japan)
        XCTAssertEqual(provider.requests.first?.from, DateOnly(year: 2026, month: 6, day: 1))
        XCTAssertEqual(provider.requests.first?.to, DateOnly(year: 2026, month: 6, day: 30))
    }

    // MARK: - Release Readiness Regression Tests

    func testDateOnlyRoundTripUsesFixedTimeZone() throws {
        let timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 9 * 60 * 60))
        let calendar = gregorianCalendar(timeZone: timeZone)
        let sourceDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 23, minute: 30)))

        let dateOnly = try XCTUnwrap(DateOnly(from: sourceDate, in: timeZone))
        XCTAssertEqual(dateOnly, DateOnly(year: 2026, month: 12, day: 31))

        let roundTripped = dateOnly.toDate(in: timeZone)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: roundTripped)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 31)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    func testMonthGridHandlesMonthStartEndAndCrossYearForSundayStart() async throws {
        let useCase = makeCalendarDisplayUseCase()
        let setting = CalendarDisplaySetting(
            displayLanguage: .enUS,
            selectedHolidayRegions: [],
            weekStartPolicy: .sunday,
            showLunarCalendar: false
        )

        let grid = try await useCase.monthGrid(year: 2027, month: 1, setting: setting)

        XCTAssertEqual(grid.title, "January 2027")
        XCTAssertEqual(grid.weekdaySymbols, ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
        XCTAssertEqual(grid.days.count, 42)
        XCTAssertEqual(grid.days.first?.date, DateOnly(year: 2026, month: 12, day: 27))
        XCTAssertEqual(grid.days.last?.date, DateOnly(year: 2027, month: 2, day: 6))
        XCTAssertEqual(grid.days.filter(\.isInCurrentMonth).count, 31)
    }

    func testMonthGridWeekStartPolicySundayMondaySaturdayAndSystem() async throws {
        let useCase = makeCalendarDisplayUseCase()
        let policies: [(WeekStartPolicy, [String], DateOnly)] = [
            (.sunday, ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], DateOnly(year: 2026, month: 5, day: 31)),
            (.monday, ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], DateOnly(year: 2026, month: 6, day: 1)),
            (.saturday, ["Sat", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri"], DateOnly(year: 2026, month: 5, day: 30))
        ]

        for (policy, expectedSymbols, expectedFirstDate) in policies {
            let setting = CalendarDisplaySetting(
                displayLanguage: .enUS,
                selectedHolidayRegions: [],
                weekStartPolicy: policy,
                showLunarCalendar: false
            )

            let grid = try await useCase.monthGrid(year: 2026, month: 6, setting: setting)
            XCTAssertEqual(grid.weekdaySymbols, expectedSymbols)
            XCTAssertEqual(grid.days.first?.date, expectedFirstDate)
        }

        let systemSetting = CalendarDisplaySetting(
            displayLanguage: .enUS,
            selectedHolidayRegions: [],
            weekStartPolicy: .system,
            showLunarCalendar: false
        )
        let systemGrid = try await useCase.monthGrid(year: 2026, month: 6, setting: systemSetting)
        XCTAssertEqual(systemGrid.days.count % 7, 0)
        XCTAssertEqual(systemGrid.days.filter(\.isInCurrentMonth).count, 30)
        XCTAssertEqual(systemGrid.weekdaySymbols.count, 7)
    }

    func testCalendarLocalizationFormatsMonthAndWeekdayTitles() {
        let useCase = CalendarLocalizationUseCase()

        XCTAssertEqual(useCase.monthTitle(year: 2026, month: 6, language: .ja), "2026年6月")
        XCTAssertEqual(useCase.monthTitle(year: 2026, month: 6, language: .zhHans), "2026年6月")
        XCTAssertEqual(useCase.monthTitle(year: 2026, month: 6, language: .ko), "2026년 6월")
        XCTAssertEqual(useCase.monthTitle(year: 2026, month: 6, language: .enUS), "June 2026")
        XCTAssertEqual(useCase.weekdaySymbols(language: .ja, weekStartPolicy: .monday), ["月", "火", "水", "木", "金", "土", "日"])
    }

    func testCalendarViewModeUsesLocalizedKeys() {
        XCTAssertEqual(CalendarViewMode.month.localizedKey.rawValue, "view_mode.month")
        XCTAssertEqual(CalendarViewMode.week.localizedKey.rawValue, "view_mode.week")
        XCTAssertEqual(CalendarViewMode.day.localizedKey.rawValue, "view_mode.day")
    }

    func testHolidayUseCaseReturnsNoHolidaysWhenRegionsAreEmpty() async throws {
        let cacheRepository = InMemoryHolidayEventCacheRepository(events: [
            HolidayEvent(
                id: "cached-us-new-year",
                region: .unitedStates,
                date: DateOnly(year: 2026, month: 1, day: 1),
                name: "New Year's Day",
                translatedNames: [:],
                type: .publicHoliday,
                sourceURL: "https://example.com/us.ics"
            )
        ])
        let useCase = HolidayUseCase(cacheRepository: cacheRepository)
        let setting = CalendarDisplaySetting(
            displayLanguage: .enUS,
            selectedHolidayRegions: [],
            weekStartPolicy: .sunday,
            showLunarCalendar: false
        )

        let holidays = try await useCase.holidaysInDateRange(
            from: DateOnly(year: 2026, month: 1, day: 1),
            to: DateOnly(year: 2026, month: 1, day: 1),
            setting: setting
        )

        XCTAssertTrue(holidays.isEmpty)
    }

    func testHolidayNamesDisplayInRegionLanguageRegardlessOfAppLanguage() async throws {
        let cacheRepository = InMemoryHolidayEventCacheRepository(events: [
            HolidayEvent(
                id: "jp-new-year",
                region: .japan,
                date: DateOnly(year: 2026, month: 1, day: 1),
                name: "Japan: New Year's Day",
                sourceURL: "https://example.com/japan.ics"
            ),
            HolidayEvent(
                id: "cn-spring-festival",
                region: .china,
                date: DateOnly(year: 2026, month: 2, day: 17),
                name: "China: Spring Festival",
                sourceURL: "https://example.com/china.ics"
            ),
            HolidayEvent(
                id: "kr-new-year",
                region: .korea,
                date: DateOnly(year: 2026, month: 1, day: 1),
                name: "South Korea: New Year's Day",
                sourceURL: "https://example.com/korea.ics"
            ),
            HolidayEvent(
                id: "us-new-year",
                region: .unitedStates,
                date: DateOnly(year: 2026, month: 1, day: 1),
                name: "USA: New Year's Day",
                sourceURL: "https://example.com/usa.ics"
            ),
            HolidayEvent(
                id: "tw-national-day",
                region: .taiwan,
                date: DateOnly(year: 2026, month: 10, day: 10),
                name: "Taiwan: National Day",
                sourceURL: "https://example.com/taiwan.ics"
            )
        ])
        let useCase = HolidayUseCase(cacheRepository: cacheRepository)

        let holidays = try await useCase.holidays(
            regions: [.japan, .china, .korea, .unitedStates, .taiwan],
            from: DateOnly(year: 2026, month: 1, day: 1),
            to: DateOnly(year: 2026, month: 10, day: 10)
        )
        let namesByRegion = Dictionary(
            uniqueKeysWithValues: holidays.map { holiday in
                (holiday.region, holiday.localizedNames.displayName(for: holiday.region))
            }
        )

        XCTAssertEqual(namesByRegion[.japan], "元日")
        XCTAssertEqual(namesByRegion[.china], "春节")
        XCTAssertEqual(namesByRegion[.korea], "신정")
        XCTAssertEqual(namesByRegion[.unitedStates], "New Year's Day")
        XCTAssertEqual(namesByRegion[.taiwan], "國慶日")
    }

    func testRecommendedHolidaySourceURLsAreHTTPSAndRegionScoped() {
        for region in HolidayRegion.allCases {
            let sources = HolidayRecommendedSources.sources(for: region)
            XCTAssertFalse(sources.isEmpty)
            XCTAssertTrue(sources.allSatisfy { $0.region == region })
            XCTAssertTrue(sources.allSatisfy { URL(string: $0.urlString)?.scheme == "https" })
        }
    }

    func testEventUseCaseCreateUpdateDeleteAndStableSameDayOrdering() async throws {
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository)
        let calendar = gregorianCalendar(timeZone: TimeZone(secondsFromGMT: 0)!)
        let morning = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 9)))
        let afternoon = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 15)))
        let interval = DateInterval(
            start: try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10))),
            end: try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 11)))
        )
        let eventID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let laterEventID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        let event = CalendarEvent(
            id: eventID,
            title: "Morning",
            note: nil,
            startDate: morning,
            endDate: calendar.date(byAdding: .hour, value: 1, to: morning),
            isAllDay: false,
            categoryID: nil,
            recurrenceRule: .none,
            reminderTemplateID: nil,
            importSource: nil,
            createdAt: morning,
            updatedAt: morning
        )
        let laterEvent = CalendarEvent(
            id: laterEventID,
            title: "Afternoon",
            note: nil,
            startDate: afternoon,
            endDate: calendar.date(byAdding: .hour, value: 1, to: afternoon),
            isAllDay: false,
            categoryID: nil,
            recurrenceRule: .none,
            reminderTemplateID: nil,
            importSource: nil,
            createdAt: afternoon,
            updatedAt: afternoon
        )

        try await useCase.createEvent(laterEvent)
        try await useCase.createEvent(event)
        let createdEvents = try await useCase.events(in: interval)
        let createdOccurrences = try await useCase.occurrences(in: interval)
        XCTAssertEqual(createdEvents.map(\.title), ["Morning", "Afternoon"])
        XCTAssertEqual(createdOccurrences.map(\.title), ["Morning", "Afternoon"])

        var updatedEvent = event
        updatedEvent.title = "Updated Morning"
        try await useCase.updateEvent(updatedEvent)
        let storedUpdatedEvent = try await repository.event(id: eventID)
        XCTAssertEqual(storedUpdatedEvent?.title, "Updated Morning")

        try await useCase.deleteEvent(id: eventID)
        let deletedEvent = try await repository.event(id: eventID)
        let remainingEvents = try await useCase.events(in: interval)
        XCTAssertNil(deletedEvent)
        XCTAssertEqual(remainingEvents.map(\.title), ["Afternoon"])
    }

    func testCalendarDisplayUseCaseIncludesLateNightEventInDayCell() async throws {
        let repository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(repository: repository)
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 22, minute: 50)))
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 23, minute: 46)))
        let useCase = CalendarDisplayUseCase(
            holidayUseCase: HolidayUseCase(cacheRepository: InMemoryHolidayEventCacheRepository()),
            localizationUseCase: CalendarLocalizationUseCase(),
            eventUseCase: eventUseCase
        )
        let setting = CalendarDisplaySetting(
            displayLanguage: .zhHans,
            selectedHolidayRegions: [],
            weekStartPolicy: .sunday,
            showLunarCalendar: false
        )

        try await eventUseCase.createEvent(CalendarEvent(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            title: "我",
            note: nil,
            startDate: start,
            endDate: end,
            isAllDay: false,
            categoryID: nil,
            recurrenceRule: .none,
            reminderTemplateID: nil,
            importSource: nil,
            createdAt: start,
            updatedAt: start
        ))

        let grid = try await useCase.monthGrid(year: 2026, month: 6, setting: setting)
        let day = try XCTUnwrap(grid.days.first { $0.date == DateOnly(year: 2026, month: 6, day: 10) })

        XCTAssertEqual(day.events.map(\.title), ["我"])
        XCTAssertEqual(day.events.first?.startDate, start)
        XCTAssertEqual(day.events.first?.endDate, end)
    }

    @MainActor
    func testWeekViewGeneratesSevenDaysFromSelectedDate() async throws {
        let calendar = gregorianCalendar(timeZone: TimeZone(secondsFromGMT: 0)!)
        let repository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(repository: repository)
        let viewModel = MonthCalendarViewModel(
            calendarDisplayUseCase: CalendarDisplayUseCase(
                holidayUseCase: HolidayUseCase(holidayProvider: BundleHolidayProvider()),
                localizationUseCase: CalendarLocalizationUseCase(),
                eventUseCase: eventUseCase
            ),
            eventUseCase: eventUseCase,
            calendarSharingStore: makeCalendarSharingStore(eventUseCase: eventUseCase)
        )

        viewModel.selectedDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10)))
        await viewModel.reloadMonth()

        let weekDates = viewModel.weekCells.map(\.date)
        XCTAssertEqual(weekDates.count, 7)
        XCTAssertTrue(weekDates.contains(DateOnly(year: 2026, month: 6, day: 10)))
    }

    @MainActor
    func testShiftInputReplacesExplicitShiftEvenWhenWorkInfoExists() async throws {
        let calendar = gregorianCalendar(timeZone: TimeZone(secondsFromGMT: 0)!)
        let repository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(repository: repository)
        let viewModel = MonthCalendarViewModel(
            calendarDisplayUseCase: CalendarDisplayUseCase(
                holidayUseCase: HolidayUseCase(cacheRepository: InMemoryHolidayEventCacheRepository()),
                localizationUseCase: CalendarLocalizationUseCase(),
                eventUseCase: eventUseCase
            ),
            eventUseCase: eventUseCase,
            calendarSharingStore: makeCalendarSharingStore(eventUseCase: eventUseCase)
        )
        let shiftDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10)))
        let existingStart = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 8, minute: 30)))
        let existingEnd = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 17, minute: 30)))
        let existingID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!

        try await eventUseCase.createEvent(CalendarEvent(
            id: existingID,
            title: "Day Shift",
            note: nil,
            startDate: existingStart,
            endDate: existingEnd,
            isAllDay: false,
            categoryID: nil,
            recurrenceRule: .none,
            reminderTemplateID: nil,
            importSource: nil,
            createdAt: existingStart,
            updatedAt: existingStart,
            shiftTemplateID: .day,
            workInfo: WorkInfo(workDate: shiftDay, workSessionId: UUID())
        ))

        let nightTemplate = ShiftTimeTemplate(
            id: .night,
            nameKey: .shiftNight,
            displayName: "Night Shift",
            note: "",
            colorHex: "#5C6BC0",
            startTime: "17:00",
            endTime: "09:00",
            enabled: true
        )

        let didSave = await viewModel.createShiftEvent(on: shiftDay, template: nightTemplate)
        let storedEvents = try await eventUseCase.events(in: DateInterval(
            start: shiftDay,
            end: try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: shiftDay))
        ))

        XCTAssertTrue(didSave)
        XCTAssertEqual(storedEvents.count, 1)
        XCTAssertEqual(storedEvents.first?.id, existingID)
        XCTAssertEqual(storedEvents.first?.title, "Night Shift")
        XCTAssertEqual(storedEvents.first?.shiftTemplateID, .night)
    }

    @MainActor
    func testWidgetSnapshotBuilderCreatesBasicSnapshotFromInMemoryData() async throws {
        let calendar = gregorianCalendar(timeZone: TimeZone(secondsFromGMT: 0)!)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 8)))
        let eventStart = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 9)))
        let repository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(repository: repository)
        let cacheRepository = InMemoryHolidayEventCacheRepository()
        let managerSuite = "WidgetSnapshotBuilderTests"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: managerSuite))
        defaults.removePersistentDomain(forName: managerSuite)
        let holidaySubscriptionManager = HolidaySubscriptionManager(
            cacheRepository: cacheRepository,
            userDefaults: defaults
        )
        let holidayUseCase = HolidayUseCase(cacheRepository: cacheRepository)
        let calendarDisplayUseCase = CalendarDisplayUseCase(
            holidayUseCase: holidayUseCase,
            localizationUseCase: CalendarLocalizationUseCase(),
            eventUseCase: eventUseCase
        )
        let builder = WidgetSnapshotBuilder(
            calendarDisplayUseCase: calendarDisplayUseCase,
            eventUseCase: eventUseCase,
            holidayUseCase: holidayUseCase,
            holidaySubscriptionManager: holidaySubscriptionManager
        )

        try await eventUseCase.createEvent(CalendarEvent(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            title: "Widget Event",
            note: nil,
            startDate: eventStart,
            endDate: calendar.date(byAdding: .hour, value: 1, to: eventStart),
            isAllDay: false,
            categoryID: nil,
            recurrenceRule: .none,
            reminderTemplateID: nil,
            importSource: nil,
            createdAt: now,
            updatedAt: now
        ))

        let snapshot = try await builder.build(now: now)

        XCTAssertEqual(snapshot.months.count, 2)
        XCTAssertEqual(snapshot.months.first?.year, 2026)
        XCTAssertEqual(snapshot.months.first?.month, 6)
        XCTAssertTrue(snapshot.todayEvents.contains { $0.title == "Widget Event" })
        XCTAssertTrue(snapshot.upcomingEvents.contains { $0.title == "Widget Event" })
        defaults.removePersistentDomain(forName: managerSuite)
    }

    private func makeCalendarDisplayUseCase() -> CalendarDisplayUseCase {
        CalendarDisplayUseCase(
            holidayUseCase: HolidayUseCase(cacheRepository: InMemoryHolidayEventCacheRepository()),
            localizationUseCase: CalendarLocalizationUseCase(),
            eventUseCase: EventUseCase(repository: InMemoryEventRepository())
        )
    }

    private func gregorianCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    @MainActor
    private func makeCalendarSharingStore(eventUseCase: EventUseCase) -> CalendarSharingStore {
        let identifier = UUID().uuidString
        let defaults = UserDefaults(suiteName: "CalendarSharingStoreTests-\(identifier)")!
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CalendarSharingStoreTests-\(identifier).json")
        return CalendarSharingStore(
            client: CloudKitCalendarSharingClient(),
            eventUseCase: eventUseCase,
            calendarRepository: InMemoryCalendarRepository(
                calendars: [.personal(name: "My Calendar")]
            ),
            cache: CalendarSharingCache(fileURL: cacheURL),
            selectionPersistence: CalendarSelectionPersistence(
                defaults: defaults,
                key: "selection"
            )
        )
    }

}

/// 空缓存实现，用于测试 fallback 逻辑
class InMemoryHolidayEventCacheRepository: HolidayEventCacheRepositoryProtocol {
    private var storedEvents: [HolidayEvent]

    init(events: [HolidayEvent] = []) {
        self.storedEvents = events
    }

    func saveEvents(_ events: [HolidayEvent], for region: HolidayRegion) async throws {
        storedEvents.removeAll { $0.region == region }
        storedEvents.append(contentsOf: events)
    }

    func getEvents(in interval: ClosedRange<DateOnly>, for regions: [HolidayRegion]) -> [HolidayEvent] {
        guard !regions.isEmpty else { return [] }
        return storedEvents.filter { regions.contains($0.region) && interval.contains($0.date) }.sorted { $0.date < $1.date }
    }

    func getEvents(on date: DateOnly, for regions: [HolidayRegion]) -> [HolidayEvent] {
        guard !regions.isEmpty else { return [] }
        return storedEvents.filter { regions.contains($0.region) && $0.date == date }
    }

    func getEvents(for regions: [HolidayRegion]) -> [HolidayEvent] {
        guard !regions.isEmpty else { return [] }
        return storedEvents.filter { regions.contains($0.region) }.sorted { $0.date < $1.date }
    }
    func clear() async throws {}
    func clearEvents() async throws {}
    func getLastSyncTime(for region: HolidayRegion) -> Date? { nil }
}

private final class RecordingHolidayProvider: HolidayProviding {
    struct Request {
        let region: HolidayRegion
        let from: DateOnly
        let to: DateOnly
    }

    private(set) var requests: [Request] = []

    func holidays(region: HolidayRegion, from: DateOnly, to: DateOnly) async throws -> [Holiday] {
        requests.append(Request(region: region, from: from, to: to))
        return []
    }
}

final class LocalizationResourceParityTests: XCTestCase {
    func testLocalizableStringsKeysAreCompleteAndUniqueAcrossLanguages() throws {
        let resourceRoot = try sourceURL(for: "TimeNest/Resources")
        let languageFolders = ["ja.lproj", "zh-Hans.lproj", "zh-Hant.lproj", "en.lproj", "ko.lproj"]
        var keySets: [String: Set<String>] = [:]

        for folder in languageFolders {
            let fileURL = resourceRoot.appendingPathComponent(folder).appendingPathComponent("Localizable.strings")
            let keys = try localizationKeys(in: fileURL)
            let emptyValues = try localizationEntries(in: fileURL)
                .filter { $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map(\.key)
            XCTAssertEqual(keys.count, Set(keys).count, "\(folder) should not contain duplicate keys")
            XCTAssertTrue(emptyValues.isEmpty, "\(folder) should not contain empty localized values: \(emptyValues)")
            keySets[folder] = Set(keys)
        }

        let expectedKeys = try XCTUnwrap(keySets["en.lproj"])
        for folder in languageFolders {
            XCTAssertEqual(keySets[folder], expectedKeys, "\(folder) should match en.lproj keys")
        }
    }

    func testLocalizableSwiftEnumKeysExistInResources() throws {
        let resourceRoot = try sourceURL(for: "TimeNest/Resources")
        let swiftURL = try sourceURL(for: "TimeNest/Shared/Localization/Localizable.swift")
        let swiftText = try String(contentsOf: swiftURL, encoding: .utf8)
        let enumKeys = Set(matches(in: swiftText, pattern: #"case\s+\w+\s*=\s*\"([^\"]+)\""#))
        let resourceKeys = Set(try localizationKeys(in: resourceRoot.appendingPathComponent("en.lproj/Localizable.strings")))

        XCTAssertFalse(enumKeys.isEmpty)
        XCTAssertTrue(enumKeys.isSubset(of: resourceKeys), "Localizable.swift keys should exist in Localizable.strings")
    }

    func testLocalizablePlaceholderSignaturesMatchAcrossLanguages() throws {
        let resourceRoot = try sourceURL(for: "TimeNest/Resources")
        let languageFolders = ["ja.lproj", "zh-Hans.lproj", "zh-Hant.lproj", "en.lproj", "ko.lproj"]
        let referenceEntries = Dictionary(
            uniqueKeysWithValues: try localizationEntries(
                in: resourceRoot.appendingPathComponent("en.lproj/Localizable.strings")
            )
        )

        for folder in languageFolders {
            let entries = Dictionary(
                uniqueKeysWithValues: try localizationEntries(
                    in: resourceRoot.appendingPathComponent(folder).appendingPathComponent("Localizable.strings")
                )
            )
            for (key, referenceValue) in referenceEntries {
                let value = try XCTUnwrap(entries[key], "\(folder) is missing \(key)")
                XCTAssertEqual(
                    placeholderSignature(in: value),
                    placeholderSignature(in: referenceValue),
                    "\(folder) placeholder signature should match en.lproj for \(key)"
                )
            }
        }
    }

    func testWorkRecordTerminologyAndJPYUnitsAreConsistent() throws {
        let resourceRoot = try sourceURL(for: "TimeNest/Resources")
        let expectations: [String: [String: String]] = [
            "ja.lproj": [
                "entry.kind.work_record": "勤務記録",
                "work_record.section_title": "勤務記録",
                "work_statistics.title": "勤務統計",
                "editor.currencyUnit": "円",
                "holiday_subscription.settings_title": "祝日購読"
            ],
            "zh-Hans.lproj": [
                "entry.kind.work_record": "工作记录",
                "work_record.section_title": "工作记录",
                "work_statistics.title": "工作统计",
                "editor.currencyUnit": "日元"
            ],
            "zh-Hant.lproj": [
                "entry.kind.work_record": "工作記錄",
                "work_record.section_title": "工作記錄",
                "work_statistics.title": "工作統計",
                "editor.currencyUnit": "日圓"
            ],
            "en.lproj": [
                "entry.kind.work_record": "Work Record",
                "work_record.section_title": "Work Records",
                "work_statistics.title": "Work Statistics",
                "editor.currencyUnit": "JPY"
            ],
            "ko.lproj": [
                "entry.kind.work_record": "근무 기록",
                "work_record.section_title": "근무 기록",
                "work_statistics.title": "근무 통계",
                "editor.currencyUnit": "일본 엔"
            ]
        ]

        for (folder, expectedValues) in expectations {
            let entries = Dictionary(
                uniqueKeysWithValues: try localizationEntries(
                    in: resourceRoot.appendingPathComponent(folder).appendingPathComponent("Localizable.strings")
                )
            )
            for (key, expectedValue) in expectedValues {
                XCTAssertEqual(entries[key], expectedValue, "\(folder) should use the agreed term for \(key)")
            }
        }

        for folder in ["zh-Hans.lproj", "zh-Hant.lproj"] {
            let entries = try localizationEntries(
                in: resourceRoot.appendingPathComponent(folder).appendingPathComponent("Localizable.strings")
            )
            let contaminatedKeys = entries
                .filter { $0.value.contains("勤務") }
                .map(\.key)
            XCTAssertTrue(contaminatedKeys.isEmpty, "\(folder) should not contain Japanese 勤務 text: \(contaminatedKeys)")
        }
    }

    func testInfoPlistStringsAreCompleteAcrossLanguages() throws {
        let resourceRoot = try sourceURL(for: "TimeNest/Resources")
        let languageFolders = ["ja.lproj", "zh-Hans.lproj", "zh-Hant.lproj", "en.lproj", "ko.lproj"]
        var keySets: [String: Set<String>] = [:]

        for folder in languageFolders {
            let fileURL = resourceRoot.appendingPathComponent(folder).appendingPathComponent("InfoPlist.strings")
            let entries = try localizationEntries(in: fileURL)
            let keys = entries.map(\.key)
            let emptyValues = entries
                .filter { $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map(\.key)

            XCTAssertEqual(keys.count, Set(keys).count, "\(folder) InfoPlist.strings should not contain duplicate keys")
            XCTAssertTrue(emptyValues.isEmpty, "\(folder) InfoPlist.strings should not contain empty values: \(emptyValues)")
            keySets[folder] = Set(keys)
        }

        let expectedKeys = try XCTUnwrap(keySets["en.lproj"])
        for folder in languageFolders {
            XCTAssertEqual(keySets[folder], expectedKeys, "\(folder) InfoPlist.strings should match en.lproj keys")
        }
    }

    func testDisplayLanguageCodesMapToExpectedLocales() {
        let cases: [(String, DisplayLanguage, String)] = [
            ("ja", .ja, "ja_JP"),
            ("zhHans", .zhHans, "zh_CN"),
            ("zh-Hant", .zhHant, "zh_TW"),
            ("enUS", .enUS, "en_US"),
            ("ko", .ko, "ko_KR"),
            ("system", .system, Locale.current.identifier)
        ]

        for (code, language, localeIdentifier) in cases {
            let manager = LocalizationManager(savedCode: code)
            XCTAssertEqual(manager.currentLanguage, language)
            XCTAssertEqual(manager.currentLanguageCode, code)
            if code != "system" {
                XCTAssertEqual(manager.currentLocale.identifier, localeIdentifier)
            }
        }
    }

    func testUserVisibleDatesFollowEachAppLocaleAndKeepTwentyFourHourTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 23, minute: 15))
        )
        let cases: [(String, Bool)] = [
            ("ja", true),
            ("zhHans", true),
            ("zh-Hant", true),
            ("enUS", false),
            ("ko", true)
        ]

        for (languageCode, yearFirst) in cases {
            let manager = LocalizationManager(savedCode: languageCode)
            let text = manager.formattedUserVisibleDate(for: date)
            let year = try XCTUnwrap(text.range(of: "2026"), "\(languageCode): \(text)")
            let month = try XCTUnwrap(text.range(of: "11"), "\(languageCode): \(text)")
            let day = try XCTUnwrap(text.range(of: "23"), "\(languageCode): \(text)")

            if yearFirst {
                XCTAssertLessThan(year.lowerBound, month.lowerBound, "\(languageCode): \(text)")
                XCTAssertLessThan(month.lowerBound, day.lowerBound, "\(languageCode): \(text)")
            } else {
                XCTAssertLessThan(month.lowerBound, day.lowerBound, "\(languageCode): \(text)")
                XCTAssertLessThan(day.lowerBound, year.lowerBound, "\(languageCode): \(text)")
            }
            XCTAssertTrue(
                manager.formattedUserVisibleDateTime(for: date).hasSuffix("23:15"),
                "\(languageCode) should preserve the product's 24-hour time rule"
            )
        }
    }

    func testUserVisibleDateHandlesLeapDayAndCrossYear() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let leapDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2028, month: 2, day: 29, hour: 12))
        )
        let yearEnd = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 12))
        )
        let nextYear = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2027, month: 1, day: 1, hour: 12))
        )

        for languageCode in ["ja", "zhHans", "zh-Hant", "enUS", "ko"] {
            let manager = LocalizationManager(savedCode: languageCode)
            let expectedLeapDay = languageCode == "enUS" ? [2, 29, 2028] : [2028, 2, 29]
            let expectedYearEnd = languageCode == "enUS" ? [12, 31, 2026] : [2026, 12, 31]
            let expectedNextYear = languageCode == "enUS" ? [1, 1, 2027] : [2027, 1, 1]
            XCTAssertEqual(
                numericDateComponents(in: manager.formattedUserVisibleDate(for: leapDay)),
                expectedLeapDay
            )
            XCTAssertEqual(
                numericDateComponents(in: manager.formattedUserVisibleDate(for: yearEnd)),
                expectedYearEnd
            )
            XCTAssertEqual(
                numericDateComponents(in: manager.formattedUserVisibleDate(for: nextYear)),
                expectedNextYear
            )
        }
    }

    func testReleaseDraftsDoNotClaimPerCategorySharingSwitches() throws {
        let files = [
            "README.md",
            "Docs/AppPrivacyAnswersDraft.md",
            "Docs/PrivacyPolicyDraft.md",
            "Docs/SupportPageDraft.md",
            "Docs/AppReviewNotesDraft.md",
            "Docs/AppStoreMetadataDraft.md",
            "Docs/AppStoreReleaseChecklist.md",
            "Docs/TestFlightSubmissionNotes.md",
            "Docs/release_review_v1.0.0_to_head.md"
        ]
        let forbiddenClaims = [
            "can separately choose",
            "owner chooses whether",
            "owner can choose",
            "所有者可分别选择",
            "個別に共有でき",
            "work-record switches are enabled",
            "shared-content switches",
            "selectable shared content",
            "共有内容を選択可能",
            "可选择共享内容",
            "공유 콘텐츠 선택 가능"
        ]

        for relativePath in files {
            let text = try String(contentsOf: sourceURL(for: relativePath), encoding: .utf8)
            for claim in forbiddenClaims {
                XCTAssertFalse(text.localizedCaseInsensitiveContains(claim), "\(relativePath) contains: \(claim)")
            }
        }
    }

    func testAdMobBuildSettingsKeepDebugReleaseAndSimulatorIDsSeparated() throws {
        let projectSwift = try String(contentsOf: sourceURL(for: "Project.swift"), encoding: .utf8)
        let projectFile = try String(contentsOf: sourceURL(for: "TimeNest.xcodeproj/project.pbxproj"), encoding: .utf8)
        let validationScript = try String(
            contentsOf: sourceURL(for: "Scripts/validate_admob_release_config.sh"),
            encoding: .utf8
        )
        let testAppID = "ca-app-pub-3940256099942544~1458002511"
        let testBannerID = "ca-app-pub-3940256099942544/2435281174"
        let productionAppID = "ca-app-pub-7907716708037277~6985657856"
        let productionBannerID = "ca-app-pub-7907716708037277/8542282103"

        XCTAssertTrue(projectSwift.contains("\"TIMENEST_ADMOB_APP_ID\": \"\(testAppID)\""))
        XCTAssertTrue(projectSwift.contains("\"TIMENEST_ADMOB_BANNER_UNIT_ID\": \"\(testBannerID)\""))
        XCTAssertTrue(projectSwift.contains("\"TIMENEST_ADMOB_APP_ID\": \"\(productionAppID)\""))
        XCTAssertTrue(projectSwift.contains("\"TIMENEST_ADMOB_BANNER_UNIT_ID\": \"\(productionBannerID)\""))
        XCTAssertTrue(projectSwift.contains("\"TIMENEST_ADMOB_APP_ID[sdk=iphonesimulator*]\": \"\(testAppID)\""))
        XCTAssertTrue(projectSwift.contains("\"TIMENEST_ADMOB_BANNER_UNIT_ID[sdk=iphonesimulator*]\": \"\(testBannerID)\""))

        XCTAssertTrue(projectFile.contains("TIMENEST_ADMOB_APP_ID = \"\(productionAppID)\";"))
        XCTAssertTrue(projectFile.contains("TIMENEST_ADMOB_BANNER_UNIT_ID = \"\(productionBannerID)\";"))
        XCTAssertTrue(projectFile.contains("\"TIMENEST_ADMOB_APP_ID[sdk=iphonesimulator*]\" = \"\(testAppID)\";"))
        XCTAssertTrue(projectFile.contains("\"TIMENEST_ADMOB_BANNER_UNIT_ID[sdk=iphonesimulator*]\" = \"\(testBannerID)\";"))
        XCTAssertTrue(projectFile.contains("TIMENEST_ADMOB_APP_ID = \"\(testAppID)\";"))
        XCTAssertTrue(projectFile.contains("TIMENEST_ADMOB_BANNER_UNIT_ID = \"\(testBannerID)\";"))

        XCTAssertTrue(validationScript.contains("Release cannot use Google's test AdMob App ID."))
        XCTAssertTrue(validationScript.contains("Release cannot use Google's test AdMob Banner Unit ID."))
    }

    private func sourceURL(for relativePath: String) throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.path != "/" {
            let candidate = url.deletingLastPathComponent().appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            url.deleteLastPathComponent()
        }
        throw NSError(domain: "LocalizationResourceParityTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find \(relativePath)"])
    }

    private func localizationKeys(in fileURL: URL) throws -> [String] {
        try localizationEntries(in: fileURL).map(\.key)
    }

    private func localizationEntries(in fileURL: URL) throws -> [(key: String, value: String)] {
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        guard let regex = try? NSRegularExpression(pattern: #"(?m)^\s*\"([^\"]+)\"\s*=\s*\"((?:\\.|[^\"])*)\"\s*;"#) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let keyRange = Range(match.range(at: 1), in: text),
                  let valueRange = Range(match.range(at: 2), in: text) else {
                return nil
            }
            return (String(text[keyRange]), String(text[valueRange]))
        }
    }

    private func placeholderSignature(in value: String) -> [String] {
        let pattern = #"%(?:\d+\$)?[-+#0 ']*\d*(?:\.\d+)?[a-zA-Z@]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.matches(in: value, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: value) else { return nil }
            return String(value[matchRange])
        }.sorted()
    }

    private func numericDateComponents(in value: String) -> [Int] {
        value
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
    }

    private func matches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let keyRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[keyRange])
        }
    }
}

final class EventSchedulingUseCaseTests: XCTestCase {
    func testDefaultEndDateIsOneHourAfterStartDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 21)))
        let end = CalendarEvent.defaultEndDate(for: start, isAllDay: false)

        XCTAssertEqual(end, calendar.date(byAdding: .hour, value: 1, to: start))
    }

    func testEndDateBeforeStartDateFailsToSave() async throws {
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository, notificationScheduler: EventNotificationSchedulerSpy())
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 21)))
        let event = makeEvent(startDate: start, endDate: start)

        do {
            try await useCase.createEvent(event)
            XCTFail("Expected invalid date range to fail")
        } catch EventUseCaseError.invalidDateRange {
            let storedEvent = try await repository.event(id: event.id)
            XCTAssertNil(storedEvent)
        }
    }

    func testReminderOffsetCanBeSavedAndRead() async throws {
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository, notificationScheduler: EventNotificationSchedulerSpy())
        let start = Date().addingTimeInterval(3600)
        let event = makeEvent(startDate: start, reminderOffsetMinutes: 10)

        try await useCase.createEvent(event)

        let storedEvent = try await repository.event(id: event.id)
        let savedEvent = try XCTUnwrap(storedEvent)
        XCTAssertEqual(savedEvent.reminderOffsetMinutes, 10)
        XCTAssertNotNil(savedEvent.notificationID)
    }

    func testEventWithoutReminderDoesNotInvokeNotificationScheduler() async throws {
        let scheduler = EventNotificationSchedulerSpy()
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(
            repository: repository,
            notificationScheduler: scheduler
        )
        let event = makeEvent(
            startDate: Date().addingTimeInterval(3_600),
            reminderOffsetMinutes: nil
        )

        let result = try await useCase.createEvent(event)

        XCTAssertEqual(result, .noReminder)
        XCTAssertTrue(scheduler.scheduledEvents.isEmpty)
        XCTAssertTrue(scheduler.cancelledIDs.isEmpty)
    }

    func testThrowingSchedulerAdapterPreservesOriginalFailureCause() async {
        let scheduler = ThrowingEventNotificationScheduler()
        let event = makeEvent(
            startDate: Date().addingTimeInterval(3_600),
            reminderOffsetMinutes: 10
        )

        let result = await scheduler.scheduleEventNotificationResult(event: event)

        guard case .failedWithCause(let failure) = result else {
            return XCTFail("Expected typed scheduling failure")
        }
        XCTAssertTrue(failure.underlyingError is NotificationRestorationFailure)
    }

    func testUpdatingReminderReplacesOldNotificationID() async throws {
        let scheduler = EventNotificationSchedulerSpy()
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository, notificationScheduler: scheduler)
        let start = Date().addingTimeInterval(3600)
        var event = makeEvent(startDate: start, reminderOffsetMinutes: 10)
        try await useCase.createEvent(event)
        let createdEvent = try await repository.event(id: event.id)
        let firstID = try XCTUnwrap(createdEvent?.notificationID)
        var callbackCount = 0
        useCase.onEventsChanged = { callbackCount += 1 }

        event.notificationID = firstID
        event.reminderOffsetMinutes = 30
        event.updatedAt = Date()
        try await useCase.updateEvent(event)

        let storedUpdatedEvent = try await repository.event(id: event.id)
        let updatedEvent = try XCTUnwrap(storedUpdatedEvent)
        XCTAssertNotEqual(updatedEvent.notificationID, firstID)
        XCTAssertEqual(scheduler.cancelledIDs, [firstID])
        XCTAssertEqual(callbackCount, 1)
    }

    func testDeletingEventCancelsNotification() async throws {
        let scheduler = EventNotificationSchedulerSpy()
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository, notificationScheduler: scheduler)
        let event = makeEvent(startDate: Date().addingTimeInterval(3600), reminderOffsetMinutes: 10)
        try await useCase.createEvent(event)
        let createdEvent = try await repository.event(id: event.id)
        let notificationID = try XCTUnwrap(createdEvent?.notificationID)

        try await useCase.deleteEvent(id: event.id)

        let deletedEvent = try await repository.event(id: event.id)
        XCTAssertEqual(scheduler.cancelledIDs, [notificationID])
        XCTAssertNil(deletedEvent)
    }

    func testCreateFailureCancelsNewlyScheduledNotification() async throws {
        let scheduler = EventNotificationSchedulerSpy()
        scheduler.queuedResults = [.scheduled("new-notification")]
        let repository = FailingMutationEventRepository(failingOperation: .create)
        let useCase = EventUseCase(repository: repository, notificationScheduler: scheduler)
        let event = makeEvent(
            startDate: Date().addingTimeInterval(3_600),
            reminderOffsetMinutes: 10
        )

        do {
            try await useCase.createEvent(event)
            XCTFail("Expected repository create to fail")
        } catch EventRepositoryMutationFailure.create {
            let storedEvent = try await repository.event(id: event.id)
            XCTAssertEqual(scheduler.cancelledIDs, ["new-notification"])
            XCTAssertNil(storedEvent)
        }
    }

    func testDeleteFailureKeepsExistingNotification() async throws {
        var event = makeEvent(
            startDate: Date().addingTimeInterval(3_600),
            reminderOffsetMinutes: 10
        )
        event.notificationID = "existing-notification"
        let scheduler = EventNotificationSchedulerSpy()
        let repository = FailingMutationEventRepository(
            events: [event],
            failingOperation: .delete
        )
        let useCase = EventUseCase(repository: repository, notificationScheduler: scheduler)

        do {
            try await useCase.deleteEvent(id: event.id)
            XCTFail("Expected repository delete to fail")
        } catch EventRepositoryMutationFailure.delete {
            let storedEvent = try await repository.event(id: event.id)
            XCTAssertTrue(scheduler.cancelledIDs.isEmpty)
            XCTAssertEqual(storedEvent, event)
        }
    }

    func testUpdateFailureSurfacesNotificationRestorationFailure() async throws {
        var oldEvent = makeEvent(
            startDate: Date().addingTimeInterval(3_600),
            reminderOffsetMinutes: 10
        )
        oldEvent.notificationID = "existing-notification"
        var updatedEvent = oldEvent
        updatedEvent.reminderOffsetMinutes = 30
        updatedEvent.updatedAt = Date()

        let scheduler = EventNotificationSchedulerSpy()
        let notificationFailure = EventNotificationScheduleFailure(
            underlyingError: NotificationRestorationFailure.injected
        )
        scheduler.queuedResults = [
            .scheduled("existing-notification"),
            .failedWithCause(notificationFailure)
        ]
        let repository = FailingMutationEventRepository(
            events: [oldEvent],
            failingOperation: .update
        )
        let useCase = EventUseCase(repository: repository, notificationScheduler: scheduler)

        do {
            try await useCase.updateEvent(updatedEvent)
            XCTFail("Expected repository update and restoration to fail")
        } catch let error as EventNotificationCompensationError {
            let storedEvent = try await repository.event(id: oldEvent.id)
            XCTAssertTrue(error.primaryError is EventRepositoryMutationFailure)
            guard case .failedWithCause(let preservedFailure) = error.compensationResult else {
                return XCTFail("Expected typed notification restoration failure")
            }
            XCTAssertTrue(
                preservedFailure.underlyingError is NotificationRestorationFailure
            )
            XCTAssertTrue(error.localizedDescription.contains("notification restoration: failed"))
            XCTAssertEqual(scheduler.scheduledEvents.count, 2)
            XCTAssertEqual(storedEvent, oldEvent)
        }
    }

    func testUpdateFailureRestoresOldNotificationAndRethrowsRepositoryError() async throws {
        var oldEvent = makeEvent(
            startDate: Date().addingTimeInterval(3_600),
            reminderOffsetMinutes: 10
        )
        oldEvent.notificationID = "existing-notification"
        var updatedEvent = oldEvent
        updatedEvent.reminderOffsetMinutes = 30
        updatedEvent.updatedAt = Date()

        let scheduler = EventNotificationSchedulerSpy()
        scheduler.queuedResults = [
            .scheduled("existing-notification"),
            .scheduled("existing-notification")
        ]
        let repository = FailingMutationEventRepository(
            events: [oldEvent],
            failingOperation: .update
        )
        let useCase = EventUseCase(repository: repository, notificationScheduler: scheduler)

        do {
            try await useCase.updateEvent(updatedEvent)
            XCTFail("Expected repository update to fail")
        } catch EventRepositoryMutationFailure.update {
            let storedEvent = try await repository.event(id: oldEvent.id)
            XCTAssertEqual(scheduler.scheduledEvents.count, 2)
            XCTAssertTrue(scheduler.cancelledIDs.isEmpty)
            XCTAssertEqual(storedEvent, oldEvent)
        }
    }

    func testNoReminderToReminderUpdateFailureCancelsNewNotificationOnlyOnce() async throws {
        let oldEvent = makeEvent(
            startDate: Date().addingTimeInterval(3_600),
            reminderOffsetMinutes: nil
        )
        var updatedEvent = oldEvent
        updatedEvent.reminderOffsetMinutes = 10
        updatedEvent.updatedAt = Date()
        let scheduler = EventNotificationSchedulerSpy()
        scheduler.queuedResults = [.scheduled("new-notification")]
        let repository = FailingMutationEventRepository(
            events: [oldEvent],
            failingOperation: .update
        )
        let useCase = EventUseCase(repository: repository, notificationScheduler: scheduler)
        var callbackCount = 0
        useCase.onEventsChanged = { callbackCount += 1 }

        do {
            try await useCase.updateEvent(updatedEvent)
            XCTFail("The repository update must fail")
        } catch EventRepositoryMutationFailure.update {}

        let storedEvent = try await repository.event(id: oldEvent.id)
        XCTAssertEqual(scheduler.cancelledIDs, ["new-notification"])
        XCTAssertEqual(scheduler.scheduledEvents.count, 1)
        XCTAssertEqual(callbackCount, 0)
        XCTAssertEqual(storedEvent, oldEvent)
    }

    func testReminderToNoReminderUpdateFailureKeepsOldNotification() async throws {
        var oldEvent = makeEvent(
            startDate: Date().addingTimeInterval(3_600),
            reminderOffsetMinutes: 10
        )
        oldEvent.notificationID = "old-notification"
        var updatedEvent = oldEvent
        updatedEvent.reminderOffsetMinutes = nil
        updatedEvent.updatedAt = Date()
        let scheduler = EventNotificationSchedulerSpy()
        let repository = FailingMutationEventRepository(
            events: [oldEvent],
            failingOperation: .update
        )
        let useCase = EventUseCase(repository: repository, notificationScheduler: scheduler)
        var callbackCount = 0
        useCase.onEventsChanged = { callbackCount += 1 }

        do {
            try await useCase.updateEvent(updatedEvent)
            XCTFail("The repository update must fail")
        } catch EventRepositoryMutationFailure.update {}

        let storedEvent = try await repository.event(id: oldEvent.id)
        XCTAssertTrue(scheduler.cancelledIDs.isEmpty)
        XCTAssertTrue(scheduler.scheduledEvents.isEmpty)
        XCTAssertEqual(callbackCount, 0)
        XCTAssertEqual(storedEvent, oldEvent)
    }

    func testReminderIdentifierChangeFailureCancelsNewAndRestoresExactOldContent() async throws {
        var oldEvent = makeEvent(
            startDate: Date().addingTimeInterval(3_600),
            reminderOffsetMinutes: 10
        )
        oldEvent.notificationID = "old-notification"
        oldEvent.note = "Original reminder content"
        var updatedEvent = oldEvent
        updatedEvent.note = "Updated reminder content"
        updatedEvent.reminderOffsetMinutes = 30
        updatedEvent.updatedAt = Date()
        let scheduler = EventNotificationSchedulerSpy()
        scheduler.queuedResults = [
            .scheduled("new-notification"),
            .scheduled("old-notification")
        ]
        let repository = FailingMutationEventRepository(
            events: [oldEvent],
            failingOperation: .update
        )
        let useCase = EventUseCase(repository: repository, notificationScheduler: scheduler)
        var callbackCount = 0
        useCase.onEventsChanged = { callbackCount += 1 }

        do {
            try await useCase.updateEvent(updatedEvent)
            XCTFail("The repository update must fail")
        } catch EventRepositoryMutationFailure.update {}

        let storedEvent = try await repository.event(id: oldEvent.id)
        XCTAssertEqual(scheduler.cancelledIDs, ["new-notification"])
        XCTAssertEqual(scheduler.scheduledEvents, [updatedEvent, oldEvent])
        XCTAssertEqual(callbackCount, 0)
        XCTAssertEqual(storedEvent, oldEvent)
    }

    func testAllDayEventSaveNormalizesToFullDayRange() async throws {
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository, notificationScheduler: EventNotificationSchedulerSpy())
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10)))
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))
        let event = makeEvent(startDate: start, endDate: end, isAllDay: true)

        try await useCase.createEvent(event)

        let storedEvent = try await repository.event(id: event.id)
        let savedEvent = try XCTUnwrap(storedEvent)
        XCTAssertTrue(savedEvent.isAllDay)
        XCTAssertEqual(savedEvent.startDate, start)
        XCTAssertEqual(savedEvent.endDate, end)
    }

    private func makeEvent(
        startDate: Date,
        endDate: Date? = nil,
        isAllDay: Bool = false,
        reminderOffsetMinutes: Int? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: UUID(),
            title: "Test Event",
            note: nil,
            startDate: startDate,
            endDate: endDate ?? CalendarEvent.defaultEndDate(for: startDate, isAllDay: isAllDay),
            isAllDay: isAllDay,
            categoryID: nil,
            recurrenceRule: .none,
            reminderTemplateID: nil,
            reminderOffsetMinutes: reminderOffsetMinutes,
            notificationID: nil,
            importSource: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

final class EventNotificationSchedulerSpy: LocalNotificationScheduling {
    private(set) var scheduledEvents: [CalendarEvent] = []
    private(set) var cancelledIDs: [String] = []
    var isAuthorized = true
    var queuedResults: [EventNotificationScheduleResult] = []

    func requestAuthorizationIfNeeded() async -> Bool {
        isAuthorized
    }

    func scheduleEventNotification(event: CalendarEvent) async throws -> String? {
        await scheduleEventNotificationResult(event: event).notificationID
    }

    func scheduleEventNotificationResult(event: CalendarEvent) async -> EventNotificationScheduleResult {
        scheduledEvents.append(event)
        if !queuedResults.isEmpty {
            return queuedResults.removeFirst()
        }
        guard isAuthorized else { return .failed }
        return .scheduled("notification-\(scheduledEvents.count)")
    }

    func cancelNotification(id: String) {
        cancelledIDs.append(id)
    }

    func scheduleDailyScheduleCheck(hour: Int, minute: Int) async {}

    func cancelDailyScheduleCheck() {}
}

private final class ThrowingEventNotificationScheduler: LocalNotificationScheduling {
    func requestAuthorizationIfNeeded() async -> Bool {
        true
    }

    func scheduleEventNotification(event: CalendarEvent) async throws -> String? {
        throw NotificationRestorationFailure.injected
    }

    func cancelNotification(id: String) {}
    func scheduleDailyScheduleCheck(hour: Int, minute: Int) async {}
    func cancelDailyScheduleCheck() {}
}

private enum EventRepositoryMutationFailure: Error {
    case create
    case update
    case delete
}

private enum NotificationRestorationFailure: Error {
    case injected
}

private actor FailingMutationEventRepository: EventRepository {
    private var storedEvents: [UUID: CalendarEvent]
    private let failingOperation: EventRepositoryMutationFailure

    init(
        events: [CalendarEvent] = [],
        failingOperation: EventRepositoryMutationFailure
    ) {
        storedEvents = Dictionary(
            uniqueKeysWithValues: events.map { ($0.id, $0) }
        )
        self.failingOperation = failingOperation
    }

    func create(_ event: CalendarEvent) async throws {
        if case .create = failingOperation {
            throw EventRepositoryMutationFailure.create
        }
        storedEvents[event.id] = event
    }

    func createBatch(
        _ events: [CalendarEvent],
        ifUnchanged expectedEvents: [CalendarEvent]
    ) async throws {
        if case .create = failingOperation {
            throw EventRepositoryMutationFailure.create
        }
        events.forEach { storedEvents[$0.id] = $0 }
    }

    func applyBatch(
        upserting events: [CalendarEvent],
        deleting eventsToDelete: [CalendarEvent],
        ifUnchanged expectedEvents: [CalendarEvent]
    ) async throws {
        try EventRepositoryBatchValidator.validateApplyBatch(
            currentEvents: Array(storedEvents.values),
            upserting: events,
            deleting: eventsToDelete,
            ifUnchanged: expectedEvents
        )
        var updated = storedEvents
        for event in events {
            updated[event.id] = event
        }
        for event in eventsToDelete {
            updated.removeValue(forKey: event.id)
        }
        storedEvents = updated
    }

    func update(_ event: CalendarEvent) async throws {
        if case .update = failingOperation {
            throw EventRepositoryMutationFailure.update
        }
        storedEvents[event.id] = event
    }

    func delete(id: UUID) async throws {
        if case .delete = failingOperation {
            throw EventRepositoryMutationFailure.delete
        }
        storedEvents.removeValue(forKey: id)
    }

    func deleteBatch(_ expectedEvents: [CalendarEvent]) async throws {
        for event in expectedEvents {
            try await delete(id: event.id)
        }
    }

    func events(in range: DateInterval) async throws -> [CalendarEvent] {
        Array(storedEvents.values)
    }

    func event(id: UUID) async throws -> CalendarEvent? {
        storedEvents[id]
    }

    func reassignEvents(from sourceCalendarID: UUID, to targetCalendarID: UUID) async throws {
        for (id, var event) in storedEvents where event.calendarID == sourceCalendarID {
            event.calendarID = targetCalendarID
            storedEvents[id] = event
        }
    }
}
