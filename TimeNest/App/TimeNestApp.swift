import GoogleMobileAds
import SwiftUI

@main
struct TimeNestApp: App {
    private let eventRepository: EventRepository = InMemoryEventRepository.shared
    private let reminderRepository: ReminderRepository = InMemoryReminderRepository.shared
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
        }
    }
}
