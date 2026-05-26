import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @StateObject private var tabBarVisibility = TabBarVisibilityState.shared
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
            // 语言变化时强制刷新整个内容区域
            .id(localization.selectedLanguageCode)

            // 自定义底部 TabBar - 固定在底部
            if !tabBarVisibility.isHidden {
                BottomTabBarView(selectedTab: $selectedTab)
            }
        }
    }
}

/// Tab 内容切换视图
struct TabSelectionView<Content: View>: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Binding var selectedTab: CalendarTab
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            switch selectedTab {
            case .monthCalendar:
                content
            case .listCalendar:
                ListPlaceholderView(titleKey: .listCalendar)
            case .shiftInput:
                ListPlaceholderView(titleKey: .shiftInput)
            case .shiftShare:
                ListPlaceholderView(titleKey: .shiftShare)
            case .settings:
                NavigationView {
                    SettingsView()
                        .environmentObject(localization)
                }
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
    .environmentObject(LocalizationManager.preview(languageCode: "ja"))
}
