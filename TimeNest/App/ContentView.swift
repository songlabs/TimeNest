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

// MARK: - Preview

#if DEBUG
#Preview {
    ContentView(
        calendarDisplayUseCase: CalendarDisplayUseCase(
            holidayUseCase: HolidayUseCase(holidayProvider: BundleHolidayProvider()),
            localizationUseCase: CalendarLocalizationUseCase(),
            eventUseCase: EventUseCase(repository: InMemoryEventRepository())
        ),
        eventUseCase: EventUseCase(repository: InMemoryEventRepository())
    )
    .environmentObject(LocalizationManager.preview(languageCode: "ja"))
}
#endif
