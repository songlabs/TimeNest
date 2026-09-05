import SwiftUI

private enum CalendarModalDestination {
    case statistics
    case settings
}

enum MonthWeatherPresentationPolicy {
    static func allowsWeatherDisplay(
        isWeatherEnabled: Bool,
        secondaryDisplayMode: MonthSecondaryDisplayMode,
        isAttributionMarkVisible: Bool
    ) -> Bool {
        isWeatherEnabled
            && secondaryDisplayMode == .weather
            && isAttributionMarkVisible
    }
}

struct MonthCalendarView: View {
    @StateObject private var viewModel: MonthCalendarViewModel
    @State private var showingYearMonthPicker = false
    @State private var showingSettings = false
    @State private var showingStatistics = false
    @State private var showingReceivedStatisticsUnavailable = false
    @StateObject private var statisticsViewModel: WorkStatisticsViewModel
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var weatherStore: CalendarWeatherStore
    @State private var isWeatherAttributionMarkVisible = false
    @ObservedObject private var purchaseManager = RemoveAdsPurchaseManager.shared
    @ObservedObject private var calendarSharingStore: CalendarSharingStore
    private let holidaySubscriptionManager: HolidaySubscriptionManager
    @State private var showingCalendarSelection = false
    @State private var readOnlyDetail: ReadOnlyCalendarDetail?
    @State private var showingReadOnlyCreateAlert = false
    @State private var editingUnifiedEntry: UnifiedEntryEditorInitialState?
    @State private var sharedEventEditorRoute: SharedEventEditorRoute?
    @State private var sharedReceivedDayDetailRoute: SharedReceivedDayDetailRoute?
    @State private var entryLoadErrorMessage: String?
    @State private var showingPhotoImport = false
    private let eventUseCase: EventUseCase

    init(
        calendarDisplayUseCase: CalendarDisplayUseCase,
        eventUseCase: EventUseCase,
        holidaySubscriptionManager: HolidaySubscriptionManager,
        calendarSharingStore: CalendarSharingStore
    ) {
        self.eventUseCase = eventUseCase
        self.holidaySubscriptionManager = holidaySubscriptionManager
        _calendarSharingStore = ObservedObject(wrappedValue: calendarSharingStore)
        _viewModel = StateObject(
            wrappedValue: MonthCalendarViewModel(
                calendarDisplayUseCase: calendarDisplayUseCase,
                eventUseCase: eventUseCase,
                calendarSharingStore: calendarSharingStore,
                subscriptionManager: holidaySubscriptionManager
            )
        )
        _statisticsViewModel = StateObject(
            wrappedValue: WorkStatisticsViewModel(
                eventUseCase: eventUseCase,
                calendarID: calendarSharingStore.selection.calendarID
            )
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 背景色覆盖 safe area
            ShiftCalendarColors.backgroundColor
                .ignoresSafeArea(edges: [.top, .bottom])

            VStack(spacing: 0) {
                // 顶部 Header（月 / 周 / 日共用导航布局）
                CalendarHeaderView(
                    title: currentTitle,
                    displayMode: viewModel.displayMode,
                    calendarAvatarInitial: calendarAvatarInitial,
                    calendarSource: calendarSharingStore.selectedCalendar.kind,
                    calendarDisplayName: calendarSharingStore.selectedCalendarDisplayName,
                    isReadOnlyCalendar: !calendarSharingStore.selectedCalendar.canEditContent,
                    weatherAttribution: headerWeatherAttribution,
                    isWeatherAttributionMarkVisible: $isWeatherAttributionMarkVisible,
                    onCalendarTapped: {
                        showingCalendarSelection = true
                    },
                    onStatisticsTapped: openStatistics,
                    onShiftInputTapped: {
                        viewModel.enterShiftInputMode()
                    },
                    onPrevious: handlePrevious,
                    onNext: handleNext,
                    onTitleTapped: {
                        if viewModel.displayMode == .month {
                            showingYearMonthPicker = true
                        }
                    },
                    onSettingsTapped: openSettings
                )

                calendarContent
                    .overlay {
                        if viewModel.isLoading {
                            ProgressView()
                        }
                    }
                    .layoutPriority(1)
                    .simultaneousGesture(calendarSwipeGesture)

                calendarBottomArea
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if showingYearMonthPicker {
                yearMonthPickerOverlay
            }

        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isShiftInputMode)
        .onAppear {
            Task {
                await viewModel.reloadMonth()
                await weatherStore.prepareForUse()
            }
        }
        .onChange(of: calendarSharingStore.revision) { _, _ in
            Task { await viewModel.reloadMonth() }
        }
        .onChange(of: headerWeatherAttribution?.squareMarkURL) { _, _ in
            isWeatherAttributionMarkVisible = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .widgetCalendarDateRequested)) { notification in
            guard let date = notification.object as? Date else { return }
            Task {
                await viewModel.openCalendar(on: date)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .timeNestDataDidRestore)) { _ in
            viewModel.refreshShiftTemplates()
            Task { await viewModel.reloadMonth() }
        }
        .popover(isPresented: $showingCalendarSelection) {
            CalendarSelectionView()
                .environmentObject(calendarSharingStore)
                .environmentObject(localization)
                .presentationCompactAdaptation(.sheet)
        }
        .sheet(item: $readOnlyDetail) { detail in
            ReadOnlySharedCalendarDetailView(detail: detail)
                .environmentObject(localization)
        }
        .sheet(item: $sharedEventEditorRoute) { route in
            SharedEventEditorView(route: route)
                .environmentObject(calendarSharingStore)
                .environmentObject(localization)
        }
        .sheet(item: $sharedReceivedDayDetailRoute) { route in
            SharedReceivedDayDetailView(route: route)
                .environmentObject(calendarSharingStore)
                .environmentObject(localization)
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            // 无论通过关闭按钮还是下拉手势关闭，都刷新 shiftTemplates
            viewModel.refreshShiftTemplates()
        }) {
            NavigationStack {
                SettingsView(
                    subscriptionManager: holidaySubscriptionManager,
                    onClose: { showingSettings = false }
                )
                    .environmentObject(localization)
            }
        }
        .sheet(isPresented: $showingStatistics) {
            WorkStatisticsView(viewModel: statisticsViewModel)
                .environmentObject(localization)
                .onAppear {
                    // 根据视图模式传入正确的基准日期
                    let anchorDate: Date
                    switch viewModel.displayMode {
                    case .month:
                        // 月视图：使用当前正在显示的月份（selectedDate）
                        anchorDate = viewModel.selectedDate
                    case .week:
                        // 周视图：使用当前周所在的日期（selectedDate）
                        anchorDate = viewModel.selectedDate
                    case .day:
                        // 日视图：优先使用 selectedDate，如果没有则使用 today
                        anchorDate = viewModel.selectedDate
                    }
                    statisticsViewModel.setDefaultRange(for: viewModel.displayMode, anchorDate: anchorDate)
                }
        }
        .sheet(isPresented: $viewModel.showingDayDetail) {
            if let cell = viewModel.selectedDayCell {
                DayDetailView(
                    cell: cell,
                    onDeleteEvent: { eventID in
                        Task {
                            await viewModel.deleteEvent(id: eventID)
                        }
                    },
                    onDeleteWorkRecord: { eventIDs in
                        Task {
                            await viewModel.deleteWorkRecord(eventIDs: eventIDs)
                        }
                    },
                    onLoadEntry: { request in
                        try await viewModel.loadUnifiedEntry(request)
                    },
                    onSaveEntry: { request in
                        try await viewModel.saveUnifiedEntry(request)
                    },
                    availableCalendars: calendarSharingStore.writableCalendars,
                    entryCalendarContext: .fixedWritableCalendar(
                        calendarSharingStore.selection.calendarID
                    )
                )
            }
        }
        .sheet(isPresented: $viewModel.showingEntryEditor) {
            let initialDate = viewModel.selectedDate
            EventEditorView(
                isPresented: $viewModel.showingEntryEditor,
                mode: .create(initialDate: initialDate),
                existingEvents: viewModel.selectedDayCell?.events ?? [],
                initialEntryKind: .event,
                availableCalendars: calendarSharingStore.writableCalendars,
                calendarContext: .fixedWritableCalendar(
                    calendarSharingStore.selection.calendarID
                ),
                onSaveEntry: { request in
                    try await viewModel.saveUnifiedEntry(request)
                }
            )
        }
        .sheet(item: $editingUnifiedEntry) { state in
            EventEditorView(
                isPresented: unifiedEntryEditingPresentationBinding,
                mode: .editUnified(state),
                existingEvents: existingEvents(for: state),
                availableCalendars: calendarSharingStore.writableCalendars,
                calendarContext: .fixedWritableCalendar(
                    state.event?.calendarID
                        ?? state.workRecord?.calendarID
                        ?? calendarSharingStore.selection.calendarID
                ),
                onSaveEntry: { request in
                    try await viewModel.saveUnifiedEntry(request)
                }
            )
        }
        .sheet(isPresented: $showingPhotoImport) {
            CalendarPhotoImportView(
                eventUseCase: eventUseCase,
                sharingStore: calendarSharingStore,
                initialDate: viewModel.selectedDate,
                // Reuse the displayed grid, including its subscription/cache fallback rules.
                holidayDates: Set((viewModel.grid?.days ?? [])
                    .filter { !$0.holidays.isEmpty }.map(\.date)),
                onCompleted: {
                    Task { await viewModel.reloadMonth() }
                }
            )
            .environmentObject(localization)
        }
        .alert(
            localization.localized(.calendarSharingReadOnlyAddTitle),
            isPresented: $showingReadOnlyCreateAlert
        ) {
            Button(localization.localized(.ok)) {
                showingReadOnlyCreateAlert = false
            }
            .accessibilityIdentifier("calendar.readOnlyAlert.dismiss")
        } message: {
            Text(localization.localized(.calendarSharingReadOnlyAddMessage))
                .accessibilityIdentifier("calendar.readOnlyAlert.message")
        }
        .alert(
            localization.localized(.workStatisticsReceivedUnavailableTitle),
            isPresented: $showingReceivedStatisticsUnavailable
        ) {
            Button(localization.localized(.ok)) {
                showingReceivedStatisticsUnavailable = false
            }
        } message: {
            Text(localization.localized(.workStatisticsReceivedUnavailableMessage))
        }
        .alert(
            localization.localized(.calendarSharingErrorTitle),
            isPresented: Binding(
                get: { entryLoadErrorMessage != nil },
                set: { if !$0 { entryLoadErrorMessage = nil } }
            )
        ) {
            Button(localization.localized(.ok)) {
                entryLoadErrorMessage = nil
            }
        } message: {
            Text(entryLoadErrorMessage ?? "")
        }
    }

    private var yearMonthPickerOverlay: some View {
        FloatingPickerOverlay(
            alignment: .top,
            onDismiss: { showingYearMonthPicker = false }
        ) {
            YearMonthPickerView(
                currentDate: viewModel.selectedDate,
                onCancel: {
                    showingYearMonthPicker = false
                },
                onSelect: { year, month in
                    showingYearMonthPicker = false
                    Task {
                        await viewModel.goToMonth(year: year, month: month)
                    }
                }
            )
            .environmentObject(localization)
            .padding(.top, ShiftCalendarLayout.headerHeight + 8)
        }
    }

    private func openStatistics() {
        guard calendarSharingStore.selectedCalendar.kind != .sharedReceived else {
            showingReceivedStatisticsUnavailable = true
            return
        }
        statisticsViewModel.setCalendarScope(
            calendarID: calendarSharingStore.selection.calendarID
        )
        openModal(.statistics)
    }

    private func openSettings() {
        openModal(.settings)
    }

    private func openModal(_ destination: CalendarModalDestination) {
        if viewModel.isShiftInputMode {
            viewModel.exitShiftInputMode()
        }
        presentModal(destination)
    }

    private func presentModal(_ destination: CalendarModalDestination) {
        switch destination {
        case .statistics:
            showingStatistics = true
        case .settings:
            showingSettings = true
        }
    }

    private var shiftInputPanel: some View {
        ShiftInputPanelView(
            templates: viewModel.shiftTemplates,
            onSelectTemplate: { template in
                Task {
                    await viewModel.registerShift(template)
                }
            },
            onCancel: {
                Task {
                    await viewModel.cancelShift()
                }
            },
            onDone: {
                viewModel.exitShiftInputMode()
            }
        )
        .environmentObject(localization)
        .padding(.horizontal, ShiftInputPanelLayout.outerHorizontalPadding)
        .padding(.bottom, ShiftInputPanelLayout.outerBottomPadding)
    }

    @ViewBuilder
    private var calendarContent: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .foregroundColor(ShiftCalendarColors.sundayRed)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch viewModel.displayMode {
            case .month:
                if let grid = viewModel.grid {
                    monthCalendarContent(grid: grid)
                } else {
                    Color.clear
                }
            case .week:
                weekCalendarContent()
            case .day:
                dayCalendarContent()
            }
        }
    }

    @ViewBuilder
    private func monthCalendarContent(grid: MonthGrid) -> some View {
        VStack(spacing: 0) {
            // 月历表格 - 最大化占据空间
            GeometryReader { geometry in
                let isShiftInputMode = viewModel.isShiftInputMode
                let weekdayRowHeight: CGFloat = ShiftCalendarLayout.weekdayRowHeight
                let dateRowCount = max(1, grid.days.count / 7)
                let minimumDateCellHeight = isShiftInputMode
                    ? ShiftCalendarLayout.shiftInputDayCellMinHeight
                    : ShiftCalendarLayout.dayCellMinHeight
                let availableDateHeight = CalendarTimelineLayout.nonNegativeDimension(geometry.size.height - weekdayRowHeight)
                let containerWidth = CalendarTimelineLayout.nonNegativeDimension(geometry.size.width)

                // 星期行固定高度 + 当前月份实际需要的日期行
                let dateCellHeight = max(minimumDateCellHeight, availableDateHeight / CGFloat(dateRowCount))
                let cellWidth = containerWidth / 7.0
                let gridHeight = weekdayRowHeight + dateCellHeight * CGFloat(dateRowCount)

                // Cell 层 + 网格线 overlay
                VStack(spacing: 0) {
                    // 第 0 行：星期栏（固定高度）
                    WeekdayHeaderView(
                        weekdaySymbols: viewModel.weekdaySymbols(),
                        cellWidth: cellWidth
                    )
                    .frame(height: weekdayRowHeight)

                    // 日期行：按当前月份实际周数渲染
                    ForEach(0..<dateRowCount, id: \.self) { rowIndex in
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(0..<7, id: \.self) { colIndex in
                                let dayIndex = rowIndex * 7 + colIndex
                                if dayIndex < grid.days.count {
                                    let cell = grid.days[dayIndex]
                                    DayCellView(
                                        cell: cell,
                                        cellWidth: cellWidth,
                                        cellHeight: dateCellHeight,
                                        isSelected: isDayCellSelected(cell),
                                        secondaryDisplayMode: viewModel.monthSecondaryDisplayMode,
                                        weatherSymbolName: monthWeatherSymbol(for: cell)
                                    )
                                    .environmentObject(localization)
                                    .onTapGesture {
                                        handleDayCellTap(cell)
                                    }
                                } else {
                                    // 空 cell
                                    DayCellView(
                                        cell: CalendarDayCell.empty,
                                        cellWidth: cellWidth,
                                        cellHeight: dateCellHeight,
                                        isSelected: false
                                    )
                                    .environmentObject(localization)
                                    .opacity(0)
                                }
                            }
                        }
                        .frame(width: containerWidth, height: dateCellHeight)
                    }
                }
                // 网格线作为 overlay 在最上层绘制，不被任何内容遮挡
                .overlay(
                    gridLinesOverlay(
                        cellWidth: cellWidth,
                        dateCellHeight: dateCellHeight,
                        dateRowCount: dateRowCount,
                        containerWidth: containerWidth,
                        gridHeight: gridHeight
                    )
                )
                .frame(height: gridHeight)
            }
            .frame(maxHeight: .infinity)
        }
        .background(ShiftCalendarColors.backgroundColor)
    }

    @ViewBuilder
    private var calendarBottomArea: some View {
        if viewModel.isShiftInputMode && viewModel.displayMode == .month {
            shiftInputBottomSection
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            calendarBottomSection
        }
    }

    private var calendarBottomSection: some View {
        VStack(spacing: 0) {
            calendarAdBannerArea
            calendarBottomToolbar
                .frame(height: ShiftCalendarLayout.footerToolbarHeight)
        }
        .frame(height: calendarBottomSectionHeight)
        .background(ShiftCalendarColors.backgroundColor)
    }

    private var shiftInputBottomSection: some View {
        VStack(spacing: 0) {
            calendarAdBannerArea
            shiftInputPanel
        }
        .background(ShiftCalendarColors.backgroundColor)
    }

    @ViewBuilder
    private var calendarAdBannerArea: some View {
        if shouldShowAds {
            CalendarAdBannerContainer()
                .frame(height: AdConfiguration.bannerHeight)
        }
    }

    private var calendarAdHeight: CGFloat {
        shouldShowAds ? AdConfiguration.bannerHeight : 0
    }

    private var shouldShowAds: Bool {
        AdConfiguration.isEnabled && !purchaseManager.isAdsRemoved
    }

    private var calendarBottomSectionHeight: CGFloat {
        calendarAdHeight + ShiftCalendarLayout.footerToolbarHeight
    }

    private func isDayCellSelected(_ cell: CalendarDayCell) -> Bool {
        if viewModel.isShiftInputMode {
            guard let targetDate = viewModel.shiftInputTargetDate else { return false }
            return DateOnly(from: targetDate) == cell.date
        }

        return viewModel.selectedDayCell?.id == cell.id
    }

    private var calendarBottomToolbar: some View {
        CalendarBottomToolbarView(
            selectedViewMode: $viewModel.displayMode,
            onTodayTapped: handleTodayTapped,
            onAddEventTapped: {
                if calendarSharingStore.selectedCalendar.kind == .sharedReceived,
                   calendarSharingStore.accessPolicy.canCreateSharedEvent {
                    sharedEventEditorRoute = .create(
                        calendarID: calendarSharingStore.selection.calendarID,
                        date: viewModel.selectedDate
                    )
                } else if calendarSharingStore.accessPolicy.canCreate {
                    Task {
                        await viewModel.openSelectedDateEntryEditor()
                    }
                } else {
                    showingReadOnlyCreateAlert = true
                }
            },
            onScanCalendarTapped: { showingPhotoImport = true },
            onModeChanged: handleModeChanged,
            showsAddButton: calendarSharingStore.accessPolicy.showsAddButton
        )
    }

    private func handleModeChanged(_ mode: CalendarViewMode) {
        switch mode {
        case .month:
            viewModel.switchToMonthView()
        case .week:
            viewModel.switchToWeekView()
        case .day:
            viewModel.switchToDayView()
        }
    }

    /// 网格线 overlay - 使用 Path 精确绘制连续网格线
    @ViewBuilder
    private func gridLinesOverlay(cellWidth: CGFloat, dateCellHeight: CGFloat, dateRowCount: Int, containerWidth: CGFloat, gridHeight: CGFloat) -> some View {
        let lineWidth = ShiftCalendarLayout.gridLineWidth
        let weekdayRowHeight: CGFloat = ShiftCalendarLayout.weekdayRowHeight

        // 横线位置（不等高行）：
        // 第 0 条：0（顶部）
        // 后续横线：weekdayRowHeight + dateCellHeight * 日期行序号（日期行底部）
        // 星期行底部不绘制，避免与 WeekdayHeaderView 背景重叠
        let horizontalLines: [CGFloat] = [0] + (1...dateRowCount).map { weekdayRowHeight + dateCellHeight * CGFloat($0) }

        // 竖线位置：0, cellWidth, cellWidth*2, ..., cellWidth*7 (共 8 条)
        let verticalLines: [CGFloat] = (0...7).map { CGFloat($0) * cellWidth }

        Path { p in
            // 绘制横线
            for y in horizontalLines {
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: containerWidth, y: y))
            }
            // 绘制竖线
            for x in verticalLines {
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: gridHeight))
            }
        }
        .stroke(ShiftCalendarColors.gridLineColor, lineWidth: lineWidth)
    }

    // MARK: - 计算属性与方法

    /// 当前标题 - 根据 displayMode 返回不同格式
    private var currentTitle: String {
        switch viewModel.displayMode {
        case .month:
            viewModel.monthTitle()
        case .week:
            viewModel.weekTitle()
        case .day:
            viewModel.dayTitle()
        }
    }

    /// 日历内容区横向滑动：保留按钮导航，并避免将纵向滚动误判为切换。
    private var calendarSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height

                guard abs(horizontalDistance) > abs(verticalDistance) * 1.2 else {
                    return
                }

                if horizontalDistance < 0 {
                    handleNext()
                } else {
                    handlePrevious()
                }
            }
    }

    /// 处理上一按钮点击
    private func handlePrevious() {
        switch viewModel.displayMode {
        case .month:
            Task {
                await viewModel.goToPreviousMonth()
            }
        case .week:
            let calendar = Calendar(identifier: .gregorian)
            if let newDate = calendar.date(byAdding: .day, value: -7, to: viewModel.selectedDate) {
                viewModel.selectedDate = newDate
                Task {
                    await viewModel.reloadMonth()
                }
            }
        case .day:
            let calendar = Calendar(identifier: .gregorian)
            if let newDate = calendar.date(byAdding: .day, value: -1, to: viewModel.selectedDate) {
                viewModel.selectedDate = newDate
                Task {
                    await viewModel.reloadMonth()
                }
            }
        }
    }

    /// 处理下一按钮点击
    private func handleNext() {
        switch viewModel.displayMode {
        case .month:
            Task {
                await viewModel.goToNextMonth()
            }
        case .week:
            let calendar = Calendar(identifier: .gregorian)
            if let newDate = calendar.date(byAdding: .day, value: 7, to: viewModel.selectedDate) {
                viewModel.selectedDate = newDate
                Task {
                    await viewModel.reloadMonth()
                }
            }
        case .day:
            let calendar = Calendar(identifier: .gregorian)
            if let newDate = calendar.date(byAdding: .day, value: 1, to: viewModel.selectedDate) {
                viewModel.selectedDate = newDate
                Task {
                    await viewModel.reloadMonth()
                }
            }
        }
    }

    /// 处理今日按钮点击
    private func handleTodayTapped() {
        Task {
            await viewModel.goToToday()
        }
    }

    /// 周视图容器
    @ViewBuilder
    private func weekCalendarContent() -> some View {
        VStack(spacing: 0) {
            // 周视图内容
            WeekCalendarView(
                selectedDate: viewModel.selectedDate,
                cells: viewModel.weekCells,
                onDateSelected: { date in
                    viewModel.selectDate(date)
                },
                onEventTapped: handleEventTap,
                weatherByDate: weekWeatherByDate,
                isWeatherEnabled: weatherStore.isEnabled,
                isWeatherLoading: weatherStore.isLoading
            )
            .environmentObject(localization)
        }
        .background(ShiftCalendarColors.backgroundColor)
    }

    /// 日视图容器
    @ViewBuilder
    private func dayCalendarContent() -> some View {
        VStack(spacing: 0) {
            // 日视图内容
            DayCalendarView(
                selectedDate: viewModel.selectedDate,
                cell: viewModel.dayCell,
                onEventTapped: handleEventTap,
                isWeatherEnabled: weatherStore.isEnabled,
                weather: weatherStore.dayWeather(for: viewModel.selectedDate),
                isWeatherLoading: weatherStore.isLoading,
                weatherAttribution: weatherStore.attribution
            )
            .environmentObject(localization)
        }
        .background(ShiftCalendarColors.backgroundColor)
    }

    private var calendarAvatarInitial: String? {
        let calendar = calendarSharingStore.selectedCalendar
        guard calendar.kind != .personal else { return nil }
        return CalendarAvatarInitial.make(
            displayName: calendar.name,
            fallback: localization.localized(.calendarSharingUnknownCalendar)
        )
    }

    private var headerWeatherAttribution: WeatherAttributionSnapshot? {
        guard weatherStore.hasValidWeather else { return nil }
        switch viewModel.displayMode {
        case .month:
            guard viewModel.monthSecondaryDisplayMode == .weather else { return nil }
            return weatherStore.attribution
        case .day:
            return nil
        case .week:
            return weatherStore.attribution
        }
    }

    private var weekWeatherByDate: [DateOnly: DailyWeatherSnapshot] {
        guard weatherStore.isEnabled else { return [:] }
        return Dictionary(
            uniqueKeysWithValues: viewModel.weekCells.compactMap { cell in
                weatherStore.dailyWeather(for: cell.date).map { (cell.date, $0) }
            }
        )
    }

    private func monthWeatherSymbol(for cell: CalendarDayCell) -> String? {
        guard MonthWeatherPresentationPolicy.allowsWeatherDisplay(
            isWeatherEnabled: weatherStore.isEnabled,
            secondaryDisplayMode: viewModel.monthSecondaryDisplayMode,
            isAttributionMarkVisible: isWeatherAttributionMarkVisible
        ) else {
            return nil
        }
        return weatherStore.monthWeatherSymbolName(for: cell.date)
    }

    private func presentReadOnlyDetailIfNeeded(for cell: CalendarDayCell) {
        guard calendarSharingStore.accessPolicy.isReadOnly else { return }
        if cell.events.isEmpty {
            showingReadOnlyCreateAlert = true
        } else {
            readOnlyDetail = ReadOnlyCalendarDetail(date: cell.date.toDate(), events: cell.events)
        }
    }

    private func handleDayCellTap(_ cell: CalendarDayCell) {
        guard calendarSharingStore.selectedCalendar.kind == .sharedReceived else {
            viewModel.selectDay(cell)
            return
        }
        viewModel.selectReadOnlyDay(cell)
        if calendarSharingStore.accessPolicy.canCreateSharedEvent {
            if cell.events.isEmpty {
                sharedEventEditorRoute = .create(
                    calendarID: calendarSharingStore.selection.calendarID,
                    date: cell.date.toDate()
                )
            } else {
                sharedReceivedDayDetailRoute = SharedReceivedDayDetailRoute(
                    calendarID: calendarSharingStore.selection.calendarID,
                    cell: cell
                )
            }
        } else {
            presentReadOnlyDetailIfNeeded(for: cell)
        }
    }

    private func handleEventTap(_ event: EventOccurrence) {
        if calendarSharingStore.selectedCalendar.kind == .sharedReceived {
            let calendarID = calendarSharingStore.selection.calendarID
            if calendarSharingStore.accessPolicy.canEditSharedEvent,
               let snapshot = calendarSharingStore.sharedEventSnapshot(
                calendarID: calendarID,
                eventID: event.eventID
               ) {
                sharedEventEditorRoute = .edit(
                    calendarID: calendarID,
                    snapshot: snapshot
                )
            } else {
                readOnlyDetail = ReadOnlyCalendarDetail(
                    date: event.occurrenceDate.toDate(),
                    events: [event]
                )
            }
            return
        }
        if calendarSharingStore.accessPolicy.isReadOnly {
            presentReadOnlyEventIfNeeded(event)
            return
        }

        entryLoadErrorMessage = nil
        let request: UnifiedEntryLoadRequest
        if event.isWorkClockEvent {
            request = workRecordLoadRequest(for: event)
        } else {
            request = .event(eventID: event.eventID)
        }
        Task {
            do {
                editingUnifiedEntry = try await viewModel.loadUnifiedEntry(request)
            } catch {
                entryLoadErrorMessage = error.localizedDescription
            }
        }
    }

    private func workRecordLoadRequest(
        for event: EventOccurrence
    ) -> UnifiedEntryLoadRequest {
        let dayEvents = viewModel.grid?.days
            .first(where: { $0.date == event.occurrenceDate })?
            .events ?? [event]
        let session = WorkRecordDisplaySession.make(
            from: dayEvents.filter(\.isWorkClockEvent),
            selectedDate: event.occurrenceDate.toDate()
        )
        .first {
            $0.clockIn?.eventID == event.eventID
                || $0.clockOut?.eventID == event.eventID
        }
        return .workRecord(
            clockInEventID: session?.clockIn?.eventID
                ?? (event.isClockInEvent ? event.eventID : nil),
            clockOutEventID: session?.clockOut?.eventID
                ?? (event.isClockOutEvent ? event.eventID : nil),
            workSessionID: event.workInfo?.workSessionId
        )
    }

    private func existingEvents(
        for state: UnifiedEntryEditorInitialState
    ) -> [EventOccurrence] {
        let eventIDs = Set(
            [state.event?.id,
             state.workRecord?.clockInEventID,
             state.workRecord?.clockOutEventID]
                .compactMap { $0 }
        )
        var seen = Set<String>()
        return (viewModel.grid?.days.flatMap(\.events) ?? [])
            .filter { eventIDs.contains($0.eventID) }
            .filter { seen.insert($0.id).inserted }
    }

    private var unifiedEntryEditingPresentationBinding: Binding<Bool> {
        Binding(
            get: { editingUnifiedEntry != nil },
            set: { isPresented in
                if !isPresented {
                    editingUnifiedEntry = nil
                }
            }
        )
    }

    private func presentReadOnlyEventIfNeeded(_ event: EventOccurrence) {
        guard calendarSharingStore.accessPolicy.isReadOnly else { return }
        readOnlyDetail = ReadOnlyCalendarDetail(
            date: event.occurrenceDate.toDate(),
            events: [event]
        )
    }
}

// MARK: - ShiftInputPanelView

private struct ShiftInputPanelView: View {
    @EnvironmentObject private var localization: LocalizationManager

    let templates: [ShiftTimeTemplate]
    let onSelectTemplate: (ShiftTimeTemplate) -> Void
    let onCancel: () -> Void
    let onDone: () -> Void

    private var orderedTemplates: [ShiftTimeTemplate] {
        let favoriteIDs = Set(
            ShiftTemplateFavoritesStore().reconcile(validTemplateIDs: templates.map(\.id))
        )
        return templates.filter { favoriteIDs.contains($0.id.id) }
            + templates.filter { !favoriteIDs.contains($0.id.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ShiftInputHeaderView(
                title: localization.localized(.shiftInputTitle),
                onClose: onDone
            )

            if templates.isEmpty {
                Text(localization.localized(.shiftInputEmpty))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(WorkStatisticsColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ShiftInputPanelLayout.contentHorizontalPadding)
                    .padding(.top, ShiftInputPanelLayout.contentTopPadding)
                    .padding(.bottom, ShiftInputPanelLayout.emptyBottomPadding)
            }

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(
                            minimum: ShiftInputPanelLayout.buttonMinWidth,
                            maximum: ShiftInputPanelLayout.buttonMaxWidth
                        ),
                        spacing: ShiftInputPanelLayout.buttonSpacing
                    )
                ],
                spacing: ShiftInputPanelLayout.buttonSpacing
            ) {
                cancellationButton

                ForEach(orderedTemplates) { template in
                    Button {
                        onSelectTemplate(template)
                    } label: {
                        Text(template.displayName)
                            .font(.system(size: ShiftInputPanelLayout.buttonTitleFontSize, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundColor(buttonTextColor(for: template))
                            .padding(.horizontal, ShiftInputPanelLayout.buttonHorizontalPadding)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: ShiftInputPanelLayout.buttonHeight
                            )
                            .background(buttonBackgroundColor(for: template))
                            .overlay(
                                RoundedRectangle(cornerRadius: ShiftInputPanelLayout.buttonCornerRadius, style: .continuous)
                                    .stroke(WorkStatisticsColors.border, lineWidth: 0.8)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: ShiftInputPanelLayout.buttonCornerRadius, style: .continuous))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, ShiftInputPanelLayout.contentHorizontalPadding)
            .padding(.top, templates.isEmpty ? 0 : ShiftInputPanelLayout.contentTopPadding)
            .padding(.bottom, ShiftInputPanelLayout.buttonBottomPadding)
        }
        .frame(maxWidth: .infinity)
        .background(ShiftCalendarColors.backgroundColor)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ShiftCalendarColors.separatorColor)
                .frame(height: ShiftCalendarLayout.gridLineWidth)
        }
    }

    private var cancellationButton: some View {
        Button(action: onCancel) {
            Text(localization.localized(.cancel))
                .font(.system(size: ShiftInputPanelLayout.buttonTitleFontSize, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundColor(ShiftCalendarColors.sundayRed)
                .padding(.horizontal, ShiftInputPanelLayout.buttonHorizontalPadding)
                .frame(
                    maxWidth: .infinity,
                    minHeight: ShiftInputPanelLayout.buttonHeight
                )
                .background(ShiftCalendarColors.sundayRed.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: ShiftInputPanelLayout.buttonCornerRadius, style: .continuous)
                        .stroke(ShiftCalendarColors.sundayRed, lineWidth: 0.8)
                )
                .clipShape(RoundedRectangle(cornerRadius: ShiftInputPanelLayout.buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func buttonBackgroundColor(for template: ShiftTimeTemplate) -> Color {
        template.displayBackgroundColor
    }

    private func buttonTextColor(for _: ShiftTimeTemplate) -> Color {
        ShiftCalendarColors.primaryText
    }

}

private struct ShiftInputHeaderView: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: ShiftInputPanelLayout.headerControlSpacing) {
            Text(title)
                .font(TimeNestTheme.Fonts.popupTitle)
                .foregroundColor(ShiftCalendarColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: ShiftInputPanelLayout.headerControlSpacing)

            ModalHeaderCloseButton(action: onClose)
                .frame(
                    width: SettingsModalSurface.closeButtonSize,
                    height: SettingsModalSurface.closeButtonSize
                )
        }
        .padding(.horizontal, ShiftInputPanelLayout.contentHorizontalPadding)
        .padding(.vertical, ShiftInputPanelLayout.headerVerticalPadding)
        .background(ShiftCalendarColors.backgroundColor)
    }
}

// MARK: - DayCellView

struct MonthDayCellContentVisibility<Item> {
    let visibleItems: [Item]
    let hiddenCount: Int
}

enum MonthDayCellEventLayout {
    static let directContentLimit = 4
    private static let overflowContentLimit = 3

    static func visibility<Item>(for items: [Item]) -> MonthDayCellContentVisibility<Item> {
        guard items.count > directContentLimit else {
            return MonthDayCellContentVisibility(visibleItems: items, hiddenCount: 0)
        }

        return MonthDayCellContentVisibility(
            visibleItems: Array(items.prefix(overflowContentLimit)),
            hiddenCount: items.count - overflowContentLimit
        )
    }
}

struct DayCellView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @AppStorage(CalendarItemColorSettings.eventBackgroundColorKey) private var eventBackgroundColorHex = CalendarItemColorSettings.defaultEventBackgroundColorHex
    @AppStorage(CalendarItemColorSettings.workRecordBackgroundColorKey) private var workRecordBackgroundColorHex = CalendarItemColorSettings.defaultWorkRecordBackgroundColorHex
    let cell: CalendarDayCell
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let isSelected: Bool
    var secondaryDisplayMode: MonthSecondaryDisplayMode = .none
    var weatherSymbolName: String? = nil

    private enum Layout {
        static let headerTopPadding: CGFloat = 3
        static let headerHeight: CGFloat = 30
        static let weatherSymbolSize: CGFloat = 17
        static let eventTopSpacing: CGFloat = 2
        static let eventRowSpacing: CGFloat = 1
        static let eventRowVerticalPadding: CGFloat = 1
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 背景
            Rectangle()
                .fill(cellBackgroundColor)

            // 选中状态边框 - 红色 2pt，贴着 cell 边缘
            if isSelected {
                Rectangle()
                    .stroke(ShiftCalendarColors.selectedDayBorder, lineWidth: 2)
            }

            // 内容区域 - 统一从顶部对齐
            VStack(alignment: .leading, spacing: 0) {
                // 日期与单一辅助信息共用固定顶部区域，天气不会改变 Cell 高度或事件配额。
                topInformationView

                eventLabelsView
                    .padding(.top, Layout.eventTopSpacing)

                // 弹性空间 - 将底部标签推到底部
                Spacer(minLength: 2)

                // 底部区域：节假日标签或排班标签
                // 节假日标签 - 底部居中，优先于排班标签显示
                if !cell.holidays.isEmpty {
                    holidayLabelsView
                } else if let shiftType = cell.shiftType {
                    // 排班标签 - 底部居中，圆角矩形样式
                    Text(shiftType)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(shiftType.shiftLabelForegroundColor)
                        .frame(maxWidth: .infinity, minHeight: ShiftCalendarLayout.shiftLabelHeight)
                        .background(shiftType.shiftLabelBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: ShiftCalendarLayout.shiftLabelCornerRadius, style: .continuous)
                                .stroke(shiftType.shiftLabelBorderColor, lineWidth: 0.8)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: ShiftCalendarLayout.shiftLabelCornerRadius, style: .continuous))
                        .padding(.horizontal, 2)
                        .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: cellWidth, height: cellHeight)
        .opacity(cell.isInCurrentMonth ? 1.0 : 0.5)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("calendar.day.\(cell.id)")
    }

    private enum TraditionalCalendarLabelKind {
        case solarTerm
        case lunar
        case rokuyo

        var accessibilityIdentifier: String {
            switch self {
            case .solarTerm:
                "calendar.traditional.solarTerm"
            case .lunar:
                "calendar.traditional.lunar"
            case .rokuyo:
                "calendar.traditional.rokuyo"
            }
        }
    }

    private struct TraditionalCalendarLabel: Identifiable {
        let kind: TraditionalCalendarLabelKind
        let text: String

        var id: String { kind.accessibilityIdentifier }
    }

    private var selectedTraditionalCalendarLabel: TraditionalCalendarLabel? {
        switch secondaryDisplayMode {
        case .lunar:
            cell.traditionalCalendar.lunarText.map {
                TraditionalCalendarLabel(kind: .lunar, text: $0)
            }
        case .rokuyo:
            cell.traditionalCalendar.rokuyoText.map {
                TraditionalCalendarLabel(kind: .rokuyo, text: $0)
            }
        case .solarTerm:
            cell.traditionalCalendar.solarTermText.map {
                TraditionalCalendarLabel(kind: .solarTerm, text: $0)
            }
        case .none, .weather:
            nil
        }
    }

    private var topInformationView: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(cell.dayText)
                .font(.system(
                    size: cell.isToday ? ShiftCalendarLayout.dayNumberFontSizeToday : ShiftCalendarLayout.dayNumberFontSize,
                    weight: cell.isToday ? .semibold : .medium
                ))
                .foregroundColor(dayNumberColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.leading, 8)
                .padding(.top, Layout.headerTopPadding)

            if secondaryDisplayMode == .weather, let weatherSymbolName {
                Image(systemName: weatherSymbolName)
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(Color(uiColor: .systemBlue))
                    .font(.system(size: Layout.weatherSymbolSize, weight: .semibold))
                    .shadow(
                        color: Color(uiColor: .systemGray).opacity(0.45),
                        radius: 0.75
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, Layout.headerTopPadding)
                    .padding(.trailing, 5)
                    .accessibilityIdentifier("calendar.weather.\(cell.id)")
            } else if let selectedTraditionalCalendarLabel {
                traditionalCalendarLabelView(selectedTraditionalCalendarLabel)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, Layout.headerTopPadding)
                    .padding(.trailing, 3)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Layout.headerHeight, maxHeight: Layout.headerHeight, alignment: .topLeading)
    }

    private func traditionalCalendarLabelView(_ label: TraditionalCalendarLabel) -> some View {
        Text(label.text)
            .font(.system(
                size: label.kind == .solarTerm ? 8.5 : 8,
                weight: label.kind == .solarTerm ? .semibold : .regular
            ))
            .foregroundColor(
                label.kind == .solarTerm
                    ? ShiftCalendarColors.primaryBlueDark
                    : ShiftCalendarColors.secondaryText
            )
            .lineLimit(1)
            .allowsTightening(true)
            .minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity, minHeight: 9, alignment: .trailing)
            .accessibilityIdentifier(
                "\(label.kind.accessibilityIdentifier).\(cell.id)"
            )
    }


    @ViewBuilder
    private var eventLabelsView: some View {
        let visibility = MonthDayCellEventLayout.visibility(for: eventLabelRows)
        let visibleRows = visibility.visibleItems
        let hiddenCount = visibility.hiddenCount

        if !visibleRows.isEmpty {
            VStack(alignment: .center, spacing: Layout.eventRowSpacing) {
                ForEach(Array(visibleRows.enumerated()), id: \.offset) { _, row in
                    eventLabelRowView(row)
                }

                if hiddenCount > 0 {
                    Text(moreEventsText(hiddenCount))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(ShiftCalendarColors.secondaryText)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private enum EventLabelRow {
        case workRecord(WorkRecordDisplaySession)
        case event(EventOccurrence)
    }

    private var eventLabelRows: [EventLabelRow] {
        var shiftRows: [EventLabelRow] = []
        var workRecordRows: [EventLabelRow] = []
        var normalRows: [EventLabelRow] = []

        let displayItems = LinkedEntryDisplayAssembler.make(
            from: cell.events,
            selectedDate: cell.date.toDate()
        )
        for item in displayItems {
            if let event = item.event {
                if event.shiftTemplateID != nil {
                    shiftRows.append(.event(event))
                } else {
                    normalRows.append(.event(event))
                }
            } else if let workRecord = item.workRecord {
                workRecordRows.append(.workRecord(workRecord))
            }
        }

        return shiftRows + workRecordRows + normalRows
    }

    @ViewBuilder
    private func eventLabelRowView(_ row: EventLabelRow) -> some View {
        switch row {
        case .workRecord(let session):
            workRecordLabelView(for: session)
        case .event(let event):
            eventLabelView(for: event)
        }
    }

    @ViewBuilder
    private func eventLabelView(for event: EventOccurrence) -> some View {
        Text(eventLabel(for: event))
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(eventLabelTextColor(for: event))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 4)
            .padding(.vertical, Layout.eventRowVerticalPadding)
            .frame(maxWidth: .infinity)
            .background(eventLabelBackgroundColor(for: event))
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(eventLabelBorderColor(for: event), lineWidth: 0.7)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }

    @ViewBuilder
    private func workRecordLabelView(for session: WorkRecordDisplaySession) -> some View {
        Text(session.displayTitle(defaultTitle: localization.localized(.workRecordDefaultTitle)))
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(workRecordLabelTextColor)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 4)
            .padding(.vertical, Layout.eventRowVerticalPadding)
            .frame(maxWidth: .infinity)
            .background(workRecordLabelBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }

    private func eventLabel(for event: EventOccurrence) -> String {
        // 优先显示标题，标题为空时才 fallback 到时间
        if !event.title.isEmpty {
            return event.localizedDisplayTitle
        }
        // Fallback: 标题为空时显示时间
        return formatTime(event.startDate)
    }

    private func eventLabelTextColor(for event: EventOccurrence) -> Color {
        let fallback = event.shiftDisplayColor.map { ShiftDisplayColors.calendarLabelForegroundColor(for: $0) }
            ?? ShiftCalendarColors.primaryBlueDark
        return CalendarItemColorSettings.foregroundColor(
            for: event,
            eventBackgroundColorHex: eventBackgroundColorHex,
            workRecordBackgroundColorHex: workRecordBackgroundColorHex,
            lightBackgroundFallback: fallback
        )
    }

    private func eventLabelBackgroundColor(for event: EventOccurrence) -> Color {
        let shiftFallback = event.shiftDisplayColor.map { ShiftDisplayColors.calendarLabelBackgroundColor(for: $0) }
            ?? ShiftCalendarColors.primaryBlue.opacity(0.12)
        return CalendarItemColorSettings.backgroundColor(
            for: event,
            eventBackgroundColorHex: eventBackgroundColorHex,
            workRecordBackgroundColorHex: workRecordBackgroundColorHex,
            shiftFallback: shiftFallback
        )
    }

    private func eventLabelBorderColor(for event: EventOccurrence) -> Color {
        guard let shiftColor = event.shiftDisplayColor else {
            return .clear
        }
        return ShiftDisplayColors.calendarLabelBorderColor(for: shiftColor)
    }

    private var workRecordLabelBackgroundColor: Color {
        CalendarItemColorSettings.backgroundColor(
            for: .workRecord,
            eventBackgroundColorHex: eventBackgroundColorHex,
            workRecordBackgroundColorHex: workRecordBackgroundColorHex
        )
    }

    private var workRecordLabelTextColor: Color {
        CalendarItemColorSettings.foregroundColor(
            for: .workRecord,
            eventBackgroundColorHex: eventBackgroundColorHex,
            workRecordBackgroundColorHex: workRecordBackgroundColorHex,
            lightBackgroundFallback: ShiftCalendarColors.primaryBlueDark
        )
    }

    private func formatTime(_ date: Date) -> String {
        LocalizationManager.shared.dateFormatter(dateFormat: "HH:mm").string(from: date)
    }

    private var cellBackgroundColor: Color {
        if cell.isToday {
            return Color(red: 0.90, green: 0.94, blue: 1.0)
        }
        return .white
    }

    private var dayNumberColor: Color {
        if !cell.isInCurrentMonth {
            return ShiftCalendarColors.otherMonthGray
        }
        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: cell.date.toDate())
        switch CalendarDateDisplayKind.resolve(weekday: weekday, isHoliday: !cell.holidays.isEmpty) {
        case .sundayOrHoliday:
            return ShiftCalendarColors.sundayRed
        case .saturday:
            return ShiftCalendarColors.saturdayBlue
        case .normal:
            return ShiftCalendarColors.primaryText
        }
    }

    
    /// 节假日标签视图 - 支持多国节假日显示
    @ViewBuilder
    private var holidayLabelsView: some View {
        let holidayNames = holidayDisplayNames
        if holidayNames.count == 1 {
            // 单个节假日：简单显示
            Text(holidayNames[0])
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(ShiftCalendarColors.sundayRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
        } else {
            // 多个节假日：分行显示
            VStack(spacing: 2) {
                ForEach(Array(holidayNames.enumerated()), id: \.offset) { index, name in
                    Text(name)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(ShiftCalendarColors.sundayRed)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
    }
    
    /// 获取节假日显示名称数组（根据节假日所属地区选择对应语言）
    private var holidayDisplayNames: [String] {
        return cell.holidays.map { holiday in
            // 根据节假日所属地区选择对应语言名称，而不是根据当前 App 语言
            holiday.localizedNames.displayName(for: holiday.region)
        }
    }
}
