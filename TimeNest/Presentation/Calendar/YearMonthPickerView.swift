import SwiftUI

/// Compact floating panel for selecting year and month.
struct YearMonthPickerView: View {
    @EnvironmentObject private var localization: LocalizationManager

    let currentDate: Date
    let onCancel: () -> Void
    let onSelect: (Int, Int) -> Void

    @State private var selectedYear: Int
    @State private var selectedMonth: Int

    private let yearRange: ClosedRange<Int>
    private let monthRange = 1...12

    init(
        currentDate: Date,
        onCancel: @escaping () -> Void,
        onSelect: @escaping (Int, Int) -> Void
    ) {
        self.currentDate = currentDate
        self.onCancel = onCancel
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
        VStack(spacing: 14) {
            // Title
            Text(localization.localized(.selectYearMonth))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            
            // Year and Month Pickers
            HStack(spacing: 16) {
                // Year Picker
                VStack(spacing: 6) {
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
                    .frame(width: 100, height: 120)
                }
                
                // Month Picker
                VStack(spacing: 6) {
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
                    .frame(width: 80, height: 120)
                }
            }
            
            // Buttons
            HStack(spacing: 12) {
               // Cancel Button
                Button(action: {
                    onCancel()
                }) {
                    Text(localization.localized(.cancel))
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .foregroundColor(.secondary)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(10)
                }
                
                // Confirm Button
                Button(action: {
                    onSelect(selectedYear, selectedMonth)
                }) {
                    Text(localization.localized(.ok))
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .foregroundColor(.white)
                        .background(ShiftCalendarColors.primaryBlue)
                        .cornerRadius(10)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .frame(maxWidth: 300)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 0.5)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 14, x: 0, y: 6)
    }
    
    private func monthLabel(for month: Int) -> String {
        localization.monthName(for: month)
    }
}
