import XCTest
@testable import TimeNest

final class TraditionalCalendarPreferencesTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "TraditionalCalendarPreferencesTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    func testMissingKeysAreFalseForFreshInstallAndExistingUser() {
        defaults.set("legacy-user-value", forKey: "unrelated.existing.preference")

        let preferences = TraditionalCalendarPreferences(defaults: defaults)

        XCTAssertFalse(preferences.showLunarCalendar)
        XCTAssertFalse(preferences.showRokuyo)
        XCTAssertFalse(preferences.showSolarTerms)
        XCTAssertNil(defaults.object(forKey: TraditionalCalendarPreferences.showLunarCalendarKey))
        XCTAssertNil(defaults.object(forKey: TraditionalCalendarPreferences.showRokuyoKey))
        XCTAssertNil(defaults.object(forKey: TraditionalCalendarPreferences.showSolarTermsKey))
    }

    func testEachSwitchIsIndependent() {
        let cases: [(String, KeyPath<TraditionalCalendarPreferences, Bool>)] = [
            (
                TraditionalCalendarPreferences.showLunarCalendarKey,
                \.showLunarCalendar
            ),
            (
                TraditionalCalendarPreferences.showRokuyoKey,
                \.showRokuyo
            ),
            (
                TraditionalCalendarPreferences.showSolarTermsKey,
                \.showSolarTerms
            )
        ]

        for (enabledKey, enabledValue) in cases {
            defaults.removePersistentDomain(forName: suiteName)
            defaults.set(true, forKey: enabledKey)

            let preferences = TraditionalCalendarPreferences(defaults: defaults)
            XCTAssertTrue(preferences[keyPath: enabledValue])
            XCTAssertEqual(
                [
                    preferences.showLunarCalendar,
                    preferences.showRokuyo,
                    preferences.showSolarTerms
                ].filter { $0 }.count,
                1
            )
        }
    }

    func testValuesPersistWhenPreferencesAreRecreated() throws {
        defaults.set(true, forKey: TraditionalCalendarPreferences.showLunarCalendarKey)
        defaults.set(false, forKey: TraditionalCalendarPreferences.showRokuyoKey)
        defaults.set(true, forKey: TraditionalCalendarPreferences.showSolarTermsKey)

        let relaunchedDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let preferences = TraditionalCalendarPreferences(defaults: relaunchedDefaults)

        XCTAssertTrue(preferences.showLunarCalendar)
        XCTAssertFalse(preferences.showRokuyo)
        XCTAssertTrue(preferences.showSolarTerms)
    }
}

final class TraditionalCalendarProviderTests: XCTestCase {
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    private let auckland = TimeZone(identifier: "Pacific/Auckland")!
    private lazy var provider = TraditionalCalendarProvider(
        localization: LocalizationManager(savedCode: "zhHans")
    )

    func testLunarFirstDayFifteenthSpringFestivalAndYearBoundaries() throws {
        // Expected lunar dates come from Hong Kong Observatory's independent
        // 2023 and 2024 Gregorian-Lunar Calendar Conversion Tables.
        XCTAssertEqual(
            provider.lunarDate(
                for: DateOnly(year: 2024, month: 2, day: 10),
                timeZone: tokyo
            ),
            TraditionalLunarDate(month: 1, day: 1, isLeapMonth: false)
        )
        XCTAssertEqual(
            provider.lunarDate(
                for: DateOnly(year: 2024, month: 2, day: 24),
                timeZone: tokyo
            ),
            TraditionalLunarDate(month: 1, day: 15, isLeapMonth: false)
        )
        XCTAssertEqual(
            provider.lunarDate(
                for: DateOnly(year: 2023, month: 12, day: 31),
                timeZone: tokyo
            ),
            TraditionalLunarDate(month: 11, day: 19, isLeapMonth: false)
        )
        XCTAssertEqual(
            provider.lunarDate(
                for: DateOnly(year: 2024, month: 1, day: 1),
                timeZone: tokyo
            ),
            TraditionalLunarDate(month: 11, day: 20, isLeapMonth: false)
        )
        XCTAssertEqual(
            provider.lunarDate(
                for: DateOnly(year: 2024, month: 2, day: 9),
                timeZone: tokyo
            ),
            TraditionalLunarDate(month: 12, day: 30, isLeapMonth: false)
        )
    }

    func testKnownLeapMonthAndCompactChineseText() throws {
        let leapStart = DateOnly(year: 2023, month: 3, day: 22)
        let leapSecondDay = DateOnly(year: 2023, month: 3, day: 23)
        XCTAssertEqual(
            provider.lunarDate(for: leapStart, timeZone: tokyo),
            TraditionalLunarDate(month: 2, day: 1, isLeapMonth: true)
        )

        let displays = provider.displays(
            for: [
                DateOnly(year: 2024, month: 2, day: 10),
                DateOnly(year: 2024, month: 2, day: 24),
                leapStart,
                leapSecondDay
            ],
            preferences: TraditionalCalendarPreferences(
                showLunarCalendar: true,
                showRokuyo: false,
                showSolarTerms: false
            ),
            language: .zhHans,
            timeZone: tokyo
        )

        XCTAssertEqual(displays[DateOnly(year: 2024, month: 2, day: 10)]?.lunarText, "正月")
        XCTAssertEqual(displays[DateOnly(year: 2024, month: 2, day: 24)]?.lunarText, "十五")
        XCTAssertEqual(displays[leapStart]?.lunarText, "闰二月")
        XCTAssertEqual(displays[leapSecondDay]?.lunarText, "闰初二")
    }

    func testLunarDateUsesRequestedLocalTimeZoneAtDateBoundary() {
        let date = DateOnly(year: 2024, month: 2, day: 10)
        let expected = TraditionalLunarDate(month: 1, day: 1, isLeapMonth: false)

        XCTAssertEqual(provider.lunarDate(for: date, timeZone: tokyo), expected)
        XCTAssertEqual(provider.lunarDate(for: date, timeZone: losAngeles), expected)
    }

    func testSixIndependentKnownDatesCoverEveryRokuyo() throws {
        // 2024-02-10 is independently published as lunar 1/1 and Sensho.
        // The following five dates use the published Rokuyo order for lunar
        // days 2...6; expected values are intentionally hard-coded.
        let samples: [(DateOnly, TraditionalRokuyo)] = [
            (DateOnly(year: 2024, month: 2, day: 10), .sensho),
            (DateOnly(year: 2024, month: 2, day: 11), .tomobiki),
            (DateOnly(year: 2024, month: 2, day: 12), .senbu),
            (DateOnly(year: 2024, month: 2, day: 13), .butsumetsu),
            (DateOnly(year: 2024, month: 2, day: 14), .taian),
            (DateOnly(year: 2024, month: 2, day: 15), .shakko)
        ]

        for (date, expected) in samples {
            let lunar = try XCTUnwrap(provider.lunarDate(for: date, timeZone: tokyo))
            XCTAssertEqual(provider.rokuyo(for: lunar), expected, date.id)
        }
    }

    func testFiveRequestedSolarTermsMatchIndependent2026Ephemeris() throws {
        // Expected UTC instants are converted from the National Astronomical
        // Observatory of Japan's published JST values for 2026. This provider
        // is date-label oriented, so a 20-minute bound protects the intended
        // precision while remaining stricter than a local-date comparison.
        let samples: [(TraditionalSolarTerm, Date)] = [
            (
                .springCommences,
                try utcDate(year: 2026, month: 2, day: 3, hour: 20, minute: 2)
            ),
            (
                .springEquinox,
                try utcDate(year: 2026, month: 3, day: 20, hour: 14, minute: 46)
            ),
            (
                .summerSolstice,
                try utcDate(year: 2026, month: 6, day: 21, hour: 8, minute: 25)
            ),
            (
                .autumnEquinox,
                try utcDate(year: 2026, month: 9, day: 23, hour: 0, minute: 5)
            ),
            (
                .winterSolstice,
                try utcDate(year: 2026, month: 12, day: 21, hour: 20, minute: 50)
            )
        ]

        for (term, expected) in samples {
            let actual = try XCTUnwrap(provider.solarTermInstant(term, year: 2026))
            XCTAssertLessThanOrEqual(abs(actual.timeIntervalSince(expected)), 20 * 60)
        }
    }

    func testSolarTermDatesFollowDeviceTimeZoneAcrossMidnight() {
        XCTAssertEqual(
            provider.solarTerm(
                on: DateOnly(year: 2026, month: 3, day: 20),
                timeZone: tokyo
            ),
            .springEquinox
        )
        XCTAssertNil(
            provider.solarTerm(
                on: DateOnly(year: 2026, month: 3, day: 20),
                timeZone: auckland
            )
        )
        XCTAssertEqual(
            provider.solarTerm(
                on: DateOnly(year: 2026, month: 3, day: 21),
                timeZone: auckland
            ),
            .springEquinox
        )
    }

    func testSolarTermSupportedRangeMinimumMaximumAndSafeFallback() {
        // Independent HKO conversion tables place these boundary-year terms
        // on 1901-02-04 and 2099-12-21.
        XCTAssertEqual(
            provider.solarTerm(
                on: DateOnly(year: 1901, month: 2, day: 4),
                timeZone: tokyo
            ),
            .springCommences
        )
        XCTAssertEqual(
            provider.solarTerm(
                on: DateOnly(year: 2099, month: 12, day: 21),
                timeZone: tokyo
            ),
            .winterSolstice
        )
        XCTAssertNil(
            provider.solarTerm(
                on: DateOnly(year: 1900, month: 2, day: 4),
                timeZone: tokyo
            )
        )
        XCTAssertNil(
            provider.solarTerm(
                on: DateOnly(year: 2100, month: 12, day: 21),
                timeZone: tokyo
            )
        )
    }

    func testDisplayOptionsDoNotAssembleDisabledComponents() {
        let date = DateOnly(year: 2026, month: 2, day: 4)
        let options: [TraditionalCalendarPreferences] = [
            .init(showLunarCalendar: true, showRokuyo: false, showSolarTerms: false),
            .init(showLunarCalendar: false, showRokuyo: true, showSolarTerms: false),
            .init(showLunarCalendar: false, showRokuyo: false, showSolarTerms: true)
        ]

        let lunar = provider.displays(
            for: [date],
            preferences: options[0],
            language: .ja,
            timeZone: tokyo
        )[date]
        XCTAssertNotNil(lunar?.lunarText)
        XCTAssertNil(lunar?.rokuyoText)
        XCTAssertNil(lunar?.solarTermText)

        let rokuyo = provider.displays(
            for: [date],
            preferences: options[1],
            language: .ja,
            timeZone: tokyo
        )[date]
        XCTAssertNil(rokuyo?.lunarText)
        XCTAssertNotNil(rokuyo?.rokuyoText)
        XCTAssertNil(rokuyo?.solarTermText)

        let solarTerm = provider.displays(
            for: [date],
            preferences: options[2],
            language: .ja,
            timeZone: tokyo
        )[date]
        XCTAssertNil(solarTerm?.lunarText)
        XCTAssertNil(solarTerm?.rokuyoText)
        XCTAssertEqual(solarTerm?.solarTermText, "立春")
    }

    func testLocalizedTraditionalCalendarListsHaveExpectedCountsInFiveLanguages() {
        let manager = LocalizationManager(savedCode: "enUS")
        let languages: [DisplayLanguage] = [.ja, .zhHans, .zhHant, .enUS, .ko]

        for language in languages {
            XCTAssertEqual(items(.traditionalCalendarLunarMonthNames, language, manager).count, 12)
            XCTAssertEqual(items(.traditionalCalendarLunarDayNames, language, manager).count, 30)
            XCTAssertEqual(items(.traditionalCalendarRokuyoNames, language, manager).count, 6)
            XCTAssertEqual(items(.traditionalCalendarSolarTermNames, language, manager).count, 24)
        }

        XCTAssertTrue(
            items(.traditionalCalendarLunarDayNames, .enUS, manager)
                .allSatisfy { $0.count <= 3 }
        )
        XCTAssertTrue(
            items(.traditionalCalendarRokuyoNames, .enUS, manager)
                .allSatisfy { $0.count <= 5 }
        )
        XCTAssertTrue(
            items(.traditionalCalendarSolarTermNames, .enUS, manager)
                .allSatisfy { $0.count <= 6 }
        )
        XCTAssertTrue(
            items(.traditionalCalendarRokuyoNames, .ko, manager)
                .allSatisfy { $0.count == 2 }
        )
    }

    private func utcDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        return try XCTUnwrap(
            calendar.date(
                from: DateComponents(
                    timeZone: calendar.timeZone,
                    year: year,
                    month: month,
                    day: day,
                    hour: hour,
                    minute: minute
                )
            )
        )
    }

    private func items(
        _ key: LocalizedString,
        _ language: DisplayLanguage,
        _ manager: LocalizationManager
    ) -> [Substring] {
        manager.localized(key, language: language)
            .split(separator: "|", omittingEmptySubsequences: false)
    }
}

final class TraditionalCalendarMonthGridTests: XCTestCase {
    func testMonthGridCarriesOnlyEnabledTraditionalCalendarDisplay() async throws {
        let useCase = CalendarDisplayUseCase(
            holidayUseCase: HolidayUseCase(
                cacheRepository: InMemoryHolidayEventCacheRepository()
            ),
            localizationUseCase: CalendarLocalizationUseCase(),
            eventUseCase: EventUseCase(repository: InMemoryEventRepository()),
            traditionalCalendarProvider: TraditionalCalendarProvider(
                localization: LocalizationManager(savedCode: "zhHans")
            )
        )
        let enabledSetting = CalendarDisplaySetting(
            displayLanguage: .zhHans,
            selectedHolidayRegions: [],
            weekStartPolicy: .sunday,
            showLunarCalendar: true,
            showRokuyo: true,
            showSolarTerms: true
        )

        let enabledGrid = try await useCase.monthGrid(
            year: 2026,
            month: 2,
            setting: enabledSetting
        )
        let springCommences = try XCTUnwrap(
            enabledGrid.days.first {
                $0.date == DateOnly(year: 2026, month: 2, day: 4)
            }
        )
        XCTAssertNotNil(springCommences.traditionalCalendar.lunarText)
        XCTAssertNotNil(springCommences.traditionalCalendar.rokuyoText)
        XCTAssertEqual(springCommences.traditionalCalendar.solarTermText, "立春")

        let disabledSetting = CalendarDisplaySetting(
            displayLanguage: .zhHans,
            selectedHolidayRegions: [],
            weekStartPolicy: .sunday,
            showLunarCalendar: false
        )
        let disabledGrid = try await useCase.monthGrid(
            year: 2026,
            month: 2,
            setting: disabledSetting
        )
        XCTAssertTrue(disabledGrid.days.allSatisfy(\.traditionalCalendar.isEmpty))
    }
}
