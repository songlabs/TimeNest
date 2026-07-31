import XCTest
@testable import TimeNest

@MainActor
final class LinkedEntryDisplayItemTests: XCTestCase {
    func testMatchingUnifiedEntryIDProducesOneLinkedDisplayItem() {
        let unifiedEntryID = UUID()
        let workSessionID = UUID()
        let event = occurrence(
            title: "Appointment",
            unifiedEntryID: unifiedEntryID
        )
        let workRecord = workOccurrences(
            title: "Work",
            unifiedEntryID: unifiedEntryID,
            workSessionID: workSessionID
        )

        let items = LinkedEntryDisplayAssembler.make(
            from: [event] + workRecord,
            selectedDate: testDate
        )

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.event?.id, event.id)
        XCTAssertEqual(items.first?.workRecord?.workSessionId, workSessionID)
        XCTAssertEqual(items.first?.unifiedEntryID, unifiedEntryID)
        XCTAssertTrue(items.first?.isLinked == true)
    }

    func testLinkedEventStillAllowsAddingAnotherEventOnWritableCalendar() {
        let unifiedEntryID = UUID()
        let event = occurrence(
            title: "Linked appointment",
            unifiedEntryID: unifiedEntryID
        )
        let workRecord = workOccurrences(
            title: "Linked work",
            unifiedEntryID: unifiedEntryID,
            workSessionID: UUID()
        )
        let items = LinkedEntryDisplayAssembler.make(
            from: [event] + workRecord,
            selectedDate: testDate
        )

        let visibility = DayDetailEventSectionVisibility(
            hasEvents: items.contains { $0.event != nil },
            allowsCreating: true
        )

        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items.first?.isLinked == true)
        XCTAssertTrue(visibility.showsSection)
        XCTAssertTrue(visibility.showsAddButton)
    }

    func testReadOnlyCalendarKeepsExistingEventsWithoutAddButton() {
        let visibility = DayDetailEventSectionVisibility(
            hasEvents: true,
            allowsCreating: false
        )

        XCTAssertTrue(visibility.showsSection)
        XCTAssertFalse(visibility.showsAddButton)
    }

    func testSameTitleAndTimeWithDifferentIDsProducesIndependentEventItems() {
        let first = occurrence(
            title: "Same appointment",
            unifiedEntryID: UUID()
        )
        let second = occurrence(
            title: "Same appointment",
            unifiedEntryID: UUID()
        )

        let items = LinkedEntryDisplayAssembler.make(
            from: [first, second],
            selectedDate: testDate
        )

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(
            Set(items.compactMap { $0.event?.id }),
            Set([first.id, second.id])
        )
        XCTAssertEqual(
            Set(items.compactMap { $0.event?.eventID }),
            Set([first.eventID, second.eventID])
        )
        XCTAssertTrue(items.allSatisfy { $0.workRecord == nil })
        XCTAssertFalse(items.contains(where: \.isLinked))
    }

    func testNilUnifiedEntryIDsNeverMergeMatchingTitlesOrTimes() {
        let event = occurrence(title: "Same title")
        let workRecord = workOccurrences(
            title: "Same title",
            unifiedEntryID: nil,
            workSessionID: UUID()
        )

        let items = LinkedEntryDisplayAssembler.make(
            from: [event] + workRecord,
            selectedDate: testDate
        )

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.filter { $0.event != nil }.count, 1)
        XCTAssertEqual(items.filter { $0.workRecord != nil }.count, 1)
        XCTAssertFalse(items.contains(where: \.isLinked))
    }

    func testCalendarCollapseRemovesOnlyLinkedWorkOccurrences() {
        let linkedID = UUID()
        let event = occurrence(
            title: "Linked appointment",
            unifiedEntryID: linkedID
        )
        let linkedWork = workOccurrences(
            title: "Linked work",
            unifiedEntryID: linkedID,
            workSessionID: UUID()
        )
        let standaloneWork = workOccurrences(
            title: "Standalone work",
            unifiedEntryID: UUID(),
            workSessionID: UUID(),
            startOffset: 10 * 3_600
        )

        let collapsed = LinkedEntryDisplayAssembler.collapsedOccurrences(
            from: [event] + linkedWork + standaloneWork
        )

        XCTAssertEqual(collapsed.map(\.id), [event.id] + standaloneWork.map(\.id))
        XCTAssertFalse(collapsed.contains { linkedWork.map(\.id).contains($0.id) })
    }

    func testMismatchedWorkUnifiedEntryIDsRemainStandalone() {
        let eventID = UUID()
        let event = occurrence(
            title: "Appointment",
            unifiedEntryID: eventID
        )
        let workSessionID = UUID()
        let clockIn = workOccurrence(
            title: "Work",
            kind: .clockIn,
            unifiedEntryID: eventID,
            workSessionID: workSessionID,
            startOffset: 0
        )
        let clockOut = workOccurrence(
            title: "Work",
            kind: .clockOut,
            unifiedEntryID: UUID(),
            workSessionID: workSessionID,
            startOffset: 8 * 3_600
        )

        let items = LinkedEntryDisplayAssembler.make(
            from: [event, clockIn, clockOut],
            selectedDate: testDate
        )

        XCTAssertEqual(items.count, 2)
        XCTAssertFalse(items.contains(where: \.isLinked))
        XCTAssertEqual(
            LinkedEntryDisplayAssembler.collapsedOccurrences(
                from: [event, clockIn, clockOut]
            ).count,
            3
        )
    }

    private func workOccurrences(
        title: String,
        unifiedEntryID: UUID?,
        workSessionID: UUID,
        startOffset: TimeInterval = 0
    ) -> [EventOccurrence] {
        [
            workOccurrence(
                title: title,
                kind: .clockIn,
                unifiedEntryID: unifiedEntryID,
                workSessionID: workSessionID,
                startOffset: startOffset
            ),
            workOccurrence(
                title: title,
                kind: .clockOut,
                unifiedEntryID: unifiedEntryID,
                workSessionID: workSessionID,
                startOffset: startOffset + 8 * 3_600
            )
        ]
    }

    private func workOccurrence(
        title: String,
        kind: WorkClockKind,
        unifiedEntryID: UUID?,
        workSessionID: UUID,
        startOffset: TimeInterval
    ) -> EventOccurrence {
        let date = testDate.addingTimeInterval(startOffset)
        let workInfo: WorkInfo
        switch kind {
        case .clockIn:
            workInfo = WorkInfo(
                workInTime: date,
                workDate: testDate,
                workSessionId: workSessionID,
                isWorkOutTimeSet: true
            )
        case .clockOut:
            workInfo = WorkInfo(
                workOutTime: date,
                workDate: testDate,
                workSessionId: workSessionID,
                isWorkOutTimeSet: true
            )
        }
        return occurrence(
            title: title,
            unifiedEntryID: unifiedEntryID,
            startDate: date,
            workInfo: workInfo
        )
    }

    private func occurrence(
        title: String,
        unifiedEntryID: UUID? = nil,
        startDate: Date? = nil,
        workInfo: WorkInfo? = nil
    ) -> EventOccurrence {
        let start = startDate ?? testDate
        let eventID = UUID()
        return EventOccurrence(
            id: eventID.uuidString,
            eventID: eventID,
            unifiedEntryID: unifiedEntryID,
            occurrenceDate: DateOnly(from: testDate)!,
            startDate: start,
            endDate: start.addingTimeInterval(3_600),
            isAllDay: false,
            title: title,
            note: nil,
            categoryID: nil,
            reminderOffsetMinutes: nil,
            notificationID: nil,
            shiftTemplateID: nil,
            workInfo: workInfo
        )
    }

    private var testDate: Date {
        Date(timeIntervalSince1970: 1_780_000_000)
    }
}
