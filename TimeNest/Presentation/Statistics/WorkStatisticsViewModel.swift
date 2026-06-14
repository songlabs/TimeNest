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
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(startDate: Date? = nil, endDate: Date? = nil) {
        let calendar = Calendar.current
        
        // 默认值：当前月份
        let computedStartDate: Date
        if let startDate = startDate {
            computedStartDate = startDate
        } else {
            computedStartDate = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        }
        
        let computedEndDate: Date
        if let endDate = endDate {
            computedEndDate = endDate
        } else {
            computedEndDate = computedStartDate
        }
        
        self.startDate = computedStartDate
        self.endDate = computedEndDate
    }
    
    // MARK: - Computed Properties
    var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy 年 MM 月"
        return formatter.string(from: startDate)
    }
    
    var formattedEndDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy 年 MM 月"
        return formatter.string(from: endDate)
    }
    
    // MARK: - Public Methods
    /// 计算统计数据
    func calculateStatistics() {
        isLoading = true
        
        // 模拟延迟（实际应用中应该从数据源获取真实数据）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.loadEmptyStatisticsState()
            self?.isLoading = false
        }
    }
    
    /// 设置日期范围
    func setDateRange(start: Date, end: Date) {
        let calendar = Calendar.current
        
        // 确保结束日期不早于开始日期
        if calendar.compare(end, to: start, toGranularity: .month) == .orderedAscending {
            self.endDate = start
        } else {
            self.startDate = start
            self.endDate = end
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
        if let range = calendar.dateInterval(of: .month, for: anchorDate) {
            self.startDate = range.start
            self.endDate = range.end
            self.startDate = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: self.startDate) ?? self.startDate
            self.endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: self.endDate) ?? self.endDate
        }
        
        calculateStatistics()
    }
    
    // MARK: - Private Methods
    /// 加载统计数据
    /// 当前无真实数据源，显示空状态
    func loadEmptyStatisticsState() {
        // TODO: 从真实数据源获取 Event 数据并计算
        // 当前无真实打工数据，清空统计数据以显示空状态
        
        statisticsData = []
        totalHours = "00:00"
        totalAmount = "¥0"
    }
}
