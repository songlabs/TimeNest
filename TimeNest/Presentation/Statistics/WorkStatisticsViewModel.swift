import SwiftUI
import Combine

/// 打工统计数据项
struct StatisticsDataItem: Identifiable, Hashable {
    let id = UUID()
    let date: String
    let time: String
    let amount: String
}

/// 打工统计 View Model
@MainActor
class WorkStatisticsViewModel: ObservableObject {
    // MARK: - Properties
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var showStartDatePicker = false
    @Published var showEndDatePicker = false
    @Published var isLoading = false

    @Published var statisticsData: [StatisticsDataItem] = []
    @Published var totalHours: String = "00:00"
    @Published var totalAmount: String = "¥0"

    private let eventUseCase: EventUseCase?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(eventUseCase: EventUseCase? = nil, startDate: Date? = nil, endDate: Date? = nil) {
        self.eventUseCase = eventUseCase
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart

        self.startDate = calendar.startOfDay(for: startDate ?? monthStart)
        self.endDate = calendar.startOfDay(for: endDate ?? monthEnd)
    }

    // MARK: - Computed Properties
    var formattedStartDate: String {
        formatDate(startDate)
    }

    var formattedEndDate: String {
        formatDate(endDate)
    }

    // MARK: - Public Methods
    /// 计算统计数据
    func calculateStatistics() {
        guard let eventUseCase else {
            loadEmptyStatisticsState()
            return
        }

        isLoading = true
        Task {
            do {
                let events = try await eventUseCase.events(in: statisticsFetchRange())
                applyStatistics(from: events)
            } catch {
                loadEmptyStatisticsState()
            }
            isLoading = false
        }
    }

    /// 设置日期范围
    func setDateRange(start: Date, end: Date) {
        let calendar = Calendar.current
        let normalizedStart = calendar.startOfDay(for: start)
        let normalizedEnd = calendar.startOfDay(for: end)

        if normalizedEnd < normalizedStart {
            self.startDate = normalizedStart
            self.endDate = normalizedStart
        } else {
            self.startDate = normalizedStart
            self.endDate = normalizedEnd
        }

        calculateStatistics()
    }

    /// 设置默认范围（根据视图模式和基准日期）
    /// - Parameters:
    ///   - viewMode: 日历视图模式（月/周/日）
    ///   - anchorDate: 基准日期，用于计算默认范围
    func setDefaultRange(for viewMode: CalendarViewMode, anchorDate: Date) {
        let calendar = Calendar.current

        // 所有视图模式都以 anchorDate 所在月份为默认
        if let range = calendar.dateInterval(of: .month, for: anchorDate),
           let monthEnd = calendar.date(byAdding: .day, value: -1, to: range.end) {
            self.startDate = calendar.startOfDay(for: range.start)
            self.endDate = calendar.startOfDay(for: monthEnd)
        }

        calculateStatistics()
    }

    // MARK: - Private Methods
    private func statisticsRange() -> DateInterval {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let selectedEndDay = calendar.startOfDay(for: endDate)
        let endDay = max(selectedEndDay, start)
        let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        return DateInterval(start: start, end: exclusiveEnd)
    }

    private func statisticsFetchRange() -> DateInterval {
        let range = statisticsRange()
        let calendar = Calendar.current
        let fetchEnd = calendar.date(byAdding: .day, value: 1, to: range.end) ?? range.end
        return DateInterval(start: range.start, end: fetchEnd)
    }

    private struct WorkSessionGroup {
        var clockIn: CalendarEvent?
        var clockOut: CalendarEvent?
    }

    private func applyStatistics(from events: [CalendarEvent]) {
        let calendar = Calendar.current
        var sessions: [UUID: WorkSessionGroup] = [:]
        var legacyClockInsByDay: [Date: [CalendarEvent]] = [:]
        var legacyClockOutsByDay: [Date: [CalendarEvent]] = [:]

        for event in events {
            guard isClockInEvent(event) || isClockOutEvent(event) else { continue }
            let workDay = calendar.startOfDay(for: event.workInfo?.workDate ?? event.startDate)

            if let sessionId = event.workInfo?.workSessionId {
                var group = sessions[sessionId] ?? WorkSessionGroup()
                if isClockInEvent(event) {
                    let time = event.workInfo?.workInTime ?? event.startDate
                    if group.clockIn.map({ time < ($0.workInfo?.workInTime ?? $0.startDate) }) ?? true {
                        group.clockIn = event
                    }
                } else if isClockOutEvent(event) {
                    let time = event.workInfo?.workOutTime ?? event.startDate
                    if group.clockOut.map({ time > ($0.workInfo?.workOutTime ?? $0.startDate) }) ?? true {
                        group.clockOut = event
                    }
                }
                sessions[sessionId] = group
            } else if isClockInEvent(event) {
                legacyClockInsByDay[workDay, default: []].append(event)
            } else if isClockOutEvent(event) {
                legacyClockOutsByDay[workDay, default: []].append(event)
            }
        }

        for group in sessions.values {
            if let clockIn = group.clockIn, group.clockOut == nil {
                let workDay = calendar.startOfDay(for: clockIn.workInfo?.workDate ?? clockIn.startDate)
                legacyClockInsByDay[workDay, default: []].append(clockIn)
            }
            if let clockOut = group.clockOut, group.clockIn == nil {
                let workDay = calendar.startOfDay(for: clockOut.workInfo?.workDate ?? clockOut.startDate)
                legacyClockOutsByDay[workDay, default: []].append(clockOut)
            }
        }

        let legacyGroups = makeLegacySessionGroups(
            clockInsByDay: legacyClockInsByDay,
            clockOutsByDay: legacyClockOutsByDay
        )

        let completeSessions = (Array(sessions.values) + legacyGroups).compactMap { group -> (day: Date, clockIn: CalendarEvent, clockOut: CalendarEvent, inTime: Date, outTime: Date)? in
            guard let clockIn = group.clockIn, let clockOut = group.clockOut else { return nil }
            let inTime = clockIn.workInfo?.workInTime ?? clockIn.startDate
            let outTime = effectiveClockOutTime(for: clockOut, clockInTime: inTime)
            guard outTime > inTime else { return nil }
            let day = calendar.startOfDay(for: clockIn.workInfo?.workDate ?? clockOut.workInfo?.workDate ?? inTime)
            guard statisticsRange().contains(day) else { return nil }
            return (day, clockIn, clockOut, inTime, outTime)
        }.sorted {
            if $0.day != $1.day { return $0.day < $1.day }
            return $0.inTime < $1.inTime
        }

        var totalMinutes = 0
        var totalPay = 0

        statisticsData = completeSessions.map { session in
            let sharedValues = sharedWorkValues(clockIn: session.clockIn, clockOut: session.clockOut)
            let workedSeconds = max(0, session.outTime.timeIntervalSince(session.inTime) - sharedValues.restHours * 3600)
            let minutes = Int(workedSeconds / 60)
            let amount = Int((workedSeconds / 3600) * Double(sharedValues.hourlyRate)) + sharedValues.transportFee

            totalMinutes += minutes
            totalPay += amount

            return StatisticsDataItem(
                date: formatDate(session.day),
                time: formatDuration(minutes: minutes),
                amount: formatCurrency(amount)
            )
        }

        totalHours = formatDuration(minutes: totalMinutes)
        totalAmount = formatCurrency(totalPay)
    }

    private func makeLegacySessionGroups(clockInsByDay: [Date: [CalendarEvent]], clockOutsByDay: [Date: [CalendarEvent]]) -> [WorkSessionGroup] {
        let clockIns = clockInsByDay.values.flatMap { $0 }.sorted { ($0.workInfo?.workInTime ?? $0.startDate) < ($1.workInfo?.workInTime ?? $1.startDate) }
        let clockOuts = clockOutsByDay.values.flatMap { $0 }.sorted { ($0.workInfo?.workOutTime ?? $0.startDate) < ($1.workInfo?.workOutTime ?? $1.startDate) }
        var usedClockOutIDs = Set<UUID>()
        var groups: [WorkSessionGroup] = []

        for (index, clockIn) in clockIns.enumerated() {
            let inTime = clockIn.workInfo?.workInTime ?? clockIn.startDate
            let nextInTime = clockIns.dropFirst(index + 1).first.map { $0.workInfo?.workInTime ?? $0.startDate }

            guard let clockOut = clockOuts.first(where: { candidate in
                guard !usedClockOutIDs.contains(candidate.id) else { return false }
                let outTime = effectiveClockOutTime(for: candidate, clockInTime: inTime)
                guard outTime > inTime else { return false }
                if let nextInTime, outTime >= nextInTime { return false }
                return true
            }) else {
                continue
            }

            usedClockOutIDs.insert(clockOut.id)
            groups.append(WorkSessionGroup(clockIn: clockIn, clockOut: clockOut))
        }

        return groups
    }

    private func effectiveClockOutTime(for event: CalendarEvent, clockInTime: Date?) -> Date {
        let outTime = event.workInfo?.workOutTime ?? event.startDate
        guard let clockInTime else { return outTime }

        let calendar = Calendar.current
        guard calendar.isDate(outTime, inSameDayAs: clockInTime) else { return outTime }

        let outComponents = calendar.dateComponents([.hour, .minute], from: outTime)
        let inComponents = calendar.dateComponents([.hour, .minute], from: clockInTime)
        let outMinutes = (outComponents.hour ?? 0) * 60 + (outComponents.minute ?? 0)
        let inMinutes = (inComponents.hour ?? 0) * 60 + (inComponents.minute ?? 0)
        guard outMinutes <= inMinutes else { return outTime }
        return calendar.date(byAdding: .day, value: 1, to: outTime) ?? outTime
    }

    private func sharedWorkValues(clockIn: CalendarEvent, clockOut: CalendarEvent) -> (restHours: Double, transportFee: Int, hourlyRate: Int) {
        (
            restHours: clockIn.workInfo?.restHours ?? clockOut.workInfo?.restHours ?? 0,
            transportFee: clockIn.workInfo?.transportFee ?? clockOut.workInfo?.transportFee ?? 0,
            hourlyRate: clockIn.workInfo?.hourlyRate ?? clockOut.workInfo?.hourlyRate ?? 0
        )
    }

    private func isClockInEvent(_ event: CalendarEvent) -> Bool {
        if WorkClockTitleMatcher.isClockInTitle(event.title) { return true }
        if WorkClockTitleMatcher.isClockOutTitle(event.title) { return false }
        return event.workInfo?.workInTime != nil && event.workInfo?.workOutTime == nil
    }

    private func isClockOutEvent(_ event: CalendarEvent) -> Bool {
        if WorkClockTitleMatcher.isClockOutTitle(event.title) { return true }
        if WorkClockTitleMatcher.isClockInTitle(event.title) { return false }
        return event.workInfo?.workOutTime != nil && event.workInfo?.workInTime == nil
    }

    private func loadEmptyStatisticsState() {
        statisticsData = []
        totalHours = "00:00"
        totalAmount = "¥0"
    }

    private func formatDate(_ date: Date) -> String {
        LocalizationManager.shared.dateFormatter(dateFormat: "yyyy/MM/dd").string(from: date)
    }

    private func formatDuration(minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func formatCurrency(_ amount: Int) -> String {
        "¥\(amount)"
    }
}
