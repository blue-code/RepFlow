import Foundation

/// 워치가 보낸 `[String: Any]` 를 타입 있는 값으로 파싱한다.
///
/// WatchConnectivity 와 분리된 순수 Foundation 코드라 `WCSession` 없이 단독 테스트할 수 있다.
/// 수신 경로가 셋(sendMessage / transferUserInfo / applicationContext)인데 파싱을 각자 하면
/// 셋이 서서히 어긋나므로, 모든 경로가 이 한 곳을 통과한다.
struct WatchPayload: Equatable {

    enum Kind: Equatable {
        /// 운동 중 실시간 카운트. 유실돼도 다음 값이 덮어쓴다.
        case repCounted(totalReps: Int)
        /// 운동 종료 리포트. 기록으로 영속되어야 하는 유일한 메시지.
        case workoutEnded(WorkoutReport)
        /// GTG 알림 응답.
        case gtgAcknowledged(exercise: ExerciseKind, repsDone: Int)
    }

    struct WorkoutReport: Equatable {
        var exercise: ExerciseKind
        var mode: WorkoutMode
        var totalReps: Int
        var durationSec: Int
        var avgTempo: Double
        /// 워치가 찍은 종료 시각. 큐잉되어 한참 뒤에 도착할 수 있으므로
        /// 수신 시각(`.now`)을 기록에 쓰면 안 된다.
        var endedAt: Date

        var startedAt: Date {
            endedAt.addingTimeInterval(-Double(durationSec))
        }
    }

    var kind: Kind
    /// 이중 송신된 메시지의 중복 제거 키. 실시간 메시지에는 없다.
    var messageId: String?

    /// 파싱 실패(알 수 없는 action, 필수 필드 누락)면 nil.
    static func parse(_ message: [String: Any]) -> WatchPayload? {
        guard let actionRaw = message[WatchMessageKey.action] as? String,
              let action = WatchAction(rawValue: actionRaw) else { return nil }

        let kind: Kind

        switch action {
        case .repCounted:
            guard let reps = message[WatchMessageKey.totalReps] as? Int else { return nil }
            kind = .repCounted(totalReps: reps)

        case .workoutEnded:
            let exercise = ExerciseKind(rawValue: message[WatchMessageKey.exercise] as? String ?? "") ?? .pushUp
            let mode = WorkoutMode(rawValue: message[WatchMessageKey.mode] as? String ?? "") ?? .freeCount
            let endedAt = (message[WatchMessageKey.timestamp] as? Double)
                .map(Date.init(timeIntervalSince1970:)) ?? .now
            kind = .workoutEnded(WorkoutReport(
                exercise: exercise,
                mode: mode,
                totalReps: message[WatchMessageKey.totalReps] as? Int ?? 0,
                durationSec: message[WatchMessageKey.durationSec] as? Int ?? 0,
                avgTempo: message[WatchMessageKey.avgTempo] as? Double ?? 0,
                endedAt: endedAt
            ))

        case .gtgPromptAcknowledged:
            let exercise = ExerciseKind(rawValue: message[WatchMessageKey.exercise] as? String ?? "") ?? .pushUp
            kind = .gtgAcknowledged(
                exercise: exercise,
                repsDone: message[WatchMessageKey.reps] as? Int ?? 0
            )

        case .workoutStarted, .setCompleted, .requestProgram:
            return nil
        }

        return WatchPayload(kind: kind, messageId: message[WatchMessageKey.messageId] as? String)
    }
}
