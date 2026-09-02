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
    case manualURL
}

enum CalendarSharingManualInvitationResult: Equatable {
    case accepted
    case alreadyAccepted
}

enum CalendarSharingInvitationURLValidator {
    private static let supportedHosts: Set<String> = ["www.icloud.com"]

    static func validatedURL(from rawValue: String) throws -> URL {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CalendarSharingError.invitationURLInputEmpty
        }
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme,
              let host = components.host,
              let url = components.url else {
            throw CalendarSharingError.invitationURLInvalid
        }
        guard scheme.lowercased() == "https",
              components.user == nil,
              components.password == nil else {
            throw CalendarSharingError.invitationURLInvalid
        }
        guard supportedHosts.contains(host.lowercased()) else {
            throw CalendarSharingError.notCloudKitShare
        }
        let pathComponents = components.percentEncodedPath.split(separator: "/")
        guard pathComponents.count >= 2, pathComponents.first == "share" else {
            throw CalendarSharingError.notCloudKitShare
        }
        return url
    }

    static func validate(_ url: URL) throws {
        _ = try validatedURL(from: url.absoluteString)
    }
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

    struct AwaitedResult: Equatable {
        let wasAlreadyQueued: Bool
        let processingResult: CalendarSharingAcceptanceProcessingResult
    }

    private var pending: [PendingAcceptance] = []
    private var queuedIdentifiers: Set<String> = []
    private var finalizedIdentifiers: Set<String> = []
    private var finalizedResults: [String: CalendarSharingAcceptanceProcessingResult] = [:]
    private var completionWaiters: [
        String: [CheckedContinuation<CalendarSharingAcceptanceProcessingResult, Never>]
    ] = [:]
    private var handler: Handler?
    private var isProcessing = false

    var pendingCount: Int { pending.count }

    func register(handler: @escaping Handler) {
        self.handler = handler
        processIfPossible()
    }

    @discardableResult
    func receive(
        _ metadata: any CalendarSharingShareMetadata,
        identifier: String
    ) -> Bool {
        guard !queuedIdentifiers.contains(identifier),
              !finalizedIdentifiers.contains(identifier) else {
            CalendarSharingDiagnostics.debug(
                operation: "acceptShare",
                stage: "metadata-duplicate",
                database: "shared",
                details: "metadataHash=\(identifier)"
            )
            processIfPossible()
            return false
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
        return true
    }

    func receiveAndWait(
        _ metadata: any CalendarSharingShareMetadata,
        identifier: String
    ) async -> AwaitedResult {
        let wasEnqueued = receive(metadata, identifier: identifier)
        if let finalizedResult = finalizedResults[identifier] {
            return AwaitedResult(
                wasAlreadyQueued: true,
                processingResult: finalizedResult
            )
        }
        let processingResult = await withCheckedContinuation { continuation in
            completionWaiters[identifier, default: []].append(continuation)
            processIfPossible()
        }
        return AwaitedResult(
            wasAlreadyQueued: !wasEnqueued,
            processingResult: processingResult
        )
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
                finalizedResults[current.identifier] = result
                resumeWaiters(for: current.identifier, with: result)
            case .retryLater:
                resumeWaiters(for: current.identifier, with: result)
                return
            }
        }
    }

    private func resumeWaiters(
        for identifier: String,
        with result: CalendarSharingAcceptanceProcessingResult
    ) {
        let waiters = completionWaiters.removeValue(forKey: identifier) ?? []
        waiters.forEach { $0.resume(returning: result) }
    }
}

@MainActor
final class CalendarSharingInvitationRouter {
    static let shared = CalendarSharingInvitationRouter()

    typealias MetadataFetcher = (
        URL
    ) async throws -> any CalendarSharingShareMetadata

    private let coordinator: CalendarSharingAcceptanceCoordinator
    private let configuredContainerIdentifier: () -> String?
    private var metadataFetcher: MetadataFetcher?
    private var acceptanceErrorProvider: (() -> CalendarSharingError?)?
    private var urlTasks: [
        String: Task<CalendarSharingManualInvitationResult, Error>
    ] = [:]

    init(
        configuredContainerIdentifier: @escaping () -> String? = {
            CKContainer.default().containerIdentifier
        }
    ) {
        coordinator = CalendarSharingAcceptanceCoordinator()
        self.configuredContainerIdentifier = configuredContainerIdentifier
    }

    init(
        coordinator: CalendarSharingAcceptanceCoordinator,
        configuredContainerIdentifier: @escaping () -> String?
    ) {
        self.coordinator = coordinator
        self.configuredContainerIdentifier = configuredContainerIdentifier
    }

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
        metadataFetcher = { [weak store] url in
            guard let store else { throw CalendarSharingError.metadataFetchFailed }
            return try await store.fetchShareMetadata(from: url)
        }
        acceptanceErrorProvider = { [weak store] in
            store?.invitationAcceptanceError
        }
    }

    func receive(
        _ metadata: any CalendarSharingShareMetadata,
        source: CalendarSharingMetadataSource
    ) {
        let metadataHash = CalendarSharingDiagnostics.metadataHash(metadata)
        let configuredContainerIdentifier = CKContainer.default().containerIdentifier
        let containerIdentifierMatched = metadata.containerIdentifier == configuredContainerIdentifier
        let rootHash = (metadata as? CKShare.Metadata)?.hierarchicalRootRecordID.map(
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

    func receive(
        url: URL,
        source: CalendarSharingMetadataSource,
        metadataDidLoad: (() -> Void)? = nil
    ) async throws -> CalendarSharingManualInvitationResult {
        try CalendarSharingInvitationURLValidator.validate(url)
        let urlHash = CalendarSharingDiagnostics.urlHash(url)
        if let task = urlTasks[urlHash] {
            CalendarSharingDiagnostics.debug(
                operation: "fetchShareMetadata",
                stage: "url-duplicate",
                database: "shared",
                details: "source=\(source.rawValue) urlHash=\(urlHash)"
            )
            return try await task.value
        }

        let task = Task { [weak self] in
            guard let self else { throw CalendarSharingError.metadataFetchFailed }
            return try await self.process(
                url: url,
                urlHash: urlHash,
                source: source,
                metadataDidLoad: metadataDidLoad
            )
        }
        urlTasks[urlHash] = task
        defer { urlTasks[urlHash] = nil }
        return try await task.value
    }

    private func process(
        url: URL,
        urlHash: String,
        source: CalendarSharingMetadataSource,
        metadataDidLoad: (() -> Void)?
    ) async throws -> CalendarSharingManualInvitationResult {
        guard let metadataFetcher else {
            throw CalendarSharingError.metadataFetchFailed
        }
        CalendarSharingDiagnostics.debug(
            operation: "fetchShareMetadata",
            stage: "url-received",
            database: "shared",
            details: "source=\(source.rawValue) urlHash=\(urlHash)"
        )
        let metadata = try await metadataFetcher(url)
        do {
            try CalendarSharingContainerValidator.validate(
                metadataContainerIdentifier: metadata.containerIdentifier,
                configuredContainerIdentifier: configuredContainerIdentifier()
            )
        } catch CalendarSharingError.cloudEnvironmentMismatch {
            throw CalendarSharingError.invitationContainerMismatch
        }

        metadataDidLoad?()
        let metadataHash = CalendarSharingDiagnostics.metadataHash(metadata)
        let wasAlreadyAccepted = metadata.participantStatus == .accepted
        let result = await coordinator.receiveAndWait(
            metadata,
            identifier: metadataHash
        )
        switch result.processingResult {
        case .completed:
            return wasAlreadyAccepted || result.wasAlreadyQueued
                ? .alreadyAccepted
                : .accepted
        case .retryLater, .discarded:
            throw acceptanceErrorProvider?() ?? .invitationAcceptanceFailed
        }
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
