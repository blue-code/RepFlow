import SwiftUI
import SwiftData

@main
struct RepFlowApp: App {

    init() {
        PhoneSessionService.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(PersistenceService.shared)
                .tint(Color("AccentColor"))
        }
    }
}
