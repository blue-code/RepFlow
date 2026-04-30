import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var context

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 14/255, alpha: 1)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.08)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 14/255, alpha: 1)
        nav.shadowColor = .clear
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }

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
        .tint(RFColor.accent)
        .preferredColorScheme(.dark)
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
