import SwiftData
import SwiftUI

@main
struct TimeNestApp: App {
    @AppStorage("themeMode") private var themeMode: String = "system"

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
        let configuration = ModelConfiguration(
            "TimeNest",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
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
        eventUseCase.onEventsChanged = {
            Task { @MainActor in
                snapshotCoordinator.scheduleRefresh()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                calendarDisplayUseCase: calendarDisplayUseCase,
                eventUseCase: eventUseCase,
                holidaySubscriptionManager: holidaySubscriptionManager
            )
            .preferredColorScheme(preferredColorScheme)
            .environmentObject(LocalizationManager.shared)
            .modelContainer(modelContainer)
            .task {
                await notificationScheduler.requestAuthorizationOnFirstLaunchIfNeeded()
            }
            .task {
                RemoveAdsPurchaseManager.shared.startObservingTransactionUpdates()
                await RemoveAdsPurchaseManager.shared.refreshPurchasedState()
            }
            .task {
                AdConsentManager.shared.requestConsentInfoIfNeeded()
                await widgetSnapshotCoordinator.refresh()
            }
        }
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
