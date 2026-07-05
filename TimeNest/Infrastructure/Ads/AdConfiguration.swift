import AppTrackingTransparency
import Combine
import CoreGraphics
import Foundation
import GoogleMobileAds
import StoreKit
import UserMessagingPlatform

enum AdConfiguration {
    static let removeAdsProductID = "com.song.TimeNest.remove_ads"

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

enum RemoveAdsPurchaseOutcome {
    case completed
    case restored
    case cancelled
    case pending
    case failed(RemoveAdsPurchaseFailureReason)
}

enum RemoveAdsPurchaseFailureReason {
    case productUnavailable
    case purchaseFailed
    case verificationFailed
    case productMismatch
    case unknownPurchaseResult
    case restoreFailed
    case noRestorablePurchases
}

@MainActor
final class RemoveAdsPurchaseManager: ObservableObject {
    static let shared = RemoveAdsPurchaseManager()

    @Published private(set) var isAdsRemoved: Bool
    @Published private(set) var isPurchasing = false

    private static let adsRemovedDefaultsKey = "removeAds.isPurchased"

    private let defaults: UserDefaults
    private var removeAdsProduct: Product?
    private var productLoadTask: Task<Product?, Never>?
    private var transactionUpdatesTask: Task<Void, Never>?

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isAdsRemoved = defaults.bool(forKey: Self.adsRemovedDefaultsKey)
    }

    @discardableResult
    func loadProductIfNeeded() async -> Bool {
        if removeAdsProduct != nil {
            return true
        }

        if let productLoadTask {
            Self.debugLog("Waiting for in-flight product load.")
            removeAdsProduct = await productLoadTask.value
            return removeAdsProduct != nil
        }

        let requestedProductID = AdConfiguration.removeAdsProductID
        let productLoadTask = Task<Product?, Never> {
            do {
                let products = try await Product.products(for: [requestedProductID])
                let productSummaries = products.map { Self.debugSummary(for: $0) }
                Self.debugLog("Product.products requested id=\(requestedProductID), returned count=\(products.count), products=\(productSummaries).")

                guard let product = products.first(where: { $0.id == requestedProductID }) else {
                    let emptyProductsHint = products.isEmpty
                        ? "The returned product list is empty."
                        : "Returned products did not include the requested product id."
                    Self.debugLog("\(emptyProductsHint) Expected a non-consumable remove-ads product. Check StoreKit Configuration, App Store Connect product id/status, bundle id, and Sandbox account.")
                    return nil
                }

                Self.debugLog("Loaded remove-ads product \(Self.debugSummary(for: product)).")
                return product
            } catch {
                Self.debugLog("Product.products failed for id=\(requestedProductID): \(Self.debugDescription(for: error))")
                return nil
            }
        }

        self.productLoadTask = productLoadTask
        removeAdsProduct = await productLoadTask.value
        self.productLoadTask = nil
        return removeAdsProduct != nil
    }

    func startObservingTransactionUpdates() {
        guard transactionUpdatesTask == nil else { return }

        transactionUpdatesTask = Task { [weak self] in
            Self.debugLog("Started Transaction.updates listener.")
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handleTransactionUpdate(result)
            }
        }
    }

    func purchaseRemoveAds() async -> RemoveAdsPurchaseOutcome {
        guard !isAdsRemoved else { return .completed }
        guard !isPurchasing else { return .pending }
        guard await loadProductIfNeeded(), let removeAdsProduct else {
            Self.debugLog("Purchase aborted because the remove-ads product is unavailable.")
            return .failed(.productUnavailable)
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await removeAdsProduct.purchase()
            switch result {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let transaction):
                    guard transaction.productID == AdConfiguration.removeAdsProductID else {
                        Self.debugLog("Purchase returned mismatched product id=\(transaction.productID).")
                        return .failed(.productMismatch)
                    }
                    guard applyVerifiedRemoveAdsTransaction(transaction) else {
                        return .failed(.verificationFailed)
                    }
                    await transaction.finish()
                    Self.debugLog("Purchase completed and transaction finished for id=\(transaction.productID).")
                    return .completed
                case .unverified(let transaction, let error):
                    Self.debugLog("Purchase transaction was unverified for id=\(transaction.productID): \(Self.debugDescription(for: error))")
                    return .failed(.verificationFailed)
                }
            case .userCancelled:
                Self.debugLog("Purchase was cancelled by the user.")
                return .cancelled
            case .pending:
                Self.debugLog("Purchase is pending external approval.")
                return .pending
            @unknown default:
                Self.debugLog("Purchase returned an unknown StoreKit result.")
                return .failed(.unknownPurchaseResult)
            }
        } catch {
            Self.debugLog("Product.purchase failed: \(Self.debugDescription(for: error))")
            return .failed(.purchaseFailed)
        }
    }

    func restorePurchases() async -> RemoveAdsPurchaseOutcome {
        var syncFailed = false
        do {
            try await AppStore.sync()
            Self.debugLog("AppStore.sync completed.")
        } catch {
            syncFailed = true
            Self.debugLog("AppStore.sync failed; checking current entitlements anyway: \(Self.debugDescription(for: error))")
        }

        let restored = await refreshPurchasedState()
        if restored {
            return .restored
        }
        return .failed(syncFailed ? .restoreFailed : .noRestorablePurchases)
    }

    @discardableResult
    func refreshPurchasedState() async -> Bool {
        let hasEntitlement = await hasVerifiedRemoveAdsEntitlement()
        setAdsRemoved(hasEntitlement)
        return hasEntitlement
    }

    private func hasVerifiedRemoveAdsEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productID == AdConfiguration.removeAdsProductID,
                   transaction.revocationDate == nil {
                    Self.debugLog("Found verified remove-ads entitlement.")
                    return true
                }
            case .unverified(let transaction, let error):
                if transaction.productID == AdConfiguration.removeAdsProductID {
                    Self.debugLog("Current entitlement was unverified for id=\(transaction.productID): \(Self.debugDescription(for: error))")
                }
            }
        }
        Self.debugLog("No verified remove-ads entitlement found.")
        return false
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            guard transaction.productID == AdConfiguration.removeAdsProductID else { return }
            if applyVerifiedRemoveAdsTransaction(transaction) {
                await transaction.finish()
                Self.debugLog("Applied Transaction.updates transaction for id=\(transaction.productID).")
            }
        case .unverified(let transaction, let error):
            guard transaction.productID == AdConfiguration.removeAdsProductID else { return }
            Self.debugLog("Transaction.updates produced unverified transaction for id=\(transaction.productID): \(Self.debugDescription(for: error))")
        }
    }

    @discardableResult
    private func applyVerifiedRemoveAdsTransaction(_ transaction: Transaction) -> Bool {
        guard transaction.productID == AdConfiguration.removeAdsProductID else {
            return false
        }
        guard transaction.revocationDate == nil else {
            setAdsRemoved(false)
            Self.debugLog("Remove-ads transaction is revoked for id=\(transaction.productID).")
            return false
        }
        setAdsRemoved(true)
        return true
    }

    private func setAdsRemoved(_ value: Bool) {
        guard isAdsRemoved != value else { return }
        isAdsRemoved = value
        defaults.set(value, forKey: Self.adsRemovedDefaultsKey)
    }

    private static func debugDescription(for error: Error) -> String {
        let nsError = error as NSError
        return "\(type(of: error))(domain=\(nsError.domain), code=\(nsError.code), description=\(nsError.localizedDescription))"
    }

    private static func debugSummary(for product: Product) -> String {
        "id=\(product.id), displayName=\(product.displayName), type=\(product.type), price=\(product.displayPrice)"
    }

    private static func debugLog(_ message: @autoclosure () -> String) {
#if DEBUG
        print("[RemoveAdsPurchase] \(message())")
#endif
    }
}
