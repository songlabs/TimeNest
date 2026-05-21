import SwiftUI

struct AddEventButtonRow: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Plus icon
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ShiftCalendarColors.primaryBlue)
                
                Text("新規の予定を入力する")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ShiftCalendarColors.primaryText)
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ShiftCalendarColors.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(ShiftCalendarColors.cardBackgroundColor)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

// MARK: - Preview

#Preview {
    AddEventButtonRow(onTap: {})
        .background(ShiftCalendarColors.backgroundColor)
}
