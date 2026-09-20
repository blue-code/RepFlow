import Foundation
import Testing
@testable import RepFlow

/// 워치 → 폰 메시지 파싱. 수신 경로 셋이 모두 이 파서를 통과하므로
/// 여기가 깨지면 기록이 통째로 사라진다.
@Suite("WatchPayload 파싱")
struct WatchPayloadTests {

    private func endedMessage(
        exercise: String = ExerciseKind.pushUp.rawValue,
        mode: String = WorkoutMode.freeCount.rawValue,
        totalReps: Int = 20,
        durationSec: Int = 60,
        avgTempo: Double = 3.0,
        timestamp: Double? = 1_700_000_000,
        messageId: String? = "msg-1"
    ) -> [String: Any] {
        var m: [String: Any] = [
            WatchMessageKey.action: WatchAction.workoutEnded.rawValue,
            WatchMessageKey.exercise: exercise,
            WatchMessageKey.mode: mode,
            WatchMessageKey.totalReps: totalReps,
            WatchMessageKey.durationSec: durationSec,
            WatchMessageKey.avgTempo: avgTempo
        ]
        if let timestamp { m[WatchMessageKey.timestamp] = timestamp }
        if let messageId { m[WatchMessageKey.messageId] = messageId }
        return m
    }

    @Test("운동 종료 메시지를 리포트로 파싱한다")
    func parsesWorkoutEnded() throws {
        let payload = try #require(WatchPayload.parse(endedMessage()))
        #expect(payload.messageId == "msg-1")

        guard case .workoutEnded(let report) = payload.kind else {
            Issue.record("workoutEnded 가 아님: \(payload.kind)")
            return
        }
        #expect(report.exercise == .pushUp)
        #expect(report.mode == .freeCount)
        #expect(report.totalReps == 20)
        #expect(report.durationSec == 60)
        #expect(report.avgTempo == 3.0)
        #expect(report.endedAt == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test("시작 시각은 종료 시각에서 운동 시간을 뺀 값이다")
    func derivesStartedAt() throws {
        let payload = try #require(WatchPayload.parse(endedMessage(durationSec: 90)))
        guard case .workoutEnded(let report) = payload.kind else { return }
        #expect(report.startedAt == report.endedAt.addingTimeInterval(-90))
    }

    @Test("큐잉되어 늦게 도착해도 워치가 찍은 종료 시각을 쓴다")
    func usesWatchTimestampNotArrivalTime() throws {
        let past = Date().addingTimeInterval(-3600)
        let payload = try #require(WatchPayload.parse(
            endedMessage(timestamp: past.timeIntervalSince1970)
        ))
        guard case .workoutEnded(let report) = payload.kind else { return }
        #expect(abs(report.endedAt.timeIntervalSince(past)) < 0.001)
    }

    @Test("실시간 카운트는 messageId 없이 파싱된다")
    func parsesRepCount() throws {
        let payload = try #require(WatchPayload.parse([
            WatchMessageKey.action: WatchAction.repCounted.rawValue,
            WatchMessageKey.totalReps: 7
        ]))
        #expect(payload.kind == .repCounted(totalReps: 7))
        #expect(payload.messageId == nil)
    }

    @Test("GTG 응답을 파싱한다")
    func parsesGTGAck() throws {
        let payload = try #require(WatchPayload.parse([
            WatchMessageKey.action: WatchAction.gtgPromptAcknowledged.rawValue,
            WatchMessageKey.exercise: ExerciseKind.pullUp.rawValue,
            WatchMessageKey.reps: 5
        ]))
        #expect(payload.kind == .gtgAcknowledged(exercise: .pullUp, repsDone: 5))
    }

    @Test("모르는 메시지는 조용히 무시한다", arguments: [
        [:] as [String: Any],
        [WatchMessageKey.action: "존재하지않는액션"],
        [WatchMessageKey.action: WatchAction.repCounted.rawValue]   // totalReps 누락
    ])
    func rejectsUnknown(message: [String: Any]) {
        #expect(WatchPayload.parse(message) == nil)
    }

    @Test("알 수 없는 종목·모드는 기본값으로 떨어진다")
    func fallsBackOnUnknownEnums() throws {
        let payload = try #require(WatchPayload.parse(
            endedMessage(exercise: "버피테스트", mode: "새로운모드")
        ))
        guard case .workoutEnded(let report) = payload.kind else { return }
        #expect(report.exercise == .pushUp)
        #expect(report.mode == .freeCount)
    }
}
