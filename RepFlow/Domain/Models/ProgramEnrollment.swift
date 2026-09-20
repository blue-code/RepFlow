import Foundation
import SwiftData

/// 「푸시업 100」 프로그램 진행 상태. 사용자당 하나(싱글톤처럼 다룬다).
///
/// 규칙 자체는 `Shared/PushUpProgram.swift` 의 순수 함수에 있다. 이 모델은 그 함수들이
/// 요구하는 상태(훈련최대·주차·연속 미달·추가 휴식)를 들고 있다가 넘겨줄 뿐이다.
@Model
final class ProgramEnrollment {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    /// 현재 훈련최대 `W`.
    var trainingMax: Int
    /// 주차별 `W` 이력(오래된 것 → 최신). 100까지 남은 기간 예측에 쓴다.
    var trainingMaxHistory: [Int]
    /// 1부터.
    var currentWeek: Int
    /// 이번 주에 끝낸 세션 결과. 주가 끝나면 판정 후 비운다.
    var completedSessionsThisWeek: [SessionResult]
    /// `ProgressionRule` 이 요구하는 이월 상태.
    var consecutiveMissedWeeks: Int
    var restBonusSeconds: Int
    /// 한 세트 최고 기록. 100이면 졸업.
    var bestSingleSet: Int
    var graduatedAt: Date?

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        trainingMax: Int,
        trainingMaxHistory: [Int]? = nil,
        currentWeek: Int = 1,
        completedSessionsThisWeek: [SessionResult] = [],
        consecutiveMissedWeeks: Int = 0,
        restBonusSeconds: Int = 0,
        bestSingleSet: Int = 0,
        graduatedAt: Date? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.trainingMax = trainingMax
        self.trainingMaxHistory = trainingMaxHistory ?? [trainingMax]
        self.currentWeek = currentWeek
        self.completedSessionsThisWeek = completedSessionsThisWeek
        self.consecutiveMissedWeeks = consecutiveMissedWeeks
        self.restBonusSeconds = restBonusSeconds
        self.bestSingleSet = max(bestSingleSet, trainingMax)
        self.graduatedAt = graduatedAt
    }

    // MARK: - 파생 상태

    var level: PushUpLevel { PushUpLevel.forMax(trainingMax) }
    var isRetestWeek: Bool { ProgramLadder.isRetestWeek(currentWeek) }
    var isDeloadWeek: Bool { ProgramLadder.isDeloadWeek(currentWeek) }
    var sessionsThisWeek: Int { ProgramLadder.sessionsPerWeek(currentWeek) }
    var sessionIndexInWeek: Int { completedSessionsThisWeek.count }
    var isWeekComplete: Bool { sessionIndexInWeek >= sessionsThisWeek }
    var hasGraduated: Bool { ProgramLadder.hasGraduated(bestSingleSet: bestSingleSet) }

    /// 100까지 남은 주. 정체·감소·이력 부족이면 nil.
    var estimatedWeeksTo100: Int? {
        ProgramLadder.estimatedWeeksTo100(history: trainingMaxHistory)
    }

    /// 지금 해야 할 세션. 이번 주를 다 했으면 nil.
    var nextSession: ProgramSession? {
        guard !isWeekComplete else { return nil }
        return ProgramLadder.generate(
            trainingMax: trainingMax,
            week: currentWeek,
            kind: ProgramLadder.kind(forSessionIndex: sessionIndexInWeek, week: currentWeek)
        )
    }

    /// 이번 주 남은 세션까지 포함한 목표 볼륨.
    var weeklyTargetVolume: Int {
        ProgramLadder.weeklyTargetVolume(trainingMax: trainingMax, week: currentWeek)
    }

    // MARK: - 진행

    /// 세션 하나를 기록한다. 그 주가 끝났으면 판정까지 하고 다음 주로 넘긴다.
    ///
    /// 판정은 **주 1회**만 돈다 — 세션마다 돌리면 주당 +33%가 되어 사다리가 무너진다.
    @discardableResult
    func record(_ result: SessionResult, at date: Date = .now) -> ProgramAdjustment? {
        guard !isWeekComplete else { return nil }

        completedSessionsThisWeek.append(result)
        bestSingleSet = max(bestSingleSet, result.achieved.max() ?? 0)
        if hasGraduated, graduatedAt == nil { graduatedAt = date }

        guard isWeekComplete else { return nil }
        return finishWeek(at: date)
    }

    private func finishWeek(at date: Date) -> ProgramAdjustment {
        let adjustment: ProgramAdjustment

        if isRetestWeek {
            // 재측정 주는 판정이 아니라 실측이다. 결과가 곧 새 훈련최대다.
            let measured = max(1, completedSessionsThisWeek.first?.amrapAchieved ?? trainingMax)
            adjustment = measured > trainingMax ? .increase(to: measured)
                       : measured < trainingMax ? .decrease(to: measured)
                       : .hold
            trainingMax = measured
            consecutiveMissedWeeks = 0
        } else {
            let outcome = ProgressionRule.apply(
                trainingMax: trainingMax,
                week: currentWeek,
                results: completedSessionsThisWeek,
                consecutiveMissedWeeks: consecutiveMissedWeeks,
                restBonusSeconds: restBonusSeconds
            )
            adjustment = outcome.adjustment
            trainingMax = outcome.trainingMax
            consecutiveMissedWeeks = outcome.consecutiveMissedWeeks
            restBonusSeconds = outcome.restBonusSeconds
        }

        trainingMaxHistory.append(trainingMax)
        completedSessionsThisWeek = []
        currentWeek += 1
        return adjustment
    }
}
