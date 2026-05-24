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

    private var languageObserver: AnyCancellable?

    private var notificationObservers: [AnyCancellable] = []
    init(
        calendarDisplayUseCase: CalendarDisplayUseCase,
        eventUseCase: EventUseCase
    ) {
        self.calendarDisplayUseCase = calendarDisplayUseCase
        self.eventUseCase = eventUseCase
        
        // 初始化时从 LocalizationManager 读取当前语言
        let initialLanguage = LocalizationManager.shared.currentLanguage
        self.currentSetting = .init(
            displayLanguage: initialLanguage,
            selectedHolidayRegions: [.japan],
            weekStartPolicy: .system,
            showLunarCalendar: false
        )

        // 监听 LocalizationManager 的语言变化
        setupLanguageObserver()
        // 监听节假日订阅变化
        setupNotificationObserver()
    }

    private func setupLanguageObserver() {
        languageObserver = LocalizationManager.shared.$selectedLanguageCode
            .sink { [weak self] _ in
                Task { @MainActor in await 
                    self?.updateDisplayLanguage()
                }
            }
    }

    private func setupNotificationObserver() {
        notificationObservers = [
            NotificationCenter.default.publisher(for: .holidaySubscriptionsDidChange)
                .sink { [weak self] _ in
                    Task { @MainActor in
                        await self?.reloadMonth()
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
            // 不添加 mock 排班数据，shift 内容应由用户输入
            grid = baseGrid
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
