import SwiftUI
import Combine

@main
@MainActor
struct ArrowGateApp: App {
    @StateObject private var state = AppState()
    var body: some Scene { WindowGroup { RootView().environmentObject(state).preferredColorScheme(.light) } }
}
