import XCTest

final class TraditionalCalendarUITests: XCTestCase {
    private let targetDateID = "2026-2-4"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testIndependentSwitchesImmediatelyRefreshWithoutChangingCellHeight() {
        let app = launchApp(language: "ja")
        let dayCell = element(in: app, identifier: "calendar.day.\(targetDateID)")
        XCTAssertTrue(dayCell.waitForExistence(timeout: 10))
        let originalCellHeight = dayCell.frame.height

        setDisplays(lunar: false, rokuyo: false, solarTerms: false, in: app)
        assertDisplayState(lunar: false, rokuyo: false, solarTerms: false, in: app)
        attachScreenshot(named: "traditional-calendar-all-off", app: app)

        setDisplays(lunar: true, rokuyo: false, solarTerms: false, in: app)
        assertDisplayState(lunar: true, rokuyo: false, solarTerms: false, in: app)
        attachScreenshot(named: "traditional-calendar-lunar-only", app: app)

        setDisplays(lunar: false, rokuyo: true, solarTerms: false, in: app)
        assertDisplayState(lunar: false, rokuyo: true, solarTerms: false, in: app)
        attachScreenshot(named: "traditional-calendar-rokuyo-only", app: app)

        setDisplays(lunar: false, rokuyo: false, solarTerms: true, in: app)
        assertDisplayState(lunar: false, rokuyo: false, solarTerms: true, in: app)
        attachScreenshot(named: "traditional-calendar-solar-term-only", app: app)

        setDisplays(lunar: true, rokuyo: true, solarTerms: true, in: app)
        assertDisplayState(lunar: true, rokuyo: true, solarTerms: true, in: app)
        XCTAssertEqual(dayCell.frame.height, originalCellHeight, accuracy: 0.5)

        let labels = [
            traditionalLabel("solarTerm", dateID: targetDateID, in: app),
            traditionalLabel("lunar", dateID: targetDateID, in: app),
            traditionalLabel("rokuyo", dateID: targetDateID, in: app)
        ]
        for label in labels {
            XCTAssertTrue(dayCell.frame.insetBy(dx: -1, dy: -1).contains(label.frame))
            XCTAssertFalse(label.frame.isEmpty)
        }
        for firstIndex in labels.indices {
            for secondIndex in labels.indices where secondIndex > firstIndex {
                XCTAssertFalse(labels[firstIndex].frame.intersects(labels[secondIndex].frame))
            }
        }
        attachScreenshot(named: "traditional-calendar-all-on", app: app)
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
                showLunar: true,
                showRokuyo: true,
                showSolarTerms: true
            )
            let dayCell = element(in: app, identifier: "calendar.day.\(dateID)")
            XCTAssertTrue(dayCell.waitForExistence(timeout: 10), language)

            let solarTerm = traditionalLabel("solarTerm", dateID: dateID, in: app)
            let lunar = traditionalLabel("lunar", dateID: dateID, in: app)
            let rokuyo = traditionalLabel("rokuyo", dateID: dateID, in: app)
            XCTAssertTrue(solarTerm.waitForExistence(timeout: 8), language)
            XCTAssertTrue(lunar.waitForExistence(timeout: 8), language)
            XCTAssertTrue(rokuyo.waitForExistence(timeout: 8), language)
            XCTAssertEqual(solarTerm.label, expectedSolarTerms[language], language)

            for label in [solarTerm, lunar, rokuyo] {
                XCTAssertFalse(label.label.isEmpty, language)
                XCTAssertFalse(label.label.contains("traditional_calendar."), language)
                XCTAssertTrue(dayCell.frame.insetBy(dx: -1, dy: -1).contains(label.frame), language)
            }

            let holiday = app.staticTexts["春分の日"]
            XCTAssertTrue(holiday.waitForExistence(timeout: 8), language)
            XCTAssertFalse(holiday.frame.intersects(solarTerm.frame), language)
            XCTAssertFalse(holiday.frame.intersects(lunar.frame), language)
            XCTAssertFalse(holiday.frame.intersects(rokuyo.frame), language)
            attachScreenshot(named: "traditional-calendar-\(language)-small-screen", app: app)
            app.terminate()
        }
    }

    func testReceivedSharedCalendarUsesReceiverLocalTraditionalDisplay() {
        let app = launchApp(
            language: "ja",
            showLunar: true,
            showRokuyo: true,
            showSolarTerms: true,
            sharingScenario: "received"
        )

        app.buttons["sharing.calendarSelector"].tap()
        let receivedCalendar = app.buttons[
            "sharing.calendar.33333333-3333-3333-3333-333333333333"
        ]
        XCTAssertTrue(receivedCalendar.waitForExistence(timeout: 10))
        receivedCalendar.tap()

        assertDisplayState(lunar: true, rokuyo: true, solarTerms: true, in: app)
        attachScreenshot(named: "traditional-calendar-received-shared", app: app)
    }

    private func launchApp(
        language: String,
        date: String = "2026-02-04",
        showLunar: Bool = false,
        showRokuyo: Bool = false,
        showSolarTerms: Bool = false,
        sharingScenario: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetUITestData",
            "-mockCloudKitState", "available",
            "-uiTestLanguage", language,
            "-uiTestCalendarDate", date
        ]
        if showLunar {
            app.launchArguments.append("-uiTestShowLunarCalendar")
        }
        if showRokuyo {
            app.launchArguments.append("-uiTestShowRokuyo")
        }
        if showSolarTerms {
            app.launchArguments.append("-uiTestShowSolarTerms")
        }
        if let sharingScenario {
            app.launchArguments += ["-mockSharingScenario", sharingScenario]
        }
        app.launch()
        XCTAssertTrue(app.buttons["calendar.moreMenu"].waitForExistence(timeout: 10))
        return app
    }

    private func setDisplays(
        lunar: Bool,
        rokuyo: Bool,
        solarTerms: Bool,
        in app: XCUIApplication
    ) {
        openSettings(in: app)

        let switches = [
            (
                app.switches["settings.traditionalCalendar.showLunar"],
                lunar
            ),
            (
                app.switches["settings.traditionalCalendar.showRokuyo"],
                rokuyo
            ),
            (
                app.switches["settings.traditionalCalendar.showSolarTerms"],
                solarTerms
            )
        ]

        for (toggle, expectedValue) in switches {
            scrollTo(toggle, in: app)
            XCTAssertTrue(toggle.exists)
            if isOn(toggle) != expectedValue {
                toggle.tap()
            }
            XCTAssertEqual(isOn(toggle), expectedValue)
        }

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

    private func isOn(_ toggle: XCUIElement) -> Bool {
        let value = String(describing: toggle.value ?? "")
        return value == "1" || value.lowercased() == "true"
    }

    private func assertDisplayState(
        lunar: Bool,
        rokuyo: Bool,
        solarTerms: Bool,
        in app: XCUIApplication
    ) {
        assert(traditionalLabel("lunar", dateID: targetDateID, in: app), exists: lunar)
        assert(traditionalLabel("rokuyo", dateID: targetDateID, in: app), exists: rokuyo)
        assert(
            traditionalLabel("solarTerm", dateID: targetDateID, in: app),
            exists: solarTerms
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
            XCTAssertEqual(
                XCTWaiter.wait(for: [expectation], timeout: 8),
                .completed
            )
        }
    }

    private func traditionalLabel(
        _ kind: String,
        dateID: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.staticTexts["calendar.traditional.\(kind).\(dateID)"]
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
