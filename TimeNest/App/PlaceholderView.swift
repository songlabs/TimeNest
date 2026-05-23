import SwiftUI

/// 通用占位视图 - 用于尚未实现的功能页面
struct ListPlaceholderView: View {
    @EnvironmentObject private var localization: LocalizationManager
    let titleKey: LocalizedString

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "hammer.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(localization.localized(titleKey))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text(localization.localized(.placeholderComingSoon))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .id(localization.selectedLanguageCode)
    }
}

#Preview {
    ListPlaceholderView(titleKey: .listCalendar)
        .environmentObject(LocalizationManager.preview(languageCode: "ja"))
}
