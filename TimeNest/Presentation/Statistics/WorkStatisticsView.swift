import SwiftUI

/// 打工统计面板 - Bottom Sheet 样式
struct WorkStatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: WorkStatisticsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            headerView
            
            // 筛选区域
            filterSection
            
            // 数据表格
            if viewModel.isLoading {
                loadingView
            } else if viewModel.statisticsData.isEmpty {
                emptyView
            } else {
                tableView
            }
        }
        .background(Color(UIColor.systemBackground))
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Text(LocalizedStringKey("work_statistics.title"))
                .font(.system(size: 20, weight: .semibold))
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(UIColor.separator))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    // MARK: - Filter Section
    private var filterSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // 开始年月选择器
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("work_statistics.start_date_month"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Button(action: { viewModel.showStartDatePicker = true }) {
                        HStack {
                            Text(viewModel.formattedStartDate)
                                .font(.system(size: 16, weight: .regular))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // 结束年月选择器
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("work_statistics.end_date_month"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Button(action: { viewModel.showEndDatePicker = true }) {
                        HStack {
                            Text(viewModel.formattedEndDate)
                                .font(.system(size: 16, weight: .regular))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // 统计按钮
            Button(action: { viewModel.calculateStatistics() }) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                    Text(LocalizedStringKey("work_statistics"))
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ShiftCalendarColors.primaryBlue)
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
    }
    
    // MARK: - Table View
    private var tableView: some View {
        VStack(spacing: 0) {
            // 表格头部
            headerRow
            
            Divider()
            
            // 数据行
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.statisticsData) { data in
                        dataRow(data)
                        if data != viewModel.statisticsData.last {
                            Divider()
                        }
                    }
                }
            }
            
            Divider()
            
            // 总计行
            totalRow
        }
        .frame(maxHeight: .infinity)
    }
    
    private var headerRow: some View {
        HStack {
            Text(LocalizedStringKey("work_statistics.column_date"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(LocalizedStringKey("work_statistics.column_time"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(LocalizedStringKey("work_statistics.column_amount"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemGray6))
    }
    
    private func dataRow(_ data: StatisticsDataItem) -> some View {
        HStack {
            Text(data.date)
                .font(.system(size: 14))
                .frame(width: 100, alignment: .leading)
            
            Text(data.time)
                .font(.system(size: 14))
                .frame(width: 100, alignment: .leading)
            
            Text(data.amount)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var totalRow: some View {
        HStack {
            Text(LocalizedStringKey("work_statistics.column_total"))
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 100, alignment: .leading)
            
            Text(viewModel.totalHours)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 100, alignment: .leading)
            
            Text(viewModel.totalAmount)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(UIColor.systemGray6))
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("加载中...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis.empty")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("暂无统计数据")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            
            Text("请调整筛选条件后点击统计按钮")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Work Statistics") {
    let viewModel = WorkStatisticsViewModel()
    viewModel.showStartDatePicker = false
    viewModel.showEndDatePicker = false
    
    return WorkStatisticsView(viewModel: viewModel)
        .environmentObject(LocalizationManager.preview(languageCode: "zh-Hans"))
        .background(Color(UIColor.systemGray5))
}
#endif
