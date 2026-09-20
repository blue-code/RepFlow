import Foundation
import Testing
@testable import RepFlow

@Suite("레벨 배정")
struct PushUpLevelTests {

    @Test("최대 측정값이 레벨 경계에 정확히 걸린다", arguments: [
        (0, PushUpLevel.l1), (5, .l1),
        (6, .l2), (10, .l2),
        (11, .l3), (20, .l3),
        (21, .l4), (30, .l4),
        (31, .l5), (45, .l5),
        (46, .l6), (100, .l6)
    ])
    func assignsLevel(max: Int, expected: PushUpLevel) {
        #expect(PushUpLevel.forMax(max) == expected)
    }

    @Test("무릎 변형은 L1만 허용한다")
    func kneeVariantOnlyL1() {
        #expect(PushUpLevel.l1.allowsKneeVariant)
        for level in PushUpLevel.allCases where level != .l1 {
            #expect(level.allowsKneeVariant == false)
        }
    }

    @Test("초보 레벨일수록 휴식이 길다")
    func restByLevel() {
        #expect(PushUpLevel.l1.baseRestSeconds == 90)
        #expect(PushUpLevel.l3.baseRestSeconds == 90)
        #expect(PushUpLevel.l4.baseRestSeconds == 60)
        #expect(PushUpLevel.l6.baseRestSeconds == 60)
    }
}

@Suite("사다리 생성")
struct ProgramLadderTests {

    @Test("한 세션은 고정 4세트 + AMRAP 1세트다")
    func fiveSets() {
        let session = ProgramLadder.generate(trainingMax: 20, week: 1, kind: .volume)
        #expect(session.sets.count == 5)
        #expect(session.sets.filter(\.isAMRAP).count == 1)
        #expect(session.sets.last?.isAMRAP == true)
    }

    @Test("세트 목표는 훈련최대의 비율이다")
    func setsFollowRatios() {
        // W=20, 볼륨 세션 비율 [.40 .50 .40 .40] + AMRAP .40
        let session = ProgramLadder.generate(trainingMax: 20, week: 1, kind: .volume)
        #expect(session.sets.map(\.reps) == [8, 10, 8, 8, 8])
    }

    @Test("강도 세션은 볼륨 세션보다 한 세트가 무겁다")
    func intensityIsHeavier() {
        let volume = ProgramLadder.generate(trainingMax: 20, week: 1, kind: .volume)
        let intensity = ProgramLadder.generate(trainingMax: 20, week: 1, kind: .intensity)
        #expect(intensity.sets.map(\.reps).max()! > volume.sets.map(\.reps).max()!)
    }

    @Test("밀도 세션만 휴식이 절반이다")
    func densityHalvesRest() {
        let volume = ProgramLadder.generate(trainingMax: 40, week: 1, kind: .volume)
        let density = ProgramLadder.generate(trainingMax: 40, week: 1, kind: .density)
        #expect(volume.restSeconds == 60)
        #expect(density.restSeconds == 30)
    }

    @Test("아무리 약해도 세트 목표가 0이 되지는 않는다")
    func neverZeroReps() {
        for max in 1...5 {
            for kind in SessionKind.allCases {
                let session = ProgramLadder.generate(trainingMax: max, week: 1, kind: kind)
                #expect(session.sets.allSatisfy { $0.reps >= 1 }, "W=\(max) \(kind)")
            }
        }
    }

    @Test("훈련최대가 오르면 세트 목표도 단조 증가한다")
    func monotonicInTrainingMax() {
        var previous = 0
        for max in stride(from: 5, through: 90, by: 5) {
            let total = ProgramLadder.generate(trainingMax: max, week: 1, kind: .volume).totalTargetReps
            #expect(total >= previous, "W=\(max) 에서 총량이 줄었다")
            previous = total
        }
    }

    @Test("4주차는 디로드라 볼륨이 60%로 줄어든다")
    func deloadWeek() {
        let normal = ProgramLadder.generate(trainingMax: 30, week: 3, kind: .volume)
        let deload = ProgramLadder.generate(trainingMax: 30, week: 4, kind: .volume)
        #expect(deload.isDeload)
        #expect(normal.isDeload == false)
        #expect(deload.totalTargetReps < normal.totalTargetReps)
    }

    @Test("7주차는 재측정 — 사다리 대신 AMRAP 한 세트")
    func retestWeek() {
        let session = ProgramLadder.generate(trainingMax: 30, week: 7, kind: .volume)
        #expect(session.isRetest)
        #expect(session.sets.count == 1)
        #expect(session.sets.first?.isAMRAP == true)
        #expect(session.restSeconds == 0)
    }

    @Test("재측정이 디로드보다 우선한다")
    func retestBeatsDeload() {
        // 28주차는 4의 배수이자 7의 배수 — 둘 다 걸린다
        #expect(ProgramLadder.isRetestWeek(28))
        #expect(ProgramLadder.isDeloadWeek(28) == false)
        #expect(ProgramLadder.generate(trainingMax: 50, week: 28, kind: .volume).isDeload == false)
    }

    @Test("주간 총 볼륨이 상한(W×8)을 넘지 않는다")
    func staysUnderWeeklyCap() {
        for max in stride(from: 5, through: 120, by: 5) {
            for week in 1...8 {
                let volume = ProgramLadder.weeklyTargetVolume(trainingMax: max, week: week)
                let cap = Int(Double(max) * ProgramLadder.weeklyVolumeCapMultiplier)
                #expect(volume <= cap, "W=\(max) \(week)주차: \(volume) > \(cap)")
            }
        }
    }

    @Test("한 주는 볼륨 → 강도 → 밀도 순서다")
    func weekOrder() {
        let week = ProgramLadder.generateWeek(trainingMax: 20, week: 1)
        #expect(week.map(\.kind) == [.volume, .intensity, .density])
    }

    @Test("졸업은 한 세트 100개")
    func graduation() {
        #expect(ProgramLadder.hasGraduated(bestSingleSet: 99) == false)
        #expect(ProgramLadder.hasGraduated(bestSingleSet: 100))
        #expect(ProgramLadder.hasGraduated(bestSingleSet: 137))
    }
}

@Suite("100까지 남은 주 예측")
struct ETATests {

    @Test("꾸준히 늘면 남은 주를 계산한다")
    func extrapolates() {
        // 주당 +10 → 60에서 100까지 4주
        #expect(ProgramLadder.estimatedWeeksTo100(history: [30, 40, 50, 60]) == 4)
    }

    @Test("정체되어 있으면 예측하지 않는다")
    func refusesWhenFlat() {
        #expect(ProgramLadder.estimatedWeeksTo100(history: [40, 40, 40, 40]) == nil)
    }

    @Test("줄어들고 있으면 예측하지 않는다")
    func refusesWhenDeclining() {
        #expect(ProgramLadder.estimatedWeeksTo100(history: [50, 45, 40]) == nil)
    }

    @Test("이력이 한 주뿐이면 예측하지 않는다")
    func refusesWithoutHistory() {
        #expect(ProgramLadder.estimatedWeeksTo100(history: [20]) == nil)
        #expect(ProgramLadder.estimatedWeeksTo100(history: []) == nil)
    }

    @Test("이미 100을 넘겼으면 예측이 없다")
    func noneAfterGoal() {
        #expect(ProgramLadder.estimatedWeeksTo100(history: [90, 100]) == nil)
    }
}
