import SwiftUI

struct MonthCalendarView: View {
    @StateObject private var viewModel: MonthCalendarViewModel

    init(calendarDisplayUseCase: CalendarDisplayUseCase, eventUseCase: EventUseCase) {
        _viewModel = StateObject(
            wrappedValue: MonthCalendarViewModel(
                calendarDisplayUseCase: calendarDisplayUseCase,
                eventUseCase: eventUseCase
            )
        )
    }

    var body: some View {
        ZStack {
            ShiftCalendarColors.backgroundColor

            VStack(spacing: 0) {
                // 顶部 Header
                CalendarHeaderView(
                    title: viewModel.monthTitle(),
                    onPreviousMonth: {
                        Task {
                            await viewModel.goToPreviousMonth()
                        }
                    },
                    onNextMonth: {
                        Task {
                            await viewModel.goToNextMonth()
                        }
                    },
                    onAddButtonTapped: {
                        viewModel.showingEventEditor = true
                    }
                )

                // 月历 Grid + 底部区域
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(ShiftCalendarColors.sundayRed)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let grid = viewModel.grid {
                    calendarWithBottomSection(grid)
                }
            }
        }
        .padding(.horizontal, ShiftCalendarLayout.calendarGridHorizontalPadding)
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            Task {
                await viewModel.reloadMonth()
            }
        }
        .sheet(isPresented: $viewModel.showingEventEditor) {
            EventEditorView(
                isPresented: $viewModel.showingEventEditor,
                mode: .create(initialDate: Date()),
                onSave: { title, date, isAllDay in
                    try await viewModel.createEvent(
                        title: title,
                        date: date,
                        isAllDay: isAllDay
                    )
                }
            )
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
                    onUpdateEvent: { eventID, title, date, isAllDay in
                        await viewModel.updateEvent(
                            id: eventID,
                            title: title,
                            date: date,
                            isAllDay: isAllDay
                        )
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func calendarWithBottomSection(_ grid: MonthGrid) -> some View {
        VStack(spacing: 0) {
            // 月历表格 - 最大化占据空间
            GeometryReader { geometry in
                let headerHeight: CGFloat = ShiftCalendarLayout.headerHeight
                let infoBarHeight: CGFloat = ShiftCalendarLayout.selectedDateInfoHeight
                let adBannerHeight: CGFloat = ShiftCalendarLayout.adBannerHeight
                let tabBarHeight: CGFloat = ShiftCalendarLayout.tabBarHeight
                let weekdayRowHeight: CGFloat = ShiftCalendarLayout.weekdayRowHeight

                // 可用高度 = 总高度 - header - infoBar - adBanner - tabBar
                let availableHeight = geometry.size.height - headerHeight - infoBarHeight - adBannerHeight - tabBarHeight
                // 星期行固定高度 + 6 行日期
                let dateCellHeight = max(ShiftCalendarLayout.dayCellMinHeight, (availableHeight - weekdayRowHeight) / 6.0)
                let containerWidth = geometry.size.width
                let cellWidth = containerWidth / 7.0
                let gridHeight = weekdayRowHeight + dateCellHeight * 6

                // Cell 层 + 网格线 overlay
                VStack(spacing: 0) {
                    // 第 0 行：星期栏（固定高度）
                    WeekdayHeaderView(
                        weekdaySymbols: viewModel.weekdaySymbols(),
                        cellWidth: cellWidth
                    )
                    .frame(height: weekdayRowHeight)

                    // 第 1～6 行：日期
                    ForEach(0..<6, id: \.self) { rowIndex in
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
                        containerWidth: containerWidth,
                        gridHeight: gridHeight
                    )
                )
                .frame(height: gridHeight)
            }
            .frame(maxHeight: .infinity)

            // 选中日期信息条
            selectedDateInfoBar(for: grid)

            // 广告 banner 占位
            AdBannerPlaceholderView()
        }
        .background(ShiftCalendarColors.backgroundColor)
    }

    /// 网格线 overlay - 使用 Path 精确绘制连续网格线
    @ViewBuilder
    private func gridLinesOverlay(cellWidth: CGFloat, dateCellHeight: CGFloat, containerWidth: CGFloat, gridHeight: CGFloat) -> some View {
        let lineWidth = ShiftCalendarLayout.gridLineWidth
        let weekdayRowHeight: CGFloat = ShiftCalendarLayout.weekdayRowHeight

        // 横线位置（不等高行）：
        // 第 0 条：0（顶部）
        // 第 1～6 条：weekdayRowHeight + dateCellHeight * 1～6（日期行底部）
        // 共 7 条横线（星期行底部不绘制，避免与 WeekdayHeaderView 背景重叠）
        let horizontalLines: [CGFloat] = [0] + (1...6).map { weekdayRowHeight + dateCellHeight * CGFloat($0) }

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

    @ViewBuilder
    private func selectedDateInfoBar(for grid: MonthGrid) -> some View {
        if let selectedCell = viewModel.selectedDayCell {
            SelectedDateInfoBarView(
                cell: selectedCell,
                onDetailTapped: {
                    viewModel.showingDayDetail = true
                }
            )
        } else {
            // 默认显示今天
            if let todayCell = grid.days.first(where: { $0.isToday }) {
                SelectedDateInfoBarView(
                    cell: todayCell,
                    onDetailTapped: {
                        viewModel.showingDayDetail = true
                    }
                )
            }
        }
    }
}

// MARK: - DayCellView

struct DayCellView: View {
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

                // 弹性空间 - 将底部标签推到底部
                Spacer()

                // 底部区域：节假日标签或排班标签
                // 节假日标签 - 底部居中，优先于排班标签显示
                if !cell.holidays.isEmpty {
                    holidayLabelsView
                } else if let shiftType = cell.shiftType {
                    // 排班标签 - 底部居中，圆角矩形样式
                    Text(shiftType)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(shiftType.shiftLabelColor)
                        .padding(.horizontal, ShiftCalendarLayout.shiftLabelHorizontalPadding)
                        .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: cellWidth, height: cellHeight)
        .opacity(cell.isInCurrentMonth ? 1.0 : 0.5)
    }

    private var cellBackgroundColor: Color {
        if cell.isToday {
            return Color(red: 0.96, green: 0.98, blue: 1.0)
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
        if cell.isWeekend {
            // Sunday = red, Saturday = blue
            // 根据 weekdayText 判断是周日还是周六（跨语言）
            // 使用 cell.isWeekend 已经正确标识周末
            // 需要进一步区分周日和周六
            if isSunday(weekdayText: cell.weekdayText) {
                return ShiftCalendarColors.sundayRed
            }
            if isSaturday(weekdayText: cell.weekdayText) {
                return ShiftCalendarColors.saturdayBlue
            }
        }
        return ShiftCalendarColors.primaryText
    }

    /// 判断是否为周日（支持多语言）
    private func isSunday(weekdayText: String) -> Bool {
        ["日", "Sun", "Sunday", "일", "dom"].contains(weekdayText)
    }

    /// 判断是否为周六（支持多语言）
    private func isSaturday(weekdayText: String) -> Bool {
        ["土", "Sat", "Saturday", "토", "sab"].contains(weekdayText)
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
    
    /// 获取节假日显示名称数组（按 UI 语言）
    private var holidayDisplayNames: [String] {
        let currentLanguage = LocalizationManager.shared.currentLanguage
        return cell.holidays.map { holiday in
            holiday.localizedNames.localized(for: currentLanguage)
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
