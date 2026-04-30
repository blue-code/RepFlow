import SwiftUI
import SwiftData

struct GTGSettingsView: View {

    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var context
    @State private var showSchedulingError: String?
    @State private var showPaywall = false
    @State private var pro = ProManager.shared

    private var profile: UserProfile? { profiles.first }
    private let scheduler: GTGSchedulerProtocol = GTGSchedulerService()

    var body: some View {
        ZStack {
            RFColor.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: RFSpace.xl) {
                    aboutCard

                    masterToggleSection

                    if profile?.gtgEnabled == true {
                        configSection
                    }

                    if let err = showSchedulingError {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .font(.rfCaption)
                            .foregroundStyle(RFColor.warning)
                            .padding(RFSpace.md)
                            .background(RFColor.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: RFRadius.md))
                    }
                }
                .padding(.horizontal, RFSpace.lg)
                .padding(.vertical, RFSpace.lg)
            }
        }
        .navigationTitle("GTG 설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .task { await pro.loadProducts() }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: RFSpace.sm) {
            HStack {
                Image(systemName: "bolt.heart.fill").foregroundStyle(RFColor.accent)
                Text("Grease the Groove").font(.rfTitleMd).foregroundStyle(RFColor.fg)
            }
            Text("하루 동안 가볍게 분산해서 운동하면 신경계가 적응하면서 최대 반복 능력이 빠르게 성장합니다. 절대 한계까지 가지 마세요. 매 알림마다 50% 강도(RPE 5)면 충분합니다.")
                .font(.rfCaption)
                .foregroundStyle(RFColor.fgMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rfCard()
    }

    @ViewBuilder
    private var masterToggleSection: some View {
        if let profile {
            VStack(alignment: .leading, spacing: RFSpace.sm) {
                Text("MODE").rfSectionHeader()
                HStack {
                    Text("GTG 모드")
                        .font(.rfBody)
                        .foregroundStyle(RFColor.fg)
                    if !pro.isPro {
                        Text("Pro").rfChip()
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { profile.gtgEnabled },
                        set: { newValue in
                            if newValue && !pro.isPro {
                                showPaywall = true
                                return
                            }
                            profile.gtgEnabled = newValue
                            try? context.save()
                            Task { await syncSchedule() }
                        }
                    ))
                    .labelsHidden()
                    .tint(RFColor.accent)
                }
                .padding(RFSpace.md)
                .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
                .overlay(RoundedRectangle(cornerRadius: RFRadius.md).stroke(RFColor.border, lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private var configSection: some View {
        if let profile {
            VStack(spacing: RFSpace.lg) {
                groupBlock(title: "EXERCISE") {
                    HStack {
                        Text("종목").font(.rfBody).foregroundStyle(RFColor.fg)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { ExerciseKind(rawValue: profile.preferredGTGExercise) ?? .pushUp },
                            set: { profile.preferredGTGExercise = $0.rawValue; try? context.save(); Task { await syncSchedule() } }
                        )) {
                            ForEach(ExerciseKind.allCases) { kind in
                                Text(kind.displayName).tag(kind)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(RFColor.accent)
                    }
                    .padding(RFSpace.md)
                }

                groupBlock(title: "DAILY TARGET") {
                    VStack(spacing: 1) {
                        stepperRow("일일 목표", value: profile.gtgDailyTarget, suffix: "개", range: 10...500, step: 10) {
                            profile.gtgDailyTarget = $0; try? context.save(); Task { await syncSchedule() }
                        }
                        stepperRow("알림 횟수", value: profile.gtgPromptCount, suffix: "회", range: 2...20, step: 1) {
                            profile.gtgPromptCount = $0; try? context.save(); Task { await syncSchedule() }
                        }
                    }
                }

                groupBlock(title: "WINDOW") {
                    VStack(spacing: 1) {
                        stepperRow("시작", value: profile.gtgStartHour, suffix: "시", range: 0...22, step: 1) {
                            profile.gtgStartHour = $0; try? context.save(); Task { await syncSchedule() }
                        }
                        stepperRow("종료", value: profile.gtgEndHour, suffix: "시", range: 1...23, step: 1) {
                            profile.gtgEndHour = $0; try? context.save(); Task { await syncSchedule() }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func groupBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: RFSpace.sm) {
            Text(title).rfSectionHeader()
            content()
                .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
                .overlay(RoundedRectangle(cornerRadius: RFRadius.md).stroke(RFColor.border, lineWidth: 1))
        }
    }

    private func stepperRow(_ label: String, value: Int, suffix: String, range: ClosedRange<Int>, step: Int, onChange: @escaping (Int) -> Void) -> some View {
        Stepper(value: Binding(get: { value }, set: onChange), in: range, step: step) {
            HStack {
                Text(label).font(.rfBody).foregroundStyle(RFColor.fg)
                Spacer()
                Text("\(value)\(suffix)").font(.rfMonoBody).foregroundStyle(RFColor.fgMuted)
            }
        }
        .padding(RFSpace.md)
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
