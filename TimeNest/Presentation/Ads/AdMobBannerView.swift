import GoogleMobileAds
import SwiftUI
import UIKit

struct AdMobBannerView: UIViewRepresentable {
    let adUnitID: String
    let canLoadAds: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        return bannerView
    }

    func updateUIView(_ bannerView: BannerView, context: Context) {
        guard canLoadAds else { return }
        guard let rootViewController = UIApplication.shared.timeNestRootViewController else {
            return
        }

        bannerView.rootViewController = rootViewController
        bannerView.adUnitID = adUnitID

        if context.coordinator.shouldLoad(adUnitID: adUnitID) {
            context.coordinator.markLoading(adUnitID: adUnitID)
            bannerView.adSize = AdSizeBanner
            bannerView.load(Request())
        }
    }

    final class Coordinator: NSObject {
        private var loadedAdUnitID: String?

        func shouldLoad(adUnitID: String) -> Bool {
            loadedAdUnitID != adUnitID
        }

        func markLoading(adUnitID: String) {
            loadedAdUnitID = adUnitID
        }
    }
}

private extension UIApplication {
    var timeNestRootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
