import SwiftUI
import Combine

@main
@MainActor
struct ArrowGateApp: App {
    @StateObject private var state: AppState

    init() {
        FirebaseBootstrap.configureIfAvailable()
        _state = StateObject(wrappedValue: AppState())
    }

    var body: some Scene { WindowGroup { RootView().environmentObject(state).preferredColorScheme(.light) } }
}
