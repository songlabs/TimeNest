import SwiftUI

/// 打工统计面板 - Bottom Sheet 样式
struct WorkStatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    @ObservedObject var viewModel: WorkStatisticsViewModel

    private let statisticIconName = "chart.bar.xaxis"

    var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView {
                VStack(spacing: WorkStatisticsLayout.sectionSpacing) {
                    filterSection

                    if viewModel.isLoading {
                        loadingView
                    } else if let errorMessage = viewModel.errorMessage {
                        errorView(message: errorMessage)
                    } else if viewModel.statisticsData.isEmpty {
                        emptyView
                    } else {
                        tableView
                    }
                }
                .padding(.horizontal, WorkStatisticsLayout.horizontalPadding)
                .padding(.top, WorkStatisticsLayout.sectionSpacing)
                .padding(.bottom, WorkStatisticsLayout.horizontalPadding)
            }
        }
        .background(WorkStatisticsColors.sheetBackground)
        .presentationDetents([.height(WorkStatisticsLayout.sheetHeight)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(WorkStatisticsColors.sheetBackground)
        .presentationCornerRadius(WorkStatisticsLayout.sheetCornerRadius)
        .overlay {
            datePickerOverlay
        }
    }

    // MARK: - Header

    private var headerView: some View {
        SettingsModalHeaderView(
            title: localizedKey(.workStatisticsTitle),
            closeAction: { dismiss() }
        )
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                dateField(
                    titleKey: .startDateMonth,
                    value: viewModel.formattedStartDate,
                    action: { viewModel.showStartDatePicker = true }
                )

                dateField(
                    titleKey: .endDateMonth,
                    value: viewModel.formattedEndDate,
                    action: { viewModel.showEndDatePicker = true }
                )
            }

            Button(action: { viewModel.calculateStatistics() }) {
                Label(localizedKey(.workStatistics), systemImage: statisticIconName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: WorkStatisticsLayout.primaryButtonHeight)
                    .background(ShiftCalendarColors.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: WorkStatisticsLayout.cardCornerRadius, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isLoading)
        }
        .padding(14)
        .background(WorkStatisticsColors.sectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: WorkStatisticsLayout.cardCornerRadius, style: .continuous))
    }

    private func dateField(titleKey: LocalizedString, value: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedKey(titleKey))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(WorkStatisticsColors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Button(action: action) {
                HStack(spacing: 8) {
                    Text(value)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(WorkStatisticsColors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(WorkStatisticsColors.secondaryText)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 46)
                .glassCapsuleStyle()
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Table View

    private var tableView: some View {
        VStack(spacing: 0) {
            headerRow

            Divider().background(WorkStatisticsColors.separator)

            VStack(spacing: 0) {
                ForEach(viewModel.statisticsData) { data in
                    dataRow(data)
                    if data != viewModel.statisticsData.last {
                        Divider().background(WorkStatisticsColors.separator)
                    }
                }
            }

            Divider().background(WorkStatisticsColors.separator)

            totalRow
        }
        .background(WorkStatisticsColors.fieldBackground)
        .overlay(
            RoundedRectangle(cornerRadius: WorkStatisticsLayout.cardCornerRadius, style: .continuous)
                .stroke(WorkStatisticsColors.border, lineWidth: 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkStatisticsLayout.cardCornerRadius, style: .continuous))
    }

    private var headerRow: some View {
        tableRowBackground(background: WorkStatisticsColors.tableHeaderBackground) {
            Text(localizedKey(.columnDate))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(localizedKey(.columnTime))
                .frame(width: 76, alignment: .center)

            Text(localizedKey(.columnAmount))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(WorkStatisticsColors.secondaryText)
    }

    private func dataRow(_ data: StatisticsDataItem) -> some View {
        tableRowBackground(background: WorkStatisticsColors.fieldBackground) {
            Text(data.date)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(data.time)
                .frame(width: 76, alignment: .center)

            Text(data.amount)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: 15))
        .foregroundColor(WorkStatisticsColors.primaryText)
    }

    private var totalRow: some View {
        tableRowBackground(background: WorkStatisticsColors.totalRowBackground, verticalPadding: 14) {
            Text(localizedKey(.columnTotal))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(viewModel.totalHours)
                .frame(width: 76, alignment: .center)

            Text(viewModel.totalAmount)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(ShiftCalendarColors.primaryBlue)
    }

    private func tableRowBackground<Content: View>(
        background: Color,
        verticalPadding: CGFloat = WorkStatisticsLayout.rowVerticalPadding,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: WorkStatisticsLayout.tableColumnSpacing) {
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, verticalPadding)
        .background(background)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text(localizedKey(.workStatisticsLoading))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(WorkStatisticsColors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(WorkStatisticsColors.sectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: WorkStatisticsLayout.cardCornerRadius, style: .continuous))
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(ShiftCalendarColors.primaryBlue.opacity(0.85))
                .padding(.bottom, 4)

            Text(localizedKey(.workStatisticsEmptyTitle))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(WorkStatisticsColors.primaryText)

            Text(localizedKey(.workStatisticsEmptyMessage))
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(WorkStatisticsColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 240)
        .background(WorkStatisticsColors.sectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: WorkStatisticsLayout.cardCornerRadius, style: .continuous))
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(.orange)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(WorkStatisticsColors.primaryText)
                .multilineTextAlignment(.center)

            Button(action: { viewModel.calculateStatistics() }) {
                Label(localizedKey(.calendarSharingRetry), systemImage: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(ShiftCalendarColors.primaryBlue)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 240)
        .background(WorkStatisticsColors.sectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: WorkStatisticsLayout.cardCornerRadius, style: .continuous))
    }

    // MARK: - Date Picker Overlay

    @ViewBuilder
    private var datePickerOverlay: some View {
        if viewModel.showStartDatePicker {
            FloatingPickerOverlay(onDismiss: dismissDatePicker) {
                FloatingDatePickerPanel(
                    title: localizedKey(.startDateMonth),
                    initialSelection: viewModel.startDate,
                    cancelTitle: localizedKey(.cancel),
                    doneTitle: localizedKey(.done),
                    kind: .date,
                    confirmColor: ShiftCalendarColors.primaryBlue,
                    onCancel: dismissDatePicker,
                    onDone: { selection in
                        viewModel.startDate = selection
                        dismissDatePicker()
                    }
                )
                .id("statistics-start-date")
            }
        } else if viewModel.showEndDatePicker {
            FloatingPickerOverlay(onDismiss: dismissDatePicker) {
                FloatingDatePickerPanel(
                    title: localizedKey(.endDateMonth),
                    initialSelection: viewModel.endDate,
                    cancelTitle: localizedKey(.cancel),
                    doneTitle: localizedKey(.done),
                    kind: .date,
                    confirmColor: ShiftCalendarColors.primaryBlue,
                    onCancel: dismissDatePicker,
                    onDone: { selection in
                        viewModel.endDate = selection
                        dismissDatePicker()
                    }
                )
                .id("statistics-end-date")
            }
        }
    }

    private func dismissDatePicker() {
        viewModel.showStartDatePicker = false
        viewModel.showEndDatePicker = false
    }

    private func localizedKey(_ key: LocalizedString) -> String {
        localization.localized(key)
    }
}
