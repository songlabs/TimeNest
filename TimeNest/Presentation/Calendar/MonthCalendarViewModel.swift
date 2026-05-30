import Foundation
import SwiftUI
import Combine

@MainActor
class MonthCalendarViewModel: ObservableObject {
    @Published private(set) var selectedDate: Date = Date()
    @Published private(set) var grid: MonthGrid?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published var showingEventEditor: Bool = false
    @Published var selectedDayCell: CalendarDayCell?
    @Published var showingDayDetail: Bool = false

    private let calendarDisplayUseCase: CalendarDisplayUseCase
    private let eventUseCase: EventUseCase
    private var currentSetting: CalendarDisplaySetting
    private let subscriptionManager: HolidaySubscriptionManager

    private var languageObserver: AnyCancellable?
    private var subscriptionObserver: AnyCancellable?

    private var notificationObservers: [AnyCancellable] = []
    init(
        calendarDisplayUseCase: CalendarDisplayUseCase,
        eventUseCase: EventUseCase,
        subscriptionManager: HolidaySubscriptionManager? = nil
    ) {
        self.calendarDisplayUseCase = calendarDisplayUseCase
        self.eventUseCase = eventUseCase
        self.subscriptionManager = subscriptionManager ?? .shared

        // 初始化时从 LocalizationManager 读取当前语言，从订阅管理器读取已启用的地区
        let initialLanguage = LocalizationManager.shared.currentLanguage
        let enabledRegions = self.subscriptionManager.enabledRegions  // 允许空数组

        self.currentSetting = .init(
            displayLanguage: initialLanguage,
            selectedHolidayRegions: enabledRegions,
            weekStartPolicy: .system,
            showLunarCalendar: false
        )

        // 监听 LocalizationManager 的语言变化
        setupLanguageObserver()
        // 监听节假日订阅变化
        setupNotificationObserver()
        // 监听订阅管理器的 region 变化
        setupSubscriptionObserver()
    }

    private func setupLanguageObserver() {
        languageObserver = LocalizationManager.shared.$selectedLanguageCode
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateDisplayLanguage()
                }
            }
    }

    private func setupNotificationObserver() {
        notificationObservers = [
            NotificationCenter.default.publisher(for: .holidaySubscriptionsDidChange)
                .sink { [weak self] _ in
                    Task { @MainActor in
                        await self?.syncHolidayRegionsAndReload()
                    }
                },
            NotificationCenter.default.publisher(for: .holidayEventsDidUpdate)
                .sink { [weak self] _ in
                    Task { @MainActor in
                        await self?.reloadMonth()
                    }
                }
        ]
    }

    private func setupSubscriptionObserver() {
        // 移除 subscriptionObserver，统一使用 notification observer
        // 避免两个 observer 同时触发导致状态不同步
        subscriptionObserver = nil
    }

    /// 同步节假日地区并重新加载月份（统一入口）
    private func syncHolidayRegionsAndReload() async {
        let newRegions = subscriptionManager.enabledRegions

        currentSetting.selectedHolidayRegions = newRegions
        await reloadMonth()
    }

    private func updateDisplayLanguage() {
        let newLanguage = LocalizationManager.shared.currentLanguage
        if currentSetting.displayLanguage != newLanguage {
            currentSetting.displayLanguage = newLanguage
            Task {
                await reloadMonth()
            }
        }
    }

    func reloadMonth() async {
        isLoading = true
        errorMessage = nil

        // 使用 Gregorian calendar 确保年份显示为西历（2026 年而不是令和 8 年）
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)

        do {
            let baseGrid = try await calendarDisplayUseCase.monthGrid(
                year: year,
                month: month,
                setting: currentSetting
            )
            // 完全替换旧的 grid，不要 append / merge
            self.grid = baseGrid

        } catch {
            errorMessage = error.localizedDescription
            grid = nil

        }

        isLoading = false
    }

    /// 获取当前月份的本地化标题
    func monthTitle() -> String {
        LocalizationManager.shared.monthTitle(for: selectedDate)
    }

    /// 获取当前语言对应的星期符号数组
    func weekdaySymbols() -> [String] {
        let weekStartPolicy: WeekStartPolicy = currentSetting.weekStartPolicy == .monday ? .monday : .sunday
        return LocalizationManager.shared.shortWeekdaySymbols(weekStartPolicy: weekStartPolicy)
    }

    func goToPreviousMonth() async {
        let calendar = Calendar(identifier: .gregorian)
        if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
            selectedDate = newDate
            await reloadMonth()
        }
    }

    func goToNextMonth() async {
        let calendar = Calendar(identifier: .gregorian)
        if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) {
            selectedDate = newDate
            await reloadMonth()
        }
    }

    func goToToday() async {
        selectedDate = Date()
        await reloadMonth()
    }

    func goToMonth(year: Int, month: Int) async {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        if let newDate = calendar.date(from: components) {
            selectedDate = newDate
            await reloadMonth()
        }
    }

    func createEvent(title: String, date: Date, isAllDay: Bool) async throws {
        let calendar = Calendar(identifier: .gregorian)
        let startDate: Date
        let endDate: Date?

        if isAllDay {
            // 全天事件：从当日 00:00 到次日 00:00
            let startComponents = calendar.dateComponents([.year, .month, .day], from: date)
            startDate = calendar.date(from: startComponents) ?? date
            endDate = calendar.date(byAdding: .day, value: 1, to: startDate)
        } else {
            // 非全天：默认 1 小时
            startDate = date
            endDate = calendar.date(byAdding: .hour, value: 1, to: date)
        }

        let event = CalendarEvent(
            id: UUID(),
            title: title,
            note: nil,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            categoryID: nil,
            recurrenceRule: .none,
            reminderTemplateID: nil,
            importSource: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await eventUseCase.createEvent(event)
        await reloadMonth()
    }

    func selectDay(_ cell: CalendarDayCell) {
        selectedDayCell = cell
        showingDayDetail = true
    }

    func deleteEvent(id: UUID) async {
        do {
            try await eventUseCase.deleteEvent(id: id)
            await reloadMonth()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateEvent(id: UUID, title: String, date: Date, isAllDay: Bool) async {
        do {
            let calendar = Calendar(identifier: .gregorian)
            let startDate: Date
            let endDate: Date?

            if isAllDay {
                let startComponents = calendar.dateComponents([.year, .month, .day], from: date)
                startDate = calendar.date(from: startComponents) ?? date
                endDate = calendar.date(byAdding: .day, value: 1, to: startDate)
            } else {
                startDate = date
                endDate = calendar.date(byAdding: .hour, value: 1, to: date)
            }

            let updatedEvent = CalendarEvent(
                id: id,
                title: title,
                note: nil,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                categoryID: nil,
                recurrenceRule: .none,
                reminderTemplateID: nil,
                importSource: nil,
                createdAt: Date(),
                updatedAt: Date()
            )

            try await eventUseCase.updateEvent(updatedEvent)
            await reloadMonth()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
