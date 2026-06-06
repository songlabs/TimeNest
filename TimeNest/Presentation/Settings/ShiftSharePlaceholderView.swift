import SwiftUI

/// 班次共享占位视图 - 从 SettingsView 进入
struct ShiftSharePlaceholderView: View {
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        ListPlaceholderView(titleKey: .shiftShare)
    }
}

#Preview {
    NavigationView {
        ShiftSharePlaceholderView()
            .environmentObject(LocalizationManager.preview(languageCode: "ja"))
    }
}
