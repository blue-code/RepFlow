import Foundation
import SwiftData
import Testing
@testable import RepFlow

/// 폰 → 워치(세션 전달) → 폰(결과 회수) 왕복.
/// 워치는 주차·연속 미달·훈련최대 이력을 들고 있지 않으므로, 판정은 폰이 해야 한다.
@MainActor
@Suite("워치 프로그램 세션 왕복")
struct ProgramWatchSyncTests {

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

    /// 워치가 실제로 보내는 것과 같은 형태의 메시지.
    private func message(for result: SessionResult, totalReps: Int, endedAt: Date) -> [String: Any] {
        [
            WatchMessageKey.action: WatchAction.programSessionCompleted.rawValue,
            WatchMessageKey.sessionResult: try! JSONEncoder().encode(result),
            WatchMessageKey.totalReps: totalReps,
            WatchMessageKey.timestamp: endedAt.timeIntervalSince1970,
            WatchMessageKey.messageId: UUID().uuidString
        ]
    }

    @Test("ProgramSession 은 JSON 왕복을 견딘다 — 워치로 통째로 건너간다")
    func sessionEncodesRoundTrip() throws {
        let original = ProgramLadder.generate(trainingMax: 32, week: 3, kind: .intensity)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProgramSession.self, from: data)
        #expect(decoded == original)
    }

    @Test("SessionResult 도 왕복을 견딘다 — 워치가 돌려보내는 형식")
    func resultEncodesRoundTrip() throws {
        let original = SessionResult(kind: .density, targets: [14, 14, 14, 14, 14], achieved: [14, 14, 14, 13, 20])
        let decoded = try JSONDecoder().decode(SessionResult.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
        #expect(decoded.metFixedSets == false)
    }

    @Test("워치 메시지가 파싱되어 결과와 종료 시각이 살아 있다")
    func parsesWatchMessage() throws {
        let result = SessionResult(kind: .volume, targets: [13, 16, 13, 13, 13], achieved: [13, 16, 13, 13, 19])
        let endedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let payload = try #require(WatchPayload.parse(message(for: result, totalReps: 74, endedAt: endedAt)))

        guard case .programSessionCompleted(let decoded, let totalReps, let at) = payload.kind else {
            Issue.record("programSessionCompleted 가 아님: \(payload.kind)")
            return
        }
        #expect(decoded == result)
        #expect(totalReps == 74)
        #expect(at == endedAt)
        #expect(payload.messageId != nil, "유실되면 안 되는 메시지라 ID가 붙는다")
    }

    @Test("결과가 깨져 있으면 조용히 무시한다")
    func rejectsCorruptResult() {
        #expect(WatchPayload.parse([
            WatchMessageKey.action: WatchAction.programSessionCompleted.rawValue,
            WatchMessageKey.sessionResult: Data("망가진데이터".utf8)
        ]) == nil)
    }

    @Test("워치에서 완주한 세션이 기록되고 주차가 넘어간다")
    func ingestsAndAdvancesWeek() throws {
        let context = try makeContext()
        let enrollment = ProgramEnrollment(trainingMax: 20)
        context.insert(enrollment)
        try context.save()

        let ingest = WorkoutIngestService(context: context)
        var lastAdjustment: ProgramAdjustment?
        for _ in 0..<enrollment.sessionsThisWeek {
            let session = try #require(enrollment.nextSession)
            let targets = session.sets.map(\.reps)
            var achieved = targets
            achieved[achieved.count - 1] += 5
            lastAdjustment = try ingest.ingestProgramSession(
                SessionResult(kind: session.kind, targets: targets, achieved: achieved),
                totalReps: achieved.reduce(0, +),
                endedAt: .now
            )
        }

        #expect(lastAdjustment == .increase(to: 22))
        #expect(enrollment.trainingMax == 22)
        #expect(enrollment.currentWeek == 2)
        // 프로그램 세션도 일반 운동 기록으로 남아야 기록 화면에 보인다.
        #expect(try context.fetch(FetchDescriptor<WorkoutSession>()).count == 3)
    }

    @Test("등록이 없으면 운동 기록만 남기고 판정은 건너뛴다")
    func toleratesMissingEnrollment() throws {
        let context = try makeContext()
        let ingest = WorkoutIngestService(context: context)

        let adjustment = try ingest.ingestProgramSession(
            SessionResult(kind: .volume, targets: [8, 10, 8, 8, 8], achieved: [8, 10, 8, 8, 11]),
            totalReps: 45,
            endedAt: .now
        )
        #expect(adjustment == nil)
        #expect(try context.fetch(FetchDescriptor<WorkoutSession>()).count == 1)
    }
}
