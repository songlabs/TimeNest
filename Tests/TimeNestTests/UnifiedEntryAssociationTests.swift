import XCTest
@testable import TimeNest

@MainActor
final class UnifiedEntryAssociationTests: XCTestCase {
    func testNewEventOnlyGetsStableUnifiedEntryID() async throws {
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository)
        let request = UnifiedEntrySaveRequest(
            event: makeEventRequest(title: "Appointment"),
            workRecord: nil
        )

        let unifiedEntryID = try await persist(
            request,
            useCase: useCase
        )

        let stored = try await allEvents(repository)
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.unifiedEntryID, unifiedEntryID)
        XCTAssertNil(stored.first?.workInfo)
    }

    func testSecondEventGetsIndependentIdentityAndMutatesByItsOwnID() async throws {
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository)
        let firstUnifiedEntryID = try await persist(
            UnifiedEntrySaveRequest(
                event: makeEventRequest(title: "First appointment"),
                workRecord: nil
            ),
            useCase: useCase
        )
        let secondUnifiedEntryID = try await persist(
            UnifiedEntrySaveRequest(
                event: makeEventRequest(title: "Second appointment"),
                workRecord: nil
            ),
            useCase: useCase
        )
        var stored = try await allEvents(repository)
        let first = try XCTUnwrap(
            stored.first { $0.title == "First appointment" }
        )
        let second = try XCTUnwrap(
            stored.first { $0.title == "Second appointment" }
        )

        XCTAssertEqual(stored.count, 2)
        XCTAssertNotEqual(firstUnifiedEntryID, secondUnifiedEntryID)
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.unifiedEntryID, firstUnifiedEntryID)
        XCTAssertEqual(second.unifiedEntryID, secondUnifiedEntryID)

        _ = try await persist(
            UnifiedEntrySaveRequest(
                unifiedEntryID: secondUnifiedEntryID,
                event: makeEventRequest(
                    eventID: second.id,
                    title: "Second appointment updated"
                ),
                workRecord: nil
            ),
            useCase: useCase
        )
        stored = try await allEvents(repository)
        XCTAssertEqual(
            stored.first { $0.id == first.id }?.title,
            "First appointment"
        )
        XCTAssertEqual(
            stored.first { $0.id == second.id }?.title,
            "Second appointment updated"
        )

        try await useCase.deleteEvent(id: second.id)
        stored = try await allEvents(repository)
        XCTAssertEqual(stored.map(\.id), [first.id])
        XCTAssertEqual(stored.first?.unifiedEntryID, firstUnifiedEntryID)
    }

    func testNewWorkOnlyUsesDistinctStableAndSessionIDs() async throws {
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository)
        let sessionID = UUID()
        let request = UnifiedEntrySaveRequest(
            event: nil,
            workRecord: makeWorkRequest(sessionID: sessionID)
        )

        let unifiedEntryID = try await persist(
            request,
            useCase: useCase
        )

        let stored = try await allEvents(repository)
        XCTAssertEqual(stored.count, 2)
        XCTAssertTrue(stored.allSatisfy {
            $0.unifiedEntryID == unifiedEntryID
        })
        XCTAssertTrue(stored.allSatisfy {
            $0.workInfo?.workSessionId == sessionID
        })
        XCTAssertNotEqual(unifiedEntryID, sessionID)
        XCTAssertEqual(
            Set(stored.compactMap(\.workClockKind)),
            Set([.clockIn, .clockOut])
        )
    }

    func testNewCombinedEntryLoadsBidirectionally() async throws {
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository)
        let sessionID = UUID()
        let unifiedEntryID = try await persist(
            UnifiedEntrySaveRequest(
                event: makeEventRequest(title: "Appointment"),
                workRecord: makeWorkRequest(sessionID: sessionID)
            ),
            useCase: useCase
        )
        let stored = try await allEvents(repository)
        let event = try XCTUnwrap(stored.first { $0.workInfo == nil })
        let clockIn = try XCTUnwrap(
            stored.first { $0.workClockKind == .clockIn }
        )
        let clockOut = try XCTUnwrap(
            stored.first { $0.workClockKind == .clockOut }
        )

        let loadedFromEvent = try await useCase.unifiedEntryGroup(
            for: .event(eventID: event.id)
        )
        let loadedFromWork = try await useCase.unifiedEntryGroup(
            for: .workRecord(
                clockInEventID: clockIn.id,
                clockOutEventID: clockOut.id,
                workSessionID: sessionID
            )
        )

        XCTAssertEqual(stored.count, 3)
        XCTAssertTrue(stored.allSatisfy {
            $0.unifiedEntryID == unifiedEntryID
        })
        XCTAssertEqual(loadedFromEvent, loadedFromWork)
        XCTAssertEqual(loadedFromEvent.event?.id, event.id)
        XCTAssertEqual(loadedFromEvent.workRecord?.sessionID, sessionID)
        let editorState = UnifiedEntryEditorInitialState(
            group: loadedFromEvent
        )
        XCTAssertEqual(editorState.unifiedEntryID, unifiedEntryID)
        XCTAssertEqual(editorState.existingEventID, event.id)
        XCTAssertEqual(editorState.existingWorkSessionID, sessionID)
        XCTAssertTrue(editorState.hasExistingEvent)
        XCTAssertTrue(editorState.hasExistingWorkRecord)
    }

    func testSingleSidedGroupsProduceDisabledMissingEditorSection() throws {
        let unifiedEntryID = UUID()
        let eventGroup = try UnifiedEntryGroupAssembler.assemble(
            unifiedEntryID: unifiedEntryID,
            events: [
                makeEvent(
                    unifiedEntryID: unifiedEntryID,
                    title: "Event only"
                )
            ]
        )
        let sessionID = UUID()
        let workEvents = makeWorkEvents(
            unifiedEntryID: unifiedEntryID,
            sessionID: sessionID
        )
        let workGroup = try UnifiedEntryGroupAssembler.assemble(
            unifiedEntryID: unifiedEntryID,
            events: workEvents
        )

        let eventState = UnifiedEntryEditorInitialState(group: eventGroup)
        XCTAssertTrue(eventState.hasExistingEvent)
        XCTAssertFalse(eventState.hasExistingWorkRecord)
        XCTAssertNil(eventState.workRecord)

        let workState = UnifiedEntryEditorInitialState(group: workGroup)
        XCTAssertFalse(workState.hasExistingEvent)
        XCTAssertTrue(workState.hasExistingWorkRecord)
        XCTAssertNil(workState.event)
        XCTAssertEqual(workState.existingWorkSessionID, sessionID)
    }

    func testEmptyPersistedGroupIsValidAfterItsLastSideIsDeleted() throws {
        let unifiedEntryID = UUID()

        let group = try UnifiedEntryGroupAssembler.assemble(
            unifiedEntryID: unifiedEntryID,
            events: []
        )

        XCTAssertEqual(group.unifiedEntryID, unifiedEntryID)
        XCTAssertNil(group.event)
        XCTAssertNil(group.workRecord)
    }

    func testNilHistoricalIDsNeverCauseTitleOrDateMatching() async throws {
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository)
        let historicalEvent = makeEvent(title: "Same title")
        try await repository.create(historicalEvent)
        let sessionID = UUID()
        try await useCase.saveWorkRecordPair(
            makeWorkRequest(
                sessionID: sessionID,
                title: "Same title"
            )
        )
        let stored = try await allEvents(repository)
        let clockIn = try XCTUnwrap(
            stored.first { $0.workClockKind == .clockIn }
        )
        let clockOut = try XCTUnwrap(
            stored.first { $0.workClockKind == .clockOut }
        )

        let eventGroup = try await useCase.unifiedEntryGroup(
            for: .event(eventID: historicalEvent.id)
        )
        let workGroup = try await useCase.unifiedEntryGroup(
            for: .workRecord(
                clockInEventID: clockIn.id,
                clockOutEventID: clockOut.id,
                workSessionID: sessionID
            )
        )

        XCTAssertNil(eventGroup.unifiedEntryID)
        XCTAssertNotNil(eventGroup.event)
        XCTAssertNil(eventGroup.workRecord)
        XCTAssertNil(workGroup.unifiedEntryID)
        XCTAssertNil(workGroup.event)
        XCTAssertNotNil(workGroup.workRecord)
    }

    func testRepeatedCombinedSaveUpdatesOriginalObjectsWithoutDuplicates() async throws {
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository)
        let sessionID = UUID()
        let unifiedEntryID = try await persist(
            UnifiedEntrySaveRequest(
                event: makeEventRequest(title: "Before"),
                workRecord: makeWorkRequest(
                    sessionID: sessionID,
                    title: "Before work"
                )
            ),
            useCase: useCase
        )
        let initial = try await allEvents(repository)
        let initialIDs = Set(initial.map(\.id))

        let update = UnifiedEntrySaveRequest(
            unifiedEntryID: unifiedEntryID,
            event: makeEventRequest(title: "After"),
            workRecord: makeWorkRequest(
                sessionID: UUID(),
                title: "After work",
                clockInDate: testDate.addingTimeInterval(30 * 60),
                clockOutDate: testDate.addingTimeInterval(9 * 3_600)
            )
        )
        _ = try await persist(update, useCase: useCase)
        _ = try await persist(update, useCase: useCase)

        let stored = try await allEvents(repository)
        XCTAssertEqual(stored.count, 3)
        XCTAssertEqual(Set(stored.map(\.id)), initialIDs)
        XCTAssertTrue(stored.allSatisfy {
            $0.unifiedEntryID == unifiedEntryID
        })
        XCTAssertEqual(
            stored.first { $0.workInfo == nil }?.title,
            "After"
        )
        XCTAssertTrue(
            stored.filter { $0.workInfo != nil }.allSatisfy {
                $0.title == "After work"
                    && $0.workInfo?.workSessionId == sessionID
            }
        )
        XCTAssertEqual(
            stored.first { $0.workClockKind == .clockIn }?.startDate,
            testDate.addingTimeInterval(30 * 60)
        )
    }

    func testHistoricalEventCanAddWorkInOneGroup() async throws {
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository)
        let historicalEvent = makeEvent(title: "Historical event")
        try await repository.create(historicalEvent)
        let sessionID = UUID()

        let unifiedEntryID = try await persist(
            UnifiedEntrySaveRequest(
                event: makeEventRequest(
                    eventID: historicalEvent.id,
                    title: "Updated historical event"
                ),
                workRecord: makeWorkRequest(sessionID: sessionID)
            ),
            useCase: useCase
        )

        let stored = try await allEvents(repository)
        XCTAssertEqual(stored.count, 3)
        XCTAssertEqual(
            stored.first { $0.id == historicalEvent.id }?.unifiedEntryID,
            unifiedEntryID
        )
        XCTAssertEqual(
            stored.filter { $0.workInfo != nil }.map(\.unifiedEntryID),
            [unifiedEntryID, unifiedEntryID]
        )
    }

    func testHistoricalWorkCanAddEventWithoutReplacingClockIDs() async throws {
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository)
        let sessionID = UUID()
        try await useCase.saveWorkRecordPair(
            makeWorkRequest(sessionID: sessionID)
        )
        let historical = try await allEvents(repository)
        let clockIn = try XCTUnwrap(
            historical.first { $0.workClockKind == .clockIn }
        )
        let clockOut = try XCTUnwrap(
            historical.first { $0.workClockKind == .clockOut }
        )
        let historicalClockIDs = Set([clockIn.id, clockOut.id])

        let unifiedEntryID = try await persist(
            UnifiedEntrySaveRequest(
                event: makeEventRequest(title: "Added event"),
                workRecord: makeWorkRequest(
                    sessionID: sessionID,
                    clockInEventID: clockIn.id,
                    clockOutEventID: clockOut.id
                )
            ),
            useCase: useCase
        )

        let stored = try await allEvents(repository)
        XCTAssertEqual(stored.count, 3)
        XCTAssertEqual(
            Set(stored.filter { $0.workInfo != nil }.map(\.id)),
            historicalClockIDs
        )
        XCTAssertTrue(stored.allSatisfy {
            $0.unifiedEntryID == unifiedEntryID
        })
        XCTAssertTrue(
            stored.filter { $0.workInfo != nil }.allSatisfy {
                $0.workInfo?.workSessionId == sessionID
            }
        )
    }

    func testIndependentDeletionKeepsIdentityAndAllowsReaddingEitherSide() async throws {
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository)
        let originalSessionID = UUID()
        let unifiedEntryID = try await persist(
            UnifiedEntrySaveRequest(
                event: makeEventRequest(title: "Original event"),
                workRecord: makeWorkRequest(sessionID: originalSessionID)
            ),
            useCase: useCase
        )
        var stored = try await allEvents(repository)
        let event = try XCTUnwrap(stored.first { $0.workInfo == nil })
        try await useCase.deleteEvent(id: event.id)

        stored = try await allEvents(repository)
        XCTAssertEqual(stored.count, 2)
        XCTAssertTrue(stored.allSatisfy {
            $0.unifiedEntryID == unifiedEntryID
        })
        let retainedClockIn = try XCTUnwrap(
            stored.first { $0.workClockKind == .clockIn }
        )
        let retainedClockOut = try XCTUnwrap(
            stored.first { $0.workClockKind == .clockOut }
        )
        _ = try await persist(
            UnifiedEntrySaveRequest(
                unifiedEntryID: unifiedEntryID,
                event: makeEventRequest(title: "Re-added event"),
                workRecord: makeWorkRequest(
                    sessionID: originalSessionID,
                    clockInEventID: retainedClockIn.id,
                    clockOutEventID: retainedClockOut.id
                )
            ),
            useCase: useCase
        )

        stored = try await allEvents(repository)
        let readdedEvent = try XCTUnwrap(
            stored.first { $0.workInfo == nil }
        )
        let workEvents = stored.filter { $0.workInfo != nil }
        _ = try await useCase.deleteEventsBatch(
            expectedEvents: workEvents
        )

        stored = try await allEvents(repository)
        XCTAssertEqual(stored, [readdedEvent])
        XCTAssertEqual(readdedEvent.unifiedEntryID, unifiedEntryID)
        let replacementSessionID = UUID()
        _ = try await persist(
            UnifiedEntrySaveRequest(
                unifiedEntryID: unifiedEntryID,
                event: makeEventRequest(
                    eventID: readdedEvent.id,
                    title: readdedEvent.title
                ),
                workRecord: makeWorkRequest(
                    sessionID: replacementSessionID
                )
            ),
            useCase: useCase
        )

        stored = try await allEvents(repository)
        XCTAssertEqual(stored.count, 3)
        XCTAssertTrue(stored.allSatisfy {
            $0.unifiedEntryID == unifiedEntryID
        })
        XCTAssertTrue(stored.filter { $0.workInfo != nil }.allSatisfy {
            $0.workInfo?.workSessionId == replacementSessionID
        })
    }

    func testDuplicateOrdinaryEventsAreRejectedWithoutMutation() async throws {
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(repository: repository)
        let unifiedEntryID = UUID()
        let first = makeEvent(
            unifiedEntryID: unifiedEntryID,
            title: "First"
        )
        let second = makeEvent(
            unifiedEntryID: unifiedEntryID,
            title: "Second"
        )
        try await repository.create(first)
        try await repository.create(second)

        do {
            _ = try await useCase.unifiedEntryGroup(
                for: .event(eventID: first.id)
            )
            XCTFail("A duplicate ordinary event group must fail.")
        } catch {
            XCTAssertEqual(
                error as? UnifiedEntryGroupError,
                .duplicateEvent
            )
        }

        let preservedEvents = try await allEvents(repository)
        XCTAssertEqual(Set(preservedEvents), Set([first, second]))
    }

    func testDifferentWorkSessionsAndMismatchedPairIDsAreRejected() async throws {
        let unifiedEntryID = UUID()
        let firstPair = makeWorkEvents(
            unifiedEntryID: unifiedEntryID,
            sessionID: UUID()
        )
        let secondPair = makeWorkEvents(
            unifiedEntryID: unifiedEntryID,
            sessionID: UUID()
        )
        XCTAssertThrowsError(
            try UnifiedEntryGroupAssembler.assemble(
                unifiedEntryID: unifiedEntryID,
                events: firstPair + secondPair
            )
        ) {
            XCTAssertEqual(
                $0 as? UnifiedEntryGroupError,
                .multipleWorkSessions
            )
        }

        let mismatched = [
            makeWorkEvent(
                kind: .clockIn,
                unifiedEntryID: UUID(),
                sessionID: UUID()
            ),
            makeWorkEvent(
                kind: .clockOut,
                unifiedEntryID: UUID(),
                sessionID: UUID()
            )
        ]
        XCTAssertThrowsError(
            try UnifiedEntryGroupAssembler.assemble(
                unifiedEntryID: nil,
                events: mismatched
            )
        ) {
            XCTAssertEqual(
                $0 as? UnifiedEntryGroupError,
                .mismatchedUnifiedEntryID
            )
        }
    }

    func testBatchValidationRejectsSecondSideWithoutChangingStoredGroup() async throws {
        let repository = InMemoryEventRepository()
        let unifiedEntryID = UUID()
        let original = makeEvent(
            unifiedEntryID: unifiedEntryID,
            title: "Original"
        )
        try await repository.create(original)
        let duplicate = makeEvent(
            unifiedEntryID: unifiedEntryID,
            title: "Duplicate"
        )

        do {
            try await repository.applyBatch(
                upserting: [duplicate],
                deleting: [],
                ifUnchanged: []
            )
            XCTFail("A second ordinary event must be rejected.")
        } catch {
            XCTAssertEqual(
                error as? UnifiedEntryGroupError,
                .duplicateEvent
            )
        }

        let preservedEvents = try await allEvents(repository)
        XCTAssertEqual(preservedEvents, [original])
    }

    private func persist(
        _ request: UnifiedEntrySaveRequest,
        useCase: EventUseCase
    ) async throws -> UUID {
        let resolution = try await useCase.resolveUnifiedEntrySave(request)
        let workRecord = request.workRecord?.resolvingExistingWorkRecord(
            resolution.existingWorkRecord,
            unifiedEntryID: resolution.unifiedEntryID
        )
        let event = request.event.map {
            makeEvent(
                id: resolution.existingEvent?.id ?? UUID(),
                unifiedEntryID: resolution.unifiedEntryID,
                calendarID: $0.calendarID,
                title: $0.title,
                note: $0.note,
                startDate: $0.startDate,
                endDate: $0.endDate,
                isAllDay: $0.isAllDay,
                reminderOffsetMinutes: $0.reminderOffsetMinutes,
                createdAt: resolution.existingEvent?.createdAt ?? testDate,
                updatedAt: Date()
            )
        }

        switch (event, workRecord) {
        case (.some(let event), .some(let workRecord)):
            _ = try await useCase.saveEventAndWorkRecordAtomically(
                event: event,
                existingEvent: resolution.existingEvent,
                workRecord: workRecord
            )
        case (.some(let event), nil):
            if resolution.existingEvent == nil {
                _ = try await useCase.createEvent(event)
            } else {
                _ = try await useCase.updateEvent(event)
            }
        case (nil, .some(let workRecord)):
            try await useCase.saveWorkRecordPair(workRecord)
        case (nil, nil):
            XCTFail("The test helper requires one enabled section.")
        }
        return resolution.unifiedEntryID
    }

    private func allEvents(
        _ repository: InMemoryEventRepository
    ) async throws -> [CalendarEvent] {
        try await repository.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
    }

    private func makeEventRequest(
        eventID: UUID? = nil,
        title: String
    ) -> EventEntrySaveRequest {
        EventEntrySaveRequest(
            eventID: eventID,
            calendarID: TimeNestCalendar.personalID,
            title: title,
            note: nil,
            startDate: testDate,
            endDate: testDate.addingTimeInterval(3_600),
            isAllDay: false,
            reminderOffsetMinutes: nil,
            shiftTemplateID: nil,
            workInfo: nil
        )
    }

    private func makeWorkRequest(
        sessionID: UUID,
        title: String = "Work",
        clockInEventID: UUID? = nil,
        clockOutEventID: UUID? = nil,
        clockInDate: Date? = nil,
        clockOutDate: Date? = nil,
        unifiedEntryID: UUID? = nil
    ) -> WorkRecordPairSaveRequest {
        WorkRecordPairSaveRequest(
            clockInEventID: clockInEventID,
            clockOutEventID: clockOutEventID,
            calendarID: TimeNestCalendar.personalID,
            title: title,
            workDate: testDate,
            clockInDate: clockInDate ?? testDate,
            clockOutDate: clockOutDate
                ?? testDate.addingTimeInterval(8 * 3_600),
            restHours: 1,
            transportFee: 500,
            hourlyRate: 2_000,
            sessionID: sessionID,
            isWorkOutTimeSet: true,
            unifiedEntryID: unifiedEntryID
        )
    }

    private func makeWorkEvents(
        unifiedEntryID: UUID,
        sessionID: UUID
    ) -> [CalendarEvent] {
        [
            makeWorkEvent(
                kind: .clockIn,
                unifiedEntryID: unifiedEntryID,
                sessionID: sessionID
            ),
            makeWorkEvent(
                kind: .clockOut,
                unifiedEntryID: unifiedEntryID,
                sessionID: sessionID
            )
        ]
    }

    private func makeWorkEvent(
        kind: WorkClockKind,
        unifiedEntryID: UUID,
        sessionID: UUID
    ) -> CalendarEvent {
        let clockDate = kind == .clockIn
            ? testDate
            : testDate.addingTimeInterval(8 * 3_600)
        let workInfo: WorkInfo
        switch kind {
        case .clockIn:
            workInfo = WorkInfo(
                workInTime: clockDate,
                restHours: 1,
                workDate: testDate,
                workSessionId: sessionID,
                isWorkOutTimeSet: true
            )
        case .clockOut:
            workInfo = WorkInfo(
                workOutTime: clockDate,
                restHours: 1,
                workDate: testDate,
                workSessionId: sessionID,
                isWorkOutTimeSet: true
            )
        }
        return makeEvent(
            unifiedEntryID: unifiedEntryID,
            title: kind == .clockIn ? "Clock In" : "Clock Out",
            startDate: clockDate,
            endDate: clockDate.addingTimeInterval(3_600),
            workInfo: workInfo
        )
    }

    private func makeEvent(
        id: UUID = UUID(),
        unifiedEntryID: UUID? = nil,
        calendarID: UUID = TimeNestCalendar.personalID,
        title: String,
        note: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isAllDay: Bool = false,
        reminderOffsetMinutes: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        workInfo: WorkInfo? = nil
    ) -> CalendarEvent {
        let start = startDate ?? testDate
        return CalendarEvent(
            id: id,
            unifiedEntryID: unifiedEntryID,
            calendarID: calendarID,
            title: title,
            note: note,
            startDate: start,
            endDate: endDate ?? start.addingTimeInterval(3_600),
            isAllDay: isAllDay,
            categoryID: nil,
            recurrenceRule: .none,
            reminderTemplateID: nil,
            reminderOffsetMinutes: reminderOffsetMinutes,
            notificationID: nil,
            importSource: nil,
            createdAt: createdAt ?? testDate,
            updatedAt: updatedAt ?? testDate,
            shiftTemplateID: nil,
            workInfo: workInfo
        )
    }

    private var testDate: Date {
        Date(timeIntervalSince1970: 1_780_000_000)
    }
}
