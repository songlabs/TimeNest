import XCTest

final class TraditionalCalendarUITests: XCTestCase {
    private let targetDateID = "2026-2-4"
    private let successfulAttributionImageURL =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testMonthSecondaryModesAreMutuallyExclusiveWithoutChangingCellHeight() {
        let app = launchApp(language: "ja", mode: "none")
        let dayCell = element(in: app, identifier: "calendar.day.\(targetDateID)")
        XCTAssertTrue(dayCell.waitForExistence(timeout: 10))
        let originalCellHeight = dayCell.frame.height

        assertDisplayMode("none", in: app)
        attachScreenshot(named: "month-secondary-none", app: app)

        for (mode, title) in [
            ("weather", "天気"),
            ("none", "表示しない"),
            ("weather", "天気"),
            ("lunar", "旧暦"),
            ("rokuyo", "六曜"),
            ("solarTerm", "二十四節気"),
            ("none", "表示しない")
        ] {
            selectMonthMode(title: title, in: app)
            assertDisplayMode(mode, in: app)
            XCTAssertEqual(dayCell.frame.height, originalCellHeight, accuracy: 0.5, mode)
            attachScreenshot(named: "month-secondary-\(mode)", app: app)
        }
    }

    func testFiveLanguagesAndHolidayCoexistOnSmallScreen() {
        let expectedSolarTerms = [
            "ja": "春分",
            "zhHans": "春分",
            "zh-Hant": "春分",
            "enUS": "SprEq",
            "ko": "춘분"
        ]
        let dateID = "2026-3-20"

        for language in ["ja", "zhHans", "zh-Hant", "enUS", "ko"] {
            let app = launchApp(
                language: language,
                date: "2026-03-20",
                mode: "solarTerm"
            )
            let dayCell = element(in: app, identifier: "calendar.day.\(dateID)")
            XCTAssertTrue(dayCell.waitForExistence(timeout: 10), language)

            let solarTerm = traditionalLabel("solarTerm", dateID: dateID, in: app)
            XCTAssertTrue(solarTerm.waitForExistence(timeout: 8), language)
            XCTAssertEqual(solarTerm.label, expectedSolarTerms[language], language)
            XCTAssertFalse(solarTerm.label.contains("traditional_calendar."), language)
            XCTAssertTrue(dayCell.frame.insetBy(dx: -1, dy: -1).contains(solarTerm.frame), language)
            XCTAssertFalse(traditionalLabel("lunar", dateID: dateID, in: app).exists, language)
            XCTAssertFalse(traditionalLabel("rokuyo", dateID: dateID, in: app).exists, language)
            XCTAssertFalse(weatherIcon(dateID: dateID, in: app).exists, language)

            let holiday = app.staticTexts["春分の日"]
            XCTAssertTrue(holiday.waitForExistence(timeout: 8), language)
            XCTAssertFalse(holiday.frame.intersects(solarTerm.frame), language)
            attachScreenshot(named: "traditional-calendar-\(language)-small-screen", app: app)
            app.terminate()
        }
    }

    func testWeekWeatherIsVisibleInFiveLanguages() {
        for language in ["ja", "zhHans", "zh-Hant", "enUS", "ko"] {
            let app = launchApp(language: language, mode: "weather")
            app.buttons["calendar.mode.week"].tap()

            let weatherCell = element(in: app, identifier: "weather.week.\(targetDateID)")
            let temperature = app.staticTexts["weather.week.temperature.\(targetDateID)"]
            let precipitation = element(
                in: app,
                identifier: "weather.week.precipitation.\(targetDateID)"
            )
            XCTAssertTrue(weatherCell.waitForExistence(timeout: 8), language)
            XCTAssertTrue(temperature.waitForExistence(timeout: 8), language)
            XCTAssertTrue(precipitation.waitForExistence(timeout: 8), language)
            assertIsOnScreen(weatherCell, in: app, language)
            assertIsOnScreen(temperature, in: app, language)
            assertIsOnScreen(precipitation, in: app, language)
            XCTAssertTrue(
                element(in: app, identifier: "weather.header.attribution").exists,
                language
            )
            attachScreenshot(named: "week-weather-\(language)", app: app)
            app.terminate()
        }
    }

    func testWeatherMonthWeekDayAndAttributionInLightAndDark() {
        let today = launchDate(offsetFromToday: 0)
        let visibleWeatherDateIDs = (0...3).map(dateID(offsetFromToday:))

        for theme in ["light", "dark"] {
            let app = launchApp(
                language: "ja",
                date: today,
                mode: "weather",
                theme: theme
            )
            for dateID in visibleWeatherDateIDs {
                let icon = weatherIcon(dateID: dateID, in: app)
                XCTAssertTrue(icon.waitForExistence(timeout: 8), "\(theme): \(dateID)")
                XCTAssertGreaterThanOrEqual(icon.frame.width, 16, "\(theme): \(dateID)")
                XCTAssertGreaterThanOrEqual(icon.frame.height, 16, "\(theme): \(dateID)")
            }
            XCTAssertTrue(
                element(in: app, identifier: "weather.header.attribution")
                    .waitForExistence(timeout: 8)
            )
            attachScreenshot(named: "weather-month-\(theme)", app: app)

            app.buttons["calendar.mode.week"].tap()
            let weekWeather = [
                "weather.week.\(visibleWeatherDateIDs[0])",
                "weather.week.symbol.\(visibleWeatherDateIDs[0])",
                "weather.week.temperature.\(visibleWeatherDateIDs[0])",
                "weather.week.precipitation.\(visibleWeatherDateIDs[0])"
            ].map { element(in: app, identifier: $0) }
            for element in weekWeather {
                XCTAssertTrue(element.waitForExistence(timeout: 8), theme)
                assertIsOnScreen(element, in: app, theme)
            }
            XCTAssertTrue(element(in: app, identifier: "weather.header.attribution").exists)
            attachScreenshot(named: "weather-week-\(theme)", app: app)

            app.buttons["calendar.mode.day"].tap()
            let dayWeather = [
                "weather.day.section",
                "weather.day.symbol",
                "weather.day.temperature",
                "weather.day.high",
                "weather.day.low",
                "weather.day.precipitation",
                "weather.day.wind",
                "weather.day.hourly",
                "weather.attribution"
            ].map { element(in: app, identifier: $0) }
            for element in dayWeather {
                XCTAssertTrue(element.waitForExistence(timeout: 8), theme)
                assertIsOnScreen(element, in: app, theme)
            }
            let legalLink = element(in: app, identifier: "weather.attribution.legal")
            XCTAssertTrue(legalLink.waitForExistence(timeout: 8), theme)
            XCTAssertTrue(legalLink.isHittable, theme)
            XCTAssertTrue(element(in: app, identifier: "weather.attribution").exists)
            attachScreenshot(named: "weather-day-\(theme)", app: app)
            app.terminate()
        }
    }

    func testMonthWeatherUsesCurrentTodayAndThreeDistinctDailyForecastDates() {
        let app = launchApp(
            language: "ja",
            date: launchDate(offsetFromToday: 0),
            mode: "weather",
            theme: "light"
        )
        let expectedDateIDs = (0...3).map(dateID(offsetFromToday:))

        for dateID in expectedDateIDs {
            XCTAssertTrue(
                weatherIcon(dateID: dateID, in: app).waitForExistence(timeout: 8),
                dateID
            )
        }
        XCTAssertEqual(
            Set(expectedDateIDs.map { weatherIcon(dateID: $0, in: app).label }).count,
            4
        )
        XCTAssertFalse(weatherIcon(dateID: dateID(offsetFromToday: 10), in: app).exists)
        XCTAssertEqual(weatherIcons(in: app).count, 10)
        XCTAssertTrue(element(in: app, identifier: "weather.header.attribution").exists)
        attachScreenshot(named: "weather-month-current-and-daily", app: app)
    }

    func testWeatherHeaderAttributionFailureHasNoFallbackAndKeepsTitleStable() {
        let successfulApp = launchApp(language: "ja", mode: "weather")
        let successfulTitle = successfulApp.buttons["calendar.header.title"]
        let successfulMark = element(
            in: successfulApp,
            identifier: "weather.header.attribution.mark"
        )
        XCTAssertTrue(successfulTitle.waitForExistence(timeout: 8))
        XCTAssertTrue(successfulMark.waitForExistence(timeout: 8))
        let successfulTitleFrame = successfulTitle.frame
        successfulApp.terminate()

        let failedApp = launchApp(
            language: "ja",
            mode: "weather",
            attributionImageFails: true
        )
        let failedTitle = failedApp.buttons["calendar.header.title"]
        XCTAssertTrue(failedTitle.waitForExistence(timeout: 8))
        assert(
            element(in: failedApp, identifier: "weather.header.attribution"),
            exists: false
        )
        assert(
            element(in: failedApp, identifier: "weather.header.attribution.mark"),
            exists: false
        )
        assert(weatherIcon(dateID: targetDateID, in: failedApp), exists: false)
        XCTAssertEqual(weatherIcons(in: failedApp).count, 0)
        XCTAssertTrue(element(in: failedApp, identifier: "calendar.day.\(targetDateID)").exists)
        XCTAssertTrue(failedApp.staticTexts["建国記念の日"].waitForExistence(timeout: 8))
        XCTAssertTrue(failedTitle.isHittable)
        assertIsOnScreen(failedTitle, in: failedApp, "attribution-load-failure")
        XCTAssertEqual(failedTitle.frame.minX, successfulTitleFrame.minX, accuracy: 1)
        XCTAssertEqual(failedTitle.frame.width, successfulTitleFrame.width, accuracy: 1)
        attachScreenshot(named: "weather-header-attribution-failure", app: failedApp)
    }

    func testMonthNavigationKeepsCalendarAndWeatherHeaderUsable() {
        let app = launchApp(language: "ja", mode: "weather")
        XCTAssertTrue(
            element(in: app, identifier: "calendar.day.2026-2-4")
                .waitForExistence(timeout: 8)
        )

        headerNavigationButton(towardNext: true, in: app).tap()
        XCTAssertTrue(
            element(in: app, identifier: "calendar.day.2026-3-20")
                .waitForExistence(timeout: 8)
        )
        XCTAssertTrue(element(in: app, identifier: "weather.header.attribution").exists)

        headerNavigationButton(towardNext: false, in: app).tap()
        XCTAssertTrue(
            element(in: app, identifier: "calendar.day.2026-2-4")
                .waitForExistence(timeout: 8)
        )
        XCTAssertTrue(element(in: app, identifier: "weather.header.attribution").exists)
    }

    func testUnavailableWeatherLeavesCalendarUsable() {
        let app = launchApp(
            language: "ja",
            mode: "weather",
            weatherUnavailable: true
        )
        XCTAssertTrue(element(in: app, identifier: "calendar.day.\(targetDateID)").exists)
        XCTAssertFalse(weatherIcon(dateID: targetDateID, in: app).exists)

        app.buttons["calendar.mode.week"].tap()
        XCTAssertTrue(
            element(in: app, identifier: "weather.unavailable")
                .waitForExistence(timeout: 8)
        )
        XCTAssertTrue(app.buttons["calendar.mode.day"].isHittable)

        app.buttons["calendar.mode.day"].tap()
        XCTAssertTrue(
            element(in: app, identifier: "weather.day.section")
                .waitForExistence(timeout: 8)
        )
        XCTAssertTrue(element(in: app, identifier: "weather.unavailable").exists)
        attachScreenshot(named: "weather-unavailable", app: app)
    }

    func testWeekWeatherSupportsAccessibilityDynamicType() {
        let app = launchApp(
            language: "enUS",
            mode: "weather",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityLarge"
        )
        app.buttons["calendar.mode.week"].tap()
        let weatherCell = element(in: app, identifier: "weather.week.\(targetDateID)")
        XCTAssertTrue(weatherCell.waitForExistence(timeout: 8))
        assertIsOnScreen(weatherCell, in: app, "accessibility-large")
        XCTAssertTrue(app.buttons["calendar.mode.day"].isHittable)
        attachScreenshot(named: "week-weather-accessibility-large", app: app)
    }

    func testReceivedSharedCalendarUsesReceiverLocalMonthDisplay() {
        let app = launchApp(
            language: "ja",
            mode: "lunar",
            sharingScenario: "received"
        )

        app.buttons["sharing.calendarSelector"].tap()
        let receivedCalendar = app.buttons[
            "sharing.calendar.33333333-3333-3333-3333-333333333333"
        ]
        XCTAssertTrue(receivedCalendar.waitForExistence(timeout: 10))
        receivedCalendar.tap()

        assertDisplayMode("lunar", in: app)
        attachScreenshot(named: "traditional-calendar-received-shared", app: app)
    }

    private func launchApp(
        language: String,
        date: String = "2026-02-04",
        mode: String,
        theme: String? = nil,
        weatherUnavailable: Bool = false,
        attributionImageFails: Bool = false,
        contentSizeCategory: String? = nil,
        sharingScenario: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetUITestData",
            "-mockCloudKitState", "available",
            "-uiTestLanguage", language,
            "-uiTestCalendarDate", date,
            "-uiTestMonthSecondaryMode", mode,
            "-uiTestWeatherSquareMarkURL",
            attributionImageFails
                ? "https://example.invalid/apple-weather-square.svg"
                : successfulAttributionImageURL
        ]
        if let theme {
            app.launchArguments += ["-uiTestTheme", theme]
        }
        if weatherUnavailable {
            app.launchArguments.append("-uiTestWeatherUnavailable")
        }
        if let contentSizeCategory {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                contentSizeCategory
            ]
        }
        if let sharingScenario {
            app.launchArguments += ["-mockSharingScenario", sharingScenario]
        }
        app.launch()
        XCTAssertTrue(app.buttons["calendar.moreMenu"].waitForExistence(timeout: 10))
        return app
    }

    private func selectMonthMode(title: String, in app: XCUIApplication) {
        openSettings(in: app)
        XCTAssertFalse(element(in: app, identifier: "settings.weather").exists)
        XCTAssertFalse(app.staticTexts["天気予報"].exists)
        XCTAssertFalse(app.switches["天気を有効にする"].exists)
        XCTAssertFalse(app.staticTexts["現在地"].exists)
        let picker = app.buttons["settings.monthSecondaryDisplay"]
        scrollTo(picker, in: app)
        picker.tap()

        let option = app.buttons[title]
        XCTAssertTrue(option.waitForExistence(timeout: 5), title)
        option.tap()

        let close = app.buttons["modal.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(app.buttons["calendar.moreMenu"].waitForExistence(timeout: 5))
    }

    private func openSettings(in app: XCUIApplication) {
        app.buttons["calendar.moreMenu"].tap()
        XCTAssertTrue(app.buttons["settings.open"].waitForExistence(timeout: 5))
        app.buttons["settings.open"].tap()
        XCTAssertTrue(app.buttons["modal.close"].waitForExistence(timeout: 8))
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        let scrollView = app.scrollViews.firstMatch
        for _ in 0..<10 where !element.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func assertDisplayMode(_ mode: String, in app: XCUIApplication) {
        assert(traditionalLabel("lunar", dateID: targetDateID, in: app), exists: mode == "lunar")
        assert(traditionalLabel("rokuyo", dateID: targetDateID, in: app), exists: mode == "rokuyo")
        assert(
            traditionalLabel("solarTerm", dateID: targetDateID, in: app),
            exists: mode == "solarTerm"
        )
        assert(weatherIcon(dateID: targetDateID, in: app), exists: mode == "weather")
        assert(
            element(in: app, identifier: "weather.header.attribution"),
            exists: mode == "weather"
        )
    }

    private func assert(_ element: XCUIElement, exists: Bool) {
        if exists {
            XCTAssertTrue(element.waitForExistence(timeout: 8))
        } else {
            let expectation = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"),
                object: element
            )
            XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
        }
    }

    private func assertIsOnScreen(
        _ element: XCUIElement,
        in app: XCUIApplication,
        _ message: String
    ) {
        let screen = app.windows.firstMatch.frame.insetBy(dx: -1, dy: -1)
        XCTAssertFalse(element.frame.isEmpty, message)
        XCTAssertTrue(screen.contains(element.frame), message)
    }

    private func headerNavigationButton(
        towardNext: Bool,
        in app: XCUIApplication
    ) -> XCUIElement {
        let titleFrame = app.buttons["calendar.header.title"].frame
        let selectorFrame = app.buttons["sharing.calendarSelector"].frame
        let menuFrame = app.buttons["calendar.moreMenu"].frame
        let candidates = app.buttons.allElementsBoundByIndex.filter { button in
            let frame = button.frame
            guard !frame.isEmpty,
                  abs(frame.midY - titleFrame.midY) < 12 else {
                return false
            }
            if towardNext {
                return frame.midX > titleFrame.maxX && frame.midX < menuFrame.minX
            }
            return frame.midX > selectorFrame.maxX && frame.midX < titleFrame.minX
        }

        XCTAssertFalse(candidates.isEmpty)
        if towardNext {
            return candidates.max(by: { $0.frame.midX < $1.frame.midX })
                ?? app.buttons["calendar.header.navigation.missing"]
        }
        return candidates.min(by: { $0.frame.midX < $1.frame.midX })
            ?? app.buttons["calendar.header.navigation.missing"]
    }

    private func traditionalLabel(
        _ kind: String,
        dateID: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.staticTexts["calendar.traditional.\(kind).\(dateID)"]
    }

    private func weatherIcon(dateID: String, in app: XCUIApplication) -> XCUIElement {
        element(in: app, identifier: "calendar.weather.\(dateID)")
    }

    private func weatherIcons(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendar.weather."))
    }

    private func launchDate(offsetFromToday offset: Int) -> String {
        let components = calendarComponents(offsetFromToday: offset)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func dateID(offsetFromToday offset: Int) -> String {
        let components = calendarComponents(offsetFromToday: offset)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func calendarComponents(offsetFromToday offset: Int) -> DateComponents {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return calendar.dateComponents([.year, .month, .day], from: date)
    }

    private func element(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
