import SwiftUI
import SwiftData

@main
struct RepFlowApp: App {

    @AppStorage("hasFinishedOnboarding") private var hasFinishedOnboarding = false

    init() {
        PhoneSessionService.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasFinishedOnboarding {
                    RootView()
                } else {
                    OnboardingView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: hasFinishedOnboarding)
            .modelContainer(PersistenceService.shared)
            .tint(Color("AccentColor"))
        }
    }
}
