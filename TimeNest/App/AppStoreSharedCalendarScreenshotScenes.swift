#if DEBUG
import SwiftUI

@MainActor
struct AppStoreScreenshotSharedCalendarSelectionView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @StateObject private var sharingStore: CalendarSharingStore

    init(selection: CalendarSelection) {
        _sharingStore = StateObject(
            wrappedValue: AppStoreScreenshotSharedCalendarData.makeStore(selection: selection)
        )
    }

    var body: some View {
        CalendarSelectionView()
            .environmentObject(sharingStore)
            .environmentObject(localization)
    }
}

@MainActor
struct AppStoreScreenshotSharedCalendarManagementView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @StateObject private var sharingStore: CalendarSharingStore

    init() {
        _sharingStore = StateObject(
            wrappedValue: AppStoreScreenshotSharedCalendarData.makeStore(selection: .mine)
        )
    }

    var body: some View {
        NavigationStack {
            CalendarSharingManagementView()
                .environmentObject(sharingStore)
                .environmentObject(localization)
        }
    }
}

struct AppStoreScreenshotSharedMonthView: View {
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        VStack(spacing: 0) {
            CalendarHeaderView(
                title: LocalizationManager.shared.monthTitle(
                    for: AppStoreScreenshotSharedCalendarData.selectedDate
                ),
                displayMode: .month,
                calendarAvatarInitial: "共",
                calendarDisplayName: AppStoreScreenshotSharedCalendarData.calendarName,
                isReadOnlyCalendar: true,
                onCalendarTapped: {},
                onStatisticsTapped: {},
                onShiftInputTapped: {},
                onPrevious: {},
                onNext: {},
                onTitleTapped: {},
                onSettingsTapped: {}
            )
            .environmentObject(localization)

            Text(AppStoreScreenshotSharedCalendarData.statusText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(ShiftCalendarColors.primaryBlue.opacity(0.06))

            AppStoreScreenshotSharedMonthGridView(
                cells: AppStoreScreenshotSharedCalendarData.monthCells,
                selectedDate: AppStoreScreenshotSharedCalendarData.selectedDateOnly
            )

            CalendarBottomToolbarView(
                selectedViewMode: .constant(.month),
                onTodayTapped: {},
                onAddEventTapped: {},
                onModeChanged: nil,
                showsAddButton: false
            )
            .environmentObject(localization)
            .frame(height: ShiftCalendarLayout.footerToolbarHeight)
        }
        .background(ShiftCalendarColors.backgroundColor.ignoresSafeArea())
    }
}

struct AppStoreScreenshotSharedReadOnlyDetailView: View {
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        ReadOnlySharedCalendarDetailView(
            detail: ReadOnlyCalendarDetail(
                date: AppStoreScreenshotSharedCalendarData.detailDate,
                events: AppStoreScreenshotSharedCalendarData.detailEvents
            )
        )
        .environmentObject(localization)
    }
}

private struct AppStoreScreenshotSharedMonthGridView: View {
    @EnvironmentObject private var localization: LocalizationManager

    let cells: [CalendarDayCell]
    let selectedDate: DateOnly

    var body: some View {
        GeometryReader { geometry in
            let weekdayRowHeight = ShiftCalendarLayout.weekdayRowHeight
            let dateRowCount = max(1, cells.count / 7)
            let availableDateHeight = CalendarTimelineLayout.nonNegativeDimension(
                geometry.size.height - weekdayRowHeight
            )
            let containerWidth = CalendarTimelineLayout.nonNegativeDimension(geometry.size.width)
            let dateCellHeight = max(
                ShiftCalendarLayout.dayCellMinHeight,
                availableDateHeight / CGFloat(dateRowCount)
            )
            let cellWidth = containerWidth / 7
            let gridHeight = weekdayRowHeight + dateCellHeight * CGFloat(dateRowCount)

            VStack(spacing: 0) {
                WeekdayHeaderView(
                    weekdaySymbols: LocalizationManager.shared.shortWeekdaySymbols(
                        weekStartPolicy: .sunday
                    ),
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
            .overlay {
                AppStoreScreenshotSharedGridLines(
                    cellWidth: cellWidth,
                    dateCellHeight: dateCellHeight,
                    dateRowCount: dateRowCount,
                    containerWidth: containerWidth,
                    gridHeight: gridHeight
                )
            }
            .frame(height: gridHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ShiftCalendarColors.backgroundColor)
    }
}

private struct AppStoreScreenshotSharedGridLines: View {
    let cellWidth: CGFloat
    let dateCellHeight: CGFloat
    let dateRowCount: Int
    let containerWidth: CGFloat
    let gridHeight: CGFloat

    var body: some View {
        let weekdayRowHeight = ShiftCalendarLayout.weekdayRowHeight
        let horizontalLines = [CGFloat(0)] + (1...dateRowCount).map {
            weekdayRowHeight + dateCellHeight * CGFloat($0)
        }
        let verticalLines = (0...7).map { CGFloat($0) * cellWidth }

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

@MainActor
enum AppStoreScreenshotSharedCalendarData {
    static let calendarID = "screenshot-shared-calendar"
    static let calendarName = "家族の予定"
    static let ownerDisplayName = "共有メンバー"
    static let selectedDateOnly = DateOnly(year: 2026, month: 7, day: 14)
    static let selectedDate = date(day: selectedDateOnly.day, hour: 9)
    static let detailDate = date(day: 14)

    static var statusText: String {
        String(
            format: LocalizationManager.shared.localized(.calendarSharingStatusFormat),
            locale: LocalizationManager.shared.currentLocale,
            ownerDisplayName
        )
    }

    static var detailEvents: [EventOccurrence] {
        let range = DateInterval(start: detailDate, end: date(day: 15))
        return sharedOccurrences.filter { range.contains($0.startDate) || $0.occurrenceDate == selectedDateOnly }
    }

    static var monthCells: [CalendarDayCell] {
        let firstDay = date(day: 1)
        let dayCount = calendar.range(of: .day, in: .month, for: firstDay)?.count ?? 31
        let offset = (calendar.component(.weekday, from: firstDay) - 1 + 7) % 7
        let totalCells = Int(ceil(Double(offset + dayCount) / 7)) * 7
        let gridStart = calendar.date(byAdding: .day, value: -offset, to: firstDay) ?? firstDay
        let occurrencesByDate = Dictionary(grouping: sharedOccurrences, by: { $0.occurrenceDate })

        return (0..<totalCells).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index, to: gridStart),
                  let dateOnly = DateOnly(from: date) else {
                return nil
            }
            let weekday = calendar.component(.weekday, from: date)
            return CalendarDayCell(
                id: dateOnly.id,
                date: dateOnly,
                dayText: String(dateOnly.day),
                weekdayText: LocalizationManager.shared.shortWeekdaySymbol(
                    for: date,
                    language: .ja
                ),
                holidays: [],
                events: occurrencesByDate[dateOnly] ?? [],
                isToday: dateOnly == DateOnly(year: 2026, month: 7, day: 13),
                isWeekend: weekday == 1 || weekday == 7,
                isInCurrentMonth: dateOnly.month == 7,
                shiftType: nil,
                eventMarkers: []
            )
        }
    }

    static func makeStore(selection: CalendarSelection) -> CalendarSharingStore {
        let sceneKey = selection.sharedCalendarID == nil ? "manage" : "switcher"
        let suiteName = "TimeNest.AppStore.SharedCalendar.\(sceneKey)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        let persistence = CalendarSelectionPersistence(defaults: defaults)
        persistence.save(selection)

        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeNest-AppStore-SharedCalendar-\(sceneKey).json")
        let cache = CalendarSharingCache(fileURL: cacheURL)
        try? cache.save(CalendarSharingCacheData(
            receivedCalendars: [receivedCalendar],
            eventsByCalendarID: [calendarID: eventSnapshots],
            shiftsByCalendarID: [calendarID: shiftSnapshots],
            workRecordsByCalendarID: [:],
            ownedCalendar: OwnedSharedCalendarDescriptor(
                displayName: calendarName,
                calendarName: calendarName,
                participantCount: 2,
                contentConfiguration: .newShareDefault
            )
        ))

        let eventUseCase = EventUseCase(repository: InMemoryEventRepository())
        return CalendarSharingStore(
            client: CloudKitCalendarSharingClient(),
            eventUseCase: eventUseCase,
            cache: cache,
            selectionPersistence: persistence
        )
    }

    private static var receivedCalendar: SharedCalendarDescriptor {
        SharedCalendarDescriptor(
            id: calendarID,
            zoneName: CalendarSharingCloudSchema.zoneName,
            ownerName: "screenshot-owner",
            displayName: ownerDisplayName,
            calendarName: calendarName,
            participantCount: 1,
            contentConfiguration: .newShareDefault
        )
    }

    private static var sharedOccurrences: [EventOccurrence] {
        let range = DateInterval(start: date(day: 1), end: date(month: 8, day: 1))
        return (
            SharedEventMapper.occurrences(from: eventSnapshots, in: range)
            + SharedShiftMapper.occurrences(from: shiftSnapshots, in: range)
        ).sorted { $0.startDate < $1.startDate }
    }

    private static var eventSnapshots: [SharedEventSnapshot] {
        [
            event(id: "11111111-1111-1111-1111-111111111111", title: "学校行事", day: 14, hour: 10),
            event(id: "22222222-2222-2222-2222-222222222222", title: "買い物", day: 18, hour: 15),
            event(id: "33333333-3333-3333-3333-333333333333", title: "会議", day: 22, hour: 19),
            event(id: "44444444-4444-4444-4444-444444444444", title: "家族予定", day: 27, hour: 11)
        ]
    }

    private static var shiftSnapshots: [SharedShiftSnapshot] {
        [
            shift(id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", title: "日勤", day: 14, startHour: 9, endHour: 17, color: "#F2D98A"),
            shift(id: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB", title: "夜勤", day: 20, startHour: 22, endHour: 7, color: "#B7C2E3"),
            shift(id: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC", title: "日勤", day: 24, startHour: 9, endHour: 17, color: "#F2D98A")
        ]
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }

    private static func date(month: Int = 7, day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: month,
            day: day,
            hour: hour
        )) ?? Date()
    }

    private static func event(id: String, title: String, day: Int, hour: Int) -> SharedEventSnapshot {
        let start = date(day: day, hour: hour)
        return SharedEventSnapshot(
            id: UUID(uuidString: id)!,
            title: title,
            startDate: start,
            endDate: start.addingTimeInterval(3_600),
            isAllDay: false,
            updatedAt: start
        )
    }

    private static func shift(
        id: String,
        title: String,
        day: Int,
        startHour: Int,
        endHour: Int,
        color: String
    ) -> SharedShiftSnapshot {
        let start = date(day: day, hour: startHour)
        let crossesMidnight = endHour <= startHour
        let endDay = crossesMidnight ? day + 1 : day
        let end = date(day: endDay, hour: endHour)
        return SharedShiftSnapshot(
            id: UUID(uuidString: id)!,
            registeredDate: date(day: day),
            displayName: title,
            startDate: start,
            endDate: end,
            spansMidnight: crossesMidnight,
            colorHex: color,
            updatedAt: start
        )
    }
}
#endif
