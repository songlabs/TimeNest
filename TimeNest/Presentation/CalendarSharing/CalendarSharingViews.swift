import SwiftUI
import UIKit

struct CalendarIdentityAvatarView: View {
    let initial: String?
    let size: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color

    init(
        initial: String?,
        size: CGFloat,
        backgroundColor: Color = ShiftCalendarColors.primaryBlue.opacity(0.16),
        foregroundColor: Color = ShiftCalendarColors.primaryBlue
    ) {
        self.initial = initial
        self.size = size
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }

    var body: some View {
        ZStack {
            Circle().fill(backgroundColor)
            if let initial, !initial.isEmpty {
                Text(initial)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(foregroundColor)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: size * 0.7))
                    .foregroundStyle(foregroundColor)
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

struct CalendarSharingCreateNameDraft: Equatable {
    private(set) var value = ""
    private(set) var initialFallbackName: String?
    private(set) var hasUserEditedCalendarName = false
    private(set) var hasAppliedResolvedDefaultName = false

    mutating func initialize(defaultName: String) {
        guard initialFallbackName == nil else { return }
        initialFallbackName = defaultName
        guard value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        value = defaultName
    }

    mutating func updateFromUser(_ value: String) {
        self.value = value
        hasUserEditedCalendarName = true
    }

    @discardableResult
    mutating func applyResolvedDefaultName(_ value: String) -> Bool {
        guard let initialFallbackName,
              !hasAppliedResolvedDefaultName,
              !hasUserEditedCalendarName,
              self.value == initialFallbackName,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        self.value = value
        hasAppliedResolvedDefaultName = true
        return true
    }
}

enum CalendarSharingLocalizedOwnerText {
    static func defaultCalendarName(
        ownerDisplayName: String,
        format: String,
        locale: Locale
    ) -> String {
        String(format: format, locale: locale, ownerDisplayName)
    }

    static func sharedByText(
        ownerDisplayName: String?,
        format: String,
        fallback: String,
        locale: Locale
    ) -> String {
        guard let ownerDisplayName = ownerDisplayName?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !ownerDisplayName.isEmpty else {
            return fallback
        }
        return String(format: format, locale: locale, ownerDisplayName)
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
    var isEnteringInvitationLink = false
    var route: CalendarSelectionRoute?
    private(set) var deletionCandidateID: UUID?
    private(set) var deletionInProgressID: UUID?

    mutating func requestCreate() {
        isCreating = true
    }

    mutating func requestInvitationLinkInput() {
        isEnteringInvitationLink = true
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

enum CalendarSelectionSharedListState: Equatable {
    case loading
    case error
    case empty
    case content

    static func resolve(
        iCloudStatus: CalendarSharingICloudStatus,
        syncStatus: CalendarSharingSyncStatus,
        hasError: Bool,
        hasSharedCalendars: Bool
    ) -> Self {
        // Keep previously loaded content visible while a refresh is in progress or fails.
        if hasSharedCalendars {
            return .content
        }

        switch iCloudStatus {
        case .unknown, .checking:
            return .loading
        case .available:
            break
        case .noAccount, .restricted, .temporarilyUnavailable,
             .couldNotDetermine, .requestFailed:
            return .error
        }

        if hasError || syncStatus == .failed {
            return .error
        }

        switch syncStatus {
        case .idle, .syncing:
            return .loading
        case .synced:
            return .empty
        case .failed:
            return .error
        }
    }
}

@MainActor
struct CalendarSelectionView: View {
    @EnvironmentObject private var sharingStore: CalendarSharingStore
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var actionState = CalendarSelectionActionState()
    @State private var errorMessage: String?
    @State private var invitationNotice: LocalizedString?

    private var owned: [TimeNestCalendar] {
        sharingStore.calendars.filter { $0.kind == .sharedOwned }
    }

    private var received: [TimeNestCalendar] {
        sharingStore.calendars.filter { $0.kind == .sharedReceived }
    }

    private var sharedListState: CalendarSelectionSharedListState {
        CalendarSelectionSharedListState.resolve(
            iCloudStatus: sharingStore.iCloudStatus,
            syncStatus: sharingStore.syncStatus,
            hasError: sharingStore.lastError != nil,
            hasSharedCalendars: !owned.isEmpty || !received.isEmpty
        )
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

                if sharedListState == .content {
                    Section(localization.localized(.calendarSharingOwnedCalendars)) {
                        ForEach(owned) { calendarRow($0) }
                        ForEach(received) { calendarRow($0) }
                    }
                } else if sharedListState == .loading {
                    Section(localization.localized(.calendarSharingOwnedCalendars)) {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(localization.localized(.calendarSharingStateSyncing))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("sharing.loading")
                    }
                } else if sharedListState == .empty {
                    Section(localization.localized(.calendarSharingOwnedCalendars)) {
                        TimeNestActionableEmptyStateView(
                            actionTitle: localization.localized(.calendarSharingCreateCalendar),
                            containerIdentifier: "sharing.empty",
                            actionIdentifier: "sharing.empty.create",
                            action: { actionState.requestCreate() }
                        )
                    }
                }

                Section {
                    if sharedListState != .empty {
                        Button {
                            actionState.requestCreate()
                        } label: {
                            Label(
                                localization.localized(.calendarSharingCreateCalendar),
                                systemImage: "plus.circle.fill"
                            )
                        }
                        .accessibilityIdentifier("sharing.create")
                    }
                    Button {
                        actionState.requestInvitationLinkInput()
                    } label: {
                        Label(
                            localization.localized(.calendarSharingInvitationLinkInputTitle),
                            systemImage: "link.badge.plus"
                        )
                    }
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("sharing.invitationLink")
                }

                if let error = sharingStore.lastError {
                    Section {
                        Text(error.localizedDescription)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("sharing.errorMessage")
                        Button(localization.localized(.calendarSharingRetry)) {
                            Task {
                                await sharingStore.synchronizeAll(
                                    forceICloudStatusRefresh: true
                                )
                            }
                        }
                        .accessibilityIdentifier("sharing.retry")
                    }
                }
            }
            .accessibilityIdentifier("sharing.calendarList")
            .navigationTitle(localization.localized(.calendarSharingSelectCalendar))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localization.localized(.cancel)) { dismiss() }
                        .accessibilityIdentifier("sharing.cancel")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await sharingStore.synchronizeAll(
                                forceICloudStatusRefresh: true
                            )
                        }
                    } label: {
                        if sharingStore.syncStatus == .syncing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(sharingStore.syncStatus == .syncing)
                    .accessibilityIdentifier("sharing.refresh")
                }
            }
        }
        .calendarSharingPresentation()
        .sheet(isPresented: $actionState.isCreating) {
            CreateSharedCalendarView()
                .environmentObject(sharingStore)
                .environmentObject(localization)
        }
        .sheet(isPresented: $actionState.isEnteringInvitationLink) {
            ManualSharedCalendarLinkView { result in
                actionState.isEnteringInvitationLink = false
                invitationNotice = result == .accepted
                    ? .calendarSharingInvitationAccepted
                    : .calendarSharingInvitationAlreadyAccepted
            }
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
        .alert(
            localization.localized(
                invitationNotice ?? .calendarSharingInvitationAccepted
            ),
            isPresented: Binding(
                get: { invitationNotice != nil },
                set: { if !$0 { invitationNotice = nil } }
            )
        ) {
            Button(localization.localized(.ok)) { invitationNotice = nil }
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
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if calendar.kind == .sharedReceived {
                            Text(receivedOwnerSubtitle(for: calendar))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text(localization.localized(
                                calendar.canEditSharedEvent
                                    ? .calendarSharingEditable
                                    : .calendarSharingReadOnly
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        if calendar.kind != .personal {
                            Text(localization.localized(
                                sharingStore.displayStatus(for: calendar).localizedKey
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
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
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
            .disabled(!actions.actionsAreEnabled)
            .accessibilityIdentifier("sharing.calendar.\(calendar.id.uuidString.lowercased())")
            .accessibilityValue(
                calendar.kind == .personal
                    ? ""
                    : localization.localized(
                        sharingStore.displayStatus(for: calendar).localizedKey
                    )
            )

            if actions.showsEdit {
                calendarActionButton(
                    systemImage: "pencil",
                    color: ShiftCalendarColors.primaryBlue,
                    accessibilityLabel: localization.localized(CalendarSelectionAccessibilityLabels.edit),
                    accessibilityIdentifier: "sharing.calendar.edit.\(calendar.id.uuidString.lowercased())",
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
                    accessibilityIdentifier: "sharing.calendar.delete.\(calendar.id.uuidString.lowercased())",
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
                    accessibilityIdentifier: "sharing.calendar.details.\(calendar.id.uuidString.lowercased())",
                    isEnabled: true
                ) {
                    _ = actionState.handle(.receivedDetails, for: calendar)
                }
            }
        }
    }

    private func receivedOwnerSubtitle(for calendar: TimeNestCalendar) -> String {
        CalendarSharingLocalizedOwnerText.sharedByText(
            ownerDisplayName: sharingStore.receivedDescriptor(id: calendar.id)?.ownerDisplayName,
            format: localization.localized(.calendarSharingSharedByOwner),
            fallback: localization.localized(.calendarSharingSharedByICloudUser),
            locale: localization.currentLocale
        )
    }

    private func calendarActionButton(
        systemImage: String,
        color: Color,
        accessibilityLabel: String,
        accessibilityIdentifier: String,
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
        .accessibilityIdentifier(accessibilityIdentifier)
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
private struct ManualSharedCalendarLinkView: View {
    @EnvironmentObject private var sharingStore: CalendarSharingStore
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    let onCompleted: (CalendarSharingManualInvitationResult) -> Void
    @State private var linkText = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section {
                        Text(localization.localized(
                            .calendarSharingInvitationLinkInputHint
                        ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        TextField(
                            localization.localized(
                                .calendarSharingInvitationLinkInputPlaceholder
                            ),
                            text: $linkText,
                            axis: .vertical
                        )
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.URL)
                        .lineLimit(2...4)
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                }

                CalendarSharingPrimaryActionButton(
                    title: localization.localized(
                        .calendarSharingInvitationLinkInputSubmit
                    ),
                    isEnabled: canSubmit,
                    isWorking: isWorking,
                    action: { Task { await submit() } }
                )
            }
            .navigationTitle(localization.localized(
                .calendarSharingInvitationLinkInputTitle
            ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.localized(.cancel)) {
                        linkText = ""
                        sharingStore.resetManualInvitationState()
                        dismiss()
                    }
                    .disabled(isWorking)
                }
            }
        }
        .calendarSharingPresentation()
        .interactiveDismissDisabled(isWorking)
        .onDisappear {
            linkText = ""
            sharingStore.resetManualInvitationState()
        }
    }

    private func submit() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let result = try await sharingStore.acceptShareURL(linkText)
            linkText = ""
            onCompleted(result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
private struct CreateSharedCalendarView: View {
    @EnvironmentObject private var sharingStore: CalendarSharingStore
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var nameDraft = CalendarSharingCreateNameDraft()
    @State private var isWorking = false
    @State private var invitation: CalendarSharingInvitation?
    @State private var errorMessage: String?
    @State private var dismissAfterErrorAcknowledgement = false
    @State private var eventEditingAllowed = false

    private var canSubmit: Bool {
        CalendarSharingFormValidation.hasRequiredName(nameDraft.value)
    }

    var body: some View {
        NavigationStack {
            Form {
                    Section(localization.localized(.calendarSharingCalendarName)) {
                        TextField(
                            localization.localized(.calendarSharingCalendarName),
                            text: Binding(
                                get: { nameDraft.value },
                                set: { nameDraft.updateFromUser($0) }
                            )
                        )
                            .textInputAutocapitalization(.sentences)
                            .accessibilityIdentifier("sharing.createCalendar.name")
                    }

                    Section {
                        Picker(
                            localization.localized(.calendarSharingEventEditingPermission),
                            selection: $eventEditingAllowed
                        ) {
                            Text(localization.localized(.calendarSharingReadOnly))
                                .accessibilityIdentifier("sharing.eventPermission.readOnly")
                                .tag(false)
                            Text(localization.localized(.calendarSharingEventEditingAllowed))
                                .accessibilityIdentifier("sharing.eventPermission.readWrite")
                                .tag(true)
                        }
                        .pickerStyle(.inline)
                        .disabled(isWorking)
                    } header: {
                        Text(localization.localized(.calendarSharingEventEditingPermission))
                    } footer: {
                        Text(localization.localized(.calendarSharingLastWriteWinsNote))
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
            .accessibilityIdentifier("sharing.createCalendar.form")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CalendarSharingPrimaryActionButton(
                    title: localization.localized(.calendarSharingCreateAction),
                    isEnabled: canSubmit,
                    isWorking: isWorking,
                    action: { Task { await create() } }
                )
                .accessibilityIdentifier("sharing.createCalendar.submit")
                .background(.bar)
            }
            .contentMargins(.bottom, 24, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(localization.localized(.calendarSharingCreateCalendar))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.localized(.cancel)) { dismiss() }
                        .disabled(isWorking)
                        .accessibilityIdentifier("sharing.createCalendar.cancel")
                }
            }
        }
        .accessibilityIdentifier("sharing.createCalendar")
        .calendarSharingPresentation()
        .onAppear {
            nameDraft.initialize(
                defaultName: localization.localized(.calendarSharingDefaultCalendarName)
            )
        }
        .task {
            nameDraft.initialize(
                defaultName: localization.localized(.calendarSharingDefaultCalendarName)
            )
            guard let ownerDisplayName = await sharingStore.currentUserDisplayName() else {
                return
            }
            nameDraft.applyResolvedDefaultName(
                CalendarSharingLocalizedOwnerText.defaultCalendarName(
                    ownerDisplayName: ownerDisplayName,
                    format: localization.localized(.calendarSharingDefaultNameWithOwner),
                    locale: localization.currentLocale
                )
            )
        }
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
                            dismissAfterErrorAcknowledgement = true
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
            Button(localization.localized(.ok)) {
                errorMessage = nil
                if dismissAfterErrorAcknowledgement {
                    dismissAfterErrorAcknowledgement = false
                    dismiss()
                }
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func create() async {
        isWorking = true
        defer { isWorking = false }
        do {
            invitation = try await sharingStore.createSharedCalendar(
                name: nameDraft.value,
                eventEditingAllowed: eventEditingAllowed
            )
        } catch {
            errorMessage = error.localizedDescription
            dismissAfterErrorAcknowledgement = (error as? CalendarSharingError)
                == .invitationURLUnavailable
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
    @State private var participantPendingRevocation: SharedCalendarParticipantSnapshot?
    @State private var eventEditingAllowed = false

    private var descriptor: OwnedSharedCalendarDescriptor? {
        sharingStore.ownedDescriptor(id: calendarID)
    }

    private var canSubmit: Bool {
        CalendarSharingFormValidation.hasRequiredName(name)
            && !sharingStore.isStopping(calendarID: calendarID)
    }

    var body: some View {
        Form {
                Section(localization.localized(.calendarSharingCalendarName)) {
                    TextField(localization.localized(.calendarSharingCalendarName), text: $name)
                        .textInputAutocapitalization(.sentences)
                }


                Section {
                    Picker(
                        localization.localized(.calendarSharingEventEditingPermission),
                        selection: $eventEditingAllowed
                    ) {
                        Text(localization.localized(.calendarSharingReadOnly))
                            .accessibilityIdentifier("sharing.eventPermission.readOnly")
                            .tag(false)
                        Text(localization.localized(.calendarSharingEventEditingAllowed))
                            .accessibilityIdentifier("sharing.eventPermission.readWrite")
                            .tag(true)
                    }
                    .pickerStyle(.inline)
                    .disabled(isWorking)
                } header: {
                    Text(localization.localized(.calendarSharingEventEditingPermission))
                } footer: {
                    Text(localization.localized(.calendarSharingLastWriteWinsNote))
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
                                    Text(localization.localized(participantStatusKey(participant)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if !participant.isAccepted {
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Button(localization.localized(.calendarSharingRetry)) {
                                            Task { await refreshPendingInvitationState() }
                                        }
                                        .buttonStyle(.borderless)
                                        .disabled(isWorking)

                                        Button(
                                            localization.localized(.calendarSharingRevokeInvitation),
                                            role: .destructive
                                        ) {
                                            participantPendingRevocation = participant
                                        }
                                        .buttonStyle(.borderless)
                                        .disabled(isWorking)
                                    }
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
        .accessibilityIdentifier("sharing.editCalendar.form")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CalendarSharingPrimaryActionButton(
                title: localization.localized(.calendarSharingSaveAction),
                isEnabled: canSubmit,
                isWorking: isWorking,
                action: { Task { await rename() } }
            )
            .accessibilityIdentifier("sharing.editCalendar.submit")
            .background(.bar)
        }
        .contentMargins(.bottom, 24, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(localization.localized(.calendarSharingEditCalendar))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(localization.localized(.cancel)) { dismiss() }
                    .disabled(isWorking)
            }
        }
        .onAppear {
            name = descriptor?.calendarName ?? ""
            eventEditingAllowed = descriptor?.eventEditingAllowed ?? false
        }
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
        .alert(
            localization.localized(.calendarSharingRevokeInvitationConfirmationTitle),
            isPresented: Binding(
                get: { participantPendingRevocation != nil },
                set: { if !$0 { participantPendingRevocation = nil } }
            )
        ) {
            Button(
                localization.localized(.calendarSharingRevokeInvitation),
                role: .destructive
            ) {
                guard let participant = participantPendingRevocation else { return }
                participantPendingRevocation = nil
                Task { await revokePendingInvitation(participant) }
            }
            Button(localization.localized(.cancel), role: .cancel) {
                participantPendingRevocation = nil
            }
        } message: {
            Text(localization.localized(.calendarSharingRevokeInvitationConfirmationMessage))
        }
    }

    private func rename() async {
        isWorking = true
        defer { isWorking = false }
        do {
            if descriptor?.eventEditingAllowed != eventEditingAllowed {
                try await sharingStore.setEventEditingAllowed(
                    calendarID: calendarID,
                    allowed: eventEditingAllowed
                )
            }
            try await sharingStore.renameOwnedCalendar(id: calendarID, name: name)
        }
        catch { errorMessage = error.localizedDescription }
    }

    private func participantStatusKey(
        _ participant: SharedCalendarParticipantSnapshot
    ) -> LocalizedString {
        guard participant.isAccepted else { return .calendarSharingInvitationPending }
        return participant.permission == .readWrite
            ? .calendarSharingEditable
            : .calendarSharingReadOnly
    }

    private func invite() async {
        isWorking = true
        defer { isWorking = false }
        do {
            invitation = try await sharingStore.createInvitation(for: calendarID)
        } catch { errorMessage = error.localizedDescription }
    }

    private func refreshPendingInvitationState() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await sharingStore.refreshOwnedInvitationStatus(calendarID: calendarID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func revokePendingInvitation(
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
                Label(
                    localization.localized(
                        descriptor?.isReadOnly == false
                            ? .calendarSharingEditable
                            : .calendarSharingReadOnly
                    ),
                    systemImage: descriptor?.isReadOnly == false ? "pencil" : "eye"
                )
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
        return String(
            format: localization.localized(.calendarSharingDateRangeFormat),
            locale: localization.currentLocale,
            localization.formattedUserVisibleDateTime(for: event.startDate),
            localization.formattedUserVisibleDateTime(for: event.endDate)
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
