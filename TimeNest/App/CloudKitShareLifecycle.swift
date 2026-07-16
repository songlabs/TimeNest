import CloudKit
import UIKit

enum CalendarSharingAcceptanceProcessingResult: Equatable {
    case completed
    case retryLater
    case discarded
}

enum CalendarSharingMetadataSource: String {
    case scene
    case app
}

@MainActor
final class CalendarSharingAcceptanceCoordinator {
    typealias Handler = (
        any CalendarSharingShareMetadata
    ) async -> CalendarSharingAcceptanceProcessingResult

    private struct PendingAcceptance {
        let identifier: String
        let metadata: any CalendarSharingShareMetadata
    }

    private var pending: [PendingAcceptance] = []
    private var queuedIdentifiers: Set<String> = []
    private var finalizedIdentifiers: Set<String> = []
    private var handler: Handler?
    private var isProcessing = false

    var pendingCount: Int { pending.count }

    func register(handler: @escaping Handler) {
        self.handler = handler
        processIfPossible()
    }

    func receive(
        _ metadata: any CalendarSharingShareMetadata,
        identifier: String
    ) {
        guard !queuedIdentifiers.contains(identifier),
              !finalizedIdentifiers.contains(identifier) else {
            CalendarSharingDiagnostics.debug(
                operation: "acceptShare",
                stage: "metadata-duplicate",
                database: "shared",
                details: "metadataHash=\(identifier)"
            )
            return
        }
        pending.append(PendingAcceptance(identifier: identifier, metadata: metadata))
        queuedIdentifiers.insert(identifier)
        CalendarSharingDiagnostics.debug(
            operation: "acceptShare",
            stage: "queued",
            database: "shared",
            details: "metadataHash=\(identifier) pendingCount=\(pending.count)"
        )
        processIfPossible()
    }

    func retryPending() {
        processIfPossible()
    }

    func waitUntilIdle() async {
        while isProcessing {
            await Task.yield()
        }
    }

    private func processIfPossible() {
        guard !isProcessing, handler != nil, !pending.isEmpty else { return }
        isProcessing = true
        Task { await drain() }
    }

    private func drain() async {
        defer { isProcessing = false }
        guard let handler else { return }

        while let current = pending.first {
            let result = await handler(current.metadata)
            switch result {
            case .completed, .discarded:
                pending.removeFirst()
                queuedIdentifiers.remove(current.identifier)
                finalizedIdentifiers.insert(current.identifier)
            case .retryLater:
                return
            }
        }
    }
}

@MainActor
final class CalendarSharingInvitationRouter {
    static let shared = CalendarSharingInvitationRouter()

    private let coordinator = CalendarSharingAcceptanceCoordinator()

    private init() {}

    func register(store: CalendarSharingStore) {
        CalendarSharingDiagnostics.debug(
            operation: "acceptShare",
            stage: "store-ready",
            database: "shared",
            details: "pendingCount=\(coordinator.pendingCount)"
        )
        coordinator.register { [weak store] metadata in
            guard let store else { return .retryLater }
            return await store.accept(metadata: metadata)
        }
    }

    func receive(
        _ metadata: CKShare.Metadata,
        source: CalendarSharingMetadataSource
    ) {
        let metadataHash = CalendarSharingDiagnostics.metadataHash(metadata)
        let configuredContainerIdentifier = CKContainer.default().containerIdentifier
        let containerIdentifierMatched = metadata.containerIdentifier == configuredContainerIdentifier
        let rootHash = metadata.hierarchicalRootRecordID.map(
            CalendarSharingDiagnostics.recordHash
        ) ?? "zone-wide"
        CalendarSharingDiagnostics.debug(
            operation: "acceptShare",
            stage: "metadata-received",
            database: "shared",
            details: "source=\(source.rawValue) metadataHash=\(metadataHash) "
                + "containerHash=\(CalendarSharingDiagnostics.identifierHash(metadata.containerIdentifier)) "
                + "containerIdentifierMatched=\(containerIdentifierMatched) "
                + "rootHash=\(rootHash) "
                + "shareHash=\(CalendarSharingDiagnostics.recordHash(metadata.share.recordID))"
        )
        coordinator.receive(metadata, identifier: metadataHash)
    }

    func retryPending() {
        coordinator.retryPending()
    }
}

@MainActor
final class TimeNestSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let metadata = connectionOptions.cloudKitShareMetadata else { return }
        CalendarSharingInvitationRouter.shared.receive(metadata, source: .scene)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        CalendarSharingInvitationRouter.shared.receive(cloudKitShareMetadata, source: .scene)
    }
}

@MainActor
final class TimeNestAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let bundleHash = CalendarSharingDiagnostics.identifierHash(
            Bundle.main.bundleIdentifier ?? "unavailable"
        )
        let containerHash = CKContainer.default().containerIdentifier.map(
            CalendarSharingDiagnostics.identifierHash
        ) ?? "unavailable"
        let ckSharingSupported = Bundle.main.object(
            forInfoDictionaryKey: "CKSharingSupported"
        ) as? Bool ?? false
#if DEBUG
        let environment = "development"
#else
        let environment = "production"
#endif
        CalendarSharingDiagnostics.debug(
            operation: "cloudConfiguration",
            stage: "startup",
            database: "configuration",
            details: "bundleHash=\(bundleHash) containerHash=\(containerHash) "
                + "environment=\(environment) environmentSource=buildConfiguration "
                + "ckSharingSupported=\(ckSharingSupported) "
                + "acceptHandlerRegistered=true "
                + "systemRegistrationComplete=\(ckSharingSupported)"
        )
        if !ckSharingSupported {
            CalendarSharingDiagnostics.error(
                operation: "cloudConfiguration",
                stage: "invalid-configuration",
                database: "configuration",
                error: CloudSharingSystemRegistrationError.ckSharingUnsupported,
                details: "ckSharingSupported=false systemRegistrationComplete=false"
            )
        }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        Self.sceneConfiguration(for: connectingSceneSession.role)
    }

    static func sceneConfiguration(
        for role: UISceneSession.Role
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: role
        )
        if role == .windowApplication {
            configuration.delegateClass = TimeNestSceneDelegate.self
        }
        return configuration
    }

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        CalendarSharingInvitationRouter.shared.receive(cloudKitShareMetadata, source: .app)
    }
}

private enum CloudSharingSystemRegistrationError: Error {
    case ckSharingUnsupported
}
