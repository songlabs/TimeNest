import SwiftUI

/// 广告 banner 占位区域 - 预留广告位，尺寸 320x50
struct AdBannerPlaceholderView: View {
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        ZStack {
            // 灰色背景
            Color(red: 0.92, green: 0.92, blue: 0.92)

            // 广告占位文字
            Text(verbatim: localization.localized(.adPlaceholder))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)

            // 边框
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
        }
        .frame(height: ShiftCalendarLayout.adBannerHeight)
        .cornerRadius(4)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack {
        Spacer()
        AdBannerPlaceholderView()
            .padding()
            .environmentObject(LocalizationManager.preview(languageCode: "ja"))
    }
    .background(ShiftCalendarColors.backgroundColor)
}
#endif
