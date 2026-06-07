import Foundation
import SwiftUI
import Combine

@MainActor
class MonthCalendarViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published private(set) var grid: MonthGrid?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published var showingEventEditor: Bool = false
    @Published var selectedDayCell: CalendarDayCell?
    @Published var showingDayDetail: Bool = false
    
    // 视图模式：month / week / day
    @Published var displayMode: CalendarViewMode = .month
    
    // 周视图显示天数：7 / 5 / 3
    @Published var weekDisplayDays: Int = 7
    
    // 周视图的日期单元格（计算属性，从 grid 生成）
    var weekCells: [CalendarDayCell] {
        guard let grid = grid else { return [] }
        return generateWeekCells(for: selectedDate, displayDays: weekDisplayDays)
    }
    
    // 日视图的日期单元格
    var dayCell: CalendarDayCell? {
        guard let grid = grid else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)
        let day = calendar.component(.day, from: selectedDate)
        
        let targetDateOnly = DateOnly(year: year, month: month, day: day)
        return grid.days.first { $0.date == targetDateOnly }
    }

    private let calendarDisplayUseCase: CalendarDisplayUseCase
    private let eventUseCase: EventUseCase
    private var currentSetting: CalendarDisplaySetting
    private let subscriptionManager: HolidaySubscriptionManager

    private var languageObserver: AnyCancellable?
    private var subscriptionObserver: AnyCancellable?
    private var weekStartObserver: AnyCancellable?

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
        let initialWeekStart = WeekStartPolicy(rawValue: UserDefaults.standard.string(forKey: "weekStart") ?? "system") ?? .system

        self.currentSetting = .init(
            displayLanguage: initialLanguage,
            selectedHolidayRegions: enabledRegions,
            weekStartPolicy: initialWeekStart,
            showLunarCalendar: false
        )

        // 监听 LocalizationManager 的语言变化
        setupLanguageObserver()
        // 监听节假日订阅变化
        setupNotificationObserver()
        // 监听订阅管理器的 region 变化
        setupSubscriptionObserver()
        // 监听 weekStart 设置变化
        setupWeekStartObserver()
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

    private func setupWeekStartObserver() {
        // 监听 weekStart AppStorage 变化
        weekStartObserver = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateWeekStartPolicy()
                }
            }
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

    private func updateWeekStartPolicy() {
        let newWeekStart = WeekStartPolicy(rawValue: UserDefaults.standard.string(forKey: "weekStart") ?? "system") ?? .system
        if currentSetting.weekStartPolicy != newWeekStart {
            currentSetting.weekStartPolicy = newWeekStart
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
        return LocalizationManager.shared.shortWeekdaySymbols(weekStartPolicy: currentSetting.weekStartPolicy)
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
    
    // MARK: - 周视图/日视图支持
    
    /// 选择某一天，如果从周视图点击则切换到日视图
    func selectDate(_ date: Date) {
        let calendar = Calendar(identifier: .gregorian)
        
        // 更新 selectedDate
        selectedDate = date
        
        // 切换到日视图
        displayMode = .day
        
        // 重新加载月份数据以更新 grid
        Task {
            await reloadMonth()
        }
    }
    
    /// 切换到周视图
    func switchToWeekView() {
        displayMode = .week
        // 确保周视图数据基于当前加载的 grid
        // 如果 selectedDate 不在 grid 月份中，需要重新加载
        Task {
            await ensureDataLoadedForDate(selectedDate)
        }
    }
    
    /// 切换到日视图
    func switchToDayView() {
        displayMode = .day
        // 确保日视图数据基于当前加载的 grid
        // 如果 selectedDate 不在 grid 月份中，需要重新加载
        Task {
            await ensureDataLoadedForDate(selectedDate)
        }
    }
    
    /// 切换到月视图
    func switchToMonthView() {
        displayMode = .month
    }
    
    /// 确保指定日期的数据已加载
    private func ensureDataLoadedForDate(_ date: Date) async {
        guard let grid = grid else {
            await reloadMonth()
            return
        }
        
        let calendar = Calendar(identifier: .gregorian)
        let currentYear = calendar.component(.year, from: selectedDate)
        let currentMonth = calendar.component(.month, from: selectedDate)
        let targetYear = calendar.component(.year, from: date)
        let targetMonth = calendar.component(.month, from: date)
        
        // 如果日期不在当前加载的月份中，重新加载
        if currentYear != targetYear || currentMonth != targetMonth {
            selectedDate = date
            await reloadMonth()
        }
    }
    
    /// 设置周视图显示天数
    func setWeekDisplayDays(_ days: Int) {
        weekDisplayDays = days
    }
    
    /// 生成周视图的日期单元格数组
    private func generateWeekCells(for selectedDate: Date, displayDays: Int) -> [CalendarDayCell] {
        guard let grid = grid else { return [] }
        let calendar = Calendar(identifier: .gregorian)
        
        // 找到当前周的第一天（周日）
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) else {
            return []
        }
        
        let selectedDateOnly = DateOnly(from: selectedDate) ?? DateOnly(year: 2000, month: 1, day: 1)
        let weekStartOnly = DateOnly(from: weekStart) ?? DateOnly(year: 2000, month: 1, day: 1)
        
        // 计算选中日期在周中的偏移（0 = 周日，6 = 周六）
        let offset = selectedDateOnly.day - weekStartOnly.day
        
        var cells: [CalendarDayCell] = []
        
        if displayDays == 7 {
            // 7 日视图：显示整周
            for i in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: i, to: weekStart) {
                    if let cell = findCell(for: date) {
                        cells.append(cell)
                    } else {
                        cells.append(createPlaceholderCell(for: date))
                    }
                }
            }
        } else {
            // 5 日/3 日视图：居中显示
            let centerOffset = (7 - displayDays) / 2
            for i in 0..<displayDays {
                let actualDay = i + centerOffset
                if let date = calendar.date(byAdding: .day, value: actualDay, to: weekStart) {
                    if let cell = findCell(for: date) {
                        cells.append(cell)
                    } else {
                        cells.append(createPlaceholderCell(for: date))
                    }
                }
            }
        }
        
        return cells
    }
    
    /// 在 grid 中查找指定日期的单元格
    private func findCell(for date: Date) -> CalendarDayCell? {
        guard let grid = grid else { return nil }
        let dateOnly = DateOnly(from: date)
        return grid.days.first { $0.date == dateOnly }
    }
    
    /// 创建占位单元格
    private func createPlaceholderCell(for date: Date) -> CalendarDayCell {
        let dateOnly = DateOnly(from: date) ?? DateOnly(year: 2000, month: 1, day: 1)
        let calendar = Calendar(identifier: .gregorian)
        let weekdaySymbols = LocalizationManager.shared.shortWeekdaySymbols(weekStartPolicy: .sunday)
        let weekdayIndex = calendar.component(.weekday, from: date) - 1
        
        return CalendarDayCell(
            id: dateOnly.id,
            date: dateOnly,
            dayText: "\(dateOnly.day)",
            weekdayText: weekdaySymbols[weekdayIndex],
            holidays: [],
            events: [],
            isToday: false,
            isWeekend: false,
            isInCurrentMonth: true,
            shiftType: nil,
            eventMarkers: []
        )
    }
    
    /// 获取周视图标题（年月格式）
    func weekTitle() -> String {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)
        return LocalizationManager.shared.monthTitle(for: selectedDate)
    }
    
    /// 获取日视图标题（年月日格式）
    func dayTitle() -> String {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)
        let day = calendar.component(.day, from: selectedDate)
        let weekdaySymbols = LocalizationManager.shared.shortWeekdaySymbols(weekStartPolicy: .sunday)
        let weekdayIndex = calendar.component(.weekday, from: selectedDate) - 1
        let weekdayText = weekdaySymbols[weekdayIndex]
        return "\(year)年\(month)月\(day)日（\(weekdayText)）"
    }
}
