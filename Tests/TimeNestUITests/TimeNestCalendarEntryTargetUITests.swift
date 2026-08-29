import XCTest

final class TimeNestCalendarEntryTargetUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testPersonalCalendarCreateAndEditKeepCalendarFixed() {
        let app = launchApp(seedData: true)

        openDirectEntryEditor(in: app)
        assertFixedEditor(in: app)
        replaceText(in: app.textFields["entry.title"], with: "Calendar Target Personal")
        app.buttons["entry.editor.save"].tap()
        XCTAssertTrue(app.staticTexts["Calendar Target Personal"].waitForExistence(timeout: 8))

        openCreatedEventDay(in: app)
        let edit = app.buttons["event.edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        assertFixedEditor(in: app)
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
        openDirectEntryEditor(in: app)
        assertFixedEditor(in: app)
        replaceText(in: app.textFields["entry.title"], with: "Calendar Target Shared")
        app.buttons["entry.editor.save"].tap()

        XCTAssertTrue(app.staticTexts["Calendar Target Shared"].waitForExistence(timeout: 8))
        XCTAssertEqual(selector.label, selectedCalendarLabel)
    }

    func testReceivedCalendarBlocksCreateBeforeEditorInAllLanguages() {
        for language in ["ja", "enUS", "zhHans", "zh-Hant", "ko"] {
            let app = launchApp(sharingScenario: "received", language: language)
            selectCalendar(
                identifier: "sharing.calendar.33333333-3333-3333-3333-333333333333",
                in: app
            )

            switchToDayView(in: app)
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

    func testReceivedCalendarDayDoesNotExposeEventAddAction() {
        let app = launchApp(sharingScenario: "received", language: "ja")
        selectCalendar(
            identifier: "sharing.calendar.33333333-3333-3333-3333-333333333333",
            in: app
        )

        let day = calendarDayElement(for: Date(), in: app)
        XCTAssertTrue(day.waitForExistence(timeout: 8))
        day.tap()

        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(element(in: app, identifier: "dayDetail.content").exists)
        XCTAssertFalse(app.buttons["event.add"].exists)
        XCTAssertFalse(element(in: app, identifier: "entry.editor").exists)
    }

    func testReceivedEditableCalendarUsesSharedEventOnlyEditorInAllLanguages() {
        for language in ["ja", "enUS", "zhHans", "zh-Hant", "ko"] {
            let app = launchApp(sharingScenario: "receivedEditable", language: language)
            selectCalendar(
                identifier: "sharing.calendar.33333333-3333-3333-3333-333333333333",
                in: app
            )

            openDirectEntryEditor(in: app)
            XCTAssertTrue(
                element(in: app, identifier: "sharedEvent.editor")
                    .waitForExistence(timeout: 5),
                language
            )
            XCTAssertTrue(app.textFields["sharedEvent.title"].exists, language)
            XCTAssertTrue(app.buttons["sharedEvent.save"].exists, language)
            XCTAssertFalse(element(in: app, identifier: "entry.editor").exists, language)
            XCTAssertFalse(element(in: app, identifier: "entry.memo.field").exists, language)
            XCTAssertFalse(element(in: app, identifier: "entry.event.reminder").exists, language)
            XCTAssertFalse(element(in: app, identifier: "entry.calendarSelector").exists, language)
            XCTAssertFalse(element(in: app, identifier: "workRecord.editor").exists, language)

            app.buttons["sharedEvent.cancel"].tap()
            XCTAssertTrue(
                element(in: app, identifier: "sharedEvent.editor")
                    .waitForNonExistence(timeout: 5),
                language
            )
            app.terminate()
        }
    }

    func testReceivedEditableCalendarCanCreateEditAndDeleteSharedEvent() {
        let app = launchApp(sharingScenario: "receivedEditable", language: "enUS")
        selectCalendar(
            identifier: "sharing.calendar.33333333-3333-3333-3333-333333333333",
            in: app
        )

        openDirectEntryEditor(in: app)
        XCTAssertTrue(
            element(in: app, identifier: "sharedEvent.editor")
                .waitForExistence(timeout: 5)
        )
        replaceText(in: app.textFields["sharedEvent.title"], with: "Shared UI Created")
        app.buttons["sharedEvent.save"].tap()
        XCTAssertTrue(
            element(in: app, identifier: "sharedEvent.editor")
                .waitForNonExistence(timeout: 8)
        )

        switchToMonthView(in: app)
        let today = calendarDayElement(for: Date(), in: app)
        XCTAssertTrue(today.waitForExistence(timeout: 8))
        today.tap()
        XCTAssertTrue(
            element(in: app, identifier: "sharedEvent.dayDetail")
                .waitForExistence(timeout: 8)
        )
        XCTAssertTrue(app.staticTexts["Shared UI Created"].waitForExistence(timeout: 5))
        app.buttons["sharedEvent.row.edit"].tap()
        replaceText(in: app.textFields["sharedEvent.title"], with: "Shared UI Updated")
        app.buttons["sharedEvent.save"].tap()

        XCTAssertTrue(app.staticTexts["Shared UI Updated"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Shared UI Created"].exists)
        app.buttons["sharedEvent.row.delete"].tap()
        let confirmDelete = app.buttons
            .matching(identifier: "sharedEvent.row.confirmDelete")
            .firstMatch
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
        confirmDelete.tap()

        XCTAssertTrue(app.staticTexts["Shared UI Updated"].waitForNonExistence(timeout: 8))
        XCTAssertFalse(app.buttons["sharedEvent.row.edit"].exists)
        XCTAssertFalse(app.buttons["sharedEvent.row.delete"].exists)
    }

    func testSharedEventSavingAndFailureStatusesAreVisible() {
        let scenarios = [
            ("receivedEditableSaving", "saving"),
            ("receivedEditablePending", "pending"),
            ("receivedEditableFailed", "failed"),
            ("receivedEditablePermissionRevoked", "permissionRevoked"),
            ("receivedEditableDeletedRemotely", "deletedRemotely"),
        ]

        for (scenario, status) in scenarios {
            let app = launchApp(sharingScenario: scenario, language: "enUS")
            selectCalendar(
                identifier: "sharing.calendar.33333333-3333-3333-3333-333333333333",
                in: app
            )
            openDirectEntryEditor(in: app)
            XCTAssertTrue(
                element(in: app, identifier: "sharedEvent.editor")
                    .waitForExistence(timeout: 5),
                scenario
            )
            replaceText(
                in: app.textFields["sharedEvent.title"],
                with: "Status \(status)"
            )
            app.buttons["sharedEvent.save"].tap()
            XCTAssertTrue(
                element(in: app, identifier: "sharedEvent.status.\(status)")
                    .waitForExistence(timeout: 5),
                scenario
            )
            app.terminate()
        }
    }

    func testSharedCalendarEventPermissionPickerDefaultsReadOnlyInAllLanguages() {
        let expectedLabels = [
            "ja": ("閲覧のみ", "予定の編集を許可"),
            "enUS": ("View Only", "Allow Event Editing"),
            "zhHans": ("仅查看", "允许编辑日程"),
            "zh-Hant": ("僅供檢視", "允許編輯行程"),
            "ko": ("보기 전용", "일정 편집 허용"),
        ]

        for language in ["ja", "enUS", "zhHans", "zh-Hant", "ko"] {
            let app = launchApp(language: language)
            app.buttons["sharing.calendarSelector"].tap()
            let create = app.buttons["sharing.empty.create"]
            XCTAssertTrue(create.waitForExistence(timeout: 5), language)
            create.tap()

            XCTAssertTrue(
                element(in: app, identifier: "sharing.createCalendar")
                    .waitForExistence(timeout: 5),
                language
            )
            replaceText(
                in: app.textFields["sharing.createCalendar.name"],
                with: "Small Screen \(language)"
            )
            let labels = expectedLabels[language]!
            let readOnly = app.buttons["sharing.eventPermission.readOnly"]
            let readWrite = app.buttons["sharing.eventPermission.readWrite"]
            let submit = app.buttons["sharing.createCalendar.submit"]
            let form = element(in: app, identifier: "sharing.createCalendar.form")
            XCTAssertTrue(readOnly.exists, language)
            XCTAssertTrue(readWrite.exists, language)
            XCTAssertEqual(readOnly.label, labels.0, language)
            XCTAssertEqual(readWrite.label, labels.1, language)
            XCTAssertTrue(submit.exists, language)
            XCTAssertTrue(form.exists, language)
            XCTAssertTrue(readOnly.isSelected, language)
            XCTAssertFalse(readWrite.isSelected, language)
            XCTAssertTrue(submit.isHittable, language)

            scrollUntilUnobscured(readWrite, by: submit, in: form)
            XCTAssertTrue(readWrite.isHittable, language)
            XCTAssertLessThanOrEqual(readWrite.frame.maxY, submit.frame.minY, language)
            readWrite.tap()
            XCTAssertTrue(waitForSelection(readWrite, selected: true), language)

            XCTAssertTrue(submit.isHittable, language)
            submit.tap()
            let error = app.alerts.firstMatch
            XCTAssertTrue(error.waitForExistence(timeout: 5), language)
            error.buttons.firstMatch.tap()
            app.terminate()
        }
    }

    func testSharedCalendarEditPermissionAndSaveStayReachableInAllLanguages() {
        let expectedLabels = [
            "ja": ("閲覧のみ", "予定の編集を許可"),
            "enUS": ("View Only", "Allow Event Editing"),
            "zhHans": ("仅查看", "允许编辑日程"),
            "zh-Hant": ("僅供檢視", "允許編輯行程"),
            "ko": ("보기 전용", "일정 편집 허용"),
        ]
        let calendarID = "22222222-2222-2222-2222-222222222222"

        for language in ["ja", "enUS", "zhHans", "zh-Hant", "ko"] {
            let app = launchApp(sharingScenario: "acceptedEditable", language: language)
            app.buttons["sharing.calendarSelector"].tap()
            let edit = app.buttons["sharing.calendar.edit.\(calendarID)"]
            XCTAssertTrue(edit.waitForExistence(timeout: 5), language)
            edit.tap()

            let labels = expectedLabels[language]!
            let readOnly = app.buttons["sharing.eventPermission.readOnly"]
            let readWrite = app.buttons["sharing.eventPermission.readWrite"]
            let submit = app.buttons["sharing.editCalendar.submit"]
            let form = element(in: app, identifier: "sharing.editCalendar.form")
            XCTAssertTrue(readOnly.waitForExistence(timeout: 5), language)
            XCTAssertTrue(readWrite.exists, language)
            XCTAssertEqual(readOnly.label, labels.0, language)
            XCTAssertEqual(readWrite.label, labels.1, language)
            XCTAssertTrue(submit.exists, language)
            XCTAssertTrue(form.exists, language)
            XCTAssertFalse(readOnly.isSelected, language)
            XCTAssertTrue(readWrite.isSelected, language)
            scrollUntilUnobscured(readOnly, by: submit, in: form)
            XCTAssertTrue(readOnly.isHittable, language)
            XCTAssertLessThanOrEqual(readOnly.frame.maxY, submit.frame.minY, language)
            readOnly.tap()
            XCTAssertTrue(waitForSelection(readOnly, selected: true), language)

            XCTAssertTrue(submit.isHittable, language)
            submit.tap()
            let error = app.alerts.firstMatch
            XCTAssertTrue(error.waitForExistence(timeout: 5), language)
            error.buttons.firstMatch.tap()
            app.terminate()
        }
    }

    func testGeneralCreateUsesCompactEventFirstLayoutAndExpandsWorkRecordInPlace() {
        let app = launchApp()
        openDirectEntryEditor(in: app)
        assertFixedEditor(in: app)

        XCTAssertFalse(element(in: app, identifier: "entry.kind").exists)
        XCTAssertFalse(
            element(in: app, identifier: "entry.event.toggle").exists
        )
        XCTAssertTrue(
            element(in: app, identifier: "event.editor")
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(
            element(in: app, identifier: "workRecord.editor").exists
        )
        XCTAssertTrue(app.textFields["entry.title"].exists)
        XCTAssertFalse(app.textFields["workRecord.title"].exists)
        XCTAssertTrue(
            element(in: app, identifier: "entry.event.allDay").exists
        )
        XCTAssertTrue(
            element(in: app, identifier: "entry.event.reminder").exists
        )
        XCTAssertTrue(
            element(in: app, identifier: "entry.event.start.date").exists
        )
        XCTAssertTrue(
            element(in: app, identifier: "entry.event.start.time").exists
        )
        XCTAssertTrue(
            element(in: app, identifier: "entry.event.end.date").exists
        )
        XCTAssertTrue(
            element(in: app, identifier: "entry.event.end.time").exists
        )

        let workRecord = app.switches["entry.workRecord.toggle"].firstMatch
        scrollUntilHittable(workRecord, in: app)
        XCTAssertEqual(workRecord.value as? String, "0")
        workRecord.tap()
        XCTAssertTrue(
            element(in: app, identifier: "workRecord.editor")
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(element(in: app, identifier: "event.editor").exists)
        XCTAssertFalse(app.textFields["workRecord.title"].exists)
        XCTAssertEqual(
            element(in: app, identifier: "workRecord.clockIn.date").label,
            element(in: app, identifier: "entry.event.start.date").label
        )
        XCTAssertEqual(
            element(in: app, identifier: "workRecord.clockIn.time").label,
            element(in: app, identifier: "entry.event.start.time").label
        )
        XCTAssertEqual(
            element(in: app, identifier: "workRecord.clockOut.date").label,
            element(in: app, identifier: "entry.event.end.date").label
        )
        XCTAssertEqual(
            element(in: app, identifier: "workRecord.clockOut.time").label,
            element(in: app, identifier: "entry.event.end.time").label
        )
        for identifier in [
            "workRecord.restTime",
            "workRecord.transportFee",
            "workRecord.hourlyRate"
        ] {
            let field = element(in: app, identifier: identifier)
            scrollUntilHittable(field, in: app)
            XCTAssertTrue(field.exists, identifier)
        }
        XCTAssertFalse(element(in: app, identifier: "entry.calendarSelector").exists)
        app.buttons["entry.editor.cancel"].tap()
    }

    func testEmptyDayEditorCanExpandWorkRecordInPlace() {
        let app = launchApp(seedData: true)
        openEmptyDayEditor(in: app)
        assertFixedEditor(in: app)

        XCTAssertTrue(element(in: app, identifier: "event.editor").exists)
        XCTAssertFalse(element(in: app, identifier: "workRecord.editor").exists)
        XCTAssertTrue(app.textFields["entry.title"].exists)
        XCTAssertFalse(app.textFields["workRecord.title"].exists)

        let workToggle = app.switches["entry.workRecord.toggle"].firstMatch
        scrollUntilHittable(workToggle, in: app)
        XCTAssertEqual(workToggle.value as? String, "0")
        workToggle.tap()

        XCTAssertTrue(
            element(in: app, identifier: "workRecord.editor")
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(element(in: app, identifier: "event.editor").exists)
        XCTAssertTrue(app.textFields["entry.title"].exists)
        XCTAssertFalse(app.textFields["workRecord.title"].exists)
        XCTAssertFalse(
            element(in: app, identifier: "entry.event.toggle").exists
        )
        app.buttons["entry.editor.cancel"].tap()
    }

    func testSmallScreenAccessibilityXXXLKeepsFixedEditorActionsReachable() {
        let app = launchApp(
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL",
            language: "ja"
        )
        openDirectEntryEditor(in: app)
        assertFixedEditor(in: app)

        XCTAssertTrue(app.buttons["entry.editor.cancel"].isHittable)
        XCTAssertTrue(app.buttons["entry.editor.save"].isHittable)
        let workRecordToggle = app.switches["entry.workRecord.toggle"].firstMatch
        scrollUntilHittable(workRecordToggle, in: app)
        XCTAssertTrue(workRecordToggle.isHittable)
        workRecordToggle.tap()

        for identifier in [
            "workRecord.clockIn.date",
            "workRecord.clockIn.time",
            "workRecord.restTime",
            "workRecord.clockOut.date",
            "workRecord.clockOut.time",
            "workRecord.transportFee",
            "workRecord.hourlyRate",
            "entry.memo.field"
        ] {
            XCTAssertTrue(
                element(in: app, identifier: identifier)
                    .waitForExistence(timeout: 5),
                identifier
            )
        }
        scrollUntilHittable(
            element(in: app, identifier: "entry.memo.field"),
            in: app
        )
        captureScreenshot(named: "05-small-screen", app: app)
        XCTAssertTrue(app.buttons["entry.editor.cancel"].isHittable)
        XCTAssertTrue(app.buttons["entry.editor.save"].isHittable)
    }

    func testUnifiedEditorVisualGeneralStates() {
        let app = launchApp(language: "ja")
        openDirectEntryEditor(in: app)
        assertFixedEditor(in: app)
        captureScreenshot(named: "01-general-work-off", app: app)

        let workToggle = app.switches["entry.workRecord.toggle"].firstMatch
        scrollUntilHittable(workToggle, in: app)
        workToggle.tap()
        let clockOut = element(
            in: app,
            identifier: "workRecord.clockOut.time"
        )
        scrollUntilHittable(clockOut, in: app)
        captureScreenshot(named: "02-general-work-on", app: app)
        dismissEditor(in: app)
    }

    func testUnifiedEditorVisualWorkRecordExpanded() {
        let app = launchApp(seedData: true, language: "ja")
        openEmptyDayEditor(in: app)
        let workToggle = app.switches["entry.workRecord.toggle"].firstMatch
        scrollUntilHittable(workToggle, in: app)
        workToggle.tap()
        XCTAssertTrue(
            element(in: app, identifier: "workRecord.editor")
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(element(in: app, identifier: "event.editor").exists)
        captureScreenshot(named: "03-work-record-expanded", app: app)
        dismissEditor(in: app)
    }

    func testUnifiedEditorVisualLinkedEdit() {
        let app = launchApp(seedUnifiedEntry: true, language: "ja")
        openCreatedEventDay(in: app)
        let edit = app.buttons["event.edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        assertBothExistingSections(in: app)
        let linkedClockOut = element(
            in: app,
            identifier: "workRecord.clockOut.time"
        )
        scrollUntilHittable(linkedClockOut, in: app)
        captureScreenshot(named: "04-linked-entry-edit", app: app)
        dismissEditor(in: app)
    }

    func testUnifiedEditorDarkModeVisualReference() {
        let app = launchApp(language: "ja", theme: "dark")
        openDirectEntryEditor(in: app)
        assertFixedEditor(in: app)
        captureScreenshot(named: "06-dark-mode", app: app)
        dismissEditor(in: app)
    }

    func testExistingStandaloneEventKeepsAddButtonVisible() {
        let app = launchApp(language: "ja")
        openDirectEntryEditor(in: app)
        replaceText(
            in: app.textFields["entry.title"],
            with: "Standalone UI Event"
        )
        app.buttons["entry.editor.save"].tap()
        XCTAssertTrue(
            app.staticTexts["Standalone UI Event"]
                .waitForExistence(timeout: 8)
        )

        openCreatedEventDay(in: app)

        XCTAssertEqual(
            app.staticTexts.matching(identifier: "event.primaryContent").count,
            1
        )
        XCTAssertTrue(app.buttons["event.add"].waitForExistence(timeout: 5))
        captureScreenshot(named: "10-existing-event-add-visible", app: app)
    }

    func testDayDetailAddsIndependentSecondAndThirdEvents() {
        let app = launchApp(seedUnifiedEntry: true, language: "ja")
        let today = Date()
        openCreatedEventDay(in: app)

        XCTAssertEqual(
            app.staticTexts.matching(identifier: "event.primaryContent").count,
            1
        )
        XCTAssertEqual(
            app.staticTexts.matching(identifier: "event.linkedWorkRecord").count,
            1
        )
        XCTAssertTrue(app.buttons["event.add"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "event.add").count, 1)
        XCTAssertFalse(element(in: app, identifier: "workRecord.list").exists)
        XCTAssertFalse(app.buttons["workRecord.add"].exists)
        captureScreenshot(named: "11-linked-entry-add-visible", app: app)

        createEventFromDayDetail(
            title: "Second UI Event",
            existingTitle: "Linked UI Event",
            in: app
        )

        XCTAssertTrue(
            eventTitle("Second UI Event", in: app)
                .waitForExistence(timeout: 8)
        )
        XCTAssertEqual(
            app.staticTexts.matching(identifier: "event.primaryContent").count,
            2
        )
        XCTAssertEqual(
            app.staticTexts.matching(identifier: "event.linkedWorkRecord").count,
            1
        )
        XCTAssertTrue(app.buttons["event.add"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "event.add").count, 1)
        captureScreenshot(named: "12-two-events-day-detail", app: app)

        app.buttons["modal.close"].tap()
        XCTAssertTrue(
            element(in: app, identifier: "dayDetail.content")
                .waitForNonExistence(timeout: 5)
        )
        let todayCell = calendarDayElement(for: today, in: app)
        XCTAssertEqual(
            todayCell.descendants(matching: .staticText)
                .matching(NSPredicate(format: "label == %@", "Linked UI Event"))
                .count,
            1
        )
        XCTAssertEqual(
            todayCell.descendants(matching: .staticText)
                .matching(NSPredicate(format: "label == %@", "Second UI Event"))
                .count,
            1
        )
        XCTAssertEqual(
            todayCell.descendants(matching: .staticText)
                .matching(NSPredicate(format: "label == %@", "勤務記録"))
                .count,
            0
        )
        captureScreenshot(named: "13-two-events-month", app: app)

        todayCell.tap()
        XCTAssertTrue(
            element(in: app, identifier: "dayDetail.content")
                .waitForExistence(timeout: 8)
        )
        let linkedTitle = eventTitle("Linked UI Event", in: app)
        scrollUntilHittable(linkedTitle, in: app)
        linkedTitle.tap()
        assertBothExistingSections(in: app)
        app.buttons["entry.editor.cancel"].tap()

        createEventFromDayDetail(
            title: "Third UI Event",
            existingTitle: "Second UI Event",
            in: app
        )
        XCTAssertTrue(
            eventTitle("Third UI Event", in: app)
                .waitForExistence(timeout: 8)
        )
        XCTAssertEqual(
            app.staticTexts.matching(identifier: "event.primaryContent").count,
            3
        )
        XCTAssertTrue(app.buttons["event.add"].exists)

        deleteEvent(named: "Third UI Event", in: app)
        XCTAssertTrue(
            eventTitle("Third UI Event", in: app)
                .waitForNonExistence(timeout: 8)
        )

        let secondTitle = eventTitle("Second UI Event", in: app)
        scrollUntilHittable(secondTitle, in: app)
        secondTitle.tap()
        XCTAssertTrue(
            element(in: app, identifier: "event.editor")
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(element(in: app, identifier: "workRecord.editor").exists)
        XCTAssertEqual(
            app.textFields["entry.title"].value as? String,
            "Second UI Event"
        )
        replaceText(
            in: app.textFields["entry.title"],
            with: "Second UI Event Updated"
        )
        app.buttons["entry.editor.save"].tap()

        XCTAssertTrue(
            eventTitle("Second UI Event Updated", in: app)
                .waitForExistence(timeout: 8)
        )
        XCTAssertTrue(eventTitle("Linked UI Event", in: app).exists)
        XCTAssertEqual(
            app.staticTexts.matching(identifier: "event.linkedWorkRecord").count,
            1
        )

        deleteEvent(named: "Second UI Event Updated", in: app)
        XCTAssertTrue(
            eventTitle("Second UI Event Updated", in: app)
                .waitForNonExistence(timeout: 8)
        )
        XCTAssertTrue(eventTitle("Linked UI Event", in: app).exists)
        XCTAssertEqual(
            app.staticTexts.matching(identifier: "event.primaryContent").count,
            1
        )
        XCTAssertEqual(
            app.staticTexts.matching(identifier: "event.linkedWorkRecord").count,
            1
        )
        XCTAssertTrue(app.buttons["event.add"].exists)
        XCTAssertFalse(element(in: app, identifier: "workRecord.list").exists)
        captureScreenshot(named: "14-second-event-deleted", app: app)
    }

    func testLinkedDayDetailAddButtonDarkModeVisualReference() {
        let app = launchApp(
            seedUnifiedEntry: true,
            language: "ja",
            theme: "dark"
        )
        openCreatedEventDay(in: app)

        XCTAssertTrue(app.buttons["event.add"].waitForExistence(timeout: 5))
        XCTAssertEqual(
            app.staticTexts.matching(identifier: "event.linkedWorkRecord").count,
            1
        )
        captureScreenshot(named: "15-linked-add-dark-mode", app: app)
    }

    func testCombinedEntryReopensFromBothSidesAndRepeatedSaveDoesNotDuplicate() {
        let app = launchApp()
        openDirectEntryEditor(in: app)
        assertFixedEditor(in: app)
        replaceText(
            in: app.textFields["entry.title"],
            with: "UI Linked Event"
        )
        dismissKeyboard(in: app)
        let workToggle = app.switches["entry.workRecord.toggle"].firstMatch
        scrollUntilHittable(workToggle, in: app)
        workToggle.tap()
        XCTAssertFalse(app.textFields["workRecord.title"].exists)
        app.buttons["entry.editor.save"].tap()
        XCTAssertTrue(
            app.staticTexts["UI Linked Event"].waitForExistence(timeout: 8)
        )

        openCreatedEventDay(in: app)
        XCTAssertEqual(app.buttons.matching(identifier: "event.edit").count, 1)
        XCTAssertEqual(
            app.buttons.matching(identifier: "workRecord.edit").count,
            1
        )
        app.buttons["event.edit"].firstMatch.tap()
        assertBothExistingSections(in: app)
        XCTAssertEqual(
            app.textFields["entry.title"].value as? String,
            "UI Linked Event"
        )
        XCTAssertFalse(app.textFields["workRecord.title"].exists)
        replaceText(
            in: app.textFields["entry.title"],
            with: "UI Linked Event Updated"
        )
        dismissKeyboard(in: app)
        app.buttons["entry.editor.save"].tap()

        XCTAssertTrue(
            app.buttons["event.edit"].firstMatch.waitForExistence(timeout: 8)
        )
        XCTAssertEqual(app.buttons.matching(identifier: "event.edit").count, 1)
        XCTAssertEqual(
            app.buttons.matching(identifier: "workRecord.edit").count,
            1
        )
        let workEdit = app.buttons["workRecord.edit"].firstMatch
        scrollUntilHittable(workEdit, in: app)
        workEdit.tap()
        assertBothExistingSections(in: app)
        XCTAssertEqual(
            app.textFields["entry.title"].value as? String,
            "UI Linked Event Updated"
        )
        let workTitle = app.textFields["workRecord.title"]
        XCTAssertEqual(
            workTitle.value as? String,
            "UI Linked Event"
        )
        replaceText(
            in: workTitle,
            with: "UI Linked Work Updated"
        )
        app.buttons["entry.editor.save"].tap()

        XCTAssertTrue(
            app.buttons["event.edit"].firstMatch.waitForExistence(timeout: 8)
        )
        XCTAssertEqual(app.buttons.matching(identifier: "event.edit").count, 1)
        XCTAssertEqual(
            app.buttons.matching(identifier: "workRecord.edit").count,
            1
        )

        let repeatedWorkEdit = app.buttons["workRecord.edit"].firstMatch
        scrollUntilHittable(repeatedWorkEdit, in: app)
        repeatedWorkEdit.tap()
        assertBothExistingSections(in: app)
        XCTAssertEqual(
            app.textFields["entry.title"].value as? String,
            "UI Linked Event Updated"
        )
        XCTAssertEqual(
            app.textFields["workRecord.title"].value as? String,
            "UI Linked Work Updated"
        )
        app.buttons["entry.editor.save"].tap()
        XCTAssertTrue(
            app.buttons["event.edit"].firstMatch.waitForExistence(timeout: 8)
        )
        XCTAssertEqual(app.buttons.matching(identifier: "event.edit").count, 1)
        XCTAssertEqual(
            app.buttons.matching(identifier: "workRecord.edit").count,
            1
        )
    }

    func testLinkedEntryOpensFromWeekAndDayTimelineViews() {
        let app = launchApp(seedUnifiedEntry: true)

        app.buttons["Week"].tap()
        let weekEvent = app.buttons["Linked UI Event"]
        XCTAssertTrue(weekEvent.waitForExistence(timeout: 8))
        weekEvent.tap()
        assertBothExistingSections(in: app)
        app.buttons["entry.editor.cancel"].tap()

        app.buttons["Day"].tap()
        let dayEvent = app.buttons["Linked UI Event"]
        XCTAssertTrue(dayEvent.waitForExistence(timeout: 8))
        dayEvent.tap()
        assertBothExistingSections(in: app)
        app.buttons["entry.editor.cancel"].tap()
    }

    func testLinkedDisplayMergesMonthAndDayDetailAndKeepsStandaloneWork() {
        let app = launchApp(seedUnifiedEntry: true, language: "ja")
        let today = Date()
        let linkedDay = calendarDayElement(for: today, in: app)

        XCTAssertTrue(linkedDay.waitForExistence(timeout: 8))
        XCTAssertEqual(
            linkedDay.descendants(matching: .staticText)
                .matching(NSPredicate(format: "label == %@", "Linked UI Event"))
                .count,
            1
        )
        XCTAssertEqual(
            linkedDay.descendants(matching: .staticText)
                .matching(NSPredicate(format: "label == %@", "勤務記録"))
                .count,
            0
        )
        captureScreenshot(named: "07-linked-month", app: app)

        linkedDay.tap()
        XCTAssertTrue(
            element(in: app, identifier: "dayDetail.content")
                .waitForExistence(timeout: 8)
        )
        XCTAssertEqual(
            app.staticTexts
                .matching(identifier: "event.primaryContent")
                .count,
            1
        )
        XCTAssertTrue(
            element(in: app, identifier: "event.linkedWorkRecord")
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(element(in: app, identifier: "workRecord.list").exists)
        XCTAssertFalse(element(in: app, identifier: "workRecord.empty").exists)
        XCTAssertFalse(app.buttons["workRecord.add"].exists)
        XCTAssertTrue(app.buttons["event.add"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "event.add").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "event.edit").count, 1)
        XCTAssertEqual(
            app.buttons.matching(identifier: "workRecord.edit").count,
            1
        )
        captureScreenshot(named: "08-linked-day-detail", app: app)

        element(in: app, identifier: "event.primaryContent").tap()
        assertBothExistingSections(in: app)
        app.buttons["entry.editor.cancel"].tap()
        app.buttons["modal.close"].tap()
        XCTAssertTrue(
            element(in: app, identifier: "dayDetail.content")
                .waitForNonExistence(timeout: 5)
        )

        let tomorrow = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: today
        )!
        let workOnlyDay = calendarDayElement(for: tomorrow, in: app)
        XCTAssertTrue(workOnlyDay.waitForExistence(timeout: 8))
        workOnlyDay.tap()
        XCTAssertTrue(
            element(in: app, identifier: "workRecord.primaryContent")
                .waitForExistence(timeout: 8)
        )
        XCTAssertTrue(element(in: app, identifier: "event.list").exists)
        XCTAssertFalse(element(in: app, identifier: "event.primaryContent").exists)
        XCTAssertTrue(app.buttons["event.add"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "event.add").count, 1)
        XCTAssertFalse(element(in: app, identifier: "workRecord.empty").exists)
        XCTAssertEqual(
            app.buttons.matching(identifier: "workRecord.edit").count,
            1
        )
        XCTAssertEqual(
            app.buttons.matching(identifier: "workRecord.delete").count,
            1
        )
        captureScreenshot(named: "09-work-only-day-detail", app: app)

        element(in: app, identifier: "workRecord.primaryContent").tap()
        XCTAssertTrue(
            element(in: app, identifier: "workRecord.editor")
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(element(in: app, identifier: "event.editor").exists)
        app.buttons["entry.editor.cancel"].tap()
    }

    func testDeletingEitherSideKeepsOtherEditableAndAllowsReadding() {
        let app = launchApp(seedUnifiedEntry: true)
        openCreatedEventDay(in: app)

        app.buttons["event.delete"].firstMatch.tap()
        XCTAssertTrue(
            app.buttons["event.delete"].firstMatch
                .waitForNonExistence(timeout: 8)
        )
        let retainedWorkEdit = app.buttons["workRecord.edit"].firstMatch
        XCTAssertTrue(retainedWorkEdit.waitForExistence(timeout: 8))
        scrollUntilHittable(retainedWorkEdit, in: app)
        retainedWorkEdit.tap()
        XCTAssertFalse(element(in: app, identifier: "event.editor").exists)
        XCTAssertTrue(
            element(in: app, identifier: "workRecord.editor")
                .waitForExistence(timeout: 5)
        )
        let addEventToggle = element(
            in: app,
            identifier: "entry.event.toggle"
        )
        XCTAssertTrue(addEventToggle.isEnabled)
        addEventToggle.tap()
        replaceText(
            in: app.textFields["entry.title"],
            with: "Re-added UI Event"
        )
        app.buttons["entry.editor.save"].tap()

        XCTAssertTrue(
            app.buttons["event.delete"].firstMatch.waitForExistence(timeout: 8)
        )
        let workDelete = app.buttons["workRecord.delete"].firstMatch
        scrollUntilHittable(workDelete, in: app)
        workDelete.tap()
        XCTAssertTrue(
            app.buttons["workRecord.delete"].firstMatch
                .waitForNonExistence(timeout: 8)
        )
        let retainedEventEdit = app.buttons["event.edit"].firstMatch
        XCTAssertTrue(retainedEventEdit.waitForExistence(timeout: 8))
        retainedEventEdit.tap()
        XCTAssertTrue(
            element(in: app, identifier: "event.editor")
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(
            element(in: app, identifier: "workRecord.editor").exists
        )
        let addWorkToggle = app.switches["entry.workRecord.toggle"].firstMatch
        scrollUntilHittable(addWorkToggle, in: app)
        XCTAssertTrue(addWorkToggle.isEnabled)
        addWorkToggle.tap()
        XCTAssertTrue(
            element(in: app, identifier: "workRecord.editor")
                .waitForExistence(timeout: 5)
        )
        app.buttons["entry.editor.save"].tap()

        XCTAssertTrue(
            app.buttons["workRecord.edit"].firstMatch
                .waitForExistence(timeout: 8)
        )
        XCTAssertEqual(app.buttons.matching(identifier: "event.edit").count, 1)
        XCTAssertEqual(
            app.buttons.matching(identifier: "workRecord.edit").count,
            1
        )
    }

    private func launchApp(
        seedData: Bool = false,
        seedUnifiedEntry: Bool = false,
        sharingScenario: String? = nil,
        contentSizeCategory: String? = nil,
        language: String = "enUS",
        theme: String? = nil
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
        if seedUnifiedEntry {
            app.launchArguments.append("-seedUnifiedEntryScenario")
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
        if let theme {
            app.launchArguments += ["-uiTestTheme", theme]
        }
        app.launch()
        XCTAssertTrue(app.buttons["calendar.moreMenu"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["calendar.photoImport"].waitForExistence(timeout: 10))
        if element(in: app, identifier: "entry.editor").exists {
            dismissEditor(in: app)
        }
        return app
    }

    private func assertFixedEditor(in app: XCUIApplication) {
        XCTAssertTrue(element(in: app, identifier: "entry.editor").waitForExistence(timeout: 5))
        XCTAssertFalse(element(in: app, identifier: "entry.calendarSelector").exists)
        XCTAssertFalse(element(in: app, identifier: "entry.kind").exists)
    }

    private func assertBothExistingSections(in app: XCUIApplication) {
        XCTAssertTrue(
            element(in: app, identifier: "event.editor")
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element(in: app, identifier: "workRecord.editor")
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(
            element(in: app, identifier: "entry.event.toggle").exists
        )
        XCTAssertFalse(
            app.switches["entry.workRecord.toggle"].firstMatch.exists
        )
    }

    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication
    ) {
        let editorScroll = app.scrollViews["entry.editor.scroll"]
        let dayDetailScroll = app.scrollViews["dayDetail.content"]
        let scrollView: XCUIElement
        if editorScroll.exists {
            scrollView = editorScroll
        } else if dayDetailScroll.exists {
            scrollView = dayDetailScroll
        } else {
            scrollView = app.scrollViews.firstMatch
        }
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        for _ in 0..<20 where !element.isHittable {
            scrollView.swipeUp()
        }
        if !element.isHittable {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "scroll-failure-\(element.identifier)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertTrue(
            element.isHittable,
            "Could not make \(element.identifier) hittable; "
                + "exists=\(element.exists), frame=\(element.frame), "
                + "scrollFrame=\(scrollView.frame)"
        )
    }

    private func dismissKeyboard(in app: XCUIApplication) {
        guard app.keyboards.firstMatch.exists else { return }
        for label in ["Done", "完了", "完成", "완료"] {
            let done = app.buttons[label]
            if done.exists {
                done.tap()
                return
            }
        }
    }

    private func dismissEditor(in app: XCUIApplication) {
        let editor = element(in: app, identifier: "entry.editor")
        guard editor.exists else { return }
        app.buttons["entry.editor.cancel"].tap()
        XCTAssertTrue(editor.waitForNonExistence(timeout: 5))
    }

    private func selectCalendar(identifier: String, in app: XCUIApplication) {
        app.buttons["sharing.calendarSelector"].tap()
        let row = app.buttons[identifier]
        XCTAssertTrue(row.waitForExistence(timeout: 10), identifier)
        row.tap()
        XCTAssertTrue(app.buttons["calendar.photoImport"].waitForExistence(timeout: 5))
    }

    private func openDirectEntryEditor(in app: XCUIApplication) {
        switchToDayView(in: app)
        let add = app.buttons["calendar.addEntry"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
    }

    private func switchToDayView(in app: XCUIApplication) {
        let dayMode = app.buttons["calendar.mode.day"]
        XCTAssertTrue(dayMode.waitForExistence(timeout: 5))
        dayMode.tap()
        XCTAssertTrue(app.buttons["calendar.addEntry"].waitForExistence(timeout: 5))
    }

    private func switchToMonthView(in app: XCUIApplication) {
        let monthMode = app.buttons["calendar.mode.month"]
        XCTAssertTrue(monthMode.waitForExistence(timeout: 5))
        monthMode.tap()
        XCTAssertTrue(app.buttons["calendar.photoImport"].waitForExistence(timeout: 5))
    }

    private func openCreatedEventDay(in app: XCUIApplication) {
        switchToMonthView(in: app)
        let day = calendarDayElement(for: Date(), in: app)
        XCTAssertTrue(day.waitForExistence(timeout: 8))
        day.tap()
        XCTAssertTrue(element(in: app, identifier: "dayDetail.content").waitForExistence(timeout: 8))
    }

    private func openEmptyDayEditor(in app: XCUIApplication) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let monthStart = calendar.dateInterval(
            of: .month,
            for: Date()
        )?.start ?? calendar.startOfDay(for: Date())
        let emptyDate = calendar.date(
            byAdding: .day,
            value: 1,
            to: monthStart
        )!
        let day = calendarDayElement(for: emptyDate, in: app)
        XCTAssertTrue(day.waitForExistence(timeout: 8))
        day.tap()
        XCTAssertTrue(
            element(in: app, identifier: "entry.editor")
                .waitForExistence(timeout: 8)
        )
    }

    private func createEventFromDayDetail(
        title: String,
        existingTitle: String,
        in app: XCUIApplication
    ) {
        let add = app.buttons["event.add"]
        scrollUntilHittable(add, in: app)
        add.tap()

        XCTAssertTrue(
            element(in: app, identifier: "event.editor")
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(element(in: app, identifier: "workRecord.editor").exists)
        XCTAssertNotEqual(
            app.textFields["entry.title"].value as? String,
            existingTitle
        )
        replaceText(in: app.textFields["entry.title"], with: title)
        let workToggle = app.switches["entry.workRecord.toggle"].firstMatch
        scrollUntilHittable(workToggle, in: app)
        XCTAssertEqual(workToggle.value as? String, "0")
        app.buttons["entry.editor.save"].tap()
    }

    private func eventTitle(
        _ title: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.staticTexts
            .matching(identifier: "event.primaryContent")
            .matching(NSPredicate(format: "label == %@", title))
            .firstMatch
    }

    private func deleteEvent(
        named title: String,
        in app: XCUIApplication
    ) {
        let titleElement = eventTitle(title, in: app)
        XCTAssertTrue(titleElement.waitForExistence(timeout: 5))
        guard let eventID = titleElement.value as? String,
              !eventID.isEmpty else {
            XCTFail("Missing event ID accessibility value for \(title)")
            return
        }
        let delete = app.buttons
            .matching(identifier: "event.delete")
            .matching(NSPredicate(format: "value == %@", eventID))
            .firstMatch
        scrollUntilHittable(delete, in: app)
        delete.tap()
    }

    private func calendarDayElement(
        for date: Date,
        in app: XCUIApplication
    ) -> XCUIElement {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents(
            [.year, .month, .day],
            from: date
        )
        return element(
            in: app,
            identifier: "calendar.day.\(components.year!)-\(components.month!)-\(components.day!)"
        )
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

    private func captureScreenshot(
        named name: String,
        app: XCUIApplication
    ) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let directory = ProcessInfo.processInfo.environment[
            "TIMENEST_UI_SCREENSHOT_DIR"
        ], !directory.isEmpty else {
            return
        }
        do {
            let directoryURL = URL(fileURLWithPath: directory)
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            try screenshot.pngRepresentation.write(
                to: directoryURL.appendingPathComponent("\(name).png"),
                options: .atomic
            )
        } catch {
            XCTFail("Could not save \(name): \(error)")
        }
    }

    private func element(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    private func waitForSelection(
        _ element: XCUIElement,
        selected: Bool,
        timeout: TimeInterval = 3
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if element.isSelected == selected { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        return element.isSelected == selected
    }

    private func scrollUntilUnobscured(
        _ element: XCUIElement,
        by fixedAction: XCUIElement,
        in scrollContainer: XCUIElement,
        maximumSwipes: Int = 8
    ) {
        for _ in 0..<maximumSwipes {
            let visibleTop = scrollContainer.frame.minY + 8
            if element.exists,
               element.frame.minY >= visibleTop,
               element.frame.maxY <= fixedAction.frame.minY {
                return
            }
            let needsScrollDown = element.exists && element.frame.minY < visibleTop
            // A normal `swipeUp()` can start on the keyboard-raised fixed action on iPhone SE.
            // Start downward drags below the inline Picker so the Picker does not consume them.
            let startOffset = needsScrollDown
                ? CGVector(dx: 0.5, dy: 0.45)
                : CGVector(dx: 0.5, dy: 0.42)
            let endOffset = needsScrollDown
                ? CGVector(dx: 0.5, dy: 0.68)
                : CGVector(dx: 0.5, dy: 0.14)
            let start = scrollContainer.coordinate(withNormalizedOffset: startOffset)
            let end = scrollContainer.coordinate(withNormalizedOffset: endOffset)
            start.press(forDuration: 0.05, thenDragTo: end)
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
    }
}
