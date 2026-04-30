import SwiftUI

@main
struct RepFlowWatchApp: App {
    @State private var coordinator = WatchCoordinator()

    init() {
        WatchSessionService.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootWatchView()
                .environment(coordinator)
        }
    }
}
