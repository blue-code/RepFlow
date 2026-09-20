import Foundation

// MARK: - 레벨

/// 최대 측정(한 세트 AMRAP) 결과로 배정되는 레벨.
/// 레벨은 휴식 시간과 무릎 변형 허용 여부만 결정한다. 세트 수치는 레벨이 아니라
/// 훈련최대(`trainingMax`)의 비율로 나오므로, 같은 레벨 안에서도 사람마다 다르다.
enum PushUpLevel: Int, CaseIterable, Codable, Sendable {
    case l1 = 1, l2, l3, l4, l5, l6

    static func forMax(_ max: Int) -> PushUpLevel {
        switch max {
        case ..<6:    return .l1
        case 6...10:  return .l2
        case 11...20: return .l3
        case 21...30: return .l4
        case 31...45: return .l5
        default:      return .l6
        }
    }

    /// L1은 정자세 5개 미만이라 무릎 푸시업으로 볼륨을 채운다.
    /// 폼 분석기도 이 값을 보고 힙라인 기준점을 발목 대신 무릎으로 바꿔야 한다.
    var allowsKneeVariant: Bool { self == .l1 }

    /// 세트 간 기본 휴식. 초보일수록 회복이 느려 길게 준다.
    var baseRestSeconds: Int { rawValue <= 3 ? 90 : 60 }
}

// MARK: - 세션 종류

/// 주 3회 세션. 같은 주 안에서 자극을 볼륨 / 강도 / 밀도로 나눈다.
enum SessionKind: String, CaseIterable, Codable, Sendable {
    case volume     // A — 많이, 편하게
    case intensity  // B — 무겁게 (한 세트 비중 높임)
    case density    // C — 같은 양을 짧은 휴식으로

    /// 앞 4세트의 훈련최대 대비 비율.
    var fixedRatios: [Double] {
        switch self {
        case .volume:    return [0.40, 0.50, 0.40, 0.40]
        case .intensity: return [0.50, 0.60, 0.50, 0.50]
        case .density:   return [0.45, 0.45, 0.45, 0.45]
        }
    }

    /// 마지막 AMRAP 세트의 최소 목표. 이 아래면 그 세션은 미달이다.
    var amrapFloorRatio: Double {
        switch self {
        case .volume:    return 0.40
        case .intensity: return 0.50
        case .density:   return 0.45
        }
    }

    /// 밀도 세션만 휴식을 절반으로 줄인다.
    var restMultiplier: Double { self == .density ? 0.5 : 1.0 }

    /// 주간 순서 (월·수·금 가정).
    var orderInWeek: Int {
        switch self {
        case .volume: return 0
        case .intensity: return 1
        case .density: return 2
        }
    }
}

// MARK: - 세트 / 세션

struct SetTarget: Equatable, Codable, Sendable, Identifiable {
    /// 세트 순번이 곧 세션 안의 식별자다.
    var id: Int { index }
    var index: Int
    /// 목표 횟수. AMRAP 세트에서는 "최소 이만큼"이라는 뜻이다.
    var reps: Int
    var isAMRAP: Bool
}

struct ProgramSession: Equatable, Codable, Sendable {
    var week: Int
    var kind: SessionKind
    var trainingMax: Int
    var level: PushUpLevel
    /// 디로드 주간이면 전 세트 볼륨을 60%로 줄인다.
    var isDeload: Bool
    /// 재측정 주간이면 사다리 대신 최대 측정을 한다.
    var isRetest: Bool
    var sets: [SetTarget]
    var restSeconds: Int

    var totalTargetReps: Int { sets.reduce(0) { $0 + $1.reps } }
    var amrapTarget: Int { sets.last(where: \.isAMRAP)?.reps ?? 0 }
}

// MARK: - 사다리 생성

enum ProgramLadder {

    /// 졸업 조건 — 한 세트에 이만큼.
    static let goal = 100

    /// 디로드 주기(주). 4주마다 볼륨을 줄여 누적 피로를 턴다.
    static let deloadEveryWeeks = 4
    /// 재측정 주기(주). 훈련최대가 실제 실력과 벌어지는 걸 막는다.
    static let retestEveryWeeks = 7

    static let deloadFactor = 0.6
    /// 주간 총 볼륨 상한 배수. A+B+C 합이 약 7W이므로 평상시엔 걸리지 않는 안전장치다.
    static let weeklyVolumeCapMultiplier = 8.0

    static func isDeloadWeek(_ week: Int) -> Bool {
        !isRetestWeek(week) && week % deloadEveryWeeks == 0
    }

    /// 재측정이 디로드보다 우선한다 (둘 다 걸리는 주가 있다).
    static func isRetestWeek(_ week: Int) -> Bool {
        week % retestEveryWeeks == 0
    }

    /// 한 세션의 세트·휴식을 만든다. `week`는 1부터.
    static func generate(trainingMax: Int, week: Int, kind: SessionKind) -> ProgramSession {
        precondition(week >= 1, "주차는 1부터 센다")
        let max = Swift.max(1, trainingMax)
        let level = PushUpLevel.forMax(max)
        let retest = isRetestWeek(week)
        let deload = isDeloadWeek(week)
        let factor = deload ? deloadFactor : 1.0

        var sets: [SetTarget] = []
        if retest {
            // 재측정 주간은 사다리를 돌리지 않는다. 폼 유지 AMRAP 한 세트가 전부다.
            sets = [SetTarget(index: 0, reps: max, isAMRAP: true)]
        } else {
            sets = kind.fixedRatios.enumerated().map { offset, ratio in
                SetTarget(index: offset, reps: reps(ratio * factor, of: max), isAMRAP: false)
            }
            sets.append(SetTarget(
                index: sets.count,
                reps: reps(kind.amrapFloorRatio * factor, of: max),
                isAMRAP: true
            ))
        }

        let rest = retest
            ? 0
            : Int((Double(level.baseRestSeconds) * kind.restMultiplier).rounded())

        return ProgramSession(
            week: week, kind: kind, trainingMax: max, level: level,
            isDeload: deload, isRetest: retest, sets: sets, restSeconds: rest
        )
    }

    /// 한 주 세 세션.
    static func generateWeek(trainingMax: Int, week: Int) -> [ProgramSession] {
        SessionKind.allCases
            .sorted { $0.orderInWeek < $1.orderInWeek }
            .map { generate(trainingMax: trainingMax, week: week, kind: $0) }
    }

    static func weeklyTargetVolume(trainingMax: Int, week: Int) -> Int {
        generateWeek(trainingMax: trainingMax, week: week).reduce(0) { $0 + $1.totalTargetReps }
    }

    static func hasGraduated(bestSingleSet: Int) -> Bool { bestSingleSet >= goal }

    /// 그 주에 해야 할 세션 수. 재측정 주는 AMRAP 한 세션으로 끝난다.
    static func sessionsPerWeek(_ week: Int) -> Int {
        isRetestWeek(week) ? 1 : SessionKind.allCases.count
    }

    /// 그 주 `index` 번째 세션의 종류. 재측정 주는 종류가 의미 없어 볼륨으로 고정한다.
    static func kind(forSessionIndex index: Int, week: Int) -> SessionKind {
        guard !isRetestWeek(week) else { return .volume }
        let ordered = SessionKind.allCases.sorted { $0.orderInWeek < $1.orderInWeek }
        return ordered[min(max(0, index), ordered.count - 1)]
    }

    /// 100까지 남은 주 수. 최근 훈련최대 이력(오래된 것 → 최신)으로 선형 외삽한다.
    /// 아직 늘지 않았거나 이력이 부족하면 nil — 모르면 모른다고 해야지 아무 숫자나 보여주면 안 된다.
    static func estimatedWeeksTo100(history: [Int]) -> Int? {
        guard let current = history.last, current < goal else { return nil }
        let recent = history.suffix(5)          // 최근 4주치 증가분
        guard recent.count >= 2 else { return nil }

        let span = Double(recent.count - 1)
        let growthPerWeek = Double(recent.last! - recent.first!) / span
        guard growthPerWeek > 0 else { return nil }

        return Int((Double(goal - current) / growthPerWeek).rounded(.up))
    }

    private static func reps(_ ratio: Double, of max: Int) -> Int {
        Swift.max(1, Int((ratio * Double(max)).rounded()))
    }
}

// MARK: - 진행 판정

/// 한 세션의 수행 결과.
struct SessionResult: Equatable, Codable, Sendable {
    var kind: SessionKind
    /// 세트별 목표 (`ProgramSession.sets` 의 reps).
    var targets: [Int]
    /// 세트별 실제 수행.
    var achieved: [Int]

    /// AMRAP 을 제외한 고정 세트를 전부 채웠는가.
    var metFixedSets: Bool {
        guard targets.count == achieved.count, targets.count >= 2 else { return false }
        return zip(targets.dropLast(), achieved.dropLast()).allSatisfy { $1 >= $0 }
    }

    var amrapTarget: Int { targets.last ?? 0 }
    var amrapAchieved: Int { achieved.last ?? 0 }
    /// AMRAP 이 목표를 얼마나 넘었는가. 진행 판정의 실제 신호다.
    var amrapSurplus: Int { amrapAchieved - amrapTarget }
}

enum ProgramAdjustment: Equatable, Sendable {
    case increase(to: Int)
    case decrease(to: Int)
    case hold
}

/// 진행 판정 후의 상태. 호출자는 이걸 통째로 저장한다.
struct ProgressionOutcome: Equatable, Sendable {
    var trainingMax: Int
    var adjustment: ProgramAdjustment
    /// 연속 미달 주 수. 2가 되면 훈련최대를 내리고 0으로 리셋한다.
    var consecutiveMissedWeeks: Int
    /// 세트 간 휴식에 더할 초. 내려갈 때마다 30초씩 붙는다.
    var restBonusSeconds: Int
}

enum ProgressionRule {

    /// AMRAP 이 목표보다 이만큼 넘어야 올린다.
    static let surplusToAdvance = 3
    static let increaseRatio = 0.10
    static let decreaseRatio = 0.10
    static let missesBeforeBackoff = 2
    static let restBonusOnBackoff = 30

    /// **주 1회**, 그 주 세 세션이 끝난 뒤에만 부른다.
    ///
    /// 세션마다 +10%를 적용하면 주당 +33%가 되어 며칠 만에 무너진다. 한 주를 한 단위로 본다.
    static func apply(
        trainingMax: Int,
        week: Int,
        results: [SessionResult],
        consecutiveMissedWeeks: Int = 0,
        restBonusSeconds: Int = 0
    ) -> ProgressionOutcome {
        let current = max(1, trainingMax)

        func unchanged(_ adjustment: ProgramAdjustment, misses: Int, rest: Int) -> ProgressionOutcome {
            ProgressionOutcome(trainingMax: current, adjustment: adjustment,
                               consecutiveMissedWeeks: misses, restBonusSeconds: rest)
        }

        // 디로드 주간은 일부러 볼륨을 줄인 주라 성과로 판정하지 않는다.
        guard !ProgramLadder.isDeloadWeek(week) else {
            return unchanged(.hold, misses: consecutiveMissedWeeks, rest: restBonusSeconds)
        }
        // 재측정 주간도 판정 대상이 아니다. 세트가 하나뿐이라 `metFixedSets` 가 항상 false가 되어
        // 가만두면 재측정을 할 때마다 미달 한 번이 적립된다. 재측정 결과로 훈련최대를 새로 잡는 건
        // 호출자의 몫이고(`W = 새 M`), 이 함수는 판정을 거부한다.
        guard !ProgramLadder.isRetestWeek(week) else {
            return unchanged(.hold, misses: consecutiveMissedWeeks, rest: restBonusSeconds)
        }
        guard !results.isEmpty else {
            return unchanged(.hold, misses: consecutiveMissedWeeks, rest: restBonusSeconds)
        }

        let allFixedMet = results.allSatisfy(\.metFixedSets)
        let averageSurplus = Double(results.reduce(0) { $0 + $1.amrapSurplus }) / Double(results.count)

        if allFixedMet && averageSurplus >= Double(surplusToAdvance) {
            let next = current + max(1, Int((Double(current) * increaseRatio).rounded()))
            return ProgressionOutcome(trainingMax: next, adjustment: .increase(to: next),
                                      consecutiveMissedWeeks: 0, restBonusSeconds: restBonusSeconds)
        }

        let misses = consecutiveMissedWeeks + 1
        guard misses >= missesBeforeBackoff else {
            return unchanged(.hold, misses: misses, rest: restBonusSeconds)
        }

        let next = max(1, current - max(1, Int((Double(current) * decreaseRatio).rounded())))
        return ProgressionOutcome(trainingMax: next, adjustment: .decrease(to: next),
                                  consecutiveMissedWeeks: 0,
                                  restBonusSeconds: restBonusSeconds + restBonusOnBackoff)
    }
}
