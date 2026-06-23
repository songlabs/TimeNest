import AppTrackingTransparency
import Combine
import CoreGraphics
import Foundation
import GoogleMobileAds
import UserMessagingPlatform

enum AdConfiguration {
    private static let testAppID = "ca-app-pub-3940256099942544~1458002511"
    private static let testBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"

    static let isEnabled: Bool = {
#if DEBUG || targetEnvironment(simulator)
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
#if DEBUG || targetEnvironment(simulator)
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
    @Published private(set) var canLoadAds = false
    @Published private(set) var isPrivacyOptionsRequired = false

    private var hasRequestedConsentInfo = false
    private var hasRequestedTrackingAuthorization = false
    private var hasStartedMobileAds = false

    private init() {}

    func requestConsentInfoIfNeeded() {
        guard AdConfiguration.isEnabled, !hasRequestedConsentInfo else { return }
        hasRequestedConsentInfo = true

        let parameters = RequestParameters()
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.refreshConsentState()

                guard error == nil else {
                    self.prepareAdsAfterConsentFlow()
                    return
                }
                try? await ConsentForm.loadAndPresentIfRequired(from: nil)
                self.prepareAdsAfterConsentFlow()
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
            Task { @MainActor in
                self?.prepareAdsAfterConsentFlow()
                completion(error)
            }
        }
    }

    private func refreshConsentState() {
        let consentInformation = ConsentInformation.shared
        isPrivacyOptionsRequired = consentInformation.privacyOptionsRequirementStatus == .required
        canRequestAds = consentInformation.canRequestAds
        if !canRequestAds {
            canLoadAds = false
        }
    }

    private func prepareAdsAfterConsentFlow() {
        refreshConsentState()
        guard canRequestAds else { return }

        switch ATTrackingManager.trackingAuthorizationStatus {
        case .notDetermined:
            guard !hasRequestedTrackingAuthorization else { return }
            hasRequestedTrackingAuthorization = true
            ATTrackingManager.requestTrackingAuthorization { [weak self] _ in
                Task { @MainActor in
                    self?.startMobileAdsIfAllowed()
                }
            }
        case .authorized, .denied, .restricted:
            startMobileAdsIfAllowed()
        @unknown default:
            startMobileAdsIfAllowed()
        }
    }

    private func startMobileAdsIfAllowed() {
        guard canRequestAds else { return }
        if hasStartedMobileAds {
            canLoadAds = true
            return
        }

        hasStartedMobileAds = true
        MobileAds.shared.requestConfiguration.publisherPrivacyPersonalizationState = .disabled
        MobileAds.shared.start(completionHandler: nil)
        canLoadAds = true
    }
}
