import SwiftUI

struct HolidayRegionSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    
    @Binding var selectedRegions: [HolidayRegion]
    
    @State private var showMaxLimitAlert = false
    @State private var showMinLimitAlert = false
    
    private let maxSelectionCount = 2
    private let minSelectionCount = 1
    
    var body: some View {
        NavigationStack {
            List(HolidayRegion.allCases, id: \.id) { region in
                HStack {
                    Text(localization.localized(region.localizedKey))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if selectedRegions.contains(region) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleRegion(region)
                }
            }
            .navigationTitle(localization.localized(.holidayRegionSelectionTitle))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.localized(.done)) {
                        dismiss()
                    }
                }
            }
            .alert(localization.localized(.holidayRegionMaxLimit), isPresented: $showMaxLimitAlert) {
            } message: {
                Text(localization.localized(.holidayRegionMaxLimit))
            }
            .alert(localization.localized(.holidayRegionMinLimit), isPresented: $showMinLimitAlert) {
            } message: {
                Text(localization.localized(.holidayRegionMinLimit))
            }
        }
    }
    
    private func toggleRegion(_ region: HolidayRegion) {
        if selectedRegions.contains(region) {
            // 取消选择
            if selectedRegions.count > minSelectionCount {
                selectedRegions.removeAll { $0 == region }
            } else {
                showMinLimitAlert = true
            }
        } else {
            // 选择新的
            if selectedRegions.count < maxSelectionCount {
                selectedRegions.append(region)
            } else {
                showMaxLimitAlert = true
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        HolidayRegionSelectionView(selectedRegions: .constant([.japan, .china]))
            .environmentObject(LocalizationManager.preview(languageCode: "ja"))
    }
}
#endif
