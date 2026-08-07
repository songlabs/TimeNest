import Foundation
import SwiftData
import SwiftUI

struct ModelContainerPreparation {
    let container: ModelContainer
    let legacyMigrationOutcome: LegacyStoreMigrator.Outcome
}

enum AppDataStartupState: Equatable {
    case ready
    case legacyStoreMigrationFailed
    case calendarDataMigrationFailed

    static func resolve(
        legacyOutcome: LegacyStoreMigrator.Outcome,
        calendarMigrationFailed: Bool
    ) -> AppDataStartupState {
        guard legacyOutcome.allowsWritableAppStartup else {
            return .legacyStoreMigrationFailed
        }
        return calendarMigrationFailed ? .calendarDataMigrationFailed : .ready
    }

    var blocksWritableUI: Bool {
        self == .legacyStoreMigrationFailed
    }
}

@main
struct TimeNestApp: App {
    @UIApplicationDelegateAdaptor(TimeNestAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("themeMode") private var themeMode: String = "system"
    @StateObject private var calendarSharingStore: CalendarSharingStore

    private let modelContainer: ModelContainer
    private let eventRepository: EventRepository
    private let calendarRepository: CalendarRepository
    private let reminderRepository: ReminderRepository
    private let reminderScheduler: ReminderScheduling = NoopReminderScheduler()
    private let holidayProvider: HolidayProviding = BundleHolidayProvider()
    private let notificationScheduler: LocalNotificationScheduling = LocalNotificationService()
    private let dataStartupState: AppDataStartupState

    private let eventUseCase: EventUseCase
    private let reminderUseCase: ReminderUseCase
    private let calendarDisplayUseCase: CalendarDisplayUseCase
    private let holidayUseCase: HolidayUseCase
    private let holidaySubscriptionManager: HolidaySubscriptionManager
    private let localizationUseCase: CalendarLocalizationUseCase
    private let widgetSnapshotCoordinator: WidgetSnapshotCoordinator

    init() {
#if DEBUG
        TimeNestUITestSupport.configureDefaults()
#endif
        let schema = Schema([
            SwiftDataCalendarEventEntity.self,
            SwiftDataReminderEntity.self,
            SwiftDataCalendarEntity.self,
            SwiftDataOwnerSharedEventMutationEntity.self
        ])
        let modelPreparation: ModelContainerPreparation
        do {
#if DEBUG
            if TimeNestUITestSupport.isEnabled {
                modelPreparation = try TimeNestUITestSupport.makeModelPreparation(schema: schema)
            } else {
                modelPreparation = try Self.makeModelContainer(schema: schema)
            }
#else
            modelPreparation = try Self.makeModelContainer(schema: schema)
#endif
            modelContainer = modelPreparation.container
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
        var calendarMigrationFailed = false
        if modelPreparation.legacyMigrationOutcome.allowsWritableAppStartup {
            do {
                let migrationResult = try CalendarDataMigrator.migrate(
                    container: modelContainer,
                    personalCalendarName: LocalizationManager.shared.localized(.calendarSharingMyCalendar)
                )
                Self.debugLog(
                    "Calendar migration v\(CalendarDataMigrator.currentVersion): "
                        + "createdPersonal=\(migrationResult.createdPersonalCalendar), "
                        + "migratedEvents=\(migrationResult.migratedEventCount)"
                )
            } catch {
                calendarMigrationFailed = true
                Self.debugLog("Calendar migration failed without deleting source data: \(error)")
            }
        }
        dataStartupState = AppDataStartupState.resolve(
            legacyOutcome: modelPreparation.legacyMigrationOutcome,
            calendarMigrationFailed: calendarMigrationFailed
        )
#if DEBUG
        do {
            try TimeNestUITestSupport.seedDataManagementScenario(in: modelContainer)
            try TimeNestUITestSupport.seedUnifiedEntryScenario(in: modelContainer)
        } catch {
            fatalError("Failed to seed UI test data: \(error)")
        }
#endif

        let eventRepository = SwiftDataEventRepository(modelContainer: modelContainer)
        let calendarRepository = SwiftDataCalendarRepository(modelContainer: modelContainer)
        let reminderRepository = SwiftDataReminderRepository(modelContainer: modelContainer)
        self.eventRepository = eventRepository
        self.calendarRepository = calendarRepository
        self.reminderRepository = reminderRepository
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            notificationScheduler: notificationScheduler,
            calendarRepository: calendarRepository
        )
        self.eventUseCase = eventUseCase
        let reminderUseCase = ReminderUseCase(
            reminderRepository: reminderRepository,
            reminderScheduler: reminderScheduler
        )
        self.reminderUseCase = reminderUseCase
        let holidayCacheRepository = HolidayEventCacheRepository.shared
        let holidaySubscriptionManager = HolidaySubscriptionManager(
            cacheRepository: holidayCacheRepository
        )
        self.holidaySubscriptionManager = holidaySubscriptionManager
        let holidayUseCase = HolidayUseCase(
            holidayProvider: holidayProvider,
            cacheRepository: holidayCacheRepository
        )
        self.holidayUseCase = holidayUseCase
        let localizationUseCase = CalendarLocalizationUseCase()
        self.localizationUseCase = localizationUseCase
        let calendarDisplayUseCase = CalendarDisplayUseCase(
            holidayUseCase: holidayUseCase,
            localizationUseCase: localizationUseCase,
            eventUseCase: eventUseCase
        )
        self.calendarDisplayUseCase = calendarDisplayUseCase
        let snapshotBuilder = WidgetSnapshotBuilder(
            calendarDisplayUseCase: calendarDisplayUseCase,
            eventUseCase: eventUseCase,
            holidayUseCase: holidayUseCase,
            holidaySubscriptionManager: holidaySubscriptionManager
        )
        let snapshotCoordinator = WidgetSnapshotCoordinator(builder: snapshotBuilder)
        self.widgetSnapshotCoordinator = snapshotCoordinator
#if DEBUG
        let sharingClient: any CalendarSharingClientProtocol = TimeNestUITestSupport.isEnabled
            ? TimeNestUITestSupport.makeCalendarSharingClient()
            : CloudKitCalendarSharingClient()
        let sharingCache = TimeNestUITestSupport.isEnabled
            ? CalendarSharingCache(
                fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(
                    "TimeNestUITestSharingCache-\(ProcessInfo.processInfo.processIdentifier).json"
                )
            )
            : CalendarSharingCache()
        let sharedEventEditingPersistence = TimeNestUITestSupport.isEnabled
            ? SharedEventEditingPersistence(
                fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(
                    "TimeNestUITestSharedEvents-\(ProcessInfo.processInfo.processIdentifier).json"
                )
            )
            : SharedEventEditingPersistence()
#else
        let sharingClient: any CalendarSharingClientProtocol = CloudKitCalendarSharingClient()
        let sharingCache = CalendarSharingCache()
        let sharedEventEditingPersistence = SharedEventEditingPersistence()
#endif
        let calendarSharingStore = CalendarSharingStore(
            client: sharingClient,
            eventUseCase: eventUseCase,
            calendarRepository: calendarRepository,
            cache: sharingCache,
            sharedEventEditingPersistence: sharedEventEditingPersistence,
            initialMigrationError: calendarMigrationFailed
                ? .calendarDataMigrationFailed
                : nil
        )
        _calendarSharingStore = StateObject(wrappedValue: calendarSharingStore)
        eventUseCase.onEventsChanged = {
            Task { @MainActor in
                snapshotCoordinator.scheduleRefresh()
                await calendarSharingStore.synchronizeOwnedEventsIfNeeded()
            }
        }
        eventUseCase.onRemoteEventsMaterialized = {
            Task { @MainActor in
                snapshotCoordinator.scheduleRefresh()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    @ViewBuilder
    private var rootView: some View {
#if DEBUG
        if let scene = AppStoreScreenshotMode.requestedScene {
            AppStoreScreenshotRootView(scene: scene)
                .preferredColorScheme(.light)
                .environmentObject(LocalizationManager.shared)
                .onAppear {
                    AppStoreScreenshotMode.configureEnvironment()
                }
        } else {
            productionRootView
        }
#else
        productionRootView
#endif
    }

    private var productionRootView: some View {
        Group {
            if dataStartupState.blocksWritableUI {
                LegacyStoreMigrationFailureView()
            } else {
                ContentView(
                    calendarDisplayUseCase: calendarDisplayUseCase,
                    eventUseCase: eventUseCase,
                    holidaySubscriptionManager: holidaySubscriptionManager,
                    calendarSharingStore: calendarSharingStore
                )
                .task {
#if DEBUG
                    guard !TimeNestUITestSupport.suppressesStartupSideEffects else { return }
#endif
                    await notificationScheduler.requestAuthorizationOnFirstLaunchIfNeeded()
                }
                .task {
#if DEBUG
                    guard !TimeNestUITestSupport.suppressesStartupSideEffects else { return }
#endif
                    RemoveAdsPurchaseManager.shared.startObservingTransactionUpdates()
                    let isAdsRemoved = await RemoveAdsPurchaseManager.shared.refreshPurchasedState(
                        context: "app startup"
                    )
                    if !isAdsRemoved {
                        AdConsentManager.shared.requestConsentInfoIfNeeded()
                    }
                }
                .task {
#if DEBUG
                    guard !TimeNestUITestSupport.suppressesStartupSideEffects else { return }
#endif
                    await widgetSnapshotCoordinator.refresh()
                }
                .task {
#if DEBUG
                    guard !TimeNestUITestSupport.suppressesStartupSideEffects else { return }
#endif
                    await holidaySubscriptionManager.performAutoSync()
                }
                .task {
                    await calendarSharingStore.start()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task { await calendarSharingStore.synchronizeOnAppActivation() }
                    Task {
#if DEBUG
                        guard !TimeNestUITestSupport.suppressesStartupSideEffects else { return }
#endif
                        await holidaySubscriptionManager.performAutoSync()
                    }
                }
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .environmentObject(LocalizationManager.shared)
        .environmentObject(calendarSharingStore)
        .modelContainer(modelContainer)
        .overlay {
            if calendarSharingStore.isAcceptingInvitation {
                ZStack {
                    Color.black.opacity(0.18).ignoresSafeArea()
                    ProgressView(
                        LocalizationManager.shared.localized(.calendarSharingInvitationPreparing)
                    )
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
                .allowsHitTesting(true)
            }
        }
        .alert(
            LocalizationManager.shared.localized(.calendarSharingErrorTitle),
            isPresented: Binding(
                get: { calendarSharingStore.invitationAcceptanceError != nil },
                set: { if !$0 { calendarSharingStore.clearInvitationAcceptanceError() } }
            )
        ) {
            Button(LocalizationManager.shared.localized(.ok)) {
                calendarSharingStore.clearInvitationAcceptanceError()
            }
        } message: {
            Text(calendarSharingStore.invitationAcceptanceError?.localizedDescription ?? "")
        }
    }

    static func makeModelContainer(schema: Schema) throws -> ModelContainerPreparation {
        let appGroupID = LegacyStoreMigrator.appGroupIdentifier
        guard let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            throw AppGroupStoreError.containerUnavailable(appGroupID)
        }

        let applicationSupportURL = appGroupURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
        try FileManager.default.createDirectory(
            at: applicationSupportURL,
            withIntermediateDirectories: true
        )

        var isDirectory: ObjCBool = false
        let parentExists = FileManager.default.fileExists(
            atPath: applicationSupportURL.path,
            isDirectory: &isDirectory
        )
        guard parentExists, isDirectory.boolValue else {
            throw AppGroupStoreError.applicationSupportDirectoryMissing(applicationSupportURL)
        }

        let storeURL = LegacyStoreMigrator.destinationStoreURL(
            appGroupContainerURL: appGroupURL
        )
        let legacyApplicationSupportURL = URL.applicationSupportDirectory
        let legacyStoreURL = legacyApplicationSupportURL.appendingPathComponent(
            LegacyStoreMigrator.storeFileName,
            isDirectory: false
        )
        let markerURL = applicationSupportURL.appendingPathComponent(
            LegacyStoreMigrator.markerFileName,
            isDirectory: false
        )
        debugLog("SwiftData store parent exists: \(parentExists), isDirectory: \(isDirectory.boolValue)")

        let preparation = try LegacyStoreMigrator.prepareModelContainer(
            schema: schema,
            legacyStoreURL: legacyStoreURL,
            destinationStoreURL: storeURL,
            markerURL: markerURL
        )
        debugLog(preparation.outcome.logSummary)
        return ModelContainerPreparation(
            container: preparation.container,
            legacyMigrationOutcome: preparation.outcome
        )
    }

    private static func debugLog(_ message: @autoclosure () -> String) {
#if DEBUG
        print("[TimeNestApp] \(message())")
#endif
    }

    private var preferredColorScheme: ColorScheme? {
        switch themeMode {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
}

private struct LegacyStoreMigrationFailureView: View {
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text(localization.localized(.calendarSharingLegacyStoreMigrationFailed))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

private enum AppGroupStoreError: LocalizedError {
    case containerUnavailable(String)
    case applicationSupportDirectoryMissing(URL)

    var errorDescription: String? {
        switch self {
        case .containerUnavailable:
            "App Group container is unavailable."
        case .applicationSupportDirectoryMissing:
            "SwiftData Application Support directory is unavailable."
        }
    }
}
