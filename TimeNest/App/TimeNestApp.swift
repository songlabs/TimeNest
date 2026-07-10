import Foundation
import SwiftData
import SwiftUI

@main
struct TimeNestApp: App {
    @UIApplicationDelegateAdaptor(TimeNestAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("themeMode") private var themeMode: String = "system"
    @StateObject private var calendarSharingStore: CalendarSharingStore

    private let modelContainer: ModelContainer
    private let eventRepository: EventRepository
    private let reminderRepository: ReminderRepository
    private let reminderScheduler: ReminderScheduling = NoopReminderScheduler()
    private let holidayProvider: HolidayProviding = BundleHolidayProvider()
    private let notificationScheduler: LocalNotificationScheduling = LocalNotificationService()

    private let eventUseCase: EventUseCase
    private let reminderUseCase: ReminderUseCase
    private let calendarDisplayUseCase: CalendarDisplayUseCase
    private let holidayUseCase: HolidayUseCase
    private let holidaySubscriptionManager: HolidaySubscriptionManager
    private let localizationUseCase: CalendarLocalizationUseCase
    private let widgetSnapshotCoordinator: WidgetSnapshotCoordinator

    init() {
        let schema = Schema([
            SwiftDataCalendarEventEntity.self,
            SwiftDataReminderEntity.self
        ])
        do {
            let configuration = try Self.makeModelConfiguration(schema: schema)
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }

        let eventRepository = SwiftDataEventRepository(modelContainer: modelContainer)
        let reminderRepository = SwiftDataReminderRepository(modelContainer: modelContainer)
        self.eventRepository = eventRepository
        self.reminderRepository = reminderRepository
        let eventUseCase = EventUseCase(
            repository: eventRepository,
            notificationScheduler: notificationScheduler
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
        let calendarSharingStore = CalendarSharingStore(
            client: CloudKitCalendarSharingClient(),
            eventUseCase: eventUseCase
        )
        _calendarSharingStore = StateObject(wrappedValue: calendarSharingStore)
        eventUseCase.onEventsChanged = {
            Task { @MainActor in
                snapshotCoordinator.scheduleRefresh()
                await calendarSharingStore.synchronizeOwnedEventsIfNeeded()
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
        ContentView(
            calendarDisplayUseCase: calendarDisplayUseCase,
            eventUseCase: eventUseCase,
            holidaySubscriptionManager: holidaySubscriptionManager,
            calendarSharingStore: calendarSharingStore
        )
        .preferredColorScheme(preferredColorScheme)
        .environmentObject(LocalizationManager.shared)
        .environmentObject(calendarSharingStore)
        .modelContainer(modelContainer)
        .task {
            await notificationScheduler.requestAuthorizationOnFirstLaunchIfNeeded()
        }
        .task {
            RemoveAdsPurchaseManager.shared.startObservingTransactionUpdates()
            await RemoveAdsPurchaseManager.shared.refreshPurchasedState(context: "app startup")
        }
        .task {
            AdConsentManager.shared.requestConsentInfoIfNeeded()
            await widgetSnapshotCoordinator.refresh()
        }
        .task {
            await calendarSharingStore.start()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await calendarSharingStore.synchronizeAll() }
        }
    }

    private static func makeModelConfiguration(schema: Schema) throws -> ModelConfiguration {
        let appGroupID = WidgetSnapshotStore.appGroupIdentifier
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

        let storeURL = applicationSupportURL.appendingPathComponent("TimeNest.store", isDirectory: false)
        debugLog("App Group container: \(appGroupURL.path)")
        debugLog("SwiftData store URL: \(storeURL.path)")
        debugLog("SwiftData store parent exists: \(parentExists), isDirectory: \(isDirectory.boolValue)")

        return ModelConfiguration(
            "TimeNest",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
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
