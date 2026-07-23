import XCTest

final class TimeNestCalendarEntryTargetUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testPersonalCalendarCreateAndEditKeepCalendarFixed() {
        let app = launchApp(seedData: true)

        app.buttons["calendar.addEntry"].tap()
        assertFixedEditor(in: app)
        replaceText(in: app.textFields["entry.title"], with: "Calendar Target Personal")
        app.buttons["entry.editor.save"].tap()
        XCTAssertTrue(app.staticTexts["Calendar Target Personal"].waitForExistence(timeout: 8))

        openCreatedEventDay(in: app)
        let edit = app.buttons["event.edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        assertFixedEditor(in: app, showsKindPicker: false)
        app.buttons["entry.editor.cancel"].tap()
    }

    func testOwnedSharedCalendarCreateKeepsSelectionAndTargetFixed() {
        let app = launchApp(seedData: true, sharingScenario: "accepted")
        selectCalendar(
            identifier: "sharing.calendar.22222222-2222-2222-2222-222222222222",
            in: app
        )

        let selector = app.buttons["sharing.calendarSelector"]
        let selectedCalendarLabel = selector.label
        app.buttons["calendar.addEntry"].tap()
        assertFixedEditor(in: app)
        replaceText(in: app.textFields["entry.title"], with: "Calendar Target Shared")
        app.buttons["entry.editor.save"].tap()

        XCTAssertTrue(app.staticTexts["Calendar Target Shared"].waitForExistence(timeout: 8))
        XCTAssertEqual(selector.label, selectedCalendarLabel)
    }

    func testReceivedCalendarBlocksCreateBeforeEditorInAllLanguages() {
        for language in ["ja", "enUS", "zhHans", "zhHant", "ko"] {
            let app = launchApp(sharingScenario: "received", language: language)
            selectCalendar(
                identifier: "sharing.calendar.33333333-3333-3333-3333-333333333333",
                in: app
            )

            let add = app.buttons["calendar.addEntry"]
            XCTAssertTrue(add.waitForExistence(timeout: 5), language)
            add.tap()

            let alert = app.alerts.firstMatch
            XCTAssertTrue(alert.waitForExistence(timeout: 5), language)
            XCTAssertFalse(app.otherElements["entry.editor"].exists, language)
            XCTAssertFalse(alert.label.contains("calendar_sharing."), language)
            XCTAssertFalse(alert.label.isEmpty, language)
            alert.buttons
                .matching(identifier: "calendar.readOnlyAlert.dismiss")
                .firstMatch
                .tap()
            XCTAssertTrue(app.buttons["sharing.calendarSelector"].exists, language)
        }
    }

    func testWorkRecordCreateUsesSameFixedCalendarContext() {
        let app = launchApp()
        app.buttons["calendar.addEntry"].tap()
        assertFixedEditor(in: app)

        let workRecord = element(in: app, identifier: "entry.kind.workRecord")
        XCTAssertTrue(workRecord.waitForExistence(timeout: 5))
        workRecord.tap()
        XCTAssertTrue(element(in: app, identifier: "workRecord.editor").waitForExistence(timeout: 5))
        XCTAssertFalse(element(in: app, identifier: "entry.calendarSelector").exists)
        app.buttons["entry.editor.cancel"].tap()
    }

    func testSmallScreenAccessibilityXXXLKeepsFixedEditorActionsReachable() {
        let app = launchApp(
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.buttons["calendar.addEntry"].tap()
        assertFixedEditor(in: app)

        XCTAssertTrue(app.buttons["entry.editor.cancel"].isHittable)
        XCTAssertTrue(app.buttons["entry.editor.save"].isHittable)
        XCTAssertTrue(element(in: app, identifier: "entry.kind").isHittable)
    }

    private func launchApp(
        seedData: Bool = false,
        sharingScenario: String? = nil,
        contentSizeCategory: String? = nil,
        language: String = "enUS"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetUITestData",
            "-mockCloudKitState", "available",
            "-uiTestLanguage", language
        ]
        if seedData {
            app.launchArguments.append("-seedDataManagementScenario")
        }
        if let sharingScenario {
            app.launchArguments += ["-mockSharingScenario", sharingScenario]
        }
        if let contentSizeCategory {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                contentSizeCategory
            ]
        }
        app.launch()
        XCTAssertTrue(app.buttons["calendar.moreMenu"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["calendar.addEntry"].waitForExistence(timeout: 10))
        return app
    }

    private func assertFixedEditor(
        in app: XCUIApplication,
        showsKindPicker: Bool = true
    ) {
        XCTAssertTrue(element(in: app, identifier: "entry.editor").waitForExistence(timeout: 5))
        XCTAssertFalse(element(in: app, identifier: "entry.calendarSelector").exists)
        XCTAssertEqual(element(in: app, identifier: "entry.kind").exists, showsKindPicker)
    }

    private func selectCalendar(identifier: String, in app: XCUIApplication) {
        app.buttons["sharing.calendarSelector"].tap()
        let row = app.buttons[identifier]
        XCTAssertTrue(row.waitForExistence(timeout: 10), identifier)
        row.tap()
        XCTAssertTrue(app.buttons["calendar.addEntry"].waitForExistence(timeout: 5))
    }

    private func openCreatedEventDay(in app: XCUIApplication) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let targetDate = Date()
        let components = calendar.dateComponents([.year, .month, .day], from: targetDate)
        let day = element(
            in: app,
            identifier: "calendar.day.\(components.year!)-\(components.month!)-\(components.day!)"
        )
        XCTAssertTrue(day.waitForExistence(timeout: 8))
        day.tap()
        XCTAssertTrue(element(in: app, identifier: "dayDetail.content").waitForExistence(timeout: 8))
    }

    private func replaceText(in field: XCUIElement, with value: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        if let currentValue = field.value as? String, !currentValue.isEmpty {
            field.typeText(
                String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count + 1)
            )
        }
        field.typeText(value)
    }

    private func element(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }
}
