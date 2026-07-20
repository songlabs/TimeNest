import XCTest

final class TimeNestShiftBatchUITests: XCTestCase {
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

    func testSelectMultipleDatesAndApplyTemplate() {
        let app = launchApp()
        openShiftBatch(in: app)
        selectAdditionalDate(in: app)

        app.buttons["shiftBatch.previewButton"].tap()
        XCTAssertTrue(element(in: app, identifier: "shiftBatch.preview").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["shiftBatch.confirm"].isEnabled)
        app.buttons["shiftBatch.confirm"].tap()

        XCTAssertTrue(element(in: app, identifier: "shiftBatch.result").waitForExistence(timeout: 8))
    }

    func testCopyPreviousDayPreviewShowsConflictAsSkipped() {
        let app = launchApp(seedBatchScenario: true)
        openShiftBatch(in: app)
        app.buttons["shiftBatch.copyPreviousDay"].tap()
        app.buttons["shiftBatch.previewButton"].tap()

        XCTAssertTrue(element(in: app, identifier: "shiftBatch.preview").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["shiftBatch.confirm"].isEnabled)
    }

    func testCopyPreviousWeekPreviewShowsNoSource() {
        let app = launchApp(seedBatchScenario: true)
        openShiftBatch(in: app)
        app.buttons["shiftBatch.copyPreviousWeek"].tap()
        app.buttons["shiftBatch.previewButton"].tap()

        XCTAssertTrue(element(in: app, identifier: "shiftBatch.preview").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["shiftBatch.confirm"].isEnabled)
    }

    func testRotationPreviewIncludesRangeAndCanCreateRows() {
        let app = launchApp(seedBatchScenario: true)
        openShiftBatch(in: app)
        app.buttons["shiftBatch.rotation"].firstMatch.tap()
        XCTAssertTrue(element(in: app, identifier: "shiftBatch.rotation").waitForExistence(timeout: 5))
        app.buttons["shiftBatch.previewButton"].tap()

        XCTAssertTrue(element(in: app, identifier: "shiftBatch.preview").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["shiftBatch.confirm"].isEnabled)
    }

    func testExistingShiftTemplatePreviewDisablesConfirm() {
        let app = launchApp(seedBatchScenario: true)
        openShiftBatch(in: app)
        app.buttons["shiftBatch.previewButton"].tap()

        XCTAssertTrue(element(in: app, identifier: "shiftBatch.preview").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["shiftBatch.confirm"].isEnabled)
    }

    func testConfirmCreatesBatchAndShowsResultBanner() {
        let app = launchApp()
        openShiftBatch(in: app)
        app.buttons["shiftBatch.previewButton"].tap()
        XCTAssertTrue(app.buttons["shiftBatch.confirm"].waitForExistence(timeout: 5))

        app.buttons["shiftBatch.confirm"].tap()

        let result = element(in: app, identifier: "shiftBatch.result")
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertFalse(result.label.contains("shift_batch."))
    }

    func testUndoRemovesLatestBatch() {
        let app = launchApp()
        openShiftBatch(in: app)
        app.buttons["shiftBatch.previewButton"].tap()
        app.buttons["shiftBatch.confirm"].tap()
        let undo = app.buttons["shiftBatch.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 8))

        undo.tap()

        XCTAssertFalse(app.buttons["shiftBatch.undo"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(in: app, identifier: "shiftBatch.result").exists)
    }

    func testCancelDoesNotShowResultOrWriteData() {
        let app = launchApp()
        openShiftBatch(in: app)

        app.buttons["shiftBatch.cancel"].tap()

        XCTAssertTrue(app.buttons["calendar.moreMenu"].waitForExistence(timeout: 5))
        XCTAssertFalse(element(in: app, identifier: "shiftBatch.result").exists)
    }

    func testSmallScreenXXXLKeepsPreviewAndCancelAccessible() {
        let app = launchApp(
            theme: "light",
            contentSizeCategory: "UICTContentSizeCategoryXXXL"
        )
        openShiftBatch(in: app)

        XCTAssertTrue(app.buttons["shiftBatch.previewButton"].isHittable)
        XCTAssertTrue(app.buttons["shiftBatch.cancel"].isHittable)

        app.buttons["shiftBatch.previewButton"].tap()
        let confirm = app.buttons["shiftBatch.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertTrue(confirm.isHittable)
        confirm.tap()

        let undo = app.buttons["shiftBatch.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 8))
        XCTAssertTrue(undo.isHittable)
    }

    func testDarkAccessibilityTextKeepsPreviewAndCancelAccessible() {
        let app = launchApp(
            theme: "dark",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        openShiftBatch(in: app)

        XCTAssertTrue(app.buttons["shiftBatch.previewButton"].isHittable)
        XCTAssertTrue(app.buttons["shiftBatch.cancel"].isHittable)
    }

    func testFiveLanguagesDoNotExposeLocalizationKeys() {
        for language in ["ja", "zhHans", "zh-Hant", "enUS", "ko"] {
            let app = launchApp(language: language)
            openShiftBatch(in: app)

            for identifier in ["shiftBatch.selectedCount", "shiftBatch.previewButton", "shiftBatch.cancel"] {
                let target = element(in: app, identifier: identifier)
                XCTAssertTrue(target.waitForExistence(timeout: 5), "\(language)-\(identifier)")
                XCTAssertFalse(target.label.isEmpty, "\(language)-\(identifier)")
                XCTAssertFalse(target.label.contains("shift_batch."), "\(language)-\(identifier)")
            }
            app.terminate()
        }
    }

    private func launchApp(
        language: String = "enUS",
        seedBatchScenario: Bool = false,
        theme: String? = nil,
        contentSizeCategory: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetUITestData",
            "-mockCloudKitState", "available",
            "-uiTestLanguage", language
        ]
        if seedBatchScenario {
            app.launchArguments.append("-seedShiftBatchScenario")
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
        app.launch()
        XCTAssertTrue(app.buttons["calendar.moreMenu"].waitForExistence(timeout: 10))
        return app
    }

    private func openShiftBatch(in app: XCUIApplication) {
        app.buttons["calendar.moreMenu"].tap()
        let open = app.buttons["shiftBatch.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        XCTAssertTrue(element(in: app, identifier: "shiftBatch.selectedCount").waitForExistence(timeout: 8))
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

    private func selectAdditionalDate(in app: XCUIApplication) {
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'shiftBatch.date.'")
        let buttons = app.buttons.matching(predicate)
        XCTAssertGreaterThan(buttons.count, 1)
        for index in 0..<buttons.count {
            let button = buttons.element(boundBy: index)
            if button.isHittable && !button.isSelected {
                button.tap()
                return
            }
        }
        XCTFail("No additional date button was hittable")
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
            in: app
        )

        XCTAssertTrue(templateRow(named: "UITest Early Shift", in: app).exists)
        XCTAssertEqual(matchingRows(named: "UITest Early Shift", in: app).count, 1)
        openEditor(for: "UITest Early Shift", in: app)
        XCTAssertEqual(app.textFields["shiftTemplate.name"].value as? String, "UITest Early Shift")
        XCTAssertEqual(app.textFields["shiftTemplate.note"].value as? String, note)
        XCTAssertEqual(app.buttons["shiftTemplate.startTime"].label, persisted.start)
        XCTAssertEqual(app.buttons["shiftTemplate.endTime"].label, persisted.end)
        XCTAssertEqual(colorValue(in: app), persisted.color)
        attachScreenshot(named: "shift-template-create-reopen", app: app)
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
        let updatedNote = "Edited note\nUnicode café"
        replaceText(in: app.textFields["shiftTemplate.note"], with: updatedNote)
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
        XCTAssertEqual(app.textFields["shiftTemplate.note"].value as? String, updatedNote)
        XCTAssertEqual(app.buttons["shiftTemplate.startTime"].label, updatedStartTime)
        XCTAssertEqual(app.buttons["shiftTemplate.endTime"].label, updatedEndTime)
        XCTAssertEqual(colorValue(in: app), updatedColor)
        attachScreenshot(named: "shift-template-edit-reopen", app: app)

        replaceText(in: app.textFields["shiftTemplate.name"], with: "Cancelled Name")
        replaceText(in: app.textFields["shiftTemplate.note"], with: "Cancelled note")
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
        XCTAssertEqual(app.textFields["shiftTemplate.note"].value as? String, updatedNote)
        XCTAssertEqual(app.buttons["shiftTemplate.startTime"].label, updatedStartTime)
        XCTAssertEqual(app.buttons["shiftTemplate.endTime"].label, updatedEndTime)
        XCTAssertEqual(colorValue(in: app), updatedColor)
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

        openShiftBatch(in: app)
        let option = button(
            identifier: "shiftBatch.templateOption",
            value: "History Snapshot Template",
            in: app
        )
        scrollUntilHittable(option, in: app)
        option.tap()
        app.buttons["shiftBatch.previewButton"].tap()
        XCTAssertTrue(app.buttons["shiftBatch.confirm"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["shiftBatch.confirm"].isEnabled)
        app.buttons["shiftBatch.confirm"].tap()
        XCTAssertTrue(element(in: app, identifier: "shiftBatch.result").waitForExistence(timeout: 8))
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

        let historicalShift = app.staticTexts["History Snapshot Template"]
        XCTAssertTrue(historicalShift.waitForExistence(timeout: 8))
        historicalShift.tap()
        XCTAssertTrue(app.staticTexts["History Snapshot Template"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["\(history.start) - \(history.end)"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.alerts.count, 0)
        attachScreenshot(named: "shift-template-referenced-event-preserved", app: app)
    }

    private func launchApp(seedInvalidFavorite: Bool = false) -> XCUIApplication {
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

    private func openShiftBatch(in app: XCUIApplication) {
        app.buttons["calendar.moreMenu"].tap()
        XCTAssertTrue(app.buttons["shiftBatch.open"].waitForExistence(timeout: 5))
        app.buttons["shiftBatch.open"].tap()
        XCTAssertTrue(element(in: app, identifier: "shiftBatch.selectedCount").waitForExistence(timeout: 8))
    }

    private func createTemplate(
        named name: String,
        note: String = "",
        colorComponents: (red: CGFloat, green: CGFloat, blue: CGFloat)? = nil,
        adjustStartTime: Bool = false,
        adjustEndTime: Bool = false,
        in app: XCUIApplication
    ) -> TemplateEditorSnapshot {
        let add = app.buttons["shiftTemplate.add"]
        scrollUntilHittable(add, in: app)
        add.tap()
        let nameField = app.textFields["shiftTemplate.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        replaceText(in: nameField, with: name)
        let noteField = app.textFields["shiftTemplate.note"]
        XCTAssertTrue(noteField.exists)
        replaceText(in: noteField, with: note)
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
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        for _ in 0..<12 where !element.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
