import GoogleMobileAds
import SwiftData
import SwiftUI

@main
struct TimeNestApp: App {
    private let modelContainer: ModelContainer
    private let eventRepository: EventRepository
    private let reminderRepository: ReminderRepository
    private let reminderScheduler: ReminderScheduling = MockReminderScheduler()
    private let holidayProvider: HolidayProviding = BundleHolidayProvider()
    private let notificationScheduler: LocalNotificationScheduling = LocalNotificationService()

    private let eventUseCase: EventUseCase
    private let reminderUseCase: ReminderUseCase
    private let calendarDisplayUseCase: CalendarDisplayUseCase
    private let holidayUseCase: HolidayUseCase
    private let localizationUseCase: CalendarLocalizationUseCase

    init() {
        Self.configureAdsIfNeeded()

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
        self.eventUseCase = EventUseCase(
            repository: eventRepository,
            notificationScheduler: notificationScheduler
        )
        self.reminderUseCase = ReminderUseCase(
            reminderRepository: reminderRepository,
            reminderScheduler: reminderScheduler
        )
        self.holidayUseCase = HolidayUseCase(holidayProvider: holidayProvider)
        self.localizationUseCase = CalendarLocalizationUseCase()
        self.calendarDisplayUseCase = CalendarDisplayUseCase(
            holidayUseCase: holidayUseCase,
            localizationUseCase: localizationUseCase,
            eventUseCase: eventUseCase
        )
    }

    private static func configureAdsIfNeeded() {
        guard AdConfiguration.isEnabled else { return }
        MobileAds.shared.start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                calendarDisplayUseCase: calendarDisplayUseCase,
                eventUseCase: eventUseCase
            )
            .environmentObject(LocalizationManager.shared)
            .modelContainer(modelContainer)
        }
    }
}
