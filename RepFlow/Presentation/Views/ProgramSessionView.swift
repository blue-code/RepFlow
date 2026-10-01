import SwiftUI
import SwiftData
import UIKit

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

    // 카운트 방식. 어느 소스든 결과는 runner.addRep() 하나로 들어간다.
    @AppStorage("repflow.countingMode") private var modeRaw = CountingMode.manual.rawValue
    @State private var camera = CameraRepCounter()
    @State private var proximity = ProximityRepCounter()
    @State private var speech = SpeechCounter()
    @AppStorage("repflow.voiceCount") private var voiceEnabled = true
    @State private var showPlacementGuide = false
    /// 거치 확인은 세션당 한 번이면 된다. 세트마다 다시 시키면 못 쓴다.
    @State private var hasPassedPlacement = false
    @State private var sourceStatus: String?
    @State private var formNotes: [PoseGeometry.FormScore] = []
    @State private var lastSpokenRest = -1
    /// 자동 완료 안내는 세트당 한 번이면 된다.
    @State private var spokeAutoAdvanceHint = false

    /// 목표를 채우고 이만큼 멈춰 있으면 세트를 자동으로 끝낸다 (카메라·근접센서 전용).
    /// 마지막 1회 뒤에 숨을 고르는 시간이 있어야 해서 넉넉히 잡는다.
    private let autoCompleteIdle: TimeInterval = 6

    private var mode: CountingMode { CountingMode(rawValue: modeRaw) ?? .manual }

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
                if case .working = runner.phase { modePicker }
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
        .onReceive(tick) { _ in
            runner.tick()
            speakRestCountdownIfNeeded()
            autoCompleteSetIfIdle()
        }
        .onAppear {
            runner.start()
            speech.isEnabled = voiceEnabled
            speech.activateAudioSession()
            startSource()
        }
        .onDisappear {
            stopSource()
            speech.deactivateAudioSession()
        }
        .onChange(of: runner.phase) { old, new in
            handlePhaseChange(from: old, to: new)
        }
        // 네비게이션 push 가 아니라 전체화면 커버다. 이유 둘:
        // ① 같은 NavigationStack 안에 `navigationDestination(isPresented:)` 가 둘이면
        //    (ProgramsView 의 세션 진입과 여기) 서로 충돌해 아예 안 열린다.
        // ② push 는 부모의 onDisappear 를 부를 수 있어서, 가이드가 막 켠 카메라를 곧바로 끈다.
        .fullScreenCover(isPresented: $showPlacementGuide) {
            NavigationStack {
                PlacementGuideView(counter: camera, speech: speech) { passed in
                    showPlacementGuide = false
                    guard passed else {
                        modeRaw = CountingMode.manual.rawValue   // 포기하면 탭으로 되돌린다
                        return
                    }
                    hasPassedPlacement = true
                    // 캡처는 그대로 두고 카운트만 0부터. 자세를 잡는 동안의 어깨 높이가
                    // 락아웃 기준값으로 굳으면 깊이 신호가 통째로 틀어진다.
                    camera.resetCounting()
                    camera.onRep = { addAutoRep() }
                    camera.onForm = { formNotes.append($0) }
                }
            }
        }
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

    /// 카운트 방식 전환. 세트 중에는 바꾸지 못하게 한다 — 바꾸는 순간 세던 수가 꼬인다.
    private var modePicker: some View {
        VStack(spacing: RFSpace.xs) {
            Picker("카운트 방식", selection: $modeRaw) {
                ForEach(CountingMode.allCases) { m in
                    Label(m.displayName, systemImage: m.symbol).tag(m.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .disabled(runner.currentReps > 0)
            .onChange(of: modeRaw) { _, _ in
                stopSource()
                hasPassedPlacement = false   // 방식을 바꾸면 거치도 다시 확인한다
                startSource()
            }

            Text(sourceStatus ?? mode.hint)
                .font(.rfCaptionSm)
                .foregroundStyle(sourceStatus == nil ? RFColor.fgSubtle : RFColor.warning)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

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

            if runner.currentReps == 0 && !isHandsOff {
                Text("화면 탭 = +1")
                    .font(.rfCaptionSm)
                    .foregroundStyle(RFColor.fgSubtle)
            } else if isHandsOff, !runner.isAMRAPSet, runner.hasMetCurrentTarget {
                Text("멈추면 자동으로 다음 세트")
                    .font(.rfCaptionSm)
                    .foregroundStyle(RFColor.success)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .contentShape(Rectangle())
        .onTapGesture {
            guard mode == .manual else { return }   // 자동 모드에서 실수로 두 번 세지 않게
            addAutoRep()
        }
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

    // MARK: - 카운트 소스

    private func startSource() {
        // 카메라 모드는 폰이 바닥에 놓인 채 아무도 안 만진다. 자동 잠금이 걸리면
        // 캡처가 끊겨서, 2세트를 마치고 일어나면 잠금화면만 남는다.
        setIdleTimerDisabled(mode != .manual)

        switch mode {
        case .manual:
            sourceStatus = nil

        case .camera:
            camera.kneeVariant = enrollment.level.allowsKneeVariant
            camera.onStatus = { sourceStatus = $0 }
            if hasPassedPlacement {
                camera.onRep = { addAutoRep() }
                camera.onForm = { formNotes.append($0) }
                camera.start()
            } else {
                // 첫 시작 전 거치를 확인한다. 이 게이트가 없으면 대부분 천장을 찍다가 0개로 끝난다.
                // 콜백은 통과한 뒤에 붙인다 — 자세를 잡으며 한 시험 동작이 세어지면 안 된다.
                showPlacementGuide = true
            }

        case .proximity:
            proximity.onRep = { addAutoRep() }
            proximity.onStatus = { sourceStatus = $0 }
            proximity.start()
        }
    }

    private func stopSource() {
        // stop() 안에서 마지막 1회를 flush 하며 onRep 을 부른다.
        // 콜백을 먼저 끊으면 그 안전망이 통째로 죽는다.
        camera.stop()
        proximity.stop()
        camera.onRep = nil
        camera.onForm = nil
        proximity.onRep = nil
        sourceStatus = nil
        setIdleTimerDisabled(false)
    }

    /// 자동 소스가 센 1회. 수동 탭과 같은 입구로 들어간다.
    private func addAutoRep() {
        runner.addRep()
        speech.announce(
            count: runner.currentReps,
            target: runner.currentTarget?.reps,
            isAMRAP: runner.isAMRAPSet
        )
        announceAutoAdvanceHintIfNeeded()
    }

    /// 목표를 채운 순간 한 번만 — 그냥 멈추면 된다는 걸 모르면 폰까지 걸어온다.
    private func announceAutoAdvanceHintIfNeeded() {
        guard isHandsOff, !spokeAutoAdvanceHint else { return }
        guard !runner.isAMRAPSet, runner.hasMetCurrentTarget else { return }
        spokeAutoAdvanceHint = true
        speech.announceAutoAdvance()
    }

    /// 폰이 손에 닿지 않는 모드. 여기서는 화면의 버튼이 없는 셈 친다.
    private var isHandsOff: Bool { mode != .manual }

    /// "세트 완료"도 누르러 갈 수 없다 — 목표를 채우고 멈추면 스스로 넘긴다.
    /// AMRAP 제외는 `shouldAutoCompleteSet` 안에 있다.
    private func autoCompleteSetIfIdle() {
        guard isHandsOff, runner.shouldAutoCompleteSet(idleFor: autoCompleteIdle) else { return }
        runner.completeSet()
    }

    // MARK: - 음성

    private func setIdleTimerDisabled(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }

    private func handlePhaseChange(from old: ProgramSessionRunner.Phase, to new: ProgramSessionRunner.Phase) {
        switch new {
        case .resting(let afterSetIndex, _):
            speech.announceSetComplete(setIndex: afterSetIndex, total: runner.session.sets.count)
            speech.announceRest(seconds: Int(runner.restDuration))
            lastSpokenRest = -1
            // 휴식 중에는 소스를 통째로 내린다. 카메라는 발열·배터리 때문이고,
            // 근접센서는 start() 가 세트마다 불리며 옵저버와 타이머가 쌓이기 때문이다.
            stopSource()

        case .working:
            spokeAutoAdvanceHint = false
            if case .resting = old { startSource() }

        case .finished, .abandoned:
            stopSource()
            speech.announceSessionComplete(totalReps: runner.totalReps)

        case .ready:
            break
        }
    }

    private func speakRestCountdownIfNeeded() {
        guard case .resting = runner.phase else { return }
        let remaining = Int(runner.remainingRest.rounded(.up))
        guard remaining != lastSpokenRest else { return }
        lastSpokenRest = remaining
        speech.announceRestCountdown(remaining)
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

        // 다음 세션을 워치로 밀어둔다. 허브로 돌아가지 않고 바로 워치를 드는 경우가 있다.
        PhoneSessionService.shared.sendProgramSession(
            enrollment.nextSession,
            restBonusSeconds: enrollment.restBonusSeconds
        )
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
