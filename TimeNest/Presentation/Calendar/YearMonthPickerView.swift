import SwiftUI

/// Year-Month Picker Sheet for selecting year and month
struct YearMonthPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager

    let currentDate: Date
    let onSelect: (Int, Int) -> Void

    @State private var selectedYear: Int
    @State private var selectedMonth: Int

    private let yearRange: ClosedRange<Int>
    private let monthRange = 1...12

    init(currentDate: Date, onSelect: @escaping (Int, Int) -> Void) {
        self.currentDate = currentDate
        self.onSelect = onSelect

        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: currentDate)
        let month = calendar.component(.month, from: currentDate)

        self.selectedYear = year
        self.selectedMonth = month

        // Year range: current year ± 10 years
        self.yearRange = (year - 10)...(year + 10)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text(localization.localized(.selectYearMonth))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            
            // Year and Month Pickers
            HStack(spacing: 16) {
                // Year Picker
                VStack(spacing: 8) {
                    Text(localization.localized(.yearLabel))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker(localization.localized(.yearLabel), selection: $selectedYear) {
                        ForEach(yearRange, id: \.self) { year in
                            Text("\(year)")
                                .tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 100, height: 140)
                }
                
               // Month Picker
                VStack(spacing: 8) {
                    Text(localization.localized(.monthLabel))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker(localization.localized(.monthLabel), selection: $selectedMonth) {
                        ForEach(monthRange, id: \.self) { month in
                            Text(monthLabel(for: month))
                                .tag(month)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 140)
                }
            }
            
            // Buttons
            HStack(spacing: 12) {
               // Cancel Button
                Button(action: {
                    dismiss()
                }) {
                    Text(localization.localized(.cancel))
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundColor(.secondary)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(10)
                }
                
                // Confirm Button
                Button(action: {
                    onSelect(selectedYear, selectedMonth)
                    dismiss()
                }) {
                    Text(localization.localized(.ok))
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundColor(.white)
                        .background(ShiftCalendarColors.primaryBlue)
                        .cornerRadius(10)
                }
            }
        }
        .padding(20)
    }
    
    private func monthLabel(for month: Int) -> String {
        localization.monthName(for: month)
    }
}
