import SwiftUI
import SwiftData

struct GTGSettingsView: View {

    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var context
    @State private var showSchedulingError: String?

    private var profile: UserProfile? { profiles.first }
    private let scheduler: GTGSchedulerProtocol = GTGSchedulerService()

    var body: some View {
        Form {
            Section {
                if let profile {
                    Toggle("GTG 모드 켜기", isOn: Binding(
                        get: { profile.gtgEnabled },
                        set: { newValue in
                            profile.gtgEnabled = newValue
                            try? context.save()
                            Task { await syncSchedule() }
                        }
                    ))
                }
            } header: {
                Text("Grease the Groove")
            } footer: {
                Text("하루 동안 가볍게 분산해서 운동하면 신경계가 적응하면서 최대 반복 능력이 빠르게 성장합니다. 절대 한계까지 가지 마세요. 매 알림마다 50% 강도(RPE 5)면 충분합니다.")
            }

            if let profile, profile.gtgEnabled {
                Section("운동") {
                    Picker("종목", selection: Binding(
                        get: { ExerciseKind(rawValue: profile.preferredGTGExercise) ?? .pushUp },
                        set: { profile.preferredGTGExercise = $0.rawValue; try? context.save(); Task { await syncSchedule() } }
                    )) {
                        ForEach(ExerciseKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                }

                Section("일일 목표") {
                    Stepper("하루 \(profile.gtgDailyTarget)개", value: Binding(
                        get: { profile.gtgDailyTarget },
                        set: { profile.gtgDailyTarget = $0; try? context.save(); Task { await syncSchedule() } }
                    ), in: 10...500, step: 10)
                    Stepper("알림 \(profile.gtgPromptCount)회", value: Binding(
                        get: { profile.gtgPromptCount },
                        set: { profile.gtgPromptCount = $0; try? context.save(); Task { await syncSchedule() } }
                    ), in: 2...20)
                }

                Section("시간대") {
                    Stepper("시작 \(profile.gtgStartHour)시", value: Binding(
                        get: { profile.gtgStartHour },
                        set: { profile.gtgStartHour = $0; try? context.save(); Task { await syncSchedule() } }
                    ), in: 0...22)
                    Stepper("종료 \(profile.gtgEndHour)시", value: Binding(
                        get: { profile.gtgEndHour },
                        set: { profile.gtgEndHour = $0; try? context.save(); Task { await syncSchedule() } }
                    ), in: 1...23)
                }
            }

            if let err = showSchedulingError {
                Section {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("GTG 설정")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func syncSchedule() async {
        guard let profile else { return }
        do {
            try await scheduler.scheduleToday(profile: profile)
            showSchedulingError = nil
        } catch {
            showSchedulingError = error.localizedDescription
        }
    }
}
