import SwiftUI

struct MonthCalendarView: View {
    @StateObject private var viewModel: MonthCalendarViewModel
    @State private var showingYearMonthPicker = false
    @State private var showingSettings = false
    @State private var showingStatistics = false
    @StateObject private var statisticsViewModel: WorkStatisticsViewModel
    @EnvironmentObject private var localization: LocalizationManager

    init(calendarDisplayUseCase: CalendarDisplayUseCase, eventUseCase: EventUseCase) {
        _viewModel = StateObject(
            wrappedValue: MonthCalendarViewModel(
                calendarDisplayUseCase: calendarDisplayUseCase,
                eventUseCase: eventUseCase
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
                    onStatisticsTapped: {
                        showingStatistics = true
                    },
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
                    onSettingsTapped: {
                        showingSettings = true
                    }
                )

                // 视图内容
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(ShiftCalendarColors.sundayRed)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    switch viewModel.displayMode {
                    case .month:
                        if let grid = viewModel.grid {
                            monthCalendarWithBottomSection(grid: grid)
                        }
                    case .week:
                        weekCalendarWithBottomSection()
                    case .day:
                        dayCalendarWithBottomSection()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.isShiftInputMode {
                shiftInputPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isShiftInputMode)
        .onAppear {
            Task {
                await viewModel.reloadMonth()
            }
        }
        .sheet(isPresented: $showingYearMonthPicker) {
            YearMonthPickerView(currentDate: viewModel.selectedDate) { year, month in
                Task {
                    await viewModel.goToMonth(year: year, month: month)
                }
            }
            .environmentObject(localization)
        }
        .sheet(isPresented: $viewModel.showingEventEditor) {
            EventEditorView(
                isPresented: $viewModel.showingEventEditor,
                mode: .create(initialDate: viewModel.selectedDate),
                existingEvents: viewModel.selectedDateEvents,
                onSave: { title, note, startDate, endDate, isAllDay, reminderOffsetMinutes, shiftTemplateID, workInfo in
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
                }
            )
        }
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                SettingsView()
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

    private var shiftInputPanel: some View {
        ShiftInputPanelView(
            templates: viewModel.shiftTemplates,
            selectedTemplate: viewModel.selectedShiftTemplate,
            onSelectTemplate: { template in
                viewModel.selectShiftTemplate(template)
            },
            onDone: {
                viewModel.exitShiftInputMode()
            }
        )
        .environmentObject(localization)
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .background(ShiftCalendarColors.backgroundColor)
    }

    @ViewBuilder
    private func calendarWithBottomSection(_ grid: MonthGrid) -> some View {
        VStack(spacing: 0) {
            // 月历表格 - 最大化占据空间
            GeometryReader { geometry in
                let adBannerHeight: CGFloat = ShiftCalendarLayout.adBannerHeight
                let toolbarHeight: CGFloat = CalendarBottomToolbarLayout.toolbarHeight
                let weekdayRowHeight: CGFloat = ShiftCalendarLayout.weekdayRowHeight
                let dateRowCount = max(1, grid.days.count / 7)

                // 可用高度 = 总高度 - adBanner - toolbar（header 已在 VStack 中占用）
                let availableHeight = geometry.size.height - adBannerHeight - toolbarHeight
                // 星期行固定高度 + 当前月份实际需要的日期行
                let dateCellHeight = max(ShiftCalendarLayout.dayCellMinHeight, (availableHeight - weekdayRowHeight) / CGFloat(dateRowCount))
                let containerWidth = geometry.size.width
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
                                        isSelected: viewModel.selectedDayCell?.id == cell.id
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

            // 广告 banner 占位
            AdBannerPlaceholderView()

            // 底部工具栏
            calendarBottomToolbar
        }
        .background(ShiftCalendarColors.backgroundColor)
    }

    private var calendarBottomToolbar: some View {
        CalendarBottomToolbarView(
            selectedViewMode: $viewModel.displayMode,
            onTodayTapped: handleTodayTapped,
            onAddEventTapped: {
                viewModel.showingEventEditor = true
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

    /// 月视图容器
    @ViewBuilder
    private func monthCalendarWithBottomSection(grid: MonthGrid) -> some View {
        calendarWithBottomSection(grid)
    }

    /// 周视图容器
    @ViewBuilder
    private func weekCalendarWithBottomSection() -> some View {
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

            // 广告 banner 占位
            AdBannerPlaceholderView()

            // 底部工具栏 - 绑定到 viewModel.displayMode
            calendarBottomToolbar
        }
        .background(ShiftCalendarColors.backgroundColor)
    }

    /// 日视图容器
    @ViewBuilder
    private func dayCalendarWithBottomSection() -> some View {
        VStack(spacing: 0) {
            // 日视图内容
            DayCalendarView(
                selectedDate: viewModel.selectedDate,
                cell: viewModel.dayCell
            )
            .environmentObject(localization)

            // 广告 banner 占位
            AdBannerPlaceholderView()

            // 底部工具栏 - 绑定到 viewModel.displayMode
            calendarBottomToolbar
        }
        .background(ShiftCalendarColors.backgroundColor)
    }
}

// MARK: - ShiftInputPanelView

private struct ShiftInputPanelView: View {
    let templates: [ShiftTimeTemplate]
    let selectedTemplate: ShiftTimeTemplate?
    let onSelectTemplate: (ShiftTimeTemplate) -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(WorkStatisticsColors.handle)
                .frame(
                    width: WorkStatisticsLayout.handleWidth,
                    height: WorkStatisticsLayout.handleHeight
                )
                .padding(.top, 10)

            HStack(spacing: 12) {
                Text(LocalizedStringKey(LocalizedString.shiftInputTitle.rawValue))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(WorkStatisticsColors.primaryText)
                    .lineLimit(1)

                Spacer()

                Button(action: onDone) {
                    Text(LocalizedStringKey(LocalizedString.done.rawValue))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ShiftCalendarColors.primaryBlue)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(WorkStatisticsColors.sectionBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, WorkStatisticsLayout.horizontalPadding)

            if templates.isEmpty {
                Text(LocalizedStringKey(LocalizedString.shiftInputEmpty.rawValue))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(WorkStatisticsColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, WorkStatisticsLayout.horizontalPadding)
                    .padding(.bottom, 18)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(templates) { template in
                            Button {
                                onSelectTemplate(template)
                            } label: {
                                VStack(spacing: 2) {
                                    Text(template.displayName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)

                                    Text(template.displayTime)
                                        .font(.system(size: 11, weight: .medium))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .foregroundColor(buttonTextColor(for: template))
                                .padding(.horizontal, 12)
                                .frame(width: 104, height: 48)
                                .background(buttonBackgroundColor(for: template))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(buttonBorderColor(for: template), lineWidth: isSelected(template) ? 2 : 0.8)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, WorkStatisticsLayout.horizontalPadding)
                    .padding(.bottom, 18)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(WorkStatisticsColors.sheetBackground)
        .clipShape(RoundedRectangle(cornerRadius: WorkStatisticsLayout.sheetCornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.16), radius: 18, x: 0, y: -4)
    }

    private func isSelected(_ template: ShiftTimeTemplate) -> Bool {
        selectedTemplate?.id == template.id
    }

    private func buttonBackgroundColor(for template: ShiftTimeTemplate) -> Color {
        isSelected(template) ? template.color : template.color.opacity(0.24)
    }

    private func buttonTextColor(for template: ShiftTimeTemplate) -> Color {
        isSelected(template) ? template.buttonTextColor : WorkStatisticsColors.primaryText
    }

    private func buttonBorderColor(for template: ShiftTimeTemplate) -> Color {
        isSelected(template) ? ShiftCalendarColors.primaryBlue : WorkStatisticsColors.border
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
                    HStack {
                        Text(shiftType)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(shiftType.shiftLabelColor)
                            .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, ShiftCalendarLayout.shiftLabelHorizontalPadding)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: cellWidth, height: cellHeight)
        .opacity(cell.isInCurrentMonth ? 1.0 : 0.5)
    }


    @ViewBuilder
    private var eventLabelsView: some View {
        let visibleEvents = Array(cell.events.prefix(3))
        let hiddenCount = max(0, cell.events.count - visibleEvents.count)

        if !visibleEvents.isEmpty {
            VStack(alignment: .center, spacing: 2) {
                ForEach(visibleEvents, id: \.id) { event in
                    HStack {
                        Spacer(minLength: 0)
                        Text(eventLabel(for: event))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(eventLabelTextColor(for: event))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(eventLabelBackgroundColor(for: event))
                            .cornerRadius(3)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
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

    private func eventLabel(for event: EventOccurrence) -> String {
        // 优先显示标题，标题为空时才 fallback 到时间
        if !event.title.isEmpty {
            return event.title
        }
        // Fallback: 标题为空时显示时间
        return formatTime(event.startDate)
    }

    private func eventLabelTextColor(for event: EventOccurrence) -> Color {
        guard let shiftTemplateID = event.shiftTemplateID else {
            return ShiftCalendarColors.primaryBlueDark
        }
        // 判断颜色深浅，决定使用深色还是白色文字
        let uiColor = UIColor(shiftTemplateID.color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let brightness = (r * 299 + g * 587 + b * 114) / 1000
        return brightness < 0.5 ? .white : ShiftCalendarColors.primaryBlueDark
    }

    private func eventLabelBackgroundColor(for event: EventOccurrence) -> Color {
        guard let shiftTemplateID = event.shiftTemplateID else {
            return ShiftCalendarColors.primaryBlue.opacity(0.12)
        }
        return shiftTemplateID.color.opacity(0.12)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
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

// MARK: - Preview

#Preview {
    MonthCalendarView(
        calendarDisplayUseCase: CalendarDisplayUseCase(
            holidayUseCase: HolidayUseCase(holidayProvider: BundleHolidayProvider()),
            localizationUseCase: CalendarLocalizationUseCase(),
            eventUseCase: EventUseCase(repository: InMemoryEventRepository())
        ),
        eventUseCase: EventUseCase(repository: InMemoryEventRepository())
    )
}
