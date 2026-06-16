import SwiftUI

struct CalendarAdBannerContainer: View {
    @State private var bannerHeight: CGFloat = 0

    var body: some View {
        if AdConfiguration.isEnabled {
            HStack(spacing: 0) {
                Spacer(minLength: 0)

                AdMobBannerView(
                    adUnitID: AdConfiguration.bannerAdUnitID,
                    bannerHeight: $bannerHeight
                )
                .frame(width: AdConfiguration.bannerWidth, height: AdConfiguration.bannerHeight)

                Spacer(minLength: 0)
            }
            .frame(height: bannerHeight)
            .frame(maxWidth: .infinity)
            .clipped()
        }
    }
}
