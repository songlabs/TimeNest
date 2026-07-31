import XCTest
@testable import TimeNest

final class CalendarEntryTargetTests: XCTestCase {
    func testFixedWritableContextHidesSelectorAndLocksSaveTarget() {
        let fixedID = UUID()
        let otherID = UUID()
        let context = EntryCalendarContext.fixedWritableCalendar(fixedID)

        XCTAssertFalse(context.showsCalendarSelector)
        XCTAssertTrue(context.allowsEditing)
        XCTAssertEqual(context.initialCalendarID(in: []), fixedID)
        XCTAssertEqual(
            context.resolvedCalendarID(selectedCalendarID: otherID),
            fixedID
        )
    }

    func testSelectionContextUsesOnlyWritableCalendarsAndPrefersPersonalFallback() {
        let received = makeCalendar(kind: .sharedReceived)
        let owned = makeCalendar(kind: .sharedOwned)
        let personal = TimeNestCalendar.personal(name: "My Calendar")
        let context = EntryCalendarContext.needsCalendarSelection(
            initialCalendarID: received.id
        )

        XCTAssertTrue(context.showsCalendarSelector)
        XCTAssertTrue(context.allowsEditing)
        XCTAssertEqual(
            context.initialCalendarID(in: [received, owned, personal]),
            personal.id
        )
        XCTAssertEqual(
            context.resolvedCalendarID(selectedCalendarID: owned.id),
            owned.id
        )
    }

    func testSelectionContextKeepsPreferredWritableCalendar() {
        let owned = makeCalendar(kind: .sharedOwned)
        let context = EntryCalendarContext.needsCalendarSelection(
            initialCalendarID: owned.id
        )

        XCTAssertEqual(
            context.initialCalendarID(
                in: [TimeNestCalendar.personal(name: "My Calendar"), owned]
            ),
            owned.id
        )
    }

    func testReadOnlyContextCannotEditAndNeverRetargets() {
        let receivedID = UUID()
        let context = EntryCalendarContext.readOnlyCalendar(receivedID)

        XCTAssertFalse(context.showsCalendarSelector)
        XCTAssertFalse(context.allowsEditing)
        XCTAssertEqual(
            context.resolvedCalendarID(selectedCalendarID: TimeNestCalendar.personalID),
            receivedID
        )
    }

    func testReadOnlyPolicyKeepsBlockedAddAffordanceVisibleForExplanation() {
        let policy = CalendarAccessPolicy(
            selectedCalendar: makeCalendar(kind: .sharedReceived)
        )

        XCTAssertFalse(policy.canCreate)
        XCTAssertTrue(policy.showsAddButton)
    }

    func testGeneralCreateStartsWithEventEnabledAndWorkRecordDisabled() {
        var selection = UnifiedEntrySectionSelection.initial(
            for: .create(initialDate: Date()),
            initialEntryKind: .event
        )

        XCTAssertTrue(selection.isEventEnabled)
        XCTAssertFalse(selection.isWorkRecordEnabled)
        XCTAssertTrue(selection.hasEnabledEntry)

        selection.setEventEnabled(false)
        XCTAssertFalse(selection.hasEnabledEntry)

        selection.setWorkRecordEnabled(true)
        XCTAssertTrue(selection.isWorkRecordEnabled)
        XCTAssertTrue(selection.hasEnabledEntry)
    }

    func testWorkRecordCreateStartsWithWorkRecordEnabled() {
        let selection = UnifiedEntrySectionSelection.initial(
            for: .create(initialDate: Date()),
            initialEntryKind: .workRecord
        )

        XCTAssertFalse(selection.isEventEnabled)
        XCTAssertTrue(selection.isWorkRecordEnabled)
        XCTAssertTrue(selection.hasEnabledEntry)
    }

    func testExistingEventEditStartsWithEventEnabled() {
        let now = Date()
        let selection = UnifiedEntrySectionSelection.initial(
            for: .edit(
                eventID: UUID(),
                initialTitle: "Existing Event",
                initialNote: nil,
                initialStartDate: now,
                initialEndDate: now.addingTimeInterval(3_600),
                initialIsAllDay: false,
                initialReminderOffsetMinutes: nil
            ),
            initialEntryKind: .workRecord
        )

        XCTAssertTrue(selection.isEventEnabled)
        XCTAssertFalse(selection.isWorkRecordEnabled)
        XCTAssertTrue(selection.hasExistingEvent)
    }

    func testExistingWorkRecordEditStartsWithWorkRecordEnabled() {
        var selection = UnifiedEntrySectionSelection.initial(
            for: .editWorkRecord(makeWorkRecordInitialSession()),
            initialEntryKind: .event
        )

        XCTAssertFalse(selection.isEventEnabled)
        XCTAssertTrue(selection.isWorkRecordEnabled)
        XCTAssertTrue(selection.hasExistingWorkRecord)

        selection.setWorkRecordEnabled(false)
        XCTAssertTrue(selection.isWorkRecordEnabled)
    }

    func testCombinedEditStartsWithBothExistingSectionsEnabled() {
        let initialState = UnifiedEntryEditorInitialState(
            unifiedEntryID: UUID(),
            event: makeCalendarEvent(title: "Existing Event"),
            workRecord: makeWorkRecordInitialSession()
        )
        var selection = UnifiedEntrySectionSelection.initial(
            for: .editUnified(initialState),
            initialEntryKind: .event
        )

        XCTAssertTrue(selection.isEventEnabled)
        XCTAssertTrue(selection.isWorkRecordEnabled)
        XCTAssertTrue(selection.hasExistingEvent)
        XCTAssertTrue(selection.hasExistingWorkRecord)

        selection.setEventEnabled(false)
        selection.setWorkRecordEnabled(false)
        XCTAssertTrue(selection.isEventEnabled)
        XCTAssertTrue(selection.isWorkRecordEnabled)
    }

    func testUnifiedEditPreservesTheEntryKindUsedToOpenIt() {
        let eventID = UUID()
        let sessionID = UUID()
        XCTAssertEqual(
            UnifiedEntryLoadRequest.event(eventID: eventID).initialEntryKind,
            .event
        )
        XCTAssertEqual(
            UnifiedEntryLoadRequest.workRecord(
                clockInEventID: nil,
                clockOutEventID: nil,
                workSessionID: sessionID
            ).initialEntryKind,
            .workRecord
        )

        let state = UnifiedEntryEditorInitialState(
            unifiedEntryID: UUID(),
            event: makeCalendarEvent(title: "Existing Event"),
            workRecord: makeWorkRecordInitialSession(),
            initialEntryKind: .workRecord
        )
        XCTAssertEqual(state.initialEntryKind, .workRecord)
    }

    func testUnifiedEditorCannotDisableAnExistingEntry() {
        var eventEdit = UnifiedEntrySectionSelection(
            isEventEnabled: true,
            isWorkRecordEnabled: false,
            hasExistingEvent: true
        )
        eventEdit.setEventEnabled(false)
        XCTAssertTrue(eventEdit.isEventEnabled)

        var workRecordEdit = UnifiedEntrySectionSelection(
            isEventEnabled: false,
            isWorkRecordEnabled: true,
            hasExistingWorkRecord: true
        )
        workRecordEdit.setWorkRecordEnabled(false)
        XCTAssertTrue(workRecordEdit.isWorkRecordEnabled)
    }

    func testWorkRecordDefaultsCopyFromEventOnlyOnceAndPreserveDraftWhenReenabled() {
        let calendar = gregorianCalendar()
        let eventStart = date(2026, 7, 30, 22, 30, calendar: calendar)
        let eventEnd = date(2026, 7, 31, 2, 15, calendar: calendar)
        let initial = UnifiedEntryWorkRecordLinkedValues(
            title: "Initial",
            workDate: date(2026, 7, 1, 0, 0, calendar: calendar),
            clockInDate: date(2026, 7, 1, 9, 0, calendar: calendar),
            clockOutDate: date(2026, 7, 1, 18, 0, calendar: calendar),
            isClockOutTimeSet: false
        )
        var linker = UnifiedEntryWorkRecordDefaultLinker()

        var linked = linker.valuesWhenEnabling(
            event: UnifiedEntryEventLinkSource(
                title: "Night Shift",
                startDate: eventStart,
                endDate: eventEnd
            ),
            current: initial,
            calendar: calendar
        )

        XCTAssertEqual(linked.title, "Night Shift")
        XCTAssertTrue(calendar.isDate(linked.workDate, inSameDayAs: eventStart))
        XCTAssertEqual(linked.clockInDate, eventStart)
        XCTAssertEqual(linked.clockOutDate, eventEnd)
        XCTAssertTrue(linked.isClockOutTimeSet)

        linked.title = "Manual Name"
        linked.clockInDate = date(2026, 7, 30, 23, 0, calendar: calendar)
        let preserved = linker.valuesWhenEnabling(
            event: UnifiedEntryEventLinkSource(
                title: "Changed Event",
                startDate: date(2026, 8, 1, 8, 0, calendar: calendar),
                endDate: date(2026, 8, 1, 17, 0, calendar: calendar)
            ),
            current: linked,
            calendar: calendar
        )

        XCTAssertEqual(preserved, linked)
    }

    func testWorkRecordSaveRequestPreservesOvernightClockOutAndEditIDs() {
        let calendar = gregorianCalendar()
        let workDate = date(2026, 7, 30, 0, 0, calendar: calendar)
        let clockInID = UUID()
        let clockOutID = UUID()
        let sessionID = UUID()
        let initialSession = WorkRecordEditorInitialSession(
            clockInEventID: clockInID,
            clockOutEventID: clockOutID,
            title: "Night Shift",
            workDate: workDate,
            workInTime: nil,
            workOutTime: nil,
            restHours: 1,
            transportFee: 500,
            hourlyRate: 1_500,
            workSessionId: sessionID,
            isWorkOutTimeSet: true,
            calendarID: TimeNestCalendar.personalID
        )
        let request = WorkRecordEditorSaveLogic.makeRequest(
            context: WorkRecordEditorSaveContext(
                title: "Night Shift",
                workDate: workDate,
                workInDate: date(2026, 7, 30, 22, 0, calendar: calendar),
                workOutDate: date(2026, 7, 31, 2, 0, calendar: calendar),
                restTime: 1,
                transportFee: "500",
                hourlyRate: "1500",
                workSessionId: sessionID,
                isWorkOutTimeSet: true,
                editInitialSession: initialSession
            ),
            defaultTitle: "Work",
            calendarID: TimeNestCalendar.personalID
        )

        XCTAssertEqual(request.clockInEventID, clockInID)
        XCTAssertEqual(request.clockOutEventID, clockOutID)
        XCTAssertEqual(request.sessionID, sessionID)
        XCTAssertTrue(request.clockOutDate > request.clockInDate)
        XCTAssertEqual(
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: request.clockInDate),
                to: calendar.startOfDay(for: request.clockOutDate)
            ).day,
            1
        )
    }

    private func gregorianCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }

    private func makeCalendarEvent(title: String) -> CalendarEvent {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        return CalendarEvent(
            id: UUID(),
            unifiedEntryID: UUID(),
            title: title,
            note: "Existing note",
            startDate: now,
            endDate: now.addingTimeInterval(3_600),
            isAllDay: false,
            categoryID: nil,
            recurrenceRule: .none,
            reminderTemplateID: nil,
            importSource: nil,
            createdAt: now,
            updatedAt: now
        )
    }

    private func makeWorkRecordInitialSession() -> WorkRecordEditorInitialSession {
        let workDate = Date(timeIntervalSince1970: 1_780_000_000)
        return WorkRecordEditorInitialSession(
            clockInEventID: UUID(),
            clockOutEventID: UUID(),
            title: "Existing Work Record",
            workDate: workDate,
            workInTime: workDate,
            workOutTime: workDate.addingTimeInterval(3_600),
            restHours: 1,
            transportFee: 500,
            hourlyRate: 1_500,
            workSessionId: UUID(),
            isWorkOutTimeSet: true,
            calendarID: TimeNestCalendar.personalID
        )
    }

    private func makeCalendar(kind: TimeNestCalendarKind) -> TimeNestCalendar {
        let now = Date()
        return TimeNestCalendar(
            id: UUID(),
            name: "Calendar",
            kind: kind,
            zoneName: kind.isCloudBacked ? "zone" : nil,
            ownerName: kind.isCloudBacked ? "owner" : nil,
            rootRecordName: kind.isCloudBacked ? "calendar" : nil,
            shareRecordName: kind.isCloudBacked ? "share" : nil,
            createdAt: now,
            updatedAt: now
        )
    }
}
