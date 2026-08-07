import Foundation

enum SharedEventMutationOperation: String, Codable, Equatable, Sendable {
    case create
    case update
    case delete
}

struct SharedEventPendingMutation: Codable, Identifiable, Equatable {
    let id: UUID
    let calendarID: UUID
    let zoneName: String
    let ownerName: String
    let eventID: UUID
    var operation: SharedEventMutationOperation
    var payload: SharedEventSnapshot
    let createdAt: Date
    var sequence: Int64
    var retryCount: Int
    var lastErrorCode: String?
    var status: SharedEventMutationStatus

    private enum CodingKeys: String, CodingKey {
        case id, calendarID, zoneName, ownerName, eventID, operation, payload
        case createdAt, sequence, retryCount, lastErrorCode, status
    }

    init(
        id: UUID,
        calendarID: UUID,
        zoneName: String,
        ownerName: String,
        eventID: UUID,
        operation: SharedEventMutationOperation,
        payload: SharedEventSnapshot,
        createdAt: Date,
        sequence: Int64,
        retryCount: Int,
        lastErrorCode: String?,
        status: SharedEventMutationStatus
    ) {
        self.id = id
        self.calendarID = calendarID
        self.zoneName = zoneName
        self.ownerName = ownerName
        self.eventID = eventID
        self.operation = operation
        self.payload = payload
        self.createdAt = createdAt
        self.sequence = sequence
        self.retryCount = retryCount
        self.lastErrorCode = lastErrorCode
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawStatus = try container.decode(String.self, forKey: .status)
        let migratedStatus = SharedEventMutationStatus(rawValue: rawStatus) ?? {
            switch rawStatus {
            case SharedEventSyncStatus.saving.rawValue,
                 SharedEventSyncStatus.pending.rawValue:
                return .awaitingReconciliation
            case SharedEventSyncStatus.synced.rawValue:
                return .completed
            case SharedEventSyncStatus.permissionRevoked.rawValue:
                return .permissionRevoked
            case SharedEventSyncStatus.deletedRemotely.rawValue:
                return .deletedRemotely
            default:
                return .failed
            }
        }()
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            calendarID: try container.decode(UUID.self, forKey: .calendarID),
            zoneName: try container.decode(String.self, forKey: .zoneName),
            ownerName: try container.decode(String.self, forKey: .ownerName),
            eventID: try container.decode(UUID.self, forKey: .eventID),
            operation: try container.decode(SharedEventMutationOperation.self, forKey: .operation),
            payload: try container.decode(SharedEventSnapshot.self, forKey: .payload),
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            sequence: try container.decodeIfPresent(Int64.self, forKey: .sequence) ?? 0,
            retryCount: try container.decode(Int.self, forKey: .retryCount),
            lastErrorCode: try container.decodeIfPresent(String.self, forKey: .lastErrorCode),
            status: migratedStatus
        )
    }
}

struct SharedEventEditingPersistenceData: Codable {
    static let currentVersion = 2

    var version = currentVersion
    var envelopesByCalendarID: [UUID: [UUID: SharedEventEnvelope]] = [:]
    var outbox: [SharedEventPendingMutation] = []
    var nextSequence: Int64 = 1

    private enum CodingKeys: String, CodingKey {
        case version, envelopesByCalendarID, outbox, nextSequence
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        envelopesByCalendarID = try container.decodeIfPresent(
            [UUID: [UUID: SharedEventEnvelope]].self,
            forKey: .envelopesByCalendarID
        ) ?? [:]
        outbox = try container.decodeIfPresent(
            [SharedEventPendingMutation].self,
            forKey: .outbox
        ) ?? []
        let highestSequence = outbox.map(\.sequence).max() ?? 0
        nextSequence = max(
            try container.decodeIfPresent(Int64.self, forKey: .nextSequence) ?? 1,
            highestSequence + 1
        )
        version = Self.currentVersion
    }
}

struct SharedEventEditingPersistence {
    let fileURL: URL
    private let loadData: ((URL) throws -> Data?)?
    private let saveData: ((Data, URL) throws -> Void)?

    init(
        fileURL: URL = Self.defaultFileURL(),
        loadData: ((URL) throws -> Data?)? = nil,
        saveData: ((Data, URL) throws -> Void)? = nil
    ) {
        self.fileURL = fileURL
        self.loadData = loadData
        self.saveData = saveData
    }

    func load() throws -> SharedEventEditingPersistenceData {
        let data: Data?
        if let loadData {
            data = try loadData(fileURL)
        } else if FileManager.default.fileExists(atPath: fileURL.path) {
            data = try Data(contentsOf: fileURL)
        } else {
            data = nil
        }
        guard let data else { return SharedEventEditingPersistenceData() }
        return try JSONDecoder().decode(SharedEventEditingPersistenceData.self, from: data)
    }

    func save(_ state: SharedEventEditingPersistenceData) throws {
        let data = try JSONEncoder().encode(state)
        if let saveData {
            try saveData(data, fileURL)
            return
        }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        let baseURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        return baseURL
            .appendingPathComponent("TimeNestCalendarSharing", isDirectory: true)
            .appendingPathComponent("SharedEventEditing.json", isDirectory: false)
    }
}

@MainActor
final class SharedEventEditingUseCase {
    private let client: any CalendarSharingClientProtocol
    private let eventUseCase: EventUseCase
    private let persistence: SharedEventEditingPersistence
    private var state: SharedEventEditingPersistenceData
    private(set) var startupPersistenceError: CalendarSharingError?
    private var knownReceivedDescriptors: [UUID: SharedCalendarDescriptor] = [:]
    private var participantFlushTask: Task<Void, Error>?

    init(
        client: any CalendarSharingClientProtocol,
        eventUseCase: EventUseCase,
        persistence: SharedEventEditingPersistence = SharedEventEditingPersistence()
    ) {
        self.client = client
        self.eventUseCase = eventUseCase
        self.persistence = persistence
        do {
            state = try persistence.load()
            startupPersistenceError = nil
        } catch {
            state = SharedEventEditingPersistenceData()
            startupPersistenceError = .localPersistenceFailed
        }
    }

    func visibleSnapshots(calendarID: UUID) -> [SharedEventSnapshot] {
        (state.envelopesByCalendarID[calendarID] ?? [:]).values
            .filter { !$0.isDeleted }
            .map(\.snapshot)
            .sorted {
                if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    func envelope(calendarID: UUID, eventID: UUID) -> SharedEventEnvelope? {
        state.envelopesByCalendarID[calendarID]?[eventID]
    }

    func status(calendarID: UUID, eventID: UUID) -> SharedEventSyncStatus? {
        envelope(calendarID: calendarID, eventID: eventID)?.syncStatus
    }

    func pendingMutations(calendarID: UUID? = nil) -> [SharedEventPendingMutation] {
        state.outbox.filter {
            (calendarID == nil || $0.calendarID == calendarID)
                && requiresAutomaticRecovery($0.status)
        }
    }

    func allParticipantMutations(calendarID: UUID? = nil) -> [SharedEventPendingMutation] {
        state.outbox.filter { calendarID == nil || $0.calendarID == calendarID }
    }

    func removeCalendar(_ calendarID: UUID) throws {
        try ensurePersistenceAvailable()
        var candidate = state
        candidate.envelopesByCalendarID[calendarID] = nil
        candidate.outbox.removeAll { $0.calendarID == calendarID }
        try commit(candidate)
        knownReceivedDescriptors[calendarID] = nil
    }

    func reset() throws {
        try ensurePersistenceAvailable()
        try commit(SharedEventEditingPersistenceData())
        knownReceivedDescriptors = [:]
    }

    func reconcileReceived(
        calendar: SharedCalendarDescriptor,
        envelopes remoteEnvelopes: [SharedEventEnvelope],
        isAuthoritative: Bool = true
    ) throws {
        try ensurePersistenceAvailable()
        if !isAuthoritative {
            try bootstrapReceivedFromCache(calendar: calendar, envelopes: remoteEnvelopes)
            return
        }

        var candidate = state
        let active = candidate.outbox.filter {
            $0.calendarID == calendar.id && !$0.status.isTerminal
        }
        let pendingByEventID = Dictionary(
            active.map { ($0.eventID, $0) },
            uniquingKeysWith: { lhs, rhs in lhs.sequence > rhs.sequence ? lhs : rhs }
        )
        let remoteByID = Dictionary(
            remoteEnvelopes.map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        var merged = candidate.envelopesByCalendarID[calendar.id] ?? [:]

        for (eventID, remote) in remoteByID {
            if remote.isDeleted {
                markParticipantMutations(
                    calendarID: calendar.id,
                    eventID: eventID,
                    status: .deletedRemotely,
                    in: &candidate
                )
                var deleted = remote
                deleted.syncStatus = .deletedRemotely
                deleted.pendingMutationID = nil
                merged[eventID] = deleted
            } else if let pending = pendingByEventID[eventID] {
                var local = merged[eventID] ?? makeLocalEnvelope(
                    calendar: calendar,
                    snapshot: pending.payload,
                    status: pending.status.visibleSyncStatus,
                    mutationID: pending.id,
                    existing: nil
                )
                local.recordChangeTag = remote.recordChangeTag
                local.modificationDate = remote.modificationDate
                local.lastMutationID = remote.lastMutationID
                local.syncStatus = pending.status.visibleSyncStatus
                local.pendingMutationID = pending.id
                merged[eventID] = local
            } else {
                var synced = remote
                synced.syncStatus = .synced
                synced.pendingMutationID = nil
                merged[eventID] = synced
            }
        }

        for (eventID, existing) in merged
        where remoteByID[eventID] == nil && pendingByEventID[eventID] == nil && !existing.isDeleted {
            var deleted = existing
            deleted.snapshot = tombstone(from: existing.snapshot)
            deleted.syncStatus = .deletedRemotely
            deleted.pendingMutationID = nil
            merged[eventID] = deleted
        }

        candidate.envelopesByCalendarID[calendar.id] = merged
        if !calendar.eventEditingAllowed
            || calendar.participantPermission != .readWrite
            || calendar.collaborationProtocolVersion < 1 {
            markPermissionRevoked(calendarID: calendar.id, in: &candidate)
        } else {
            // This must also work after relaunch, when no previous in-memory descriptor exists.
            restorePermissionRevokedMutations(calendarID: calendar.id, in: &candidate)
        }
        try commit(candidate)
        knownReceivedDescriptors[calendar.id] = calendar
    }

    private func bootstrapReceivedFromCache(
        calendar: SharedCalendarDescriptor,
        envelopes cachedEnvelopes: [SharedEventEnvelope]
    ) throws {
        var candidate = state
        let active = candidate.outbox.filter {
            $0.calendarID == calendar.id && !$0.status.isTerminal
        }
        let pendingByEventID = Dictionary(
            active.map { ($0.eventID, $0) },
            uniquingKeysWith: { lhs, rhs in lhs.sequence > rhs.sequence ? lhs : rhs }
        )
        var merged = candidate.envelopesByCalendarID[calendar.id] ?? [:]
        for cached in cachedEnvelopes where merged[cached.id] == nil {
            if let pending = pendingByEventID[cached.id] {
                merged[cached.id] = makeLocalEnvelope(
                    calendar: calendar,
                    snapshot: pending.payload,
                    status: pending.status.visibleSyncStatus,
                    mutationID: pending.id,
                    existing: nil
                )
            } else {
                merged[cached.id] = cached
            }
        }
        for pending in pendingByEventID.values where merged[pending.eventID] == nil {
            merged[pending.eventID] = makeLocalEnvelope(
                calendar: calendar,
                snapshot: pending.payload,
                status: pending.status.visibleSyncStatus,
                mutationID: pending.id,
                existing: nil
            )
        }
        candidate.envelopesByCalendarID[calendar.id] = merged
        try commit(candidate)
    }

    @discardableResult
    func create(
        _ snapshot: SharedEventSnapshot,
        in calendar: SharedCalendarDescriptor
    ) async throws -> SharedEventSyncStatus {
        try validateWritePermission(calendar)
        if state.envelopesByCalendarID[calendar.id]?[snapshot.id]?.isDeleted == true {
            throw CalendarSharingError.sharedEventDeleted
        }
        try enqueue(snapshot: snapshot, operation: .create, calendar: calendar)
        try await flush(descriptors: [calendar.id: calendar])
        return status(calendarID: calendar.id, eventID: snapshot.id) ?? .failed
    }

    @discardableResult
    func update(
        _ snapshot: SharedEventSnapshot,
        in calendar: SharedCalendarDescriptor
    ) async throws -> SharedEventSyncStatus {
        try validateWritePermission(calendar)
        guard state.envelopesByCalendarID[calendar.id]?[snapshot.id]?.isDeleted != true else {
            throw CalendarSharingError.sharedEventDeleted
        }
        try enqueue(snapshot: snapshot, operation: .update, calendar: calendar)
        try await flush(descriptors: [calendar.id: calendar])
        return status(calendarID: calendar.id, eventID: snapshot.id) ?? .failed
    }

    @discardableResult
    func delete(
        eventID: UUID,
        in calendar: SharedCalendarDescriptor
    ) async throws -> SharedEventSyncStatus {
        try validateWritePermission(calendar)
        guard let existing = state.envelopesByCalendarID[calendar.id]?[eventID],
              !existing.isDeleted else {
            return .synced
        }
        try enqueue(snapshot: existing.snapshot, operation: .delete, calendar: calendar)
        try await flush(descriptors: [calendar.id: calendar])
        return status(calendarID: calendar.id, eventID: eventID) ?? .failed
    }

    func retryPending(in calendars: [SharedCalendarDescriptor]) async throws {
        try await flush(descriptors: Dictionary(uniqueKeysWithValues: calendars.map { ($0.id, $0) }))
    }

    /// Owner uploads are driven only by the SwiftData mutation journal. The materialized remote
    /// snapshot never serves as evidence that the owner intended a write.
    func synchronizeOwned(
        calendar: OwnedSharedCalendarDescriptor,
        adding _: [SharedEventSnapshot] = []
    ) async throws {
        guard calendar.collaborationProtocolVersion >= 1 else { return }
        var remote = try await client.fetchOwnedSharedEvents(in: calendar)
        try await reconcileOwnerUncertainMutations(calendar: calendar, remote: remote)
        try await applyRemoteTombstonesToOwnerJournal(calendar: calendar, remote: remote)
        try await drainOwnerPreparedMutations(calendar: calendar, remote: remote)
        remote = try await client.fetchOwnedSharedEvents(in: calendar)
        try await applyRemoteTombstonesToOwnerJournal(calendar: calendar, remote: remote)
        try await materializeOwnerRemote(calendar: calendar, remote: remote)
    }

    private func enqueue(
        snapshot: SharedEventSnapshot,
        operation: SharedEventMutationOperation,
        calendar: SharedCalendarDescriptor
    ) throws {
        try ensurePersistenceAvailable()
        let now = Date()
        let normalized = SharedEventSnapshot(
            id: snapshot.id,
            title: snapshot.title,
            startDate: snapshot.startDate,
            endDate: snapshot.endDate,
            isAllDay: snapshot.isAllDay,
            updatedAt: snapshot.updatedAt,
            isDeleted: operation == .delete,
            deletedAt: operation == .delete ? now : nil
        )
        var candidate = state
        for index in candidate.outbox.indices
        where candidate.outbox[index].calendarID == calendar.id
            && candidate.outbox[index].eventID == snapshot.id
            && candidate.outbox[index].status == .prepared {
            candidate.outbox[index].status = .superseded
        }
        let mutation = SharedEventPendingMutation(
            id: UUID(),
            calendarID: calendar.id,
            zoneName: calendar.zoneName,
            ownerName: calendar.ownerName,
            eventID: snapshot.id,
            operation: operation,
            payload: normalized,
            createdAt: now,
            sequence: candidate.nextSequence,
            retryCount: 0,
            lastErrorCode: nil,
            status: .prepared
        )
        candidate.nextSequence += 1
        candidate.outbox.append(mutation)
        let existing = candidate.envelopesByCalendarID[calendar.id]?[snapshot.id]
        candidate.envelopesByCalendarID[calendar.id, default: [:]][snapshot.id] = makeLocalEnvelope(
            calendar: calendar,
            snapshot: normalized,
            status: .saving,
            mutationID: mutation.id,
            existing: existing
        )
        try commit(candidate)
        knownReceivedDescriptors[calendar.id] = calendar
    }

    private func flush(descriptors: [UUID: SharedCalendarDescriptor]) async throws {
        try ensurePersistenceAvailable()
        knownReceivedDescriptors.merge(descriptors) { _, latest in latest }
        if let participantFlushTask {
            try await participantFlushTask.value
            if nextParticipantMutation() != nil {
                try await flush(descriptors: [:])
            }
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            var reconciledUncertainMutationIDs: Set<UUID> = []
            var transmittedMutationIDs: Set<UUID> = []
            while let mutation = self.nextParticipantMutation() {
                guard let calendar = self.knownReceivedDescriptors[mutation.calendarID] else {
                    return
                }
                // One flush may reconcile a prior uncertain write and then safely retry it, but
                // it never sends the same mutation twice across one network boundary. A timeout
                // therefore remains awaiting reconciliation until a later trigger/relaunch.
                guard !transmittedMutationIDs.contains(mutation.id) else { return }
                if mutation.status == .sending || mutation.status == .awaitingReconciliation {
                    guard reconciledUncertainMutationIDs.insert(mutation.id).inserted else {
                        return
                    }
                } else if mutation.status == .prepared {
                    transmittedMutationIDs.insert(mutation.id)
                }
                try await self.processParticipantMutation(mutation.id, calendar: calendar)
            }
        }
        participantFlushTask = task
        defer { participantFlushTask = nil }
        try await task.value
    }

    private func nextParticipantMutation() -> SharedEventPendingMutation? {
        state.outbox
            .filter { $0.status == .prepared
                || $0.status == .sending
                || $0.status == .awaitingReconciliation }
            .sorted { $0.sequence < $1.sequence }
            .first
    }

    private func processParticipantMutation(
        _ mutationID: UUID,
        calendar: SharedCalendarDescriptor
    ) async throws {
        guard let mutation = state.outbox.first(where: { $0.id == mutationID }) else { return }
        guard calendar.eventEditingAllowed,
              calendar.participantPermission == .readWrite,
              calendar.collaborationProtocolVersion >= 1 else {
            var candidate = state
            markPermissionRevoked(calendarID: calendar.id, in: &candidate)
            try commit(candidate)
            return
        }

        if mutation.status == .sending || mutation.status == .awaitingReconciliation {
            try await reconcileParticipantMutation(mutation, calendar: calendar)
            return
        }
        guard mutation.status == .prepared else { return }
        if mutation.retryCount >= 3 {
            try updateParticipantMutation(
                id: mutation.id,
                status: .failed,
                lastErrorCode: "retry_limit"
            )
            return
        }

        var sendingState = state
        guard let sendingIndex = sendingState.outbox.firstIndex(where: { $0.id == mutation.id }) else {
            return
        }
        sendingState.outbox[sendingIndex].status = .sending
        sendingState.outbox[sendingIndex].retryCount += 1
        sendingState.outbox[sendingIndex].lastErrorCode = nil
        setEnvelopeStatus(for: sendingState.outbox[sendingIndex], in: &sendingState)
        try commit(sendingState)
        guard let sending = state.outbox.first(where: { $0.id == mutation.id }) else { return }

        do {
            let envelope: SharedEventEnvelope?
            switch sending.operation {
            case .create:
                envelope = try await client.createReceivedSharedEvent(
                    sending.payload,
                    mutationID: sending.id,
                    in: calendar
                )
            case .update:
                envelope = try await client.updateReceivedSharedEvent(
                    sending.payload,
                    mutationID: sending.id,
                    in: calendar
                )
            case .delete:
                envelope = try await client.deleteReceivedSharedEvent(
                    eventID: sending.eventID,
                    mutationID: sending.id,
                    in: calendar
                )
            }
            try completeParticipantMutation(sending, envelope: envelope, calendar: calendar)
        } catch CalendarSharingError.localPersistenceFailed {
            // The durable copy is still `sending`; never downgrade a possibly accepted write to
            // an ordinary retry merely because its local completion marker could not be saved.
            throw CalendarSharingError.localPersistenceFailed
        } catch CalendarSharingError.sharedEventDeleted {
            try finishParticipantAsDeleted(sending, calendar: calendar)
        } catch let error as SharedEventWriteError {
            guard case .confirmedNotSent(let cause) = error else { return }
            try updateParticipantMutation(
                id: sending.id,
                status: .prepared,
                lastErrorCode: "confirmed_not_sent:\(String(describing: cause))"
            )
        } catch let error as CalendarSharingError {
            let status: SharedEventMutationStatus
            switch error {
            case .permissionDenied, .sharedEventPermissionRevoked:
                status = .permissionRevoked
            case .networkUnavailable, .serviceTemporarilyUnavailable, .noICloudAccount,
                 .iCloudStatusUnavailable:
                status = .awaitingReconciliation
            default:
                status = .failed
            }
            try updateParticipantMutation(
                id: sending.id,
                status: status,
                lastErrorCode: String(describing: error)
            )
        } catch {
            // The request crossed the network boundary. Unknown completion is reconciled; it is
            // never converted back into an ordinary retry.
            try updateParticipantMutation(
                id: sending.id,
                status: .awaitingReconciliation,
                lastErrorCode: "unexpected"
            )
        }
    }

    private func reconcileParticipantMutation(
        _ mutation: SharedEventPendingMutation,
        calendar: SharedCalendarDescriptor
    ) async throws {
        do {
            let remote = try await client.fetchReceivedSharedEvent(
                eventID: mutation.eventID,
                in: calendar
            )
            if let remote, remote.isDeleted {
                try finishParticipantAsDeleted(mutation, calendar: calendar, remote: remote)
            } else if let remote, remote.lastMutationID == mutation.id {
                try completeParticipantMutation(mutation, envelope: remote, calendar: calendar)
            } else if let remote {
                try supersedeParticipantMutation(mutation, remote: remote, calendar: calendar)
            } else if mutation.operation == .create, mutation.retryCount < 3 {
                try updateParticipantMutation(
                    id: mutation.id,
                    status: .prepared,
                    lastErrorCode: nil
                )
            } else {
                try finishParticipantAsDeleted(mutation, calendar: calendar)
            }
        } catch CalendarSharingError.localPersistenceFailed {
            throw CalendarSharingError.localPersistenceFailed
        } catch let error as CalendarSharingError {
            switch error {
            case .networkUnavailable, .serviceTemporarilyUnavailable, .noICloudAccount,
                 .iCloudStatusUnavailable:
                try updateParticipantMutation(
                    id: mutation.id,
                    status: .awaitingReconciliation,
                    lastErrorCode: String(describing: error)
                )
            default:
                try updateParticipantMutation(
                    id: mutation.id,
                    status: .failed,
                    lastErrorCode: String(describing: error)
                )
            }
        }
    }

    private func completeParticipantMutation(
        _ mutation: SharedEventPendingMutation,
        envelope: SharedEventEnvelope?,
        calendar: SharedCalendarDescriptor
    ) throws {
        var candidate = state
        guard let index = candidate.outbox.firstIndex(where: { $0.id == mutation.id }) else { return }
        candidate.outbox[index].status = .completed
        candidate.outbox[index].lastErrorCode = nil
        let hasNewer = candidate.outbox.contains {
            $0.calendarID == mutation.calendarID
                && $0.eventID == mutation.eventID
                && $0.sequence > mutation.sequence
                && !$0.status.isTerminal
        }
        if var envelope, !hasNewer {
            envelope.syncStatus = .synced
            envelope.pendingMutationID = nil
            candidate.envelopesByCalendarID[calendar.id, default: [:]][mutation.eventID] = envelope
        } else if let envelope, hasNewer {
            candidate.envelopesByCalendarID[calendar.id]?[mutation.eventID]?.recordChangeTag =
                envelope.recordChangeTag
            candidate.envelopesByCalendarID[calendar.id]?[mutation.eventID]?.modificationDate =
                envelope.modificationDate
            candidate.envelopesByCalendarID[calendar.id]?[mutation.eventID]?.lastMutationID =
                envelope.lastMutationID
        } else if mutation.operation == .delete, !hasNewer {
            var local = candidate.envelopesByCalendarID[calendar.id]?[mutation.eventID]
                ?? makeLocalEnvelope(
                    calendar: calendar,
                    snapshot: mutation.payload,
                    status: .synced,
                    mutationID: nil,
                    existing: nil
                )
            local.snapshot = tombstone(from: local.snapshot)
            local.syncStatus = .synced
            local.pendingMutationID = nil
            local.lastMutationID = mutation.id
            candidate.envelopesByCalendarID[calendar.id, default: [:]][mutation.eventID] = local
        }
        try commit(candidate)
    }

    private func supersedeParticipantMutation(
        _ mutation: SharedEventPendingMutation,
        remote: SharedEventEnvelope,
        calendar: SharedCalendarDescriptor
    ) throws {
        var candidate = state
        guard let index = candidate.outbox.firstIndex(where: { $0.id == mutation.id }) else { return }
        candidate.outbox[index].status = .superseded
        candidate.outbox[index].lastErrorCode = "server_has_other_mutation"
        let hasNewer = candidate.outbox.contains {
            $0.calendarID == mutation.calendarID
                && $0.eventID == mutation.eventID
                && $0.sequence > mutation.sequence
                && !$0.status.isTerminal
        }
        if !hasNewer {
            var materialized = remote
            materialized.syncStatus = .synced
            materialized.pendingMutationID = nil
            candidate.envelopesByCalendarID[calendar.id, default: [:]][mutation.eventID] = materialized
        }
        try commit(candidate)
    }

    private func finishParticipantAsDeleted(
        _ mutation: SharedEventPendingMutation,
        calendar: SharedCalendarDescriptor,
        remote: SharedEventEnvelope? = nil
    ) throws {
        var candidate = state
        markParticipantMutations(
            calendarID: mutation.calendarID,
            eventID: mutation.eventID,
            status: .deletedRemotely,
            in: &candidate
        )
        var local = remote ?? candidate.envelopesByCalendarID[calendar.id]?[mutation.eventID]
            ?? makeLocalEnvelope(
                calendar: calendar,
                snapshot: mutation.payload,
                status: .deletedRemotely,
                mutationID: nil,
                existing: nil
            )
        local.snapshot = tombstone(from: local.snapshot)
        local.syncStatus = .deletedRemotely
        local.pendingMutationID = nil
        candidate.envelopesByCalendarID[calendar.id, default: [:]][mutation.eventID] = local
        try commit(candidate)
    }

    private func updateParticipantMutation(
        id: UUID,
        status: SharedEventMutationStatus,
        lastErrorCode: String?
    ) throws {
        var candidate = state
        guard let index = candidate.outbox.firstIndex(where: { $0.id == id }) else { return }
        candidate.outbox[index].status = status
        candidate.outbox[index].lastErrorCode = lastErrorCode
        setEnvelopeStatus(for: candidate.outbox[index], in: &candidate)
        try commit(candidate)
    }

    private func reconcileOwnerUncertainMutations(
        calendar: OwnedSharedCalendarDescriptor,
        remote: [SharedEventEnvelope]
    ) async throws {
        let remoteByID = Dictionary(
            remote.map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        let mutations = try await eventUseCase.ownerSharedEventMutations(calendarID: calendar.id)
        for var mutation in mutations
        where mutation.status == .sending || mutation.status == .awaitingReconciliation {
            let server = remoteByID[mutation.eventID]
            if server?.isDeleted == true {
                mutation.status = .deletedRemotely
                mutation.lastErrorCode = "remote_tombstone"
                try await eventUseCase.saveOwnerSharedEventMutation(mutation)
            } else if server?.lastMutationID == mutation.id {
                mutation.status = .completed
                mutation.lastErrorCode = nil
                try await eventUseCase.saveOwnerSharedEventMutation(mutation)
            } else if server != nil {
                mutation.status = .superseded
                mutation.lastErrorCode = "server_has_other_mutation"
                try await eventUseCase.saveOwnerSharedEventMutation(mutation)
            } else if mutation.operation == .create, mutation.retryCount < 3 {
                mutation.status = .prepared
                mutation.lastErrorCode = nil
                try await eventUseCase.saveOwnerSharedEventMutation(mutation)
            } else {
                mutation.status = .deletedRemotely
                mutation.lastErrorCode = "remote_record_missing"
                try await eventUseCase.saveOwnerSharedEventMutation(mutation)
            }
        }
    }

    private func applyRemoteTombstonesToOwnerJournal(
        calendar: OwnedSharedCalendarDescriptor,
        remote: [SharedEventEnvelope]
    ) async throws {
        let tombstonedIDs = Set(remote.filter(\.isDeleted).map(\.id))
        guard !tombstonedIDs.isEmpty else { return }
        let mutations = try await eventUseCase.ownerSharedEventMutations(calendarID: calendar.id)
        for var mutation in mutations
        where tombstonedIDs.contains(mutation.eventID) && !mutation.status.isTerminal {
            mutation.status = .deletedRemotely
            mutation.lastErrorCode = "remote_tombstone"
            try await eventUseCase.saveOwnerSharedEventMutation(mutation)
        }
    }

    private func drainOwnerPreparedMutations(
        calendar: OwnedSharedCalendarDescriptor,
        remote: [SharedEventEnvelope]
    ) async throws {
        let remoteByID = Dictionary(
            remote.map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        var mutations = try await eventUseCase.ownerSharedEventMutations(calendarID: calendar.id)
        mutations.sort { $0.sequence < $1.sequence }
        for var mutation in mutations where mutation.status == .prepared {
            if remoteByID[mutation.eventID]?.isDeleted == true {
                mutation.status = .deletedRemotely
                mutation.lastErrorCode = "remote_tombstone"
                try await eventUseCase.saveOwnerSharedEventMutation(mutation)
                continue
            }
            if mutation.retryCount >= 3 {
                mutation.status = .failed
                mutation.lastErrorCode = "retry_limit"
                try await eventUseCase.saveOwnerSharedEventMutation(mutation)
                continue
            }
            mutation.status = .sending
            mutation.retryCount += 1
            mutation.lastErrorCode = nil
            try await eventUseCase.saveOwnerSharedEventMutation(mutation)
            do {
                switch mutation.operation {
                case .create, .update:
                    _ = try await client.upsertOwnedSharedEvent(
                        mutation.payload,
                        mutationID: mutation.id,
                        in: calendar
                    )
                case .delete:
                    _ = try await client.deleteOwnedSharedEvent(
                        eventID: mutation.eventID,
                        mutationID: mutation.id,
                        in: calendar
                    )
                }
                mutation.status = .completed
                mutation.lastErrorCode = nil
                try await eventUseCase.saveOwnerSharedEventMutation(mutation)
            } catch CalendarSharingError.localPersistenceFailed {
                // SwiftData still contains `sending`; the next worker run must fetch first.
                throw CalendarSharingError.localPersistenceFailed
            } catch CalendarSharingError.sharedEventDeleted {
                mutation.status = .deletedRemotely
                mutation.lastErrorCode = "remote_tombstone"
                try await eventUseCase.saveOwnerSharedEventMutation(mutation)
            } catch let error as SharedEventWriteError {
                guard case .confirmedNotSent(let cause) = error else { continue }
                mutation.status = .prepared
                mutation.lastErrorCode = "confirmed_not_sent:\(String(describing: cause))"
                try await eventUseCase.saveOwnerSharedEventMutation(mutation)
            } catch let error as CalendarSharingError {
                switch error {
                case .networkUnavailable, .serviceTemporarilyUnavailable, .noICloudAccount,
                     .iCloudStatusUnavailable:
                    mutation.status = .awaitingReconciliation
                default:
                    mutation.status = .failed
                }
                mutation.lastErrorCode = String(describing: error)
                try await eventUseCase.saveOwnerSharedEventMutation(mutation)
            } catch {
                mutation.status = .awaitingReconciliation
                mutation.lastErrorCode = "unexpected"
                try await eventUseCase.saveOwnerSharedEventMutation(mutation)
            }
        }
    }

    private func materializeOwnerRemote(
        calendar: OwnedSharedCalendarDescriptor,
        remote: [SharedEventEnvelope]
    ) async throws {
        let mutations = try await eventUseCase.ownerSharedEventMutations(calendarID: calendar.id)
        let activeEventIDs = Set(mutations.filter { !$0.status.isTerminal }.map(\.eventID))
        let remoteByID = Dictionary(
            remote.map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        let local = try await eventUseCase.sharedEventSnapshots(calendarID: calendar.id)
        let localByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })

        for envelope in remote where !activeEventIDs.contains(envelope.id) {
            if envelope.isDeleted {
                try await eventUseCase.removeSharedEventFromCloud(
                    id: envelope.id,
                    calendarID: calendar.id
                )
            } else if localByID[envelope.id] != envelope.snapshot {
                try await eventUseCase.mergeSharedEventFromCloud(
                    envelope.snapshot,
                    calendarID: calendar.id
                )
            }
        }
        for snapshot in local
        where remoteByID[snapshot.id] == nil && !activeEventIDs.contains(snapshot.id) {
            try await eventUseCase.removeSharedEventFromCloud(
                id: snapshot.id,
                calendarID: calendar.id
            )
        }
    }

    private func validateWritePermission(_ calendar: SharedCalendarDescriptor) throws {
        try ensurePersistenceAvailable()
        guard calendar.kind == .sharedReceived,
              calendar.eventEditingAllowed,
              calendar.participantPermission == .readWrite,
              calendar.collaborationProtocolVersion >= 1 else {
            throw CalendarSharingError.sharedEventPermissionRevoked
        }
    }

    private func markPermissionRevoked(
        calendarID: UUID,
        in candidate: inout SharedEventEditingPersistenceData
    ) {
        for index in candidate.outbox.indices
        where candidate.outbox[index].calendarID == calendarID
            && !candidate.outbox[index].status.isTerminal {
            candidate.outbox[index].status = .permissionRevoked
            setEnvelopeStatus(for: candidate.outbox[index], in: &candidate)
        }
    }

    private func restorePermissionRevokedMutations(
        calendarID: UUID,
        in candidate: inout SharedEventEditingPersistenceData
    ) {
        for index in candidate.outbox.indices
        where candidate.outbox[index].calendarID == calendarID
            && candidate.outbox[index].status == .permissionRevoked {
            candidate.outbox[index].status = .prepared
            candidate.outbox[index].lastErrorCode = nil
            setEnvelopeStatus(for: candidate.outbox[index], in: &candidate)
        }
    }

    private func markParticipantMutations(
        calendarID: UUID,
        eventID: UUID,
        status: SharedEventMutationStatus,
        in candidate: inout SharedEventEditingPersistenceData
    ) {
        for index in candidate.outbox.indices
        where candidate.outbox[index].calendarID == calendarID
            && candidate.outbox[index].eventID == eventID
            && !candidate.outbox[index].status.isTerminal {
            candidate.outbox[index].status = status
            candidate.outbox[index].lastErrorCode = status == .deletedRemotely
                ? "remote_tombstone"
                : candidate.outbox[index].lastErrorCode
        }
    }

    private func setEnvelopeStatus(
        for mutation: SharedEventPendingMutation,
        in candidate: inout SharedEventEditingPersistenceData
    ) {
        let visibleStatus: SharedEventSyncStatus
        if mutation.status == .prepared, mutation.lastErrorCode != nil {
            visibleStatus = .pending
        } else {
            visibleStatus = mutation.status.visibleSyncStatus
        }
        candidate.envelopesByCalendarID[mutation.calendarID]?[mutation.eventID]?.syncStatus =
            visibleStatus
        candidate.envelopesByCalendarID[mutation.calendarID]?[mutation.eventID]?.pendingMutationID =
            mutation.status.isTerminal ? nil : mutation.id
    }

    private func makeLocalEnvelope(
        calendar: SharedCalendarDescriptor,
        snapshot: SharedEventSnapshot,
        status: SharedEventSyncStatus,
        mutationID: UUID?,
        existing: SharedEventEnvelope?
    ) -> SharedEventEnvelope {
        SharedEventEnvelope(
            calendarID: calendar.id,
            zoneName: calendar.zoneName,
            ownerName: calendar.ownerName,
            recordName: existing?.recordName
                ?? "collaborative-event-\(snapshot.id.uuidString.lowercased())",
            snapshot: snapshot,
            recordChangeTag: existing?.recordChangeTag,
            modificationDate: existing?.modificationDate,
            creatorIdentifierHash: existing?.creatorIdentifierHash,
            lastModifierIdentifierHash: existing?.lastModifierIdentifierHash,
            syncStatus: status,
            pendingMutationID: mutationID,
            lastMutationID: existing?.lastMutationID
        )
    }

    private func tombstone(from snapshot: SharedEventSnapshot) -> SharedEventSnapshot {
        let now = Date()
        return SharedEventSnapshot(
            id: snapshot.id,
            title: snapshot.title,
            startDate: snapshot.startDate,
            endDate: snapshot.endDate,
            isAllDay: snapshot.isAllDay,
            updatedAt: now,
            isDeleted: true,
            deletedAt: now
        )
    }

    private func requiresAutomaticRecovery(_ status: SharedEventMutationStatus) -> Bool {
        switch status {
        case .prepared, .sending, .awaitingReconciliation, .permissionRevoked:
            true
        case .completed, .superseded, .failed, .deletedRemotely:
            false
        }
    }

    private func ensurePersistenceAvailable() throws {
        if let startupPersistenceError { throw startupPersistenceError }
    }

    private func commit(_ candidate: SharedEventEditingPersistenceData) throws {
        do {
            try persistence.save(candidate)
            state = candidate
        } catch {
            throw CalendarSharingError.localPersistenceFailed
        }
    }
}
