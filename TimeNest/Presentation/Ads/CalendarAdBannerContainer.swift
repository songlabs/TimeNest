import SwiftUI

struct CalendarAdBannerContainer: View {
    var body: some View {
        if AdConfiguration.isEnabled {
            HStack(spacing: 0) {
                Spacer(minLength: 0)

                AdMobBannerView(
                    adUnitID: AdConfiguration.bannerAdUnitID
                )
                .frame(width: AdConfiguration.bannerWidth, height: AdConfiguration.bannerHeight)

                Spacer(minLength: 0)
            }
            .frame(height: AdConfiguration.bannerHeight)
            .frame(maxWidth: .infinity)
            .clipped()
        }
    }
}
