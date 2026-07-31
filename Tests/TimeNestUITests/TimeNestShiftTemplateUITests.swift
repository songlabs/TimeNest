import XCTest

final class TimeNestShiftTemplateFavoritesUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testFavoriteTemplateAppearsInFavoriteSection() {
        let app = launchApp()
        openShiftTemplates(in: app)

        let favorite = element(in: app, identifier: "shiftTemplate.favorite")
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))
        favorite.tap()

        XCTAssertTrue(element(in: app, identifier: "shiftTemplate.favoriteSection").waitForExistence(timeout: 5))
        XCTAssertTrue(element(in: app, identifier: "shiftTemplate.unfavorite").exists)
    }

    func testUnfavoriteTemplateRemovesEmptyFavoriteSection() {
        let app = launchApp()
        openShiftTemplates(in: app)
        element(in: app, identifier: "shiftTemplate.favorite").tap()
        XCTAssertTrue(element(in: app, identifier: "shiftTemplate.favoriteSection").waitForExistence(timeout: 5))

        element(in: app, identifier: "shiftTemplate.unfavorite").tap()

        XCTAssertFalse(element(in: app, identifier: "shiftTemplate.favoriteSection").waitForExistence(timeout: 2))
    }

    func testOnlyOrdinaryShiftInputRemainsInCalendarMenu() {
        let app = launchApp()
        app.buttons["calendar.moreMenu"].tap()

        XCTAssertTrue(app.buttons["Shift Input"].waitForExistence(timeout: 5))
        let shiftActions = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Shift")
        )
        XCTAssertEqual(shiftActions.count, 1)
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetUITestData",
            "-mockCloudKitState", "available",
            "-uiTestLanguage", "enUS"
        ]
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

    private func element(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        for _ in 0..<12 where !element.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}

final class TimeNestShiftTemplateUITests: XCTestCase {
    private struct TemplateEditorSnapshot {
        let start: String
        let end: String
        let color: String
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testCoreOnlyCreateShowsCoreFieldsAndIsSelectableInShiftInput() {
        let app = launchApp()
        openShiftTemplates(in: app)
        app.buttons["shiftTemplate.add"].tap()

        let nameField = app.textFields["shiftTemplate.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["shiftTemplate.startTime"].exists)
        XCTAssertTrue(app.buttons["shiftTemplate.endTime"].exists)
        XCTAssertTrue(element(in: app, identifier: "shiftTemplate.colorPicker").exists)
        XCTAssertTrue(app.buttons["shiftTemplate.details.toggle"].exists)
        XCTAssertFalse(app.textFields["shiftTemplate.note"].exists)
        XCTAssertFalse(app.switches["shiftTemplate.enabled"].exists)

        replaceText(in: nameField, with: "Core Only Shift")
        let startTime = app.buttons["shiftTemplate.startTime"].label
        let endTime = app.buttons["shiftTemplate.endTime"].label
        app.buttons["shiftTemplate.edit.save"].tap()

        scrollUntilHittable(templateRow(named: "Core Only Shift", in: app), in: app)
        openEditor(for: "Core Only Shift", in: app)
        XCTAssertEqual(nameField.value as? String, "Core Only Shift")
        XCTAssertEqual(app.buttons["shiftTemplate.startTime"].label, startTime)
        XCTAssertEqual(app.buttons["shiftTemplate.endTime"].label, endTime)
        XCTAssertFalse(app.textFields["shiftTemplate.note"].exists)
        app.buttons["shiftTemplate.edit.cancel"].tap()

        closeTemplatesAndSettings(in: app)
        openShiftInput(in: app)
        let option = app.buttons["Core Only Shift"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        XCTAssertTrue(option.isHittable)
        app.buttons["modal.close"].tap()
    }

    func testTemplateCreationPersistsNoteTimesAndNonDefaultColorWhenReopened() {
        let app = launchApp()
        openShiftTemplates(in: app)
        let note = "Template note, \"quoted\""

        let persisted = createTemplate(
            named: "UITest Early Shift",
            note: note,
            colorComponents: (red: 0.85, green: 0.20, blue: 0.70),
            adjustStartTime: true,
            adjustEndTime: true,
            disableTemplate: true,
            in: app
        )

        XCTAssertTrue(templateRow(named: "UITest Early Shift", in: app).exists)
        XCTAssertEqual(matchingRows(named: "UITest Early Shift", in: app).count, 1)
        openEditor(for: "UITest Early Shift", in: app)
        XCTAssertEqual(app.textFields["shiftTemplate.name"].value as? String, "UITest Early Shift")
        XCTAssertFalse(app.textFields["shiftTemplate.note"].exists)
        expandDetails(in: app)
        XCTAssertEqual(app.textFields["shiftTemplate.note"].value as? String, note)
        XCTAssertEqual(enabledValue(in: app), "0")
        attachScreenshot(named: "shift-template-create-reopen", app: app)
        collapseDetails(in: app)
        XCTAssertEqual(app.buttons["shiftTemplate.startTime"].label, persisted.start)
        XCTAssertEqual(app.buttons["shiftTemplate.endTime"].label, persisted.end)
        XCTAssertEqual(colorValue(in: app), persisted.color)
        app.buttons["shiftTemplate.edit.cancel"].tap()
    }

    func testTemplateEditPersistsAllValuesAndCancelKeepsSavedValues() {
        let app = launchApp()
        openShiftTemplates(in: app)
        let initial = createTemplate(
            named: "Gate Edit",
            note: "Initial note",
            colorComponents: (red: 0.85, green: 0.20, blue: 0.70),
            in: app
        )

        openEditor(for: "Gate Edit", in: app)
        replaceText(in: app.textFields["shiftTemplate.name"], with: "Gate Edited")
        expandDetails(in: app)
        let updatedNote = "Edited note\nUnicode café"
        replaceText(in: app.textFields["shiftTemplate.note"], with: updatedNote)
        toggleEnabled(in: app)
        XCTAssertEqual(enabledValue(in: app), "0")
        collapseDetails(in: app)
        let updatedStartTime = adjustTime(buttonIdentifier: "shiftTemplate.startTime", in: app)
        let updatedEndTime = adjustTime(buttonIdentifier: "shiftTemplate.endTime", in: app)
        let updatedColor = selectColor(
            red: 0.10,
            green: 0.45,
            blue: 0.95,
            in: app
        )
        XCTAssertNotEqual(updatedStartTime, initial.start)
        XCTAssertNotEqual(updatedEndTime, initial.end)
        XCTAssertNotEqual(updatedColor, initial.color)
        app.buttons["shiftTemplate.edit.save"].tap()

        let editedRow = templateRow(named: "Gate Edited", in: app)
        scrollUntilHittable(editedRow, in: app)
        XCTAssertFalse(templateRow(named: "Gate Edit", in: app).exists)
        XCTAssertEqual(matchingRows(named: "Gate Edited", in: app).count, 1)
        openEditor(for: "Gate Edited", in: app)
        XCTAssertEqual(app.textFields["shiftTemplate.name"].value as? String, "Gate Edited")
        XCTAssertFalse(app.textFields["shiftTemplate.note"].exists)
        expandDetails(in: app)
        XCTAssertEqual(app.textFields["shiftTemplate.note"].value as? String, updatedNote)
        XCTAssertEqual(enabledValue(in: app), "0")
        attachScreenshot(named: "shift-template-edit-reopen", app: app)
        collapseDetails(in: app)
        XCTAssertEqual(app.buttons["shiftTemplate.startTime"].label, updatedStartTime)
        XCTAssertEqual(app.buttons["shiftTemplate.endTime"].label, updatedEndTime)
        XCTAssertEqual(colorValue(in: app), updatedColor)

        let nameField = app.textFields["shiftTemplate.name"]
        scrollDownUntilHittable(nameField, in: app)
        replaceText(in: nameField, with: "Cancelled Name")
        expandDetails(in: app)
        replaceText(in: app.textFields["shiftTemplate.note"], with: "Cancelled note")
        toggleEnabled(in: app)
        collapseDetails(in: app)
        let cancelledColor = selectColor(
            red: 0.75,
            green: 0.75,
            blue: 0.10,
            in: app
        )
        XCTAssertNotEqual(cancelledColor, updatedColor)
        app.buttons["shiftTemplate.edit.cancel"].tap()

        XCTAssertFalse(templateRow(named: "Cancelled Name", in: app).exists)
        XCTAssertEqual(matchingRows(named: "Gate Edited", in: app).count, 1)
        openEditor(for: "Gate Edited", in: app)
        XCTAssertEqual(app.textFields["shiftTemplate.name"].value as? String, "Gate Edited")
        expandDetails(in: app)
        XCTAssertEqual(app.textFields["shiftTemplate.note"].value as? String, updatedNote)
        XCTAssertEqual(enabledValue(in: app), "0")
        collapseDetails(in: app)
        XCTAssertEqual(app.buttons["shiftTemplate.startTime"].label, updatedStartTime)
        XCTAssertEqual(app.buttons["shiftTemplate.endTime"].label, updatedEndTime)
        XCTAssertEqual(colorValue(in: app), updatedColor)
        app.buttons["shiftTemplate.edit.cancel"].tap()
    }

    func testCancelNewTemplateDoesNotAddRow() {
        let app = launchApp()
        openShiftTemplates(in: app)
        let initialCount = app.buttons.matching(identifier: "shiftTemplate.edit").count

        app.buttons["shiftTemplate.add"].tap()
        let nameField = app.textFields["shiftTemplate.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        replaceText(in: nameField, with: "Cancelled New Shift")
        expandDetails(in: app)
        replaceText(in: app.textFields["shiftTemplate.note"], with: "Must not be saved")
        app.buttons["shiftTemplate.edit.cancel"].tap()

        XCTAssertFalse(templateRow(named: "Cancelled New Shift", in: app).exists)
        XCTAssertEqual(app.buttons.matching(identifier: "shiftTemplate.edit").count, initialCount)
    }

    func testEmptyNameShowsValidationAndDoesNotDismissEditor() {
        let app = launchApp()
        openShiftTemplates(in: app)
        app.buttons["shiftTemplate.add"].tap()
        let nameField = app.textFields["shiftTemplate.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        replaceText(in: nameField, with: "   ")

        app.buttons["shiftTemplate.edit.save"].tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["Please enter a title"].exists)
        alert.buttons.firstMatch.tap()
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        app.buttons["shiftTemplate.edit.cancel"].tap()
    }

    func testAccessibilityTextKeepsEditorActionsAndDetailsAccessible() {
        let app = launchApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        openShiftTemplates(in: app)
        let add = app.buttons["shiftTemplate.add"]
        scrollUntilHittable(add, in: app)
        add.tap()

        XCTAssertTrue(app.textFields["shiftTemplate.name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["shiftTemplate.edit.cancel"].isHittable)
        XCTAssertTrue(app.buttons["shiftTemplate.edit.save"].isHittable)
        let details = app.buttons["shiftTemplate.details.toggle"]
        scrollUntilHittable(details, in: app)
        XCTAssertFalse(details.label.contains("shift_time."))
        expandDetails(in: app)
        XCTAssertTrue(app.buttons["shiftTemplate.edit.save"].isHittable)
        app.buttons["shiftTemplate.edit.cancel"].tap()
    }

    func testUnusedTemplateDeleteCanCancelThenConfirm() {
        let app = launchApp()
        openShiftTemplates(in: app)
        _ = createTemplate(named: "Gate Unused", note: "Unused note", in: app)
        let favorite = button(identifier: "shiftTemplate.favorite", value: "Gate Unused", in: app)
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))
        favorite.tap()
        XCTAssertTrue(element(in: app, identifier: "shiftTemplate.favoriteSection").waitForExistence(timeout: 5))

        requestDelete(templateNamed: "Gate Unused", in: app)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        deleteAlertButton(identifier: "shiftTemplate.delete.cancel", in: app).tap()
        XCTAssertTrue(templateRow(named: "Gate Unused", in: app).exists)
        XCTAssertTrue(button(identifier: "shiftTemplate.unfavorite", value: "Gate Unused", in: app).exists)

        requestDelete(templateNamed: "Gate Unused", in: app)
        deleteAlertButton(identifier: "shiftTemplate.delete.confirm", in: app).tap()

        XCTAssertTrue(waitForDisappearance(templateRow(named: "Gate Unused", in: app)))
        XCTAssertTrue(waitForDisappearance(element(in: app, identifier: "shiftTemplate.favoriteSection")))
        XCTAssertGreaterThanOrEqual(app.buttons.matching(identifier: "shiftTemplate.edit").count, 2)
        attachScreenshot(named: "shift-template-unused-deleted", app: app)
    }

    func testReferencedTemplateDeletePreservesExistingShiftAndCleansFavorites() {
        let app = launchApp(seedInvalidFavorite: true)
        openShiftTemplates(in: app)
        XCTAssertFalse(element(in: app, identifier: "shiftTemplate.favoriteSection").exists)
        let history = createTemplate(
            named: "History Snapshot Template",
            note: "History template note",
            colorComponents: (red: 0.85, green: 0.20, blue: 0.70),
            adjustStartTime: true,
            adjustEndTime: true,
            in: app
        )

        let favorite = button(
            identifier: "shiftTemplate.favorite",
            value: "History Snapshot Template",
            in: app
        )
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))
        favorite.tap()
        XCTAssertTrue(element(in: app, identifier: "shiftTemplate.favoriteSection").waitForExistence(timeout: 5))
        closeTemplatesAndSettings(in: app)

        openShiftInput(in: app)
        let option = app.buttons["History Snapshot Template"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        XCTAssertTrue(app.buttons["modal.close"].waitForExistence(timeout: 5))
        app.buttons["modal.close"].tap()
        XCTAssertTrue(app.staticTexts["History Snapshot Template"].waitForExistence(timeout: 8))

        app.buttons["Week"].tap()
        XCTAssertTrue(app.buttons["History Snapshot Template"].waitForExistence(timeout: 8))
        app.buttons["Month"].tap()
        let historicalShift = app.staticTexts["History Snapshot Template"]
        XCTAssertTrue(historicalShift.waitForExistence(timeout: 8))
        historicalShift.tap()
        XCTAssertTrue(element(in: app, identifier: "dayDetail.content").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["\(history.start) - \(history.end)"].waitForExistence(timeout: 5))
        app.buttons["event.edit"].firstMatch.tap()
        XCTAssertTrue(element(in: app, identifier: "entry.editor").waitForExistence(timeout: 5))
        let updatedStart = adjustEventStartTime(currentLabel: history.start, in: app)
        app.buttons["entry.editor.save"].tap()
        XCTAssertTrue(app.staticTexts["\(updatedStart) - \(history.end)"].waitForExistence(timeout: 8))
        app.buttons["modal.close"].tap()
        XCTAssertTrue(app.staticTexts["History Snapshot Template"].waitForExistence(timeout: 8))

        openShiftTemplates(in: app)
        requestDelete(templateNamed: "History Snapshot Template", in: app)
        let deleteAlert = app.alerts.firstMatch
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 5))
        let alertText = deleteAlert.staticTexts.allElementsBoundByIndex
            .map(\.label)
            .joined(separator: " ")
        XCTAssertTrue(alertText.contains("1"))
        deleteAlertButton(identifier: "shiftTemplate.delete.cancel", in: app).tap()
        XCTAssertTrue(templateRow(named: "History Snapshot Template", in: app).exists)

        requestDelete(templateNamed: "History Snapshot Template", in: app)
        deleteAlertButton(identifier: "shiftTemplate.delete.confirm", in: app).tap()
        XCTAssertTrue(waitForDisappearance(templateRow(named: "History Snapshot Template", in: app)))
        XCTAssertTrue(waitForDisappearance(element(in: app, identifier: "shiftTemplate.favoriteSection")))
        closeTemplatesAndSettings(in: app)

        let preservedShift = app.staticTexts["History Snapshot Template"]
        XCTAssertTrue(preservedShift.waitForExistence(timeout: 8))
        preservedShift.tap()
        XCTAssertTrue(app.staticTexts["History Snapshot Template"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["\(updatedStart) - \(history.end)"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.alerts.count, 0)
        attachScreenshot(named: "shift-template-referenced-event-preserved", app: app)
        app.buttons["event.delete"].firstMatch.tap()
        app.buttons["modal.close"].tap()
        XCTAssertFalse(app.staticTexts["History Snapshot Template"].waitForExistence(timeout: 5))
    }

    private func launchApp(
        seedInvalidFavorite: Bool = false,
        contentSizeCategory: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetUITestData",
            "-mockCloudKitState", "available",
            "-uiTestLanguage", "enUS"
        ]
        if seedInvalidFavorite {
            app.launchArguments.append("-seedInvalidShiftTemplateFavorite")
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

    private func openShiftInput(in app: XCUIApplication) {
        app.buttons["calendar.moreMenu"].tap()
        let open = app.buttons["Shift Input"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        XCTAssertTrue(app.buttons["modal.close"].waitForExistence(timeout: 5))
    }

    private func createTemplate(
        named name: String,
        note: String = "",
        colorComponents: (red: CGFloat, green: CGFloat, blue: CGFloat)? = nil,
        adjustStartTime: Bool = false,
        adjustEndTime: Bool = false,
        disableTemplate: Bool = false,
        in app: XCUIApplication
    ) -> TemplateEditorSnapshot {
        let add = app.buttons["shiftTemplate.add"]
        scrollUntilHittable(add, in: app)
        add.tap()
        let nameField = app.textFields["shiftTemplate.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        replaceText(in: nameField, with: name)
        XCTAssertFalse(app.textFields["shiftTemplate.note"].exists)
        if !note.isEmpty || disableTemplate {
            expandDetails(in: app)
            let noteField = app.textFields["shiftTemplate.note"]
            replaceText(in: noteField, with: note)
            if disableTemplate {
                toggleEnabled(in: app)
                XCTAssertEqual(enabledValue(in: app), "0")
            }
            collapseDetails(in: app)
            XCTAssertFalse(noteField.exists)
        }
        let initialColor = colorValue(in: app)
        var selectedColor = initialColor
        if let colorComponents {
            selectedColor = selectColor(
                red: colorComponents.red,
                green: colorComponents.green,
                blue: colorComponents.blue,
                in: app
            )
            XCTAssertNotEqual(selectedColor, initialColor)
        }
        var startTime = app.buttons["shiftTemplate.startTime"].label
        var endTime = app.buttons["shiftTemplate.endTime"].label
        if adjustStartTime {
            startTime = adjustTime(
                buttonIdentifier: "shiftTemplate.startTime",
                wheelX: 0.38,
                in: app
            )
        }
        if adjustEndTime {
            endTime = adjustTime(
                buttonIdentifier: "shiftTemplate.endTime",
                wheelX: 0.62,
                in: app
            )
        }
        app.buttons["shiftTemplate.edit.save"].tap()
        scrollUntilHittable(templateRow(named: name, in: app), in: app)
        return TemplateEditorSnapshot(start: startTime, end: endTime, color: selectedColor)
    }

    private func openEditor(for name: String, in app: XCUIApplication) {
        let edit = button(identifier: "shiftTemplate.edit", value: name, in: app)
        scrollUntilHittable(edit, in: app)
        edit.tap()
        XCTAssertTrue(app.textFields["shiftTemplate.name"].waitForExistence(timeout: 5))
    }

    private func expandDetails(in app: XCUIApplication) {
        dismissKeyboardIfNeeded(in: app)
        let toggle = app.buttons["shiftTemplate.details.toggle"]
        scrollUntilHittable(toggle, in: app)
        toggle.tap()
        XCTAssertTrue(app.textFields["shiftTemplate.note"].waitForExistence(timeout: 5))
    }

    private func collapseDetails(in app: XCUIApplication) {
        dismissKeyboardIfNeeded(in: app)
        let toggle = app.buttons["shiftTemplate.details.toggle"]
        scrollDownUntilHittable(toggle, in: app)
        toggle.tap()
        XCTAssertFalse(app.textFields["shiftTemplate.note"].exists)
    }

    private func toggleEnabled(in app: XCUIApplication) {
        dismissKeyboardIfNeeded(in: app)
        let enabled = app.switches["shiftTemplate.enabled"]
        scrollUntilHittable(enabled, in: app)
        let originalValue = enabled.value as? String
        enabled.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let changed = NSPredicate { element, _ in
            (element as? XCUIElement)?.value as? String != originalValue
        }
        let expectation = XCTNSPredicateExpectation(predicate: changed, object: enabled)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 2), .completed)
    }

    private func enabledValue(in app: XCUIApplication) -> String? {
        let enabled = app.switches["shiftTemplate.enabled"]
        scrollUntilHittable(enabled, in: app)
        return enabled.value as? String
    }

    private func dismissKeyboardIfNeeded(in app: XCUIApplication) {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        let dismissKey = app.buttons["shiftTemplate.keyboard.done"]
        XCTAssertTrue(dismissKey.waitForExistence(timeout: 2))
        dismissKey.tap()
        XCTAssertFalse(keyboard.waitForExistence(timeout: 2))
    }

    private func requestDelete(templateNamed name: String, in app: XCUIApplication) {
        let delete = button(identifier: "shiftTemplate.delete", value: name, in: app)
        scrollUntilHittable(delete, in: app)
        delete.tap()
        XCTAssertTrue(deleteAlertButton(identifier: "shiftTemplate.delete.cancel", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(deleteAlertButton(identifier: "shiftTemplate.delete.confirm", in: app).exists)
    }

    private func colorValue(in app: XCUIApplication) -> String {
        let picker = element(in: app, identifier: "shiftTemplate.colorPicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        guard let value = picker.value as? String else {
            XCTFail("Shift template color picker must expose its selected hex value")
            return ""
        }
        XCTAssertTrue(value.hasPrefix("#"))
        return value
    }

    private func selectColor(
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        in app: XCUIApplication
    ) -> String {
        let picker = element(in: app, identifier: "shiftTemplate.colorPicker")
        let initialValue = colorValue(in: app)
        picker.tap()

        let mode = app.segmentedControls.firstMatch
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        XCTAssertEqual(mode.buttons.count, 3)
        mode.buttons.element(boundBy: 2).tap()

        let redSlider = app.sliders["sliderRed"].firstMatch
        let greenSlider = app.sliders["sliderGreen"].firstMatch
        let blueSlider = app.sliders["sliderBlue"].firstMatch
        for slider in [redSlider, greenSlider, blueSlider] {
            XCTAssertTrue(slider.waitForExistence(timeout: 5))
            XCTAssertTrue(slider.isEnabled)
        }
        redSlider.adjust(toNormalizedSliderPosition: red)
        greenSlider.adjust(toNormalizedSliderPosition: green)
        blueSlider.adjust(toNormalizedSliderPosition: blue)

        // Compact devices present the system picker full-screen with a localized
        // Close button; larger devices dismiss its popover by tapping outside.
        let systemCloseLabels = ["Close", "关闭", "關閉", "閉じる", "닫기"]
        let systemClose = app.buttons
            .matching(NSPredicate(format: "label IN %@", systemCloseLabels))
            .firstMatch
        if systemClose.exists {
            systemClose.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.17)).tap()
        }
        XCTAssertFalse(mode.waitForExistence(timeout: 2))

        let selectedValue = colorValue(in: app)
        XCTAssertNotEqual(selectedValue, initialValue)
        return selectedValue
    }

    private func adjustTime(
        buttonIdentifier: String,
        wheelX: CGFloat = 0.38,
        in app: XCUIApplication
    ) -> String {
        let button = app.buttons[buttonIdentifier]
        let initialValue = button.label
        button.tap()

        let isHourWheel = wheelX < 0.5
        let wheel = app.pickerWheels.element(boundBy: isHourWheel ? 0 : 1)
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        let currentComponent = Int(wheel.value as? String ?? "") ?? 0
        let componentRange = isHourWheel ? 24 : 60
        let nextComponent = String(format: "%02d", (currentComponent + 1) % componentRange)
        wheel.adjust(toPickerWheelValue: nextComponent)
        XCTAssertEqual(wheel.value as? String, nextComponent)
        app.buttons["picker.confirm"].tap()

        XCTAssertTrue(button.waitForExistence(timeout: 5))
        let adjustedValue = button.label
        XCTAssertNotEqual(adjustedValue, initialValue)
        return adjustedValue
    }

    private func adjustEventStartTime(
        currentLabel: String,
        in app: XCUIApplication
    ) -> String {
        let editor = element(in: app, identifier: "entry.editor")
        let button = editor.buttons[currentLabel]
        let scrollView = editor.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        for _ in 0..<12 where !button.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(button.isHittable)
        button.tap()

        let hourWheel = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(hourWheel.waitForExistence(timeout: 5))
        let currentHour = Int(hourWheel.value as? String ?? "") ?? 0
        let nextHour = String(format: "%02d", (currentHour + 1) % 24)
        hourWheel.adjust(toPickerWheelValue: nextHour)
        XCTAssertEqual(hourWheel.value as? String, nextHour)
        app.buttons["picker.confirm"].tap()

        let minute = currentLabel.split(separator: ":").last.map(String.init) ?? "00"
        return "\(nextHour):\(minute)"
    }

    private func closeTemplatesAndSettings(in app: XCUIApplication) {
        let list = element(in: app, identifier: "shiftTemplate.list")
        app.buttons["modal.close"].tap()
        XCTAssertFalse(list.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["modal.close"].waitForExistence(timeout: 5))
        app.buttons["modal.close"].tap()
        XCTAssertTrue(app.buttons["calendar.moreMenu"].waitForExistence(timeout: 5))
    }

    private func replaceText(in field: XCUIElement, with value: String) {
        if let currentValue = field.value as? String, !currentValue.isEmpty {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.80)).tap()
            field.typeText(
                String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count + 1)
            )
        } else {
            field.tap()
        }
        field.typeText(value)
    }

    private func matchingRows(named name: String, in app: XCUIApplication) -> XCUIElementQuery {
        app.scrollViews.firstMatch.staticTexts.matching(NSPredicate(format: "label == %@", name))
    }

    private func templateRow(named name: String, in app: XCUIApplication) -> XCUIElement {
        matchingRows(named: name, in: app).firstMatch
    }

    private func button(identifier: String, value: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons
            .matching(identifier: identifier)
            .matching(NSPredicate(format: "value == %@", value))
            .firstMatch
    }

    private func deleteAlertButton(identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.alerts.firstMatch.buttons.matching(identifier: identifier).firstMatch
    }

    private func element(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        let scrollView = scrollContainer(in: app)
        for _ in 0..<12 where !element.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func scrollDownUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        let scrollView = scrollContainer(in: app)
        for _ in 0..<12 where !element.isHittable {
            scrollView.swipeDown()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func scrollContainer(in app: XCUIApplication) -> XCUIElement {
        let collectionView = app.collectionViews.firstMatch
        if collectionView.exists {
            return collectionView
        }
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        return scrollView
    }

    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
