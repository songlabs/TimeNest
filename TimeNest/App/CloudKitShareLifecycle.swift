import CloudKit
import UIKit

@MainActor
final class CalendarSharingInvitationRouter {
    static let shared = CalendarSharingInvitationRouter()

    private weak var store: CalendarSharingStore?
    private var pendingMetadata: CKShare.Metadata?

    private init() {}

    func register(store: CalendarSharingStore) {
        self.store = store
        guard let pendingMetadata else { return }
        self.pendingMetadata = nil
        Task {
            await store.accept(metadata: pendingMetadata)
        }
    }

    func receive(_ metadata: CKShare.Metadata) {
        guard let store else {
            pendingMetadata = metadata
            return
        }
        Task {
            await store.accept(metadata: metadata)
        }
    }
}

final class TimeNestSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            CalendarSharingInvitationRouter.shared.receive(cloudKitShareMetadata)
        }
    }
}

final class TimeNestAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = TimeNestSceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            CalendarSharingInvitationRouter.shared.receive(cloudKitShareMetadata)
        }
    }
}
