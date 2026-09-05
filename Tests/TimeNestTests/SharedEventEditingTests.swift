import CloudKit
import XCTest
@testable import TimeNest

@MainActor
final class SharedEventEditingTests: XCTestCase {
    func testMonthInputPartialSharedSaveKeepsDraftAndRetriesExistingMutation() async throws {
        let descriptor = makeReceivedDescriptor()
        let calendar = makeReceivedCalendar(id: descriptor.id, permission: .readWrite)
        let client = SharedEventEditingClientStub()
        client.receivedDescriptors = [descriptor]
        let cache = CalendarSharingCache(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("MonthInputSharedCache-\(UUID()).json"))
        try cache.save(CalendarSharingCacheData(receivedCalendars: [descriptor],
                                                eventsByCalendarID: [descriptor.id: []]))
        let suite = "MonthInputShared-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let persistence = makePersistence()
        let useCase = EventUseCase(repository: InMemoryEventRepository())
        let store = CalendarSharingStore(
            client: client, eventUseCase: useCase,
            calendarRepository: InMemoryCalendarRepository(calendars: [calendar]), cache: cache,
            sharedEventEditingPersistence: persistence,
            selectionPersistence: CalendarSelectionPersistence(defaults: defaults),
            syncMetadataPersistence: CalendarSharingSyncMetadataPersistence(defaults: defaults),
            initialCalendars: [calendar]
        )
        let model = CalendarPhotoImportViewModel(eventUseCase: useCase, sharingStore: store, initialDate: Date())
        model.draft.rows[0].setTitle("Saved first")
        model.draft.rows[1].setTitle("Retry second")
        model.prepareConfirmation()
        let original = model.draft
        let firstID = model.draft.rows[0].id
        let secondID = model.draft.rows[1].id
        client.confirmedNotSentEventIDs = [secondID]
        let initial = await model.saveSelected()
        XCTAssertFalse(initial)
        XCTAssertEqual(model.step, .review)
        XCTAssertFalse(model.didSave)
        XCTAssertNotNil(model.failureMessage)
        XCTAssertEqual(model.draft, original, "Partial success must not discard accepted or failed drafts")
        XCTAssertEqual(store.sharedEventSyncStatus(calendarID: calendar.id, eventID: firstID), .synced)
        XCTAssertEqual(store.sharedEventSyncStatus(calendarID: calendar.id, eventID: secondID), .pending)
        XCTAssertEqual(model.submittedIDs, [firstID, secondID])
        let initialMutation = try XCTUnwrap(persistence.load().outbox.first { $0.eventID == secondID })
        client.confirmedNotSentEventIDs = []
        let retried = await model.saveSelected()
        XCTAssertTrue(retried)
        XCTAssertEqual(client.receivedRecords.count, 2)
        XCTAssertEqual(client.receivedCreateEventIDs.filter { $0 == firstID }.count, 1)
        XCTAssertEqual(client.receivedWriteSnapshots.map(\.id), [firstID, secondID])
        XCTAssertEqual(client.receivedWriteMutationIDs.last, initialMutation.id,
                       "Use the existing outbox mutation, not another logical create")
        XCTAssertEqual(model.draft, original)
    }

    func testLegacyPermissionFieldsDefaultToReadOnlyAndReadWriteIsEventOnly() throws {
        let id = UUID()
        let legacyDescriptorJSON: [String: Any] = [
            "id": id.uuidString,
            "zoneName": "zone",
            "ownerName": "owner",
            "calendarName": "Family",
            "participantCount": 1,
            "kind": TimeNestCalendarKind.sharedReceived.rawValue,
            "rootRecordName": "calendar",
            "shareRecordName": CKRecordNameZoneWideShare,
        ]
        let legacyDescriptor = try JSONDecoder().decode(
            SharedCalendarDescriptor.self,
            from: JSONSerialization.data(withJSONObject: legacyDescriptorJSON)
        )

        XCTAssertTrue(legacyDescriptor.isReadOnly)
        XCTAssertFalse(legacyDescriptor.eventEditingAllowed)
        XCTAssertEqual(legacyDescriptor.participantPermission, .unknown)

        let legacyOwnedDescriptorJSON: [String: Any] = [
            "id": id.uuidString,
            "zoneName": "owned-zone",
            "ownerName": CKCurrentUserDefaultName,
            "calendarName": "Family",
            "participantCount": 1,
            "rootRecordName": "calendar",
            "shareRecordName": CKRecordNameZoneWideShare,
        ]
        let legacyOwnedDescriptor = try JSONDecoder().decode(
            OwnedSharedCalendarDescriptor.self,
            from: JSONSerialization.data(withJSONObject: legacyOwnedDescriptorJSON)
        )
        XCTAssertFalse(legacyOwnedDescriptor.eventEditingAllowed)

        let editable = makeReceivedCalendar(id: id, permission: .readWrite)
        let policy = CalendarAccessPolicy(selectedCalendar: editable)

        XCTAssertFalse(editable.canEditContent)
        XCTAssertTrue(policy.canCreateSharedEvent)
        XCTAssertTrue(policy.canEditSharedEvent)
        XCTAssertTrue(policy.canDeleteSharedEvent)
        XCTAssertFalse(policy.canEditShifts)
        XCTAssertFalse(policy.canEditWorkRecords)
        XCTAssertFalse(policy.canManageShare)

        let encoded = try JSONEncoder().encode(editable)
        var legacyCalendarJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        legacyCalendarJSON.removeValue(forKey: "eventEditingAllowed")
        legacyCalendarJSON.removeValue(forKey: "participantPermission")
        let legacyCalendar = try JSONDecoder().decode(
            TimeNestCalendar.self,
            from: JSONSerialization.data(withJSONObject: legacyCalendarJSON)
        )

        XCTAssertTrue(legacyCalendar.isReadOnly)
        XCTAssertFalse(legacyCalendar.canCreateSharedEvent)
    }

    func testInvitationPermissionFollowsOwnerEventEditingSetting() {
        let zoneID = CKRecordZone.ID(zoneName: "zone", ownerName: CKCurrentUserDefaultName)
        let readOnlyShare = CalendarSharingCloudRecordFactory.makeZoneWideShare(
            recordZoneID: zoneID
        )
        _ = OneTimeSharingInvitation.prepare(
            on: readOnlyShare,
            eventEditingAllowed: false
        )
        let readWriteShare = CalendarSharingCloudRecordFactory.makeZoneWideShare(
            recordZoneID: CKRecordZone.ID(
                zoneName: "zone-2",
                ownerName: CKCurrentUserDefaultName
            )
        )
        _ = OneTimeSharingInvitation.prepare(
            on: readWriteShare,
            eventEditingAllowed: true
        )

        XCTAssertEqual(
            readOnlyShare.participants.first { $0.role != .owner }?.permission,
            .readOnly
        )
        XCTAssertEqual(
            readWriteShare.participants.first { $0.role != .owner }?.permission,
            .readWrite
        )
    }

    func testReadWriteReceivedCalendarCannotWriteThroughOrdinaryEventUseCase() async throws {
        let calendar = makeReceivedCalendar(permission: .readWrite)
        let calendarRepository = InMemoryCalendarRepository(calendars: [calendar])
        let repository = InMemoryEventRepository()
        let useCase = EventUseCase(
            repository: repository,
            calendarRepository: calendarRepository
        )

        do {
            _ = try await useCase.createEvent(makeEvent(calendarID: calendar.id, title: "Blocked"))
            XCTFail("Received records must not enter the ordinary EventRepository write path")
        } catch {
            XCTAssertEqual(error as? CalendarSharingError, .permissionDenied)
        }
    }

    func testTwoParticipantsLastSuccessfulFullSaveWinsAndBothConverge() async throws {
        let calendar = makeReceivedDescriptor()
        let eventID = UUID()
        let original = makeSnapshot(id: eventID, title: "Original")
        let client = SharedEventEditingClientStub()
        client.receivedRecords[eventID] = makeEnvelope(
            snapshot: original,
            calendar: calendar,
            tag: "initial"
        )
        let participantA = makeUseCase(client: client)
        let participantB = makeUseCase(client: client)
        try participantA.reconcileReceived(
            calendar: calendar,
            envelopes: [client.receivedRecords[eventID]!]
        )
        try participantB.reconcileReceived(
            calendar: calendar,
            envelopes: [client.receivedRecords[eventID]!]
        )
        let editA = makeSnapshot(
            id: eventID,
            title: "A",
            startOffset: 600,
            duration: 1_800,
            isAllDay: true
        )
        let editB = makeSnapshot(
            id: eventID,
            title: "B",
            startOffset: 1_200,
            duration: 7_200,
            isAllDay: false
        )

        let participantAStatus = try await participantA.update(editA, in: calendar)
        let participantBStatus = try await participantB.update(editB, in: calendar)
        XCTAssertEqual(participantAStatus, .synced)
        XCTAssertEqual(participantBStatus, .synced)

        let final = try XCTUnwrap(client.receivedRecords[eventID])
        XCTAssertEqual(final.snapshot, editB)
        XCTAssertEqual(client.receivedWriteSnapshots, [editA, editB])

        try participantA.reconcileReceived(calendar: calendar, envelopes: [final])
        try participantB.reconcileReceived(calendar: calendar, envelopes: [final])
        XCTAssertEqual(participantA.visibleSnapshots(calendarID: calendar.id), [editB])
        XCTAssertEqual(participantB.visibleSnapshots(calendarID: calendar.id), [editB])
    }

    func testSameDeviceSerializesInFlightEditsSoOldTaskCannotOverwriteNewTask() async throws {
        let calendar = makeReceivedDescriptor()
        let eventID = UUID()
        let original = makeSnapshot(id: eventID, title: "Original")
        let client = SharedEventEditingClientStub()
        client.receivedRecords[eventID] = makeEnvelope(
            snapshot: original,
            calendar: calendar,
            tag: "initial"
        )
        let gate = SharedEventEditingTestGate()
        client.nextReceivedWriteGate = gate
        let useCase = makeUseCase(client: client)
        try useCase.reconcileReceived(
            calendar: calendar,
            envelopes: [client.receivedRecords[eventID]!]
        )
        let olderEdit = makeSnapshot(id: eventID, title: "Older save")
        let newerEdit = makeSnapshot(id: eventID, title: "Newer save", startOffset: 300)

        let olderTask = Task { @MainActor in
            try await useCase.update(olderEdit, in: calendar)
        }
        await gate.waitUntilEntered()
        let newerTask = Task { @MainActor in
            try await useCase.update(newerEdit, in: calendar)
        }
        while useCase.pendingMutations().count < 2 {
            await Task.yield()
        }
        gate.release()

        _ = try await olderTask.value
        _ = try await newerTask.value
        XCTAssertEqual(client.receivedWriteSnapshots, [olderEdit, newerEdit])
        XCTAssertEqual(client.receivedRecords[eventID]?.snapshot, newerEdit)
        XCTAssertEqual(useCase.visibleSnapshots(calendarID: calendar.id), [newerEdit])
        XCTAssertTrue(useCase.pendingMutations().isEmpty)
    }

    func testEditThenDeleteEndsAsTombstoneAndIsHidden() async throws {
        let calendar = makeReceivedDescriptor()
        let eventID = UUID()
        let client = SharedEventEditingClientStub()
        client.receivedRecords[eventID] = makeEnvelope(
            snapshot: makeSnapshot(id: eventID, title: "Original"),
            calendar: calendar,
            tag: "initial"
        )
        let useCase = makeUseCase(client: client)
        try useCase.reconcileReceived(
            calendar: calendar,
            envelopes: [client.receivedRecords[eventID]!]
        )

        _ = try await useCase.update(
            makeSnapshot(id: eventID, title: "Edited"),
            in: calendar
        )
        _ = try await useCase.delete(eventID: eventID, in: calendar)

        let remote = try XCTUnwrap(client.receivedRecords[eventID])
        XCTAssertTrue(remote.isDeleted)
        XCTAssertTrue(useCase.visibleSnapshots(calendarID: calendar.id).isEmpty)
        XCTAssertTrue(
            SharedEventMapper.occurrences(
                from: [remote.snapshot],
                in: DateInterval(start: .distantPast, end: .distantFuture)
            ).isEmpty
        )
    }

    func testDeleteThenStaleEditCannotReviveAndRepeatedDeleteIsIdempotent() async throws {
        let calendar = makeReceivedDescriptor()
        let eventID = UUID()
        let original = makeSnapshot(id: eventID, title: "Original")
        let client = SharedEventEditingClientStub()
        let initialEnvelope = makeEnvelope(
            snapshot: original,
            calendar: calendar,
            tag: "initial"
        )
        client.receivedRecords[eventID] = initialEnvelope
        let deletingParticipant = makeUseCase(client: client)
        let staleParticipant = makeUseCase(client: client)
        try deletingParticipant.reconcileReceived(calendar: calendar, envelopes: [initialEnvelope])
        try staleParticipant.reconcileReceived(calendar: calendar, envelopes: [initialEnvelope])

        let deleteStatus = try await deletingParticipant.delete(
            eventID: eventID,
            in: calendar
        )
        let staleStatus = try await staleParticipant.update(
            makeSnapshot(id: eventID, title: "Stale edit"),
            in: calendar
        )
        let repeatedDeleteStatus = try await deletingParticipant.delete(
            eventID: eventID,
            in: calendar
        )
        XCTAssertEqual(deleteStatus, .synced)
        XCTAssertEqual(staleStatus, .deletedRemotely)
        XCTAssertEqual(repeatedDeleteStatus, .synced)

        XCTAssertTrue(client.receivedRecords[eventID]?.isDeleted == true)
        XCTAssertEqual(client.receivedDeleteCallCount, 1)
        XCTAssertTrue(staleParticipant.visibleSnapshots(calendarID: calendar.id).isEmpty)
        XCTAssertTrue(staleParticipant.pendingMutations().isEmpty)
    }

    func testOfflineUpdateIsDiscardedWhenRefreshFindsServerTombstone() async throws {
        let calendar = makeReceivedDescriptor()
        let eventID = UUID()
        let original = makeSnapshot(id: eventID, title: "Original")
        let client = SharedEventEditingClientStub()
        let initialEnvelope = makeEnvelope(
            snapshot: original,
            calendar: calendar,
            tag: "initial"
        )
        client.receivedRecords[eventID] = initialEnvelope
        client.receivedWriteErrors = [.networkUnavailable]
        let useCase = makeUseCase(client: client)
        try useCase.reconcileReceived(calendar: calendar, envelopes: [initialEnvelope])

        let offlineStatus = try await useCase.update(
            makeSnapshot(id: eventID, title: "Offline edit"),
            in: calendar
        )
        XCTAssertEqual(offlineStatus, .pending)
        XCTAssertEqual(useCase.pendingMutations().count, 1)

        let tombstone = makeEnvelope(
            snapshot: makeSnapshot(id: eventID, title: "Original", isDeleted: true),
            calendar: calendar,
            tag: "deleted"
        )
        client.receivedRecords[eventID] = tombstone
        try useCase.reconcileReceived(calendar: calendar, envelopes: [tombstone])
        try await useCase.retryPending(in: [calendar])

        XCTAssertTrue(useCase.pendingMutations().isEmpty)
        XCTAssertTrue(useCase.visibleSnapshots(calendarID: calendar.id).isEmpty)
        XCTAssertEqual(client.receivedUpdateCallCount, 1)
        XCTAssertTrue(client.receivedRecords[eventID]?.isDeleted == true)
    }

    func testOfflineCreateSurvivesRestartAndRetriesWithStableEventID() async throws {
        let calendar = makeReceivedDescriptor()
        let eventID = UUID()
        let snapshot = makeSnapshot(id: eventID, title: "Offline create")
        let persistence = makePersistence()
        let client = SharedEventEditingClientStub()
        client.receivedWriteErrors = [.networkUnavailable]
        var useCase: SharedEventEditingUseCase? = SharedEventEditingUseCase(
            client: client,
            eventUseCase: EventUseCase(repository: InMemoryEventRepository()),
            persistence: persistence
        )

        let offlineCreateStatus = try await useCase?.create(snapshot, in: calendar)
        XCTAssertEqual(offlineCreateStatus, .pending)
        XCTAssertEqual(useCase?.pendingMutations().first?.operation, .create)
        XCTAssertEqual(useCase?.pendingMutations().first?.eventID, eventID)

        useCase = nil
        let relaunched = SharedEventEditingUseCase(
            client: client,
            eventUseCase: EventUseCase(repository: InMemoryEventRepository()),
            persistence: persistence
        )
        try relaunched.reconcileReceived(calendar: calendar, envelopes: [])
        try await relaunched.retryPending(in: [calendar])

        XCTAssertTrue(relaunched.pendingMutations().isEmpty)
        XCTAssertEqual(client.receivedCreateEventIDs, [eventID, eventID])
        XCTAssertEqual(client.receivedRecords.count, 1)
        XCTAssertEqual(
            client.receivedRecords[eventID]?.recordName,
            "collaborative-event-\(eventID.uuidString.lowercased())"
        )
    }

    func testOfflineUpdateAndDeleteOutboxEntriesSurviveRestart() async throws {
        let calendar = makeReceivedDescriptor()
        let updateID = UUID()
        let deleteID = UUID()
        let updateEnvelope = makeEnvelope(
            snapshot: makeSnapshot(id: updateID, title: "Update original"),
            calendar: calendar,
            tag: "u1"
        )
        let deleteEnvelope = makeEnvelope(
            snapshot: makeSnapshot(id: deleteID, title: "Delete original"),
            calendar: calendar,
            tag: "d1"
        )
        let client = SharedEventEditingClientStub()
        client.receivedRecords = [updateID: updateEnvelope, deleteID: deleteEnvelope]
        client.receivedWriteErrors = [
            .networkUnavailable,
            .networkUnavailable,
            .networkUnavailable,
        ]
        let persistence = makePersistence()
        var useCase: SharedEventEditingUseCase? = SharedEventEditingUseCase(
            client: client,
            eventUseCase: EventUseCase(repository: InMemoryEventRepository()),
            persistence: persistence
        )
        try useCase?.reconcileReceived(
            calendar: calendar,
            envelopes: [updateEnvelope, deleteEnvelope]
        )

        _ = try await useCase?.update(
            makeSnapshot(id: updateID, title: "Offline update"),
            in: calendar
        )
        _ = try await useCase?.delete(eventID: deleteID, in: calendar)
        useCase = nil

        let persisted = try persistence.load().outbox
        XCTAssertEqual(Set(persisted.map(\.operation)), [.update, .delete])
        XCTAssertEqual(Set(persisted.map(\.eventID)), [updateID, deleteID])
        XCTAssertEqual(
            persisted.first { $0.operation == .update }?.status,
            .superseded,
            "An uncertain update must not replay over the server's existing version"
        )
        XCTAssertEqual(
            persisted.first { $0.operation == .delete }?.status,
            .awaitingReconciliation
        )
    }

    func testLaunchCacheBootstrapPreservesPersistedEnvelopeMetadataAndDrafts() async throws {
        let calendar = makeReceivedDescriptor()
        let editedID = UUID()
        let uncachedID = UUID()
        let editedEnvelope = makeEnvelope(
            snapshot: makeSnapshot(id: editedID, title: "Server baseline"),
            calendar: calendar,
            tag: "real-change-tag"
        )
        let uncachedEnvelope = makeEnvelope(
            snapshot: makeSnapshot(id: uncachedID, title: "Persisted but not cached"),
            calendar: calendar,
            tag: "second-change-tag"
        )
        let persistence = makePersistence()
        let client = SharedEventEditingClientStub()
        client.receivedRecords = [
            editedID: editedEnvelope,
            uncachedID: uncachedEnvelope,
        ]
        client.receivedWriteErrors = [.networkUnavailable]
        var useCase: SharedEventEditingUseCase? = makeUseCase(
            client: client,
            persistence: persistence
        )
        try useCase?.reconcileReceived(
            calendar: calendar,
            envelopes: [editedEnvelope, uncachedEnvelope]
        )
        let draft = makeSnapshot(id: editedID, title: "Offline draft")
        let updateStatus = try await useCase?.update(draft, in: calendar)
        XCTAssertEqual(updateStatus, .pending)
        useCase = nil

        let relaunched = makeUseCase(client: client, persistence: persistence)
        let snapshotOnlyCache = makeEnvelope(
            snapshot: editedEnvelope.snapshot,
            calendar: calendar,
            tag: "ignored-cache-tag"
        )
        try relaunched.reconcileReceived(
            calendar: calendar,
            envelopes: [snapshotOnlyCache],
            isAuthoritative: false
        )

        XCTAssertEqual(relaunched.envelope(calendarID: calendar.id, eventID: editedID)?.snapshot, draft)
        XCTAssertEqual(
            relaunched.envelope(calendarID: calendar.id, eventID: editedID)?.recordChangeTag,
            "real-change-tag"
        )
        XCTAssertEqual(relaunched.status(calendarID: calendar.id, eventID: editedID), .pending)
        XCTAssertNotNil(relaunched.envelope(calendarID: calendar.id, eventID: uncachedID))
        XCTAssertEqual(relaunched.visibleSnapshots(calendarID: calendar.id).count, 2)
    }

    func testOfflineCreateThenDeleteUsesTombstonePathAndCreatesNoGhostRecord() async throws {
        let calendar = makeReceivedDescriptor()
        let eventID = UUID()
        let client = SharedEventEditingClientStub()
        client.receivedWriteErrors = [.networkUnavailable]
        let useCase = makeUseCase(client: client)

        let createStatus = try await useCase.create(
            makeSnapshot(id: eventID, title: "Transient"),
            in: calendar
        )
        let deleteStatus = try await useCase.delete(eventID: eventID, in: calendar)
        XCTAssertEqual(createStatus, .pending)
        XCTAssertEqual(deleteStatus, .synced)

        XCTAssertEqual(
            client.receivedCreateEventIDs,
            [eventID, eventID],
            "A confirmed-missing create may retry, but it must retain one stable event ID"
        )
        XCTAssertEqual(client.receivedDeleteEventIDs, [eventID])
        XCTAssertTrue(
            client.receivedRecords[eventID]?.isDeleted == true,
            "Delete remains as a durable tombstone; it must not leave a visible ghost"
        )
        XCTAssertTrue(useCase.visibleSnapshots(calendarID: calendar.id).isEmpty)
        XCTAssertTrue(useCase.pendingMutations().isEmpty)
    }

    func testPermissionRevocationStopsRetryAndRestoredPermissionReplaysDraft() async throws {
        let calendar = makeReceivedDescriptor()
        let eventID = UUID()
        let initial = makeEnvelope(
            snapshot: makeSnapshot(id: eventID, title: "Original"),
            calendar: calendar,
            tag: "initial"
        )
        let client = SharedEventEditingClientStub()
        client.receivedRecords[eventID] = initial
        client.receivedWriteErrors = [.permissionDenied]
        let persistence = makePersistence()
        let useCase = makeUseCase(client: client, persistence: persistence)
        try useCase.reconcileReceived(calendar: calendar, envelopes: [initial])
        let draft = makeSnapshot(id: eventID, title: "Retained draft")

        let revokedStatus = try await useCase.update(draft, in: calendar)
        XCTAssertEqual(revokedStatus, .permissionRevoked)
        try await useCase.retryPending(in: [calendar])
        XCTAssertEqual(client.receivedUpdateCallCount, 1)
        XCTAssertEqual(useCase.pendingMutations().first?.payload, draft)

        var readOnly = calendar
        readOnly.eventEditingAllowed = false
        readOnly.participantPermission = .readOnly
        try useCase.reconcileReceived(calendar: readOnly, envelopes: [initial])
        let relaunched = makeUseCase(client: client, persistence: persistence)
        try relaunched.reconcileReceived(calendar: calendar, envelopes: [initial])
        try await relaunched.retryPending(in: [calendar])

        XCTAssertEqual(client.receivedUpdateCallCount, 2)
        XCTAssertEqual(client.receivedRecords[eventID]?.snapshot, draft)
        XCTAssertTrue(relaunched.pendingMutations().isEmpty)
    }

    func testPermanentFailureDoesNotRetryAutomatically() async throws {
        let calendar = makeReceivedDescriptor()
        let eventID = UUID()
        let initial = makeEnvelope(
            snapshot: makeSnapshot(id: eventID, title: "Original"),
            calendar: calendar,
            tag: "initial"
        )
        let client = SharedEventEditingClientStub()
        client.receivedRecords[eventID] = initial
        client.receivedWriteErrors = [.syncFailed]
        let useCase = makeUseCase(client: client)
        try useCase.reconcileReceived(calendar: calendar, envelopes: [initial])

        let failedStatus = try await useCase.update(
            makeSnapshot(id: eventID, title: "Failed edit"),
            in: calendar
        )
        XCTAssertEqual(failedStatus, .failed)
        try await useCase.retryPending(in: [calendar])

        XCTAssertEqual(client.receivedUpdateCallCount, 1)
        XCTAssertEqual(useCase.allParticipantMutations().last?.status, .failed)
    }

    func testOwnerLocalEditAndMutationJournalCommitTogether() async throws {
        let descriptor = makeOwnerDescriptor()
        let localCalendar = makeOwnerCalendar(id: descriptor.id)
        let calendarRepository = InMemoryCalendarRepository(calendars: [localCalendar])
        let repository = InMemoryEventRepository()
        let eventUseCase = EventUseCase(
            repository: repository,
            calendarRepository: calendarRepository
        )
        let event = makeEvent(calendarID: descriptor.id, title: "Owner create")

        _ = try await eventUseCase.createEvent(event)

        let stored = try await repository.event(id: event.id)
        let mutations = try await eventUseCase.ownerSharedEventMutations(
            calendarID: descriptor.id
        )
        XCTAssertEqual(stored?.title, event.title)
        XCTAssertEqual(mutations.count, 1)
        XCTAssertEqual(mutations.first?.operation, .create)
        XCTAssertEqual(mutations.first?.payload, SharedEventMapper.snapshot(from: event))
        XCTAssertEqual(mutations.first?.status, .prepared)
        XCTAssertGreaterThan(mutations.first?.sequence ?? 0, 0)
    }

    func testOwnerRemoteR1ThenR2WithUnavailableBaselineCreatesNoMutationOrCloudWrite() async throws {
        let calendar = makeOwnerDescriptor()
        let eventID = UUID()
        let repository = InMemoryEventRepository()
        let client = SharedEventEditingClientStub()
        let eventUseCase = EventUseCase(repository: repository)
        let persistenceFault = SharedEventPersistenceFaultInjector()
        persistenceFault.failAllSaves = true
        let useCase = SharedEventEditingUseCase(
            client: client,
            eventUseCase: eventUseCase,
            persistence: persistenceFault.persistence
        )
        let remoteR1 = makeSnapshot(id: eventID, title: "Participant R1")
        client.ownerRecords[eventID] = makeEnvelope(
            snapshot: remoteR1,
            calendar: calendar,
            tag: "r1"
        )
        try await useCase.synchronizeOwned(calendar: calendar)

        let remoteR2 = makeSnapshot(id: eventID, title: "Participant R2", startOffset: 600)
        client.ownerRecords[eventID] = makeEnvelope(
            snapshot: remoteR2,
            calendar: calendar,
            tag: "r2"
        )
        try await useCase.synchronizeOwned(calendar: calendar)

        let stored = try await repository.event(id: eventID)
        let mutations = try await eventUseCase.ownerSharedEventMutations(calendarID: calendar.id)
        XCTAssertEqual(stored?.title, remoteR2.title)
        XCTAssertTrue(mutations.isEmpty)
        XCTAssertTrue(client.ownerUpsertSnapshots.isEmpty)
        XCTAssertTrue(client.ownerDeleteEventIDs.isEmpty)
        XCTAssertEqual(
            persistenceFault.saveAttemptCount,
            0,
            "Owner synchronization must not use participant baseline persistence as write intent"
        )
    }

    func testOwnerEventAndMutationJournalRollbackTogetherWhenAtomicSaveFails() async throws {
        let descriptor = makeOwnerDescriptor()
        let calendarRepository = InMemoryCalendarRepository(
            calendars: [makeOwnerCalendar(id: descriptor.id)]
        )
        let repository = FaultInjectingOwnerMutationRepository()
        await repository.failNextAtomicWrite()
        let eventUseCase = EventUseCase(
            repository: repository,
            calendarRepository: calendarRepository
        )
        let event = makeEvent(calendarID: descriptor.id, title: "Must roll back")

        do {
            _ = try await eventUseCase.createEvent(event)
            XCTFail("The injected atomic persistence failure must be surfaced")
        } catch {
            XCTAssertEqual(error as? CalendarSharingError, .localPersistenceFailed)
        }

        let storedEvent = try await repository.event(id: event.id)
        let storedMutations = try await repository.ownerSharedEventMutations(
            calendarID: descriptor.id
        )
        let ordinaryCreateCallCount = await repository.ordinaryCreateCallCount()
        XCTAssertNil(storedEvent)
        XCTAssertTrue(storedMutations.isEmpty)
        XCTAssertEqual(ordinaryCreateCallCount, 0)
    }

    func testOwnerCloudSuccessLocalCompletionFailureReconcilesBeforeRemoteB() async throws {
        let descriptor = makeOwnerDescriptor()
        let calendarRepository = InMemoryCalendarRepository(
            calendars: [makeOwnerCalendar(id: descriptor.id)]
        )
        let repository = FaultInjectingOwnerMutationRepository()
        let eventUseCase = EventUseCase(
            repository: repository,
            calendarRepository: calendarRepository
        )
        let event = makeEvent(calendarID: descriptor.id, title: "Owner mutation A")
        _ = try await eventUseCase.createEvent(event)
        await repository.failNextCompletedMutationSave()
        let client = SharedEventEditingClientStub()
        let editing = SharedEventEditingUseCase(
            client: client,
            eventUseCase: eventUseCase,
            persistence: makePersistence()
        )

        do {
            try await editing.synchronizeOwned(calendar: descriptor)
            XCTFail("Cloud success followed by a local completion failure must surface")
        } catch {
            XCTAssertEqual(error as? CalendarSharingError, .localPersistenceFailed)
        }
        let uncertainMutations = try await repository.ownerSharedEventMutations(
            calendarID: descriptor.id
        )
        let uncertain = try XCTUnwrap(uncertainMutations.first)
        XCTAssertEqual(uncertain.status, .sending)
        XCTAssertEqual(client.ownerRecords[event.id]?.lastMutationID, uncertain.id)

        let remoteMutationB = UUID()
        let remoteB = makeSnapshot(
            id: event.id,
            title: "Participant mutation B",
            startOffset: 900
        )
        client.ownerRecords[event.id] = makeEnvelope(
            snapshot: remoteB,
            calendar: descriptor,
            tag: "remote-b",
            lastMutationID: remoteMutationB
        )
        try await editing.synchronizeOwned(calendar: descriptor)

        let reconciledMutations = try await repository.ownerSharedEventMutations(
            calendarID: descriptor.id
        )
        let reconciled = try XCTUnwrap(reconciledMutations.first)
        let storedRemoteB = try await repository.event(id: event.id)
        XCTAssertEqual(reconciled.status, .superseded)
        XCTAssertEqual(reconciled.payload.title, "Owner mutation A")
        XCTAssertEqual(client.ownerUpsertSnapshots.count, 1)
        XCTAssertEqual(storedRemoteB?.title, remoteB.title)
    }

    func testParticipantCloudSuccessLocalCompletionFailureDoesNotReplayOverRemoteB() async throws {
        let calendar = makeReceivedDescriptor()
        let eventID = UUID()
        let original = makeSnapshot(id: eventID, title: "Original")
        let mutationA = makeSnapshot(id: eventID, title: "Mutation A", startOffset: 300)
        let mutationB = makeSnapshot(id: eventID, title: "Mutation B", startOffset: 900)
        let client = SharedEventEditingClientStub()
        let originalEnvelope = makeEnvelope(
            snapshot: original,
            calendar: calendar,
            tag: "original"
        )
        client.receivedRecords[eventID] = originalEnvelope
        let persistenceFault = SharedEventPersistenceFaultInjector()
        let useCase = makeUseCase(client: client, persistence: persistenceFault.persistence)
        try useCase.reconcileReceived(calendar: calendar, envelopes: [originalEnvelope])
        persistenceFault.failNextCompletionSave = true

        do {
            _ = try await useCase.update(mutationA, in: calendar)
            XCTFail("The local completion-state persistence error must reach the caller")
        } catch {
            XCTAssertEqual(error as? CalendarSharingError, .localPersistenceFailed)
        }
        let durableMutation = try XCTUnwrap(
            try persistenceFault.persistence.load().outbox.first
        )
        XCTAssertEqual(durableMutation.status, .sending)
        XCTAssertEqual(client.receivedRecords[eventID]?.lastMutationID, durableMutation.id)

        let mutationBID = UUID()
        let remoteB = makeEnvelope(
            snapshot: mutationB,
            calendar: calendar,
            tag: "remote-b",
            lastMutationID: mutationBID
        )
        client.receivedRecords[eventID] = remoteB
        let relaunched = makeUseCase(client: client, persistence: persistenceFault.persistence)
        try relaunched.reconcileReceived(calendar: calendar, envelopes: [remoteB])
        let writeCountBeforeReconciliation = client.receivedUpdateCallCount
        try await relaunched.retryPending(in: [calendar])

        let reconciled = try XCTUnwrap(
            relaunched.allParticipantMutations().first { $0.id == durableMutation.id }
        )
        XCTAssertEqual(reconciled.status, .superseded)
        XCTAssertEqual(reconciled.payload, mutationA, "The superseded draft remains recoverable")
        XCTAssertEqual(client.receivedUpdateCallCount, writeCountBeforeReconciliation)
        XCTAssertEqual(client.receivedRecords[eventID]?.snapshot, mutationB)
        XCTAssertEqual(relaunched.visibleSnapshots(calendarID: calendar.id), [mutationB])
    }

    func testParticipantRestartCompletesSendingWhenServerMutationIDMatches() async throws {
        let calendar = makeReceivedDescriptor()
        let eventID = UUID()
        let original = makeSnapshot(id: eventID, title: "Original")
        let update = makeSnapshot(id: eventID, title: "Accepted A")
        let client = SharedEventEditingClientStub()
        let originalEnvelope = makeEnvelope(snapshot: original, calendar: calendar, tag: "old")
        client.receivedRecords[eventID] = originalEnvelope
        let persistenceFault = SharedEventPersistenceFaultInjector()
        let useCase = makeUseCase(client: client, persistence: persistenceFault.persistence)
        try useCase.reconcileReceived(calendar: calendar, envelopes: [originalEnvelope])
        persistenceFault.failNextCompletionSave = true
        do {
            _ = try await useCase.update(update, in: calendar)
            XCTFail("Expected injected local completion failure")
        } catch {
            XCTAssertEqual(error as? CalendarSharingError, .localPersistenceFailed)
        }
        let mutation = try XCTUnwrap(try persistenceFault.persistence.load().outbox.first)

        let relaunched = makeUseCase(client: client, persistence: persistenceFault.persistence)
        try await relaunched.retryPending(in: [calendar])

        XCTAssertEqual(
            relaunched.allParticipantMutations().first { $0.id == mutation.id }?.status,
            .completed
        )
        XCTAssertEqual(client.receivedUpdateCallCount, 1)
        XCTAssertEqual(relaunched.visibleSnapshots(calendarID: calendar.id), [update])
    }

    func testParticipantRestartStopsSendingWhenServerHasTombstone() async throws {
        let calendar = makeReceivedDescriptor()
        let eventID = UUID()
        let original = makeSnapshot(id: eventID, title: "Original")
        let update = makeSnapshot(id: eventID, title: "Accepted then deleted")
        let client = SharedEventEditingClientStub()
        let originalEnvelope = makeEnvelope(snapshot: original, calendar: calendar, tag: "old")
        client.receivedRecords[eventID] = originalEnvelope
        let persistenceFault = SharedEventPersistenceFaultInjector()
        let useCase = makeUseCase(client: client, persistence: persistenceFault.persistence)
        try useCase.reconcileReceived(calendar: calendar, envelopes: [originalEnvelope])
        persistenceFault.failNextCompletionSave = true
        do {
            _ = try await useCase.update(update, in: calendar)
            XCTFail("Expected injected local completion failure")
        } catch {
            XCTAssertEqual(error as? CalendarSharingError, .localPersistenceFailed)
        }
        let mutation = try XCTUnwrap(try persistenceFault.persistence.load().outbox.first)
        client.receivedRecords[eventID] = makeEnvelope(
            snapshot: makeSnapshot(id: eventID, title: "Deleted", isDeleted: true),
            calendar: calendar,
            tag: "tombstone",
            lastMutationID: UUID()
        )

        let relaunched = makeUseCase(client: client, persistence: persistenceFault.persistence)
        try await relaunched.retryPending(in: [calendar])

        XCTAssertEqual(
            relaunched.allParticipantMutations().first { $0.id == mutation.id }?.status,
            .deletedRemotely
        )
        XCTAssertEqual(client.receivedUpdateCallCount, 1)
        XCTAssertTrue(relaunched.visibleSnapshots(calendarID: calendar.id).isEmpty)
    }

    func testConfirmedNotSentMutationCanRetryWithStableMutationID() async throws {
        let calendar = makeReceivedDescriptor()
        let snapshot = makeSnapshot(title: "Safe retry")
        let client = SharedEventEditingClientStub()
        client.confirmedNotSentWriteErrors = [.networkUnavailable]
        let useCase = makeUseCase(client: client)

        let initialStatus = try await useCase.create(snapshot, in: calendar)
        let prepared = try XCTUnwrap(useCase.pendingMutations().first)
        XCTAssertEqual(initialStatus, .pending)
        XCTAssertEqual(prepared.status, .prepared)
        XCTAssertTrue(prepared.lastErrorCode?.hasPrefix("confirmed_not_sent:") == true)

        try await useCase.retryPending(in: [calendar])

        XCTAssertEqual(client.receivedAttemptMutationIDs, [prepared.id, prepared.id])
        XCTAssertEqual(client.receivedCreateEventIDs, [snapshot.id, snapshot.id])
        XCTAssertEqual(useCase.allParticipantMutations().first?.status, .completed)
        XCTAssertEqual(client.receivedRecords[snapshot.id]?.snapshot, snapshot)
    }

    func testRemovedReceivedCalendarPurgesPersistentOutboxBeforeDeletingLocalCalendar() async throws {
        let descriptor = makeReceivedDescriptor()
        let calendar = makeReceivedCalendar(id: descriptor.id, permission: .readWrite)
        let eventID = UUID()
        let original = makeSnapshot(id: eventID, title: "Original")
        let client = SharedEventEditingClientStub()
        let initialEnvelope = makeEnvelope(
            snapshot: original,
            calendar: descriptor,
            tag: "initial"
        )
        client.receivedRecords[eventID] = initialEnvelope
        client.receivedWriteErrors = [.networkUnavailable]
        let persistence = makePersistence()
        let seedingUseCase = SharedEventEditingUseCase(
            client: client,
            eventUseCase: EventUseCase(repository: InMemoryEventRepository()),
            persistence: persistence
        )
        try seedingUseCase.reconcileReceived(
            calendar: descriptor,
            envelopes: [initialEnvelope]
        )
        _ = try await seedingUseCase.update(
            makeSnapshot(id: eventID, title: "Offline draft"),
            in: descriptor
        )
        XCTAssertEqual(try persistence.load().outbox.count, 1)

        let calendarRepository = InMemoryCalendarRepository(calendars: [calendar])
        let defaults = try XCTUnwrap(
            UserDefaults(suiteName: "SharedEventRemoval-\(UUID().uuidString)")
        )
        let cache = CalendarSharingCache(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(
                "SharedEventRemovalCache-\(UUID().uuidString).json"
            )
        )
        let store = CalendarSharingStore(
            client: client,
            eventUseCase: EventUseCase(repository: InMemoryEventRepository()),
            calendarRepository: calendarRepository,
            cache: cache,
            sharedEventEditingPersistence: persistence,
            selectionPersistence: CalendarSelectionPersistence(defaults: defaults),
            syncMetadataPersistence: CalendarSharingSyncMetadataPersistence(defaults: defaults)
        )

        await store.start()

        let removedCalendar = await calendarRepository.calendar(id: calendar.id)
        XCTAssertNil(removedCalendar)
        XCTAssertTrue(try persistence.load().outbox.isEmpty)
        XCTAssertNil(try persistence.load().envelopesByCalendarID[calendar.id])
    }

    func testLocalRestoreKeepsSharedEventPersistenceFailureVisible() async throws {
        let persistenceFault = SharedEventPersistenceFaultInjector()
        let defaults = try XCTUnwrap(
            UserDefaults(suiteName: "SharedEventRestore-\(UUID().uuidString)")
        )
        let store = CalendarSharingStore(
            client: SharedEventEditingClientStub(),
            eventUseCase: EventUseCase(repository: InMemoryEventRepository()),
            calendarRepository: InMemoryCalendarRepository(),
            cache: CalendarSharingCache(
                fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(
                    "SharedEventRestoreCache-\(UUID().uuidString).json"
                )
            ),
            sharedEventEditingPersistence: persistenceFault.persistence,
            selectionPersistence: CalendarSelectionPersistence(defaults: defaults),
            syncMetadataPersistence: CalendarSharingSyncMetadataPersistence(defaults: defaults)
        )
        persistenceFault.failAllSaves = true

        await store.handleLocalDataRestore()

        XCTAssertEqual(store.lastError, .localPersistenceFailed)
    }

    func testLeaveKeepsLocalCalendarWhenOutboxCleanupCannotPersist() async throws {
        let descriptor = makeReceivedDescriptor()
        let calendar = makeReceivedCalendar(id: descriptor.id, permission: .readWrite)
        let calendarRepository = InMemoryCalendarRepository(calendars: [calendar])
        let persistenceFault = SharedEventPersistenceFaultInjector()
        let defaults = try XCTUnwrap(
            UserDefaults(suiteName: "SharedEventLeave-\(UUID().uuidString)")
        )
        let store = CalendarSharingStore(
            client: SharedEventEditingClientStub(),
            eventUseCase: EventUseCase(repository: InMemoryEventRepository()),
            calendarRepository: calendarRepository,
            cache: CalendarSharingCache(
                fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(
                    "SharedEventLeaveCache-\(UUID().uuidString).json"
                )
            ),
            sharedEventEditingPersistence: persistenceFault.persistence,
            selectionPersistence: CalendarSelectionPersistence(defaults: defaults),
            syncMetadataPersistence: CalendarSharingSyncMetadataPersistence(defaults: defaults)
        )
        persistenceFault.failAllSaves = true

        do {
            try await store.leave(descriptor)
            XCTFail("Expected durable shared-event cleanup to fail")
        } catch {
            XCTAssertEqual(error as? CalendarSharingError, .localPersistenceFailed)
        }

        let retainedCalendar = await calendarRepository.calendar(id: calendar.id)
        XCTAssertEqual(retainedCalendar?.id, calendar.id)
    }

    func testRemoteOwnerMergeReschedulesAndCancelsNotificationAndRefreshesWidgetOnly() async throws {
        let calendar = makeOwnerDescriptor()
        let eventID = UUID()
        let repository = InMemoryEventRepository()
        let scheduler = EventNotificationSchedulerSpy()
        let existing = makeEvent(
            id: eventID,
            calendarID: calendar.id,
            title: "Owner private reminder",
            note: "private note",
            reminderOffsetMinutes: 15,
            notificationID: "old-notification"
        )
        try await repository.create(existing)
        let eventUseCase = EventUseCase(
            repository: repository,
            notificationScheduler: scheduler
        )
        var localMutationCallbackCount = 0
        var widgetRefreshCount = 0
        eventUseCase.onEventsChanged = { localMutationCallbackCount += 1 }
        eventUseCase.onRemoteEventsMaterialized = { widgetRefreshCount += 1 }
        let client = SharedEventEditingClientStub()
        let editing = SharedEventEditingUseCase(
            client: client,
            eventUseCase: eventUseCase,
            persistence: makePersistence()
        )
        let remoteUpdate = makeSnapshot(
            id: eventID,
            title: "Participant moved event",
            startOffset: 1_800
        )
        client.ownerRecords[eventID] = makeEnvelope(
            snapshot: remoteUpdate,
            calendar: calendar,
            tag: "update",
            lastMutationID: UUID()
        )

        try await editing.synchronizeOwned(calendar: calendar)

        XCTAssertEqual(scheduler.scheduledEvents.count, 1)
        XCTAssertEqual(scheduler.scheduledEvents.first?.startDate, remoteUpdate.startDate)
        XCTAssertEqual(scheduler.scheduledEvents.first?.title, remoteUpdate.title)
        let storedRemoteUpdate = try await repository.event(id: eventID)
        XCTAssertEqual(storedRemoteUpdate?.note, "private note")
        XCTAssertEqual(storedRemoteUpdate?.reminderOffsetMinutes, 15)
        XCTAssertEqual(scheduler.cancelledIDs, ["old-notification"])
        XCTAssertEqual(widgetRefreshCount, 1)
        XCTAssertEqual(localMutationCallbackCount, 0)
        XCTAssertTrue(client.ownerUpsertSnapshots.isEmpty)

        let tombstone = makeSnapshot(id: eventID, title: remoteUpdate.title, isDeleted: true)
        client.ownerRecords[eventID] = makeEnvelope(
            snapshot: tombstone,
            calendar: calendar,
            tag: "delete",
            lastMutationID: UUID()
        )
        try await editing.synchronizeOwned(calendar: calendar)

        let storedAfterDelete = try await repository.event(id: eventID)
        XCTAssertNil(storedAfterDelete)
        XCTAssertEqual(scheduler.cancelledIDs, ["old-notification", "notification-1"])
        XCTAssertEqual(widgetRefreshCount, 2)
        XCTAssertEqual(localMutationCallbackCount, 0)

        let noReminder = makeSnapshot(title: "Remote create without reminder")
        client.ownerRecords[noReminder.id] = makeEnvelope(
            snapshot: noReminder,
            calendar: calendar,
            tag: "create",
            lastMutationID: UUID()
        )
        try await editing.synchronizeOwned(calendar: calendar)

        let storedNoReminder = try await repository.event(id: noReminder.id)
        let ownerMutations = try await eventUseCase.ownerSharedEventMutations(
            calendarID: calendar.id
        )
        XCTAssertNotNil(storedNoReminder)
        XCTAssertEqual(scheduler.scheduledEvents.count, 1)
        XCTAssertEqual(widgetRefreshCount, 3)
        XCTAssertEqual(localMutationCallbackCount, 0)
        XCTAssertTrue(ownerMutations.isEmpty)
        XCTAssertTrue(client.ownerUpsertSnapshots.isEmpty)
        XCTAssertTrue(client.ownerDeleteEventIDs.isEmpty)
    }

    func testLegacyReplacementPlannerCannotTouchCollaborativeEventsOrTombstones() {
        let zoneID = CKRecordZone.ID(zoneName: "legacy-zone", ownerName: "owner")
        let legacyID = CKRecord.ID(recordName: "event-legacy", zoneID: zoneID)
        let collaborativeID = CKRecord.ID(recordName: "collaborative-event-live", zoneID: zoneID)
        let tombstoneID = CKRecord.ID(
            recordName: "collaborative-event-tombstone",
            zoneID: zoneID
        )
        let legacy = CKRecord(
            recordType: CalendarSharingCloudSchema.eventRecordType,
            recordID: legacyID
        )
        let collaborative = CKRecord(
            recordType: CalendarSharingCloudSchema.collaborativeEventRecordType,
            recordID: collaborativeID
        )
        let tombstone = CKRecord(
            recordType: CalendarSharingCloudSchema.collaborativeEventRecordType,
            recordID: tombstoneID
        )
        tombstone[CalendarSharingCloudSchema.EventField.isDeleted] = NSNumber(value: true)
        var collection = SharedZoneRecordCollection()
        collection.apply([legacy, collaborative, tombstone])

        // This is the old binary's explicit SharedEvent replacement input boundary.
        let oldReplacementInput = collection.records(
            ofType: CalendarSharingCloudSchema.eventRecordType
        )
        let plan = CalendarSharingContentRecordPlan(
            recordType: CalendarSharingCloudSchema.eventRecordType,
            existingRecords: oldReplacementInput,
            snapshots: [SharedEventSnapshot](),
            recordID: { snapshot in
                CKRecord.ID(
                    recordName: "event-\(snapshot.id.uuidString.lowercased())",
                    zoneID: zoneID
                )
            },
            makeRecord: CalendarSharingCloudRecordFactory.makeEventRecord
        )
        let touchedIDs = Set(
            plan.legacyRecordIDsToDelete
                + plan.ordinaryRecordIDsToDelete
                + plan.recordsToRecreate.map(\.recordID)
                + plan.recordsToSave.map(\.recordID)
        )

        XCTAssertEqual(touchedIDs, [legacyID])
        XCTAssertFalse(touchedIDs.contains(collaborativeID))
        XCTAssertFalse(touchedIDs.contains(tombstoneID))
        XCTAssertEqual(collection.recordsByID[collaborativeID]?.recordType, "CollaborativeEvent")
        XCTAssertEqual(
            collection.recordsByID[tombstoneID]?[
                CalendarSharingCloudSchema.EventField.isDeleted
            ] as? NSNumber,
            NSNumber(value: true)
        )
    }

    func testServerRecordChangedBranchRetriesFullPayloadTwiceAndStopsAtThird() throws {
        let zoneID = CKRecordZone.ID(zoneName: "conflict-zone", ownerName: "owner")
        let eventID = UUID()
        let recordID = CKRecord.ID(
            recordName: "collaborative-event-\(eventID.uuidString.lowercased())",
            zoneID: zoneID
        )
        let serverSnapshot = makeSnapshot(
            id: eventID,
            title: "Concurrent server value",
            startOffset: 300,
            duration: 1_800,
            isAllDay: true
        )
        let serverRecord = CalendarSharingCloudRecordFactory.makeCollaborativeEventRecord(
            snapshot: serverSnapshot,
            recordID: recordID,
            mutationID: UUID()
        )
        let conflict = CKError(
            _nsError: NSError(
                domain: CKError.errorDomain,
                code: CKError.Code.serverRecordChanged.rawValue,
                userInfo: [CKRecordChangedErrorServerRecordKey: serverRecord]
            )
        )

        let extracted = try XCTUnwrap(SharedEventServerConflict.serverRecord(in: conflict))
        XCTAssertEqual(extracted.recordID, recordID)
        XCTAssertTrue(SharedEventServerConflict.shouldRetry(afterAttempt: 1))
        XCTAssertTrue(SharedEventServerConflict.shouldRetry(afterAttempt: 2))
        XCTAssertFalse(SharedEventServerConflict.shouldRetry(afterAttempt: 3))
        XCTAssertEqual(SharedEventServerConflict.maximumAttempts, 3)

        let proposedMutationID = UUID()
        let proposed = makeSnapshot(
            id: eventID,
            title: "Complete local payload",
            startOffset: 1_200,
            duration: 7_200,
            isAllDay: false
        )
        let retryRecord = CalendarSharingCloudRecordFactory.makeCollaborativeEventRecord(
            snapshot: proposed,
            recordID: recordID,
            existingRecord: extracted,
            mutationID: proposedMutationID
        )
        XCTAssertEqual(
            ReceivedSharedCalendarPayloadAssembler.decodeEvent(retryRecord),
            proposed,
            "Conflict retry must use the complete proposed payload, not a field merge"
        )
        XCTAssertEqual(
            retryRecord[CalendarSharingCloudSchema.EventField.lastMutationID] as? String,
            proposedMutationID.uuidString
        )

        let tombstone = CalendarSharingCloudRecordFactory.makeCollaborativeEventRecord(
            snapshot: makeSnapshot(id: eventID, title: "Deleted", isDeleted: true),
            recordID: recordID,
            mutationID: UUID()
        )
        XCTAssertTrue(
            ReceivedSharedCalendarPayloadAssembler.decodeEvent(tombstone)?.isDeleted == true,
            "The production conflict branch treats this server input as delete-wins"
        )
    }

    func testOwnerSynchronizationMergesCreateUpdateDeleteAndPreservesPrivateFields() async throws {
        let calendar = makeOwnerDescriptor()
        let changedID = UUID()
        let createdID = UUID()
        let deletedID = UUID()
        let oldChanged = makeSnapshot(id: changedID, title: "Old title")
        let oldDeleted = makeSnapshot(id: deletedID, title: "Delete me")
        let remoteChanged = makeSnapshot(id: changedID, title: "Participant title")
        let remoteCreated = makeSnapshot(id: createdID, title: "Participant new")
        let remoteDeleted = makeSnapshot(id: deletedID, title: "Delete me", isDeleted: true)
        let baseline = [
            makeEnvelope(snapshot: oldChanged, calendar: calendar, tag: "c1"),
            makeEnvelope(snapshot: oldDeleted, calendar: calendar, tag: "d1"),
        ]
        let remote = [
            makeEnvelope(snapshot: remoteChanged, calendar: calendar, tag: "c2"),
            makeEnvelope(snapshot: remoteCreated, calendar: calendar, tag: "n1"),
            makeEnvelope(snapshot: remoteDeleted, calendar: calendar, tag: "d2"),
        ]
        let persistence = makePersistence()
        var persisted = SharedEventEditingPersistenceData()
        persisted.envelopesByCalendarID[calendar.id] = Dictionary(
            uniqueKeysWithValues: baseline.map { ($0.id, $0) }
        )
        try persistence.save(persisted)
        let repository = InMemoryEventRepository()
        var changedLocal = makeEvent(
            id: changedID,
            calendarID: calendar.id,
            title: oldChanged.title,
            note: "private memo",
            reminderOffsetMinutes: 15,
            notificationID: "private-notification"
        )
        changedLocal.updatedAt = oldChanged.updatedAt
        var deletedLocal = makeEvent(
            id: deletedID,
            calendarID: calendar.id,
            title: oldDeleted.title
        )
        deletedLocal.updatedAt = oldDeleted.updatedAt
        try await repository.create(changedLocal)
        try await repository.create(deletedLocal)
        let client = SharedEventEditingClientStub()
        client.ownerRecords = Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })
        let useCase = SharedEventEditingUseCase(
            client: client,
            eventUseCase: EventUseCase(repository: repository),
            persistence: persistence
        )

        try await useCase.synchronizeOwned(calendar: calendar)

        let changed = try await repository.event(id: changedID)
        let created = try await repository.event(id: createdID)
        let deleted = try await repository.event(id: deletedID)
        XCTAssertEqual(changed?.title, remoteChanged.title)
        XCTAssertEqual(changed?.note, "private memo")
        XCTAssertEqual(changed?.reminderOffsetMinutes, 15)
        XCTAssertEqual(changed?.notificationID, "private-notification")
        XCTAssertEqual(created?.title, remoteCreated.title)
        XCTAssertNil(created?.note)
        XCTAssertNil(deleted)
        XCTAssertTrue(client.ownerUpsertSnapshots.isEmpty)
        XCTAssertTrue(client.ownerDeleteEventIDs.isEmpty)

        try await useCase.synchronizeOwned(calendar: calendar)
        XCTAssertTrue(client.ownerUpsertSnapshots.isEmpty)
        XCTAssertTrue(client.ownerDeleteEventIDs.isEmpty)
    }

    func testCloudSchemaDefaultsMissingPermissionAndDeletionFieldsSafely() throws {
        let calendarID = UUID()
        let zoneID = CKRecordZone.ID(zoneName: "legacy-zone", ownerName: "owner")
        let root = CKRecord(
            recordType: CalendarSharingCloudSchema.calendarRecordType,
            recordID: CKRecord.ID(
                recordName: CalendarSharingCloudSchema.calendarRecordName,
                zoneID: zoneID
            )
        )
        root[CalendarSharingCloudSchema.CalendarField.calendarID] =
            calendarID.uuidString as CKRecordValue
        root[CalendarSharingCloudSchema.CalendarField.calendarName] =
            "Legacy" as CKRecordValue
        let descriptor = try XCTUnwrap(
            CalendarSharingCloudSchema.receivedDescriptor(
                from: root,
                zoneID: zoneID,
                ownerDisplayName: nil,
                participantCount: 1,
                participantPermission: .readWrite
            )
        )
        XCTAssertFalse(descriptor.eventEditingAllowed)
        XCTAssertTrue(descriptor.isReadOnly)

        let snapshot = makeSnapshot(id: UUID(), title: "Legacy event")
        let recordID = CKRecord.ID(
            recordName: "event-\(snapshot.id.uuidString.lowercased())",
            zoneID: zoneID
        )
        let legacyRecord = CKRecord(
            recordType: CalendarSharingCloudSchema.eventRecordType,
            recordID: recordID
        )
        legacyRecord[CalendarSharingCloudSchema.EventField.eventID] =
            snapshot.id.uuidString as CKRecordValue
        legacyRecord[CalendarSharingCloudSchema.EventField.title] = snapshot.title as CKRecordValue
        legacyRecord[CalendarSharingCloudSchema.EventField.startDate] =
            snapshot.startDate as CKRecordValue
        legacyRecord[CalendarSharingCloudSchema.EventField.endDate] =
            snapshot.endDate as CKRecordValue
        legacyRecord[CalendarSharingCloudSchema.EventField.isAllDay] =
            NSNumber(value: snapshot.isAllDay)
        legacyRecord[CalendarSharingCloudSchema.EventField.updatedAt] =
            snapshot.updatedAt as CKRecordValue

        let decodedLegacy = try XCTUnwrap(
            ReceivedSharedCalendarPayloadAssembler.decodeEvent(legacyRecord)
        )
        XCTAssertFalse(decodedLegacy.isDeleted)
        XCTAssertNil(decodedLegacy.deletedAt)

        let deleted = makeSnapshot(id: snapshot.id, title: snapshot.title, isDeleted: true)
        let tombstoneRecord = CalendarSharingCloudRecordFactory.makeEventRecord(
            snapshot: deleted,
            recordID: recordID
        )
        XCTAssertEqual(
            (tombstoneRecord[CalendarSharingCloudSchema.EventField.isDeleted] as? NSNumber)?
                .boolValue,
            true
        )
        XCTAssertEqual(
            tombstoneRecord[CalendarSharingCloudSchema.EventField.deletedAt] as? Date,
            deleted.deletedAt
        )
    }

    func testZoneStateStorePersistsMaterializedRecordsPerDatabaseScope() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "CalendarSharingZoneStateTests-\(UUID().uuidString)",
            isDirectory: true
        )
        let store = CalendarSharingZoneStateStore(directoryURL: directory)
        let zoneID = CKRecordZone.ID(zoneName: "zone", ownerName: "owner")
        let record = CKRecord(
            recordType: CalendarSharingCloudSchema.eventRecordType,
            recordID: CKRecord.ID(recordName: "event-one", zoneID: zoneID)
        )
        record[CalendarSharingCloudSchema.EventField.title] = "Persisted" as CKRecordValue
        var collection = SharedZoneRecordCollection()
        collection.apply([record])

        try store.save(
            CalendarSharingPersistedZoneState(records: collection, changeToken: nil),
            scope: .receivedShared,
            zoneID: zoneID
        )

        let loaded = try XCTUnwrap(store.load(scope: .receivedShared, zoneID: zoneID))
        XCTAssertEqual(loaded.records.allRecords.map(\.recordID.recordName), ["event-one"])
        XCTAssertEqual(
            loaded.records.allRecords.first?[
                CalendarSharingCloudSchema.EventField.title
            ] as? String,
            "Persisted"
        )
        XCTAssertNil(store.load(scope: .ownedPrivate, zoneID: zoneID))

        store.remove(scope: .receivedShared, zoneID: zoneID)
        XCTAssertNil(store.load(scope: .receivedShared, zoneID: zoneID))
    }

    private func makeUseCase(
        client: SharedEventEditingClientStub,
        persistence: SharedEventEditingPersistence? = nil
    ) -> SharedEventEditingUseCase {
        SharedEventEditingUseCase(
            client: client,
            eventUseCase: EventUseCase(repository: InMemoryEventRepository()),
            persistence: persistence ?? makePersistence()
        )
    }

    private func makePersistence() -> SharedEventEditingPersistence {
        SharedEventEditingPersistence(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(
                "SharedEventEditingTests-\(UUID().uuidString).json"
            )
        )
    }
}

@MainActor
private final class SharedEventEditingClientStub: CalendarSharingClientProtocol {
    var receivedDescriptors: [SharedCalendarDescriptor] = []
    var confirmedNotSentEventIDs: Set<UUID> = []
    var receivedRecords: [UUID: SharedEventEnvelope] = [:]
    var ownerRecords: [UUID: SharedEventEnvelope] = [:]
    var receivedWriteErrors: [CalendarSharingError] = []
    var confirmedNotSentWriteErrors: [CalendarSharingError] = []
    var nextReceivedWriteGate: SharedEventEditingTestGate?
    var receivedWriteSnapshots: [SharedEventSnapshot] = []
    var receivedWriteMutationIDs: [UUID] = []
    var receivedAttemptMutationIDs: [UUID] = []
    var receivedCreateEventIDs: [UUID] = []
    var receivedDeleteEventIDs: [UUID] = []
    var ownerUpsertSnapshots: [SharedEventSnapshot] = []
    var ownerMutationIDs: [UUID] = []
    var ownerDeleteEventIDs: [UUID] = []
    var receivedUpdateCallCount = 0
    var receivedDeleteCallCount = 0
    private var changeSequence = 0

    func iCloudAccountStatus() async -> CalendarSharingICloudStatus { .available }
    func currentUserDisplayName() async -> String? { nil }

    func fetchShareMetadata(
        from url: URL
    ) async throws -> any CalendarSharingShareMetadata {
        throw CalendarSharingError.metadataFetchFailed
    }

    func fetchOwnedCalendars() async throws -> [OwnedSharedCalendarCloudState] { [] }

    func createShare(
        calendarID: UUID,
        calendarName: String,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws -> OwnedSharingInvitationResult {
        throw CalendarSharingError.shareCreationFailed
    }

    func createInvitation(
        for calendar: OwnedSharedCalendarDescriptor
    ) async throws -> OwnedSharingInvitationResult {
        throw CalendarSharingError.invitationCreationFailed
    }

    func revokePendingInvitation(
        for calendar: OwnedSharedCalendarDescriptor,
        participantID: CKShare.Participant.ID
    ) async throws -> OwnedSharedCalendarCloudState {
        throw CalendarSharingError.shareUnavailable
    }

    func synchronizeOwnedContent(
        calendar: OwnedSharedCalendarDescriptor,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws {}

    func renameOwnedCalendar(
        _ calendar: OwnedSharedCalendarDescriptor,
        name: String
    ) async throws {}

    func fetchReceivedCalendars() async throws -> [ReceivedSharedCalendarPayload] {
        receivedDescriptors.map { descriptor in
            let envelopes = receivedRecords.values.filter { $0.calendarID == descriptor.id }
            return ReceivedSharedCalendarPayload(
                calendar: descriptor, events: envelopes.map(\.snapshot), shifts: [], workRecords: [],
                eventEnvelopes: Array(envelopes)
            )
        }
    }

    func createReceivedSharedEvent(
        _ snapshot: SharedEventSnapshot,
        mutationID: UUID,
        in calendar: SharedCalendarDescriptor
    ) async throws -> SharedEventEnvelope {
        receivedCreateEventIDs.append(snapshot.id)
        receivedAttemptMutationIDs.append(mutationID)
        if confirmedNotSentEventIDs.contains(snapshot.id) {
            throw SharedEventWriteError.confirmedNotSent(.networkUnavailable)
        }
        try await prepareReceivedWrite()
        if receivedRecords[snapshot.id]?.isDeleted == true {
            throw CalendarSharingError.sharedEventDeleted
        }
        receivedWriteSnapshots.append(snapshot)
        receivedWriteMutationIDs.append(mutationID)
        let envelope = makeEnvelope(
            snapshot: snapshot,
            calendar: calendar,
            tag: nextTag(),
            lastMutationID: mutationID
        )
        receivedRecords[snapshot.id] = envelope
        return envelope
    }

    func updateReceivedSharedEvent(
        _ snapshot: SharedEventSnapshot,
        mutationID: UUID,
        in calendar: SharedCalendarDescriptor
    ) async throws -> SharedEventEnvelope {
        receivedUpdateCallCount += 1
        receivedAttemptMutationIDs.append(mutationID)
        try await prepareReceivedWrite()
        guard receivedRecords[snapshot.id]?.isDeleted == false else {
            throw CalendarSharingError.sharedEventDeleted
        }
        receivedWriteSnapshots.append(snapshot)
        receivedWriteMutationIDs.append(mutationID)
        let envelope = makeEnvelope(
            snapshot: snapshot,
            calendar: calendar,
            tag: nextTag(),
            lastMutationID: mutationID
        )
        receivedRecords[snapshot.id] = envelope
        return envelope
    }

    func deleteReceivedSharedEvent(
        eventID: UUID,
        mutationID: UUID,
        in calendar: SharedCalendarDescriptor
    ) async throws -> SharedEventEnvelope? {
        receivedDeleteCallCount += 1
        receivedDeleteEventIDs.append(eventID)
        receivedAttemptMutationIDs.append(mutationID)
        try await prepareReceivedWrite()
        guard let existing = receivedRecords[eventID] else { return nil }
        if existing.isDeleted { return existing }
        let deleted = tombstone(existing.snapshot)
        receivedWriteMutationIDs.append(mutationID)
        let envelope = makeEnvelope(
            snapshot: deleted,
            calendar: calendar,
            tag: nextTag(),
            lastMutationID: mutationID
        )
        receivedRecords[eventID] = envelope
        return envelope
    }

    func fetchReceivedSharedEvent(
        eventID: UUID,
        in calendar: SharedCalendarDescriptor
    ) async throws -> SharedEventEnvelope? {
        receivedRecords[eventID]
    }

    func fetchOwnedSharedEvents(
        in calendar: OwnedSharedCalendarDescriptor
    ) async throws -> [SharedEventEnvelope] {
        Array(ownerRecords.values)
    }

    func upsertOwnedSharedEvent(
        _ snapshot: SharedEventSnapshot,
        mutationID: UUID,
        in calendar: OwnedSharedCalendarDescriptor
    ) async throws -> SharedEventEnvelope {
        if ownerRecords[snapshot.id]?.isDeleted == true {
            throw CalendarSharingError.sharedEventDeleted
        }
        ownerUpsertSnapshots.append(snapshot)
        ownerMutationIDs.append(mutationID)
        let envelope = makeEnvelope(
            snapshot: snapshot,
            calendar: calendar,
            tag: nextTag(),
            lastMutationID: mutationID
        )
        ownerRecords[snapshot.id] = envelope
        return envelope
    }

    func deleteOwnedSharedEvent(
        eventID: UUID,
        mutationID: UUID,
        in calendar: OwnedSharedCalendarDescriptor
    ) async throws -> SharedEventEnvelope? {
        ownerDeleteEventIDs.append(eventID)
        ownerMutationIDs.append(mutationID)
        guard let existing = ownerRecords[eventID] else { return nil }
        if existing.isDeleted { return existing }
        let envelope = makeEnvelope(
            snapshot: tombstone(existing.snapshot),
            calendar: calendar,
            tag: nextTag(),
            lastMutationID: mutationID
        )
        ownerRecords[eventID] = envelope
        return envelope
    }

    func accept(
        metadata: any CalendarSharingShareMetadata
    ) async throws -> AcceptedSharedCalendarCloudResult {
        throw CalendarSharingError.invitationAcceptanceFailed
    }

    func leaveSharedCalendar(_ calendar: SharedCalendarDescriptor) async throws {}
    func stopOwnedSharing(_ calendar: OwnedSharedCalendarDescriptor) async throws {}

    private func prepareReceivedWrite() async throws {
        if let gate = nextReceivedWriteGate {
            nextReceivedWriteGate = nil
            try await gate.waitForRelease()
        }
        if !confirmedNotSentWriteErrors.isEmpty {
            throw SharedEventWriteError.confirmedNotSent(
                confirmedNotSentWriteErrors.removeFirst()
            )
        }
        if !receivedWriteErrors.isEmpty {
            throw receivedWriteErrors.removeFirst()
        }
    }

    private func nextTag() -> String {
        changeSequence += 1
        return "tag-\(changeSequence)"
    }

    private func tombstone(_ snapshot: SharedEventSnapshot) -> SharedEventSnapshot {
        SharedEventSnapshot(
            id: snapshot.id,
            title: snapshot.title,
            startDate: snapshot.startDate,
            endDate: snapshot.endDate,
            isAllDay: snapshot.isAllDay,
            updatedAt: snapshot.updatedAt.addingTimeInterval(1),
            isDeleted: true,
            deletedAt: snapshot.updatedAt.addingTimeInterval(1)
        )
    }
}

private enum SharedEventEditingInjectedFailure: Error {
    case persistence
}

@MainActor
private final class SharedEventPersistenceFaultInjector {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(
        "SharedEventPersistenceFault-\(UUID().uuidString).json"
    )
    var failAllSaves = false
    var failNextCompletionSave = false
    private(set) var saveAttemptCount = 0

    lazy var persistence = SharedEventEditingPersistence(
        fileURL: fileURL,
        loadData: { [weak self] url in
            guard self != nil, FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            return try Data(contentsOf: url)
        },
        saveData: { [weak self] data, url in
            guard let self else { throw SharedEventEditingInjectedFailure.persistence }
            saveAttemptCount += 1
            let candidate = try JSONDecoder().decode(
                SharedEventEditingPersistenceData.self,
                from: data
            )
            if failAllSaves
                || (failNextCompletionSave
                    && candidate.outbox.contains { $0.status == .completed }) {
                failNextCompletionSave = false
                throw SharedEventEditingInjectedFailure.persistence
            }
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        }
    )
}

private actor FaultInjectingOwnerMutationRepository:
    EventRepository,
    OwnerSharedEventMutationRepository
{
    private let base = InMemoryEventRepository()
    private var shouldFailNextAtomicWrite = false
    private var shouldFailNextCompletedMutationSave = false
    private var createCalls = 0

    func failNextAtomicWrite() {
        shouldFailNextAtomicWrite = true
    }

    func failNextCompletedMutationSave() {
        shouldFailNextCompletedMutationSave = true
    }

    func ordinaryCreateCallCount() -> Int { createCalls }

    func create(_ event: CalendarEvent) async throws {
        createCalls += 1
        try await base.create(event)
    }

    func applyBatch(
        upserting events: [CalendarEvent],
        deleting eventsToDelete: [CalendarEvent],
        ifUnchanged expectedEvents: [CalendarEvent]
    ) async throws {
        try await base.applyBatch(
            upserting: events,
            deleting: eventsToDelete,
            ifUnchanged: expectedEvents
        )
    }

    func applyBatchWithOwnerSharedEventMutations(
        upserting events: [CalendarEvent],
        deleting eventsToDelete: [CalendarEvent],
        ifUnchanged expectedEvents: [CalendarEvent],
        mutations: [OwnerSharedEventMutation]
    ) async throws {
        if shouldFailNextAtomicWrite {
            shouldFailNextAtomicWrite = false
            throw SharedEventEditingInjectedFailure.persistence
        }
        try await base.applyBatchWithOwnerSharedEventMutations(
            upserting: events,
            deleting: eventsToDelete,
            ifUnchanged: expectedEvents,
            mutations: mutations
        )
    }

    func ownerSharedEventMutations(
        calendarID: UUID
    ) async throws -> [OwnerSharedEventMutation] {
        try await base.ownerSharedEventMutations(calendarID: calendarID)
    }

    func saveOwnerSharedEventMutation(_ mutation: OwnerSharedEventMutation) async throws {
        if shouldFailNextCompletedMutationSave, mutation.status == .completed {
            shouldFailNextCompletedMutationSave = false
            throw CalendarSharingError.localPersistenceFailed
        }
        try await base.saveOwnerSharedEventMutation(mutation)
    }

    func update(_ event: CalendarEvent) async throws {
        try await base.update(event)
    }

    func delete(id: UUID) async throws {
        try await base.delete(id: id)
    }

    func deleteBatch(_ expectedEvents: [CalendarEvent]) async throws {
        try await base.deleteBatch(expectedEvents)
    }

    func events(in range: DateInterval) async throws -> [CalendarEvent] {
        try await base.events(in: range)
    }

    func event(id: UUID) async throws -> CalendarEvent? {
        try await base.event(id: id)
    }

    func events(unifiedEntryID: UUID) async throws -> [CalendarEvent] {
        try await base.events(unifiedEntryID: unifiedEntryID)
    }

    func workRecordEvents(workSessionID: UUID) async throws -> [CalendarEvent] {
        try await base.workRecordEvents(workSessionID: workSessionID)
    }

    func reassignEvents(from sourceCalendarID: UUID, to targetCalendarID: UUID) async throws {
        try await base.reassignEvents(from: sourceCalendarID, to: targetCalendarID)
    }
}

@MainActor
private final class SharedEventEditingTestGate {
    private(set) var hasEntered = false
    private var isReleased = false

    func waitForRelease() async throws {
        hasEntered = true
        while !isReleased {
            try Task.checkCancellation()
            await Task.yield()
        }
    }

    func waitUntilEntered() async {
        while !hasEntered { await Task.yield() }
    }

    func release() {
        isReleased = true
    }
}

private func makeReceivedDescriptor(
    id: UUID = UUID(),
    eventEditingAllowed: Bool = true,
    permission: SharedCalendarParticipantPermission = .readWrite
) -> SharedCalendarDescriptor {
    SharedCalendarDescriptor(
        id: id,
        zoneName: "zone-\(id.uuidString.lowercased())",
        ownerName: "owner",
        calendarName: "Family",
        participantCount: 2,
        kind: .sharedReceived,
        rootRecordName: CalendarSharingCloudSchema.calendarRecordName,
        shareRecordName: CKRecordNameZoneWideShare,
        eventEditingAllowed: eventEditingAllowed,
        collaborationProtocolVersion: 1,
        participantPermission: permission
    )
}

private func makeReceivedCalendar(
    id: UUID = UUID(),
    permission: SharedCalendarParticipantPermission
) -> TimeNestCalendar {
    TimeNestCalendar(
        id: id,
        name: "Family",
        kind: .sharedReceived,
        zoneName: "zone-\(id.uuidString.lowercased())",
        ownerName: "owner",
        rootRecordName: CalendarSharingCloudSchema.calendarRecordName,
        shareRecordName: CKRecordNameZoneWideShare,
        eventEditingAllowed: true,
        collaborationProtocolVersion: 1,
        participantPermission: permission,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

private func makeOwnerDescriptor(id: UUID = UUID()) -> OwnedSharedCalendarDescriptor {
    OwnedSharedCalendarDescriptor(
        id: id,
        zoneName: "zone-\(id.uuidString.lowercased())",
        ownerName: CKCurrentUserDefaultName,
        calendarName: "Family",
        participantCount: 1,
        rootRecordName: CalendarSharingCloudSchema.calendarRecordName,
        shareRecordName: CKRecordNameZoneWideShare,
        eventEditingAllowed: true,
        collaborationProtocolVersion: 1
    )
}

private func makeOwnerCalendar(id: UUID = UUID()) -> TimeNestCalendar {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    return TimeNestCalendar(
        id: id,
        name: "Family",
        kind: .sharedOwned,
        zoneName: "zone-\(id.uuidString.lowercased())",
        ownerName: CKCurrentUserDefaultName,
        rootRecordName: CalendarSharingCloudSchema.calendarRecordName,
        shareRecordName: CKRecordNameZoneWideShare,
        eventEditingAllowed: true,
        collaborationProtocolVersion: 1,
        participantPermission: .none,
        createdAt: now,
        updatedAt: now
    )
}

private func makeSnapshot(
    id: UUID = UUID(),
    title: String,
    startOffset: TimeInterval = 0,
    duration: TimeInterval = 3_600,
    isAllDay: Bool = false,
    isDeleted: Bool = false
) -> SharedEventSnapshot {
    let start = Date(timeIntervalSince1970: 1_700_000_000 + startOffset)
    return SharedEventSnapshot(
        id: id,
        title: title,
        startDate: start,
        endDate: start.addingTimeInterval(duration),
        isAllDay: isAllDay,
        updatedAt: start.addingTimeInterval(60),
        isDeleted: isDeleted,
        deletedAt: isDeleted ? start.addingTimeInterval(60) : nil
    )
}

private func makeEnvelope(
    snapshot: SharedEventSnapshot,
    calendar: SharedCalendarDescriptor,
    tag: String,
    lastMutationID: UUID? = nil
) -> SharedEventEnvelope {
    SharedEventEnvelope(
        calendarID: calendar.id,
        zoneName: calendar.zoneName,
        ownerName: calendar.ownerName,
        recordName: "collaborative-event-\(snapshot.id.uuidString.lowercased())",
        snapshot: snapshot,
        recordChangeTag: tag,
        modificationDate: snapshot.updatedAt,
        creatorIdentifierHash: "creator-hash",
        lastModifierIdentifierHash: "modifier-hash",
        syncStatus: snapshot.isDeleted ? .deletedRemotely : .synced,
        pendingMutationID: nil,
        lastMutationID: lastMutationID
    )
}

private func makeEnvelope(
    snapshot: SharedEventSnapshot,
    calendar: OwnedSharedCalendarDescriptor,
    tag: String,
    lastMutationID: UUID? = nil
) -> SharedEventEnvelope {
    SharedEventEnvelope(
        calendarID: calendar.id,
        zoneName: calendar.zoneName,
        ownerName: calendar.ownerName,
        recordName: "collaborative-event-\(snapshot.id.uuidString.lowercased())",
        snapshot: snapshot,
        recordChangeTag: tag,
        modificationDate: snapshot.updatedAt,
        creatorIdentifierHash: "creator-hash",
        lastModifierIdentifierHash: "modifier-hash",
        syncStatus: snapshot.isDeleted ? .deletedRemotely : .synced,
        pendingMutationID: nil,
        lastMutationID: lastMutationID
    )
}

private func makeEvent(
    id: UUID = UUID(),
    calendarID: UUID,
    title: String,
    note: String? = nil,
    reminderOffsetMinutes: Int? = nil,
    notificationID: String? = nil
) -> CalendarEvent {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    return CalendarEvent(
        id: id,
        calendarID: calendarID,
        title: title,
        note: note,
        startDate: start,
        endDate: start.addingTimeInterval(3_600),
        isAllDay: false,
        categoryID: UUID(),
        recurrenceRule: .weekly,
        reminderTemplateID: UUID(),
        reminderOffsetMinutes: reminderOffsetMinutes,
        notificationID: notificationID,
        importSource: nil,
        createdAt: start,
        updatedAt: start
    )
}
