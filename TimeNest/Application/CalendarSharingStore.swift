import CloudKit
import Combine
import Foundation

enum CalendarSharingSyncStatus: Equatable {
    case idle
    case syncing
    case synced
    case failed
}

@MainActor
final class CalendarSharingStore: ObservableObject {
    @Published private(set) var selection: CalendarSelection
    @Published private(set) var calendars: [TimeNestCalendar] = []
    @Published private(set) var ownedCalendars: [OwnedSharedCalendarDescriptor] = []
    @Published private(set) var receivedCalendars: [SharedCalendarDescriptor]
    @Published private(set) var participantsByCalendarID: [UUID: [SharedCalendarParticipantSnapshot]] = [:]
    @Published private(set) var syncStatus: CalendarSharingSyncStatus = .idle
    @Published private(set) var lastError: CalendarSharingError?
    @Published private(set) var isAcceptingInvitation = false
    @Published private(set) var invitationAcceptanceError: CalendarSharingError?
    @Published private(set) var revision = 0

    private let client: any CalendarSharingClientProtocol
    private let eventUseCase: EventUseCase
    private let calendarRepository: any CalendarRepository
    private let cache: CalendarSharingCache
    private let selectionPersistence: CalendarSelectionPersistence
    private var eventsByCalendarID: [UUID: [SharedEventSnapshot]]
    private var shiftsByCalendarID: [UUID: [SharedShiftSnapshot]]
    private var workRecordsByCalendarID: [UUID: [SharedWorkRecordSnapshot]]
    private var refreshIsInProgress = false
    private var refreshWasRequested = false
    private var refreshCompletionWaiters: [CheckedContinuation<Void, Never>] = []
    private var acceptedMetadataAwaitingRefresh: [String: String] = [:]
    private let initialMigrationError: CalendarSharingError?
    private var syncGenerations: [UUID: Int] = [:]
    private var completedSyncGenerations: [UUID: Int] = [:]
    private var failedSyncGenerations: [UUID: Int] = [:]
    private var syncWorkers: [UUID: Task<Void, Never>] = [:]
    private var syncDescriptors: [UUID: OwnedSharedCalendarDescriptor] = [:]
    private var pendingExtraEvents: [UUID: [UUID: CalendarEvent]] = [:]

    init(
        client: any CalendarSharingClientProtocol,
        eventUseCase: EventUseCase,
        calendarRepository: any CalendarRepository,
        cache: CalendarSharingCache = CalendarSharingCache(),
        selectionPersistence: CalendarSelectionPersistence = CalendarSelectionPersistence(),
        initialCalendars: [TimeNestCalendar] = [],
        initialMigrationError: CalendarSharingError? = nil
    ) {
        self.client = client
        self.eventUseCase = eventUseCase
        self.calendarRepository = calendarRepository
        self.cache = cache
        self.selectionPersistence = selectionPersistence
        self.initialMigrationError = initialMigrationError
        calendars = initialCalendars
        let cached = cache.load()
        receivedCalendars = cached.receivedCalendars
        eventsByCalendarID = cached.eventsByCalendarID
        shiftsByCalendarID = cached.shiftsByCalendarID
        workRecordsByCalendarID = cached.workRecordsByCalendarID
        selection = selectionPersistence.load()
    }

    deinit {
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

    func isStopping(calendarID: UUID) -> Bool {
        calendar(id: calendarID)?.stopPhase.isStopping == true
    }

    func calendar(id: UUID) -> TimeNestCalendar? {
        calendars.first { $0.id == id }
    }

    func ownedDescriptor(id: UUID) -> OwnedSharedCalendarDescriptor? {
        ownedCalendars.first { $0.id == id }
    }

    func participants(for calendarID: UUID) -> [SharedCalendarParticipantSnapshot] {
        participantsByCalendarID[calendarID] ?? []
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

    func start() async {
        await loadLocalCalendars()
        _ = await resumePendingStops()
        CalendarSharingInvitationRouter.shared.register(store: self)
        await synchronizeAll()
    }

    func synchronizeOnAppActivation() async {
        _ = await resumePendingStops()
        await synchronizeAll()
        CalendarSharingInvitationRouter.shared.retryPending()
    }

    func synchronizeAll() async {
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
        CalendarSharingInvitationRouter.shared.retryPending()
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
            let receivedPayloads = try await client.fetchReceivedCalendars()
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

    func refreshOwnedParticipants() async {
        await synchronizeAll()
    }

    func createSharedCalendar(name: String) async throws -> CalendarSharingInvitation {
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
            try await persistOwnedState(result.state)
            ownedCalendars.append(result.state.calendar)
            participantsByCalendarID[id] = result.state.participants
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
        case .cancelled, .activityError:
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
                        + "activityCompleted=false"
                )
                lastError = initialMigrationError
            } catch {
                lastError = .invitationCancellationFailed
                throw CalendarSharingError.invitationCancellationFailed
            }
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
            shareRecordName: shareRecordName
        )
    }

    func leave(_ calendar: SharedCalendarDescriptor) async throws {
        try await client.leaveSharedCalendar(calendar)
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

    func accept(
        metadata: any CalendarSharingShareMetadata
    ) async -> CalendarSharingAcceptanceProcessingResult {
        isAcceptingInvitation = true
        invitationAcceptanceError = nil
        syncStatus = .syncing
        lastError = nil
        defer { isAcceptingInvitation = false }
        let metadataHash = CalendarSharingDiagnostics.metadataHash(metadata)
        let acceptedZoneName: String

        if let pendingZoneName = acceptedMetadataAwaitingRefresh[metadataHash] {
            acceptedZoneName = pendingZoneName
            CalendarSharingDiagnostics.debug(
                operation: "acceptShare",
                stage: "accept-skipped-already-completed",
                database: "shared",
                details: "metadataHash=\(metadataHash)"
            )
        } else {
            do {
                acceptedZoneName = try await client.accept(metadata: metadata)
                acceptedMetadataAwaitingRefresh[metadataHash] = acceptedZoneName
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
                acceptedZoneName: acceptedZoneName
            )
            acceptedMetadataAwaitingRefresh[metadataHash] = nil
            select(.calendar(calendar.id))
            lastError = initialMigrationError
            invitationAcceptanceError = nil
            syncStatus = .synced
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
        case .noICloudAccount, .iCloudRestricted, .networkUnavailable,
             .invitationPending, .receivedCalendarRefreshFailed, .syncFailed:
            .retryLater
        case .invitationInvalid, .invitationRevoked, .cloudEnvironmentMismatch,
             .permissionDenied, .invitationCreationFailed, .invitationURLUnavailable,
             .shareCreationFailed, .shareUnavailable, .calendarDataMigrationFailed,
             .invitationCancellationFailed:
            .discarded
        }
    }

    private func refreshReceivedCalendar(
        acceptedZoneName: String
    ) async throws -> SharedCalendarDescriptor {
        let payloads = try await client.fetchReceivedCalendars()
        guard let acceptedPayload = payloads.first(where: {
            $0.calendar.zoneName == acceptedZoneName
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

        if let target = ownedDescriptor(id: targetCalendarID) {
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
        if let source = ownedDescriptor(id: sourceCalendarID) {
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
        let worker = Task { @MainActor [weak self] in
            defer { self?.syncWorkers[calendarID] = nil }
            while !Task.isCancelled {
                guard let work = self?.nextSyncWork(calendarID: calendarID) else {
                    return
                }
                do {
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
}
