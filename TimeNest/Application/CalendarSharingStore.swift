import CloudKit
import Combine
import Foundation

enum CalendarSharingSyncStatus: Equatable {
    case idle
    case syncing
    case synced
    case failed
}

enum CalendarSharingManualInvitationState: Equatable {
    case idle
    case validating
    case accepting
    case accepted
    case alreadyAccepted
    case failed(CalendarSharingError)
}

enum CalendarSharingCreationMode: String, CaseIterable, Identifiable {
    case empty
    case copyPersonalCalendar

    var id: Self { self }
}

enum CalendarSharingOwnerDisplayNameResolver {
    static func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    static func resolve(incoming: String?, existing: String?) -> String? {
        normalized(incoming) ?? normalized(existing)
    }
}

@MainActor
final class CalendarSharingStore: ObservableObject {
    @Published private(set) var selection: CalendarSelection
    @Published private(set) var calendars: [TimeNestCalendar] = []
    @Published private(set) var ownedCalendars: [OwnedSharedCalendarDescriptor] = []
    @Published private(set) var receivedCalendars: [SharedCalendarDescriptor]
    @Published private(set) var participantsByCalendarID: [UUID: [SharedCalendarParticipantSnapshot]] = [:]
    @Published private(set) var iCloudStatus: CalendarSharingICloudStatus = .unknown
    @Published private(set) var syncStatus: CalendarSharingSyncStatus = .idle
    @Published private(set) var lastSuccessfulSyncAt: Date?
    @Published private(set) var lastError: CalendarSharingError?
    @Published private(set) var isAcceptingInvitation = false
    @Published private(set) var invitationAcceptanceError: CalendarSharingError?
    @Published private(set) var manualInvitationState: CalendarSharingManualInvitationState = .idle
    @Published private(set) var revision = 0

    private let client: any CalendarSharingClientProtocol
    private let eventUseCase: EventUseCase
    private let sharedEventEditingUseCase: SharedEventEditingUseCase
    private let calendarRepository: any CalendarRepository
    private let cache: CalendarSharingCache
    private let selectionPersistence: CalendarSelectionPersistence
    private let syncMetadataPersistence: CalendarSharingSyncMetadataPersistence
    private let invitationRouter: CalendarSharingInvitationRouter
    private var eventsByCalendarID: [UUID: [SharedEventSnapshot]]
    private var shiftsByCalendarID: [UUID: [SharedShiftSnapshot]]
    private var workRecordsByCalendarID: [UUID: [SharedWorkRecordSnapshot]]
    private var refreshIsInProgress = false
    private var refreshWasRequested = false
    private var refreshCompletionWaiters: [CheckedContinuation<Void, Never>] = []
    private var acceptedMetadataAwaitingRefresh: [String: AcceptedSharedCalendarCloudResult] = [:]
    private let initialMigrationError: CalendarSharingError?
    private var syncGenerations: [UUID: Int] = [:]
    private var completedSyncGenerations: [UUID: Int] = [:]
    private var failedSyncGenerations: [UUID: Int] = [:]
    private var syncWorkers: [UUID: Task<Void, Never>] = [:]
    private var syncDescriptors: [UUID: OwnedSharedCalendarDescriptor] = [:]
    private var pendingExtraEvents: [UUID: [UUID: CalendarEvent]] = [:]
    private var lastICloudStatusCheckAt: Date?
    private var iCloudStatusRefreshTask: Task<CalendarSharingICloudStatus, Never>?

    private static let iCloudStatusCacheDuration: TimeInterval = 60

    init(
        client: any CalendarSharingClientProtocol,
        eventUseCase: EventUseCase,
        calendarRepository: any CalendarRepository,
        cache: CalendarSharingCache = CalendarSharingCache(),
        sharedEventEditingPersistence: SharedEventEditingPersistence = SharedEventEditingPersistence(),
        selectionPersistence: CalendarSelectionPersistence = CalendarSelectionPersistence(),
        syncMetadataPersistence: CalendarSharingSyncMetadataPersistence = CalendarSharingSyncMetadataPersistence(),
        initialCalendars: [TimeNestCalendar] = [],
        initialMigrationError: CalendarSharingError? = nil,
        invitationRouter: CalendarSharingInvitationRouter? = nil
    ) {
        self.client = client
        self.eventUseCase = eventUseCase
        sharedEventEditingUseCase = SharedEventEditingUseCase(
            client: client,
            eventUseCase: eventUseCase,
            persistence: sharedEventEditingPersistence
        )
        self.calendarRepository = calendarRepository
        self.cache = cache
        self.selectionPersistence = selectionPersistence
        self.syncMetadataPersistence = syncMetadataPersistence
        self.initialMigrationError = initialMigrationError
        self.invitationRouter = invitationRouter ?? .shared
        calendars = initialCalendars
        let cached = cache.load()
        receivedCalendars = cached.receivedCalendars
        eventsByCalendarID = cached.eventsByCalendarID
        shiftsByCalendarID = cached.shiftsByCalendarID
        workRecordsByCalendarID = cached.workRecordsByCalendarID
        selection = selectionPersistence.load()
        lastSuccessfulSyncAt = syncMetadataPersistence.loadLastSuccessfulSyncAt()
        for descriptor in cached.receivedCalendars {
            // Keep a missing cache key distinct from an authoritative empty event snapshot.
            guard let cachedEvents = cached.eventsByCalendarID[descriptor.id] else {
                continue
            }
            let cachedPayload = ReceivedSharedCalendarPayload(
                calendar: descriptor,
                events: cachedEvents,
                shifts: cached.shiftsByCalendarID[descriptor.id] ?? [],
                workRecords: cached.workRecordsByCalendarID[descriptor.id] ?? []
            )
            do {
                try sharedEventEditingUseCase.reconcileReceived(
                    calendar: descriptor,
                    envelopes: cachedPayload.eventEnvelopes,
                    isAuthoritative: false
                )
                eventsByCalendarID[descriptor.id] = sharedEventEditingUseCase.visibleSnapshots(
                    calendarID: descriptor.id
                )
            } catch {
                lastError = .localPersistenceFailed
            }
        }
        if sharedEventEditingUseCase.startupPersistenceError != nil {
            lastError = .localPersistenceFailed
        }
    }

    deinit {
        iCloudStatusRefreshTask?.cancel()
        for worker in syncWorkers.values {
            worker.cancel()
        }
    }

    var selectedCalendar: TimeNestCalendar {
        calendars.first(where: { $0.id == selection.calendarID })
            ?? TimeNestCalendar.personal(
                name: LocalizationManager.shared.localized(.calendarSharingMyCalendar)
            )
    }

    var accessPolicy: CalendarAccessPolicy {
        CalendarAccessPolicy(selectedCalendar: selectedCalendar)
    }

    var selectedCalendarDisplayName: String {
        selectedCalendar.name
    }

    var personalCalendar: TimeNestCalendar {
        calendars.first(where: { $0.kind == .personal })
            ?? TimeNestCalendar.personal(
                name: LocalizationManager.shared.localized(.calendarSharingMyCalendar)
            )
    }

    var writableCalendars: [TimeNestCalendar] {
        calendars.filter(\.canEditContent)
    }

    /// Event-only destinations include received calendars whose owner and CKShare
    /// permissions allow the existing collaborative-event creation path.
    var eventWritableCalendars: [TimeNestCalendar] {
        calendars.filter(\.canCreateSharedEvent)
    }

    var writablePersonalCalendars: [TimeNestCalendar] {
        calendars.filter { $0.kind == .personal && $0.canEditContent }
    }

    func isStopping(calendarID: UUID) -> Bool {
        calendar(id: calendarID)?.stopPhase.isStopping == true
    }

    func calendar(id: UUID) -> TimeNestCalendar? {
        calendars.first { $0.id == id }
    }

    func ownedDescriptor(id: UUID) -> OwnedSharedCalendarDescriptor? {
        ownedCalendars.first { $0.id == id }
    }

    func receivedDescriptor(id: UUID) -> SharedCalendarDescriptor? {
        receivedCalendars.first { $0.id == id }
    }

    func currentUserDisplayName() async -> String? {
        await client.currentUserDisplayName()
    }

    func participants(for calendarID: UUID) -> [SharedCalendarParticipantSnapshot] {
        participantsByCalendarID[calendarID] ?? []
    }

    func sharedEventSnapshot(calendarID: UUID, eventID: UUID) -> SharedEventSnapshot? {
        sharedEventEditingUseCase.envelope(
            calendarID: calendarID,
            eventID: eventID
        )?.snapshot ?? eventsByCalendarID[calendarID]?.first { $0.id == eventID }
    }

    func sharedEventSyncStatus(
        calendarID: UUID,
        eventID: UUID
    ) -> SharedEventSyncStatus? {
        sharedEventEditingUseCase.status(calendarID: calendarID, eventID: eventID)
    }

    func ensureCanWriteSharedEvent(calendarID: UUID) throws {
        guard calendar(id: calendarID)?.canCreateSharedEvent == true else {
            throw CalendarSharingError.sharedEventPermissionRevoked
        }
    }

    @discardableResult
    func createReceivedSharedEvent(
        _ snapshot: SharedEventSnapshot,
        calendarID: UUID
    ) async throws -> SharedEventSyncStatus {
        try ensureCanWriteSharedEvent(calendarID: calendarID)
        guard let descriptor = receivedDescriptor(id: calendarID) else {
            throw CalendarSharingError.shareUnavailable
        }
        let status = try await sharedEventEditingUseCase.create(snapshot, in: descriptor)
        refreshReceivedSharedEventCache(calendarID: calendarID)
        return status
    }

    @discardableResult
    func updateReceivedSharedEvent(
        _ snapshot: SharedEventSnapshot,
        calendarID: UUID
    ) async throws -> SharedEventSyncStatus {
        try ensureCanWriteSharedEvent(calendarID: calendarID)
        guard let descriptor = receivedDescriptor(id: calendarID) else {
            throw CalendarSharingError.shareUnavailable
        }
        let status = try await sharedEventEditingUseCase.update(snapshot, in: descriptor)
        refreshReceivedSharedEventCache(calendarID: calendarID)
        return status
    }

    @discardableResult
    func deleteReceivedSharedEvent(
        eventID: UUID,
        calendarID: UUID
    ) async throws -> SharedEventSyncStatus {
        try ensureCanWriteSharedEvent(calendarID: calendarID)
        guard let descriptor = receivedDescriptor(id: calendarID) else {
            throw CalendarSharingError.shareUnavailable
        }
        let status = try await sharedEventEditingUseCase.delete(
            eventID: eventID,
            in: descriptor
        )
        refreshReceivedSharedEventCache(calendarID: calendarID)
        return status
    }

    func setEventEditingAllowed(calendarID: UUID, allowed: Bool) async throws {
        guard calendar(id: calendarID)?.canManageShare == true,
              let descriptor = ownedDescriptor(id: calendarID) else {
            throw CalendarSharingError.permissionDenied
        }
        if allowed, descriptor.collaborationProtocolVersion < 1 {
            let snapshots = try await Self.localSnapshots(
                eventUseCase: eventUseCase,
                calendarID: calendarID,
                adding: []
            )
            try await client.synchronizeOwnedContent(
                calendar: descriptor,
                events: snapshots.events,
                shifts: snapshots.shifts,
                workRecords: snapshots.workRecords
            )
        }
        let state = try await client.updateEventEditingPermission(
            for: descriptor,
            allowed: allowed
        )
        try await persistOwnedState(state)
        ownedCalendars = ownedCalendars.map {
            $0.id == calendarID ? state.calendar : $0
        }
        participantsByCalendarID[calendarID] = state.participants
        await loadLocalCalendars()
        revision &+= 1
    }

    func displayStatus(for calendar: TimeNestCalendar) -> CalendarSharingDisplayStatus {
        guard calendar.kind != .personal else { return .notShared }
        guard !calendar.stopPhase.isStopping else { return .unavailable }
        switch syncStatus {
        case .syncing:
            return .syncing
        case .failed:
            return .failed
        case .idle, .synced:
            break
        }
        switch calendar.kind {
        case .personal:
            return .notShared
        case .sharedOwned:
            return participants(for: calendar.id).contains(where: \.isAccepted)
                ? .shared
                : .waitingForAcceptance
        case .sharedReceived:
            return .shared
        }
    }

    @discardableResult
    func refreshICloudStatus(force: Bool = false) async -> CalendarSharingICloudStatus {
        if let task = iCloudStatusRefreshTask {
            return await task.value
        }
        if !force,
           let checkedAt = lastICloudStatusCheckAt,
           Date().timeIntervalSince(checkedAt) < Self.iCloudStatusCacheDuration,
           iCloudStatus != .checking,
           iCloudStatus != .unknown {
            return iCloudStatus
        }

        iCloudStatus = .checking
        let task = Task { @MainActor [client] in
            await client.iCloudAccountStatus()
        }
        iCloudStatusRefreshTask = task
        let status = await task.value
        iCloudStatusRefreshTask = nil
        iCloudStatus = status
        lastICloudStatusCheckAt = Date()
        return status
    }

    func select(_ newSelection: CalendarSelection) {
        let resolved = CalendarSelectionPersistence.resolved(
            newSelection,
            validCalendarIDs: Set(calendars.map(\.id))
        )
        guard resolved != selection else { return }
        selection = resolved
        selectionPersistence.save(resolved)
        revision &+= 1
    }

    func occurrences(for calendarID: UUID, in range: DateInterval) -> [EventOccurrence] {
        var occurrences = SharedEventMapper.occurrences(
            from: eventsByCalendarID[calendarID] ?? [],
            in: range
        )
        occurrences.append(contentsOf: SharedShiftMapper.occurrences(
            from: shiftsByCalendarID[calendarID] ?? [],
            in: range
        ))
        occurrences.append(contentsOf: SharedWorkRecordMapper.occurrences(
            from: workRecordsByCalendarID[calendarID] ?? [],
            in: range
        ))
        return occurrences.sorted {
            if $0.occurrenceDate != $1.occurrenceDate {
                return $0.occurrenceDate.id < $1.occurrenceDate.id
            }
            return $0.startDate < $1.startDate
        }
    }

    @discardableResult
    func overwritePersonalCalendar(
        from sharedCalendarID: UUID,
        to targetCalendarID: UUID,
        scope: SharedCalendarCopyScope
    ) async throws -> [CalendarEvent] {
        guard let sourceCalendar = calendar(id: sharedCalendarID),
              let targetCalendar = calendar(id: targetCalendarID),
              sourceCalendar.kind != .personal,
              sourceCalendar.id != targetCalendar.id,
              !sourceCalendar.stopPhase.isStopping,
              targetCalendar.kind == .personal,
              targetCalendar.canEditContent else {
            throw CalendarSharingError.permissionDenied
        }

        let snapshots: LocalSnapshots
        switch sourceCalendar.kind {
        case .personal:
            throw CalendarSharingError.permissionDenied
        case .sharedOwned:
            snapshots = try await Self.localSnapshots(
                eventUseCase: eventUseCase,
                calendarID: sharedCalendarID
            )
        case .sharedReceived:
            guard receivedDescriptor(id: sharedCalendarID) != nil else {
                throw CalendarSharingError.shareUnavailable
            }
            // Empty arrays are authoritative; a missing key means that snapshot type is not ready.
            guard let events = eventsByCalendarID[sharedCalendarID],
                  let shifts = shiftsByCalendarID[sharedCalendarID],
                  let workRecords = workRecordsByCalendarID[sharedCalendarID] else {
                throw CalendarSharingError.syncFailed
            }
            snapshots = LocalSnapshots(
                events: events,
                shifts: shifts,
                workRecords: workRecords
            )
        }

        let copies = try await eventUseCase.overwritePersonalCalendar(
            targetCalendarID: targetCalendarID,
            sharedEvents: snapshots.events,
            sharedShifts: snapshots.shifts,
            sharedWorkRecords: snapshots.workRecords,
            scope: scope
        )
        revision &+= 1
        return copies
    }

    func start() async {
        await loadLocalCalendars()
        invitationRouter.register(store: self)
        await synchronizeAll()
    }

    func synchronizeOnAppActivation() async {
        await synchronizeAll()
        invitationRouter.retryPending()
    }

    func synchronizeAll(forceICloudStatusRefresh: Bool = false) async {
        let accountStatus = await refreshICloudStatus(force: forceICloudStatusRefresh)
        guard accountStatus == .available else {
            lastError = accountStatus.operationError
            syncStatus = .failed
            return
        }
        if refreshIsInProgress {
            refreshWasRequested = true
            await waitForRefreshToFinish()
            return
        }
        refreshIsInProgress = true
        defer { finishRefresh() }

        repeat {
            refreshWasRequested = false
            await performFullSynchronization()
        } while refreshWasRequested
        invitationRouter.retryPending()
    }

    /// Manual retry for an owned invitation. This refreshes the latest CKShare state and
    /// deliberately never enters the participant-revocation path.
    func refreshOwnedInvitationStatus(calendarID: UUID) async throws {
        await synchronizeAll(forceICloudStatusRefresh: true)
        guard syncStatus == .synced else {
            throw lastError ?? CalendarSharingError.syncFailed
        }
        guard ownedDescriptor(id: calendarID) != nil else {
            throw CalendarSharingError.shareUnavailable
        }
    }

    private func performFullSynchronization() async {
        let stopRecoveryError = await resumePendingStops()
        syncStatus = .syncing
        lastError = initialMigrationError ?? stopRecoveryError

        do {
            let initialOwnedStates = try await client.fetchOwnedCalendars()
            try await persistCloudCalendars(
                ownedStates: initialOwnedStates,
                receivedPayloads: []
            )
            await loadLocalCalendars()
            ownedCalendars = mergedOwnedDescriptors(
                cloudDescriptors: initialOwnedStates.map(\.calendar)
            )

            let activeInitialStates = initialOwnedStates.filter {
                !isStopping(calendarID: $0.calendar.id)
            }
            let requests = activeInitialStates.map {
                enqueueOwnedSync($0.calendar)
            }
            for request in requests {
                await waitForOwnedSync(request)
                guard completedSyncGenerations[request.calendarID, default: 0]
                    >= request.generation else {
                    throw lastError ?? CalendarSharingError.syncFailed
                }
            }

            let refreshedOwnedStates = try await client.fetchOwnedCalendars()
            var receivedPayloads = try reconcileReceivedSharedEvents(
                mergingReceivedOwnerDisplayNames(
                    into: try await client.fetchReceivedCalendars()
                )
            )
            if !sharedEventEditingUseCase.pendingMutations().isEmpty {
                try await sharedEventEditingUseCase.retryPending(
                    in: receivedPayloads.map(\.calendar)
                )
                receivedPayloads = try reconcileReceivedSharedEvents(
                    mergingReceivedOwnerDisplayNames(
                        into: try await client.fetchReceivedCalendars()
                    )
                )
            }
            try await reconcileRemovedCloudCalendars(
                ownedIDs: Set(refreshedOwnedStates.map(\.calendar.id)),
                receivedIDs: Set(receivedPayloads.map(\.calendar.id))
            )
            try await persistCloudCalendars(
                ownedStates: refreshedOwnedStates,
                receivedPayloads: receivedPayloads
            )

            ownedCalendars = mergedOwnedDescriptors(
                cloudDescriptors: refreshedOwnedStates.map(\.calendar)
            )
            participantsByCalendarID = Dictionary(
                uniqueKeysWithValues: refreshedOwnedStates.map {
                    ($0.calendar.id, $0.participants)
                }
            )
            receivedCalendars = receivedPayloads.map(\.calendar)
            eventsByCalendarID = Dictionary(
                uniqueKeysWithValues: receivedPayloads.map { ($0.calendar.id, $0.events) }
            )
            shiftsByCalendarID = Dictionary(
                uniqueKeysWithValues: receivedPayloads.map { ($0.calendar.id, $0.shifts) }
            )
            workRecordsByCalendarID = Dictionary(
                uniqueKeysWithValues: receivedPayloads.map { ($0.calendar.id, $0.workRecords) }
            )
            await loadLocalCalendars()
            validateSelection()
            persistCache()
            syncStatus = .synced
            lastError = initialMigrationError ?? stopRecoveryError
            if !ownedCalendars.isEmpty || !receivedCalendars.isEmpty {
                recordSuccessfulSync()
            }
            revision &+= 1
        } catch is CancellationError {
            syncStatus = .idle
        } catch let error as CalendarSharingError {
            lastError = error
            syncStatus = .failed
        } catch {
            lastError = CalendarSharingErrorMapper.map(error)
            syncStatus = .failed
        }
    }

    func synchronizeOwnedEventsIfNeeded() async {
        let active = ownedCalendars.filter { !isStopping(calendarID: $0.id) }
        let requests = active.map(enqueueOwnedSync)
        for request in requests {
            await waitForOwnedSync(request)
        }
    }

    func createSharedCalendar(
        name: String,
        eventEditingAllowed: Bool = false,
        creationMode: CalendarSharingCreationMode = .empty
    ) async throws -> CalendarSharingInvitation {
        try await requireAvailableICloud()
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw CalendarSharingError.shareCreationFailed }
        let now = Date()
        let id = UUID()
        let pending = TimeNestCalendar(
            id: id,
            name: name,
            kind: .sharedOwned,
            zoneName: CalendarSharingCloudSchema.zoneName(for: id),
            ownerName: CKCurrentUserDefaultName,
            rootRecordName: CalendarSharingCloudSchema.calendarRecordName,
            shareRecordName: CKRecordNameZoneWideShare,
            createdAt: now,
            updatedAt: now
        )
        try await calendarRepository.save(pending)
        await loadLocalCalendars()

        var cloudCreated = false
        do {
            let result = try await client.createShare(
                calendarID: id,
                calendarName: name,
                events: [],
                shifts: [],
                workRecords: []
            )
            cloudCreated = true
            let finalState: OwnedSharedCalendarCloudState
            if eventEditingAllowed {
                finalState = try await client.updateEventEditingPermission(
                    for: result.state.calendar,
                    allowed: true
                )
            } else {
                finalState = result.state
            }
            try await persistOwnedState(finalState)
            ownedCalendars.append(finalState.calendar)
            participantsByCalendarID[id] = finalState.participants
            if creationMode == .copyPersonalCalendar {
                let copiedEvents = try await eventUseCase.copyShareableEventsOnce(
                    from: TimeNestCalendar.personalID,
                    to: id
                )
                if !copiedEvents.isEmpty {
                    let request = enqueueOwnedSync(finalState.calendar)
                    await waitForOwnedSync(request)
                }
            }
            select(.calendar(id))
            await loadLocalCalendars()
            revision &+= 1
            guard let invitationURL = result.invitationURL else {
                CalendarSharingDiagnostics.debug(
                    operation: "invite",
                    stage: "url-unavailable",
                    database: "private",
                    details: "calendarHash=\(CalendarSharingDiagnostics.identifierHash(id.uuidString)) "
                        + "participantHash=\(CalendarSharingDiagnostics.identifierHash(result.participantID)) "
                        + "shareURLAvailable=false"
                )
                if let cleanedState = try? await client.revokePendingInvitation(
                    for: result.state.calendar,
                    participantID: result.participantID
                ) {
                    participantsByCalendarID[id] = cleanedState.participants
                }
                throw CalendarSharingError.invitationURLUnavailable
            }
            return CalendarSharingInvitation(
                id: OwnedCalendarParticipantSnapshotAssembler.participantSnapshotID(
                    result.participantID
                ),
                calendarID: id,
                url: invitationURL
            )
        } catch {
            if !cloudCreated {
                try? await calendarRepository.delete(id: id)
            }
            await loadLocalCalendars()
            throw error
        }
    }

    func createInvitation(for calendarID: UUID) async throws -> CalendarSharingInvitation {
        try await requireAvailableICloud()
        guard calendar(id: calendarID)?.canManageParticipants == true,
              let calendar = ownedDescriptor(id: calendarID) else {
            throw CalendarSharingError.shareUnavailable
        }
        let result = try await client.createInvitation(for: calendar)
        ownedCalendars = ownedCalendars.map {
            $0.id == calendarID ? result.state.calendar : $0
        }
        participantsByCalendarID[calendarID] = result.state.participants
        guard let invitationURL = result.invitationURL else {
            CalendarSharingDiagnostics.debug(
                operation: "invite",
                stage: "url-unavailable",
                database: "private",
                details: "calendarHash=\(CalendarSharingDiagnostics.identifierHash(calendarID.uuidString)) "
                    + "participantHash=\(CalendarSharingDiagnostics.identifierHash(result.participantID)) "
                    + "shareURLAvailable=false"
            )
            if let cleanedState = try? await client.revokePendingInvitation(
                for: result.state.calendar,
                participantID: result.participantID
            ) {
                participantsByCalendarID[calendarID] = cleanedState.participants
            }
            throw CalendarSharingError.invitationURLUnavailable
        }
        return CalendarSharingInvitation(
            id: OwnedCalendarParticipantSnapshotAssembler.participantSnapshotID(
                result.participantID
            ),
            calendarID: calendarID,
            url: invitationURL
        )
    }

    func handleInvitationActivity(
        _ invitation: CalendarSharingInvitation,
        outcome: SharingInvitationActivityOutcome
    ) async throws {
        switch outcome {
        case .completed:
            CalendarSharingDiagnostics.debug(
                operation: "invite",
                stage: "activity-completed",
                database: "private",
                details: "calendarHash=\(CalendarSharingDiagnostics.identifierHash(invitation.calendarID.uuidString)) "
                    + "participantHash=\(CalendarSharingDiagnostics.identifierHash(invitation.id)) "
                    + "activityCompleted=true"
            )
            await synchronizeAll()
        case .cancelled:
            try await removeUnusedInvitation(invitation, activityFailed: false)
        case .activityError:
            try await removeUnusedInvitation(invitation, activityFailed: true)
            throw CalendarSharingError.invitationActivityFailed
        }
    }

    private func removeUnusedInvitation(
        _ invitation: CalendarSharingInvitation,
        activityFailed: Bool
    ) async throws {
        do {
            try await revokePendingInvitation(
                calendarID: invitation.calendarID,
                participantSnapshotID: invitation.id
            )
            CalendarSharingDiagnostics.debug(
                operation: "invite",
                stage: "pending-participant-revoked",
                database: "private",
                details: "calendarHash=\(CalendarSharingDiagnostics.identifierHash(invitation.calendarID.uuidString)) "
                    + "participantHash=\(CalendarSharingDiagnostics.identifierHash(invitation.id)) "
                    + "activityCompleted=false activityFailed=\(activityFailed)"
            )
            lastError = initialMigrationError
        } catch {
            lastError = .invitationCancellationFailed
            throw CalendarSharingError.invitationCancellationFailed
        }
    }

    func revokePendingInvitation(
        calendarID: UUID,
        participantSnapshotID: String
    ) async throws {
        guard let descriptor = ownedDescriptor(id: calendarID),
              let participant = participants(for: calendarID).first(where: {
                  $0.id == participantSnapshotID && !$0.isAccepted
              }),
              let token = participant.revocationToken else {
            throw CalendarSharingError.shareUnavailable
        }
        let state = try await client.revokePendingInvitation(
            for: descriptor,
            participantID: token
        )
        ownedCalendars = ownedCalendars.map {
            $0.id == calendarID ? state.calendar : $0
        }
        participantsByCalendarID[calendarID] = state.participants
    }

    func renameOwnedCalendar(id: UUID, name: String) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              let descriptor = ownedDescriptor(id: id),
              var local = calendar(id: id),
              local.canManageParticipants else {
            throw CalendarSharingError.permissionDenied
        }
        try await client.renameOwnedCalendar(descriptor, name: name)
        local.name = name
        local.updatedAt = Date()
        try await calendarRepository.save(local)
        ownedCalendars = ownedCalendars.map { value in
            guard value.id == id else { return value }
            var value = value
            value.calendarName = name
            return value
        }
        await loadLocalCalendars()
    }

    func stopOwnedSharing(id: UUID) async throws {
        guard var local = try await calendarRepository.calendar(id: id),
              local.kind == .sharedOwned else {
            throw CalendarSharingError.shareUnavailable
        }

        if local.stopPhase == .active {
            local.stopPhase = .localReassignmentPending
            local.updatedAt = Date()
            try await calendarRepository.save(local)
            if selection.calendarID == id { select(.mine) }
            await loadLocalCalendars()
            revision &+= 1
        }

        await cancelAndWaitForSync(calendarID: id)

        if local.stopPhase == .localReassignmentPending {
            try await eventUseCase.reassignEventsForStoppingOwnedCalendar(
                from: id,
                to: TimeNestCalendar.personalID
            )
            local.stopPhase = .cloudDeletionPending
            local.updatedAt = Date()
            try await calendarRepository.save(local)
            await loadLocalCalendars()
        }

        let descriptor = try ownedDescriptorForStopping(local)
        try await client.stopOwnedSharing(descriptor)
        try await calendarRepository.delete(id: id)
        ownedCalendars.removeAll { $0.id == id }
        participantsByCalendarID.removeValue(forKey: id)
        if selection.calendarID == id { select(.mine) }
        await loadLocalCalendars()
        revision &+= 1
    }

    private func resumePendingStops() async -> CalendarSharingError? {
        let pending: [TimeNestCalendar]
        do {
            pending = try await calendarRepository.calendars().filter {
                $0.kind == .sharedOwned && $0.stopPhase.isStopping
            }
        } catch {
            lastError = .syncFailed
            return .syncFailed
        }

        var recoveryError: CalendarSharingError?
        for calendar in pending {
            do {
                try await stopOwnedSharing(id: calendar.id)
            } catch let error as CalendarSharingError {
                lastError = error
                recoveryError = recoveryError ?? error
            } catch {
                lastError = CalendarSharingErrorMapper.map(error)
                recoveryError = recoveryError ?? CalendarSharingErrorMapper.map(error)
            }
        }
        return recoveryError
    }

    private func ownedDescriptorForStopping(
        _ calendar: TimeNestCalendar
    ) throws -> OwnedSharedCalendarDescriptor {
        guard let zoneName = calendar.zoneName,
              let ownerName = calendar.ownerName,
              let rootRecordName = calendar.rootRecordName,
              let shareRecordName = calendar.shareRecordName else {
            throw CalendarSharingError.shareUnavailable
        }
        return OwnedSharedCalendarDescriptor(
            id: calendar.id,
            zoneName: zoneName,
            ownerName: ownerName,
            calendarName: calendar.name,
            participantCount: participants(for: calendar.id).filter(\.isAccepted).count,
            rootRecordName: rootRecordName,
            shareRecordName: shareRecordName,
            eventEditingAllowed: calendar.eventEditingAllowed,
            collaborationProtocolVersion: calendar.collaborationProtocolVersion
        )
    }

    func leave(_ calendar: SharedCalendarDescriptor) async throws {
        try await client.leaveSharedCalendar(calendar)
        // Keep the local calendar visible until its durable collaborative-editing
        // state has been removed. Otherwise a persistence failure would orphan an
        // outbox that can no longer be reached from the UI or retried safely.
        try sharedEventEditingUseCase.removeCalendar(calendar.id)
        try await calendarRepository.delete(id: calendar.id)
        receivedCalendars.removeAll { $0.id == calendar.id }
        eventsByCalendarID.removeValue(forKey: calendar.id)
        shiftsByCalendarID.removeValue(forKey: calendar.id)
        workRecordsByCalendarID.removeValue(forKey: calendar.id)
        if selection.calendarID == calendar.id { select(.mine) }
        await loadLocalCalendars()
        persistCache()
        revision &+= 1
    }

    func acceptShareURL(
        _ rawValue: String
    ) async throws -> CalendarSharingManualInvitationResult {
        manualInvitationState = .validating
        do {
            try await requireAvailableICloud()
            let url = try CalendarSharingInvitationURLValidator.validatedURL(
                from: rawValue
            )
            invitationRouter.register(store: self)
            let result = try await invitationRouter.receive(
                url: url,
                source: .manualURL,
                metadataDidLoad: { [weak self] in
                    self?.manualInvitationState = .accepting
                }
            )
            invitationAcceptanceError = nil
            switch result {
            case .accepted:
                manualInvitationState = .accepted
            case .alreadyAccepted:
                manualInvitationState = .alreadyAccepted
            }
            return result
        } catch {
            let mappedError = (error as? CalendarSharingError)
                ?? CalendarSharingErrorMapper.map(
                    error,
                    context: .fetchingInvitationMetadata
                )
            manualInvitationState = .failed(mappedError)
            invitationAcceptanceError = nil
            throw mappedError
        }
    }

    func resetManualInvitationState() {
        manualInvitationState = .idle
    }

    func fetchShareMetadata(
        from url: URL
    ) async throws -> any CalendarSharingShareMetadata {
        try await requireAvailableICloud()
        return try await client.fetchShareMetadata(from: url)
    }

    func accept(
        metadata: any CalendarSharingShareMetadata
    ) async -> CalendarSharingAcceptanceProcessingResult {
        isAcceptingInvitation = true
        invitationAcceptanceError = nil
        syncStatus = .syncing
        lastError = nil
        defer { isAcceptingInvitation = false }
        let metadataHash = CalendarSharingDiagnostics.metadataHash(metadata)
        let acceptedShare: AcceptedSharedCalendarCloudResult

        do {
            try await requireAvailableICloud()
        } catch {
            let mappedError = (error as? CalendarSharingError) ?? .iCloudStatusUnavailable
            lastError = mappedError
            invitationAcceptanceError = mappedError
            syncStatus = .failed
            return acceptanceProcessingResult(for: mappedError)
        }

        if let pendingShare = acceptedMetadataAwaitingRefresh[metadataHash] {
            acceptedShare = pendingShare
            CalendarSharingDiagnostics.debug(
                operation: "acceptShare",
                stage: "accept-skipped-already-completed",
                database: "shared",
                details: "metadataHash=\(metadataHash)"
            )
        } else {
            do {
                acceptedShare = try await client.accept(metadata: metadata)
                acceptedMetadataAwaitingRefresh[metadataHash] = acceptedShare
            } catch {
                let mappedError = (error as? CalendarSharingError)
                    ?? CalendarSharingErrorMapper.map(
                        error,
                        context: .acceptingInvitation
                    )
                lastError = mappedError
                invitationAcceptanceError = mappedError
                syncStatus = .failed
                CalendarSharingDiagnostics.error(
                    operation: "acceptShare",
                    stage: "accept-failed",
                    database: "shared",
                    error: error,
                    details: "metadataHash=\(metadataHash)"
                )
                return acceptanceProcessingResult(for: mappedError)
            }
        }

        await waitForRefreshToFinish()
        CalendarSharingDiagnostics.debug(
            operation: "acceptShare",
            stage: "refresh-started",
            database: "shared",
            details: "metadataHash=\(metadataHash)"
        )
        do {
            let calendar = try await refreshReceivedCalendar(
                acceptedShare: acceptedShare
            )
            acceptedMetadataAwaitingRefresh[metadataHash] = nil
            select(.calendar(calendar.id))
            lastError = initialMigrationError
            invitationAcceptanceError = nil
            syncStatus = .synced
            recordSuccessfulSync()
            CalendarSharingDiagnostics.debug(
                operation: "acceptShare",
                stage: "refresh-completed",
                database: "shared",
                details: "metadataHash=\(metadataHash) "
                    + "calendarHash=\(CalendarSharingDiagnostics.identifierHash(calendar.id.uuidString)) "
                    + "receivedCalendarCount=\(receivedCalendars.count)"
            )
            return .completed
        } catch {
            let refreshError = CalendarSharingError.receivedCalendarRefreshFailed
            lastError = refreshError
            invitationAcceptanceError = refreshError
            syncStatus = .failed
            CalendarSharingDiagnostics.error(
                operation: "acceptShare",
                stage: "refresh-failed",
                database: "shared",
                error: error,
                details: "metadataHash=\(metadataHash) "
                    + "receivedCalendarCount=\(receivedCalendars.count)"
            )
            return .retryLater
        }
    }

    func clearInvitationAcceptanceError() {
        invitationAcceptanceError = nil
    }

    private func acceptanceProcessingResult(
        for error: CalendarSharingError
    ) -> CalendarSharingAcceptanceProcessingResult {
        switch error {
        case .noICloudAccount, .iCloudRestricted, .iCloudStatusUnavailable, .networkUnavailable,
             .serviceTemporarilyUnavailable, .invitationPending,
             .invitationAcceptanceFailed, .receivedCalendarRefreshFailed,
             .localPersistenceFailed, .syncFailed:
            .retryLater
        case .invitationInvalid, .invitationRevoked, .cloudEnvironmentMismatch,
             .invitationURLInputEmpty, .invitationURLInvalid, .notCloudKitShare,
             .metadataFetchFailed, .invitationContainerMismatch,
             .invitationUnavailable, .permissionDenied,
             .sharedEventDeleted, .sharedEventPermissionRevoked,
             .invitationCreationFailed, .invitationURLUnavailable,
             .invitationActivityFailed,
             .shareCreationFailed, .shareUnavailable,
             .calendarDataMigrationFailed, .invitationCancellationFailed:
            .discarded
        }
    }

    private func refreshReceivedCalendar(
        acceptedShare: AcceptedSharedCalendarCloudResult
    ) async throws -> SharedCalendarDescriptor {
        let metadataOwnerDisplayName = CalendarSharingOwnerDisplayNameResolver.normalized(
            acceptedShare.ownerDisplayName
        )
        let payloads = try reconcileReceivedSharedEvents(mergingReceivedOwnerDisplayNames(
            into: try await client.fetchReceivedCalendars()
        ).map { payload in
            guard payload.calendar.zoneName == acceptedShare.zoneName,
                  let metadataOwnerDisplayName else {
                return payload
            }
            var calendar = payload.calendar
            calendar.ownerDisplayName = metadataOwnerDisplayName
            return ReceivedSharedCalendarPayload(
                calendar: calendar,
                events: payload.events,
                shifts: payload.shifts,
                workRecords: payload.workRecords,
                eventEnvelopes: payload.eventEnvelopes
            )
        })
        guard let acceptedPayload = payloads.first(where: {
            $0.calendar.zoneName == acceptedShare.zoneName
        }) else {
            throw CalendarSharingError.receivedCalendarRefreshFailed
        }

        try await persistCloudCalendars(
            ownedStates: [],
            receivedPayloads: payloads
        )
        try await reconcileReceivedCalendars(
            receivedIDs: Set(payloads.map(\.calendar.id))
        )
        receivedCalendars = payloads.map(\.calendar)
        eventsByCalendarID = Dictionary(
            uniqueKeysWithValues: payloads.map { ($0.calendar.id, $0.events) }
        )
        shiftsByCalendarID = Dictionary(
            uniqueKeysWithValues: payloads.map { ($0.calendar.id, $0.shifts) }
        )
        workRecordsByCalendarID = Dictionary(
            uniqueKeysWithValues: payloads.map { ($0.calendar.id, $0.workRecords) }
        )
        await loadLocalCalendars()
        validateSelection()
        persistCache()
        revision &+= 1
        return acceptedPayload.calendar
    }

    private func mergingReceivedOwnerDisplayNames(
        into payloads: [ReceivedSharedCalendarPayload]
    ) -> [ReceivedSharedCalendarPayload] {
        payloads.map { payload in
            let existingOwnerDisplayName = receivedCalendars.first {
                $0.id == payload.calendar.id
            }?.ownerDisplayName

            var calendar = payload.calendar
            calendar.ownerDisplayName = CalendarSharingOwnerDisplayNameResolver.resolve(
                incoming: calendar.ownerDisplayName,
                existing: existingOwnerDisplayName
            )
            return ReceivedSharedCalendarPayload(
                calendar: calendar,
                events: payload.events,
                shifts: payload.shifts,
                workRecords: payload.workRecords,
                eventEnvelopes: payload.eventEnvelopes
            )
        }
    }

    private func reconcileReceivedSharedEvents(
        _ payloads: [ReceivedSharedCalendarPayload]
    ) throws -> [ReceivedSharedCalendarPayload] {
        try payloads.map { payload in
            try sharedEventEditingUseCase.reconcileReceived(
                calendar: payload.calendar,
                envelopes: payload.eventEnvelopes
            )
            return ReceivedSharedCalendarPayload(
                calendar: payload.calendar,
                events: sharedEventEditingUseCase.visibleSnapshots(
                    calendarID: payload.calendar.id
                ),
                shifts: payload.shifts,
                workRecords: payload.workRecords,
                eventEnvelopes: payload.eventEnvelopes
            )
        }
    }

    func ensureCanWrite(calendarID: UUID) throws {
        guard let calendar = calendar(id: calendarID), calendar.canEditContent else {
            throw CalendarSharingError.permissionDenied
        }
    }

    /// Cloud target is reconciled before the local row leaves its source calendar. This makes
    /// cross-zone moves duplicate-safe: a failure can leave an extra target record, never lose data.
    func moveEvent(_ event: CalendarEvent, to targetCalendarID: UUID) async throws {
        try ensureCanWrite(calendarID: event.calendarID)
        try ensureCanWrite(calendarID: targetCalendarID)
        guard event.calendarID != targetCalendarID else { return }

        let sourceCalendarID = event.calendarID
        var moved = event
        moved.calendarID = targetCalendarID
        moved.updatedAt = Date()

        let sourceDescriptor = ownedDescriptor(id: sourceCalendarID)
        let targetDescriptor = ownedDescriptor(id: targetCalendarID)
        let touchesCollaborativeCalendar = (sourceDescriptor?.collaborationProtocolVersion ?? 0) >= 1
            || (targetDescriptor?.collaborationProtocolVersion ?? 0) >= 1
        if touchesCollaborativeCalendar {
            // The event move and both source/target cloud intents are persisted together by
            // EventUseCase. Cloud delivery may fail later without losing either intent.
            _ = try await eventUseCase.updateEvent(moved)
            for descriptor in [targetDescriptor, sourceDescriptor].compactMap({ $0 }) {
                let request = enqueueOwnedSync(descriptor)
                await waitForOwnedSync(request)
                if completedSyncGenerations[descriptor.id, default: 0] < request.generation {
                    throw lastError ?? CalendarSharingError.syncFailed
                }
            }
            revision &+= 1
            return
        }

        if let target = targetDescriptor {
            pendingExtraEvents[targetCalendarID, default: [:]][moved.id] = moved
            let request = enqueueOwnedSync(target)
            await waitForOwnedSync(request)
            if completedSyncGenerations[targetCalendarID, default: 0] < request.generation {
                pendingExtraEvents[targetCalendarID]?[moved.id] = nil
                throw lastError ?? CalendarSharingError.syncFailed
            }
        }

        _ = try await eventUseCase.updateEvent(moved)
        pendingExtraEvents[targetCalendarID]?[moved.id] = nil
        if let source = sourceDescriptor {
            let request = enqueueOwnedSync(source)
            await waitForOwnedSync(request)
            if completedSyncGenerations[sourceCalendarID, default: 0] < request.generation {
                throw lastError ?? CalendarSharingError.syncFailed
            }
        }
        revision &+= 1
    }

    private struct LocalSnapshots {
        let events: [SharedEventSnapshot]
        let shifts: [SharedShiftSnapshot]
        let workRecords: [SharedWorkRecordSnapshot]
    }

    private struct OwnedSyncRequest {
        let calendarID: UUID
        let generation: Int
    }

    private struct OwnedSyncWork {
        let descriptor: OwnedSharedCalendarDescriptor
        let generation: Int
        let extraEvents: [CalendarEvent]
    }

    private func enqueueOwnedSync(
        _ calendar: OwnedSharedCalendarDescriptor
    ) -> OwnedSyncRequest {
        let id = calendar.id
        guard !isStopping(calendarID: id) else {
            return OwnedSyncRequest(
                calendarID: id,
                generation: completedSyncGenerations[id, default: 0]
            )
        }
        syncDescriptors[id] = calendar
        syncGenerations[id, default: 0] &+= 1
        let request = OwnedSyncRequest(calendarID: id, generation: syncGenerations[id, default: 0])
        startSyncWorkerIfNeeded(calendarID: id)
        return request
    }

    private func startSyncWorkerIfNeeded(calendarID: UUID) {
        guard syncWorkers[calendarID] == nil else { return }
        let client = client
        let eventUseCase = eventUseCase
        let sharedEventEditingUseCase = sharedEventEditingUseCase
        let worker = Task { @MainActor [weak self] in
            defer { self?.syncWorkers[calendarID] = nil }
            while !Task.isCancelled {
                guard let work = self?.nextSyncWork(calendarID: calendarID) else {
                    return
                }
                do {
                    try await sharedEventEditingUseCase.synchronizeOwned(
                        calendar: work.descriptor,
                        adding: work.extraEvents.compactMap(SharedEventMapper.snapshot(from:))
                    )
                    let snapshots = try await Self.localSnapshots(
                        eventUseCase: eventUseCase,
                        calendarID: calendarID,
                        adding: work.extraEvents
                    )
                    try Task.checkCancellation()
                    try await client.synchronizeOwnedContent(
                        calendar: work.descriptor,
                        events: snapshots.events,
                        shifts: snapshots.shifts,
                        workRecords: snapshots.workRecords
                    )
                    guard let store = self else { return }
                    store.completedSyncGenerations[calendarID] = work.generation
                    store.failedSyncGenerations[calendarID] = nil
                    if store.lastError != store.initialMigrationError {
                        store.lastError = store.initialMigrationError
                    }
                    guard store.syncGenerations[calendarID, default: 0] != work.generation else {
                        return
                    }
                } catch is CancellationError {
                    return
                } catch let error as CalendarSharingError {
                    self?.failedSyncGenerations[calendarID] = work.generation
                    self?.lastError = error
                    return
                } catch {
                    self?.failedSyncGenerations[calendarID] = work.generation
                    self?.lastError = CalendarSharingErrorMapper.map(error)
                    return
                }
            }
        }
        syncWorkers[calendarID] = worker
    }

    private func waitForOwnedSync(_ request: OwnedSyncRequest) async {
        while completedSyncGenerations[request.calendarID, default: 0] < request.generation {
            guard !Task.isCancelled, !isStopping(calendarID: request.calendarID) else {
                return
            }
            guard let worker = syncWorkers[request.calendarID] else {
                let failedGeneration = failedSyncGenerations[request.calendarID, default: 0]
                guard request.generation > failedGeneration else { return }
                startSyncWorkerIfNeeded(calendarID: request.calendarID)
                continue
            }
            await worker.value
            if failedSyncGenerations[request.calendarID, default: 0] >= request.generation {
                return
            }
        }
    }

    private func nextSyncWork(calendarID: UUID) -> OwnedSyncWork? {
        guard !isStopping(calendarID: calendarID),
              let descriptor = syncDescriptors[calendarID] else {
            return nil
        }
        return OwnedSyncWork(
            descriptor: descriptor,
            generation: syncGenerations[calendarID, default: 0],
            extraEvents: pendingExtraEvents[calendarID].map { Array($0.values) } ?? []
        )
    }

    private func cancelAndWaitForSync(calendarID: UUID) async {
        if let worker = syncWorkers[calendarID] {
            worker.cancel()
            await worker.value
        }
        syncWorkers[calendarID] = nil
        syncGenerations[calendarID] = nil
        completedSyncGenerations[calendarID] = nil
        failedSyncGenerations[calendarID] = nil
        syncDescriptors[calendarID] = nil
        pendingExtraEvents[calendarID] = nil
    }

    private static func localSnapshots(
        eventUseCase: EventUseCase,
        calendarID: UUID,
        adding extraEvents: [CalendarEvent] = []
    ) async throws -> LocalSnapshots {
        var localEvents = try await eventUseCase.events(
            in: DateInterval(start: .distantPast, end: .distantFuture),
            calendarID: calendarID
        )
        for extraEvent in extraEvents {
            localEvents.removeAll { $0.id == extraEvent.id }
            localEvents.append(extraEvent)
        }
        return LocalSnapshots(
            events: localEvents.compactMap(SharedEventMapper.snapshot(from:)),
            shifts: localEvents.compactMap { SharedShiftMapper.snapshot(from: $0) },
            workRecords: SharedWorkRecordMapper.snapshots(from: localEvents)
        )
    }

    private func persistCloudCalendars(
        ownedStates: [OwnedSharedCalendarCloudState],
        receivedPayloads: [ReceivedSharedCalendarPayload]
    ) async throws {
        for state in ownedStates { try await persistOwnedState(state) }
        for payload in receivedPayloads {
            let descriptor = payload.calendar
            let existing = try await calendarRepository.calendar(id: descriptor.id)
            let now = Date()
            try await calendarRepository.save(
                TimeNestCalendar(
                    id: descriptor.id,
                    name: descriptor.calendarName,
                    kind: .sharedReceived,
                    zoneName: descriptor.zoneName,
                    ownerName: descriptor.ownerName,
                    rootRecordName: descriptor.rootRecordName,
                    shareRecordName: descriptor.shareRecordName,
                    eventEditingAllowed: descriptor.eventEditingAllowed,
                    collaborationProtocolVersion: descriptor.collaborationProtocolVersion,
                    participantPermission: descriptor.participantPermission,
                    createdAt: existing?.createdAt ?? now,
                    updatedAt: now
                )
            )
        }
    }

    private func reconcileRemovedCloudCalendars(
        ownedIDs: Set<UUID>,
        receivedIDs: Set<UUID>
    ) async throws {
        let localCalendars = try await calendarRepository.calendars()
        for calendar in localCalendars {
            switch calendar.kind {
            case .personal:
                continue
            case .sharedOwned where calendar.stopPhase.isStopping:
                continue
            case .sharedOwned where !ownedIDs.contains(calendar.id):
                try await eventUseCase.reassignEvents(
                    from: calendar.id,
                    to: TimeNestCalendar.personalID
                )
                try await calendarRepository.delete(id: calendar.id)
            case .sharedReceived where !receivedIDs.contains(calendar.id):
                try sharedEventEditingUseCase.removeCalendar(calendar.id)
                try await calendarRepository.delete(id: calendar.id)
            case .sharedOwned, .sharedReceived:
                continue
            }
        }
    }

    private func reconcileReceivedCalendars(
        receivedIDs: Set<UUID>
    ) async throws {
        let localCalendars = try await calendarRepository.calendars()
        for calendar in localCalendars
        where calendar.kind == .sharedReceived && !receivedIDs.contains(calendar.id) {
            try sharedEventEditingUseCase.removeCalendar(calendar.id)
            try await calendarRepository.delete(id: calendar.id)
        }
    }

    private func waitForRefreshToFinish() async {
        while refreshIsInProgress {
            await withCheckedContinuation { continuation in
                refreshCompletionWaiters.append(continuation)
            }
        }
    }

    private func finishRefresh() {
        refreshIsInProgress = false
        refreshWasRequested = false
        let waiters = refreshCompletionWaiters
        refreshCompletionWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private func persistOwnedState(_ state: OwnedSharedCalendarCloudState) async throws {
        let descriptor = state.calendar
        let existing = try await calendarRepository.calendar(id: descriptor.id)
        let now = Date()
        try await calendarRepository.save(
            TimeNestCalendar(
                id: descriptor.id,
                name: descriptor.calendarName,
                kind: .sharedOwned,
                zoneName: descriptor.zoneName,
                ownerName: descriptor.ownerName,
                rootRecordName: descriptor.rootRecordName,
                shareRecordName: descriptor.shareRecordName,
                eventEditingAllowed: descriptor.eventEditingAllowed,
                collaborationProtocolVersion: descriptor.collaborationProtocolVersion,
                participantPermission: .none,
                stopPhase: existing?.stopPhase ?? .active,
                createdAt: existing?.createdAt ?? now,
                updatedAt: now
            )
        )
    }

    private func loadLocalCalendars() async {
        do {
            calendars = try await calendarRepository.calendars()
                .sorted { lhs, rhs in
                    if lhs.kind != rhs.kind {
                        return kindOrder(lhs.kind) < kindOrder(rhs.kind)
                    }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
            validateSelection()
        } catch {
            lastError = .syncFailed
        }
    }

    private func mergedOwnedDescriptors(
        cloudDescriptors: [OwnedSharedCalendarDescriptor]
    ) -> [OwnedSharedCalendarDescriptor] {
        var byID = Dictionary(uniqueKeysWithValues: cloudDescriptors.map { ($0.id, $0) })
        for calendar in calendars where calendar.kind == .sharedOwned && calendar.stopPhase.isStopping {
            if byID[calendar.id] == nil,
               let descriptor = try? ownedDescriptorForStopping(calendar) {
                byID[calendar.id] = descriptor
            }
        }
        return byID.values.sorted {
            $0.calendarName.localizedCaseInsensitiveCompare($1.calendarName) == .orderedAscending
        }
    }

    private func validateSelection() {
        let resolved = CalendarSelectionPersistence.resolved(
            selection,
            validCalendarIDs: Set(calendars.map(\.id))
        )
        if resolved != selection {
            selection = resolved
            selectionPersistence.save(resolved)
        }
    }

    private func kindOrder(_ kind: TimeNestCalendarKind) -> Int {
        switch kind {
        case .personal: 0
        case .sharedOwned: 1
        case .sharedReceived: 2
        }
    }

    private func persistCache() {
        try? cache.save(
            CalendarSharingCacheData(
                receivedCalendars: receivedCalendars,
                eventsByCalendarID: eventsByCalendarID,
                shiftsByCalendarID: shiftsByCalendarID,
                workRecordsByCalendarID: workRecordsByCalendarID
            )
        )
    }

    private func refreshReceivedSharedEventCache(calendarID: UUID) {
        eventsByCalendarID[calendarID] = sharedEventEditingUseCase.visibleSnapshots(
            calendarID: calendarID
        )
        persistCache()
        revision &+= 1
    }

    func handleLocalDataRestore() async {
        select(.mine)
        calendars = []
        ownedCalendars = []
        receivedCalendars = []
        participantsByCalendarID = [:]
        eventsByCalendarID = [:]
        shiftsByCalendarID = [:]
        workRecordsByCalendarID = [:]
        let sharedEventResetError: CalendarSharingError?
        do {
            try sharedEventEditingUseCase.reset()
            sharedEventResetError = nil
        } catch {
            sharedEventResetError = .localPersistenceFailed
        }
        syncStatus = .idle
        lastError = sharedEventResetError
        lastSuccessfulSyncAt = nil
        syncMetadataPersistence.saveLastSuccessfulSyncAt(nil)
        try? cache.save(.empty)
        await loadLocalCalendars()
        revision &+= 1
    }

    private func requireAvailableICloud() async throws {
        let status = await refreshICloudStatus()
        if let error = status.operationError {
            throw error
        }
    }

    private func recordSuccessfulSync(at date: Date = Date()) {
        lastSuccessfulSyncAt = date
        syncMetadataPersistence.saveLastSuccessfulSyncAt(date)
    }
}
