import SwiftUI

/// Year-Month Picker Sheet for selecting year and month
struct YearMonthPickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    let currentYear: Int
    let currentMonth: Int
    let onConfirm: (Int, Int) -> Void
    
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    
    private let yearRange: ClosedRange<Int>
    private let monthRange = 1...12
    
    init(currentDate: Date, onConfirm: @escaping (Int, Int) -> Void) {
        let calendar = Calendar(identifier: .gregorian)
        self.currentYear = calendar.component(.year, from: currentDate)
        self.currentMonth = calendar.component(.month, from: currentDate)
        self.onConfirm = onConfirm
        
        self.selectedYear = self.currentYear
        self.selectedMonth = self.currentMonth
        
        // Year range: current year ± 10 years
        self.yearRange = (currentYear - 10)...(currentYear + 10)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("select_year_month")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            
            // Year and Month Pickers
            HStack(spacing: 16) {
                // Year Picker
                VStack(spacing: 8) {
                    Text("year_label")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker("Year", selection: $selectedYear) {
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
                    Text("month_label")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker("Month", selection: $selectedMonth) {
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
                    Text("common.cancel")
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundColor(.secondary)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(10)
                }
                
                // Confirm Button
                Button(action: {
                    onConfirm(selectedYear, selectedMonth)
                    dismiss()
                }) {
                    Text("common.ok")
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
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = selectedYear
        components.month = month
        if let date = calendar.date(from: components) {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.dateFormat = "M"
            return formatter.string(from: date)
        }
        return "\(month)"
    }
}

// MARK: - Preview

#Preview {
    YearMonthPickerView(currentDate: Date()) { year, month in
        print("Selected: \(year)-\(month)")
    }
    .padding()
    .background(ShiftCalendarColors.backgroundColor)
}
