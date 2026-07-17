import SwiftUI
import UIKit

struct CalendarIdentityAvatarView: View {
    let initial: String?
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(ShiftCalendarColors.primaryBlue.opacity(0.16))
            if let initial, !initial.isEmpty {
                Text(initial)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(ShiftCalendarColors.primaryBlue)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: size * 0.7))
                    .foregroundStyle(ShiftCalendarColors.primaryBlue)
            }
        }
        .frame(width: size, height: size)
    }
}

struct CalendarSelectionRowActions: Equatable {
    let showsEdit: Bool
    let showsDelete: Bool
    let showsReceivedDetails: Bool
    let actionsAreEnabled: Bool

    init(calendar: TimeNestCalendar) {
        showsEdit = calendar.kind == .sharedOwned
        showsDelete = calendar.kind == .sharedOwned
        showsReceivedDetails = calendar.kind == .sharedReceived
        actionsAreEnabled = !calendar.stopPhase.isStopping
    }
}

enum CalendarSharingFormValidation {
    static func hasRequiredName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum CalendarSelectionAccessibilityLabels {
    static let edit: LocalizedString = .calendarSharingEditCalendar
    static let delete: LocalizedString = .calendarSharingDeleteCalendar
    static let receivedDetails: LocalizedString = .calendarSharingReceivedDetails
}

enum CalendarSelectionRowInteraction: Equatable {
    case select
    case edit
    case delete
    case receivedDetails
}

enum CalendarSelectionRoute: Identifiable, Equatable {
    case edit(UUID)
    case receivedDetails(UUID)

    var id: String {
        switch self {
        case .edit(let calendarID): "edit-\(calendarID.uuidString)"
        case .receivedDetails(let calendarID): "received-\(calendarID.uuidString)"
        }
    }

    var calendarID: UUID {
        switch self {
        case .edit(let calendarID), .receivedDetails(let calendarID): calendarID
        }
    }
}

struct CalendarSelectionActionState: Equatable {
    var isCreating = false
    var route: CalendarSelectionRoute?
    private(set) var deletionCandidateID: UUID?
    private(set) var deletionInProgressID: UUID?

    mutating func requestCreate() {
        isCreating = true
    }

    /// Returns a calendar ID only for a row-selection interaction. Accessory actions route
    /// independently so they cannot also switch the displayed calendar.
    mutating func handle(
        _ interaction: CalendarSelectionRowInteraction,
        for calendar: TimeNestCalendar
    ) -> UUID? {
        let actions = CalendarSelectionRowActions(calendar: calendar)
        switch interaction {
        case .select:
            return actions.actionsAreEnabled ? calendar.id : nil
        case .edit:
            guard actions.showsEdit, actions.actionsAreEnabled else { return nil }
            route = .edit(calendar.id)
        case .delete:
            guard actions.showsDelete,
                  actions.actionsAreEnabled,
                  deletionInProgressID == nil else { return nil }
            deletionCandidateID = calendar.id
        case .receivedDetails:
            guard actions.showsReceivedDetails else { return nil }
            route = .receivedDetails(calendar.id)
        }
        return nil
    }

    mutating func cancelDeletion() {
        deletionCandidateID = nil
    }

    mutating func beginConfirmedDeletion() -> UUID? {
        guard deletionInProgressID == nil, let calendarID = deletionCandidateID else {
            return nil
        }
        deletionCandidateID = nil
        deletionInProgressID = calendarID
        return calendarID
    }

    mutating func finishDeletion(calendarID: UUID) {
        guard deletionInProgressID == calendarID else { return }
        deletionInProgressID = nil
    }
}

@MainActor
private enum CalendarSharingPresentationLayout {
    static let heightRatio: CGFloat = 0.60
    static let minimumHeight: CGFloat = 380
    static let maximumHeight: CGFloat = 620
    static let receivedDetailsHeight: CGFloat = 380

    static func sharedPopupHeight() -> CGFloat {
        let availableHeight = availableDisplayHeight()
        guard availableHeight > 0 else { return minimumHeight }

        let preferredHeight = availableHeight * heightRatio
        let lowerBound = min(minimumHeight, availableHeight)
        let upperBound = min(maximumHeight, availableHeight)
        return min(max(preferredHeight, lowerBound), upperBound)
    }

    private static func availableDisplayHeight() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive })
            ?? scenes.first else {
            return 0
        }

        let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first
        let containerHeight = window?.bounds.height ?? scene.screen.bounds.height
        let safeAreaInsets = window?.safeAreaInsets ?? .zero
        return max(containerHeight - safeAreaInsets.top - safeAreaInsets.bottom, 0)
    }
}

private struct CalendarSharingPresentationModifier: ViewModifier {
    let height: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(minWidth: 320)
            .frame(height: height)
            .presentationDetents([.height(height)])
            .presentationContentInteraction(.scrolls)
    }
}

@MainActor
private extension View {
    func calendarSharingPresentation() -> some View {
        modifier(CalendarSharingPresentationModifier(
            height: CalendarSharingPresentationLayout.sharedPopupHeight()
        ))
    }

    func calendarSharingPresentation(height: CGFloat) -> some View {
        modifier(CalendarSharingPresentationModifier(height: height))
    }
}

private enum CalendarSelectionLayout {
    static let actionSpacing: CGFloat = 8
    static let actionButtonHeight: CGFloat = 44
    static let actionButtonHorizontalPadding: CGFloat = 2
}

@MainActor
struct CalendarSelectionView: View {
    @EnvironmentObject private var sharingStore: CalendarSharingStore
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var actionState = CalendarSelectionActionState()
    @State private var errorMessage: String?

    private var owned: [TimeNestCalendar] {
        sharingStore.calendars.filter { $0.kind == .sharedOwned }
    }

    private var received: [TimeNestCalendar] {
        sharingStore.calendars.filter { $0.kind == .sharedReceived }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(localization.localized(.calendarSharingMyCalendar)) {
                    if let personal = sharingStore.calendars.first(where: { $0.kind == .personal }) {
                        calendarRow(personal)
                    } else {
                        calendarRow(sharingStore.personalCalendar)
                    }
                }

                Section(localization.localized(.calendarSharingOwnedCalendars)) {
                    if owned.isEmpty && received.isEmpty {
                        Text(localization.localized(.calendarSharingNoSharedCalendars))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(owned) { calendarRow($0) }
                        ForEach(received) { calendarRow($0) }
                    }
                }

                Section {
                    Button {
                        actionState.requestCreate()
                    } label: {
                        Label(
                            localization.localized(.calendarSharingCreateCalendar),
                            systemImage: "plus.circle.fill"
                        )
                    }
                }

                if let error = sharingStore.lastError {
                    Section {
                        Text(error.localizedDescription)
                            .foregroundStyle(.secondary)
                        Button(localization.localized(.calendarSharingRetry)) {
                            Task { await sharingStore.synchronizeAll() }
                        }
                    }
                }
            }
            .navigationTitle(localization.localized(.calendarSharingSelectCalendar))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localization.localized(.cancel)) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await sharingStore.synchronizeAll() }
                    } label: {
                        if sharingStore.syncStatus == .syncing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(sharingStore.syncStatus == .syncing)
                }
            }
        }
        .calendarSharingPresentation()
        .sheet(isPresented: $actionState.isCreating) {
            CreateSharedCalendarView()
                .environmentObject(sharingStore)
                .environmentObject(localization)
        }
        .sheet(item: $actionState.route) { route in
            Group {
                switch route {
                case .edit(let calendarID):
                    NavigationStack {
                        OwnedSharedCalendarDetailView(calendarID: calendarID)
                    }
                    .calendarSharingPresentation()
                case .receivedDetails(let calendarID):
                    NavigationStack {
                        ReceivedSharedCalendarDetailView(calendarID: calendarID)
                    }
                    .calendarSharingPresentation(
                        height: CalendarSharingPresentationLayout.receivedDetailsHeight
                    )
                }
            }
            .environmentObject(sharingStore)
            .environmentObject(localization)
        }
        .confirmationDialog(
            localization.localized(.calendarSharingDeleteConfirmationTitle),
            isPresented: Binding(
                get: { actionState.deletionCandidateID != nil },
                set: { if !$0 { actionState.cancelDeletion() } }
            ),
            titleVisibility: .visible
        ) {
            Button(localization.localized(.calendarSharingDeleteAction), role: .destructive) {
                guard let calendarID = actionState.beginConfirmedDeletion() else { return }
                Task { await deleteOwnedCalendar(calendarID: calendarID) }
            }
            Button(localization.localized(.cancel), role: .cancel) {
                actionState.cancelDeletion()
            }
        } message: {
            Text(localization.localized(.calendarSharingDeleteConfirmationMessage))
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

    private func calendarRow(_ calendar: TimeNestCalendar) -> some View {
        let actions = CalendarSelectionRowActions(calendar: calendar)
        return HStack(spacing: CalendarSelectionLayout.actionSpacing) {
            Button {
                guard let calendarID = actionState.handle(.select, for: calendar) else { return }
                sharingStore.select(.calendar(calendarID))
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(
                        systemName: calendar.kind == .personal
                            ? "calendar"
                            : "person.2.fill"
                    )
                    .foregroundStyle(ShiftCalendarColors.primaryBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(calendar.name)
                            .foregroundStyle(.primary)
                        if calendar.isReadOnly {
                            Text(localization.localized(.calendarSharingReadOnly))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if sharingStore.selection.calendarID == calendar.id {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(ShiftCalendarColors.primaryBlue)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!actions.actionsAreEnabled)

            if actions.showsEdit {
                calendarActionButton(
                    systemImage: "pencil",
                    color: ShiftCalendarColors.primaryBlue,
                    accessibilityLabel: localization.localized(CalendarSelectionAccessibilityLabels.edit),
                    isEnabled: actions.actionsAreEnabled
                        && actionState.deletionInProgressID == nil
                ) {
                    _ = actionState.handle(.edit, for: calendar)
                }
            }

            if actions.showsDelete {
                if sharingStore.isStopping(calendarID: calendar.id)
                    || actionState.deletionInProgressID == calendar.id {
                    ProgressView()
                        .frame(height: CalendarSelectionLayout.actionButtonHeight)
                        .padding(.horizontal, CalendarSelectionLayout.actionButtonHorizontalPadding)
                        .accessibilityLabel(localization.localized(
                            CalendarSelectionAccessibilityLabels.delete
                        ))
                } else {
                    calendarActionButton(
                        systemImage: "trash",
                        color: .red,
                        accessibilityLabel: localization.localized(CalendarSelectionAccessibilityLabels.delete),
                        isEnabled: actions.actionsAreEnabled
                            && actionState.deletionInProgressID == nil
                    ) {
                        _ = actionState.handle(.delete, for: calendar)
                    }
                }
            }

            if actions.showsReceivedDetails {
                calendarActionButton(
                    systemImage: "info.circle",
                    color: ShiftCalendarColors.primaryBlue,
                    accessibilityLabel: localization.localized(
                        CalendarSelectionAccessibilityLabels.receivedDetails
                    ),
                    isEnabled: true
                ) {
                    _ = actionState.handle(.receivedDetails, for: calendar)
                }
            }
        }
    }

    private func calendarActionButton(
        systemImage: String,
        color: Color,
        accessibilityLabel: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(height: CalendarSelectionLayout.actionButtonHeight)
                .padding(.horizontal, CalendarSelectionLayout.actionButtonHorizontalPadding)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private func deleteOwnedCalendar(calendarID: UUID) async {
        defer { actionState.finishDeletion(calendarID: calendarID) }
        do {
            try await sharingStore.stopOwnedSharing(id: calendarID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CalendarSharingPrimaryActionLabel: View {
    let title: String
    let isWorking: Bool

    var body: some View {
        HStack {
            Spacer()
            if isWorking { ProgressView() }
            Text(title)
                .fontWeight(.semibold)
            Spacer()
        }
        .foregroundStyle(.black.opacity(0.82))
        .padding(.vertical, 6)
    }
}

private struct CalendarSharingPrimaryActionButton: View {
    let title: String
    let isEnabled: Bool
    let isWorking: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CalendarSharingPrimaryActionLabel(
                title: title,
                isWorking: isWorking
            )
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(ShiftCalendarColors.accentYellow)
        .disabled(!isEnabled || isWorking)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

@MainActor
private struct CreateSharedCalendarView: View {
    @EnvironmentObject private var sharingStore: CalendarSharingStore
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isWorking = false
    @State private var invitation: CalendarSharingInvitation?
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        CalendarSharingFormValidation.hasRequiredName(name)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section(localization.localized(.calendarSharingCalendarName)) {
                        TextField(localization.localized(.calendarSharingCalendarName), text: $name)
                            .textInputAutocapitalization(.sentences)
                    }

                    Section {
                        Label(
                            localization.localized(.calendarSharingInviteAfterCreation),
                            systemImage: "person.badge.plus"
                        )
                        .foregroundStyle(.secondary)
                    } header: {
                        Text(localization.localized(.calendarSharingInvitePeople))
                    } footer: {
                        Text(localization.localized(.calendarSharingContentPrivacyNote))
                    }
                }

                CalendarSharingPrimaryActionButton(
                    title: localization.localized(.calendarSharingCreateAction),
                    isEnabled: canSubmit,
                    isWorking: isWorking,
                    action: { Task { await create() } }
                )
            }
            .navigationTitle(localization.localized(.calendarSharingCreateCalendar))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.localized(.cancel)) { dismiss() }
                        .disabled(isWorking)
                }
            }
        }
        .calendarSharingPresentation()
        .sheet(item: $invitation) { item in
            SharingInvitationActivityView(
                invitation: item,
                onFinished: { outcome in
                    let completedInvitation = item
                    invitation = nil
                    Task {
                        do {
                            try await sharingStore.handleInvitationActivity(
                                completedInvitation,
                                outcome: outcome
                            )
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            )
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

    private func create() async {
        isWorking = true
        defer { isWorking = false }
        do {
            invitation = try await sharingStore.createSharedCalendar(name: name)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
private struct OwnedSharedCalendarDetailView: View {
    @EnvironmentObject private var sharingStore: CalendarSharingStore
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    let calendarID: UUID
    @State private var name = ""
    @State private var invitation: CalendarSharingInvitation?
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var descriptor: OwnedSharedCalendarDescriptor? {
        sharingStore.ownedDescriptor(id: calendarID)
    }

    private var canSubmit: Bool {
        CalendarSharingFormValidation.hasRequiredName(name)
            && !sharingStore.isStopping(calendarID: calendarID)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section(localization.localized(.calendarSharingCalendarName)) {
                    TextField(localization.localized(.calendarSharingCalendarName), text: $name)
                        .textInputAutocapitalization(.sentences)
                }

                Section(localization.localized(.calendarSharingSharedPeople)) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(ShiftCalendarColors.primaryBlue)
                        Text(localization.localized(.calendarSharingYou))
                        Spacer()
                        Text(localization.localized(.calendarSharingOwner))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    let participants = sharingStore.participants(for: calendarID)
                    if !participants.isEmpty {
                        ForEach(participants) { participant in
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundStyle(ShiftCalendarColors.primaryBlue)
                                VStack(alignment: .leading) {
                                    Text(participant.resolvedDisplayName(
                                        fallback: localization.localized(.calendarSharingUnknownPerson)
                                    ))
                                    Text(localization.localized(
                                        participant.isAccepted
                                            ? .calendarSharingReadOnly
                                            : .calendarSharingInvitationPending
                                    ))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if !participant.isAccepted {
                                    Button(localization.localized(.calendarSharingRetry)) {
                                        Task {
                                            await retryPendingInvitationRemoval(participant)
                                        }
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(isWorking)
                                }
                            }
                        }
                    }
                    Button {
                        Task { await invite() }
                    } label: {
                        Label(localization.localized(.calendarSharingAddPeople), systemImage: "person.badge.plus")
                    }
                    .disabled(isWorking || sharingStore.isStopping(calendarID: calendarID))
                }
            }

            CalendarSharingPrimaryActionButton(
                title: localization.localized(.calendarSharingSaveAction),
                isEnabled: canSubmit,
                isWorking: isWorking,
                action: { Task { await rename() } }
            )
        }
        .navigationTitle(localization.localized(.calendarSharingEditCalendar))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(localization.localized(.cancel)) { dismiss() }
                    .disabled(isWorking)
            }
        }
        .onAppear { name = descriptor?.calendarName ?? "" }
        .sheet(item: $invitation) { item in
            SharingInvitationActivityView(
                invitation: item,
                onFinished: { outcome in
                    let completedInvitation = item
                    invitation = nil
                    Task {
                        do {
                            try await sharingStore.handleInvitationActivity(
                                completedInvitation,
                                outcome: outcome
                            )
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            )
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

    private func rename() async {
        isWorking = true
        defer { isWorking = false }
        do { try await sharingStore.renameOwnedCalendar(id: calendarID, name: name) }
        catch { errorMessage = error.localizedDescription }
    }

    private func invite() async {
        isWorking = true
        defer { isWorking = false }
        do {
            invitation = try await sharingStore.createInvitation(for: calendarID)
        } catch { errorMessage = error.localizedDescription }
    }

    private func retryPendingInvitationRemoval(
        _ participant: SharedCalendarParticipantSnapshot
    ) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await sharingStore.revokePendingInvitation(
                calendarID: calendarID,
                participantSnapshotID: participant.id
            )
        } catch {
            errorMessage = CalendarSharingError.invitationCancellationFailed.localizedDescription
        }
    }
}

@MainActor
private struct ReceivedSharedCalendarDetailView: View {
    @EnvironmentObject private var sharingStore: CalendarSharingStore
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    let calendarID: UUID
    @State private var isWorking = false
    @State private var confirmingLeave = false
    @State private var errorMessage: String?

    private var descriptor: SharedCalendarDescriptor? {
        sharingStore.receivedCalendars.first { $0.id == calendarID }
    }

    var body: some View {
        Form {
            Section(localization.localized(.calendarSharingCalendarName)) {
                Text(descriptor?.calendarName ?? sharingStore.calendar(id: calendarID)?.name ?? "")
                Label(localization.localized(.calendarSharingReadOnly), systemImage: "eye")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(role: .destructive) {
                    confirmingLeave = true
                } label: {
                    HStack {
                        if isWorking { ProgressView() }
                        Text(localization.localized(.calendarSharingLeave))
                    }
                }
                .disabled(isWorking || descriptor == nil)
            } footer: {
                Text(localization.localized(.calendarSharingLeaveConfirmation))
            }
        }
        .navigationTitle(localization.localized(.calendarSharingReceivedDetails))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            localization.localized(.calendarSharingLeaveConfirmation),
            isPresented: $confirmingLeave,
            titleVisibility: .visible
        ) {
            Button(localization.localized(.calendarSharingLeave), role: .destructive) {
                Task { await leaveSharing() }
            }
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

    private func leaveSharing() async {
        guard let descriptor else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await sharingStore.leave(descriptor)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CalendarAssignmentPicker: View {
    @EnvironmentObject private var sharingStore: CalendarSharingStore
    @EnvironmentObject private var localization: LocalizationManager
    @Binding var calendarID: UUID

    var body: some View {
        Picker(localization.localized(.calendarSharingSelectCalendar), selection: $calendarID) {
            ForEach(sharingStore.writableCalendars) { calendar in
                Text(calendar.name).tag(calendar.id)
            }
        }
    }
}

struct ReadOnlyCalendarDetail: Identifiable {
    let id = UUID()
    let date: Date
    let events: [EventOccurrence]
}

struct ReadOnlySharedCalendarDetailView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    let detail: ReadOnlyCalendarDetail

    var body: some View {
        VStack(spacing: 0) {
            SettingsModalHeaderView(title: localization.formattedDateShort(for: detail.date)) {
                dismiss()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(detail.events) { event in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(event.title).font(.headline)
                            Text(dateText(for: event))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Label(localization.localized(.calendarSharingReadOnly), systemImage: "eye")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(ShiftCalendarColors.primaryBlue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: TimeNestTheme.controlCornerRadius))
                    }
                }
                .padding(SettingsModalSurface.horizontalPadding)
            }
        }
        .background(SettingsModalSurface.background)
        .presentationDetents([.medium, .large])
    }

    private func dateText(for event: EventOccurrence) -> String {
        if event.isWorkClockEvent { return CalendarTimelineEventMetrics.timeText(for: event) }
        if event.isAllDay { return localization.localized(.editorAllDay) }
        let formatter = localization.dateFormatter(dateFormat: "yyyy/MM/dd HH:mm")
        return String(
            format: localization.localized(.calendarSharingDateRangeFormat),
            locale: localization.currentLocale,
            formatter.string(from: event.startDate),
            formatter.string(from: event.endDate)
        )
    }
}

enum CalendarSharingInvitationActivityItems {
    static func make(for invitation: CalendarSharingInvitation) -> [Any] {
        [invitation.url]
    }
}

private struct SharingInvitationActivityView: UIViewControllerRepresentable {
    let invitation: CalendarSharingInvitation
    let onFinished: (SharingInvitationActivityOutcome) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinished: onFinished) }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        CalendarSharingDiagnostics.debug(
            operation: "invite",
            stage: "activity-presented",
            database: "private",
            details: "calendarHash=\(CalendarSharingDiagnostics.identifierHash(invitation.calendarID.uuidString)) "
                + "participantHash=\(CalendarSharingDiagnostics.identifierHash(invitation.id)) "
                + "shareURLAvailable=true"
        )
        let controller = UIActivityViewController(
            activityItems: CalendarSharingInvitationActivityItems.make(for: invitation),
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { activityType, completed, _, error in
            let outcome: SharingInvitationActivityOutcome
            if error != nil {
                outcome = .activityError
            } else if completed {
                outcome = .completed
            } else {
                outcome = .cancelled
            }
            let details = "calendarHash=\(CalendarSharingDiagnostics.identifierHash(invitation.calendarID.uuidString)) "
                + "participantHash=\(CalendarSharingDiagnostics.identifierHash(invitation.id)) "
                + "activityCompleted=\(completed) "
                + "activityType=\(activityType?.rawValue ?? "none")"
            if let error {
                CalendarSharingDiagnostics.error(
                    operation: "invite",
                    stage: "activity-completed",
                    database: "private",
                    error: error,
                    details: details
                )
            } else {
                CalendarSharingDiagnostics.debug(
                    operation: "invite",
                    stage: "activity-completed",
                    database: "private",
                    details: details
                )
            }
            Task { @MainActor in context.coordinator.onFinished(outcome) }
        }
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(
                x: controller.view.bounds.midX,
                y: controller.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    final class Coordinator {
        let onFinished: (SharingInvitationActivityOutcome) -> Void
        init(onFinished: @escaping (SharingInvitationActivityOutcome) -> Void) {
            self.onFinished = onFinished
        }
    }
}
