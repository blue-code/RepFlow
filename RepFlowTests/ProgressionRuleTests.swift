import Foundation
import Testing
@testable import RepFlow

/// 진행 판정은 **주 1회**만 돈다. 세션마다 +10%를 적용하면 주당 +33%가 되어
/// 며칠 만에 사다리가 무너지므로, 그 계약이 지켜지는지가 이 스위트의 핵심이다.
@Suite("주간 진행 판정")
struct ProgressionRuleTests {

    /// 목표를 정확히 채우고 AMRAP만 `surplus` 만큼 넘긴 한 주.
    private func week(surplus: Int, missFixedSet: Bool = false) -> [SessionResult] {
        SessionKind.allCases.map { kind in
            let session = ProgramLadder.generate(trainingMax: 20, week: 1, kind: kind)
            let targets = session.sets.map(\.reps)
            var achieved = targets
            achieved[achieved.count - 1] += surplus
            if missFixedSet { achieved[0] = max(0, targets[0] - 1) }
            return SessionResult(kind: kind, targets: targets, achieved: achieved)
        }
    }

    @Test("전 세트 달성 + AMRAP 여유 3 이상이면 훈련최대가 10% 오른다")
    func advances() {
        let outcome = ProgressionRule.apply(trainingMax: 20, week: 1, results: week(surplus: 3))
        #expect(outcome.trainingMax == 22)
        #expect(outcome.adjustment == .increase(to: 22))
        #expect(outcome.consecutiveMissedWeeks == 0)
    }

    @Test("AMRAP 여유가 모자라면 그 주는 제자리다")
    func holdsOnInsufficientSurplus() {
        let outcome = ProgressionRule.apply(trainingMax: 20, week: 1, results: week(surplus: 2))
        #expect(outcome.adjustment == .hold)
        #expect(outcome.trainingMax == 20)
        #expect(outcome.consecutiveMissedWeeks == 1)
    }

    @Test("고정 세트를 하나라도 놓치면 AMRAP을 아무리 넘겨도 올리지 않는다")
    func fixedSetMissBlocksAdvance() {
        let outcome = ProgressionRule.apply(
            trainingMax: 20, week: 1,
            results: week(surplus: 10, missFixedSet: true)
        )
        #expect(outcome.adjustment == .hold)
        #expect(outcome.consecutiveMissedWeeks == 1)
    }

    @Test("한 번 미달로는 내리지 않는다 — 2주 연속이어야 한다")
    func backsOffOnlyAfterTwoMisses() {
        let first = ProgressionRule.apply(trainingMax: 20, week: 1, results: week(surplus: 0))
        #expect(first.adjustment == .hold)

        let second = ProgressionRule.apply(
            trainingMax: first.trainingMax, week: 2, results: week(surplus: 0),
            consecutiveMissedWeeks: first.consecutiveMissedWeeks,
            restBonusSeconds: first.restBonusSeconds
        )
        #expect(second.adjustment == .decrease(to: 18))
        #expect(second.trainingMax == 18)
        #expect(second.restBonusSeconds == 30, "내려갈 때 휴식 30초를 더 준다")
        #expect(second.consecutiveMissedWeeks == 0, "내린 뒤에는 카운터를 리셋한다")
    }

    @Test("성공하면 연속 미달 카운터가 초기화된다")
    func successResetsMisses() {
        let outcome = ProgressionRule.apply(
            trainingMax: 20, week: 1, results: week(surplus: 5),
            consecutiveMissedWeeks: 1
        )
        #expect(outcome.consecutiveMissedWeeks == 0)
    }

    @Test("디로드 주간은 일부러 볼륨을 줄인 주라 성과로 판정하지 않는다")
    func deloadWeekIsNeverJudged() {
        #expect(ProgramLadder.isDeloadWeek(4))
        let outcome = ProgressionRule.apply(trainingMax: 20, week: 4, results: week(surplus: 0))
        #expect(outcome.adjustment == .hold)
        #expect(outcome.consecutiveMissedWeeks == 0, "미달로 세지도 않는다")
    }

    @Test("아주 낮은 훈련최대에서도 최소 1은 오르내린다")
    func movesAtLeastOne() {
        let up = ProgressionRule.apply(trainingMax: 3, week: 1, results: week(surplus: 5))
        #expect(up.trainingMax == 4)

        let down = ProgressionRule.apply(
            trainingMax: 3, week: 1, results: week(surplus: 0), consecutiveMissedWeeks: 1
        )
        #expect(down.trainingMax == 2)
    }

    @Test("훈련최대는 1 아래로 내려가지 않는다")
    func neverBelowOne() {
        let outcome = ProgressionRule.apply(
            trainingMax: 1, week: 1, results: week(surplus: 0), consecutiveMissedWeeks: 1
        )
        #expect(outcome.trainingMax >= 1)
    }

    @Test("결과가 없으면 아무것도 바꾸지 않는다")
    func emptyResultsAreNoop() {
        let outcome = ProgressionRule.apply(trainingMax: 20, week: 1, results: [])
        #expect(outcome.adjustment == .hold)
        #expect(outcome.trainingMax == 20)
        #expect(outcome.consecutiveMissedWeeks == 0)
    }

    @Test("성공을 반복하면 100에 도달한다 — 사다리가 막히지 않는지 확인")
    func reachesGoalEventually() {
        var trainingMax = 5
        var weeks = 0
        while trainingMax < ProgramLadder.goal && weeks < 200 {
            weeks += 1
            guard !ProgramLadder.isDeloadWeek(weeks), !ProgramLadder.isRetestWeek(weeks) else { continue }
            let results = SessionKind.allCases.map { kind -> SessionResult in
                let session = ProgramLadder.generate(trainingMax: trainingMax, week: weeks, kind: kind)
                let targets = session.sets.map(\.reps)
                var achieved = targets
                achieved[achieved.count - 1] += 3
                return SessionResult(kind: kind, targets: targets, achieved: achieved)
            }
            trainingMax = ProgressionRule.apply(
                trainingMax: trainingMax, week: weeks, results: results
            ).trainingMax
        }
        #expect(trainingMax >= ProgramLadder.goal, "\(weeks)주 지나도 \(trainingMax)에서 멈췄다")
        // 매주 성공만 하는 이상적 경우라 하한일 뿐이지만, 몇 주 만에 끝나면 사다리가 너무 공격적이다.
        #expect(weeks >= 20, "\(weeks)주 만에 100 달성 — 증가율이 비현실적으로 가파르다")
    }
}
