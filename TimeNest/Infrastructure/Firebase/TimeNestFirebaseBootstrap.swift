import FirebaseAppCheck
import FirebaseCore
import Foundation

final class TimeNestAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        AppAttestProvider(app: app)
    }
}

enum TimeNestFirebaseBootstrap {
    @discardableResult
    static func configureIfAvailable(bundle: Bundle = .main) -> Bool {
        guard FirebaseApp.app() == nil else { return true }
        guard let path = bundle.path(
            forResource: "GoogleService-Info",
            ofType: "plist"
        ), let options = FirebaseOptions(contentsOfFile: path) else {
            return false
        }

        #if DEBUG && targetEnvironment(simulator)
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(TimeNestAppCheckProviderFactory())
        #endif
        FirebaseApp.configure(options: options)
        return true
    }
}
