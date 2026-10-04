import SwiftUI

@main
struct MojiApp: App {
    init() {
        MojiEngineRuntime.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ThemeRootBoundary {
                RootView()
            }
        }
    }
}
