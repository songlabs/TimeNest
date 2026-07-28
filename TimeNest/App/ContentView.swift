import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var localization: LocalizationManager
    private let calendarDisplayUseCase: CalendarDisplayUseCase
    private let eventUseCase: EventUseCase
    private let holidaySubscriptionManager: HolidaySubscriptionManager
    private let calendarSharingStore: CalendarSharingStore

    init(
        calendarDisplayUseCase: CalendarDisplayUseCase,
        eventUseCase: EventUseCase,
        holidaySubscriptionManager: HolidaySubscriptionManager,
        calendarSharingStore: CalendarSharingStore
    ) {
        self.calendarDisplayUseCase = calendarDisplayUseCase
        self.eventUseCase = eventUseCase
        self.holidaySubscriptionManager = holidaySubscriptionManager
        self.calendarSharingStore = calendarSharingStore
    }

    var body: some View {
        MonthCalendarView(
            calendarDisplayUseCase: calendarDisplayUseCase,
            eventUseCase: eventUseCase,
            holidaySubscriptionManager: holidaySubscriptionManager,
            calendarSharingStore: calendarSharingStore
        )
        .environmentObject(localization)
        .environmentObject(calendarSharingStore)
        .onOpenURL { url in
            guard let date = TimeNestWidgetDeepLink.date(from: url) else { return }
            NotificationCenter.default.post(name: .widgetCalendarDateRequested, object: date)
        }
    }
}

#if DEBUG
enum AppStoreScreenshotScene: String, CaseIterable {
    case monthView = "month_view"
    case weekView = "week_view"
    case dayView = "day_view"
    case holidayView = "holiday_view"
    case dayDetail = "day_detail"
    case eventEditor = "event_editor"
    case workRecord = "work_record"
    case shiftRecord = "shift_record"
    case help = "help"
    case settings = "settings"
    case removeAds = "remove_ads"
    case sharedManageEntry = "shared_manage_entry"
    case sharedContent = "shared_content"
    case sharedMonth = "shared_month"
    case sharedReadOnly = "shared_read_only"
    case sharedSwitcher = "shared_switcher"
}

enum AppStoreScreenshotMode {
    private static let sceneArgument = "--timenest-screenshot-scene"

    static var requestedScene: AppStoreScreenshotScene? {
        let arguments = ProcessInfo.processInfo.arguments

        if let index = arguments.firstIndex(of: sceneArgument),
           arguments.indices.contains(index + 1) {
            return AppStoreScreenshotScene(rawValue: arguments[index + 1])
        }

        let prefix = "\(sceneArgument)="
        if let argument = arguments.first(where: { $0.hasPrefix(prefix) }) {
            return AppStoreScreenshotScene(rawValue: String(argument.dropFirst(prefix.count)))
        }

        return nil
    }

    static func configureEnvironment() {
        let defaults = UserDefaults.standard
        defaults.set("ja", forKey: "preferredLanguageCode")
        defaults.set("light", forKey: "themeMode")
        defaults.set("sunday", forKey: "weekStart")
        configureShiftTemplates(in: defaults)
        LocalizationManager.shared.setLanguage(.ja)
    }

    private static func configureShiftTemplates(in defaults: UserDefaults) {
        let earlyShiftID = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!
        let prefix = "shiftTime.custom.\(earlyShiftID.uuidString)"
        defaults.set(earlyShiftID.uuidString, forKey: "\(prefix).id")
        defaults.set("早番", forKey: "\(prefix).displayName")
        defaults.set("#B8E3F5", forKey: "\(prefix).colorHex")
        defaults.set("07:00", forKey: "\(prefix).start")
        defaults.set("15:00", forKey: "\(prefix).end")
        defaults.set(true, forKey: "\(prefix).enabled")
    }
}

struct AppStoreScreenshotRootView: View {
    @EnvironmentObject private var localization: LocalizationManager

    let scene: AppStoreScreenshotScene

    init(scene: AppStoreScreenshotScene) {
        AppStoreScreenshotMode.configureEnvironment()
        self.scene = scene
    }

    var body: some View {
        Group {
            switch scene {
            case .monthView:
                AppStoreScreenshotCalendarSceneView(mode: .month)
            case .weekView:
                AppStoreScreenshotCalendarSceneView(mode: .week)
            case .dayView:
                AppStoreScreenshotCalendarSceneView(mode: .day)
            case .holidayView:
                AppStoreScreenshotCalendarSceneView(
                    mode: .month,
                    selectedDate: AppStoreScreenshotSampleData.date(
                        year: 2026,
                        month: 7,
                        day: 20,
                        hour: 9,
                        minute: 0
                    )
                )
            case .dayDetail:
                AppStoreScreenshotDayDetailView()
            case .eventEditor:
                AppStoreScreenshotEventEditorView()
            case .workRecord:
                AppStoreScreenshotWorkRecordEditorView()
            case .shiftRecord:
                NavigationStack {
                    ShiftTimeSettingsView()
                }
            case .help:
                HelpView()
                    .environmentObject(localization)
            case .settings:
                AppStoreScreenshotSettingsOverviewView()
            case .removeAds:
                AppStoreScreenshotRemoveAdsView()
            case .sharedManageEntry:
                AppStoreScreenshotSharedCalendarSelectionView(selection: .mine)
            case .sharedContent:
                AppStoreScreenshotSharedCalendarManagementView()
            case .sharedMonth:
                AppStoreScreenshotSharedMonthView()
            case .sharedReadOnly:
                AppStoreScreenshotSharedReadOnlyDetailView()
            case .sharedSwitcher:
                AppStoreScreenshotSharedCalendarSelectionView(
                    selection: .calendar(AppStoreScreenshotSharedCalendarData.calendarID)
                )
            }
        }
        .environment(\.locale, Locale(identifier: "ja_JP"))
        .environment(\.calendar, AppStoreScreenshotSampleData.calendar)
        .environment(\.localization, localization)
        .tint(ShiftCalendarColors.primaryBlue)
    }
}

private struct AppStoreScreenshotCalendarSceneView: View {
    @EnvironmentObject private var localization: LocalizationManager

    let mode: CalendarViewMode
    let selectedDate: Date

    init(
        mode: CalendarViewMode,
        selectedDate: Date = AppStoreScreenshotSampleData.selectedDate
    ) {
        self.mode = mode
        self.selectedDate = selectedDate
    }

    var body: some View {
        VStack(spacing: 0) {
            CalendarHeaderView(
                title: title,
                displayMode: mode,
                onStatisticsTapped: {},
                onShiftInputTapped: {},
                onPrevious: {},
                onNext: {},
                onTitleTapped: {},
                onSettingsTapped: {}
            )
            .environmentObject(localization)

            calendarContent

            CalendarBottomToolbarView(
                selectedViewMode: .constant(mode),
                onTodayTapped: {},
                onAddEventTapped: {},
                onModeChanged: nil
            )
            .environmentObject(localization)
            .frame(height: ShiftCalendarLayout.footerToolbarHeight)
        }
        .background(ShiftCalendarColors.backgroundColor.ignoresSafeArea())
    }

    private var title: String {
        switch mode {
        case .month, .week:
            return LocalizationManager.shared.monthTitle(for: selectedDate)
        case .day:
            return LocalizationManager.shared.dayTitle(for: selectedDate)
        }
    }

    @ViewBuilder
    private var calendarContent: some View {
        switch mode {
        case .month:
            AppStoreScreenshotMonthGridView(
                cells: AppStoreScreenshotSampleData.monthCells(),
                selectedDate: DateOnly(from: selectedDate) ?? AppStoreScreenshotSampleData.selectedDateOnly
            )
        case .week:
            WeekCalendarView(
                selectedDate: AppStoreScreenshotSampleData.selectedDate,
                cells: AppStoreScreenshotSampleData.weekCells(),
                onDateSelected: { _ in }
            )
        case .day:
            DayCalendarView(
                selectedDate: AppStoreScreenshotSampleData.selectedDate,
                cell: AppStoreScreenshotSampleData.dayCell()
            )
        }
    }
}

private struct AppStoreScreenshotShiftSceneView: View {
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        VStack(spacing: 0) {
            CalendarHeaderView(
                title: LocalizationManager.shared.monthTitle(for: AppStoreScreenshotSampleData.selectedDate),
                displayMode: .month,
                onStatisticsTapped: {},
                onShiftInputTapped: {},
                onPrevious: {},
                onNext: {},
                onTitleTapped: {},
                onSettingsTapped: {}
            )
            .environmentObject(localization)

            AppStoreScreenshotMonthGridView(
                cells: AppStoreScreenshotSampleData.monthCells(),
                selectedDate: DateOnly(year: 2026, month: 7, day: 9)
            )

            AppStoreScreenshotShiftInputPanel()
        }
        .background(ShiftCalendarColors.backgroundColor.ignoresSafeArea())
    }
}

private struct AppStoreScreenshotMonthGridView: View {
    @EnvironmentObject private var localization: LocalizationManager

    let cells: [CalendarDayCell]
    let selectedDate: DateOnly

    var body: some View {
        GeometryReader { geometry in
            let weekdayRowHeight: CGFloat = ShiftCalendarLayout.weekdayRowHeight
            let dateRowCount = max(1, cells.count / 7)
            let availableDateHeight = CalendarTimelineLayout.nonNegativeDimension(geometry.size.height - weekdayRowHeight)
            let containerWidth = CalendarTimelineLayout.nonNegativeDimension(geometry.size.width)
            let dateCellHeight = max(ShiftCalendarLayout.dayCellMinHeight, availableDateHeight / CGFloat(dateRowCount))
            let cellWidth = containerWidth / 7.0
            let gridHeight = weekdayRowHeight + dateCellHeight * CGFloat(dateRowCount)

            VStack(spacing: 0) {
                WeekdayHeaderView(
                    weekdaySymbols: LocalizationManager.shared.shortWeekdaySymbols(weekStartPolicy: .sunday),
                    cellWidth: cellWidth
                )
                .frame(height: weekdayRowHeight)

                ForEach(0..<dateRowCount, id: \.self) { rowIndex in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(0..<7, id: \.self) { columnIndex in
                            let dayIndex = rowIndex * 7 + columnIndex
                            if dayIndex < cells.count {
                                let cell = cells[dayIndex]
                                DayCellView(
                                    cell: cell,
                                    cellWidth: cellWidth,
                                    cellHeight: dateCellHeight,
                                    isSelected: cell.date == selectedDate
                                )
                                .environmentObject(localization)
                            }
                        }
                    }
                    .frame(width: containerWidth, height: dateCellHeight)
                }
            }
            .overlay(
                AppStoreScreenshotGridLines(
                    cellWidth: cellWidth,
                    dateCellHeight: dateCellHeight,
                    dateRowCount: dateRowCount,
                    containerWidth: containerWidth,
                    gridHeight: gridHeight
                )
            )
            .frame(height: gridHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ShiftCalendarColors.backgroundColor)
    }
}

private struct AppStoreScreenshotGridLines: View {
    let cellWidth: CGFloat
    let dateCellHeight: CGFloat
    let dateRowCount: Int
    let containerWidth: CGFloat
    let gridHeight: CGFloat

    var body: some View {
        let weekdayRowHeight: CGFloat = ShiftCalendarLayout.weekdayRowHeight
        let horizontalLines: [CGFloat] = [0] + (1...dateRowCount).map {
            weekdayRowHeight + dateCellHeight * CGFloat($0)
        }
        let verticalLines: [CGFloat] = (0...7).map { CGFloat($0) * cellWidth }

        Path { path in
            for y in horizontalLines {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: containerWidth, y: y))
            }
            for x in verticalLines {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: gridHeight))
            }
        }
        .stroke(ShiftCalendarColors.gridLineColor, lineWidth: ShiftCalendarLayout.gridLineWidth)
    }
}

private struct AppStoreScreenshotShiftInputPanel: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(LocalizationManager.shared.localized(.shiftInputTitle))
                    .font(TimeNestTheme.Fonts.popupTitle)
                    .foregroundColor(ShiftCalendarColors.primaryText)
                Spacer()
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ShiftCalendarColors.secondaryText)
                    .frame(width: SettingsModalSurface.closeButtonSize, height: SettingsModalSurface.closeButtonSize)
                    .background(Color(.tertiarySystemGroupedBackground), in: Circle())
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                shiftButton("キャンセル", foreground: ShiftCalendarColors.sundayRed, background: ShiftCalendarColors.sundayRed.opacity(0.12))
                shiftButton(LocalizationManager.shared.localized(.shiftDay), foreground: ShiftCalendarColors.primaryText, background: ShiftTimeTemplateID.day.displayBackgroundColor)
                shiftButton(LocalizationManager.shared.localized(.shiftNight), foreground: ShiftCalendarColors.primaryText, background: ShiftTimeTemplateID.night.displayBackgroundColor)
                shiftButton("早番", foreground: ShiftCalendarColors.primaryText, background: ShiftCalendarColors.primaryBlue.opacity(0.14))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(ShiftCalendarColors.backgroundColor)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ShiftCalendarColors.separatorColor)
                .frame(height: ShiftCalendarLayout.gridLineWidth)
        }
    }

    private func shiftButton(_ title: String, foreground: Color, background: Color) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundColor(foreground)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(WorkStatisticsColors.border, lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct AppStoreScreenshotDayDetailView: View {
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        DayDetailView(
            cell: AppStoreScreenshotSampleData.dayCell(),
            onDeleteEvent: { _ in },
            onDeleteWorkRecord: { _ in },
            onCreateEvent: { _, _, _, _, _, _, _, _, _ in .noReminder },
            onUpdateEvent: { _, _, _, _, _, _, _, _, _, _ in .noReminder },
            onSaveWorkRecordPair: { _ in }
        )
        .environmentObject(localization)
    }
}

private struct AppStoreScreenshotEventEditorView: View {
    @State private var isPresented = true

    var body: some View {
        EventEditorView(
            isPresented: $isPresented,
            mode: .edit(
                eventID: AppStoreScreenshotSampleData.teamMeetingID,
                initialTitle: "チームMTG",
                initialNote: "週次の予定確認とメモ",
                initialStartDate: AppStoreScreenshotSampleData.date(year: 2026, month: 7, day: 7, hour: 10, minute: 0),
                initialEndDate: AppStoreScreenshotSampleData.date(year: 2026, month: 7, day: 7, hour: 11, minute: 0),
                initialIsAllDay: false,
                initialReminderOffsetMinutes: 10
            ),
            existingEvents: AppStoreScreenshotSampleData.dayCell().events,
            onSave: { _, _, _, _, _, _, _, _, _ in .noReminder }
        )
    }
}

private struct AppStoreScreenshotWorkRecordEditorView: View {
    @State private var isPresented = true

    var body: some View {
        WorkRecordEditorView(
            isPresented: $isPresented,
            mode: .edit(AppStoreScreenshotSampleData.workRecordInitialSession),
            existingEvents: AppStoreScreenshotSampleData.dayCell().events,
            onSavePair: { _ in }
        )
    }
}

private struct AppStoreScreenshotSettingsOverviewView: View {
    var body: some View {
        VStack(spacing: 0) {
            AppStoreScreenshotSimpleHeader(title: LocalizationManager.shared.localized(.settingsTitle))

            ScrollView {
                VStack(spacing: 14) {
                    settingsCard {
                        settingsRow(icon: "globe", title: LocalizationManager.shared.localized(.settingsLanguage), value: LocalizationManager.shared.localized(.languageJapanese))
                        divider
                        settingsRow(icon: "sun.max", title: LocalizationManager.shared.localized(.settingsTheme), value: LocalizationManager.shared.localized(.themeLight))
                        divider
                        settingsRow(icon: "calendar", title: LocalizationManager.shared.localized(.settingsWeekStart), value: LocalizationManager.shared.localized(.weekStartSunday))
                    }

                    settingsCard {
                        settingsRow(icon: "flag", title: LocalizationManager.shared.localized(.settingsHolidayRegion), value: LocalizationManager.shared.localized(.regionJapan))
                        divider
                        settingsRow(icon: "calendar.badge.plus", title: LocalizationManager.shared.localized(.shiftTimeSettingsTitle), value: "日勤 / 夜勤")
                    }

                    settingsCard {
                        settingsRow(icon: "rectangle.slash", title: LocalizationManager.shared.localized(.adsRemove), value: "")
                        divider
                        settingsRow(icon: "arrow.clockwise", title: LocalizationManager.shared.localized(.adsRestorePurchases), value: "")
                    }

                    settingsCard {
                        settingsRow(icon: "questionmark.circle", title: LocalizationManager.shared.localized(.helpTitle), value: "")
                        divider
                        settingsRow(icon: "hand.raised", title: LocalizationManager.shared.localized(.aboutPrivacy), value: "")
                        divider
                        settingsRow(icon: "info.circle", title: LocalizationManager.shared.localized(.aboutVersion), value: "1.1 (3)")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0, content: content)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func settingsRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ShiftCalendarColors.primaryBlue)
                .frame(width: 30, height: 30)
                .background(ShiftCalendarColors.primaryBlue.opacity(0.12), in: Circle())

            Text(title)
                .font(.body)
                .foregroundColor(.primary)

            Spacer(minLength: 10)

            if !value.isEmpty {
                Text(value)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 54)
    }

    private var divider: some View {
        Divider()
            .padding(.leading, 56)
    }
}

private struct AppStoreScreenshotRemoveAdsView: View {
    var body: some View {
        VStack(spacing: 0) {
            AppStoreScreenshotSimpleHeader(title: LocalizationManager.shared.localized(.helpCategoryAds))

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(LocalizationManager.shared.localized(.adsRemove), systemImage: "rectangle.slash")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.primary)

                        Text(LocalizationManager.shared.localized(.helpAdsAboutAnswer))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(spacing: 12) {
                        screenshotActionButton(
                            title: LocalizationManager.shared.localized(.adsRemove),
                            systemImage: "cart"
                        )

                        screenshotSecondaryButton(
                            title: LocalizationManager.shared.localized(.adsRestorePurchases),
                            systemImage: "arrow.clockwise"
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizationManager.shared.localized(.helpCategoryPrivacy))
                            .font(.headline)
                        Text(LocalizationManager.shared.localized(.helpPrivacyOptionsDescription))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(16)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func screenshotActionButton(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(ShiftCalendarColors.primaryBlue)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func screenshotSecondaryButton(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundColor(ShiftCalendarColors.primaryBlue)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(ShiftCalendarColors.primaryBlue.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct AppStoreScreenshotSimpleHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(TimeNestTheme.Fonts.popupTitle)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: SettingsModalSurface.closeButtonSize, height: SettingsModalSurface.closeButtonSize)
                .background(Color(.tertiarySystemGroupedBackground), in: Circle())
        }
        .padding(.horizontal, SettingsModalSurface.horizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color(.systemGroupedBackground))
    }
}

private enum AppStoreScreenshotSampleData {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }

    static let selectedDate = date(year: 2026, month: 7, day: 7, hour: 9, minute: 0)
    static let selectedDateOnly = DateOnly(year: 2026, month: 7, day: 7)
    static let teamMeetingID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static let workSessionID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private static let clockInID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    private static let clockOutID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

    static var workRecordInitialSession: WorkRecordEditorInitialSession {
        WorkRecordEditorInitialSession(
            clockInEventID: clockInID,
            clockOutEventID: clockOutID,
            title: "カフェ勤務",
            workDate: date(year: 2026, month: 7, day: 7),
            workInTime: date(year: 2026, month: 7, day: 7, hour: 9, minute: 0),
            workOutTime: date(year: 2026, month: 7, day: 7, hour: 18, minute: 0),
            restHours: 1.0,
            transportFee: 500,
            hourlyRate: 1200,
            workSessionId: workSessionID,
            isWorkOutTimeSet: true,
            calendarID: TimeNestCalendar.personalID
        )
    }

    static func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date ?? Date()
    }

    static func monthCells() -> [CalendarDayCell] {
        let year = 2026
        let month = 7
        let firstDay = date(year: year, month: month, day: 1)
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstDay)?.count ?? 31
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let weekStartOffset = (firstWeekday - 1 + 7) % 7
        let totalCells = Int(ceil(Double(weekStartOffset + daysInMonth) / 7.0)) * 7
        let gridStartDate = calendar.date(byAdding: .day, value: -weekStartOffset, to: firstDay) ?? firstDay

        return (0..<totalCells).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStartDate) else {
                return nil
            }
            return cell(for: date, currentMonth: month)
        }
    }

    static func weekCells() -> [CalendarDayCell] {
        let weekday = calendar.component(.weekday, from: selectedDate)
        let weekStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: selectedDate) ?? selectedDate
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }
            return cell(for: date, currentMonth: 7)
        }
    }

    static func dayCell() -> CalendarDayCell {
        cell(for: selectedDate, currentMonth: 7)
    }

    private static func cell(for date: Date, currentMonth: Int) -> CalendarDayCell {
        let dateOnly = DateOnly(from: date) ?? selectedDateOnly
        let weekdayIndex = (calendar.component(.weekday, from: date) - 1 + 7) % 7
        let weekdayText = LocalizationManager.shared.shortWeekdaySymbol(for: date, language: .ja)
        let dayStart = calendar.startOfDay(for: date)

        return CalendarDayCell(
            id: dateOnly.id,
            date: dateOnly,
            dayText: "\(dateOnly.day)",
            weekdayText: weekdayText,
            holidays: holidays(on: dateOnly),
            events: occurrences(on: dayStart),
            isToday: dateOnly == DateOnly(year: 2026, month: 7, day: 6),
            isWeekend: weekdayIndex == 0 || weekdayIndex == 6,
            isInCurrentMonth: dateOnly.month == currentMonth,
            shiftType: nil,
            eventMarkers: []
        )
    }

    private static func holidays(on date: DateOnly) -> [Holiday] {
        guard date == DateOnly(year: 2026, month: 7, day: 20) else {
            return []
        }

        return [
            Holiday(
                id: "jp-marine-2026",
                region: .japan,
                date: date,
                localizedNames: LocalizedText(region: .japan, displayName: "海の日"),
                type: .publicHoliday,
                isObserved: true
            )
        ]
    }

    private static func occurrences(on day: Date) -> [EventOccurrence] {
        sampleEvents.compactMap { event in
            occurrence(from: event, on: day)
        }
        .sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay {
                return lhs.isAllDay && !rhs.isAllDay
            }
            return lhs.startDate < rhs.startDate
        }
    }

    private static func occurrence(from event: CalendarEvent, on day: Date) -> EventOccurrence? {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let dateOnly = DateOnly(from: dayStart) ?? selectedDateOnly

        if event.workClockKind != nil {
            guard calendar.isDate(event.workDate, inSameDayAs: dayStart) else {
                return nil
            }
        } else if event.shiftTemplateID != nil {
            guard calendar.isDate(event.startDate, inSameDayAs: dayStart) else {
                return nil
            }
        } else {
            guard event.startDate < dayEnd, event.endDate > dayStart else {
                return nil
            }
        }

        return EventOccurrence(
            id: "\(event.id)-\(dateOnly.id)",
            eventID: event.id,
            occurrenceDate: dateOnly,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            title: event.title,
            note: event.note,
            categoryID: event.categoryID,
            reminderOffsetMinutes: event.reminderOffsetMinutes,
            notificationID: event.notificationID,
            shiftTemplateID: event.shiftTemplateID,
            workInfo: event.workInfo
        )
    }

    private static var sampleEvents: [CalendarEvent] {
        [
            event(
                id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                title: "予定",
                note: "月初の確認",
                start: date(year: 2026, month: 7, day: 3, hour: 13, minute: 0),
                end: date(year: 2026, month: 7, day: 3, hour: 14, minute: 0)
            ),
            shift(
                id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
                title: LocalizationManager.shared.localized(.shiftDay),
                start: date(year: 2026, month: 7, day: 6, hour: 9, minute: 0),
                end: date(year: 2026, month: 7, day: 6, hour: 17, minute: 0),
                templateID: .day
            ),
            event(
                id: teamMeetingID,
                title: "チームMTG",
                note: "週次の予定確認とメモ",
                start: date(year: 2026, month: 7, day: 7, hour: 10, minute: 0),
                end: date(year: 2026, month: 7, day: 7, hour: 11, minute: 0),
                reminderOffsetMinutes: 10
            ),
            event(
                id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
                title: "買い物",
                note: "帰宅前に買い物",
                start: date(year: 2026, month: 7, day: 7, hour: 14, minute: 30),
                end: date(year: 2026, month: 7, day: 7, hour: 15, minute: 30)
            ),
            event(
                id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
                title: "メモ",
                note: "簡単なメモ文",
                start: date(year: 2026, month: 7, day: 7),
                end: date(year: 2026, month: 7, day: 8),
                isAllDay: true
            ),
            workClock(
                id: clockInID,
                title: "カフェ勤務",
                clockDate: date(year: 2026, month: 7, day: 7, hour: 9, minute: 0),
                workDate: date(year: 2026, month: 7, day: 7),
                isClockIn: true
            ),
            workClock(
                id: clockOutID,
                title: "カフェ勤務",
                clockDate: date(year: 2026, month: 7, day: 7, hour: 18, minute: 0),
                workDate: date(year: 2026, month: 7, day: 7),
                isClockIn: false
            ),
            event(
                id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
                title: "通院",
                note: nil,
                start: date(year: 2026, month: 7, day: 8, hour: 16, minute: 0),
                end: date(year: 2026, month: 7, day: 8, hour: 17, minute: 0)
            ),
            shift(
                id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                title: LocalizationManager.shared.localized(.shiftNight),
                start: date(year: 2026, month: 7, day: 9, hour: 22, minute: 0),
                end: date(year: 2026, month: 7, day: 10, hour: 6, minute: 0),
                templateID: .night
            ),
            event(
                id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                title: "シフト確認",
                note: nil,
                start: date(year: 2026, month: 7, day: 10, hour: 12, minute: 0),
                end: date(year: 2026, month: 7, day: 10, hour: 12, minute: 30)
            ),
            event(
                id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
                title: "勤務記録",
                note: nil,
                start: date(year: 2026, month: 7, day: 15, hour: 9, minute: 30),
                end: date(year: 2026, month: 7, day: 15, hour: 10, minute: 0)
            )
        ]
    }

    private static func event(
        id: UUID,
        title: String,
        note: String?,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        reminderOffsetMinutes: Int? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            note: note,
            startDate: start,
            endDate: end,
            isAllDay: isAllDay,
            categoryID: nil,
            recurrenceRule: .none,
            reminderTemplateID: nil,
            reminderOffsetMinutes: reminderOffsetMinutes,
            notificationID: nil,
            importSource: nil,
            createdAt: start,
            updatedAt: start
        )
    }

    private static func shift(id: UUID, title: String, start: Date, end: Date, templateID: ShiftTimeTemplateID) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            note: nil,
            startDate: start,
            endDate: end,
            isAllDay: false,
            categoryID: nil,
            recurrenceRule: .none,
            reminderTemplateID: nil,
            reminderOffsetMinutes: nil,
            notificationID: nil,
            importSource: nil,
            createdAt: start,
            updatedAt: start,
            shiftTemplateID: templateID
        )
    }

    private static func workClock(id: UUID, title: String, clockDate: Date, workDate: Date, isClockIn: Bool) -> CalendarEvent {
        let workInfo = WorkInfo(
            workInTime: isClockIn ? clockDate : nil,
            workOutTime: isClockIn ? nil : clockDate,
            restHours: 1.0,
            workDate: workDate,
            transportFee: 500,
            hourlyRate: 1200,
            workSessionId: workSessionID,
            isWorkOutTimeSet: !isClockIn
        )

        return CalendarEvent(
            id: id,
            title: title,
            note: nil,
            startDate: clockDate,
            endDate: CalendarEvent.defaultEndDate(for: clockDate, isAllDay: false),
            isAllDay: false,
            categoryID: nil,
            recurrenceRule: .none,
            reminderTemplateID: nil,
            reminderOffsetMinutes: nil,
            notificationID: nil,
            importSource: nil,
            createdAt: clockDate,
            updatedAt: clockDate,
            workInfo: workInfo
        )
    }
}
#endif
