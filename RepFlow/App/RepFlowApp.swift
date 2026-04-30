import SwiftUI
import SwiftData

@main
struct RepFlowApp: App {

    @AppStorage("hasFinishedOnboarding") private var hasFinishedOnboarding = false

    init() {
        PhoneSessionService.shared.activate()
        if MockDataLoader.shouldSkipOnboarding {
            UserDefaults.standard.set(true, forKey: "hasFinishedOnboarding")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasFinishedOnboarding || MockDataLoader.shouldSkipOnboarding {
                    RootView()
                } else {
                    OnboardingView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: hasFinishedOnboarding)
            .modelContainer(PersistenceService.shared)
            .tint(Color("AccentColor"))
            .task {
                MockDataLoader.inject(into: PersistenceService.shared.mainContext)
            }
        }
    }
}
