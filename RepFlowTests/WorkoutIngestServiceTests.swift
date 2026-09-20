import Foundation
import SwiftData
import Testing
@testable import RepFlow

/// 워치 결과가 실제로 기록으로 남는지. 이 경로가 통째로 없어서 기록 화면이
/// 영원히 비어 있었으므로, 회귀를 막는 것이 이 스위트의 목적이다.
@MainActor
@Suite("워치 결과 영속화")
struct WorkoutIngestServiceTests {

    /// 디스크를 건드리지 않는 일회용 컨테이너.
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            WorkoutSession.self, WorkoutSet.self,
            GTGDay.self, GTGPrompt.self, UserProfile.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func report(
        exercise: ExerciseKind = .pushUp,
        totalReps: Int = 20,
        durationSec: Int = 60,
        avgTempo: Double = 3.0
    ) -> WatchPayload.WorkoutReport {
        WatchPayload.WorkoutReport(
            exercise: exercise,
            mode: .freeCount,
            totalReps: totalReps,
            durationSec: durationSec,
            avgTempo: avgTempo,
            endedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test("종료 리포트가 WorkoutSession 으로 저장된다")
    func persistsSession() throws {
        let context = try makeContext()
        let ingest = WorkoutIngestService(context: context)

        try ingest.ingest(report())

        let saved = try context.fetch(FetchDescriptor<WorkoutSession>())
        #expect(saved.count == 1)
        let session = try #require(saved.first)
        #expect(session.exercise == .pushUp)
        #expect(session.totalReps == 20)
        #expect(session.avgTempoSeconds == 3.0)
        #expect(session.endedAt == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(session.durationSeconds == 60)
    }

    @Test("세트를 쪼개 받지 못해도 전체를 1세트로 남긴다")
    func recordsSingleSet() throws {
        let context = try makeContext()
        try WorkoutIngestService(context: context).ingest(report(totalReps: 15))

        let session = try #require(try context.fetch(FetchDescriptor<WorkoutSession>()).first)
        #expect(session.sets.count == 1)
        #expect(session.sets.first?.reps == 15)
    }

    @Test("0회 세션은 빈 세트를 만들지 않는다")
    func skipsEmptySet() throws {
        let context = try makeContext()
        try WorkoutIngestService(context: context).ingest(report(totalReps: 0))

        let session = try #require(try context.fetch(FetchDescriptor<WorkoutSession>()).first)
        #expect(session.sets.isEmpty)
    }

    @Test("기록을 깨면 개인최고가 갱신된다")
    func updatesPersonalBest() throws {
        let context = try makeContext()
        context.insert(UserProfile(pushUpBest: 30))
        try context.save()

        try WorkoutIngestService(context: context).ingest(report(totalReps: 42))

        let profile = try #require(try context.fetch(FetchDescriptor<UserProfile>()).first)
        #expect(profile.pushUpBest == 42)
    }

    @Test("기록에 못 미치면 개인최고를 건드리지 않는다")
    func keepsHigherBest() throws {
        let context = try makeContext()
        context.insert(UserProfile(pushUpBest: 50))
        try context.save()

        try WorkoutIngestService(context: context).ingest(report(totalReps: 20))

        let profile = try #require(try context.fetch(FetchDescriptor<UserProfile>()).first)
        #expect(profile.pushUpBest == 50)
    }

    @Test("종목별로 각자의 기록에 들어간다")
    func routesBestByExercise() throws {
        let context = try makeContext()
        context.insert(UserProfile())
        try context.save()
        let ingest = WorkoutIngestService(context: context)

        try ingest.ingest(report(exercise: .pushUp, totalReps: 40))
        try ingest.ingest(report(exercise: .pullUp, totalReps: 11))
        try ingest.ingest(report(exercise: .dip, totalReps: 17))

        let profile = try #require(try context.fetch(FetchDescriptor<UserProfile>()).first)
        #expect(profile.pushUpBest == 40)
        #expect(profile.pullUpBest == 11)
        #expect(profile.dipBest == 17)
    }

    @Test("파이크 푸시업은 푸시업 기록을 오염시키지 않는다")
    func variantDoesNotPolluteBest() throws {
        let context = try makeContext()
        context.insert(UserProfile(pushUpBest: 10))
        try context.save()

        try WorkoutIngestService(context: context).ingest(report(exercise: .pikePushUp, totalReps: 25))

        let profile = try #require(try context.fetch(FetchDescriptor<UserProfile>()).first)
        #expect(profile.pushUpBest == 10)
    }

    @Test("프로필이 아직 없어도 저장은 성공한다")
    func survivesMissingProfile() throws {
        let context = try makeContext()
        try WorkoutIngestService(context: context).ingest(report(totalReps: 30))
        #expect(try context.fetch(FetchDescriptor<WorkoutSession>()).count == 1)
    }

    @Test("GTG 응답은 오늘자 하루 기록에 누적된다")
    func accumulatesGTG() throws {
        let context = try makeContext()
        let ingest = WorkoutIngestService(context: context)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        try ingest.ingestGTG(exercise: .pushUp, repsDone: 5, at: now)
        try ingest.ingestGTG(exercise: .pushUp, repsDone: 7, at: now.addingTimeInterval(3600))

        let days = try context.fetch(FetchDescriptor<GTGDay>())
        #expect(days.count == 1, "같은 날 같은 종목은 하루 기록 하나에 모여야 한다")
        let day = try #require(days.first)
        #expect(day.prompts.count == 2)
        #expect(day.completedReps == 12)
    }

    @Test("자정을 넘겨 도착한 응답은 수행한 날짜에 적립된다")
    func filesUnderPerformedDay() throws {
        let context = try makeContext()
        let ingest = WorkoutIngestService(context: context)
        let lateNight = Date(timeIntervalSince1970: 1_700_000_000)   // 어제 밤
        let nextMorning = lateNight.addingTimeInterval(9 * 3600)     // 날짜가 바뀐 뒤

        try ingest.ingestGTG(exercise: .pushUp, repsDone: 5, at: lateNight)
        try ingest.ingestGTG(exercise: .pushUp, repsDone: 5, at: nextMorning)

        let days = try context.fetch(FetchDescriptor<GTGDay>())
        let expected = Set([lateNight.startOfDay, nextMorning.startOfDay])
        #expect(days.count == expected.count)
        #expect(Set(days.map(\.date)) == expected)
    }

    @Test("종목이 다르면 같은 날이라도 하루 기록을 따로 만든다")
    func separatesByExercise() throws {
        let context = try makeContext()
        let ingest = WorkoutIngestService(context: context)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        try ingest.ingestGTG(exercise: .pushUp, repsDone: 5, at: now)
        try ingest.ingestGTG(exercise: .pullUp, repsDone: 3, at: now)

        #expect(try context.fetch(FetchDescriptor<GTGDay>()).count == 2)
    }

    @Test("0회 응답은 건너뛴 것으로 기록된다")
    func marksSkipped() throws {
        let context = try makeContext()
        let day = try WorkoutIngestService(context: context)
            .ingestGTG(exercise: .pushUp, repsDone: 0)
        #expect(day.prompts.first?.skipped == true)
    }

    @Test("하루 목표는 사용자 프로필을 따른다")
    func usesProfileTarget() throws {
        let context = try makeContext()
        context.insert(UserProfile(gtgDailyTarget: 120, gtgPromptCount: 12))
        try context.save()

        let day = try WorkoutIngestService(context: context)
            .ingestGTG(exercise: .pushUp, repsDone: 5)
        #expect(day.targetReps == 120)
        #expect(day.promptCount == 12)
    }
}
