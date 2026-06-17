import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var localization: LocalizationManager
    private let calendarDisplayUseCase: CalendarDisplayUseCase
    private let eventUseCase: EventUseCase

    init(
        calendarDisplayUseCase: CalendarDisplayUseCase,
        eventUseCase: EventUseCase
    ) {
        self.calendarDisplayUseCase = calendarDisplayUseCase
        self.eventUseCase = eventUseCase
    }

    var body: some View {
        MonthCalendarView(
            calendarDisplayUseCase: calendarDisplayUseCase,
            eventUseCase: eventUseCase
        )
        .environmentObject(localization)
    }
}
