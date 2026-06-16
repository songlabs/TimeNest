import SwiftUI

struct CalendarAdBannerContainer: View {
    @State private var bannerHeight: CGFloat = 0

    var body: some View {
        if AdConfiguration.isEnabled {
            GeometryReader { proxy in
                let availableWidth = max(
                    0,
                    floor(proxy.size.width - proxy.safeAreaInsets.leading - proxy.safeAreaInsets.trailing)
                )

                if availableWidth > 0 {
                    HStack(spacing: 0) {
                        Spacer(minLength: proxy.safeAreaInsets.leading)

                        AdMobBannerView(
                            width: availableWidth,
                            adUnitID: AdConfiguration.bannerAdUnitID,
                            bannerHeight: $bannerHeight
                        )
                        .frame(width: availableWidth, height: bannerHeight)

                        Spacer(minLength: proxy.safeAreaInsets.trailing)
                    }
                }
            }
            .frame(height: bannerHeight)
            .frame(maxWidth: .infinity)
            .clipped()
        }
    }
}
