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
                let events = try await eventUseCase.events(in: statisticsRange())
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

    private func applyStatistics(from events: [CalendarEvent]) {
        let calendar = Calendar.current
        var clockIns: [Date: CalendarEvent] = [:]
        var clockOuts: [Date: CalendarEvent] = [:]

        for event in events {
            let clockInTime = event.workInfo?.workInTime ?? event.startDate
            let clockOutTime = effectiveClockOutTime(for: event, clockInTime: nil)

            if isClockInEvent(event) {
                let day = calendar.startOfDay(for: event.workInfo?.workDate ?? clockInTime)
                if clockIns[day].map({ clockInTime < ($0.workInfo?.workInTime ?? $0.startDate) }) ?? true {
                    clockIns[day] = event
                }
            } else if isClockOutEvent(event) {
                let day = calendar.startOfDay(for: event.workInfo?.workDate ?? event.startDate)
                if clockOuts[day].map({ clockOutTime > ($0.workInfo?.workOutTime ?? $0.startDate) }) ?? true {
                    clockOuts[day] = event
                }
            }
        }

        let days = clockIns.keys.filter { clockOuts[$0] != nil }.sorted()
        var totalMinutes = 0
        var totalPay = 0

        statisticsData = days.compactMap { day in
            guard let clockIn = clockIns[day], let clockOut = clockOuts[day] else { return nil }
            let inTime = clockIn.workInfo?.workInTime ?? clockIn.startDate
            let outTime = effectiveClockOutTime(for: clockOut, clockInTime: inTime)
            guard outTime > inTime else { return nil }

            let restHours = clockIn.workInfo?.restHours ?? clockOut.workInfo?.restHours ?? 0
            let workedSeconds = max(0, outTime.timeIntervalSince(inTime) - restHours * 3600)
            let minutes = Int(workedSeconds / 60)
            let sharedValues = sharedWorkValues(clockIn: clockIn, clockOut: clockOut)
            let amount = Int((workedSeconds / 3600) * Double(sharedValues.hourlyRate)) + sharedValues.transportFee

            totalMinutes += minutes
            totalPay += amount

            return StatisticsDataItem(
                date: formatDate(day),
                time: formatDuration(minutes: minutes),
                amount: formatCurrency(amount)
            )
        }

        totalHours = formatDuration(minutes: totalMinutes)
        totalAmount = formatCurrency(totalPay)
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
        guard outMinutes < inMinutes else { return outTime }
        return calendar.date(byAdding: .day, value: 1, to: outTime) ?? outTime
    }

    private func sharedWorkValues(clockIn: CalendarEvent, clockOut: CalendarEvent) -> (transportFee: Int, hourlyRate: Int) {
        (
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    private func formatDuration(minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func formatCurrency(_ amount: Int) -> String {
        "¥\(amount)"
    }
}
