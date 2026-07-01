import SwiftUI

private enum CalendarModalDestination {
    case statistics
    case settings
}

struct MonthCalendarView: View {
    @StateObject private var viewModel: MonthCalendarViewModel
    @State private var showingYearMonthPicker = false
    @State private var showingSettings = false
    @State private var showingStatistics = false
    @StateObject private var statisticsViewModel: WorkStatisticsViewModel
    @EnvironmentObject private var localization: LocalizationManager
    @ObservedObject private var purchaseManager = RemoveAdsPurchaseManager.shared
    private let holidaySubscriptionManager: HolidaySubscriptionManager

    init(
        calendarDisplayUseCase: CalendarDisplayUseCase,
        eventUseCase: EventUseCase,
        holidaySubscriptionManager: HolidaySubscriptionManager
    ) {
        self.holidaySubscriptionManager = holidaySubscriptionManager
        _viewModel = StateObject(
            wrappedValue: MonthCalendarViewModel(
                calendarDisplayUseCase: calendarDisplayUseCase,
                eventUseCase: eventUseCase,
                subscriptionManager: holidaySubscriptionManager
            )
        )
        _statisticsViewModel = StateObject(wrappedValue: WorkStatisticsViewModel(eventUseCase: eventUseCase))
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
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .widgetCalendarDateRequested)) { notification in
            guard let date = notification.object as? Date else { return }
            Task {
                await viewModel.openCalendar(on: date)
            }
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
                    onCreateEvent: { title, note, startDate, endDate, isAllDay, reminderOffsetMinutes, shiftTemplateID, workInfo in
                        try await viewModel.createEvent(
                            title: title,
                            note: note,
                            startDate: startDate,
                            endDate: endDate,
                            isAllDay: isAllDay,
                            reminderOffsetMinutes: reminderOffsetMinutes,
                            shiftTemplateID: shiftTemplateID,
                            workInfo: workInfo
                        )
                    },
                    onUpdateEvent: { eventID, title, note, startDate, endDate, isAllDay, reminderOffsetMinutes, shiftTemplateID, workInfo in
                        try await viewModel.updateEvent(
                            id: eventID,
                            title: title,
                            note: note,
                            startDate: startDate,
                            endDate: endDate,
                            isAllDay: isAllDay,
                            reminderOffsetMinutes: reminderOffsetMinutes,
                            shiftTemplateID: shiftTemplateID,
                            workInfo: workInfo
                        )
                    }
                )
            }
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
                                        isSelected: isDayCellSelected(cell)
                                    )
                                    .environmentObject(localization)
                                    .onTapGesture {
                                        viewModel.selectDay(cell)
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
                Task {
                    await viewModel.openSelectedDateDetail()
                }
            },
            onModeChanged: handleModeChanged
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
                }
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
                cell: viewModel.dayCell
            )
            .environmentObject(localization)
        }
        .background(ShiftCalendarColors.backgroundColor)
    }
}

// MARK: - ShiftInputPanelView

private struct ShiftInputPanelView: View {
    @EnvironmentObject private var localization: LocalizationManager

    let templates: [ShiftTimeTemplate]
    let onSelectTemplate: (ShiftTimeTemplate) -> Void
    let onCancel: () -> Void
    let onDone: () -> Void

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

                ForEach(templates) { template in
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

struct DayCellView: View {
    @EnvironmentObject private var localization: LocalizationManager
    let cell: CalendarDayCell
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let isSelected: Bool

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
                // 顶部区域：日期数字
                Text(cell.dayText)
                    .font(.system(
                        size: cell.isToday ? ShiftCalendarLayout.dayNumberFontSizeToday : ShiftCalendarLayout.dayNumberFontSize,
                        weight: cell.isToday ? .semibold : .medium
                    ))
                    .foregroundColor(dayNumberColor)
                    .padding(.leading, 8)
                    .padding(.top, 8)

                eventLabelsView
                    .padding(.top, 4)

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
    }


    @ViewBuilder
    private var eventLabelsView: some View {
        let rows = eventLabelRows
        let visibleRows = Array(rows.prefix(3))
        let hiddenCount = max(0, rows.count - visibleRows.count)

        if !visibleRows.isEmpty {
            VStack(alignment: .center, spacing: 2) {
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
        var workClockEvents: [EventOccurrence] = []
        var shiftRows: [EventLabelRow] = []
        var normalRows: [EventLabelRow] = []

        for event in cell.events {
            if event.isWorkClockEvent {
                workClockEvents.append(event)
                continue
            }
            if event.shiftTemplateID != nil {
                shiftRows.append(.event(event))
            } else {
                normalRows.append(.event(event))
            }
        }

        let workRecordRows = WorkRecordDisplaySession
            .make(from: workClockEvents, selectedDate: cell.date.toDate())
            .map(EventLabelRow.workRecord)

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
            .padding(.vertical, 2)
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
            .foregroundColor(ShiftCalendarColors.primaryBlueDark)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity)
            .background(workRecordLabelBackgroundColor(for: session))
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
        guard let shiftTemplateID = event.shiftTemplateID else {
            return ShiftCalendarColors.primaryBlueDark
        }
        return ShiftDisplayColors.calendarLabelForegroundColor(for: shiftTemplateID.color)
    }

    private func eventLabelBackgroundColor(for event: EventOccurrence) -> Color {
        guard let shiftTemplateID = event.shiftTemplateID else {
            return ShiftCalendarColors.primaryBlue.opacity(0.12)
        }
        return ShiftDisplayColors.calendarLabelBackgroundColor(for: shiftTemplateID.color)
    }

    private func eventLabelBorderColor(for event: EventOccurrence) -> Color {
        guard let shiftTemplateID = event.shiftTemplateID else {
            return .clear
        }
        return ShiftDisplayColors.calendarLabelBorderColor(for: shiftTemplateID.color)
    }

    private func workRecordLabelBackgroundColor(for session: WorkRecordDisplaySession) -> Color {
        if let clockIn = session.clockIn {
            return eventLabelBackgroundColor(for: clockIn)
        }
        if let clockOut = session.clockOut {
            return eventLabelBackgroundColor(for: clockOut)
        }
        return ShiftCalendarColors.primaryBlue.opacity(0.12)
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
        // 节假日优先于周末颜色
        if !cell.holidays.isEmpty {
            return ShiftCalendarColors.sundayRed
        }
        // 使用 isWeekend 属性判断周末，而不是硬编码星期文字
        if cell.isWeekend, let weekendColor = ShiftCalendarColors.weekendTextColor(for: cell.weekdayText) {
            return weekendColor
        }
        return ShiftCalendarColors.primaryText
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
