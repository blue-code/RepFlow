import Foundation
import SwiftData
import Testing
@testable import RepFlow

@MainActor
@Suite("프로그램 진행 상태")
struct ProgramEnrollmentTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            WorkoutSession.self, WorkoutSet.self,
            GTGDay.self, GTGPrompt.self, UserProfile.self, ProgramEnrollment.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// 지정한 여유만큼 AMRAP을 넘긴 세션 결과.
    private func perfect(_ enrollment: ProgramEnrollment, surplus: Int) -> SessionResult {
        let session = enrollment.nextSession!
        let targets = session.sets.map(\.reps)
        var achieved = targets
        achieved[achieved.count - 1] += surplus
        return SessionResult(kind: session.kind, targets: targets, achieved: achieved)
    }

    /// 한 주를 통째로 수행한다.
    ///
    /// 세션 수를 미리 읽어 고정 횟수로 돈다. `while !isWeekComplete` 로 돌면 안 된다 —
    /// 마지막 세션에서 주가 넘어가며 상태가 다음 주로 리셋되어 영원히 끝나지 않는다.
    @discardableResult
    private func runWeek(_ enrollment: ProgramEnrollment, surplus: Int) -> ProgramAdjustment? {
        var last: ProgramAdjustment?
        for _ in 0..<enrollment.sessionsThisWeek {
            last = enrollment.record(perfect(enrollment, surplus: surplus))
        }
        return last
    }

    @Test("최대 측정값으로 시작하면 레벨과 1주차가 잡힌다")
    func starts() {
        let e = ProgramEnrollment(trainingMax: 25)
        #expect(e.currentWeek == 1)
        #expect(e.level == .l4)
        #expect(e.trainingMaxHistory == [25])
        #expect(e.bestSingleSet == 25, "측정값 자체가 첫 개인최고다")
        #expect(e.hasGraduated == false)
    }

    @Test("한 주는 볼륨 → 강도 → 밀도 세 세션이다")
    func threeSessionsPerWeek() {
        let e = ProgramEnrollment(trainingMax: 20)
        #expect(e.sessionsThisWeek == 3)
        #expect(e.nextSession?.kind == .volume)
        e.record(perfect(e, surplus: 0))
        #expect(e.nextSession?.kind == .intensity)
        e.record(perfect(e, surplus: 0))
        #expect(e.nextSession?.kind == .density)
    }

    @Test("주가 끝나기 전에는 훈련최대를 건드리지 않는다")
    func judgesOncePerWeek() {
        let e = ProgramEnrollment(trainingMax: 20)
        #expect(e.record(perfect(e, surplus: 5)) == nil)
        #expect(e.trainingMax == 20, "첫 세션만으로 올리면 주당 +33%가 된다")
        #expect(e.record(perfect(e, surplus: 5)) == nil)
        #expect(e.trainingMax == 20)

        let adjustment = e.record(perfect(e, surplus: 5))
        #expect(adjustment == .increase(to: 22))
        #expect(e.trainingMax == 22)
        #expect(e.currentWeek == 2)
        #expect(e.completedSessionsThisWeek.isEmpty)
        #expect(e.trainingMaxHistory == [20, 22])
    }

    @Test("2주 연속 미달이면 내려간다")
    func backsOff() {
        let e = ProgramEnrollment(trainingMax: 20)
        #expect(runWeek(e, surplus: 0) == .hold)
        #expect(e.trainingMax == 20)
        #expect(runWeek(e, surplus: 0) == .decrease(to: 18))
        #expect(e.trainingMax == 18)
        #expect(e.restBonusSeconds == 30)
    }

    @Test("재측정 주는 한 세션이고, 결과가 곧 새 훈련최대다")
    func retestMeasures() {
        let e = ProgramEnrollment(trainingMax: 30, currentWeek: 7)
        #expect(e.isRetestWeek)
        #expect(e.sessionsThisWeek == 1)

        let session = e.nextSession!
        #expect(session.sets.count == 1)
        let result = SessionResult(kind: session.kind,
                                   targets: session.sets.map(\.reps),
                                   achieved: [37])

        #expect(e.record(result) == .increase(to: 37))
        #expect(e.trainingMax == 37)
        #expect(e.currentWeek == 8)
    }

    @Test("재측정에서 떨어져도 연속 미달로 세지 않는다")
    func retestRegressionIsNotAMiss() {
        let e = ProgramEnrollment(trainingMax: 30, currentWeek: 7, consecutiveMissedWeeks: 1)
        let session = e.nextSession!
        e.record(SessionResult(kind: session.kind,
                               targets: session.sets.map(\.reps),
                               achieved: [24]))
        #expect(e.trainingMax == 24)
        #expect(e.consecutiveMissedWeeks == 0)
    }

    @Test("디로드 주간은 볼륨이 줄고 판정도 하지 않는다")
    func deloadWeek() {
        let e = ProgramEnrollment(trainingMax: 30, currentWeek: 4)
        #expect(e.isDeloadWeek)
        #expect(e.nextSession!.isDeload)
        #expect(runWeek(e, surplus: 0) == .hold)
        #expect(e.trainingMax == 30)
        #expect(e.consecutiveMissedWeeks == 0)
    }

    @Test("한 세트 100개를 하면 졸업한다")
    func graduates() {
        let e = ProgramEnrollment(trainingMax: 90)
        let session = e.nextSession!
        var achieved = session.sets.map(\.reps)
        achieved[achieved.count - 1] = 100

        e.record(SessionResult(kind: session.kind,
                               targets: session.sets.map(\.reps),
                               achieved: achieved))
        #expect(e.hasGraduated)
        #expect(e.graduatedAt != nil)
    }

    @Test("개인최고는 뒤로 가지 않는다")
    func bestNeverRegresses() {
        let e = ProgramEnrollment(trainingMax: 40)
        let session = e.nextSession!
        var achieved = session.sets.map(\.reps)
        achieved[achieved.count - 1] = 55
        e.record(SessionResult(kind: session.kind, targets: session.sets.map(\.reps), achieved: achieved))
        #expect(e.bestSingleSet == 55)

        e.record(perfect(e, surplus: 0))
        #expect(e.bestSingleSet == 55)
    }

    @Test("이력이 쌓이면 100까지 남은 주를 예측한다")
    func predictsETA() {
        let e = ProgramEnrollment(trainingMax: 20)
        #expect(e.estimatedWeeksTo100 == nil, "이력이 한 주뿐이면 예측하지 않는다")

        for _ in 0..<4 { runWeek(e, surplus: 5) }
        #expect(e.estimatedWeeksTo100 != nil)
        #expect(e.estimatedWeeksTo100! > 0)
    }

    @Test("주차를 다 채우면 다음 세션이 없다")
    func noSessionWhenWeekDone() {
        let e = ProgramEnrollment(trainingMax: 20, currentWeek: 7)
        let session = e.nextSession!
        e.record(SessionResult(kind: session.kind, targets: session.sets.map(\.reps), achieved: [22]))
        #expect(e.currentWeek == 8)
        #expect(e.nextSession != nil, "다음 주 첫 세션이 열린다")
    }

    @Test("SwiftData에 저장하고 다시 읽어도 진행 상태가 유지된다")
    func roundTrips() throws {
        let context = try makeContext()
        let e = ProgramEnrollment(trainingMax: 20)
        context.insert(e)
        runWeek(e, surplus: 5)
        try context.save()

        let loaded = try #require(try context.fetch(FetchDescriptor<ProgramEnrollment>()).first)
        #expect(loaded.trainingMax == 22)
        #expect(loaded.currentWeek == 2)
        #expect(loaded.trainingMaxHistory == [20, 22])
    }

    @Test("이전 버전 저장소(프로그램 없음)를 열어도 깨지지 않는다")
    func opensLegacyStore() throws {
        let context = try makeContext()
        context.insert(UserProfile(pushUpBest: 30))
        try context.save()

        #expect(try context.fetch(FetchDescriptor<ProgramEnrollment>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<UserProfile>()).count == 1)
    }
}
