import SwiftUI

struct ContentView: View {
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
        TabView {
            NavigationStack {
                MonthCalendarView(
                    calendarDisplayUseCase: calendarDisplayUseCase,
                    eventUseCase: eventUseCase
                )
            }
            .tabItem {
                Label("日历", systemImage: "calendar")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gear")
            }
        }
    }
}

