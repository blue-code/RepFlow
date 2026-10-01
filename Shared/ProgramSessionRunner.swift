import Foundation
import Observation

/// 프로그램 세션 한 번을 굴리는 상태머신.
///
/// 폰(카메라·근접센서·음성)과 워치(탭·크라운·모션)가 **같은 것을 쓴다**. 카운트가 어디서
/// 오는지는 이 타입이 알 필요가 없다 — 소스는 `addRep()` 을 부를 뿐이다. UI 안에 상태를
/// 넣으면 워치에서 통째로 다시 만들어야 하므로 `Shared/` 의 순수 타입으로 둔다.
///
/// 시계를 주입받기 때문에 테스트가 실제로 기다리지 않아도 된다.
@Observable
final class ProgramSessionRunner {

    enum Phase: Equatable {
        case ready
        /// `setIndex` 세트를 수행 중.
        case working(setIndex: Int)
        /// `afterSetIndex` 세트를 끝내고 `until` 까지 휴식.
        case resting(afterSetIndex: Int, until: Date)
        case finished
        /// 사용자가 중간에 그만둠. 여기까지 한 만큼은 기록에 남긴다.
        case abandoned
    }

    let session: ProgramSession
    /// 진행 판정에서 내려온 추가 휴식(2주 연속 미달 시 +30s).
    let restBonusSeconds: Int

    private(set) var phase: Phase = .ready
    /// 세트별 실제 수행 횟수. 완료된 세트까지만 채워진다.
    private(set) var completedReps: [Int] = []
    /// 현재 세트에서 지금까지 센 횟수.
    private(set) var currentReps: Int = 0
    /// 마지막으로 1회를 센 시각. 자동 세트 완료 판정에만 쓴다.
    private(set) var lastRepAt: Date?

    @ObservationIgnored private let now: () -> Date

    init(
        session: ProgramSession,
        restBonusSeconds: Int = 0,
        now: @escaping () -> Date = { .now }
    ) {
        self.session = session
        self.restBonusSeconds = restBonusSeconds
        self.now = now
    }

    // MARK: - 파생 상태

    var currentSetIndex: Int? {
        if case .working(let index) = phase { return index }
        return nil
    }

    var currentTarget: SetTarget? {
        currentSetIndex.map { session.sets[$0] }
    }

    /// AMRAP 세트에는 상한이 없다 — 목표를 채웠다고 멈추라고 하면 안 된다.
    var isAMRAPSet: Bool { currentTarget?.isAMRAP ?? false }

    var hasMetCurrentTarget: Bool {
        guard let target = currentTarget else { return false }
        return currentReps >= target.reps
    }

    var restDuration: TimeInterval {
        TimeInterval(session.restSeconds + restBonusSeconds)
    }

    /// 휴식 잔여. 휴식 중이 아니면 0.
    var remainingRest: TimeInterval {
        guard case .resting(_, let until) = phase else { return 0 }
        return max(0, until.timeIntervalSince(now()))
    }

    var isRunning: Bool {
        switch phase {
        case .working, .resting: return true
        case .ready, .finished, .abandoned: return false
        }
    }

    /// 완료된 세트 + 진행 중인 세트의 누적.
    var totalReps: Int { completedReps.reduce(0, +) + currentReps }

    /// **손이 폰에 닿지 않는 모드**(카메라·근접센서)에서는 "세트 완료"를 누를 수 없다.
    /// 목표를 채우고 `idle` 만큼 멈춰 있으면 세트가 끝난 것으로 본다.
    ///
    /// AMRAP 은 제외한다 — 잠깐 쉬었다 몇 개 더 하는 게 정상인 세트라, 끊으면 기록이 깎인다.
    /// 탭 모드도 제외다(판단은 호출부에서 한다): 그쪽은 손이 폰에 있으니 버튼이 멀쩡히 동작한다.
    func shouldAutoCompleteSet(idleFor idle: TimeInterval) -> Bool {
        guard case .working = phase else { return false }
        guard !isAMRAPSet, hasMetCurrentTarget else { return false }
        guard let lastRepAt else { return false }
        return now().timeIntervalSince(lastRepAt) >= idle
    }

    /// 끝난 세션의 결과. 진행 중이면 nil — 아직 판정할 게 없다.
    var result: SessionResult? {
        switch phase {
        case .finished, .abandoned:
            // 중단한 경우 남은 세트는 0회 수행으로 채운다. 안 그러면 targets 와 길이가 달라져
            // `metFixedSets` 가 조용히 false 를 내놓는다.
            let achieved = completedReps + Array(repeating: 0, count: session.sets.count - completedReps.count)
            return SessionResult(
                kind: session.kind,
                targets: session.sets.map(\.reps),
                achieved: achieved
            )
        case .ready, .working, .resting:
            return nil
        }
    }

    // MARK: - 조작

    func start() {
        guard case .ready = phase, !session.sets.isEmpty else { return }
        phase = .working(setIndex: 0)
        currentReps = 0
        lastRepAt = nil
    }

    /// 카운트 소스(탭·크라운·카메라·근접센서·모션)가 부르는 단일 입구.
    func addRep(_ delta: Int = 1) {
        guard case .working = phase else { return }
        currentReps = max(0, currentReps + delta)
        // 취소(-1)는 활동 시각으로 치지 않는다. 그건 사용자가 폰 앞에 있다는 뜻이고,
        // 그 경우 자동 완료를 기다릴 이유가 없다.
        if delta > 0 { lastRepAt = now() }
    }

    func undoRep() { addRep(-1) }

    /// 현재 세트를 끝낸다. 목표에 못 미쳐도 실제 수행분 그대로 기록한다.
    func completeSet() {
        guard case .working(let index) = phase else { return }
        completedReps.append(currentReps)
        currentReps = 0
        lastRepAt = nil

        let isLastSet = index == session.sets.count - 1
        if isLastSet {
            phase = .finished
        } else {
            phase = .resting(afterSetIndex: index, until: now().addingTimeInterval(restDuration))
        }
    }

    func skipRest() {
        guard case .resting(let afterSetIndex, _) = phase else { return }
        phase = .working(setIndex: afterSetIndex + 1)
        currentReps = 0
        lastRepAt = nil
    }

    /// 휴식이 끝났으면 다음 세트로 넘긴다. 뷰가 타이머로 주기적으로 부른다.
    func tick() {
        guard case .resting = phase, remainingRest <= 0 else { return }
        skipRest()
    }

    /// 중간에 그만둔다. 여기까지 한 세트는 남는다.
    func abandon() {
        guard isRunning else { return }
        if case .working = phase, currentReps > 0 {
            completedReps.append(currentReps)
            currentReps = 0
        }
        phase = .abandoned
    }
}
