import SwiftUI

struct ContentView: View {
    private let calendarDisplayUseCase: CalendarDisplayUseCase
    private let eventUseCase: EventUseCase
    @State private var selectedTab: CalendarTab = .monthCalendar

    init(
        calendarDisplayUseCase: CalendarDisplayUseCase,
        eventUseCase: EventUseCase
    ) {
        self.calendarDisplayUseCase = calendarDisplayUseCase
        self.eventUseCase = eventUseCase
    }

    var body: some View {
        VStack(spacing: 0) {
            // 内容区域 - 占据剩余空间
            TabSelectionView(selectedTab: $selectedTab) {
                MonthCalendarView(
                    calendarDisplayUseCase: calendarDisplayUseCase,
                    eventUseCase: eventUseCase
                )
            }

            // 自定义底部 TabBar - 固定在底部
            BottomTabBarView(selectedTab: $selectedTab)
        }
    }
}

/// Tab 内容切换视图
struct TabSelectionView<Content: View>: View {
    @Binding var selectedTab: CalendarTab
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            switch selectedTab {
            case .monthCalendar:
                content
            default:
                // 其他 Tab 暂时显示占位
                Color.black.opacity(0.1)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView(
        calendarDisplayUseCase: CalendarDisplayUseCase(
            holidayUseCase: HolidayUseCase(holidayProvider: BundleHolidayProvider()),
            localizationUseCase: CalendarLocalizationUseCase(),
            eventUseCase: EventUseCase(repository: InMemoryEventRepository())
        ),
        eventUseCase: EventUseCase(repository: InMemoryEventRepository())
    )
}
