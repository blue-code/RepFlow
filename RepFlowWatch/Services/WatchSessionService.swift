import Foundation
import WatchConnectivity
import WatchKit

@Observable
final class WatchSessionService: NSObject {

    static let shared = WatchSessionService()

    var isPhoneReachable: Bool = false
    var pendingGTGPrompt: (exercise: ExerciseKind, reps: Int)?

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

    // MARK: - 송신

    func sendRepCount(_ totalReps: Int) {
        sendMessage([
            WatchMessageKey.action: WatchAction.repCounted.rawValue,
            WatchMessageKey.totalReps: totalReps
        ])
    }

    func sendWorkoutEnded(
        exercise: ExerciseKind,
        mode: WorkoutMode,
        totalReps: Int,
        durationSec: Int,
        avgTempo: Double
    ) {
        sendMessage([
            WatchMessageKey.action: WatchAction.workoutEnded.rawValue,
            WatchMessageKey.exercise: exercise.rawValue,
            WatchMessageKey.mode: mode.rawValue,
            WatchMessageKey.totalReps: totalReps,
            WatchMessageKey.durationSec: durationSec,
            WatchMessageKey.avgTempo: avgTempo
        ])
    }

    func sendGTGAck(exercise: ExerciseKind, reps: Int) {
        sendMessage([
            WatchMessageKey.action: WatchAction.gtgPromptAcknowledged.rawValue,
            WatchMessageKey.exercise: exercise.rawValue,
            WatchMessageKey.reps: reps
        ])
    }

    private func sendMessage(_ message: [String: Any]) {
        guard let session, session.isReachable else {
            // 연결 안 되어 있으면 transferUserInfo로 폴백 (지속 큐)
            session?.transferUserInfo(message)
            return
        }
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionService: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let eventRaw = message[WatchMessageKey.event] as? String,
              let event = PhoneEvent(rawValue: eventRaw) else { return }

        Task { @MainActor in
            switch event {
            case .gtgPrompt:
                let exerciseRaw = message[WatchMessageKey.exercise] as? String ?? ExerciseKind.pushUp.rawValue
                let reps = message[WatchMessageKey.reps] as? Int ?? 5
                self.pendingGTGPrompt = (
                    ExerciseKind(rawValue: exerciseRaw) ?? .pushUp,
                    reps
                )
                WKInterfaceDevice.current().play(.notification)
            default:
                break
            }
        }
    }
}
