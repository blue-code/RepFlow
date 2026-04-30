import Foundation
import WatchConnectivity

@Observable
final class PhoneSessionService: NSObject {

    static let shared = PhoneSessionService()

    var isWatchReachable: Bool = false
    var lastRepCountFromWatch: Int = 0
    var lastWorkoutSummary: WorkoutSummary?

    struct WorkoutSummary: Equatable {
        var exercise: ExerciseKind
        var mode: WorkoutMode
        var totalReps: Int
        var durationSec: Int
        var avgTempo: Double
        var endedAt: Date
    }

    private var session: WCSession?

    override private init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    /// Watch에 GTG 프롬프트 즉시 트리거 (포어그라운드일 때 빠른 핸드오프)
    func sendGTGPrompt(exercise: ExerciseKind, suggestedReps: Int) {
        sendMessage([
            WatchMessageKey.event: PhoneEvent.gtgPrompt.rawValue,
            WatchMessageKey.exercise: exercise.rawValue,
            WatchMessageKey.reps: suggestedReps
        ])
    }

    private func sendMessage(_ message: [String: Any]) {
        guard let session, session.isReachable else { return }
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }
}

extension PhoneSessionService: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let actionRaw = message[WatchMessageKey.action] as? String,
              let action = WatchAction(rawValue: actionRaw) else { return }

        Task { @MainActor in
            switch action {
            case .repCounted:
                self.lastRepCountFromWatch = message[WatchMessageKey.totalReps] as? Int ?? 0
            case .workoutEnded:
                let exerciseRaw = message[WatchMessageKey.exercise] as? String ?? ExerciseKind.pushUp.rawValue
                let modeRaw = message[WatchMessageKey.mode] as? String ?? WorkoutMode.freeCount.rawValue
                let summary = WorkoutSummary(
                    exercise: ExerciseKind(rawValue: exerciseRaw) ?? .pushUp,
                    mode: WorkoutMode(rawValue: modeRaw) ?? .freeCount,
                    totalReps: message[WatchMessageKey.totalReps] as? Int ?? 0,
                    durationSec: message[WatchMessageKey.durationSec] as? Int ?? 0,
                    avgTempo: message[WatchMessageKey.avgTempo] as? Double ?? 0,
                    endedAt: .now
                )
                self.lastWorkoutSummary = summary
            default:
                break
            }
        }
    }
}
