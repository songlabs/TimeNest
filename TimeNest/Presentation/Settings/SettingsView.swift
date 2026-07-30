import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    private static let privacyPolicyURL = URL(string: "https://songlabs.github.io/timenest/privacy.html")

    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var calendarSharingStore: CalendarSharingStore
    @AppStorage("weekStart") private var weekStart: String = "system"
    @AppStorage("themeMode") private var themeMode: String = "system"
    @AppStorage(TraditionalCalendarPreferences.showLunarCalendarKey) private var showLunarCalendar = false
    @AppStorage(TraditionalCalendarPreferences.showRokuyoKey) private var showRokuyo = false
    @AppStorage(TraditionalCalendarPreferences.showSolarTermsKey) private var showSolarTerms = false

    @State private var showVersionInfo: Bool = false
    @State private var showingHelp = false
    @State private var showingThirdPartyLicenses = false
    @State private var purchaseAlertMessage: String?
    @State private var dataAlertMessage: String?
    @State private var exportedFile: TimeNestTemporaryExportFile?
    @State private var isImportingBackup = false
    @State private var pendingRestore: TimeNestBackupDocument?
    @State private var isConfirmingRestore = false
    @State private var shouldRestoreAfterConfirmationDismissal = false
    @State private var isSelectingWorkRecordMonth = false
    @State private var selectedWorkRecordMonth = Date()
    @State private var dataOperationInProgress = false
    @StateObject private var subscriptionManager: HolidaySubscriptionManager
    @ObservedObject private var purchaseManager = RemoveAdsPurchaseManager.shared

    private let onClose: (() -> Void)?

    init(
        subscriptionManager: HolidaySubscriptionManager,
        onClose: (() -> Void)? = nil
    ) {
        _subscriptionManager = StateObject(wrappedValue: subscriptionManager)
        self.onClose = onClose
    }

    var body: some View {
        Group {
            if let onClose {
                VStack(spacing: 0) {
                    SettingsModalHeaderView(
                        title: localization.localized(.settingsTitle),
                        closeAction: onClose
                    )

                    settingsForm
                }
                .background(SettingsModalSurface.background)
            } else {
                settingsForm
                    .navigationTitle(localization.localized(.settingsTitle))
            }
        }
        .presentationDetents([.custom(SettingsCompactDetent.self)])
    }

    private var settingsForm: some View {
        ScrollView {
            VStack(spacing: SettingsStyle.sectionSpacing) {
                SettingsCard {
                    SettingsPickerRow(
                        title: localization.localized(.settingsLanguage),
                        allowsMultiline: true,
                        selection: Binding(
                            get: { localization.selectedLanguageCode },
                            set: { localization.setLanguage(DisplayLanguage(rawValue: $0) ?? .system) }
                        ),
                        options: [
                            SettingsPickerOption(title: localization.localized(.languageSystem), tag: "system"),
                            SettingsPickerOption(title: localization.localized(.languageSimplifiedChinese), tag: "zhHans"),
                            SettingsPickerOption(title: localization.localized(.languageTraditionalChinese), tag: "zh-Hant"),
                            SettingsPickerOption(title: localization.localized(.languageJapanese), tag: "ja"),
                            SettingsPickerOption(title: localization.localized(.languageKorean), tag: "ko"),
                            SettingsPickerOption(title: localization.localized(.languageEnglish), tag: "enUS")
                        ]
                    )
                    .accessibilityIdentifier("settings.currentLanguage")
                }

                SettingsCard {
                    SettingsCardTitle(localization.localized(.calendarSharingSettingsTitle))
                    SettingsDivider()

                    SettingsValueRow(
                        title: localization.localized(.calendarSharingICloudStatusTitle),
                        value: localization.localized(calendarSharingStore.iCloudStatus.localizedKey),
                        allowsMultiline: true
                    )
                    .accessibilityIdentifier("sharing.iCloudStatusValue")

                    SettingsDivider()

                    SettingsValueRow(
                        title: localization.localized(.calendarSharingLastSuccessfulSync),
                        value: lastSuccessfulSyncText,
                        allowsMultiline: true
                    )
                    .accessibilityIdentifier("sharing.lastSuccessfulSync")

                    SettingsDivider()

                    SettingsActionRow(
                        title: localization.localized(.calendarSharingSyncNow),
                        systemImage: "arrow.triangle.2.circlepath"
                    ) {
                        Task {
                            await calendarSharingStore.synchronizeAll(
                                forceICloudStatusRefresh: true
                            )
                        }
                    }
                    .accessibilityIdentifier("sharing.syncNow")

                    if shouldShowICloudSettingsAction {
                        SettingsDivider()

                        SettingsActionRow(
                            title: localization.localized(.calendarSharingOpenSettings),
                            systemImage: "gearshape"
                        ) {
                            openSystemSettings()
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("sharing.icloudStatus")

                SettingsCard {
                    SettingsCardTitle(
                        localization.localized(.settingsDataManagement),
                        allowsMultiline: true
                    )
                    SettingsDivider()

                    SettingsActionRow(
                        title: localization.localized(.dataBackupCreate),
                        systemImage: "square.and.arrow.up",
                        allowsMultiline: true
                    ) {
                        createBackup()
                    }
                    .accessibilityIdentifier("settings.createBackup")

                    SettingsDivider()

                    SettingsActionRow(
                        title: localization.localized(.dataBackupRestore),
                        systemImage: "square.and.arrow.down",
                        allowsMultiline: true
                    ) {
                        guard !dataOperationInProgress else { return }
#if DEBUG
                        if TimeNestUITestSupport.isEnabled {
                            prepareUITestRestoreFixture()
                            return
                        }
#endif
                        isImportingBackup = true
                    }
                    .accessibilityIdentifier("settings.restoreBackup")

                    SettingsDivider()

                    SettingsActionRow(
                        title: localization.localized(.dataWorkRecordsExport),
                        systemImage: "tablecells",
                        allowsMultiline: true
                    ) {
                        guard !dataOperationInProgress else { return }
                        isSelectingWorkRecordMonth = true
                    }
                    .accessibilityIdentifier("settings.exportWorkRecords")
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("settings.dataManagement")

                SettingsCard {
                    SettingsNavigationRow(
                        title: localization.localized(.settingsHolidayRegion),
                        value: enabledSubscriptionsDisplayText
                    ) {
                        HolidaySubscriptionSettingsView(subscriptionManager: subscriptionManager)
                            .environmentObject(localization)
                    }
                }

                SettingsCard {
                    SettingsPickerRow(
                        title: localization.localized(.settingsWeekStart),
                        selection: $weekStart,
                        options: [
                            SettingsPickerOption(title: localization.localized(.weekStartSystem), tag: "system"),
                            SettingsPickerOption(title: localization.localized(.weekStartSunday), tag: "sunday"),
                            SettingsPickerOption(title: localization.localized(.weekStartMonday), tag: "monday"),
                            SettingsPickerOption(title: localization.localized(.weekStartSaturday), tag: "saturday")
                        ]
                    )
                }

                SettingsCard {
                    SettingsCardTitle(localization.localized(.settingsTraditionalCalendar))
                    SettingsDivider()

                    SettingsToggleRow(
                        title: localization.localized(.settingsTraditionalCalendarShowLunar),
                        isOn: $showLunarCalendar,
                        accessibilityIdentifier: "settings.traditionalCalendar.showLunar"
                    )

                    SettingsDivider()

                    SettingsToggleRow(
                        title: localization.localized(.settingsTraditionalCalendarShowRokuyo),
                        isOn: $showRokuyo,
                        accessibilityIdentifier: "settings.traditionalCalendar.showRokuyo"
                    )

                    SettingsDivider()

                    SettingsToggleRow(
                        title: localization.localized(.settingsTraditionalCalendarShowSolarTerms),
                        isOn: $showSolarTerms,
                        accessibilityIdentifier: "settings.traditionalCalendar.showSolarTerms"
                    )
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("settings.traditionalCalendar")

                SettingsCard {
                    SettingsNavigationRow(
                        title: localization.localized(.shiftTimeSettingsTitle)
                    ) {
                        ShiftTimeSettingsView()
                            .environmentObject(localization)
                    }
                    .accessibilityIdentifier("settings.shiftTemplates")
                }

                SettingsCard {
                    SettingsPickerRow(
                        title: localization.localized(.settingsTheme),
                        selection: $themeMode,
                        options: [
                            SettingsPickerOption(title: localization.localized(.themeLight), tag: "light"),
                            SettingsPickerOption(title: localization.localized(.themeDark), tag: "dark"),
                            SettingsPickerOption(title: localization.localized(.themeSystem), tag: "system")
                        ]
                    )

                    SettingsDivider()

                    SettingsNavigationRow(
                        title: localization.localized(.settingsCalendarDisplayCustomize)
                    ) {
                        CalendarDisplayCustomizeView()
                            .environmentObject(localization)
                    }
                }

                SettingsCard {
                    if purchaseManager.isAdsRemoved {
                        SettingsValueRow(
                            title: localization.localized(.adsRemove),
                            value: localization.localized(.adsRemoved)
                        )
                    } else {
                        SettingsActionRow(
                            title: localization.localized(.adsRemove),
                            systemImage: "rectangle.slash"
                        ) {
                            Task {
                                await purchaseRemoveAds()
                            }
                        }
                    }

                    SettingsDivider()

                    SettingsActionRow(
                        title: localization.localized(.adsRestorePurchases),
                        systemImage: "arrow.clockwise"
                    ) {
                        Task {
                            await restorePurchases()
                        }
                    }
                }

                SettingsCard {
                    SettingsCardTitle(localization.localized(.settingsSupport))
                    SettingsDivider()

                    SettingsActionRow(
                        title: localization.localized(.helpTitle),
                        systemImage: "questionmark.circle"
                    ) {
                        showingHelp = true
                    }

                    SettingsDivider()

                    SettingsActionRow(
                        title: localization.localized(.aboutPrivacy),
                        systemImage: "hand.raised"
                    ) {
                        openPrivacyPolicy()
                    }

                    SettingsDivider()

                    SettingsActionRow(
                        title: localization.localized(.thirdPartyLicensesTitle),
                        systemImage: "doc.text"
                    ) {
                        showingThirdPartyLicenses = true
                    }
                }

                SettingsCard {
                    SettingsCardTitle(localization.localized(.settingsAbout))
                    SettingsDivider()

                    SettingsValueRow(
                        title: localization.localized(.aboutVersion),
                        value: appVersionText
                    )

                    SettingsDivider()

                    SettingsValueRow(
                        title: localization.localized(.aboutDeveloper),
                        value: localization.localized(.aboutDeveloperName)
                    )
                }
            }
            .padding(.horizontal, SettingsStyle.horizontalPadding)
            .padding(.top, SettingsStyle.topPadding)
            .padding(.bottom, SettingsStyle.bottomPadding)
        }
        .background(SettingsStyle.background)
        .foregroundColor(SettingsStyle.primaryText)
        .sheet(isPresented: $showingHelp) {
            HelpView()
                .environmentObject(localization)
        }
        .sheet(isPresented: $showingThirdPartyLicenses) {
            ThirdPartyLicensesView()
                .environmentObject(localization)
        }
        .sheet(item: $exportedFile) { item in
            TimeNestActivityView(activityItems: [item.url]) {
                cleanupExportedFile(item)
            }
        }
        .sheet(isPresented: $isSelectingWorkRecordMonth) {
            ZStack {
                SettingsModalSurface.background.ignoresSafeArea()
                YearMonthPickerView(
                    currentDate: selectedWorkRecordMonth,
                    onCancel: { isSelectingWorkRecordMonth = false },
                    onSelect: { year, month in
                        let calendar = Calendar(identifier: .gregorian)
                        selectedWorkRecordMonth = calendar.date(
                            from: DateComponents(year: year, month: month, day: 1)
                        ) ?? selectedWorkRecordMonth
                        isSelectingWorkRecordMonth = false
                        exportWorkRecords()
                    }
                )
                .environmentObject(localization)
                .padding()
            }
            .presentationDetents([.height(280)])
        }
        .sheet(isPresented: $isConfirmingRestore, onDismiss: {
            guard shouldRestoreAfterConfirmationDismissal else { return }
            shouldRestoreAfterConfirmationDismissal = false
            Task { await restorePendingBackup() }
        }) {
            restoreConfirmationSheet
        }
        .fileImporter(
            isPresented: $isImportingBackup,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleBackupImport
        )
        .alert(
            dataAlertMessage ?? purchaseAlertMessage ?? "",
            isPresented: Binding(
                get: { dataAlertMessage != nil || purchaseAlertMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        dataAlertMessage = nil
                        purchaseAlertMessage = nil
                    }
                }
            )
        ) {
            Button(localization.localized(.ok), role: .cancel) {
                dataAlertMessage = nil
                purchaseAlertMessage = nil
            }
        }
        .task {
#if DEBUG
            if !TimeNestUITestSupport.isEnabled {
                await purchaseManager.loadProductIfNeeded()
                await purchaseManager.refreshPurchasedState(context: "settings appear")
            }
#else
            await purchaseManager.loadProductIfNeeded()
            await purchaseManager.refreshPurchasedState(context: "settings appear")
#endif
            _ = await calendarSharingStore.refreshICloudStatus()
        }
    }

    private var restoreConfirmationSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(localization.localized(.dataBackupRestoreConfirmationTitle))
                    .font(.title2.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(localization.localized(.dataBackupRestoreConfirmationMessage))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    Button(role: .destructive) {
                        shouldRestoreAfterConfirmationDismissal = true
                        isConfirmingRestore = false
                    } label: {
                        Text(localization.localized(.dataBackupRestoreConfirmationAction))
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.white)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityIdentifier("settings.restoreConfirm")

                    Button {
                        shouldRestoreAfterConfirmationDismissal = false
                        pendingRestore = nil
                        isConfirmingRestore = false
                    } label: {
                        Text(localization.localized(.cancel))
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .background(Color.secondary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityIdentifier("settings.restoreCancel")
                }
            }
            .padding(24)
        }
        .background(SettingsModalSurface.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var shouldShowICloudSettingsAction: Bool {
        switch calendarSharingStore.iCloudStatus {
        case .noAccount, .restricted:
            true
        case .unknown, .checking, .available, .temporarilyUnavailable,
             .couldNotDetermine, .requestFailed:
            false
        }
    }

    private var lastSuccessfulSyncText: String {
        guard let date = calendarSharingStore.lastSuccessfulSyncAt else {
            return localization.localized(.calendarSharingLastSuccessfulSyncNever)
        }
        let formatter = DateFormatter()
        formatter.locale = localization.currentLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var enabledSubscriptionsDisplayText: String {
        let enabledRegions = subscriptionManager.enabledRegions
        if enabledRegions.isEmpty {
            return localization.localized(.holidaySubscriptionNone)
        }
        return enabledRegions
            .sorted { $0.localizedKey < $1.localizedKey }
            .map { localization.localized($0.localizedKey) }
            .joined(separator: ", ")
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        guard let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              !build.isEmpty else {
            return version
        }
        return "\(version) (\(build))"
    }

    private func openPrivacyPolicy() {
        guard let url = Self.privacyPolicyURL else { return }
        openURL(url) { _ in }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url) { _ in }
    }

    private func createBackup() {
        guard !dataOperationInProgress else { return }
        dataOperationInProgress = true
        defer { dataOperationInProgress = false }
        do {
            let document = try backupService.makeDocument(
                appVersion: appVersionText
            )
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd_HHmmss"
            exportedFile = try TimeNestTemporaryExportFile.make(
                data: document.encoded(),
                fileName: "TimeNest_Backup_\(formatter.string(from: document.createdAt)).json"
            )
        } catch {
            dataAlertMessage = localization.localized(.dataBackupCreateFailed)
        }
    }

    private func handleBackupImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                throw CocoaError(.fileReadUnknown)
            }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            let document = try TimeNestBackupDocument.decoded(from: Data(contentsOf: url))
            pendingRestore = document
            isConfirmingRestore = true
        } catch {
            pendingRestore = nil
            dataAlertMessage = localization.localized(.dataBackupInvalidFile)
        }
    }

#if DEBUG
    private func prepareUITestRestoreFixture() {
        do {
            let document = try backupService.makeDocument(appVersion: appVersionText)
            if TimeNestUITestSupport.shouldSimulateRestoreFailure {
                pendingRestore = TimeNestBackupDocument(
                    formatVersion: TimeNestBackupDocument.currentFormatVersion + 1,
                    appIdentifier: document.appIdentifier,
                    createdAt: document.createdAt,
                    appVersion: document.appVersion,
                    data: document.data
                )
            } else {
                pendingRestore = document
            }
            isConfirmingRestore = true
        } catch {
            pendingRestore = nil
            dataAlertMessage = localization.localized(.dataBackupInvalidFile)
        }
    }
#endif

    private func restorePendingBackup() async {
        guard let pendingRestore, !dataOperationInProgress else { return }
        dataOperationInProgress = true
        defer { dataOperationInProgress = false }
        do {
            let notificationSummary = try await backupService.restore(pendingRestore)
            self.pendingRestore = nil
            subscriptionManager.reloadFromPersistence()
            LocalizationManager.shared.reloadFromPersistence()
            NotificationCenter.default.post(name: .timeNestDataDidRestore, object: nil)
            Task { await calendarSharingStore.handleLocalDataRestore() }
            dataAlertMessage = localization.localized(.dataBackupRestoreSuccess)
#if DEBUG
            if notificationSummary.hasWarnings {
                print(
                    "[TimeNest][Restore] notification rebuild warning "
                        + "denied=\(notificationSummary.deniedCount) "
                        + "failed=\(notificationSummary.failedCount)"
                )
            }
#endif
        } catch {
            dataAlertMessage = localization.localized(.dataBackupRestoreFailed)
        }
    }

    private func exportWorkRecords() {
        guard !dataOperationInProgress else { return }
        dataOperationInProgress = true
        defer { dataOperationInProgress = false }
        do {
            let events = try modelContext.fetch(
                FetchDescriptor<SwiftDataCalendarEventEntity>(sortBy: [SortDescriptor(\.startDate)])
            ).map(SwiftDataEventMapper.makeDomainModel)
            let export = try WorkRecordCSVExporter.makeExport(
                events: events,
                monthContaining: selectedWorkRecordMonth,
                headers: WorkRecordCSVHeaders(
                    date: localization.localized(.dataCSVDate),
                    startTime: localization.localized(.dataCSVStartTime),
                    endTime: localization.localized(.dataCSVEndTime),
                    restTime: localization.localized(.dataCSVRestTime),
                    workedTime: localization.localized(.dataCSVWorkedTime),
                    recordName: localization.localized(.dataCSVRecordName),
                    note: localization.localized(.dataCSVNote)
                ),
                locale: localization.currentLocale
            )
            exportedFile = try TimeNestTemporaryExportFile.make(
                data: export.data,
                fileName: export.fileName
            )
        } catch WorkRecordCSVExportError.noData {
            dataAlertMessage = localization.localized(.dataWorkRecordsNoData)
        } catch {
            dataAlertMessage = localization.localized(.dataWorkRecordsExportFailed)
        }
    }

    private var backupService: TimeNestBackupService {
        TimeNestBackupService(modelContext: modelContext)
    }

    private func cleanupExportedFile(_ item: TimeNestTemporaryExportFile) {
#if DEBUG
        if TimeNestUITestSupport.preserveExportedTestFile {
            if exportedFile?.id == item.id {
                exportedFile = nil
            }
            return
        }
#endif
        try? FileManager.default.removeItem(at: item.cleanupURL)
        if exportedFile?.id == item.id {
            exportedFile = nil
        }
    }

    private func purchaseRemoveAds() async {
        let outcome = await purchaseManager.purchaseRemoveAds()
        switch outcome {
        case .completed:
            purchaseAlertMessage = localization.localized(.adsPurchaseCompleted)
        case .failed(let reason):
            purchaseAlertMessage = purchaseFailureMessage(for: reason)
        case .pending:
            purchaseAlertMessage = localization.localized(.adsPurchasePending)
        case .restored, .cancelled:
            break
        }
    }

    private func restorePurchases() async {
        let outcome = await purchaseManager.restorePurchases()
        switch outcome {
        case .restored, .completed:
            purchaseAlertMessage = localization.localized(.adsRestoreCompleted)
        case .failed(let reason):
            purchaseAlertMessage = restoreFailureMessage(for: reason)
        case .pending:
            purchaseAlertMessage = localization.localized(.adsPurchasePending)
        case .cancelled:
            break
        }
    }

    private func purchaseFailureMessage(for reason: RemoveAdsPurchaseFailureReason) -> String {
        switch reason {
        case .productUnavailable:
            return localization.localized(.adsPurchaseUnavailable)
        case .noRestorablePurchases:
            return localization.localized(.adsRestoreNotFound)
        case .restoreFailed:
            return localization.localized(.adsRestoreFailed)
        case .purchaseFailed, .verificationFailed, .productMismatch, .unknownPurchaseResult:
            return localization.localized(.adsPurchaseFailed)
        }
    }

    private func restoreFailureMessage(for reason: RemoveAdsPurchaseFailureReason) -> String {
        switch reason {
        case .noRestorablePurchases:
            return localization.localized(.adsRestoreNotFound)
        case .restoreFailed:
            return localization.localized(.adsRestoreFailed)
        case .productUnavailable, .purchaseFailed, .verificationFailed, .productMismatch, .unknownPurchaseResult:
            return localization.localized(.adsPurchaseFailed)
        }
    }
}

private struct TimeNestTemporaryExportFile: Identifiable {
    let id = UUID()
    let url: URL
    let cleanupURL: URL

    static func make(data: Data, fileName: String) throws -> TimeNestTemporaryExportFile {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeNestExport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent(fileName, isDirectory: false)
        do {
            try data.write(to: url, options: .atomic)
            return TimeNestTemporaryExportFile(url: url, cleanupURL: directory)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }
}

private struct TimeNestActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onCompletion: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            context.coordinator.complete()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    static func dismantleUIViewController(
        _ uiViewController: UIActivityViewController,
        coordinator: Coordinator
    ) {
        coordinator.complete()
    }

    final class Coordinator {
        private let onCompletion: () -> Void
        private var didComplete = false

        init(onCompletion: @escaping () -> Void) {
            self.onCompletion = onCompletion
        }

        func complete() {
            guard !didComplete else { return }
            didComplete = true
            onCompletion()
        }
    }
}

private enum SettingsStyle {
    static let background = SettingsModalSurface.background
    static let cardBackground = SettingsModalSurface.sectionBackground
    static let primaryText = SettingsModalSurface.primaryText
    static let secondaryText = SettingsModalSurface.secondaryText
    static let divider = SettingsModalSurface.separator

    static let horizontalPadding: CGFloat = TimeNestTheme.externalPadding
    static let sectionSpacing: CGFloat = 16
    static let topPadding: CGFloat = 12
    static let bottomPadding: CGFloat = 12
    static let sheetCompactHeight: CGFloat = 620
    static let sheetMaximumHeightRatio: CGFloat = 0.82
    static let rowHorizontalPadding: CGFloat = 16
    static let rowMinHeight: CGFloat = 56
    static let cardCornerRadius: CGFloat = 26
    static let titleTopPadding: CGFloat = 14
    static let titleBottomPadding: CGFloat = 8
    static let accessorySpacing: CGFloat = 6
    static let rowContentSpacing: CGFloat = 8
    static let rowAccessoryMinSpacing: CGFloat = 8
}

private struct SettingsCompactDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        min(
            SettingsStyle.sheetCompactHeight,
            context.maxDetentValue * SettingsStyle.sheetMaximumHeightRatio
        )
    }
}

private struct SettingsPickerOption: Identifiable {
    let title: String
    let tag: String

    var id: String { tag }
}

private struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(SettingsStyle.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: SettingsStyle.cardCornerRadius, style: .continuous))
    }
}

private struct SettingsCardTitle: View {
    let title: String
    let allowsMultiline: Bool

    init(_ title: String, allowsMultiline: Bool = false) {
        self.title = title
        self.allowsMultiline = allowsMultiline
    }

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(SettingsStyle.secondaryText)
            .lineLimit(allowsMultiline ? nil : 1)
            .fixedSize(horizontal: false, vertical: allowsMultiline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SettingsStyle.rowHorizontalPadding)
            .padding(.top, SettingsStyle.titleTopPadding)
            .padding(.bottom, SettingsStyle.titleBottomPadding)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(SettingsStyle.divider)
            .frame(height: 1 / UIScreen.main.scale)
            .padding(.leading, SettingsStyle.rowHorizontalPadding)
    }
}

private struct SettingsRow<Accessory: View>: View {
    let title: String
    let allowsMultiline: Bool
    let accessory: Accessory

    init(
        title: String,
        allowsMultiline: Bool = false,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.allowsMultiline = allowsMultiline
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: SettingsStyle.rowContentSpacing) {
            Text(title)
                .font(.body)
                .foregroundColor(SettingsStyle.primaryText)
                .lineLimit(allowsMultiline ? nil : 1)
                .minimumScaleFactor(allowsMultiline ? 1 : 0.82)
                .fixedSize(horizontal: false, vertical: allowsMultiline)
                .layoutPriority(1)

            Spacer(minLength: SettingsStyle.rowAccessoryMinSpacing)

            accessory
                .layoutPriority(0)
        }
        .frame(minHeight: SettingsStyle.rowMinHeight)
        .padding(.horizontal, SettingsStyle.rowHorizontalPadding)
        .contentShape(Rectangle())
    }
}

private struct SettingsPickerRow: View {
    let title: String
    var allowsMultiline = false
    @Binding var selection: String
    let options: [SettingsPickerOption]

    var body: some View {
        SettingsRow(title: title, allowsMultiline: allowsMultiline) {
            Picker("", selection: $selection) {
                ForEach(options) { option in
                    Text(option.title).tag(option.tag)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(SettingsStyle.secondaryText)
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let accessibilityIdentifier: String

    var body: some View {
        SettingsRow(title: title) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .accessibilityIdentifier(accessibilityIdentifier)
        }
    }
}

private struct SettingsNavigationRow<Destination: View>: View {
    let title: String
    var value: String?
    let destination: Destination

    init(
        title: String,
        value: String? = nil,
        @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.value = value
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            SettingsRow(title: title) {
                HStack(spacing: SettingsStyle.accessorySpacing) {
                    if let value {
                        Text(value)
                            .font(.body)
                            .foregroundColor(SettingsStyle.secondaryText)
                            .lineLimit(1)
                    }

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(SettingsStyle.secondaryText)
                        .fixedSize()
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsActionRow: View {
    let title: String
    let systemImage: String
    var allowsMultiline = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SettingsStyle.rowContentSpacing) {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                    .foregroundColor(.accentColor)
                    .frame(width: 24)

                Text(title)
                    .font(.body)
                    .foregroundColor(SettingsStyle.primaryText)
                    .lineLimit(allowsMultiline ? nil : 1)
                    .minimumScaleFactor(allowsMultiline ? 1 : 0.82)
                    .fixedSize(horizontal: false, vertical: allowsMultiline)

                Spacer(minLength: SettingsStyle.rowAccessoryMinSpacing)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(SettingsStyle.secondaryText)
            }
            .frame(minHeight: SettingsStyle.rowMinHeight)
            .padding(.horizontal, SettingsStyle.rowHorizontalPadding)
            .padding(.vertical, allowsMultiline ? 6 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String
    var allowsMultiline = false

    @ViewBuilder
    var body: some View {
        if allowsMultiline {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(SettingsStyle.primaryText)
                Text(value)
                    .font(.body)
                    .foregroundColor(SettingsStyle.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: SettingsStyle.rowMinHeight, alignment: .leading)
            .padding(.horizontal, SettingsStyle.rowHorizontalPadding)
            .padding(.vertical, 8)
        } else {
            SettingsRow(title: title) {
                Text(value)
                    .font(.body)
                    .foregroundColor(SettingsStyle.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
    }
}

// MARK: - Calendar Display Customize

private struct CalendarDisplayCustomizeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    @AppStorage(CalendarItemColorSettings.eventBackgroundColorKey) private var eventBackgroundColorHex = CalendarItemColorSettings.defaultEventBackgroundColorHex
    @AppStorage(CalendarItemColorSettings.workRecordBackgroundColorKey) private var workRecordBackgroundColorHex = CalendarItemColorSettings.defaultWorkRecordBackgroundColorHex

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsStyle.sectionSpacing) {
                HStack {
                    Text(localization.localized(.settingsCalendarDisplayCustomize))
                        .font(TimeNestTheme.Fonts.popupTitle)
                        .foregroundColor(SettingsModalSurface.primaryText)

                    Spacer()

                    ModalHeaderCloseButton {
                        dismiss()
                    }
                }

                SettingsCard {
                    CalendarBackgroundColorRow(
                        title: localization.localized(.settingsCalendarDisplayCustomizeEventBackground),
                        colorHex: $eventBackgroundColorHex,
                        defaultHex: CalendarItemColorSettings.defaultEventBackgroundColorHex
                    )

                    SettingsDivider()

                    CalendarBackgroundColorRow(
                        title: localization.localized(.settingsCalendarDisplayCustomizeWorkRecordBackground),
                        colorHex: $workRecordBackgroundColorHex,
                        defaultHex: CalendarItemColorSettings.defaultWorkRecordBackgroundColorHex
                    )

                    SettingsDivider()

                    CalendarResetDefaultsRow(
                        title: localization.localized(.settingsCalendarDisplayCustomizeResetDefaults),
                        action: resetDefaults
                    )
                }
            }
            .padding(.horizontal, SettingsStyle.horizontalPadding)
            .padding(.top, SettingsStyle.topPadding)
            .padding(.bottom, SettingsStyle.bottomPadding)
        }
        .background(SettingsModalSurface.background)
        .navigationBarBackButtonHidden(true)
    }

    private func resetDefaults() {
        CalendarItemColorSettings.resetDefaults()
        eventBackgroundColorHex = CalendarItemColorSettings.defaultEventBackgroundColorHex
        workRecordBackgroundColorHex = CalendarItemColorSettings.defaultWorkRecordBackgroundColorHex
    }
}

private struct CalendarBackgroundColorRow: View {
    let title: String
    @Binding var colorHex: String
    let defaultHex: String

    var body: some View {
        SettingsRow(title: title) {
            ColorPicker("", selection: colorBinding, supportsOpacity: false)
                .labelsHidden()
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: {
                Color(hex: colorHex) ?? Color(hex: defaultHex) ?? .gray
            },
            set: { newColor in
                colorHex = newColor.toHexRGB()
            }
        )
    }
}

private struct CalendarResetDefaultsRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SettingsStyle.rowContentSpacing) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.body.weight(.medium))
                    .foregroundColor(.accentColor)
                    .frame(width: 24)

                Text(title)
                    .font(.body)
                    .foregroundColor(SettingsStyle.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: SettingsStyle.rowAccessoryMinSpacing)
            }
            .frame(minHeight: SettingsStyle.rowMinHeight)
            .padding(.horizontal, SettingsStyle.rowHorizontalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shift Time Settings

extension ShiftTimeTemplateID {
    var nameKey: LocalizedString {
        switch self {
        case .day:
            return .shiftDay
        case .night:
            return .shiftNight
        case .custom:
            return .shiftCommon
        }
    }
    
    /// 自定义班次的 UUID 存储 key，用于在 UserDefaults 中记录自定义班次的存在
    var uuidStorageKey: String {
        switch self {
        case .day, .night:
            return ""
        case .custom(let uuid):
            return "shiftTime.custom.\(uuid.uuidString).id"
        }
    }

    var defaultDisplayName: String {
        switch self {
        case .day:
            return LocalizationManager.shared.localized(.shiftDay)
        case .night:
            return LocalizationManager.shared.localized(.shiftNight)
        case .custom:
            return ""
        }
    }

    var defaultStartTime: String {
        switch self {
        case .day:
            return "08:30"
        case .night:
            return "17:00"
        case .custom:
            return "09:00"
        }
    }

    var defaultEndTime: String {
        switch self {
        case .day:
            return "17:30"
        case .night:
            return "09:00"
        case .custom:
            return "18:00"
        }
    }

    var defaultColorHex: String {
        switch self {
        case .day:
            return "#FFD54F"
        case .night:
            return "#5C6BC0"
        case .custom:
            return "#4CAF50"
        }
    }

    var startTimeKey: String {
        switch self {
        case .day:
            return "shiftTime.day.start"
        case .night:
            return "shiftTime.night.start"
        case .custom(let uuid):
            return "shiftTime.custom.\(uuid.uuidString).start"
        }
    }

    var endTimeKey: String {
        switch self {
        case .day:
            return "shiftTime.day.end"
        case .night:
            return "shiftTime.night.end"
        case .custom(let uuid):
            return "shiftTime.custom.\(uuid.uuidString).end"
        }
    }

    var enabledKey: String {
        switch self {
        case .day:
            return "shiftTime.day.enabled"
        case .night:
            return "shiftTime.night.enabled"
        case .custom(let uuid):
            return "shiftTime.custom.\(uuid.uuidString).enabled"
        }
    }

    var displayNameKey: String {
        switch self {
        case .day:
            return "shiftTime.day.displayName"
        case .night:
            return "shiftTime.night.displayName"
        case .custom(let uuid):
            return "shiftTime.custom.\(uuid.uuidString).displayName"
        }
    }

    var displayNameCustomizedKey: String {
        "\(displayNameKey).customized"
    }

    var noteKey: String {
        switch self {
        case .day:
            return "shiftTime.day.note"
        case .night:
            return "shiftTime.night.note"
        case .custom(let uuid):
            return "shiftTime.custom.\(uuid.uuidString).note"
        }
    }

    var colorHexKey: String {
        switch self {
        case .day:
            return "shiftTime.day.colorHex"
        case .night:
            return "shiftTime.night.colorHex"
        case .custom(let uuid):
            return "shiftTime.custom.\(uuid.uuidString).colorHex"
        }
    }

    /// 获取对应的颜色（十六进制版本）
    var colorHex: String {
        defaultColorHex
    }
}

struct ShiftTimeTemplate: Identifiable, Equatable {
    let id: ShiftTimeTemplateID
    let nameKey: LocalizedString
    var displayName: String
    var note: String
    var colorHex: String
    var startTime: String
    var endTime: String
    var enabled: Bool
    var usesLocalizedDefaultName: Bool = false

    var displayTime: String {
        "\(startTime)〜\(endTime)"
    }

    var color: Color {
        Color(hex: colorHex) ?? .gray
    }

    var buttonTextColor: Color {
        // 判断背景色深浅，决定使用深色还是白色文字
        // 将颜色转换为 UIColor 来判断亮度
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // 计算相对亮度 (YIQ 公式)
        let brightness = (r * 299 + g * 587 + b * 114) / 1000
        
        // 亮度低于 0.5 使用白色文字，否则使用深色文字（使用黑色确保在白色背景上可见）
        return brightness < 0.5 ? .white : .black
    }

    var startHourMinute: (hour: Int, minute: Int)? {
        Self.hourMinute(from: startTime)
    }

    var endHourMinute: (hour: Int, minute: Int)? {
        Self.hourMinute(from: endTime)
    }

    static func all(from defaults: UserDefaults = .standard) -> [ShiftTimeTemplate] {
        // 固定模板：day, night
        let fixedTemplates: [ShiftTimeTemplateID] = [.day, .night]
        var templates: [ShiftTimeTemplate] = []
        
        for id in fixedTemplates {
            // 跳过已删除的模板
            let deletedKey = "shiftTemplate.deleted.\(id.id)"
            if defaults.bool(forKey: deletedKey) {
                continue
            }
            
            let usesLocalizedDefaultName = usesLocalizedDefaultDisplayName(for: id, defaults: defaults)
            let displayName = usesLocalizedDefaultName
                ? id.defaultDisplayName
                : (defaults.string(forKey: id.displayNameKey) ?? id.defaultDisplayName)
            templates.append(ShiftTimeTemplate(
                id: id,
                nameKey: id.nameKey,
                displayName: displayName,
                note: defaults.string(forKey: id.noteKey) ?? "",
                colorHex: defaults.string(forKey: id.colorHexKey) ?? id.defaultColorHex,
                startTime: defaults.string(forKey: id.startTimeKey) ?? id.defaultStartTime,
                endTime: defaults.string(forKey: id.endTimeKey) ?? id.defaultEndTime,
                enabled: defaults.object(forKey: id.enabledKey) as? Bool ?? true,
                usesLocalizedDefaultName: usesLocalizedDefaultName
            ))
        }

        // 加载自定义班次
        let customKeys = Set(
            defaults.dictionaryRepresentation()
                .filter { $0.key.hasPrefix("shiftTime.custom.") && $0.key.hasSuffix(".id") }
                .map { String($0.key.prefix($0.key.count - 3)) }
        )

        for prefix in customKeys {
            if let uuidString = defaults.string(forKey: prefix + ".id"),
               let uuid = UUID(uuidString: uuidString) {
                let id = ShiftTimeTemplateID.custom(uuid)
                
                // 跳过已删除的模板
                let deletedKey = "shiftTemplate.deleted.\(id.id)"
                if defaults.bool(forKey: deletedKey) {
                    continue
                }
                
                // 自定义班次优先显示保存的 displayName，为空时才使用默认值
                let displayName = defaults.string(forKey: prefix + ".displayName") ?? ""
                templates.append(ShiftTimeTemplate(
                    id: id,
                    nameKey: id.nameKey,
                    displayName: displayName,
                    note: defaults.string(forKey: id.noteKey) ?? "",
                    colorHex: defaults.string(forKey: id.colorHexKey) ?? id.defaultColorHex,
                    startTime: defaults.string(forKey: id.startTimeKey)
                        ?? defaults.string(forKey: prefix + ".startTime")
                        ?? id.defaultStartTime,
                    endTime: defaults.string(forKey: id.endTimeKey)
                        ?? defaults.string(forKey: prefix + ".endTime")
                        ?? id.defaultEndTime,
                    enabled: defaults.object(forKey: id.enabledKey) as? Bool ?? true
                ))
            }
        }

        return templates
    }

    /// 识别旧版本自动保存的内置名称；其他值均视为用户自定义名称。
    static func usesLocalizedDefaultDisplayName(
        for template: ShiftTimeTemplateID,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard !defaults.bool(forKey: template.displayNameCustomizedKey) else {
            return false
        }
        guard let stored = defaults.string(forKey: template.displayNameKey) else {
            return true
        }
        return isKnownDefaultDisplayName(stored, for: template)
    }

    static func isKnownDefaultDisplayName(_ name: String, for template: ShiftTimeTemplateID) -> Bool {
        switch template {
        case .day:
            return ["白", "白班", "日勤", "Day Shift", "주간"].contains(name)
        case .night:
            return ["夜", "夜班", "夜勤", "Night Shift", "야간"].contains(name)
        case .custom:
            return false
        }
    }

    static func isKnownDefaultDisplayName(_ name: String) -> Bool {
        isKnownDefaultDisplayName(name, for: .day)
            || isKnownDefaultDisplayName(name, for: .night)
    }

    static func localizedDisplayName(for storedName: String, templateID: ShiftTimeTemplateID?) -> String {
        guard let templateID, isKnownDefaultDisplayName(storedName, for: templateID) else {
            return storedName
        }
        return templateID.defaultDisplayName
    }

    static func enabled(from defaults: UserDefaults = .standard) -> [ShiftTimeTemplate] {
        all(from: defaults).filter(\.enabled)
    }

    static func normalizedTimeString(from date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%02d:%02d", hour, minute)
    }

    static func date(from timeString: String, calendar: Calendar = Calendar(identifier: .gregorian)) -> Date {
        let components = hourMinute(from: timeString) ?? (0, 0)
        return calendar.date(bySettingHour: components.hour, minute: components.minute, second: 0, of: Date()) ?? Date()
    }

    static func hourMinute(from timeString: String) -> (hour: Int, minute: Int)? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }

    static func == (lhs: ShiftTimeTemplate, rhs: ShiftTimeTemplate) -> Bool {
        lhs.id == rhs.id &&
        lhs.displayName == rhs.displayName &&
        lhs.note == rhs.note &&
        lhs.colorHex == rhs.colorHex &&
        lhs.startTime == rhs.startTime &&
        lhs.endTime == rhs.endTime &&
        lhs.enabled == rhs.enabled &&
        lhs.usesLocalizedDefaultName == rhs.usesLocalizedDefaultName
    }
}

// MARK: - Color Hex Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count
        switch length {
        case 6:
            let r = Double((rgb & 0xFF0000) >> 16) / 255.0
            let g = Double((rgb & 0x00FF00) >> 8) / 255.0
            let b = Double(rgb & 0x0000FF) / 255.0
            self.init(red: r, green: g, blue: b)
        case 8:
            let r = Double((rgb & 0xFF000000) >> 24) / 255.0
            let g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            let b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            self.init(red: r, green: g, blue: b)
        default:
            return nil
        }
    }

    func toHex() -> String {
        // Extract RGBA components using UIColor
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let red = Int((r * 255).rounded())
        let green = Int((g * 255).rounded())
        let blue = Int((b * 255).rounded())
        let alpha = Int((a * 255).rounded())
        
        return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
    }

    func toHexRGB() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        let red = Int(r * 255)
        let green = Int(g * 255)
        let blue = Int(b * 255)

        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

// MARK: - ShiftTimeTemplateID Color Extension

extension ShiftTimeTemplateID {
    var color: Color {
        color(from: .standard)
    }

    func colorHex(from defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: colorHexKey) ?? defaultColorHex
    }

    func color(from defaults: UserDefaults = .standard) -> Color {
        Color(hex: colorHex(from: defaults)) ?? .gray
    }
}

struct ShiftTimeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    @State private var selectedShift: ShiftTimeTemplateID?
    @State private var shiftTemplates: [ShiftTimeTemplate] = []
    @State private var hasLoadedShiftTemplates = false
    @State private var showAddShift: Bool = false
    @State private var favoriteIDs = Set<String>()
    @State private var pendingDeletion: ShiftTimeTemplate?
    @State private var pendingDeletionReferenceCount = 0
    @Query private var storedEvents: [SwiftDataCalendarEventEntity]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text(localization.localized(.shiftTimeSettingsTitle))
                        .font(TimeNestTheme.Fonts.popupTitle)
                        .foregroundColor(SettingsModalSurface.primaryText)
                        .accessibilityIdentifier("shiftTemplate.list")
                    
                    Spacer()
                    
                    ModalHeaderCloseButton {
                        dismiss()
                    }
                }
                .padding(.bottom, 8)
                
                if !hasLoadedShiftTemplates {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 160)
                        .accessibilityIdentifier("shiftTemplate.loading")
                } else if shiftTemplates.isEmpty {
                    TimeNestActionableEmptyStateView(
                        actionTitle: localization.localized(.shiftTimeAddButton),
                        containerIdentifier: "shiftTemplate.empty",
                        actionIdentifier: "shiftTemplate.empty.create",
                        action: { showAddShift = true }
                    )
                } else {
                    // Shift List
                    VStack(alignment: .leading, spacing: 12) {
                        let favorites = shiftTemplates.filter { favoriteIDs.contains($0.id.id) }
                        let remaining = shiftTemplates.filter { !favoriteIDs.contains($0.id.id) }

                        if !favorites.isEmpty {
                            Text(localization.localized(.shiftTemplateFavorites))
                                .font(.headline)
                                .accessibilityIdentifier("shiftTemplate.favoriteSection")
                            ForEach(favorites) { template in
                                templateRow(template)
                            }
                        }

                        if !remaining.isEmpty {
                            ForEach(remaining) { template in
                                templateRow(template)
                            }
                        }
                    }

                    // Add Button
                    HStack {
                        Spacer()
                        Button {
                            showAddShift = true
                        } label: {
                            Text(localization.localized(.shiftTimeAddButton))
                                .fontWeight(.medium)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .accessibilityIdentifier("shiftTemplate.add")
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .background(SettingsModalSurface.background)
        .sheet(item: $selectedShift) { shiftID in
            ShiftTimeEditSheet(
                shiftID: shiftID,
                onSave: updateShiftTemplate
            )
            .environmentObject(localization)
        }
        .sheet(isPresented: $showAddShift) {
            ShiftTimeEditSheet(
                shiftID: .custom(UUID()),
                isNew: true,
                onSave: addNewShiftTemplate
            )
            .environmentObject(localization)
        }
        .onAppear {
            loadShiftTemplates()
        }
        .onChange(of: localization.selectedLanguageCode) { _, _ in
            loadShiftTemplates()
        }
        .alert(
            localization.localized(.shiftTemplateDeleteConfirmationTitle),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            )
        ) {
            Button(localization.localized(.cancel), role: .cancel) {
                pendingDeletion = nil
            }
            .accessibilityIdentifier("shiftTemplate.delete.cancel")
            Button(localization.localized(.shiftTimeDeleteButton), role: .destructive) {
                guard let template = pendingDeletion else { return }
                deleteShiftTemplate(template)
                pendingDeletion = nil
            }
            .accessibilityIdentifier("shiftTemplate.delete.confirm")
        } message: {
            Text(deleteConfirmationMessage)
                .accessibilityIdentifier("shiftTemplate.delete.message")
        }
        .navigationBarBackButtonHidden(true)
    }

    private func templateRow(_ template: ShiftTimeTemplate) -> some View {
        ShiftTimeSettingsRow(
            template: template,
            isFavorite: favoriteIDs.contains(template.id.id),
            onToggleFavorite: { toggleFavorite(template) },
            onDelete: requestDeleteShiftTemplate,
            onEdit: { selectedShift = template.id }
        )
    }

    private func loadShiftTemplates() {
        shiftTemplates = ShiftTimeTemplate.all()
        let ids = ShiftTemplateFavoritesStore().reconcile(
            validTemplateIDs: shiftTemplates.map(\.id)
        )
        favoriteIDs = Set(ids)
        hasLoadedShiftTemplates = true
    }

    private func requestDeleteShiftTemplate(_ template: ShiftTimeTemplate) {
        pendingDeletionReferenceCount = storedEvents.filter {
            switch template.id {
            case .day:
                return $0.shiftTemplateKind == "day"
            case .night:
                return $0.shiftTemplateKind == "night"
            case .custom(let id):
                return $0.shiftTemplateKind == "custom" && $0.shiftTemplateCustomID == id
            }
        }.count
        pendingDeletion = template
    }

    private var deleteConfirmationMessage: String {
        if pendingDeletionReferenceCount > 0 {
            return String(
                format: localization.localized(.shiftTemplateDeleteReferencedMessage),
                pendingDeletionReferenceCount
            )
        }
        return localization.localized(.shiftTemplateDeleteUnusedMessage)
    }

    private func deleteShiftTemplate(_ template: ShiftTimeTemplate) {
        // 记录已删除的模板 ID，防止自动恢复
        let deletedKey = "shiftTemplate.deleted.\(template.id.id)"
        UserDefaults.standard.set(true, forKey: deletedKey)
        
        shiftTemplates.removeAll { $0.id == template.id }
        saveShiftTemplates()
        favoriteIDs = Set(
            ShiftTemplateFavoritesStore().reconcile(validTemplateIDs: shiftTemplates.map(\.id))
        )
    }

    private func updateShiftTemplate(_ template: ShiftTimeTemplate) {
        if let index = shiftTemplates.firstIndex(where: { $0.id == template.id }) {
            shiftTemplates[index] = template
            saveShiftTemplates()
        }
    }

    private func addNewShiftTemplate(_ template: ShiftTimeTemplate) {
        shiftTemplates.append(template)
        saveShiftTemplates()
    }

    private func toggleFavorite(_ template: ShiftTimeTemplate) {
        let willFavorite = !favoriteIDs.contains(template.id.id)
        favoriteIDs = Set(
            ShiftTemplateFavoritesStore().setFavorite(willFavorite, id: template.id)
        )
    }

    private func saveShiftTemplates() {
        let defaults = UserDefaults.standard
        for template in shiftTemplates {
            if template.usesLocalizedDefaultName {
                defaults.removeObject(forKey: template.id.displayNameKey)
                defaults.removeObject(forKey: template.id.displayNameCustomizedKey)
            } else {
                defaults.set(template.displayName, forKey: template.id.displayNameKey)
                if case .day = template.id {
                    defaults.set(true, forKey: template.id.displayNameCustomizedKey)
                } else if case .night = template.id {
                    defaults.set(true, forKey: template.id.displayNameCustomizedKey)
                }
            }
            defaults.set(template.note, forKey: template.id.noteKey)
            defaults.set(template.colorHex, forKey: template.id.colorHexKey)
            defaults.set(template.startTime, forKey: template.id.startTimeKey)
            defaults.set(template.endTime, forKey: template.id.endTimeKey)
            defaults.set(template.enabled, forKey: template.id.enabledKey)
            
            // 保存自定义班次的 UUID，确保可以正确加载
            if case .custom(let uuid) = template.id {
                defaults.set(uuid.uuidString, forKey: template.id.uuidStorageKey)
            }
        }
    }
}


struct ShiftToggleActiveButtonStyle: ButtonStyle {
    static let workAction = ShiftToggleActiveButtonStyle(
        width: 88,
        height: 32,
        cornerRadius: 8,
        font: .subheadline.weight(.semibold)
    )

    var backgroundColor: Color = .blue
    var width: CGFloat = 44
    var height: CGFloat = 28
    var cornerRadius: CGFloat = 6
    var font: Font = .caption.weight(.semibold)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundColor(.white)
            .frame(width: width, height: height)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct ShiftTimeSettingsRow: View {
    let template: ShiftTimeTemplate
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onDelete: (ShiftTimeTemplate) -> Void
    let onEdit: () -> Void
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                // Shift Name: 优先显示 displayName，为空时 fallback 到本地化名称
                if !template.displayName.isEmpty {
                    Text(template.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                } else {
                    Text(localization.localized(template.nameKey))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }

                // Time Range
                Text(template.displayTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .accessibilityIdentifier("shiftTemplate.time")
            }

            Spacer()

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundColor(ShiftCalendarColors.accentYellow)
            }
            .accessibilityLabel(
                localization.localized(isFavorite ? .shiftTemplateUnfavorite : .shiftTemplateFavorite)
            )
            .accessibilityIdentifier(
                isFavorite ? "shiftTemplate.unfavorite" : "shiftTemplate.favorite"
            )
            .accessibilityValue(template.displayName)

            // Edit Button
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
            .accessibilityIdentifier("shiftTemplate.edit")
            .accessibilityValue(template.displayName)

            // Delete Button
            Button(action: { onDelete(template) }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .accessibilityIdentifier("shiftTemplate.delete")
            .accessibilityValue(template.displayName)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

private enum ShiftTimePickerTarget: Hashable {
    case start
    case end
}

private enum ShiftTemplateFocusedField: Hashable {
    case name
    case note
}

private struct ShiftTimeEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager

    let shiftID: ShiftTimeTemplateID
    let isNew: Bool
    let onSave: (ShiftTimeTemplate) -> Void

    @State private var displayName: String
    @State private var note: String
    @State private var color: Color
    @State private var startTime: String
    @State private var endTime: String
    @State private var isEnabled: Bool
    @State private var isDetailsExpanded = false
    @State private var showsValidationError = false
    @State private var editingTime: ShiftTimePickerTarget?
    @FocusState private var focusedField: ShiftTemplateFocusedField?
    private let initialDisplayName: String
    private let initialUsesLocalizedDefaultName: Bool

    init(shiftID: ShiftTimeTemplateID, isNew: Bool = false, onSave: @escaping (ShiftTimeTemplate) -> Void) {
        self.shiftID = shiftID
        self.isNew = isNew
        self.onSave = onSave
        let defaults = UserDefaults.standard
        let existingTemplate = ShiftTimeTemplate.all(from: defaults).first { $0.id == shiftID }
        let initialDisplayName = isNew
            ? LocalizationManager.shared.localized(.shiftTimeNewShiftName)
            : (existingTemplate?.displayName ?? shiftID.defaultDisplayName)
        self.initialDisplayName = initialDisplayName
        self.initialUsesLocalizedDefaultName = existingTemplate?.usesLocalizedDefaultName ?? false
        _displayName = State(initialValue: initialDisplayName)
        _note = State(initialValue: existingTemplate?.note ?? "")
        let defaultHex = existingTemplate?.colorHex ?? shiftID.defaultColorHex
        _color = State(initialValue: Color(hex: defaultHex) ?? .blue)
        _startTime = State(initialValue: existingTemplate?.startTime ?? shiftID.defaultStartTime)
        _endTime = State(initialValue: existingTemplate?.endTime ?? shiftID.defaultEndTime)
        _isEnabled = State(initialValue: existingTemplate?.enabled ?? true)
    }

    var body: some View {
        ZStack {
            NavigationStack {
                Form {
                    // Core fields stay visible for the shortest template-creation path.
                    Section {
                        TextField(localization.localized(.editorTitle), text: $displayName)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                            .accessibilityIdentifier("shiftTemplate.name")
                    }

                    // 时间
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(localization.localized(.shiftTimeStartTime))
                                    .font(.subheadline)
                                Spacer()
                                timePickerButton(value: startTime, target: .start)
                            }

                            HStack {
                                Text(localization.localized(.shiftTimeEndTime))
                                    .font(.subheadline)
                                Spacer()
                                timePickerButton(value: endTime, target: .end)
                            }
                        }
                        .padding(.vertical, 8)
                    } footer: {
                        Text(localization.localized(.shiftTimeEditFooter))
                    }

                    Section {
                        HStack {
                            Text(localization.localized(.shiftTimeColor))
                            Spacer()
                            ColorPicker("", selection: $color)
                                .accessibilityLabel(localization.localized(.shiftTimeColor))
                                .accessibilityValue(color.toHex().uppercased())
                                .accessibilityIdentifier("shiftTemplate.colorPicker")
                        }
                    }

                    Section {
                        Button {
                            focusedField = nil
                            withAnimation {
                                isDetailsExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text(localization.localized(.shiftTimeDetails))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                                    .rotationEffect(.degrees(isDetailsExpanded ? 90 : 0))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(localization.localized(
                            isDetailsExpanded ? .shiftTimeDetailsCollapse : .shiftTimeDetailsExpand
                        ))
                        .accessibilityIdentifier("shiftTemplate.details.toggle")

                        if isDetailsExpanded {
                            TextField(localization.localized(.editorNote), text: $note, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(1...5)
                                .focused($focusedField, equals: .note)
                                .accessibilityLabel(localization.localized(.editorNote))
                                .accessibilityIdentifier("shiftTemplate.note")

                            Toggle(localization.localized(.shiftEnabled), isOn: $isEnabled)
                                .accessibilityIdentifier("shiftTemplate.enabled")
                        }
                    }
                }
                .scrollDismissesKeyboard(.immediately)
                .navigationTitle(localization.localized(.shiftTimeEditTitle))
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(localization.localized(.cancel)) {
                            dismiss()
                        }
                        .accessibilityIdentifier("shiftTemplate.edit.cancel")
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button(localization.localized(.save)) {
                            save()
                        }
                        .accessibilityIdentifier("shiftTemplate.edit.save")
                    }

                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(localization.localized(.done)) {
                            focusedField = nil
                        }
                        .accessibilityIdentifier("shiftTemplate.keyboard.done")
                    }
                }
                .alert(localization.localized(.editorError), isPresented: $showsValidationError) {
                    Button(localization.localized(.ok), role: .cancel) {}
                } message: {
                    Text(localization.localized(.validationTitleRequired))
                }
            }

            timePickerOverlay
        }
    }

    private func timePickerButton(value: String, target: ShiftTimePickerTarget) -> some View {
        Button {
            editingTime = target
        } label: {
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundColor(TimeNestTheme.primaryText)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .glassCapsuleStyle()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
            target == .start ? "shiftTemplate.startTime" : "shiftTemplate.endTime"
        )
    }

    @ViewBuilder
    private var timePickerOverlay: some View {
        if let target = editingTime {
            FloatingPickerOverlay(onDismiss: { editingTime = nil }) {
                FloatingDatePickerPanel(
                    title: pickerTitle(for: target),
                    initialSelection: pickerDate(for: target),
                    cancelTitle: localization.localized(.cancel),
                    doneTitle: localization.localized(.done),
                    kind: .time,
                    confirmColor: ShiftCalendarColors.primaryBlue,
                    onCancel: { editingTime = nil },
                    onDone: { selection in
                        applyPickerSelection(selection, to: target)
                        editingTime = nil
                    }
                )
                .id(target)
            }
        }
    }

    private func pickerTitle(for target: ShiftTimePickerTarget) -> String {
        switch target {
        case .start:
            return localization.localized(.shiftTimeStartTime)
        case .end:
            return localization.localized(.shiftTimeEndTime)
        }
    }

    private func pickerDate(for target: ShiftTimePickerTarget) -> Date {
        switch target {
        case .start:
            return ShiftTimeTemplate.date(from: startTime)
        case .end:
            return ShiftTimeTemplate.date(from: endTime)
        }
    }

    private func applyPickerSelection(_ selection: Date, to target: ShiftTimePickerTarget) {
        let normalizedTime = ShiftTimeTemplate.normalizedTimeString(from: selection)
        switch target {
        case .start:
            startTime = normalizedTime
        case .end:
            endTime = normalizedTime
        }
    }

    private func save() {
        // 标题不能为空
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showsValidationError = true
            return
        }
        
        let colorHex = color.toHex()
        let normalizedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let usesLocalizedDefaultName = initialUsesLocalizedDefaultName
            && normalizedDisplayName == initialDisplayName

        let template = ShiftTimeTemplate(
            id: shiftID,
            nameKey: shiftID.nameKey,
            displayName: normalizedDisplayName,
            note: note,
            colorHex: colorHex,
            startTime: startTime,
            endTime: endTime,
            enabled: isEnabled,
            usesLocalizedDefaultName: usesLocalizedDefaultName
        )
        onSave(template)
        dismiss()
    }
}
