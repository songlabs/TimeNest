import Combine
import CoreGraphics
import Foundation
import GoogleMobileAds
import UserMessagingPlatform

enum AdConfiguration {
    private static let testAppID = "ca-app-pub-3940256099942544~1458002511"
    private static let testBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"

    static let isEnabled: Bool = {
#if DEBUG
        return true
#else
        precondition(configuredAdsEnabled, "Release builds must enable advertising.")

        let appID = infoString(for: "GADApplicationIdentifier")
        let bannerID = infoString(for: "TimeNestAdMobBannerUnitID")
        precondition(
            appID != testAppID && bannerID != testBannerAdUnitID,
            "Release builds cannot use Google's test AdMob IDs."
        )
        precondition(
            isValidAppID(appID) && isValidBannerAdUnitID(bannerID),
            "Release builds require valid production AdMob App and Banner IDs."
        )
        return true
#endif
    }()

    static let bannerAdUnitID: String = {
#if DEBUG
        return testBannerAdUnitID
#else
        return infoString(for: "TimeNestAdMobBannerUnitID")
#endif
    }()

    static let bannerWidth: CGFloat = 320
    static let bannerHeight: CGFloat = 50

    private static var configuredAdsEnabled: Bool {
        let value = infoString(for: "TimeNestAdsEnabled").lowercased()
        return value == "yes" || value == "true" || value == "1"
    }

    private static func infoString(for key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func isValidAppID(_ value: String) -> Bool {
        value.range(
            of: #"^ca-app-pub-[0-9]{16}~[0-9]{10}$"#,
            options: .regularExpression
        ) != nil
    }

    private static func isValidBannerAdUnitID(_ value: String) -> Bool {
        value.range(
            of: #"^ca-app-pub-[0-9]{16}/[0-9]{10}$"#,
            options: .regularExpression
        ) != nil
    }
}

@MainActor
final class AdConsentManager: ObservableObject {
    static let shared = AdConsentManager()

    @Published private(set) var canRequestAds = false
    @Published private(set) var isPrivacyOptionsRequired = false

    private var hasRequestedConsentInfo = false
    private var hasStartedMobileAds = false

    private init() {}

    func requestConsentInfoIfNeeded() {
        guard AdConfiguration.isEnabled, !hasRequestedConsentInfo else { return }
        hasRequestedConsentInfo = true

        let parameters = RequestParameters()
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            guard let self else { return }
            self.refreshConsentState()

            guard error == nil else { return }
            ConsentForm.loadAndPresentIfRequired(from: nil) { [weak self] _ in
                self?.refreshConsentState()
            }
        }

        // UMP synchronously exposes a valid consent decision cached from a prior launch.
        refreshConsentState()
    }

    func presentPrivacyOptions(completion: @escaping (Error?) -> Void) {
        guard isPrivacyOptionsRequired else {
            completion(nil)
            return
        }

        ConsentForm.presentPrivacyOptionsForm(from: nil) { [weak self] error in
            self?.refreshConsentState()
            completion(error)
        }
    }

    private func refreshConsentState() {
        let consentInformation = ConsentInformation.shared
        isPrivacyOptionsRequired = consentInformation.privacyOptionsRequirementStatus == .required
        canRequestAds = consentInformation.canRequestAds

        guard canRequestAds, !hasStartedMobileAds else { return }
        hasStartedMobileAds = true
        MobileAds.shared.requestConfiguration.publisherPrivacyPersonalizationState = .disabled
        MobileAds.shared.start(completionHandler: nil)
    }
}
