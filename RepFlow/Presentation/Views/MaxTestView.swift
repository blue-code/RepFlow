import SwiftUI
import SwiftData

/// 최대 측정 — 프로그램의 유일한 입구.
///
/// 폼을 유지한 채 한 세트 AMRAP. 이 숫자가 훈련최대 `W` 가 되고 모든 세트 목표가 여기서 나온다.
struct MaxTestView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var enrollments: [ProgramEnrollment]
    @Query private var profiles: [UserProfile]

    /// 재측정이면 기존 등록을 갱신한다.
    var isRetest: Bool = false

    @State private var reps: Int = 0
    @State private var isCounting = false

    private var level: PushUpLevel { PushUpLevel.forMax(reps) }

    var body: some View {
        ZStack {
            RFColor.bg.ignoresSafeArea()
            VStack(spacing: RFSpace.xl) {
                header
                counter
                Spacer()
                footer
            }
            .padding(.horizontal, RFSpace.lg)
            .padding(.vertical, RFSpace.xl)
        }
        .navigationTitle(isRetest ? "재측정" : "최대 측정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        // 운동 중에는 탭바를 치운다 — 실수로 다른 탭을 누르면 세션이 날아간다.
        .toolbar(.hidden, for: .tabBar)
    }

    private var header: some View {
        VStack(spacing: RFSpace.sm) {
            Text(isCounting ? "화면을 탭할 때마다 1개" : "폼이 무너지기 직전까지, 한 세트")
                .font(.rfTitleMd)
                .foregroundStyle(RFColor.fg)
            Text(isCounting
                 ? "끝나면 아래 '측정 완료'"
                 : "반동 없이 가슴이 주먹 높이까지. 여기서 나온 숫자가 앞으로 모든 세트의 기준이 된다.")
                .font(.rfCaption)
                .foregroundStyle(RFColor.fgMuted)
                .multilineTextAlignment(.center)
        }
    }

    /// 화면 어디를 눌러도 +1. 푸시업 중에 작은 버튼을 겨냥할 수는 없다.
    private var counter: some View {
        VStack(spacing: RFSpace.md) {
            Text("\(reps)")
                .font(.system(size: 108, weight: .heavy))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(reps > 0 ? RFColor.accent : RFColor.fgSubtle)

            if reps > 0 {
                Text("레벨 \(level.rawValue) · 목표 100까지 \(max(0, ProgramLadder.goal - reps))개")
                    .rfChip()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isCounting else { return }
            reps += 1
        }
        .rfCard()
    }

    private var footer: some View {
        VStack(spacing: RFSpace.md) {
            if isCounting {
                Button("측정 완료") { finish() }
                    .buttonStyle(RFPrimaryButton())
                    .disabled(reps == 0)

                Button {
                    reps = max(0, reps - 1)
                } label: {
                    Label("한 개 취소", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(RFSecondaryButton())
                .disabled(reps == 0)
            } else {
                Button("시작") { isCounting = true }
                    .buttonStyle(RFPrimaryButton())
            }
        }
    }

    private func finish() {
        guard reps > 0 else { return }

        if let existing = enrollments.first {
            if existing.isRetestWeek, let session = existing.nextSession {
                // 재측정 주의 측정은 그 주의 "세션"이다. 주차 진행은 `record` 한 곳에서만
                // 일어나야 한다 — 여기서 currentWeek를 직접 올리면 워치로 같은 세션을
                // 했을 때 주차가 두 번 넘어간다.
                existing.record(SessionResult(
                    kind: session.kind,
                    targets: session.sets.map(\.reps),
                    achieved: [reps]
                ))
            } else {
                // 주기와 무관한 수동 재측정. 훈련최대만 다시 잡고 주차는 건드리지 않는다.
                existing.trainingMax = reps
                existing.trainingMaxHistory.append(reps)
                existing.completedSessionsThisWeek = []
                existing.consecutiveMissedWeeks = 0
                existing.bestSingleSet = max(existing.bestSingleSet, reps)
            }
        } else {
            context.insert(ProgramEnrollment(trainingMax: reps))
        }

        // 최대 측정도 한 세트 기록이다. 개인최고와 운동 기록에 남긴다.
        let ingest = WorkoutIngestService(context: context)
        try? ingest.ingest(WatchPayload.WorkoutReport(
            exercise: .pushUp, mode: .freeCount,
            totalReps: reps, durationSec: 0, avgTempo: 0, endedAt: .now
        ))
        try? context.save()
        pushSessionToWatch()
        dismiss()
    }

    /// 측정 직후 워치의 다음 세션도 갱신한다. 허브로 돌아가지 않고 바로 워치를 드는 경우가 있다.
    private func pushSessionToWatch() {
        guard let enrollment = enrollments.first else { return }
        PhoneSessionService.shared.sendProgramSession(
            enrollment.nextSession,
            restBonusSeconds: enrollment.restBonusSeconds
        )
    }
}
