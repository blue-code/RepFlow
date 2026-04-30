import SwiftUI
import SwiftData

struct SettingsView: View {

    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var context

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            Form {
                Section("프로필") {
                    if let profile {
                        TextField("이름", text: Binding(
                            get: { profile.displayName },
                            set: { profile.displayName = $0; try? context.save() }
                        ))
                        Stepper("푸시업 베스트: \(profile.pushUpBest)", value: Binding(
                            get: { profile.pushUpBest },
                            set: { profile.pushUpBest = $0; try? context.save() }
                        ), in: 0...500)
                        Stepper("풀업 베스트: \(profile.pullUpBest)", value: Binding(
                            get: { profile.pullUpBest },
                            set: { profile.pullUpBest = $0; try? context.save() }
                        ), in: 0...100)
                    }
                }

                Section("GTG") {
                    NavigationLink("GTG 설정") { GTGSettingsView() }
                }

                Section("환경설정") {
                    if let profile {
                        Toggle("햅틱", isOn: Binding(
                            get: { profile.hapticEnabled },
                            set: { profile.hapticEnabled = $0; try? context.save() }
                        ))
                        Toggle("알림 사운드", isOn: Binding(
                            get: { profile.notificationSoundEnabled },
                            set: { profile.notificationSoundEnabled = $0; try? context.save() }
                        ))
                    }
                }

                Section {
                    Link(destination: URL(string: "https://github.com/digimaru/RepFlow")!) {
                        Label("오픈소스 / 피드백", systemImage: "globe")
                    }
                } footer: {
                    Text("RepFlow v1.0.0 — 워치가 하루 종일 너의 코치")
                }
            }
            .navigationTitle("설정")
        }
    }
}
