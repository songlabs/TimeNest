import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var localization: LocalizationManager
    private let calendarDisplayUseCase: CalendarDisplayUseCase
    private let eventUseCase: EventUseCase
    private let holidaySubscriptionManager: HolidaySubscriptionManager

    init(
        calendarDisplayUseCase: CalendarDisplayUseCase,
        eventUseCase: EventUseCase,
        holidaySubscriptionManager: HolidaySubscriptionManager
    ) {
        self.calendarDisplayUseCase = calendarDisplayUseCase
        self.eventUseCase = eventUseCase
        self.holidaySubscriptionManager = holidaySubscriptionManager
    }

    var body: some View {
        MonthCalendarView(
            calendarDisplayUseCase: calendarDisplayUseCase,
            eventUseCase: eventUseCase,
            holidaySubscriptionManager: holidaySubscriptionManager
        )
        .environmentObject(localization)
        .onOpenURL { url in
            guard let date = TimeNestWidgetDeepLink.date(from: url) else { return }
            NotificationCenter.default.post(name: .widgetCalendarDateRequested, object: date)
        }
    }
}
