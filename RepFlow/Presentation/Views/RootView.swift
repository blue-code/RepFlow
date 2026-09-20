import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var context
    /// 스크린샷 자동화에서 특정 탭으로 바로 열기 위한 선택 상태.
    @State private var selectedTab: Int = MockDataLoader.initialTab ?? 0

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
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("홈", systemImage: "house.fill") }
                .tag(0)

            ProgramsView()
                .tabItem { Label("푸시업 100", systemImage: "target") }
                .tag(1)

            HistoryView()
                .tabItem { Label("기록", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(2)

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape.fill") }
                .tag(3)
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
