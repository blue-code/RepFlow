import SwiftUI
import SwiftData

/// 프로그램 세션 한 번을 진행한다.
///
/// 상태는 전부 `ProgramSessionRunner`(Shared)에 있다 — 워치도 같은 것을 쓴다.
/// 이 뷰는 그리고, 탭을 `addRep()` 으로 흘려보내고, 끝나면 저장할 뿐이다.
/// M5·M6에서 카메라·근접센서·음성이 붙어도 이 뷰의 구조는 그대로다.
struct ProgramSessionView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let enrollment: ProgramEnrollment
    @State private var runner: ProgramSessionRunner
    @State private var adjustment: ProgramAdjustment?
    @State private var showAbandonConfirm = false

    /// 휴식 잔여를 갱신하기 위한 심박. 상태는 runner가 시계로 계산하므로 여기선 깨우기만 한다.
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    init(enrollment: ProgramEnrollment, session: ProgramSession) {
        self.enrollment = enrollment
        _runner = State(initialValue: ProgramSessionRunner(
            session: session,
            restBonusSeconds: enrollment.restBonusSeconds
        ))
    }

    var body: some View {
        ZStack {
            RFColor.bg.ignoresSafeArea()
            VStack(spacing: RFSpace.lg) {
                progressHeader
                Spacer(minLength: 0)
                phaseBody
                Spacer(minLength: 0)
                controls
            }
            .padding(.horizontal, RFSpace.lg)
            .padding(.vertical, RFSpace.xl)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        // 운동 중에는 탭바를 치운다 — 실수로 다른 탭을 누르면 세션이 날아간다.
        .toolbar(.hidden, for: .tabBar)
        .onReceive(tick) { _ in runner.tick() }
        .onAppear { runner.start() }
        .confirmationDialog("세션을 그만둘까요?", isPresented: $showAbandonConfirm) {
            Button("그만두기", role: .destructive) {
                runner.abandon()
                save()
            }
            Button("계속하기", role: .cancel) {}
        } message: {
            Text("여기까지 한 세트는 기록에 남습니다.")
        }
    }

    private var title: String {
        runner.session.isRetest
            ? "재측정"
            : "\(enrollment.currentWeek)주차 · \(runner.session.kind.displayName)"
    }

    // MARK: - 조각

    private var progressHeader: some View {
        HStack(spacing: RFSpace.xs) {
            ForEach(runner.session.sets.indices, id: \.self) { index in
                Capsule()
                    .fill(fillColor(forSet: index))
                    .frame(height: 4)
            }
        }
    }

    private func fillColor(forSet index: Int) -> Color {
        if index < runner.completedReps.count { return RFColor.success }
        if index == runner.currentSetIndex { return RFColor.accent }
        return RFColor.border
    }

    @ViewBuilder
    private var phaseBody: some View {
        switch runner.phase {
        case .resting:
            restingBody
        case .finished, .abandoned:
            summaryBody
        case .ready, .working:
            workingBody
        }
    }

    private var workingBody: some View {
        VStack(spacing: RFSpace.md) {
            Text(setLabel)
                .rfSectionHeader()

            Text("\(runner.currentReps)")
                .font(.system(size: 120, weight: .heavy))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(runner.hasMetCurrentTarget ? RFColor.success : RFColor.fg)

            Text(targetLabel)
                .font(.rfCaption)
                .foregroundStyle(RFColor.fgMuted)

            if runner.currentReps == 0 {
                Text("화면 탭 = +1")
                    .font(.rfCaptionSm)
                    .foregroundStyle(RFColor.fgSubtle)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .contentShape(Rectangle())
        .onTapGesture { runner.addRep() }
        .rfCard()
    }

    private var setLabel: String {
        guard let index = runner.currentSetIndex else { return "" }
        return "\(index + 1) / \(runner.session.sets.count) 세트"
    }

    private var targetLabel: String {
        guard let target = runner.currentTarget else { return "" }
        // AMRAP 세트는 상한이 없다. 목표를 채웠다고 멈추라고 하면 안 된다.
        return target.isAMRAP ? "최소 \(target.reps)개 — 가능한 만큼" : "목표 \(target.reps)개"
    }

    private var restingBody: some View {
        VStack(spacing: RFSpace.md) {
            Text("휴식")
                .rfSectionHeader()
            Text(restText)
                .font(.system(size: 88, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(RFColor.accent)
            Text("다음: \(nextSetLabel)")
                .font(.rfCaption)
                .foregroundStyle(RFColor.fgMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .rfCard()
    }

    private var restText: String {
        let remaining = Int(runner.remainingRest.rounded(.up))
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    private var nextSetLabel: String {
        guard case .resting(let afterSetIndex, _) = runner.phase,
              afterSetIndex + 1 < runner.session.sets.count else { return "-" }
        let next = runner.session.sets[afterSetIndex + 1]
        return next.isAMRAP ? "마지막 세트 (최소 \(next.reps)개)" : "\(next.reps)개"
    }

    private var summaryBody: some View {
        VStack(spacing: RFSpace.md) {
            Text(runner.phase == .abandoned ? "중단함" : "세션 완료")
                .font(.rfTitleLg)
                .foregroundStyle(runner.phase == .abandoned ? RFColor.warning : RFColor.success)

            Text("\(runner.totalReps)")
                .font(.system(size: 96, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(RFColor.fg)
            Text("총 횟수")
                .font(.rfCaption)
                .foregroundStyle(RFColor.fgMuted)

            if let adjustment {
                Text(adjustmentText(adjustment))
                    .rfChip(adjustmentColor(adjustment))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .rfCard()
    }

    private func adjustmentText(_ adjustment: ProgramAdjustment) -> String {
        switch adjustment {
        case .increase(let to): return "한 주 완료 — 훈련최대 \(to)개로 상향"
        case .decrease(let to): return "2주 연속 미달 — 훈련최대 \(to)개로 조정"
        case .hold:             return "한 주 완료 — 훈련최대 유지"
        }
    }

    private func adjustmentColor(_ adjustment: ProgramAdjustment) -> Color {
        switch adjustment {
        case .increase: return RFColor.success
        case .decrease: return RFColor.warning
        case .hold:     return RFColor.fgMuted
        }
    }

    // MARK: - 조작

    @ViewBuilder
    private var controls: some View {
        switch runner.phase {
        case .working:
            VStack(spacing: RFSpace.sm) {
                Button("세트 완료") { runner.completeSet() }
                    .buttonStyle(RFPrimaryButton())
                    .disabled(runner.currentReps == 0)
                HStack(spacing: RFSpace.sm) {
                    Button { runner.undoRep() } label: {
                        Label("취소", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(RFSecondaryButton())
                    .disabled(runner.currentReps == 0)

                    Button("그만두기") { showAbandonConfirm = true }
                        .buttonStyle(RFSecondaryButton())
                }
            }

        case .resting:
            Button("휴식 건너뛰기") { runner.skipRest() }
                .buttonStyle(RFSecondaryButton())

        case .finished, .abandoned:
            Button("완료") { dismiss() }
                .buttonStyle(RFPrimaryButton())
                .onAppear { save() }

        case .ready:
            EmptyView()
        }
    }

    /// 한 번만 저장한다 — `.onAppear` 는 여러 번 불릴 수 있다.
    @State private var didSave = false

    private func save() {
        guard !didSave, let result = runner.result else { return }
        didSave = true

        adjustment = enrollment.record(result)

        let ingest = WorkoutIngestService(context: context)
        try? ingest.ingest(WatchPayload.WorkoutReport(
            exercise: .pushUp,
            mode: .sets,
            totalReps: runner.totalReps,
            durationSec: 0,
            avgTempo: 0,
            endedAt: .now
        ))
        try? context.save()
    }
}

extension SessionKind {
    var displayName: String {
        switch self {
        case .volume:    return "볼륨"
        case .intensity: return "강도"
        case .density:   return "밀도"
        }
    }
}
