import CloudKit
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
        let displayName = calendar.resolvedDisplayName(
            fallback: localization.localized(.calendarSharingUnknownPerson)
        )
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

    @State private var displayName = ""
    @State private var calendarName = ""
    @State private var sharingContent = SharedContentConfiguration.newShareDefault
    @State private var isWorking = false
    @State private var presentationState = SharingManagementPresentationState()

    var body: some View {
        Form {
            if let ownedCalendar = sharingStore.ownedCalendar {
                ownedSharingSection(ownedCalendar)
            } else {
                createSharingSection
            }

            sharingContentSection(isExistingShare: sharingStore.ownedCalendar != nil)

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
            if isWorking {
                ProgressView()
            }
        }
        .onAppear {
            if let ownedCalendar = sharingStore.ownedCalendar {
                sharingContent = ownedCalendar.sharedContent
            }
        }
        .onChange(of: sharingStore.ownedCalendar) { _, calendar in
            sharingContent = calendar?.sharedContent ?? .newShareDefault
        }
        .sheet(item: $presentationState.presentedShare, onDismiss: {
            Task { await sharingStore.synchronizeAll() }
        }) { item in
            CloudSharingControllerView(
                share: item.share,
                title: item.title,
                onChanged: { Task { await sharingStore.synchronizeAll() } }
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

    private var createSharingSection: some View {
        Section {
            TextField(localization.localized(.calendarSharingDisplayName), text: $displayName)
                .textContentType(.name)
            TextField(localization.localized(.calendarSharingCalendarName), text: $calendarName)
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
            } else {
                Button(localization.localized(.calendarSharingStart)) {
                    Task { await createSharing() }
                }
                .disabled(!sharingContent.hasSelectedContent)
            }
        } header: {
            Text(localization.localized(.calendarSharingContentTitle))
        } footer: {
            Text(localization.localized(.calendarSharingContentPrivacyNote))
        }
    }

    @ViewBuilder
    private func ownedSharingSection(_ calendar: OwnedSharedCalendarDescriptor) -> some View {
        Section(localization.localized(.calendarSharingMyCalendar)) {
            LabeledContent(
                localization.localized(.calendarSharingDisplayName),
                value: calendar.displayName
            )
            LabeledContent(
                localization.localized(.calendarSharingCalendarName),
                value: calendar.calendarName
            )
            LabeledContent(
                localization.localized(.calendarSharingParticipants),
                value: String(calendar.participantCount)
            )
            Button(localization.localized(.calendarSharingOpenSystemManagement)) {
                Task { await openOwnedShare() }
            }
            Button(localization.localized(.calendarSharingStop), role: .destructive) {
                presentationState.showAlert(.confirmStop)
            }
        }
    }

    private var receivedSharingSection: some View {
        Section(localization.localized(.calendarSharingReceivedCalendars)) {
            ForEach(sharingStore.receivedCalendars) { calendar in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(calendar.resolvedCalendarName(
                            fallback: localization.localized(.calendarSharingUnknownCalendar)
                        ))
                        Text(calendar.resolvedDisplayName(
                            fallback: localization.localized(.calendarSharingUnknownPerson)
                        ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !calendarName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            presentationState.showAlert(
                .message(localization.localized(.calendarSharingRequiredFields))
            )
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let share = try await sharingStore.createShare(
                displayName: displayName,
                calendarName: calendarName,
                content: sharingContent
            )
            presentationState.present(share: share, title: calendarName)
            CalendarSharingDiagnostics.debug(
                operation: "startSharing",
                stage: "controller_ready",
                database: "private",
                details: "selectedSource=mine sharingControllerReady=true"
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

    private func openOwnedShare() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let share = try await sharingStore.ownedShareForPresentation()
            let title = sharingStore.ownedCalendar?.calendarName
                ?? localization.localized(.calendarSharingUnknownCalendar)
            presentationState.present(share: share, title: title)
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

struct PresentedCloudShare: Identifiable {
    let id = UUID()
    let share: CKShare
    let title: String
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
    var presentedShare: PresentedCloudShare?
    var alertState: SharingManagementAlert?

    mutating func present(share: CKShare, title: String) {
        alertState = nil
        presentedShare = PresentedCloudShare(share: share, title: title)
    }

    mutating func showAlert(_ alert: SharingManagementAlert) {
        presentedShare = nil
        alertState = alert
    }
}

private struct CloudSharingControllerView: UIViewControllerRepresentable {
    let share: CKShare
    let title: String
    let onChanged: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(title: title, onChanged: onChanged)
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: CKContainer.default())
        controller.availablePermissions = [.allowPrivate, .allowReadOnly]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let title: String
        let onChanged: () -> Void

        init(title: String, onChanged: @escaping () -> Void) {
            self.title = title
            self.onChanged = onChanged
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            title
        }

        func cloudSharingController(
            _ csc: UICloudSharingController,
            failedToSaveShareWithError error: Error
        ) {
            CalendarSharingDiagnostics.error(
                operation: "sharingController",
                stage: "save_failed",
                database: "private",
                error: error
            )
            onChanged()
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            onChanged()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            onChanged()
        }
    }
}
