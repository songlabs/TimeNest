import GoogleMobileAds
import SwiftUI
import UIKit

struct AdMobBannerView: UIViewRepresentable {
    let width: CGFloat
    let adUnitID: String
    @Binding var bannerHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(bannerHeight: $bannerHeight)
    }

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: Self.adSize(for: width))
        bannerView.delegate = context.coordinator
        context.coordinator.bannerView = bannerView
        return bannerView
    }

    func updateUIView(_ bannerView: BannerView, context: Context) {
        let adWidth = floor(width)
        guard adWidth > 0 else {
            context.coordinator.updateHeight(0)
            return
        }

        guard let rootViewController = UIApplication.shared.timeNestRootViewController else {
            context.coordinator.updateHeight(0)
            return
        }

        let adSize = Self.adSize(for: adWidth)
        bannerView.rootViewController = rootViewController
        bannerView.adUnitID = adUnitID

        if context.coordinator.shouldLoad(width: adWidth, adUnitID: adUnitID) {
            context.coordinator.markLoading(width: adWidth, adUnitID: adUnitID)
            bannerView.adSize = adSize
            bannerView.load(Request())
        }
    }

    private static func adSize(for width: CGFloat) -> AdSize {
        largeAnchoredAdaptiveBanner(width: width)
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        private var bannerHeight: Binding<CGFloat>
        private var loadedWidth: CGFloat?
        private var loadedAdUnitID: String?
        weak var bannerView: BannerView?

        init(bannerHeight: Binding<CGFloat>) {
            self.bannerHeight = bannerHeight
        }

        func shouldLoad(width: CGFloat, adUnitID: String) -> Bool {
            loadedWidth != width || loadedAdUnitID != adUnitID
        }

        func markLoading(width: CGFloat, adUnitID: String) {
            loadedWidth = width
            loadedAdUnitID = adUnitID
            updateHeight(0)
        }

        func updateHeight(_ height: CGFloat) {
            DispatchQueue.main.async {
                self.bannerHeight.wrappedValue = height
            }
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            updateHeight(bannerView.adSize.size.height)
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            updateHeight(0)
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
