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
    
    // 周视图的日期单元格（计算属性，从 grid 生成）
    var weekCells: [CalendarDayCell] {
        generateWeekCells(for: selectedDate)
    }
    
    // 日视图的日期单元格
    var selectedDateEvents: [EventOccurrence] {
        dayCell?.events ?? []
    }

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
            refreshSelectedDayCell()

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

    func createEvent(title: String, note: String?, startDate: Date, endDate: Date, isAllDay: Bool, reminderOffsetMinutes: Int?, shiftTemplateID: ShiftTimeTemplateID?, workInfo: WorkInfo) async throws {
        let adjustedWorkInfo = try await adjustedWorkInfoForSave(title: title, startDate: startDate, workInfo: workInfo)
        let saveDates = eventDatesForSave(title: title, startDate: startDate, endDate: endDate, isAllDay: isAllDay, workInfo: adjustedWorkInfo)
        let now = Date()

        let event = CalendarEvent(
            id: UUID(),
            title: title,
            note: note,
            startDate: saveDates.start,
            endDate: saveDates.end,
            isAllDay: isAllDay,
            categoryID: nil,
            recurrenceRule: .none,
            reminderTemplateID: nil,
            reminderOffsetMinutes: reminderOffsetMinutes,
            notificationID: nil,
            importSource: nil,
            createdAt: now,
            updatedAt: now,
            shiftTemplateID: shiftTemplateID,
            workInfo: adjustedWorkInfo
        )

        if let kind = workClockKind(for: title) {
            try await upsertWorkClockEvent(event, kind: kind)
            try await syncSharedWorkValues(for: adjustedWorkInfo.workDate ?? saveDates.start, transportFee: adjustedWorkInfo.transportFee, hourlyRate: adjustedWorkInfo.hourlyRate)
        } else {
            try await eventUseCase.createEvent(event)
        }
        await reloadMonth()
    }


    private func upsertWorkClockEvent(_ event: CalendarEvent, kind: WorkClockKind) async throws {
        let calendar = Calendar(identifier: .gregorian)
        let dayStart = calendar.startOfDay(for: event.workInfo?.workDate ?? event.startDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let sameDayEvents = try await eventUseCase.events(in: DateInterval(start: dayStart, end: dayEnd))
        let sameKindEvents = sameDayEvents
            .filter { workClockKind(for: $0.title) == kind }
            .sorted { $0.createdAt < $1.createdAt }

        guard let existingEvent = sameKindEvents.first else {
            try await eventUseCase.createEvent(event)
            return
        }

        let now = Date()
        let updatedEvent = CalendarEvent(
            id: existingEvent.id,
            title: event.title,
            note: event.note,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            categoryID: existingEvent.categoryID,
            recurrenceRule: existingEvent.recurrenceRule,
            reminderTemplateID: existingEvent.reminderTemplateID,
            reminderOffsetMinutes: event.reminderOffsetMinutes,
            notificationID: existingEvent.notificationID,
            importSource: existingEvent.importSource,
            createdAt: existingEvent.createdAt,
            updatedAt: now,
            shiftTemplateID: event.shiftTemplateID,
            workInfo: event.workInfo
        )
        try await eventUseCase.updateEvent(updatedEvent)

        for duplicate in sameKindEvents.dropFirst() {
            try await eventUseCase.deleteEvent(id: duplicate.id)
        }
    }
    private func syncSharedWorkValues(for date: Date, transportFee: Int?, hourlyRate: Int?) async throws {
        let sameDayWorkEvents = try await sameDayWorkEvents(for: date)
        let now = Date()

        for event in sameDayWorkEvents {
            var syncedWorkInfo = event.workInfo ?? WorkInfo()
            syncedWorkInfo.transportFee = transportFee
            syncedWorkInfo.hourlyRate = hourlyRate

            let syncedEvent = CalendarEvent(
                id: event.id,
                title: event.title,
                note: event.note,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                categoryID: event.categoryID,
                recurrenceRule: event.recurrenceRule,
                reminderTemplateID: event.reminderTemplateID,
                reminderOffsetMinutes: event.reminderOffsetMinutes,
                notificationID: event.notificationID,
                importSource: event.importSource,
                createdAt: event.createdAt,
                updatedAt: now,
                shiftTemplateID: event.shiftTemplateID,
                workInfo: syncedWorkInfo
            )
            try await eventUseCase.updateEvent(syncedEvent)
        }
    }

    private func sameDayWorkEvents(for date: Date) async throws -> [CalendarEvent] {
        let calendar = Calendar(identifier: .gregorian)
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        return try await eventUseCase.events(in: DateInterval(start: dayStart, end: dayEnd))
            .filter { workClockKind(for: $0.title) != nil }
    }


    private func workClockKind(for title: String) -> WorkClockKind? {
        if WorkClockTitleMatcher.isClockInTitle(title) {
            return .clockIn
        }
        if WorkClockTitleMatcher.isClockOutTitle(title) {
            return .clockOut
        }
        return nil
    }

    func selectDay(_ cell: CalendarDayCell) {
        selectedDayCell = cell
        showingDayDetail = true
    }

    private func refreshSelectedDayCell() {
        guard let selectedDayCell else { return }
        self.selectedDayCell = grid?.days.first { $0.id == selectedDayCell.id } ?? selectedDayCell
    }

    func deleteEvent(id: UUID) async {
        do {
            try await eventUseCase.deleteEvent(id: id)
            await reloadMonth()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateEvent(id: UUID, title: String, note: String?, startDate: Date, endDate: Date, isAllDay: Bool, reminderOffsetMinutes: Int?, shiftTemplateID: ShiftTimeTemplateID?, workInfo: WorkInfo) async throws {
        do {
            let adjustedWorkInfo = try await adjustedWorkInfoForSave(title: title, startDate: startDate, workInfo: workInfo)
            let saveDates = eventDatesForSave(title: title, startDate: startDate, endDate: endDate, isAllDay: isAllDay, workInfo: adjustedWorkInfo)
            let existingEvent = try await eventUseCase.event(id: id)
            let now = Date()

            let updatedEvent = CalendarEvent(
                id: id,
                title: title,
                note: note,
                startDate: saveDates.start,
                endDate: saveDates.end,
                isAllDay: isAllDay,
                categoryID: existingEvent?.categoryID,
                recurrenceRule: existingEvent?.recurrenceRule ?? .none,
                reminderTemplateID: existingEvent?.reminderTemplateID,
                reminderOffsetMinutes: reminderOffsetMinutes,
                notificationID: existingEvent?.notificationID,
                importSource: existingEvent?.importSource,
                createdAt: existingEvent?.createdAt ?? now,
                updatedAt: now,
                shiftTemplateID: shiftTemplateID ?? existingEvent?.shiftTemplateID,
                workInfo: adjustedWorkInfo
            )

            try await eventUseCase.updateEvent(updatedEvent)
            if workClockKind(for: title) != nil {
                try await syncSharedWorkValues(for: adjustedWorkInfo.workDate ?? saveDates.start, transportFee: adjustedWorkInfo.transportFee, hourlyRate: adjustedWorkInfo.hourlyRate)
            }
            await reloadMonth()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    private func adjustedWorkInfoForSave(title: String, startDate: Date, workInfo: WorkInfo) async throws -> WorkInfo {
        guard workClockKind(for: title) != nil else {
            return workInfo
        }

        var adjusted = workInfo
        let calendar = Calendar(identifier: .gregorian)
        let workDay = calendar.startOfDay(for: workInfo.workDate ?? startDate)
        adjusted.workDate = workDay

        if WorkClockTitleMatcher.isClockInTitle(title), let workInTime = workInfo.workInTime {
            adjusted.workInTime = date(on: workDay, matchingTimeOf: workInTime)
        }

        guard WorkClockTitleMatcher.isClockOutTitle(title), let workOutTime = workInfo.workOutTime else {
            return adjusted
        }

        let clockInTime = try await clockInTime(on: workDay)
        let baseOut = date(on: workDay, matchingTimeOf: workOutTime)
        if let clockInTime, isTime(baseOut, earlierThan: clockInTime) {
            adjusted.workOutTime = calendar.date(byAdding: .day, value: 1, to: baseOut) ?? baseOut
        } else {
            adjusted.workOutTime = baseOut
        }
        return adjusted
    }

    private func clockInTime(on workDay: Date) async throws -> Date? {
        try await sameDayWorkEvents(for: workDay)
            .filter { WorkClockTitleMatcher.isClockInTitle($0.title) }
            .map { $0.workInfo?.workInTime ?? $0.startDate }
            .min()
    }

    private func date(on day: Date, matchingTimeOf date: Date) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let time = calendar.dateComponents([.hour, .minute, .second], from: date)
        return calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: day) ?? date
    }

    private func isTime(_ lhs: Date, earlierThan rhs: Date) -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        let left = calendar.dateComponents([.hour, .minute], from: lhs)
        let right = calendar.dateComponents([.hour, .minute], from: rhs)
        let leftMinutes = (left.hour ?? 0) * 60 + (left.minute ?? 0)
        let rightMinutes = (right.hour ?? 0) * 60 + (right.minute ?? 0)
        return leftMinutes < rightMinutes
    }


    private func eventDatesForSave(title: String, startDate: Date, endDate: Date, isAllDay: Bool, workInfo: WorkInfo) -> (start: Date, end: Date) {
        if WorkClockTitleMatcher.isClockInTitle(title), let workInTime = workInfo.workInTime {
            return workClockEventDates(for: workInTime)
        }
        if WorkClockTitleMatcher.isClockOutTitle(title), let workOutTime = workInfo.workOutTime {
            return workClockEventDates(for: workOutTime)
        }
        return normalizedEventDates(startDate: startDate, endDate: endDate, isAllDay: isAllDay)
    }

    private func workClockEventDates(for clockDate: Date) -> (start: Date, end: Date) {
        (clockDate, CalendarEvent.defaultEndDate(for: clockDate, isAllDay: false))
    }

    private func normalizedEventDates(startDate: Date, endDate: Date, isAllDay: Bool) -> (start: Date, end: Date) {
        let calendar = Calendar(identifier: .gregorian)
        if isAllDay {
            let start = calendar.startOfDay(for: startDate)
            let selectedEndDay = calendar.startOfDay(for: endDate)
            let safeEndDay = max(selectedEndDay, start)
            let end = calendar.date(byAdding: .day, value: 1, to: safeEndDay) ?? safeEndDay
            return (start, end)
        }
        return (startDate, endDate)
    }
    
    // MARK: - 周视图/日视图支持
    
    /// 选择某一天，如果从周视图点击则切换到日视图
    func selectDate(_ date: Date) {
        
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
        guard self.grid != nil else {
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
    
    /// 生成周视图的日期单元格数组。周起始日与月视图设置保持一致。
    private func generateWeekCells(for selectedDate: Date) -> [CalendarDayCell] {
        guard grid != nil else { return [] }
        let calendar = Calendar(identifier: .gregorian)
        let weekday = calendar.component(.weekday, from: selectedDate)
        let weekStartOffset = (weekday - firstWeekday(for: currentSetting.weekStartPolicy) + 7) % 7

        guard let weekStart = calendar.date(byAdding: .day, value: -weekStartOffset, to: selectedDate) else {
            return []
        }

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }
            return findCell(for: date) ?? createPlaceholderCell(for: date)
        }
    }

    private func firstWeekday(for policy: WeekStartPolicy) -> Int {
        switch policy {
        case .sunday:
            return 1
        case .monday:
            return 2
        case .saturday:
            return 7
        case .system:
            return Calendar.current.firstWeekday
        }
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
        LocalizationManager.shared.monthTitle(for: selectedDate)
    }
    
    /// 获取日视图标题（年月日格式）
    func dayTitle() -> String {
        LocalizationManager.shared.dayTitle(for: selectedDate)
    }
}
