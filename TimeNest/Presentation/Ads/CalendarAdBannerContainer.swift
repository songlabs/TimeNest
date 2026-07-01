import SwiftUI

struct CalendarAdBannerContainer: View {
    @ObservedObject private var consentManager = AdConsentManager.shared
    @ObservedObject private var purchaseManager = RemoveAdsPurchaseManager.shared

    var body: some View {
        if AdConfiguration.isEnabled && !purchaseManager.isAdsRemoved {
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
