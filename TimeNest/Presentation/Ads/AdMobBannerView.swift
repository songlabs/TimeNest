import GoogleMobileAds
import SwiftUI
import UIKit

struct AdMobBannerView: UIViewRepresentable {
    let adUnitID: String
    let canLoadAds: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BannerHostView {
        BannerHostView()
    }

    func updateUIView(_ hostView: BannerHostView, context: Context) {
        guard canLoadAds else { return }
        guard let rootViewController = UIApplication.shared.timeNestRootViewController else {
            return
        }

        let bannerView = hostView.bannerView
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

final class BannerHostView: UIView {
    let bannerView = BannerView(adSize: AdSizeBanner)

    private let bannerWidth = AdConfiguration.bannerWidth
    private let bannerHeight = AdConfiguration.bannerHeight

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        clipsToBounds = true
        bannerView.backgroundColor = .clear
        bannerView.clipsToBounds = false
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bannerView)

        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            bannerView.widthAnchor.constraint(equalToConstant: bannerWidth),
            bannerView.heightAnchor.constraint(equalToConstant: bannerHeight)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
