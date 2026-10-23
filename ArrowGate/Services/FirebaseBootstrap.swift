import FirebaseAppCheck
import FirebaseCore
import Foundation

enum FirebaseBootstrap {
    private(set) static var isConfigured = false

    /// Campaign content is remote-only. Without a valid Firebase configuration,
    /// the root view keeps the player on the recoverable content-loading screen.
    @MainActor
    @discardableResult
    static func configureIfAvailable(bundle: Bundle = .main) -> Bool {
        #if DEBUG
        // This switch is kept only for exercising the first-launch offline UI.
        let process = ProcessInfo.processInfo
        if process.environment["PICTARROW_LOCAL_ONLY"] == "1"
            || process.environment["PICTARROW_CONTENT_PREVIEW"] == "1" {
            return false
        }
        #endif
        guard !isConfigured else { return true }
        guard let path = bundle.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path) else {
            return false
        }

        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
        #endif

        FirebaseApp.configure(options: options)
        AppCheck.appCheck().isTokenAutoRefreshEnabled = true
        isConfigured = true
        return true
    }
}

private final class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        AppAttestProvider(app: app)
    }
}
