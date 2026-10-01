import Foundation
import Testing
@testable import RepFlow

/// 폰과 워치가 같은 상태머신을 쓰므로, 전이가 틀리면 양쪽이 동시에 틀린다.
@Suite("세션 진행 상태머신")
struct ProgramSessionRunnerTests {

    /// 테스트가 실제로 기다리지 않도록 시계를 손으로 민다.
    final class Clock {
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        func advance(_ seconds: TimeInterval) { now += seconds }
        var provider: () -> Date { { [self] in now } }
    }

    private func makeRunner(
        trainingMax: Int = 20,
        kind: SessionKind = .volume,
        restBonusSeconds: Int = 0,
        clock: Clock = Clock()
    ) -> (ProgramSessionRunner, Clock) {
        let session = ProgramLadder.generate(trainingMax: trainingMax, week: 1, kind: kind)
        return (ProgramSessionRunner(session: session,
                                     restBonusSeconds: restBonusSeconds,
                                     now: clock.provider), clock)
    }

    /// 목표대로 한 세트를 끝낸다.
    private func finishSet(_ runner: ProgramSessionRunner, extra: Int = 0) {
        let target = runner.currentTarget?.reps ?? 0
        runner.addRep(target + extra)
        runner.completeSet()
    }

    // MARK: - 자동 세트 완료 (손이 폰에 닿지 않는 모드)

    /// 카메라·근접센서 모드에서는 "세트 완료" 버튼이 1.5~2m 밖에 있다.
    /// 목표를 채우고 멈추면 스스로 넘어가야 한다.
    @Test("목표를 채우고 멈춰 있으면 세트를 자동으로 끝낸다")
    func autoCompletesAfterIdle() {
        let (runner, clock) = makeRunner()
        runner.start()
        let target = runner.currentTarget?.reps ?? 0
        runner.addRep(target)

        clock.advance(5)
        #expect(runner.shouldAutoCompleteSet(idleFor: 6) == false)
        clock.advance(1)
        #expect(runner.shouldAutoCompleteSet(idleFor: 6))
    }

    @Test("1회를 더 세면 기다리는 시간이 다시 시작된다")
    func newRepResetsIdleWindow() {
        let (runner, clock) = makeRunner()
        runner.start()
        runner.addRep(runner.currentTarget?.reps ?? 0)

        clock.advance(5)
        runner.addRep()
        clock.advance(5)
        #expect(runner.shouldAutoCompleteSet(idleFor: 6) == false, "마지막 1회부터 다시 센다")
        clock.advance(1)
        #expect(runner.shouldAutoCompleteSet(idleFor: 6))
    }

    @Test("목표에 못 미치면 아무리 멈춰 있어도 끝내지 않는다")
    func neverAutoCompletesBelowTarget() {
        let (runner, clock) = makeRunner()
        runner.start()
        runner.addRep((runner.currentTarget?.reps ?? 0) - 1)
        clock.advance(600)
        #expect(runner.shouldAutoCompleteSet(idleFor: 6) == false)
    }

    /// AMRAP 은 잠깐 쉬었다 몇 개 더 하는 게 정상인 세트다. 끊으면 기록이 깎인다.
    @Test("AMRAP 세트는 자동으로 끝내지 않는다")
    func neverAutoCompletesAMRAP() {
        let (runner, clock) = makeRunner()
        runner.start()
        // 마지막 세트까지 간다 — 사다리의 마지막은 AMRAP 이다.
        while runner.currentSetIndex != runner.session.sets.count - 1 {
            finishSet(runner)
            runner.skipRest()
        }
        #expect(runner.isAMRAPSet, "마지막 세트는 AMRAP 이어야 한다")

        runner.addRep((runner.currentTarget?.reps ?? 0) + 5)
        clock.advance(600)
        #expect(runner.shouldAutoCompleteSet(idleFor: 6) == false)
    }

    @Test("취소는 활동으로 치지 않는다 — 폰 앞에 있다는 뜻이다")
    func undoDoesNotCountAsActivity() {
        let (runner, clock) = makeRunner()
        runner.start()
        runner.addRep(runner.currentTarget?.reps ?? 0)
        clock.advance(6)
        runner.addRep(-1)
        #expect(runner.hasMetCurrentTarget == false, "하나 줄었으니 목표 미달이다")
        runner.addRep()
        #expect(runner.shouldAutoCompleteSet(idleFor: 6) == false, "방금 센 1회부터 다시 센다")
    }

    @Test("휴식 뒤 다음 세트는 처음부터 기다린다")
    func idleWindowResetsAcrossSets() {
        let (runner, clock) = makeRunner()
        runner.start()
        finishSet(runner)
        runner.skipRest()
        clock.advance(600)
        #expect(runner.shouldAutoCompleteSet(idleFor: 6) == false, "아직 한 개도 안 셌다")
    }

    @Test("시작 전에는 아무 일도 일어나지 않는다")
    func idleBeforeStart() {
        let (runner, _) = makeRunner()
        #expect(runner.phase == .ready)
        #expect(runner.currentSetIndex == nil)
        #expect(runner.result == nil)

        runner.addRep()
        #expect(runner.totalReps == 0, "시작 전 카운트는 무시한다")
    }

    @Test("시작하면 첫 세트로 들어간다")
    func startsFirstSet() {
        let (runner, _) = makeRunner()
        runner.start()
        #expect(runner.phase == .working(setIndex: 0))
        #expect(runner.currentTarget == runner.session.sets.first)
    }

    @Test("카운트 소스가 무엇이든 addRep 하나로 들어온다")
    func countsReps() {
        let (runner, _) = makeRunner()
        runner.start()
        runner.addRep()          // 탭
        runner.addRep(3)         // 카메라가 한 번에 3개 보고
        #expect(runner.currentReps == 4)
        runner.undoRep()
        #expect(runner.currentReps == 3)
    }

    @Test("카운트는 0 아래로 내려가지 않는다")
    func neverNegative() {
        let (runner, _) = makeRunner()
        runner.start()
        runner.undoRep()
        runner.undoRep()
        #expect(runner.currentReps == 0)
    }

    @Test("세트를 끝내면 휴식으로 넘어간다")
    func restsBetweenSets() {
        let (runner, clock) = makeRunner()
        runner.start()
        finishSet(runner)

        #expect(runner.phase == .resting(afterSetIndex: 0,
                                         until: clock.now.addingTimeInterval(runner.restDuration)))
        #expect(runner.remainingRest == runner.restDuration)
        #expect(runner.currentReps == 0, "다음 세트를 위해 초기화된다")
    }

    @Test("휴식이 끝나면 tick 으로 다음 세트가 열린다")
    func advancesAfterRest() {
        let (runner, clock) = makeRunner()
        runner.start()
        finishSet(runner)

        clock.advance(runner.restDuration - 1)
        runner.tick()
        #expect(runner.phase == .resting(afterSetIndex: 0,
                                         until: clock.now.addingTimeInterval(1)),
                "아직 1초 남았으면 넘어가지 않는다")

        clock.advance(1)
        runner.tick()
        #expect(runner.phase == .working(setIndex: 1))
    }

    @Test("휴식은 건너뛸 수 있다")
    func skipsRest() {
        let (runner, _) = makeRunner()
        runner.start()
        finishSet(runner)
        runner.skipRest()
        #expect(runner.phase == .working(setIndex: 1))
        #expect(runner.remainingRest == 0)
    }

    @Test("진행 판정에서 붙은 추가 휴식이 반영된다")
    func appliesRestBonus() {
        let (runner, _) = makeRunner(restBonusSeconds: 30)
        #expect(runner.restDuration == TimeInterval(runner.session.restSeconds + 30))
    }

    @Test("마지막 AMRAP 세트에는 상한도 휴식도 없다")
    func lastSetIsAMRAP() {
        let (runner, _) = makeRunner()
        runner.start()
        for _ in 0..<(runner.session.sets.count - 1) {
            finishSet(runner)
            runner.skipRest()
        }
        #expect(runner.isAMRAPSet)

        runner.addRep(runner.currentTarget!.reps + 7)
        #expect(runner.hasMetCurrentTarget, "목표를 넘겨도 계속 셀 수 있다")
        runner.completeSet()
        #expect(runner.phase == .finished, "마지막 세트 뒤에는 휴식이 없다")
    }

    @Test("끝나기 전에는 결과가 없다")
    func noResultUntilDone() {
        let (runner, _) = makeRunner()
        runner.start()
        #expect(runner.result == nil)
        finishSet(runner)
        #expect(runner.result == nil, "휴식 중에도 아직 결과가 아니다")
    }

    @Test("완주하면 진행 판정에 바로 넣을 수 있는 결과가 나온다")
    func producesResult() throws {
        let (runner, _) = makeRunner()
        runner.start()
        while runner.isRunning {
            if runner.currentSetIndex != nil {
                finishSet(runner, extra: runner.isAMRAPSet ? 3 : 0)
            } else {
                runner.skipRest()
            }
        }
        let result = try #require(runner.result)
        #expect(result.kind == .volume)
        #expect(result.targets == runner.session.sets.map(\.reps))
        #expect(result.metFixedSets)
        #expect(result.amrapSurplus == 3)

        // 이 결과 셋이 그대로 주간 판정에 들어간다.
        let outcome = ProgressionRule.apply(
            trainingMax: 20, week: 1,
            results: [result, result, result]
        )
        #expect(outcome.adjustment == .increase(to: 22))
    }

    @Test("중간에 그만둬도 한 만큼은 남는다")
    func abandonKeepsProgress() throws {
        let (runner, _) = makeRunner()
        runner.start()
        finishSet(runner)
        runner.skipRest()
        runner.addRep(4)
        runner.abandon()

        #expect(runner.phase == .abandoned)
        let result = try #require(runner.result)
        #expect(result.achieved.count == result.targets.count,
                "남은 세트를 0으로 채워야 길이가 맞는다")
        #expect(result.achieved[1] == 4)
        #expect(result.achieved.last == 0)
        #expect(result.metFixedSets == false)
    }

    @Test("중단한 세션은 미달로 판정되어 진행을 막는다")
    func abandonedSessionBlocksAdvance() throws {
        let (runner, _) = makeRunner()
        runner.start()
        runner.abandon()
        let result = try #require(runner.result)

        let outcome = ProgressionRule.apply(trainingMax: 20, week: 1, results: [result])
        #expect(outcome.adjustment == .hold)
    }

    @Test("끝난 뒤의 조작은 무시한다")
    func ignoresPostFinishInput() {
        let (runner, _) = makeRunner()
        runner.start()
        runner.abandon()
        let before = runner.totalReps
        runner.addRep(10)
        runner.completeSet()
        runner.skipRest()
        #expect(runner.phase == .abandoned)
        #expect(runner.totalReps == before)
    }

    @Test("밀도 세션은 휴식이 짧다")
    func densityRestsLess() {
        let (volume, _) = makeRunner(trainingMax: 40, kind: .volume)
        let (density, _) = makeRunner(trainingMax: 40, kind: .density)
        #expect(density.restDuration < volume.restDuration)
    }

    @Test("재측정 세션은 한 세트로 바로 끝난다")
    func retestIsSingleSet() {
        let session = ProgramLadder.generate(trainingMax: 30, week: 7, kind: .volume)
        let runner = ProgramSessionRunner(session: session)
        runner.start()
        #expect(runner.isAMRAPSet)
        runner.addRep(34)
        runner.completeSet()
        #expect(runner.phase == .finished)
        #expect(runner.totalReps == 34)
    }
}
