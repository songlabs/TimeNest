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
    @Published private(set) var receivedCalendars: [SharedCalendarDescriptor]
    @Published private(set) var ownedCalendar: OwnedSharedCalendarDescriptor?
    @Published private(set) var ownedParticipants: [SharedCalendarParticipantSnapshot] = []
    @Published private(set) var participantRefreshFailed = false
    @Published private(set) var syncStatus: CalendarSharingSyncStatus = .idle
    @Published private(set) var lastError: CalendarSharingError?
    @Published private(set) var revision: Int = 0

    private let client: any CalendarSharingClientProtocol
    private let eventUseCase: EventUseCase
    private let cache: CalendarSharingCache
    private let selectionPersistence: CalendarSelectionPersistence
    private var eventsByCalendarID: [String: [SharedEventSnapshot]]
    private var shiftsByCalendarID: [String: [SharedShiftSnapshot]]
    private var workRecordsByCalendarID: [String: [SharedWorkRecordSnapshot]]
    private var refreshIsInProgress = false
    private var participantRefreshIsInProgress = false
    private var participantManagementIsActive = false
    private var shareCreationIsInProgress = false
    private var refreshCompletionWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        client: any CalendarSharingClientProtocol,
        eventUseCase: EventUseCase,
        cache: CalendarSharingCache = CalendarSharingCache(),
        selectionPersistence: CalendarSelectionPersistence = CalendarSelectionPersistence()
    ) {
        self.client = client
        self.eventUseCase = eventUseCase
        self.cache = cache
        self.selectionPersistence = selectionPersistence

        let cached = cache.load()
        receivedCalendars = cached.receivedCalendars
        eventsByCalendarID = cached.eventsByCalendarID
        shiftsByCalendarID = cached.shiftsByCalendarID
        workRecordsByCalendarID = cached.workRecordsByCalendarID
        ownedCalendar = cached.ownedCalendar
        selection = selectionPersistence.load()
    }

    var accessPolicy: CalendarAccessPolicy {
        CalendarAccessPolicy(selection: selection)
    }

    var selectedSharedCalendar: SharedCalendarDescriptor? {
        guard let id = selection.sharedCalendarID else { return nil }
        return receivedCalendars.first { $0.id == id }
    }

    var selectedCalendarDisplayName: String {
        if let selectedSharedCalendar {
            return selectedSharedCalendar.resolvedCalendarName(
                fallback: LocalizationManager.shared.localized(.calendarSharingUnknownCalendar)
            )
        }
        return LocalizationManager.shared.localized(.calendarSharingMyCalendar)
    }

    func select(_ newSelection: CalendarSelection) {
        let validIDs = Set(receivedCalendars.map(\.id))
        let resolved = CalendarSelectionPersistence.resolved(
            newSelection,
            validSharedCalendarIDs: validIDs
        )
        guard selection != resolved else { return }
        selection = resolved
        selectionPersistence.save(resolved)
        revision &+= 1
    }

    func occurrences(for calendarID: String, in range: DateInterval) -> [EventOccurrence] {
        let content = receivedCalendars.first(where: { $0.id == calendarID })?.sharedContent
            ?? .legacyDefault
        var occurrences: [EventOccurrence] = []
        if content.sharesEvents {
            occurrences.append(contentsOf: SharedEventMapper.occurrences(
                from: eventsByCalendarID[calendarID] ?? [],
                in: range
            ))
        }
        if content.sharesShifts {
            occurrences.append(contentsOf: SharedShiftMapper.occurrences(
                from: shiftsByCalendarID[calendarID] ?? [],
                in: range
            ))
        }
        if content.sharesWorkRecords {
            occurrences.append(contentsOf: SharedWorkRecordMapper.occurrences(
                from: workRecordsByCalendarID[calendarID] ?? [],
                in: range
            ))
        }
        return occurrences.sorted {
            if $0.occurrenceDate != $1.occurrenceDate {
                return $0.occurrenceDate.id < $1.occurrenceDate.id
            }
            return $0.startDate < $1.startDate
        }
    }

    func start() async {
        CalendarSharingInvitationRouter.shared.register(store: self)
        await synchronizeAll()
    }

    func setParticipantManagementActive(_ isActive: Bool) {
        participantManagementIsActive = isActive
    }

    func synchronizeOnAppActivation() async {
        if participantManagementIsActive {
            await refreshOwnedParticipants()
        } else {
            await synchronizeAll()
        }
    }

    func synchronizeAll() async {
        guard !refreshIsInProgress,
              !participantRefreshIsInProgress,
              !shareCreationIsInProgress else {
            CalendarSharingDiagnostics.debug(
                operation: "refresh",
                stage: "skipped_busy",
                database: "private+shared",
                details: "selectedSource=\(selectionKind)"
            )
            return
        }
        refreshIsInProgress = true
        defer { finishRefresh() }
        syncStatus = .syncing
        lastError = nil
        CalendarSharingDiagnostics.debug(
            operation: "refresh",
            stage: "started",
            database: "private+shared",
            details: "selectedSource=\(selectionKind)"
        )

        do {
            let ownerState = try await client.ownedCalendarState()
            if let ownerState {
                try await synchronizeOwnedContent(ownerState.calendar.sharedContent)
            }
            let refreshedOwnedState = try await client.ownedCalendarState()

            let payloads = try await client.fetchReceivedCalendars()
            let refreshedCalendars = payloads.map(\.calendar)
            let refreshedEvents = Dictionary(
                uniqueKeysWithValues: payloads.map { ($0.calendar.id, $0.events) }
            )
            let refreshedShifts = Dictionary(
                uniqueKeysWithValues: payloads.map { ($0.calendar.id, $0.shifts) }
            )
            let refreshedWorkRecords = Dictionary(
                uniqueKeysWithValues: payloads.map { ($0.calendar.id, $0.workRecords) }
            )

            ownedCalendar = refreshedOwnedState?.calendar
            ownedParticipants = refreshedOwnedState?.participants ?? []
            participantRefreshFailed = false
            receivedCalendars = refreshedCalendars
            eventsByCalendarID = refreshedEvents
            shiftsByCalendarID = refreshedShifts
            workRecordsByCalendarID = refreshedWorkRecords
            let didFallback = validateSelectionAfterSuccessfulRefresh()
            lastError = didFallback ? .shareUnavailable : nil
            persistCache()
            syncStatus = .synced
            revision &+= 1
            CalendarSharingDiagnostics.debug(
                operation: "refresh",
                stage: "completed",
                database: "private+shared",
                details: "receivedCount=\(receivedCalendars.count) selectedSource=\(selectionKind) fallback=\(didFallback)"
            )
        } catch is CancellationError {
            syncStatus = .idle
            CalendarSharingDiagnostics.debug(
                operation: "refresh",
                stage: "cancelled",
                database: "private+shared",
                details: "fallback=false"
            )
        } catch let error as CalendarSharingError {
            lastError = error
            syncStatus = .failed
        } catch {
            lastError = CalendarSharingErrorMapper.map(error)
            syncStatus = .failed
        }
    }

    func synchronizeOwnedEventsIfNeeded() async {
        guard !refreshIsInProgress,
              !participantRefreshIsInProgress,
              !shareCreationIsInProgress else { return }
        do {
            guard let state = try await client.ownedCalendarState() else { return }
            try await synchronizeOwnedContent(state.calendar.sharedContent)
            let refreshedState = try await client.ownedCalendarState()
            ownedCalendar = refreshedState?.calendar
            ownedParticipants = refreshedState?.participants ?? []
            participantRefreshFailed = false
            lastError = nil
            persistCache()
        } catch is CancellationError {
            return
        } catch let error as CalendarSharingError {
            lastError = error
            syncStatus = .failed
        } catch {
            lastError = CalendarSharingErrorMapper.map(error)
            syncStatus = .failed
        }
    }

    func refreshOwnedParticipants() async {
        guard !participantRefreshIsInProgress,
              !refreshIsInProgress,
              !shareCreationIsInProgress else {
            CalendarSharingDiagnostics.debug(
                operation: "refreshOwnedParticipants",
                stage: "skipped_busy",
                database: "private"
            )
            return
        }
        participantRefreshIsInProgress = true
        defer { finishParticipantRefresh() }

        do {
            let state = try await client.ownedCalendarState()
            ownedCalendar = state?.calendar
            ownedParticipants = state?.participants ?? []
            participantRefreshFailed = false
            persistCache()
            revision &+= 1
        } catch is CancellationError {
            return
        } catch {
            participantRefreshFailed = true
            CalendarSharingDiagnostics.error(
                operation: "refreshOwnedParticipants",
                stage: "failed",
                database: "private",
                error: error,
                details: "preservedCount=\(ownedParticipants.count)"
            )
        }
    }

    func createShare(
        displayName: String? = nil,
        calendarName: String,
        content: SharedContentConfiguration = .newShareDefault
    ) async throws -> URL {
        guard content.hasSelectedContent else {
            throw CalendarSharingError.contentSelectionRequired
        }
        var content = content
        content.schemaVersion = SharedContentConfiguration.currentSchemaVersion
        await waitForRefreshToFinish()
        guard !shareCreationIsInProgress else {
            throw CalendarSharingError.shareCreationFailed
        }
        shareCreationIsInProgress = true
        defer { shareCreationIsInProgress = false }

        let trimmedDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCalendarName = calendarName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCalendarName.isEmpty else {
            throw CalendarSharingError.shareCreationFailed
        }
        let internalDisplayName = trimmedDisplayName.flatMap { $0.isEmpty ? nil : $0 }
            ?? trimmedCalendarName
        let selectedSourceBefore = selectionKind
        lastError = nil
        CalendarSharingDiagnostics.debug(
            operation: "startSharing",
            stage: "started",
            database: "private",
            details: "selectedSourceBefore=\(selectedSourceBefore)"
        )

        do {
            let snapshots = try await localSharedContentSnapshots()
            let result = try await client.createShare(
                displayName: internalDisplayName,
                calendarName: trimmedCalendarName,
                content: content,
                events: snapshots.events,
                shifts: snapshots.shifts,
                workRecords: snapshots.workRecords
            )
            selection = .mine
            selectionPersistence.save(.mine)
            ownedCalendar = result.state.calendar
            ownedParticipants = result.state.participants
            participantRefreshFailed = false
            lastError = nil
            syncStatus = .synced
            persistCache()
            revision &+= 1
            CalendarSharingDiagnostics.debug(
                operation: "startSharing",
                stage: "completed",
                database: "private",
                details: "selectedSourceBefore=\(selectedSourceBefore) selectedSourceAfter=\(selectionKind) fallback=false shareSaved=true"
            )
            guard let invitationURL = result.invitationURL else {
                throw CalendarSharingError.invitationURLUnavailable
            }
            return invitationURL
        } catch is CancellationError {
            CalendarSharingDiagnostics.debug(
                operation: "startSharing",
                stage: "cancelled",
                database: "private",
                details: "fallback=false"
            )
            throw CancellationError()
        } catch let error as CalendarSharingError {
            lastError = error
            syncStatus = .failed
            throw error
        } catch {
            let mapped = CalendarSharingErrorMapper.map(error, context: .creatingShare)
            lastError = mapped
            syncStatus = .failed
            throw mapped
        }
    }

    func updateOwnedSharing(content: SharedContentConfiguration) async throws {
        guard content.hasSelectedContent else {
            throw CalendarSharingError.contentSelectionRequired
        }
        var content = content
        content.schemaVersion = SharedContentConfiguration.currentSchemaVersion
        await waitForRefreshToFinish()
        guard !shareCreationIsInProgress else {
            throw CalendarSharingError.syncFailed
        }
        shareCreationIsInProgress = true
        defer { shareCreationIsInProgress = false }
        lastError = nil
        syncStatus = .syncing

        do {
            let snapshots = try await localSharedContentSnapshots()
            let state = try await client.updateOwnedSharing(
                content: content,
                events: snapshots.events,
                shifts: snapshots.shifts,
                workRecords: snapshots.workRecords
            )
            ownedCalendar = state.calendar
            ownedParticipants = state.participants
            participantRefreshFailed = false
            syncStatus = .synced
            persistCache()
            revision &+= 1
        } catch is CancellationError {
            syncStatus = .idle
            throw CancellationError()
        } catch let error as CalendarSharingError {
            lastError = error
            syncStatus = .failed
            throw error
        } catch {
            let mapped = CalendarSharingErrorMapper.map(error)
            lastError = mapped
            syncStatus = .failed
            throw mapped
        }
    }

    func createOwnedInvitation() async throws -> URL {
        await waitForRefreshToFinish()
        guard ownedCalendar != nil else {
            throw CalendarSharingError.shareUnavailable
        }
        guard !shareCreationIsInProgress else {
            throw CalendarSharingError.invitationCreationFailed
        }
        shareCreationIsInProgress = true
        defer { shareCreationIsInProgress = false }
        syncStatus = .syncing
        lastError = nil

        do {
            let result = try await client.createOwnedInvitation()
            ownedCalendar = result.state.calendar
            ownedParticipants = result.state.participants
            participantRefreshFailed = false
            persistCache()
            syncStatus = .synced
            revision &+= 1
            guard let invitationURL = result.invitationURL else {
                throw CalendarSharingError.invitationURLUnavailable
            }
            return invitationURL
        } catch is CancellationError {
            syncStatus = .idle
            throw CancellationError()
        } catch let error as CalendarSharingError {
            lastError = error
            syncStatus = .failed
            throw error
        } catch {
            let mapped = CalendarSharingErrorMapper.map(error, context: .creatingInvitation)
            lastError = mapped
            syncStatus = .failed
            throw mapped
        }
    }

    func stopOwnedSharing() async throws {
        try await client.stopOwnedSharing(plan: OwnedSharingStopPlan())
        ownedCalendar = nil
        ownedParticipants = []
        participantRefreshFailed = false
        persistCache()
    }

    func leave(_ calendar: SharedCalendarDescriptor) async throws {
        try await client.leaveSharedCalendar(calendar)
        receivedCalendars.removeAll { $0.id == calendar.id }
        eventsByCalendarID.removeValue(forKey: calendar.id)
        shiftsByCalendarID.removeValue(forKey: calendar.id)
        workRecordsByCalendarID.removeValue(forKey: calendar.id)
        if selection == .shared(calendar.id) {
            selection = .mine
            selectionPersistence.save(.mine)
        }
        persistCache()
        revision &+= 1
    }

    func accept(metadata: CKShare.Metadata) async {
        await waitForRefreshToFinish()
        syncStatus = .syncing
        lastError = nil
        do {
            let acceptedCalendarID = try await client.accept(metadata: metadata)
            let payloads = try await client.fetchReceivedCalendars()
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
            if receivedCalendars.contains(where: { $0.id == acceptedCalendarID }) {
                selection = .shared(acceptedCalendarID)
                selectionPersistence.save(selection)
            } else {
                validateSelectionAfterSuccessfulRefresh()
            }
            persistCache()
            syncStatus = .synced
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

    private struct LocalSharedContentSnapshots {
        let events: [SharedEventSnapshot]
        let shifts: [SharedShiftSnapshot]
        let workRecords: [SharedWorkRecordSnapshot]
    }

    private func synchronizeOwnedContent(_ content: SharedContentConfiguration) async throws {
        let snapshots = try await localSharedContentSnapshots()
        try await client.synchronizeOwnedContent(
            content: content,
            events: snapshots.events,
            shifts: snapshots.shifts,
            workRecords: snapshots.workRecords
        )
    }

    private func localSharedContentSnapshots() async throws -> LocalSharedContentSnapshots {
        let allEvents = try await eventUseCase.events(
            in: DateInterval(start: .distantPast, end: .distantFuture)
        )
        let snapshots = LocalSharedContentSnapshots(
            events: allEvents.compactMap(SharedEventMapper.snapshot(from:)),
            shifts: allEvents.compactMap { SharedShiftMapper.snapshot(from: $0) },
            workRecords: SharedWorkRecordMapper.snapshots(from: allEvents)
        )
#if DEBUG
        for (sourceIndex, event) in allEvents.enumerated() {
            let mappedAsEvent = SharedEventMapper.snapshot(from: event) != nil
            let mappedAsShift = SharedShiftMapper.snapshot(from: event) != nil
            let isWorkRecordCandidate = SharedWorkRecordMapper.isCandidate(event)
            let eventExclusion = SharedEventMapper.exclusionReason(for: event)?.rawValue ?? "none"
            CalendarSharingDiagnostics.debug(
                operation: "collectSharedContent",
                stage: "classify_source_event",
                database: "local",
                details: "sourceIndex=\(sourceIndex) hasShiftTemplateID=\(event.shiftTemplateID != nil) hasWorkInfo=\(event.workInfo != nil) hasWorkClockKind=\(event.workClockKind != nil) mappedAsEvent=\(mappedAsEvent) mappedAsShift=\(mappedAsShift) isWorkRecordCandidate=\(isWorkRecordCandidate) eventExclusion=\(eventExclusion)"
            )
        }
#endif
        CalendarSharingDiagnostics.debug(
            operation: "collectSharedContent",
            stage: "completed",
            database: "local",
            details: "sourceEvents=\(allEvents.count) events=\(snapshots.events.count) shifts=\(snapshots.shifts.count) workRecords=\(snapshots.workRecords.count)"
        )
        return snapshots
    }

    @discardableResult
    private func validateSelectionAfterSuccessfulRefresh() -> Bool {
        let resolved = CalendarSelectionPersistence.resolved(
            selection,
            validSharedCalendarIDs: Set(receivedCalendars.map(\.id))
        )
        if resolved != selection {
            selection = resolved
            selectionPersistence.save(resolved)
            CalendarSharingDiagnostics.debug(
                operation: "validateSelection",
                stage: "fallback_to_my_calendar",
                database: "shared",
                details: "selectedSourceBefore=received selectedSourceAfter=mine fallback=true"
            )
            return true
        }
        return false
    }

    private func waitForRefreshToFinish() async {
        while refreshIsInProgress || participantRefreshIsInProgress {
            await withCheckedContinuation { continuation in
                refreshCompletionWaiters.append(continuation)
            }
        }
    }

    private func finishRefresh() {
        refreshIsInProgress = false
        resumeRefreshCompletionWaiters()
    }

    private func finishParticipantRefresh() {
        participantRefreshIsInProgress = false
        resumeRefreshCompletionWaiters()
    }

    private func resumeRefreshCompletionWaiters() {
        let waiters = refreshCompletionWaiters
        refreshCompletionWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private var selectionKind: String {
        selection.sharedCalendarID == nil ? "mine" : "received"
    }

    private func persistCache() {
        let data = CalendarSharingCacheData(
            receivedCalendars: receivedCalendars,
            eventsByCalendarID: eventsByCalendarID,
            shiftsByCalendarID: shiftsByCalendarID,
            workRecordsByCalendarID: workRecordsByCalendarID,
            ownedCalendar: ownedCalendar
        )
        try? cache.save(data)
    }
}
