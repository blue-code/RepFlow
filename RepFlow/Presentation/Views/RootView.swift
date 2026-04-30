import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("홈", systemImage: "house.fill") }

            ProgramsView()
                .tabItem { Label("프로그램", systemImage: "list.bullet.rectangle.portrait") }

            HistoryView()
                .tabItem { Label("기록", systemImage: "chart.line.uptrend.xyaxis") }

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape.fill") }
        }
        .task {
            ensureProfile()
        }
    }

    private func ensureProfile() {
        if profiles.isEmpty {
            context.insert(UserProfile())
            try? context.save()
        }
    }
}
