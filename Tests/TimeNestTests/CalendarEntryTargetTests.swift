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
