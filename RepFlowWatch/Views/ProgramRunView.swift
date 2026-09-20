import SwiftUI
import WatchKit

/// 워치에서 「푸시업 100」 세션을 진행한다. **폰 없이 완주할 수 있다.**
///
/// 상태는 `ProgramSessionRunner`(Shared) — 폰의 `ProgramSessionView` 와 같은 것을 쓴다.
/// 여기서 하는 일은 워치 입력(탭·크라운)을 `addRep()` 으로 흘리고, 햅틱을 울리고,
/// 끝나면 결과를 폰으로 보장 송신하는 것뿐이다. 주간 판정은 폰이 한다.
struct ProgramRunView: View {

    let session: ProgramSession
    let restBonusSeconds: Int

    @Environment(WatchCoordinator.self) private var coord
    @State private var workoutManager = WatchWorkoutManager.shared
    @State private var runner: ProgramSessionRunner
    @State private var crownAccum: Double = 0
    @State private var didSend = false
    /// 휴식 잔여를 다시 그리기 위한 심박. 상태 자체는 runner가 시계로 계산한다.
    @State private var tickerDate: Date = .now

    @FocusState private var crownFocused: Bool

    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    init(session: ProgramSession, restBonusSeconds: Int) {
        self.session = session
        self.restBonusSeconds = restBonusSeconds
        _runner = State(initialValue: ProgramSessionRunner(
            session: session, restBonusSeconds: restBonusSeconds
        ))
    }

    var body: some View {
        VStack(spacing: 2) {
            metaRow
            Spacer(minLength: 0)
            content
            Spacer(minLength: 2)
            controls
        }
        // §5.1 레이아웃 규약 — 둥근 모서리 잘림 + 시스템 시계 충돌 방지
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .onAppear {
            runner.start()
            workoutManager.start(exercise: .pushUp)
            crownFocused = true
        }
        .onReceive(ticker) { date in
            tickerDate = date
            let wasResting = runner.remainingRest > 0
            runner.tick()
            if wasResting, runner.remainingRest == 0, case .working = runner.phase {
                coord.haptic(.start)      // 휴식 끝 — 화면을 안 보고 있어도 알 수 있어야 한다
            }
        }
        .onChange(of: runner.phase) { _, phase in
            if phase == .finished || phase == .abandoned { finish() }
        }
    }

    // MARK: - 조각

    private var metaRow: some View {
        HStack(spacing: 4) {
            Text(session.isRetest ? "재측정" : "\(session.week)주 \(session.kind.shortName)")
            Spacer()
            if let index = runner.currentSetIndex {
                Text("\(index + 1)/\(session.sets.count)")
            }
            if workoutManager.heartRate > 0 {
                Text("\(Int(workoutManager.heartRate))")
            }
        }
        .font(.caption2)
        .minimumScaleFactor(0.8)
        .lineLimit(1)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var content: some View {
        switch runner.phase {
        case .resting:
            restBody
        case .finished, .abandoned:
            summaryBody
        case .ready, .working:
            countBody
        }
    }

    /// 카운터 영역 전체가 탭 타깃. 푸시업 중에 작은 버튼을 겨냥할 수는 없다.
    private var countBody: some View {
        VStack(spacing: 0) {
            Text("\(runner.currentReps)")
                .font(.system(size: 62, weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(runner.hasMetCurrentTarget ? .green : .primary)

            Text(targetLabel)
                .font(.caption2)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            runner.addRep()
            coord.haptic(.click)
        }
        .focusable(true)
        .focused($crownFocused)
        .digitalCrownRotation(
            $crownAccum, from: -1000, through: 1000, by: 1,
            sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true
        )
        .onChange(of: crownAccum) { old, new in
            let delta = Int(new.rounded()) - Int(old.rounded())
            guard delta != 0 else { return }
            runner.addRep(delta)
        }
    }

    private var targetLabel: String {
        guard let target = runner.currentTarget else { return "" }
        return target.isAMRAP ? "최소 \(target.reps) · 최대한" : "목표 \(target.reps)"
    }

    private var restBody: some View {
        VStack(spacing: 2) {
            Text("휴식")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(restText)
                .font(.system(size: 52, weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity)
    }

    private var restText: String {
        let remaining = Int(runner.remainingRest.rounded(.up))
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    private var summaryBody: some View {
        VStack(spacing: 2) {
            Text(runner.phase == .abandoned ? "중단" : "완료")
                .font(.caption2)
                .foregroundStyle(runner.phase == .abandoned ? .orange : .green)
            Text("\(runner.totalReps)")
                .font(.system(size: 56, weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var controls: some View {
        switch runner.phase {
        case .working:
            HStack(spacing: 6) {
                Button { runner.undoRep() } label: { Image(systemName: "minus") }
                    .frame(maxWidth: .infinity)
                    .disabled(runner.currentReps == 0)

                Button {
                    coord.haptic(.success)
                    runner.completeSet()
                } label: {
                    Image(systemName: "checkmark")
                }
                .frame(maxWidth: .infinity)
                .disabled(runner.currentReps == 0)
            }
            .controlSize(.small)
            .font(.footnote)

        case .resting:
            Button("건너뛰기") {
                coord.haptic(.click)
                runner.skipRest()
            }
            .controlSize(.small)
            .font(.footnote)
            .frame(maxWidth: .infinity)

        case .finished, .abandoned:
            Button("닫기") { coord.backToMenu() }
                .controlSize(.small)
                .font(.footnote)
                .frame(maxWidth: .infinity)

        case .ready:
            EmptyView()
        }
    }

    // MARK: - 종료

    /// 한 번만 보낸다 — `onChange` 는 여러 번 불릴 수 있다.
    private func finish() {
        guard !didSend, let result = runner.result else { return }
        didSend = true
        coord.haptic(runner.phase == .abandoned ? .stop : .success)
        workoutManager.stop(totalReps: runner.totalReps, exercise: .pushUp)
        WatchSessionService.shared.sendProgramSessionCompleted(result, totalReps: runner.totalReps)
    }
}

extension SessionKind {
    /// 워치 화면은 좁다 — 한 글자로 줄인다.
    var shortName: String {
        switch self {
        case .volume:    return "볼륨"
        case .intensity: return "강도"
        case .density:   return "밀도"
        }
    }
}
