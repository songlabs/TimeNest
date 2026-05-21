import SwiftUI

struct WeekdayHeaderView: View {
    let weekdaySymbols: [String]
    let cellWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(
                        size: ShiftCalendarLayout.dayNumberFontSize,
                        weight: .medium
                    ))
                    .foregroundColor(.white)
                    .frame(width: cellWidth)
            }
        }
        .frame(height: ShiftCalendarLayout.weekdayRowHeight)
        .background(ShiftCalendarColors.primaryBlue)
    }
}

// MARK: - Preview

#Preview {
    WeekdayHeaderView(
        weekdaySymbols: ["日", "一", "二", "三", "四", "五", "六"],
        cellWidth: 50
    )
}
