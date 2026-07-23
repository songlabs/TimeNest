import XCTest

final class TimeNestEmptyStatesUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testShiftTemplateEmptyStateLifecycle() {
        let app = launchApp(emptyShiftTemplates: true)
        openShiftTemplates(in: app)

        let emptyState = element(in: app, identifier: "shiftTemplate.empty")
        let emptyAction = app.buttons["shiftTemplate.empty.create"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5))
        XCTAssertTrue(emptyAction.isHittable)

        emptyAction.tap()
        XCTAssertTrue(app.textFields["shiftTemplate.name"].waitForExistence(timeout: 5))
        app.buttons["shiftTemplate.edit.cancel"].tap()
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5))

        emptyAction.tap()
        let nameField = app.textFields["shiftTemplate.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        replaceText(in: nameField, with: "First Shift Template")
        app.buttons["shiftTemplate.edit.save"].tap()

        XCTAssertTrue(
            button(
                identifier: "shiftTemplate.edit",
                value: "First Shift Template",
                in: app
            ).waitForExistence(timeout: 5)
        )
        XCTAssertFalse(emptyState.exists)

        let delete = app.buttons["shiftTemplate.delete"].firstMatch
        scrollUntilHittable(delete, in: app)
        delete.tap()
        let confirmDelete = app.buttons["shiftTemplate.delete.confirm"].firstMatch
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
        confirmDelete.tap()

        XCTAssertTrue(emptyState.waitForExistence(timeout: 5))
    }

    func testWorkRecordEmptyStateLifecycle() {
        let app = launchApp(seedData: true)
        openSeededDayWithoutWorkRecords(in: app)

        let emptyState = element(in: app, identifier: "workRecord.empty")
        let emptyAction = app.buttons["workRecord.empty.create"]
        scrollUntilHittable(emptyAction, in: app)
        XCTAssertTrue(emptyState.exists)

        emptyAction.tap()
        XCTAssertTrue(app.buttons["entry.editor.cancel"].waitForExistence(timeout: 5))
        app.buttons["entry.editor.cancel"].tap()
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5))

        scrollUntilHittable(emptyAction, in: app)
        emptyAction.tap()
        XCTAssertTrue(app.buttons["entry.editor.save"].waitForExistence(timeout: 5))
        app.buttons["entry.editor.save"].tap()

        XCTAssertTrue(waitForDisappearance(emptyState, timeout: 8))
        let delete = app.buttons["workRecord.delete"].firstMatch
        scrollUntilHittable(delete, in: app)
        delete.tap()

        XCTAssertTrue(emptyState.waitForExistence(timeout: 8))
    }

    func testSharingEmptyStateActionAndStatePriority() {
        var app = launchApp()
        openCalendarSelection(in: app)
        let emptyState = element(in: app, identifier: "sharing.empty")
        let emptyAction = app.buttons["sharing.empty.create"]
        let invitationLink = app.buttons["sharing.invitationLink"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 8))
        XCTAssertFalse(element(in: app, identifier: "sharing.empty.title").exists)
        XCTAssertFalse(element(in: app, identifier: "sharing.empty.message").exists)
        XCTAssertTrue(emptyAction.isHittable)
        XCTAssertTrue(invitationLink.isHittable)
        emptyAction.tap()
        XCTAssertTrue(app.textFields["sharing.createCalendar.name"].waitForExistence(timeout: 5))
        app.buttons["sharing.createCalendar.cancel"].tap()
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5))
        app.terminate()

        app = launchApp(sharingScenario: "syncing")
        openCalendarSelection(in: app)
        XCTAssertTrue(element(in: app, identifier: "sharing.loading").waitForExistence(timeout: 5))
        XCTAssertFalse(element(in: app, identifier: "sharing.empty").exists)
        app.terminate()

        app = launchApp(sharingScenario: "syncFailure")
        openCalendarSelection(in: app)
        XCTAssertTrue(element(in: app, identifier: "sharing.errorMessage").waitForExistence(timeout: 8))
        XCTAssertFalse(element(in: app, identifier: "sharing.empty").exists)
        app.terminate()

        app = launchApp(cloudState: "noAccount")
        openCalendarSelection(in: app)
        XCTAssertTrue(element(in: app, identifier: "sharing.errorMessage").waitForExistence(timeout: 8))
        XCTAssertFalse(element(in: app, identifier: "sharing.empty").exists)
        app.terminate()

        app = launchApp(seedData: true, sharingScenario: "pending")
        openCalendarSelection(in: app)
        XCTAssertTrue(
            app.buttons["sharing.calendar.22222222-2222-2222-2222-222222222222"]
                .waitForExistence(timeout: 8)
        )
        XCTAssertFalse(element(in: app, identifier: "sharing.empty").exists)
        app.terminate()

        app = launchApp(sharingScenario: "received")
        openCalendarSelection(in: app)
        XCTAssertTrue(
            app.buttons["sharing.calendar.33333333-3333-3333-3333-333333333333"]
                .waitForExistence(timeout: 8)
        )
        XCTAssertFalse(element(in: app, identifier: "sharing.empty").exists)
    }

    func testAccessibilityXXXLKeepsEmptyStateActionsReachable() {
        var app = launchApp(
            emptyShiftTemplates: true,
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        openShiftTemplates(in: app)
        var action = app.buttons["shiftTemplate.empty.create"]
        scrollUntilHittable(action, in: app)
        action.tap()
        XCTAssertTrue(app.buttons["shiftTemplate.edit.cancel"].waitForExistence(timeout: 5))
        app.buttons["shiftTemplate.edit.cancel"].tap()
        app.terminate()

        app = launchApp(
            seedData: true,
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        openSeededDayWithoutWorkRecords(in: app)
        action = app.buttons["workRecord.empty.create"]
        scrollUntilHittable(action, in: app)
        action.tap()
        XCTAssertTrue(app.buttons["entry.editor.cancel"].waitForExistence(timeout: 5))
        app.buttons["entry.editor.cancel"].tap()
        app.terminate()

        app = launchApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        openCalendarSelection(in: app)
        action = app.buttons["sharing.empty.create"]
        scrollUntilHittable(action, in: app)
        action.tap()
        XCTAssertTrue(app.buttons["sharing.createCalendar.cancel"].waitForExistence(timeout: 5))
    }

    private func launchApp(
        emptyShiftTemplates: Bool = false,
        seedData: Bool = false,
        sharingScenario: String? = nil,
        cloudState: String = "available",
        contentSizeCategory: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetUITestData",
            "-mockCloudKitState", cloudState,
            "-uiTestLanguage", "enUS"
        ]
        if emptyShiftTemplates {
            app.launchArguments.append("-emptyShiftTemplates")
        }
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
        return app
    }

    private func openShiftTemplates(in app: XCUIApplication) {
        app.buttons["calendar.moreMenu"].tap()
        XCTAssertTrue(app.buttons["settings.open"].waitForExistence(timeout: 5))
        app.buttons["settings.open"].tap()
        let row = element(in: app, identifier: "settings.shiftTemplates")
        scrollUntilHittable(row, in: app)
        row.tap()
        XCTAssertTrue(element(in: app, identifier: "shiftTemplate.list").waitForExistence(timeout: 8))
    }

    private func openSeededDayWithoutWorkRecords(in app: XCUIApplication) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = Date()
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start
            ?? calendar.startOfDay(for: now)
        let targetDate = calendar.date(byAdding: .day, value: 2, to: monthStart)!
        let components = calendar.dateComponents([.year, .month, .day], from: targetDate)
        let identifier = "calendar.day.\(components.year!)-\(components.month!)-\(components.day!)"
        let day = element(in: app, identifier: identifier)
        XCTAssertTrue(day.waitForExistence(timeout: 8), identifier)
        day.tap()
        XCTAssertTrue(element(in: app, identifier: "dayDetail.content").waitForExistence(timeout: 8))
    }

    private func openCalendarSelection(in app: XCUIApplication) {
        let selector = app.buttons["sharing.calendarSelector"]
        XCTAssertTrue(selector.waitForExistence(timeout: 5))
        selector.tap()
        XCTAssertTrue(element(in: app, identifier: "sharing.calendarList").waitForExistence(timeout: 8))
    }

    private func element(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    private func button(
        identifier: String,
        value: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.buttons
            .matching(identifier: identifier)
            .matching(NSPredicate(format: "value == %@", value))
            .firstMatch
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        if element.isHittable { return }
        let scrollView = firstScrollContainer(in: app)
        for _ in 0..<14 where !element.isHittable {
            let isAboveViewport = element.exists && element.frame.midY < scrollView.frame.minY
            let start = scrollView.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: isAboveViewport ? 0.25 : 0.78)
            )
            let end = scrollView.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: isAboveViewport ? 0.58 : 0.42)
            )
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable, "Element was not reachable: \(element.identifier)")
    }

    private func replaceText(in field: XCUIElement, with value: String) {
        field.tap()
        if let currentValue = field.value as? String, !currentValue.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count + 1))
        }
        field.typeText(value)
    }

    private func firstScrollContainer(in app: XCUIApplication) -> XCUIElement {
        for candidate in [
            app.scrollViews.firstMatch,
            app.collectionViews.firstMatch,
            app.tables.firstMatch
        ] where candidate.waitForExistence(timeout: 1) {
            return candidate
        }
        XCTFail("No scrollable container was available")
        return app
    }

    private func waitForDisappearance(
        _ element: XCUIElement,
        timeout: TimeInterval
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
