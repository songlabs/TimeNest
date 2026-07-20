import XCTest

final class TimeNestDataManagementUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testDataManagementActionsAndAccessibilityIdentifiers() {
        let app = launchApp(language: "enUS", cloudState: "available", seedData: true)
        openSettings(in: app)

        let dataManagement = element(in: app, identifier: "settings.dataManagement")
        XCTAssertTrue(dataManagement.waitForExistence(timeout: 5))
        for identifier in [
            "settings.createBackup",
            "settings.restoreBackup",
            "settings.exportWorkRecords"
        ] {
            let button = app.buttons[identifier]
            XCTAssertTrue(button.exists, "Missing accessibility identifier: \(identifier)")
            XCTAssertFalse(button.label.isEmpty)
            XCTAssertFalse(button.frame.isEmpty)
        }
        attachScreenshot(named: "settings-data-management-en", app: app)
    }

    func testBackupShowsAndDismissesSystemShareSheet() {
        let app = launchApp(language: "enUS", cloudState: "available", seedData: true)
        openSettings(in: app)
        app.buttons["settings.createBackup"].tap()

        let activityList = app.otherElements["ActivityListView"]
        XCTAssertTrue(
            activityList.waitForExistence(timeout: 8) || app.sheets.firstMatch.waitForExistence(timeout: 2),
            "System share sheet did not appear for JSON backup."
        )
        attachScreenshot(named: "backup-share-sheet", app: app)
        dismissSystemShareSheet(in: app)
        XCTAssertTrue(app.buttons["settings.createBackup"].waitForExistence(timeout: 5))
    }

    func testRestoreConfirmationCancelAndSuccessfulRestore() {
        let app = launchApp(language: "enUS", cloudState: "available", seedData: true)
        openSettings(in: app)

        app.buttons["settings.restoreBackup"].tap()
        let cancelButton = app.buttons["settings.restoreCancel"]
        let confirmButton = app.buttons["settings.restoreConfirm"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        attachScreenshot(named: "restore-confirmation", app: app)
        cancelButton.tap()
        XCTAssertFalse(cancelButton.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["settings.restoreBackup"].isHittable)

        app.buttons["settings.restoreBackup"].tap()
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 8))
        attachScreenshot(named: "restore-success", app: app)
    }

    func testCSVExportAndNoDataMessage() {
        var app = launchApp(language: "enUS", cloudState: "available", seedData: true)
        openSettings(in: app)
        app.buttons["settings.exportWorkRecords"].tap()
        XCTAssertTrue(app.buttons["picker.confirm"].waitForExistence(timeout: 5))
        app.buttons["picker.confirm"].tap()
        let activityList = app.otherElements["ActivityListView"]
        XCTAssertTrue(
            activityList.waitForExistence(timeout: 8) || app.sheets.firstMatch.waitForExistence(timeout: 2),
            "System share sheet did not appear for CSV export."
        )
        attachScreenshot(named: "csv-share-sheet", app: app)
        dismissSystemShareSheet(in: app)

        app.terminate()
        app = launchApp(language: "enUS", cloudState: "available", seedData: false)
        openSettings(in: app)
        app.buttons["settings.exportWorkRecords"].tap()
        XCTAssertTrue(app.buttons["picker.confirm"].waitForExistence(timeout: 5))
        app.buttons["picker.confirm"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        attachScreenshot(named: "csv-no-data", app: app)
    }

    func testFiveLanguagesDataManagementHappyPathsRenderWithoutLocalizationKeys() {
        let languages = ["ja", "zhHans", "zh-Hant", "enUS", "ko"]
        for language in languages {
            let app = launchApp(
                language: language,
                cloudState: "available",
                seedData: true,
                sharingScenario: "pending"
            )
            openSettings(in: app)
            for identifier in [
                "settings.currentLanguage",
                "sharing.iCloudStatusValue",
                "sharing.lastSuccessfulSync",
                "sharing.syncNow",
                "settings.createBackup",
                "settings.restoreBackup",
                "settings.exportWorkRecords"
            ] {
                assertLocalizedElement(element(in: app, identifier: identifier), identifier: identifier)
            }

            app.buttons["settings.createBackup"].tap()
            XCTAssertTrue(
                app.otherElements["ActivityListView"].waitForExistence(timeout: 8)
                    || app.sheets.firstMatch.waitForExistence(timeout: 2)
            )
            dismissSystemShareSheet(in: app)

            app.buttons["settings.restoreBackup"].tap()
            XCTAssertTrue(app.buttons["settings.restoreCancel"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["settings.restoreConfirm"].exists)
            app.buttons["settings.restoreCancel"].tap()

            app.buttons["settings.restoreBackup"].tap()
            XCTAssertTrue(app.buttons["settings.restoreConfirm"].waitForExistence(timeout: 5))
            app.buttons["settings.restoreConfirm"].tap()
            assertLocalizedAlert(in: app)
            dismissFirstAlert(in: app)

            app.buttons["settings.exportWorkRecords"].tap()
            XCTAssertTrue(app.buttons["picker.confirm"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["picker.cancel"].exists)
            app.buttons["picker.cancel"].tap()

            app.buttons["settings.exportWorkRecords"].tap()
            XCTAssertTrue(app.buttons["picker.confirm"].waitForExistence(timeout: 5))
            app.buttons["picker.confirm"].tap()
            XCTAssertTrue(
                app.otherElements["ActivityListView"].waitForExistence(timeout: 8)
                    || app.sheets.firstMatch.waitForExistence(timeout: 2)
            )
            dismissSystemShareSheet(in: app)
            attachScreenshot(named: "settings-\(language)", app: app)
            app.terminate()
        }
    }

    func testFiveLanguagesDataManagementFailureAndNoDataMessages() {
        for language in ["ja", "zhHans", "zh-Hant", "enUS", "ko"] {
            var app = launchApp(
                language: language,
                cloudState: "available",
                seedData: true,
                restoreFailure: true
            )
            openSettings(in: app)
            app.buttons["settings.restoreBackup"].tap()
            XCTAssertTrue(app.buttons["settings.restoreConfirm"].waitForExistence(timeout: 5))
            app.buttons["settings.restoreConfirm"].tap()
            assertLocalizedAlert(in: app)
            attachScreenshot(named: "restore-failure-\(language)", app: app)
            app.terminate()

            app = launchApp(language: language, cloudState: "available", seedData: false)
            openSettings(in: app)
            app.buttons["settings.exportWorkRecords"].tap()
            XCTAssertTrue(app.buttons["picker.confirm"].waitForExistence(timeout: 5))
            app.buttons["picker.confirm"].tap()
            assertLocalizedAlert(in: app)
            attachScreenshot(named: "csv-no-data-\(language)", app: app)
            app.terminate()
        }
    }

    func testFiveLanguagesSharingStatesAndErrors() {
        let calendarRowID = "sharing.calendar.22222222-2222-2222-2222-222222222222"
        for language in ["ja", "zhHans", "zh-Hant", "enUS", "ko"] {
            var statusValues = Set<String>()
            for scenario in ["pending", "accepted", "syncing", "syncFailure", "stopped"] {
                let app = launchApp(
                    language: language,
                    cloudState: "available",
                    seedData: true,
                    sharingScenario: scenario
                )
                app.buttons["sharing.calendarSelector"].tap()
                let row = app.buttons[calendarRowID]
                XCTAssertTrue(row.waitForExistence(timeout: 8), "\(language)-\(scenario)")
                let status = row.value as? String ?? ""
                XCTAssertFalse(status.isEmpty, "\(language)-\(scenario)")
                XCTAssertFalse(status.contains("calendar_sharing."), "\(language)-\(scenario)")
                statusValues.insert(status)

                if scenario == "syncFailure" {
                    let scrollContainer = sharingScrollContainer(in: app)
                    let errorMessage = element(in: app, identifier: "sharing.errorMessage")
                    let retry = app.buttons["sharing.retry"]
                    let didRevealFailureActions = scrollUntilVisible(
                        [errorMessage, retry],
                        in: scrollContainer,
                        maxSwipes: 6
                    )
                    if !didRevealFailureActions {
                        attachScrollFailureEvidence(
                            named: "sharing-\(language)-syncFailure-scroll-failure",
                            app: app,
                            scrollContainer: scrollContainer,
                            targets: [errorMessage, retry]
                        )
                    }
                    XCTAssertTrue(didRevealFailureActions, "Failed to reveal sharing failure actions")
                    assertLocalizedElement(errorMessage, identifier: "sharing.errorMessage")
                    XCTAssertTrue(retry.exists)
                    XCTAssertFalse(retry.label.isEmpty)
                    XCTAssertTrue(retry.isHittable)

                    retry.tap()

                    assertLocalizedElement(errorMessage, identifier: "sharing.errorMessage after retry")
                    XCTAssertTrue(retry.waitForExistence(timeout: 5))
                    XCTAssertTrue(retry.isHittable)
                }
                attachScreenshot(named: "sharing-\(language)-\(scenario)", app: app)
                app.terminate()
            }
            XCTAssertEqual(statusValues.count, 5, "Distinct sharing states for \(language)")
        }
    }

    func testFiveLanguagesMockICloudStatesRenderWithoutLocalizationKeys() {
        for language in ["ja", "zhHans", "zh-Hant", "enUS", "ko"] {
            for state in [
                "noAccount",
                "restricted",
                "temporarilyUnavailable",
                "networkError",
                "permissionDenied",
                "unknown"
            ] {
                let app = launchApp(language: language, cloudState: state, seedData: true)
                openSettings(in: app)
                let status = element(in: app, identifier: "sharing.iCloudStatusValue")
                assertLocalizedElement(status, identifier: "\(language)-\(state)")
                attachScreenshot(named: "icloud-mock-\(language)-\(state)", app: app)
                app.terminate()
            }
        }
    }

    func testSmallScreenLargeTextRestoreActionsAndTargetRowsRemainAccessible() {
        for configuration in [
            (theme: "light", size: "UICTContentSizeCategoryXXXL", suffix: "light-xxxl"),
            (theme: "dark", size: "UICTContentSizeCategoryAccessibilityXXXL", suffix: "dark-accessibility")
        ] {
            let app = launchApp(
                language: "enUS",
                cloudState: "available",
                seedData: true,
                theme: configuration.theme,
                contentSizeCategory: configuration.size
            )
            openSettings(in: app)
            for identifier in [
                "settings.currentLanguage",
                "sharing.iCloudStatusValue",
                "sharing.lastSuccessfulSync",
                "settings.createBackup",
                "settings.restoreBackup",
                "settings.exportWorkRecords"
            ] {
                let target = element(in: app, identifier: identifier)
                XCTAssertTrue(target.waitForExistence(timeout: 5), identifier)
                XCTAssertFalse(target.frame.isEmpty, identifier)
            }
            scrollUntilHittable(app.buttons["settings.restoreBackup"], in: app)
            app.buttons["settings.restoreBackup"].tap()
            XCTAssertTrue(app.buttons["settings.restoreCancel"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["settings.restoreConfirm"].exists)
            attachScreenshot(named: "small-\(configuration.suffix)", app: app)
            if configuration.theme == "light" {
                app.buttons["settings.restoreCancel"].tap()
                XCTAssertTrue(app.buttons["settings.exportWorkRecords"].waitForExistence(timeout: 5))
            } else {
                app.buttons["settings.restoreConfirm"].tap()
                XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 8))
            }
            app.terminate()
        }
    }

    func testSmallScreenDarkAccessibilitySharingFailureRemainsScrollableAndActionable() {
        let app = launchApp(
            language: "ja",
            cloudState: "available",
            seedData: true,
            theme: "dark",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL",
            sharingScenario: "syncFailure"
        )
        app.buttons["sharing.calendarSelector"].tap()

        let scrollContainer = sharingScrollContainer(in: app)
        let calendarRow = element(
            in: app,
            identifier: "sharing.calendar.22222222-2222-2222-2222-222222222222"
        )
        let didRevealCalendarRow = scrollUntilVisible(
            [calendarRow],
            in: scrollContainer,
            maxSwipes: 6
        )
        if !didRevealCalendarRow {
            attachScrollFailureEvidence(
                named: "small-dark-accessibility-sharing-row-scroll-failure",
                app: app,
                scrollContainer: scrollContainer,
                targets: [calendarRow]
            )
        }
        XCTAssertTrue(didRevealCalendarRow, "Failed to reveal shared calendar status row")
        XCTAssertFalse((calendarRow.value as? String ?? "").isEmpty)

        let errorMessage = element(in: app, identifier: "sharing.errorMessage")
        let retry = app.buttons["sharing.retry"]
        let didRevealFailureActions = scrollUntilVisible(
            [errorMessage, retry],
            in: scrollContainer,
            maxSwipes: 6
        )
        if !didRevealFailureActions {
            attachScrollFailureEvidence(
                named: "small-dark-accessibility-sharing-scroll-failure",
                app: app,
                scrollContainer: scrollContainer,
                targets: [errorMessage, retry]
            )
        }
        XCTAssertTrue(didRevealFailureActions, "Failed to reveal sharing failure actions")
        assertLocalizedElement(errorMessage, identifier: "sharing.errorMessage")
        XCTAssertTrue(retry.isHittable)
        attachScreenshot(named: "small-dark-accessibility-sharing-failure", app: app)

        retry.tap()

        assertLocalizedElement(errorMessage, identifier: "sharing.errorMessage after retry")
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(retry.isHittable)
    }

    private func launchApp(
        language: String,
        cloudState: String,
        seedData: Bool,
        theme: String? = nil,
        contentSizeCategory: String? = nil,
        sharingScenario: String? = nil,
        restoreFailure: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetUITestData",
            "-mockCloudKitState", cloudState,
            "-uiTestLanguage", language,
            "-preserveExportedTestFile"
        ]
        if seedData {
            app.launchArguments.append("-seedDataManagementScenario")
        }
        if let theme {
            app.launchArguments += ["-uiTestTheme", theme]
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
        if restoreFailure {
            app.launchArguments.append("-simulateRestoreFailure")
        }
        app.launch()
        XCTAssertTrue(app.buttons["calendar.moreMenu"].waitForExistence(timeout: 10))
        return app
    }

    private func openSettings(in app: XCUIApplication) {
        app.buttons["calendar.moreMenu"].tap()
        XCTAssertTrue(app.buttons["settings.open"].waitForExistence(timeout: 5))
        app.buttons["settings.open"].tap()
        XCTAssertTrue(
            element(in: app, identifier: "settings.dataManagement").waitForExistence(timeout: 8)
                || app.buttons["settings.createBackup"].waitForExistence(timeout: 2)
        )
    }

    private func dismissSystemShareSheet(in app: XCUIApplication) {
        let closeButton = app.buttons["header.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()
        XCTAssertFalse(app.otherElements["ActivityListView"].waitForExistence(timeout: 3))
    }

    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertLocalizedElement(_ element: XCUIElement, identifier: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), identifier)
        XCTAssertFalse(element.label.isEmpty, identifier)
        XCTAssertFalse(element.label.contains("data_management."), identifier)
        XCTAssertFalse(element.label.contains("calendar_sharing."), identifier)
    }

    private func element(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    private func assertLocalizedAlert(in app: XCUIApplication) {
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 8))
        XCTAssertFalse(alert.label.isEmpty)
        XCTAssertFalse(alert.label.contains("data_management."))
        XCTAssertFalse(alert.label.contains("calendar_sharing."))
    }

    private func dismissFirstAlert(in app: XCUIApplication) {
        let button = app.alerts.firstMatch.buttons.firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        for _ in 0..<16 where !element.isHittable {
            let isAboveViewport = element.frame.midY < scrollView.frame.minY
            let start = scrollView.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: isAboveViewport ? 0.25 : 0.75)
            )
            let end = scrollView.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: isAboveViewport ? 0.55 : 0.45)
            )
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(
            element.isHittable,
            "Element frame \(element.frame), scroll frame \(scrollView.frame)"
        )
    }

    private func sharingScrollContainer(in app: XCUIApplication) -> XCUIElement {
        for candidate in [
            app.collectionViews.firstMatch,
            app.tables.firstMatch,
            app.scrollViews.firstMatch
        ] where candidate.waitForExistence(timeout: 1) {
            return candidate
        }
        XCTFail("Sharing page did not expose a scrollable container")
        return app
    }

    private func scrollUntilVisible(
        _ elements: [XCUIElement],
        in scrollView: XCUIElement,
        maxSwipes: Int = 6
    ) -> Bool {
        if elements.allSatisfy({ $0.exists }) {
            return true
        }
        for _ in 0..<maxSwipes {
            let start = scrollView.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)
            )
            let end = scrollView.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.50)
            )
            start.press(forDuration: 0.05, thenDragTo: end)
            if elements.allSatisfy({ $0.waitForExistence(timeout: 0.5) }) {
                return true
            }
        }
        return false
    }

    private func attachScrollFailureEvidence(
        named name: String,
        app: XCUIApplication,
        scrollContainer: XCUIElement,
        targets: [XCUIElement]
    ) {
        let targetSummary = targets.map { target in
            guard target.exists else { return "exists=false" }
            return "identifier=\(target.identifier), exists=true, hittable=\(target.isHittable), frame=\(target.frame)"
        }.joined(separator: "\n")
        let treeAttachment = XCTAttachment(string: """
        Scroll container: type=\(scrollContainer.elementType.rawValue), frame=\(scrollContainer.frame)
        Targets:
        \(targetSummary)

        Accessibility tree:
        \(app.debugDescription)
        """)
        treeAttachment.name = "\(name)-accessibility-tree"
        treeAttachment.lifetime = .keepAlways
        add(treeAttachment)
        attachScreenshot(named: name, app: app)
    }
}
