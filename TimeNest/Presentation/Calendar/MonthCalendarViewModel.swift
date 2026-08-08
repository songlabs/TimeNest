import Foundation
import SwiftUI
import Combine

@MainActor
class MonthCalendarViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published private(set) var grid: MonthGrid?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published var selectedDayCell: CalendarDayCell?
    @Published var showingDayDetail: Bool = false
    @Published var showingEntryEditor: Bool = false
    @Published var isShiftInputMode: Bool = false
    @Published var shiftInputTargetDate: Date?
    @Published var selectedShiftTemplate: ShiftTimeTemplate?
    @Published private(set) var shiftTemplates: [ShiftTimeTemplate] = ShiftTimeTemplate.all()
    @Published private(set) var monthSecondaryDisplayMode: MonthSecondaryDisplayMode
    
    // 视图模式：month / week / day
    @Published var displayMode: CalendarViewMode = .month
    
    // 周视图的日期单元格（计算属性，从 grid 生成）
    var weekCells: [CalendarDayCell] {
        generateWeekCells(for: selectedDate)
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
    private let calendarSharingStore: CalendarSharingStore
    private var currentSetting: CalendarDisplaySetting
    private let subscriptionManager: HolidaySubscriptionManager
    private let userDefaults: UserDefaults
    private var reloadGeneration = 0

    private var languageObserver: AnyCancellable?
    private var subscriptionObserver: AnyCancellable?
    private var preferencesObserver: AnyCancellable?
    private var sharingObserver: AnyCancellable?

    private var notificationObservers: [AnyCancellable] = []
    init(
        calendarDisplayUseCase: CalendarDisplayUseCase,
        eventUseCase: EventUseCase,
        calendarSharingStore: CalendarSharingStore,
        subscriptionManager: HolidaySubscriptionManager? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.calendarDisplayUseCase = calendarDisplayUseCase
        self.eventUseCase = eventUseCase
        self.calendarSharingStore = calendarSharingStore
        self.subscriptionManager = subscriptionManager ?? .shared
        self.userDefaults = userDefaults

        // 初始化时从 LocalizationManager 读取当前语言，从订阅管理器读取已启用的地区
        let initialLanguage = LocalizationManager.shared.currentLanguage
        let enabledRegions = self.subscriptionManager.enabledRegions  // 允许空数组
        let initialWeekStart = WeekStartPolicy(rawValue: userDefaults.string(forKey: "weekStart") ?? "system") ?? .system
        let monthSecondaryDisplayMode = MonthSecondaryDisplayMode.resolved(defaults: userDefaults)
        self.monthSecondaryDisplayMode = monthSecondaryDisplayMode
        let traditionalPreferences = monthSecondaryDisplayMode.traditionalPreferences

        self.currentSetting = .init(
            displayLanguage: initialLanguage,
            selectedHolidayRegions: enabledRegions,
            weekStartPolicy: initialWeekStart,
            showLunarCalendar: traditionalPreferences.showLunarCalendar,
            showRokuyo: traditionalPreferences.showRokuyo,
            showSolarTerms: traditionalPreferences.showSolarTerms
        )

#if DEBUG
        if let initialDate = TimeNestUITestSupport.initialCalendarDate {
            selectedDate = initialDate
        }
#endif

        // 监听 LocalizationManager 的语言变化
        setupLanguageObserver()
        // 监听节假日订阅变化
        setupNotificationObserver()
        // 监听订阅管理器的 region 变化
        setupSubscriptionObserver()
        // 监听周起始日和传统历法开关变化
        setupPreferencesObserver()
        setupSharingObserver()
    }

    private func setupSharingObserver() {
        sharingObserver = calendarSharingStore.$revision
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.showingEntryEditor = false
                    self.showingDayDetail = false
                    self.exitShiftInputMode()
                    await self.reloadMonth()
                }
            }
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

    private func setupPreferencesObserver() {
        preferencesObserver = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updatePersistedCalendarSettings()
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
            refreshShiftTemplates()
            Task {
                await reloadMonth()
            }
        }
    }

    private func updatePersistedCalendarSettings() {
        let newWeekStart = WeekStartPolicy(rawValue: userDefaults.string(forKey: "weekStart") ?? "system") ?? .system
        let newMonthSecondaryDisplayMode = MonthSecondaryDisplayMode.resolved(defaults: userDefaults)
        let traditionalPreferences = newMonthSecondaryDisplayMode.traditionalPreferences
        var needsReload = false

        if currentSetting.weekStartPolicy != newWeekStart {
            currentSetting.weekStartPolicy = newWeekStart
            needsReload = true
        }
        if currentSetting.showLunarCalendar != traditionalPreferences.showLunarCalendar {
            currentSetting.showLunarCalendar = traditionalPreferences.showLunarCalendar
            needsReload = true
        }
        if currentSetting.showRokuyo != traditionalPreferences.showRokuyo {
            currentSetting.showRokuyo = traditionalPreferences.showRokuyo
            needsReload = true
        }
        if currentSetting.showSolarTerms != traditionalPreferences.showSolarTerms {
            currentSetting.showSolarTerms = traditionalPreferences.showSolarTerms
            needsReload = true
        }
        if monthSecondaryDisplayMode != newMonthSecondaryDisplayMode {
            monthSecondaryDisplayMode = newMonthSecondaryDisplayMode
            needsReload = true
        }

        if needsReload {
            Task { await reloadMonth() }
        }
    }

    func reloadMonth() async {
        reloadGeneration &+= 1
        let generation = reloadGeneration
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
                setting: currentSetting,
                calendarID: calendarSharingStore.selectedCalendar.kind == .sharedReceived
                    ? TimeNestCalendar.personalID
                    : calendarSharingStore.selection.calendarID
            )
            guard generation == reloadGeneration else { return }

            // 完全替换旧的 grid，不要 append / merge
            self.grid = gridForCurrentCalendar(from: baseGrid)
            refreshSelectedDayCell()

        } catch {
            guard generation == reloadGeneration else { return }
            errorMessage = error.localizedDescription
            grid = nil

        }

        isLoading = false
    }

    private func gridForCurrentCalendar(from baseGrid: MonthGrid) -> MonthGrid {
        guard calendarSharingStore.selectedCalendar.kind == .sharedReceived,
              let firstDay = baseGrid.days.first?.date.toDate(),
              let lastDay = baseGrid.days.last?.date.toDate() else {
            return baseGrid
        }

        let calendarID = calendarSharingStore.selection.calendarID

        let calendar = Calendar(identifier: .gregorian)
        let rangeEnd = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
        let occurrences = calendarSharingStore.occurrences(
            for: calendarID,
            in: DateInterval(start: firstDay, end: rangeEnd)
        )
        let occurrencesByDate = Dictionary(grouping: occurrences, by: { $0.occurrenceDate.id })
        let days = baseGrid.days.map { day in
            CalendarDayCell(
                id: day.id,
                date: day.date,
                dayText: day.dayText,
                weekdayText: day.weekdayText,
                holidays: day.holidays,
                events: occurrencesByDate[day.date.id] ?? [],
                isToday: day.isToday,
                isWeekend: day.isWeekend,
                isInCurrentMonth: day.isInCurrentMonth,
                shiftType: nil,
                eventMarkers: [],
                traditionalCalendar: day.traditionalCalendar
            )
        }
        return MonthGrid(title: baseGrid.title, weekdaySymbols: baseGrid.weekdaySymbols, days: days)
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

    func openCalendar(on date: Date) async {
        selectedDate = date
        displayMode = .month
        showingDayDetail = false
        await reloadMonth()
        selectedDayCell = findCell(for: date)
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

    @discardableResult
    func createEvent(
        title: String,
        note: String?,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        reminderOffsetMinutes: Int?,
        shiftTemplateID: ShiftTimeTemplateID?,
        workInfo: WorkInfo?,
        calendarID: UUID,
        unifiedEntryID: UUID? = nil
    ) async throws -> EventNotificationScheduleResult {
        try calendarSharingStore.ensureCanWrite(calendarID: calendarID)
        let adjustedWorkInfo = try await adjustedWorkInfoForSave(
            title: title,
            startDate: startDate,
            workInfo: workInfo,
            calendarID: calendarID
        )
        let saveDates = eventDatesForSave(title: title, startDate: startDate, endDate: endDate, isAllDay: isAllDay, workInfo: adjustedWorkInfo)
        let now = Date()

        let event = CalendarEvent(
            id: UUID(),
            unifiedEntryID: unifiedEntryID,
            calendarID: calendarID,
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

        let notificationResult: EventNotificationScheduleResult
        if let adjustedWorkInfo,
           let kind = workClockKind(title: title, workInfo: adjustedWorkInfo) {
            notificationResult = try await upsertWorkClockEvent(event, kind: kind)
            if let sessionId = adjustedWorkInfo.workSessionId {
                try await syncSharedWorkValues(for: sessionId, workDate: adjustedWorkInfo.workDate ?? saveDates.start, restHours: adjustedWorkInfo.restHours, transportFee: adjustedWorkInfo.transportFee, hourlyRate: adjustedWorkInfo.hourlyRate, calendarID: calendarID)
            }
        } else {
            notificationResult = try await eventUseCase.createEvent(event)
        }
        await reloadMonth()
        return notificationResult
    }

    func enterShiftInputMode() {
        guard calendarSharingStore.accessPolicy.canEditShifts else { return }
        refreshShiftTemplates()
        isShiftInputMode = true
        shiftInputTargetDate = selectedDate
        showingDayDetail = false
        selectedShiftTemplate = nil
    }

    func exitShiftInputMode() {
        isShiftInputMode = false
        shiftInputTargetDate = nil
        selectedShiftTemplate = nil
    }

    func registerShift(_ template: ShiftTimeTemplate) async {
        let targetDate = shiftInputTargetDate ?? selectedDate
        guard await createShiftEvent(on: targetDate, template: template) else { return }

        await advanceShiftInputDate(after: targetDate)
    }

    func cancelShift() async {
        guard calendarSharingStore.accessPolicy.canDelete else {
            errorMessage = CalendarSharingError.permissionDenied.localizedDescription
            return
        }
        let targetDate = shiftInputTargetDate ?? selectedDate

        do {
            if let existingEvent = try await existingAnyShiftEvent(on: targetDate) {
                try await eventUseCase.deleteEvent(id: existingEvent.id)
                await reloadMonth()
            }
            await advanceShiftInputDate(after: targetDate)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func advanceShiftInputDate(after date: Date) async {
        let calendar = Calendar(identifier: .gregorian)
        guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { return }

        shiftInputTargetDate = nextDate
        selectedDate = nextDate

        if findCell(for: nextDate) == nil {
            await reloadMonth()
        }
        selectedDayCell = findCell(for: nextDate)
    }

    func refreshShiftTemplates() {
        shiftTemplates = ShiftTimeTemplate.all()
        if let selectedShiftTemplate,
           !shiftTemplates.contains(where: { $0.id == selectedShiftTemplate.id }) {
            self.selectedShiftTemplate = shiftTemplates.first
        }
    }

    @discardableResult
    func createShiftEvent(on date: Date, template: ShiftTimeTemplate) async -> Bool {
        guard calendarSharingStore.accessPolicy.canCreate else {
            errorMessage = CalendarSharingError.permissionDenied.localizedDescription
            return false
        }
        do {
            guard let dates = shiftEventDates(on: date, template: template) else { return false }
            let now = Date()

            // 查找当天是否已有任意班次（不限模板）
            if let existingEvent = try await existingAnyShiftEvent(on: date) {
                // 已有班次：覆盖旧班次
                let updatedEvent = CalendarEvent(
                    id: existingEvent.id,
                    unifiedEntryID: existingEvent.unifiedEntryID,
                    calendarID: existingEvent.calendarID,
                    title: template.displayName,
                    note: existingEvent.note,
                    startDate: dates.start,
                    endDate: dates.end,
                    isAllDay: false,
                    categoryID: existingEvent.categoryID,
                    recurrenceRule: existingEvent.recurrenceRule,
                    reminderTemplateID: existingEvent.reminderTemplateID,
                    reminderOffsetMinutes: existingEvent.reminderOffsetMinutes,
                    notificationID: existingEvent.notificationID,
                    importSource: existingEvent.importSource,
                    createdAt: existingEvent.createdAt,
                    updatedAt: now,
                    shiftTemplateID: template.id,
                    workInfo: existingEvent.workInfo
                )
                try await eventUseCase.updateEvent(updatedEvent)
            } else {
                // 无班次：新增班次
                let event = CalendarEvent(
                    id: UUID(),
                    calendarID: calendarSharingStore.selection.calendarID,
                    title: template.displayName,
                    note: nil,
                    startDate: dates.start,
                    endDate: dates.end,
                    isAllDay: false,
                    categoryID: nil,
                    recurrenceRule: .none,
                    reminderTemplateID: nil,
                    reminderOffsetMinutes: nil,
                    notificationID: nil,
                    importSource: nil,
                    createdAt: now,
                    updatedAt: now,
                    shiftTemplateID: template.id,
                    workInfo: nil
                )
                try await eventUseCase.createEvent(event)
            }

            await reloadMonth()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func shiftEventDates(on date: Date, template: ShiftTimeTemplate) -> (start: Date, end: Date)? {
        guard let startTime = template.startHourMinute,
              let endTime = template.endHourMinute else { return nil }

        let calendar = Calendar(identifier: .gregorian)
        let dayStart = calendar.startOfDay(for: date)
        let start = calendar.date(
            bySettingHour: startTime.hour,
            minute: startTime.minute,
            second: 0,
            of: dayStart
        ) ?? dayStart

        let startMinutes = startTime.hour * 60 + startTime.minute
        let endMinutes = endTime.hour * 60 + endTime.minute
        let endBaseDate = endMinutes <= startMinutes
            ? (calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart)
            : dayStart

        let end = calendar.date(
            bySettingHour: endTime.hour,
            minute: endTime.minute,
            second: 0,
            of: endBaseDate
        ) ?? CalendarEvent.defaultEndDate(for: start, isAllDay: false)

        return (start, end)
    }

    /// 查找当天是否已有任意班次（不限模板 ID）
    /// 用于实现「同一天只能存在一个班次」的规则
    private func existingAnyShiftEvent(
        on date: Date,
        calendarID: UUID? = nil
    ) async throws -> CalendarEvent? {
        let calendar = Calendar(identifier: .gregorian)
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let allTemplates = ShiftTimeTemplate.all()

        return try await eventUseCase.events(
            in: DateInterval(start: dayStart, end: dayEnd),
            calendarID: calendarID ?? calendarSharingStore.selection.calendarID
        )
            .filter { event in
                guard !WorkClockTitleMatcher.isClockInTitle(event.title),
                      !WorkClockTitleMatcher.isClockOutTitle(event.title),
                      calendar.isDate(event.startDate, inSameDayAs: dayStart) else {
                    return false
                }

                // 班次事件的判断标准：
                // 1. 有 shiftTemplateID（明确的班次模板关联）
                // 2. 或标题与某个班次模板的 displayName 匹配（兼容旧数据）
                if event.shiftTemplateID != nil {
                    return true
                }

                // 仅对旧版标题识别路径要求没有 workInfo，避免普通日程或工作记录被误判为班次。
                guard event.workInfo == nil else {
                    return false
                }

                return allTemplates.contains { $0.displayName == event.title }
                    || ShiftTimeTemplate.isKnownDefaultDisplayName(event.title)
            }
            .sorted { $0.createdAt < $1.createdAt }
            .first
    }


    private func upsertWorkClockEvent(_ event: CalendarEvent, kind: WorkClockKind) async throws -> EventNotificationScheduleResult {
        let sessionId = event.workInfo?.workSessionId
        let sameKindEvents: [CalendarEvent]
        if let sessionId {
            sameKindEvents = try await workEventsAround(
                workDate: event.workInfo?.workDate ?? event.startDate,
                calendarID: event.calendarID
            )
                .filter { $0.workInfo?.workSessionId == sessionId && $0.workClockKind == kind }
                .sorted { $0.createdAt < $1.createdAt }
        } else {
            sameKindEvents = []
        }

        guard let existingEvent = sameKindEvents.first else {
            return try await eventUseCase.createEvent(event)
        }

        let now = Date()
        let updatedEvent = CalendarEvent(
            id: existingEvent.id,
            unifiedEntryID: event.unifiedEntryID ?? existingEvent.unifiedEntryID,
            calendarID: existingEvent.calendarID,
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
        let notificationResult = try await eventUseCase.updateEvent(updatedEvent)

        for duplicate in sameKindEvents.dropFirst() {
            try await eventUseCase.deleteEvent(id: duplicate.id)
        }
        return notificationResult
    }
    private func syncSharedWorkValues(for sessionId: UUID, workDate: Date, restHours: Double, transportFee: Int?, hourlyRate: Int?, calendarID: UUID) async throws {
        let sameSessionWorkEvents = try await workEventsAround(
            workDate: workDate,
            calendarID: calendarID
        )
            .filter { $0.workInfo?.workSessionId == sessionId }
        let now = Date()

        for event in sameSessionWorkEvents {
            var syncedWorkInfo = event.workInfo ?? WorkInfo()
            syncedWorkInfo.restHours = restHours
            syncedWorkInfo.transportFee = transportFee
            syncedWorkInfo.hourlyRate = hourlyRate

            let syncedEvent = CalendarEvent(
                id: event.id,
                unifiedEntryID: event.unifiedEntryID,
                calendarID: event.calendarID,
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

    private func sameDayWorkEvents(for date: Date, calendarID: UUID) async throws -> [CalendarEvent] {
        let calendar = Calendar(identifier: .gregorian)
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        return try await eventUseCase.events(
            in: DateInterval(start: dayStart, end: dayEnd),
            calendarID: calendarID
        )
            .filter { $0.workClockKind != nil }
    }

    private func workEventsAround(workDate: Date, calendarID: UUID) async throws -> [CalendarEvent] {
        let calendar = Calendar(identifier: .gregorian)
        let dayStart = calendar.startOfDay(for: workDate)
        let dayEnd = calendar.date(byAdding: .day, value: 2, to: dayStart) ?? dayStart
        return try await eventUseCase.events(
            in: DateInterval(start: dayStart, end: dayEnd),
            calendarID: calendarID
        )
            .filter { $0.workClockKind != nil }
    }


    private func workClockKind(for title: String) -> WorkClockKind? {
        WorkClockTitleMatcher.kind(for: title)
    }

    private func workClockKind(title: String, workInfo: WorkInfo?) -> WorkClockKind? {
        guard let workInfo else { return nil }
        return WorkClockTitleMatcher.kind(for: title) ?? WorkClockTitleMatcher.kind(for: workInfo)
    }

    func selectDay(_ cell: CalendarDayCell) {
        if calendarSharingStore.accessPolicy.isReadOnly {
            selectReadOnlyDay(cell)
            return
        }
        selectedDayCell = cell
        selectedDate = cell.date.toDate()

        if isShiftInputMode {
            shiftInputTargetDate = cell.date.toDate()
            return
        }

        if cell.events.isEmpty {
            showingDayDetail = false
            showingEntryEditor = true
        } else {
            showingEntryEditor = false
            showingDayDetail = true
        }
    }

    func selectReadOnlyDay(_ cell: CalendarDayCell) {
        selectedDayCell = cell
        selectedDate = cell.date.toDate()
        showingDayDetail = false
        showingEntryEditor = false
        exitShiftInputMode()
    }

    func openSelectedDateEntryEditor() async {
        guard calendarSharingStore.accessPolicy.canCreate else { return }
        let targetDate = selectedDate
        await ensureDataLoadedForDate(targetDate)
        selectedDayCell = findCell(for: targetDate) ?? createPlaceholderCell(for: targetDate)
        showingDayDetail = false
        showingEntryEditor = true
    }

    private func refreshSelectedDayCell() {
        guard let selectedDayCell else { return }
        self.selectedDayCell = grid?.days.first { $0.id == selectedDayCell.id } ?? selectedDayCell
    }

    func deleteEvent(id: UUID) async {
        guard calendarSharingStore.accessPolicy.canDelete else {
            errorMessage = CalendarSharingError.permissionDenied.localizedDescription
            return
        }
        do {
            try await eventUseCase.deleteEvent(id: id)
            await reloadMonth()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveWorkRecordPair(_ request: WorkRecordPairSaveRequest) async throws {
        try calendarSharingStore.ensureCanWrite(calendarID: request.calendarID)
        do {
            try await eventUseCase.saveWorkRecordPair(request)
            await reloadMonth()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func loadUnifiedEntry(
        _ request: UnifiedEntryLoadRequest
    ) async throws -> UnifiedEntryEditorInitialState {
        guard calendarSharingStore.accessPolicy.canEdit else {
            throw CalendarSharingError.permissionDenied
        }
        do {
            let group = try await eventUseCase.unifiedEntryGroup(for: request)
            return UnifiedEntryEditorInitialState(
                group: group,
                initialEntryKind: request.initialEntryKind
            )
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    @discardableResult
    func saveUnifiedEntry(
        _ request: UnifiedEntrySaveRequest
    ) async throws -> EventNotificationScheduleResult? {
        guard request.hasEnabledEntry else {
            throw UnifiedEntrySaveError.noEnabledEntry
        }

        do {
            let resolution = try await eventUseCase.resolveUnifiedEntrySave(request)
            let resolvedWorkRecord = request.workRecord?.resolvingExistingWorkRecord(
                resolution.existingWorkRecord,
                unifiedEntryID: resolution.unifiedEntryID
            )

            switch (request.event, resolvedWorkRecord) {
            case (.some(let event), nil):
                if let existingEvent = resolution.existingEvent {
                    return try await updateEvent(
                        id: existingEvent.id,
                        title: event.title,
                        note: event.note,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        isAllDay: event.isAllDay,
                        reminderOffsetMinutes: event.reminderOffsetMinutes,
                        shiftTemplateID: event.shiftTemplateID,
                        workInfo: event.workInfo,
                        calendarID: event.calendarID,
                        unifiedEntryID: resolution.unifiedEntryID
                    )
                }
                return try await createEvent(
                    title: event.title,
                    note: event.note,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    reminderOffsetMinutes: event.reminderOffsetMinutes,
                    shiftTemplateID: event.shiftTemplateID,
                    workInfo: event.workInfo,
                    calendarID: event.calendarID,
                    unifiedEntryID: resolution.unifiedEntryID
                )
            case (nil, .some(let workRecord)):
                try await saveWorkRecordPair(workRecord)
                return nil
            case (.some(let event), .some(let workRecord)):
                return try await saveEventAndWorkRecordAtomically(
                    eventRequest: event,
                    workRecordRequest: workRecord,
                    resolution: resolution
                )
            case (nil, nil):
                throw UnifiedEntrySaveError.noEnabledEntry
            }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    private func saveEventAndWorkRecordAtomically(
        eventRequest: EventEntrySaveRequest,
        workRecordRequest: WorkRecordPairSaveRequest,
        resolution: UnifiedEntrySaveResolution
    ) async throws -> EventNotificationScheduleResult {
        try calendarSharingStore.ensureCanWrite(calendarID: eventRequest.calendarID)
        try calendarSharingStore.ensureCanWrite(calendarID: workRecordRequest.calendarID)

        do {
            let adjustedWorkInfo = try await adjustedWorkInfoForSave(
                title: eventRequest.title,
                startDate: eventRequest.startDate,
                workInfo: eventRequest.workInfo,
                calendarID: eventRequest.calendarID
            )
            let saveDates = eventDatesForSave(
                title: eventRequest.title,
                startDate: eventRequest.startDate,
                endDate: eventRequest.endDate,
                isAllDay: eventRequest.isAllDay,
                workInfo: adjustedWorkInfo
            )
            let existingEvent = resolution.existingEvent
            let now = Date()
            let finalShiftTemplateID = eventRequest.shiftTemplateID
                ?? existingEvent?.shiftTemplateID
            let shiftEventToReplace: CalendarEvent?
            if eventRequest.shiftTemplateID != nil {
                let existingShift = try await existingAnyShiftEvent(
                    on: saveDates.start,
                    calendarID: eventRequest.calendarID
                )
                shiftEventToReplace = existingShift?.id != existingEvent?.id
                    ? existingShift
                    : nil
            } else {
                shiftEventToReplace = nil
            }
            let event = CalendarEvent(
                id: existingEvent?.id ?? UUID(),
                unifiedEntryID: resolution.unifiedEntryID,
                calendarID: eventRequest.calendarID,
                title: eventRequest.title,
                note: eventRequest.note,
                startDate: saveDates.start,
                endDate: saveDates.end,
                isAllDay: eventRequest.isAllDay,
                categoryID: existingEvent?.categoryID,
                recurrenceRule: existingEvent?.recurrenceRule ?? .none,
                reminderTemplateID: existingEvent?.reminderTemplateID,
                reminderOffsetMinutes: eventRequest.reminderOffsetMinutes,
                notificationID: existingEvent?.notificationID,
                importSource: existingEvent?.importSource,
                createdAt: existingEvent?.createdAt ?? now,
                updatedAt: now,
                shiftTemplateID: finalShiftTemplateID,
                workInfo: adjustedWorkInfo
            )

            let notificationResult = try await eventUseCase.saveEventAndWorkRecordAtomically(
                event: event,
                existingEvent: existingEvent,
                workRecord: workRecordRequest,
                deleting: [shiftEventToReplace].compactMap { $0 }
            )
            await reloadMonth()
            return notificationResult
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func deleteWorkRecord(eventIDs: [UUID]) async {
        do {
            var events: [CalendarEvent] = []
            for id in eventIDs {
                if let event = try await eventUseCase.event(id: id) {
                    events.append(event)
                }
            }
            guard !events.isEmpty else { return }
            _ = try await eventUseCase.deleteEventsBatch(expectedEvents: events)
            await reloadMonth()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func updateEvent(
        id: UUID,
        title: String,
        note: String?,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        reminderOffsetMinutes: Int?,
        shiftTemplateID: ShiftTimeTemplateID?,
        workInfo: WorkInfo?,
        calendarID: UUID,
        unifiedEntryID: UUID? = nil
    ) async throws -> EventNotificationScheduleResult {
        try calendarSharingStore.ensureCanWrite(calendarID: calendarID)
        do {
            let adjustedWorkInfo = try await adjustedWorkInfoForSave(
                title: title,
                startDate: startDate,
                workInfo: workInfo,
                calendarID: calendarID
            )
            let saveDates = eventDatesForSave(title: title, startDate: startDate, endDate: endDate, isAllDay: isAllDay, workInfo: adjustedWorkInfo)
            let existingEvent = try await eventUseCase.event(id: id)
            let now = Date()

            // 班次覆盖保护：如果本次保存的是班次事件，检查目标日期是否已有其他班次
            let finalShiftTemplateID = shiftTemplateID ?? existingEvent?.shiftTemplateID
            let shiftEventToReplace: CalendarEvent?
            if shiftTemplateID != nil {
                let existingShift = try await existingAnyShiftEvent(
                    on: saveDates.start,
                    calendarID: calendarID
                )
                // 只保留查到的班次与当前更新事件不是同一个的情况
                shiftEventToReplace = existingShift?.id != id ? existingShift : nil
            } else {
                shiftEventToReplace = nil
            }

            let updatedEvent = CalendarEvent(
                id: id,
                unifiedEntryID: unifiedEntryID ?? existingEvent?.unifiedEntryID,
                calendarID: calendarID,
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
                shiftTemplateID: finalShiftTemplateID,
                workInfo: adjustedWorkInfo
            )

            let notificationResult: EventNotificationScheduleResult
            if let existingEvent,
               existingEvent.calendarID != updatedEvent.calendarID {
                var sourceEvent = updatedEvent
                sourceEvent.calendarID = existingEvent.calendarID
                try await calendarSharingStore.moveEvent(
                    sourceEvent,
                    to: updatedEvent.calendarID
                )
                notificationResult = .noReminder
            } else {
                notificationResult = try await eventUseCase.updateEvent(updatedEvent)
            }

            // 更新成功后，再删除被覆盖的旧班次
            if let shiftEventToReplace {
                try await eventUseCase.deleteEvent(id: shiftEventToReplace.id)
            }

            if let adjustedWorkInfo,
               workClockKind(title: title, workInfo: adjustedWorkInfo) != nil {
                if let sessionId = adjustedWorkInfo.workSessionId {
                    try await syncSharedWorkValues(for: sessionId, workDate: adjustedWorkInfo.workDate ?? saveDates.start, restHours: adjustedWorkInfo.restHours, transportFee: adjustedWorkInfo.transportFee, hourlyRate: adjustedWorkInfo.hourlyRate, calendarID: calendarID)
                }
            }
            await reloadMonth()
            return notificationResult
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    private func adjustedWorkInfoForSave(title: String, startDate: Date, workInfo: WorkInfo?, calendarID: UUID) async throws -> WorkInfo? {
        guard let workInfo else { return nil }
        guard let kind = workClockKind(title: title, workInfo: workInfo) else {
            CalendarSharingDiagnostics.debug(
                operation: "saveLocalEvent",
                stage: "clear_inconsistent_work_info",
                database: "local",
                details: "hasWorkInfo=true hasWorkClockKind=false workInfoCleared=true"
            )
            return nil
        }

        var adjusted = workInfo
        if adjusted.workSessionId == nil {
            adjusted.workSessionId = WorkInfo.makeNewWorkSessionId()
        }
        let calendar = Calendar(identifier: .gregorian)
        let workDay = calendar.startOfDay(for: workInfo.workDate ?? startDate)
        adjusted.workDate = workDay

        if kind == .clockIn, let workInTime = workInfo.workInTime {
            adjusted.workInTime = date(on: workDay, matchingTimeOf: workInTime)
        }

        guard kind == .clockOut, let workOutTime = workInfo.workOutTime else {
            return adjusted
        }

        let clockInTime = try await clockInTime(
            on: workDay,
            sessionId: adjusted.workSessionId,
            calendarID: calendarID
        )
        let baseOut = date(on: workDay, matchingTimeOf: workOutTime)
        guard adjusted.isWorkOutTimeSet else {
            adjusted.workOutTime = baseOut
            return adjusted
        }
        if let clockInTime, isTime(baseOut, earlierThan: clockInTime) {
            adjusted.workOutTime = calendar.date(byAdding: .day, value: 1, to: baseOut) ?? baseOut
        } else {
            adjusted.workOutTime = baseOut
        }
        return adjusted
    }

    private func clockInTime(on workDay: Date, sessionId: UUID?, calendarID: UUID) async throws -> Date? {
        try await sameDayWorkEvents(for: workDay, calendarID: calendarID)
            .filter { $0.isClockInEvent }
            .filter { event in
                guard let sessionId else { return event.workInfo?.workSessionId == nil }
                return event.workInfo?.workSessionId == sessionId || event.workInfo?.workSessionId == nil
            }
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


    private func eventDatesForSave(title: String, startDate: Date, endDate: Date, isAllDay: Bool, workInfo: WorkInfo?) -> (start: Date, end: Date) {
        if workClockKind(title: title, workInfo: workInfo) == .clockIn, let workInTime = workInfo?.workInTime {
            return workClockEventDates(for: workInTime)
        }
        if workClockKind(title: title, workInfo: workInfo) == .clockOut, let workOutTime = workInfo?.workOutTime {
            return workClockEventDates(for: workOutTime)
        }
        return EventEditorDateNormalizer.persistenceDates(
            startDate: startDate,
            inclusiveEndDate: endDate,
            isAllDay: isAllDay
        )
    }

    private func workClockEventDates(for clockDate: Date) -> (start: Date, end: Date) {
        (clockDate, CalendarEvent.defaultEndDate(for: clockDate, isAllDay: false))
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
        let weekdayIndex = (calendar.component(.weekday, from: date) - 1 + 7) % 7
        let weekdayText = LocalizationManager.shared.shortWeekdaySymbol(for: date)
        
        return CalendarDayCell(
            id: dateOnly.id,
            date: dateOnly,
            dayText: "\(dateOnly.day)",
            weekdayText: weekdayText,
            holidays: [],
            events: [],
            isToday: false,
            isWeekend: weekdayIndex == 0 || weekdayIndex == 6,
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
