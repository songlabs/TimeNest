import SwiftUI

@main
struct TimeNestApp: App {
    private let eventRepository: EventRepository = InMemoryEventRepository()
    private let reminderRepository: ReminderRepository = InMemoryReminderRepository()
    private let reminderScheduler: ReminderScheduling = MockReminderScheduler()
    private let holidayProvider: HolidayProviding = BundleHolidayProvider()

    private let eventUseCase: EventUseCase
    private let reminderUseCase: ReminderUseCase
    private let calendarDisplayUseCase: CalendarDisplayUseCase
    private let holidayUseCase: HolidayUseCase
    private let localizationUseCase: CalendarLocalizationUseCase

    init() {
        self.eventUseCase = EventUseCase(repository: eventRepository)
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

    var body: some Scene {
        WindowGroup {
            ContentView(
                calendarDisplayUseCase: calendarDisplayUseCase,
                eventUseCase: eventUseCase
            )
        }
    }
}
