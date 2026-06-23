import SwiftUI

struct CalendarAdBannerContainer: View {
    @ObservedObject private var consentManager = AdConsentManager.shared

    var body: some View {
        if AdConfiguration.isEnabled {
            Group {
                if consentManager.canLoadAds {
                    AdMobBannerView(
                        adUnitID: AdConfiguration.bannerAdUnitID,
                        canLoadAds: consentManager.canLoadAds
                    )
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: AdConfiguration.bannerHeight)
        }
    }
}
