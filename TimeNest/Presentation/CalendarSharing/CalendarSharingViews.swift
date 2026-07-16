import SwiftUI
import UIKit

struct CalendarIdentityAvatarView: View {
    let initial: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let initial {
                Text(initial)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: size, height: size)
                    .background(ShiftCalendarColors.primaryBlue)
                    .clipShape(Circle())
            } else {
                Image(systemName: "calendar.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(ShiftCalendarColors.primaryBlue)
                    .frame(width: size, height: size)
            }
        }
    }
}

struct CalendarSelectionView: View {
    @EnvironmentObject private var sharingStore: CalendarSharingStore
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(localization.localized(.calendarSharingMyCalendar)) {
                    Button {
                        sharingStore.select(.mine)
                        dismiss()
                    } label: {
                        calendarRow(
                            avatarInitial: nil,
                            title: localization.localized(.calendarSharingMyCalendar),
                            subtitle: myCalendarSubtitle,
                            isSelected: sharingStore.selection == .mine
                        )
                    }
                    .buttonStyle(.plain)
                }

                if !sharingStore.receivedCalendars.isEmpty {
                    Section(localization.localized(.calendarSharingReceivedCalendars)) {
                        ForEach(sharingStore.receivedCalendars) { calendar in
                            Button {
                                sharingStore.select(.shared(calendar.id))
                                dismiss()
                            } label: {
                                calendarRow(
                                    avatarInitial: CalendarAvatarInitial.make(
                                        displayName: calendar.displayName,
                                        fallback: localization.localized(.calendarSharingUnknownPerson)
                                    ),
                                    title: calendar.resolvedCalendarName(
                                        fallback: localization.localized(.calendarSharingUnknownCalendar)
                                    ),
                                    subtitle: sharedCalendarSubtitle(calendar),
                                    isSelected: sharingStore.selection == .shared(calendar.id)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if sharingStore.syncStatus == .failed, let error = sharingStore.lastError {
                    Section {
                        Text(error.localizedDescription)
                            .foregroundStyle(.secondary)
                        Button(localization.localized(.calendarSharingRetry)) {
                            Task { await sharingStore.synchronizeAll() }
                        }
                    }
                }

                Section {
                    NavigationLink {
                        CalendarSharingManagementView()
                            .environmentObject(sharingStore)
                            .environmentObject(localization)
                    } label: {
                        Label(
                            localization.localized(.calendarSharingManage),
                            systemImage: "person.2.badge.gearshape"
                        )
                    }
                }
            }
            .navigationTitle(localization.localized(.calendarSharingSelectCalendar))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if sharingStore.syncStatus == .syncing {
                        ProgressView()
                    } else {
                        Button {
                            Task { await sharingStore.synchronizeAll() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel(localization.localized(.calendarSharingRetry))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var myCalendarSubtitle: String? {
        guard let count = sharingStore.ownedCalendar?.participantCount, count > 0 else { return nil }
        return String(
            format: localization.localized(.calendarSharingSharedWithCount),
            locale: localization.currentLocale,
            count
        )
    }

    private func sharedCalendarSubtitle(_ calendar: SharedCalendarDescriptor) -> String {
        guard let displayName = calendar.distinctDisplayName else {
            return localization.localized(.calendarSharingReadOnly)
        }
        return String(
            format: localization.localized(.calendarSharingOwnerReadOnlyFormat),
            locale: localization.currentLocale,
            displayName,
            localization.localized(.calendarSharingReadOnly)
        )
    }

    private func calendarRow(
        avatarInitial: String?,
        title: String,
        subtitle: String?,
        isSelected: Bool
    ) -> some View {
        HStack(spacing: 12) {
            CalendarIdentityAvatarView(initial: avatarInitial, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(ShiftCalendarColors.primaryBlue)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct CalendarSharingManagementView: View {
    @EnvironmentObject private var sharingStore: CalendarSharingStore
    @EnvironmentObject private var localization: LocalizationManager

    @State private var calendarName = ""
    @State private var sharingContent = SharedContentConfiguration.newShareDefault
    @State private var isWorking = false
    @State private var isPreparingInvitation = false
    @State private var presentationState = SharingManagementPresentationState()

    var body: some View {
        Form {
            calendarNameSection

            sharingContentSection(isExistingShare: sharingStore.ownedCalendar != nil)

            if sharingStore.ownedCalendar == nil {
                startSharingSection
            } else {
                participantsSection
                addPeopleSection
                stopSharingSection
            }

            if !sharingStore.receivedCalendars.isEmpty {
                receivedSharingSection
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
        .navigationTitle(localization.localized(.calendarSharingManage))
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isWorking)
        .overlay {
            if isWorking && !isPreparingInvitation {
                ProgressView()
            }
        }
        .onAppear {
            sharingStore.setParticipantManagementActive(true)
            if let ownedCalendar = sharingStore.ownedCalendar {
                sharingContent = ownedCalendar.sharedContent
            }
        }
        .onDisappear {
            sharingStore.setParticipantManagementActive(false)
        }
        .task {
            await sharingStore.refreshOwnedParticipants()
        }
        .onChange(of: sharingStore.ownedCalendar) { _, calendar in
            sharingContent = calendar?.sharedContent ?? .newShareDefault
        }
        .sheet(item: $presentationState.presentedInvitation) { item in
            SharingInvitationActivityView(
                activityItems: [
                    localization.localized(.calendarSharingInvitationMessage),
                    item.url
                ],
                onFinished: {
                    presentationState.dismissInvitation()
                    Task { await sharingStore.refreshOwnedParticipants() }
                }
            )
        }
        .alert(item: $presentationState.alertState) { state in
            switch state {
            case .message(let message):
                Alert(
                    title: Text(localization.localized(.calendarSharingErrorTitle)),
                    message: Text(message),
                    dismissButton: .default(Text(localization.localized(.ok)))
                )
            case .confirmStop:
                Alert(
                    title: Text(localization.localized(.calendarSharingStop)),
                    message: Text(localization.localized(.calendarSharingStopConfirmation)),
                    primaryButton: .destructive(Text(localization.localized(.calendarSharingStop))) {
                        Task { await stopSharing() }
                    },
                    secondaryButton: .cancel(Text(localization.localized(.cancel)))
                )
            case .confirmLeave(let calendar):
                Alert(
                    title: Text(localization.localized(.calendarSharingLeave)),
                    message: Text(localization.localized(.calendarSharingLeaveConfirmation)),
                    primaryButton: .destructive(Text(localization.localized(.calendarSharingLeave))) {
                        Task { await leave(calendar) }
                    },
                    secondaryButton: .cancel(Text(localization.localized(.cancel)))
                )
            }
        }
    }

    private var calendarNameSection: some View {
        Section {
            if let ownedCalendar = sharingStore.ownedCalendar {
                Text(ownedCalendar.calendarName)
            } else {
                TextField(localization.localized(.calendarSharingCalendarName), text: $calendarName)
            }
        } header: {
            Text(localization.localized(.calendarSharingCalendarName))
        }
    }

    private func sharingContentSection(isExistingShare: Bool) -> some View {
        Section {
            Toggle(
                localization.localized(.calendarSharingContentEvents),
                isOn: $sharingContent.sharesEvents
            )
            Toggle(
                localization.localized(.calendarSharingContentShifts),
                isOn: $sharingContent.sharesShifts
            )
            Toggle(
                localization.localized(.calendarSharingContentWorkRecords),
                isOn: $sharingContent.sharesWorkRecords
            )

            if !sharingContent.hasSelectedContent {
                Text(localization.localized(.calendarSharingContentSelectionRequired))
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if isExistingShare {
                if sharingContent != sharingStore.ownedCalendar?.sharedContent {
                    Button(localization.localized(.calendarSharingUpdateSettings)) {
                        Task { await updateSharing() }
                    }
                    .disabled(!sharingContent.hasSelectedContent)
                }
            }
        } header: {
            Text(localization.localized(.calendarSharingContentTitle))
        } footer: {
            Text(localization.localized(.calendarSharingContentPrivacyNote))
        }
    }

    private var startSharingSection: some View {
        Section {
            Button {
                Task { await createSharing() }
            } label: {
                invitationButtonLabel(
                    title: localization.localized(.calendarSharingStart)
                )
            }
            .buttonStyle(.plain)
            .background(ShiftCalendarColors.accentYellow)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: TimeNestTheme.controlCornerRadius,
                    style: .continuous
                )
            )
            .opacity(sharingContent.hasSelectedContent ? 1 : 0.45)
            .disabled(!sharingContent.hasSelectedContent)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var addPeopleSection: some View {
        Section {
            Button {
                Task { await createAdditionalInvitation() }
            } label: {
                invitationButtonLabel(
                    title: localization.localized(.calendarSharingAddPeople),
                    systemImage: "person.badge.plus"
                )
            }
            .buttonStyle(.plain)
            .background(ShiftCalendarColors.accentYellow)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: TimeNestTheme.controlCornerRadius,
                    style: .continuous
                )
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var participantsSection: some View {
        Section {
            if sharingStore.ownedParticipants.isEmpty {
                Text(
                    localization.localized(
                        sharingStore.participantRefreshFailed
                            ? .calendarSharingParticipantInfoUnavailable
                            : .calendarSharingNoParticipants
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else {
                ForEach(sharingStore.ownedParticipants) { participant in
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(ShiftCalendarColors.primaryBlue.opacity(0.72))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(
                                participant.resolvedDisplayName(
                                    fallback: localization.localized(.calendarSharingUnknownPerson)
                                )
                            )
                            Text(localization.localized(.calendarSharingReadOnly))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                if sharingStore.participantRefreshFailed {
                    Text(localization.localized(.calendarSharingParticipantInfoUnavailable))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(localization.localized(.calendarSharingSharedPeople))
        }
    }

    private var stopSharingSection: some View {
        Section {
            Button(localization.localized(.calendarSharingStop), role: .destructive) {
                presentationState.showAlert(.confirmStop)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        } footer: {
            Text(localization.localized(.calendarSharingStopConfirmation))
        }
    }

    @ViewBuilder
    private func invitationButtonLabel(title: String, systemImage: String? = nil) -> some View {
        HStack(spacing: 8) {
            if isPreparingInvitation {
                ProgressView()
                    .tint(.black.opacity(0.82))
            } else if let systemImage {
                Image(systemName: systemImage)
            }
            Text(
                isPreparingInvitation
                    ? localization.localized(.calendarSharingInvitationPreparing)
                    : title
            )
        }
        .font(.headline)
        .foregroundStyle(.black.opacity(0.82))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    private var receivedSharingSection: some View {
        Section(localization.localized(.calendarSharingReceivedCalendars)) {
            ForEach(sharingStore.receivedCalendars) { calendar in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(calendar.resolvedCalendarName(
                            fallback: localization.localized(.calendarSharingUnknownCalendar)
                        ))
                        if let displayName = calendar.distinctDisplayName {
                            Text(displayName)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button(localization.localized(.calendarSharingLeave), role: .destructive) {
                        presentationState.showAlert(.confirmLeave(calendar))
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private func createSharing() async {
        let normalizedCalendarName = calendarName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCalendarName.isEmpty else {
            presentationState.showAlert(
                .message(localization.localized(.calendarSharingRequiredFields))
            )
            return
        }
        isWorking = true
        isPreparingInvitation = true
        defer {
            isWorking = false
            isPreparingInvitation = false
        }
        do {
            let invitationURL = try await sharingStore.createShare(
                calendarName: normalizedCalendarName,
                content: sharingContent
            )
            presentationState.present(invitationURL: invitationURL)
            CalendarSharingDiagnostics.debug(
                operation: "startSharing",
                stage: "invitation_ready",
                database: "private",
                details: "selectedSource=mine invitationReady=true"
            )
        } catch is CancellationError {
            return
        } catch {
            presentationState.showAlert(.message(error.localizedDescription))
        }
    }

    private func updateSharing() async {
        guard sharingContent.hasSelectedContent else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await sharingStore.updateOwnedSharing(content: sharingContent)
        } catch is CancellationError {
            return
        } catch {
            presentationState.showAlert(
                .message(localization.localized(.calendarSharingUpdateFailed))
            )
        }
    }

    private func createAdditionalInvitation() async {
        isWorking = true
        isPreparingInvitation = true
        defer {
            isWorking = false
            isPreparingInvitation = false
        }
        do {
            let invitationURL = try await sharingStore.createOwnedInvitation()
            presentationState.present(invitationURL: invitationURL)
        } catch is CancellationError {
            return
        } catch {
            presentationState.showAlert(.message(error.localizedDescription))
        }
    }

    private func stopSharing() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await sharingStore.stopOwnedSharing()
        } catch is CancellationError {
            return
        } catch {
            presentationState.showAlert(.message(error.localizedDescription))
        }
    }

    private func leave(_ calendar: SharedCalendarDescriptor) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await sharingStore.leave(calendar)
        } catch is CancellationError {
            return
        } catch {
            presentationState.showAlert(.message(error.localizedDescription))
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
                            Text(event.title)
                                .font(.headline)
                            Text(dateText(for: event))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if event.isWorkClockEvent, let restHours = event.workInfo?.restHours {
                                LabeledContent(
                                    localization.localized(.editorRestTime),
                                    value: formattedRestTime(restHours)
                                )
                                .font(.subheadline)
                            }
                            Label(
                                localization.localized(.calendarSharingReadOnly),
                                systemImage: "eye"
                            )
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
        if event.isWorkClockEvent {
            return CalendarTimelineEventMetrics.timeText(for: event)
        }
        if event.isAllDay {
            return localization.localized(.editorAllDay)
        }
        let formatter = localization.dateFormatter(dateFormat: "yyyy/MM/dd HH:mm")
        return String(
            format: localization.localized(.calendarSharingDateRangeFormat),
            locale: localization.currentLocale,
            formatter.string(from: event.startDate),
            formatter.string(from: event.endDate)
        )
    }

    private func formattedRestTime(_ hours: Double) -> String {
        let hour = Int(hours)
        let minute = Int((hours - Double(hour)) * 60)
        return String(format: "%d:%02d", hour, minute)
    }
}

struct PresentedSharingInvitation: Identifiable {
    let id = UUID()
    let url: URL
}

enum SharingManagementAlert: Identifiable {
    case message(String)
    case confirmStop
    case confirmLeave(SharedCalendarDescriptor)

    var id: String {
        switch self {
        case .message(let message): "message-\(message)"
        case .confirmStop: "stop"
        case .confirmLeave(let calendar): "leave-\(calendar.id)"
        }
    }
}

struct SharingManagementPresentationState {
    var presentedInvitation: PresentedSharingInvitation?
    var alertState: SharingManagementAlert?

    mutating func present(invitationURL: URL) {
        alertState = nil
        presentedInvitation = PresentedSharingInvitation(url: invitationURL)
    }

    mutating func dismissInvitation() {
        presentedInvitation = nil
    }

    mutating func showAlert(_ alert: SharingManagementAlert) {
        presentedInvitation = nil
        alertState = alert
    }
}

private struct SharingInvitationActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onFinished: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            Task { @MainActor in
                context.coordinator.onFinished()
            }
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
        let onFinished: () -> Void

        init(onFinished: @escaping () -> Void) {
            self.onFinished = onFinished
        }
    }
}
