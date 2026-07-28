import SwiftUI
import Combine

/// 打工统计数据项
struct StatisticsDataItem: Identifiable, Hashable {
    let id = UUID()
    let date: String
    let time: String
    let amount: String
}

enum WorkStatisticsLoadState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case failed(String)
}

enum JPYCurrencyFormatter {
    static func string(amount: Int, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: amount)) ?? "JPY \(amount)"
    }
}

/// 打工统计 View Model
@MainActor
class WorkStatisticsViewModel: ObservableObject {
    // MARK: - Properties
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var showStartDatePicker = false
    @Published var showEndDatePicker = false
    @Published private(set) var loadState: WorkStatisticsLoadState = .idle

    @Published var statisticsData: [StatisticsDataItem] = []
    @Published var totalHours: String = "00:00"
    @Published var totalAmount: String

    private let eventUseCase: EventUseCase?
    private(set) var calendarID: UUID
    private var calculationTask: Task<Void, Never>?
    private var calculationGeneration = 0

    var isLoading: Bool {
        loadState == .loading
    }

    var errorMessage: String? {
        guard case .failed(let message) = loadState else { return nil }
        return message
    }

    // MARK: - Initialization
    init(
        eventUseCase: EventUseCase? = nil,
        calendarID: UUID,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) {
        self.eventUseCase = eventUseCase
        self.calendarID = calendarID
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart

        self.startDate = calendar.startOfDay(for: startDate ?? monthStart)
        self.endDate = calendar.startOfDay(for: endDate ?? monthEnd)
        totalAmount = JPYCurrencyFormatter.string(
            amount: 0,
            locale: LocalizationManager.shared.currentLocale
        )
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
            loadState = .empty
            return
        }

        calculationTask?.cancel()
        calculationGeneration &+= 1
        let generation = calculationGeneration
        let requestedRange = statisticsRange()
        let requestedFetchRange = statisticsFetchRange(for: requestedRange)
        let requestedCalendarID = calendarID
        loadState = .loading

        calculationTask = Task { [weak self] in
            do {
                let events = try await eventUseCase.events(
                    in: requestedFetchRange,
                    calendarID: requestedCalendarID
                )
                try Task.checkCancellation()
                guard let self,
                      generation == self.calculationGeneration,
                      requestedCalendarID == self.calendarID else {
                    return
                }
                self.applyStatistics(from: events, in: requestedRange)
                self.loadState = self.statisticsData.isEmpty ? .empty : .loaded
            } catch is CancellationError {
                return
            } catch {
                guard let self,
                      generation == self.calculationGeneration else {
                    return
                }
                self.loadEmptyStatisticsState()
                self.loadState = .failed(error.localizedDescription)
            }
        }
    }

    func setCalendarScope(calendarID: UUID) {
        guard self.calendarID != calendarID else { return }
        calculationTask?.cancel()
        calculationGeneration &+= 1
        self.calendarID = calendarID
        loadEmptyStatisticsState()
        loadState = .idle
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

    private func statisticsFetchRange(for range: DateInterval) -> DateInterval {
        let calendar = Calendar.current
        let fetchEnd = calendar.date(byAdding: .day, value: 1, to: range.end) ?? range.end
        return DateInterval(start: range.start, end: fetchEnd)
    }

    private func applyStatistics(from events: [CalendarEvent], in range: DateInterval) {
        let completeSessions = WorkRecordSessionCalculator.sessions(
            from: events,
            in: range,
            calendar: .current
        )

        var totalMinutes = 0
        var totalPay = 0

        statisticsData = completeSessions.map { session in
            let sharedValues = sharedWorkValues(clockIn: session.clockIn, clockOut: session.clockOut)
            let minutes = session.workedMinutes
            let amount = Int((session.workedSeconds / 3600) * Double(sharedValues.hourlyRate))
                + sharedValues.transportFee

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

    private func sharedWorkValues(clockIn: CalendarEvent, clockOut: CalendarEvent) -> (restHours: Double, transportFee: Int, hourlyRate: Int) {
        (
            restHours: clockIn.workInfo?.restHours ?? clockOut.workInfo?.restHours ?? 0,
            transportFee: clockIn.workInfo?.transportFee ?? clockOut.workInfo?.transportFee ?? 0,
            hourlyRate: clockIn.workInfo?.hourlyRate ?? clockOut.workInfo?.hourlyRate ?? 0
        )
    }

    func loadEmptyStatisticsState() {
        statisticsData = []
        totalHours = "00:00"
        totalAmount = formatCurrency(0)
    }

    private func formatDate(_ date: Date) -> String {
        LocalizationManager.shared.formattedUserVisibleDate(for: date)
    }

    private func formatDuration(minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func formatCurrency(_ amount: Int) -> String {
        JPYCurrencyFormatter.string(
            amount: amount,
            locale: LocalizationManager.shared.currentLocale
        )
    }
}
