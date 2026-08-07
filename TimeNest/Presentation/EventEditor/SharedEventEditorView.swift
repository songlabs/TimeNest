import SwiftUI

struct SharedEventEditorRoute: Identifiable {
    let id = UUID()
    let calendarID: UUID
    let eventID: UUID
    let initialDate: Date
    let snapshot: SharedEventSnapshot?

    static func create(calendarID: UUID, date: Date) -> SharedEventEditorRoute {
        SharedEventEditorRoute(
            calendarID: calendarID,
            eventID: UUID(),
            initialDate: date,
            snapshot: nil
        )
    }

    static func edit(
        calendarID: UUID,
        snapshot: SharedEventSnapshot
    ) -> SharedEventEditorRoute {
        SharedEventEditorRoute(
            calendarID: calendarID,
            eventID: snapshot.id,
            initialDate: snapshot.startDate,
            snapshot: snapshot
        )
    }
}

struct SharedReceivedDayDetailRoute: Identifiable {
    let id = UUID()
    let calendarID: UUID
    let cell: CalendarDayCell
}

struct SharedEventSyncStatusLabel: View {
    @EnvironmentObject private var localization: LocalizationManager
    let status: SharedEventSyncStatus

    var body: some View {
        Label(localization.localized(localizedKey), systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(color)
            .accessibilityIdentifier("sharedEvent.status.\(status.rawValue)")
    }

    private var localizedKey: LocalizedString {
        switch status {
        case .saving: .calendarSharingSaving
        case .pending: .calendarSharingWaitingForSync
        case .synced: .calendarSharingSynced
        case .failed: .calendarSharingEventSyncFailed
        case .permissionRevoked: .calendarSharingEventPermissionRevoked
        case .deletedRemotely: .calendarSharingEventDeleted
        }
    }

    private var systemImage: String {
        switch status {
        case .saving: "arrow.triangle.2.circlepath"
        case .pending: "clock"
        case .synced: "checkmark.icloud"
        case .failed: "exclamationmark.icloud"
        case .permissionRevoked: "lock"
        case .deletedRemotely: "trash"
        }
    }

    private var color: Color {
        switch status {
        case .failed, .permissionRevoked, .deletedRemotely: .red
        case .saving, .pending: .orange
        case .synced: .secondary
        }
    }
}

@MainActor
struct SharedEventEditorView: View {
    @EnvironmentObject private var sharingStore: CalendarSharingStore
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let route: SharedEventEditorRoute
    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var isWorking = false
    @State private var syncStatus: SharedEventSyncStatus?
    @State private var errorMessage: String?
    @State private var confirmingDelete = false

    init(route: SharedEventEditorRoute) {
        self.route = route
        let startDate = route.snapshot?.startDate ?? route.initialDate
        let endDate = route.snapshot?.endDate
            ?? CalendarEvent.defaultEndDate(for: startDate, isAllDay: false)
        _title = State(initialValue: route.snapshot?.title ?? "")
        _startDate = State(initialValue: startDate)
        _endDate = State(initialValue: endDate)
        _isAllDay = State(initialValue: route.snapshot?.isAllDay ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(localization.localized(.editorTitle), text: $title)
                        .disabled(isWorking)
                        .accessibilityIdentifier("sharedEvent.title")
                }

                Section {
                    Toggle(localization.localized(.editorAllDay), isOn: $isAllDay)
                        .disabled(isWorking)
                    DatePicker(
                        localization.localized(.editorStart),
                        selection: $startDate,
                        displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                    .disabled(isWorking)
                    DatePicker(
                        localization.localized(.editorEnd),
                        selection: $endDate,
                        displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                    .disabled(isWorking)
                }

                Section {
                    if let syncStatus {
                        SharedEventSyncStatusLabel(status: syncStatus)
                    }
                    Text(localization.localized(.calendarSharingLastWriteWinsNote))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if route.snapshot != nil {
                    Section {
                        Button(
                            localization.localized(.calendarSharingDeleteAction),
                            role: .destructive
                        ) {
                            confirmingDelete = true
                        }
                        .disabled(isWorking)
                        .accessibilityIdentifier("sharedEvent.delete")
                    }
                }
            }
            .navigationTitle(localization.localized(
                route.snapshot == nil
                    ? .calendarSharingSharedEventNewTitle
                    : .calendarSharingSharedEventEditTitle
            ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.localized(.cancel)) { dismiss() }
                        .disabled(isWorking)
                        .accessibilityIdentifier("sharedEvent.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.localized(.calendarSharingSaveAction)) {
                        Task { await save() }
                    }
                    .disabled(!canSave || isWorking)
                    .accessibilityIdentifier("sharedEvent.save")
                }
            }
            .confirmationDialog(
                localization.localized(.calendarSharingDeleteAction),
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button(
                    localization.localized(.calendarSharingDeleteAction),
                    role: .destructive
                ) {
                    Task { await delete() }
                }
                .accessibilityIdentifier("sharedEvent.confirmDelete")
                Button(localization.localized(.cancel), role: .cancel) {}
            }
            .alert(
                localization.localized(.calendarSharingErrorTitle),
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button(localization.localized(.ok)) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .accessibilityIdentifier("sharedEvent.editor")
        .interactiveDismissDisabled(isWorking)
        .onAppear {
            syncStatus = sharingStore.sharedEventSyncStatus(
                calendarID: route.calendarID,
                eventID: route.eventID
            )
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && endDate > startDate
    }

    private func save() async {
        guard canSave else {
            errorMessage = EventUseCaseError.invalidDateRange.localizedDescription
            return
        }
        isWorking = true
        syncStatus = .saving
        defer { isWorking = false }
        let snapshot = SharedEventSnapshot(
            id: route.eventID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            updatedAt: Date()
        )
        do {
            if route.snapshot == nil {
                syncStatus = try await sharingStore.createReceivedSharedEvent(
                    snapshot,
                    calendarID: route.calendarID
                )
            } else {
                syncStatus = try await sharingStore.updateReceivedSharedEvent(
                    snapshot,
                    calendarID: route.calendarID
                )
            }
            if syncStatus == .synced { dismiss() }
        } catch {
            syncStatus = status(for: error)
            errorMessage = error.localizedDescription
        }
    }

    private func delete() async {
        isWorking = true
        syncStatus = .saving
        defer { isWorking = false }
        do {
            syncStatus = try await sharingStore.deleteReceivedSharedEvent(
                eventID: route.eventID,
                calendarID: route.calendarID
            )
            if syncStatus == .synced || syncStatus == .pending { dismiss() }
        } catch {
            syncStatus = status(for: error)
            errorMessage = error.localizedDescription
        }
    }

    private func status(for error: Error) -> SharedEventSyncStatus {
        switch error as? CalendarSharingError {
        case .sharedEventDeleted: .deletedRemotely
        case .sharedEventPermissionRevoked, .permissionDenied: .permissionRevoked
        default: .failed
        }
    }
}

@MainActor
struct SharedReceivedDayDetailView: View {
    @EnvironmentObject private var sharingStore: CalendarSharingStore
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    let route: SharedReceivedDayDetailRoute
    @State private var editorRoute: SharedEventEditorRoute?
    @State private var deleteCandidate: SharedEventSnapshot?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(currentEvents) { event in
                    eventRow(event)
                }
                if canCreateEvent {
                    Button {
                        editorRoute = .create(
                            calendarID: route.calendarID,
                            date: route.cell.date.toDate()
                        )
                    } label: {
                        Label(
                            localization.localized(.dayDetailAddEvent),
                            systemImage: "plus"
                        )
                    }
                }
            }
            .navigationTitle(localization.formattedDateShort(for: route.cell.date.toDate()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.localized(.done)) { dismiss() }
                        .accessibilityIdentifier("sharedEvent.dayDetail.done")
                }
            }
            .sheet(item: $editorRoute) { route in
                SharedEventEditorView(route: route)
                    .environmentObject(sharingStore)
                    .environmentObject(localization)
            }
            .confirmationDialog(
                localization.localized(.calendarSharingDeleteAction),
                isPresented: Binding(
                    get: { deleteCandidate != nil },
                    set: { if !$0 { deleteCandidate = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(
                    localization.localized(.calendarSharingDeleteAction),
                    role: .destructive
                ) {
                    guard let candidate = deleteCandidate else { return }
                    deleteCandidate = nil
                    Task { await delete(candidate) }
                }
                .accessibilityIdentifier("sharedEvent.row.confirmDelete")
                Button(localization.localized(.cancel), role: .cancel) {}
            }
            .alert(
                localization.localized(.calendarSharingErrorTitle),
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button(localization.localized(.ok)) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .accessibilityIdentifier("sharedEvent.dayDetail")
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func eventRow(_ event: EventOccurrence) -> some View {
        let snapshot = sharingStore.sharedEventSnapshot(
            calendarID: route.calendarID,
            eventID: event.eventID
        )
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(timeText(event))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let status = sharingStore.sharedEventSyncStatus(
                    calendarID: route.calendarID,
                    eventID: event.eventID
                ) {
                    SharedEventSyncStatusLabel(status: status)
                } else {
                    Label(
                        localization.localized(.calendarSharingReadOnly),
                        systemImage: "eye"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let snapshot, canEditEvent {
                Button {
                    editorRoute = .edit(calendarID: route.calendarID, snapshot: snapshot)
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("sharedEvent.row.edit")
                Button(role: .destructive) {
                    deleteCandidate = snapshot
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("sharedEvent.row.delete")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard let snapshot, canEditEvent else { return }
            editorRoute = .edit(calendarID: route.calendarID, snapshot: snapshot)
        }
    }

    private var canCreateEvent: Bool {
        sharingStore.calendar(id: route.calendarID)?.canCreateSharedEvent == true
    }

    private var currentEvents: [EventOccurrence] {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.startOfDay(for: route.cell.date.toDate())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return route.cell.events
        }
        return sharingStore.occurrences(
            for: route.calendarID,
            in: DateInterval(start: start, end: end)
        )
    }

    private var canEditEvent: Bool {
        sharingStore.calendar(id: route.calendarID)?.canEditSharedEvent == true
    }

    private func timeText(_ event: EventOccurrence) -> String {
        if event.isAllDay { return localization.localized(.editorAllDay) }
        return String(
            format: localization.localized(.calendarSharingDateRangeFormat),
            locale: localization.currentLocale,
            localization.formattedUserVisibleDateTime(for: event.startDate),
            localization.formattedUserVisibleDateTime(for: event.endDate)
        )
    }

    private func delete(_ snapshot: SharedEventSnapshot) async {
        do {
            _ = try await sharingStore.deleteReceivedSharedEvent(
                eventID: snapshot.id,
                calendarID: route.calendarID
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
