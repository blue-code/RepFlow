import Foundation
import WatchConnectivity
import WatchKit

@Observable
final class WatchSessionService: NSObject {

    static let shared = WatchSessionService()

    var isPhoneReachable: Bool = false
    var pendingGTGPrompt: (exercise: ExerciseKind, reps: Int)?

    /// 폰이 미리 밀어둔 다음 프로그램 세션. 폰이 꺼져 있어도 워치 단독으로 완주할 수 있다.
    var programSession: ProgramSession?
    var programRestBonusSeconds: Int = 0

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

    /// 운동 종료 리포트. **이것만은 유실되면 안 된다** — 폰의 기록 화면에 남는 유일한 경로다.
    /// 그래서 빠른 경로(sendMessage)와 보장 경로(transferUserInfo)로 이중 송신하고,
    /// 중복은 수신 측이 `messageId`로 제거한다.
    func sendWorkoutEnded(
        exercise: ExerciseKind,
        mode: WorkoutMode,
        totalReps: Int,
        durationSec: Int,
        avgTempo: Double
    ) {
        sendReliably([
            WatchMessageKey.action: WatchAction.workoutEnded.rawValue,
            WatchMessageKey.exercise: exercise.rawValue,
            WatchMessageKey.mode: mode.rawValue,
            WatchMessageKey.totalReps: totalReps,
            WatchMessageKey.durationSec: durationSec,
            WatchMessageKey.avgTempo: avgTempo,
            WatchMessageKey.timestamp: Date.now.timeIntervalSince1970
        ])
    }

    /// 프로그램 세션 결과. 주간 판정(주차·연속 미달·훈련최대)은 폰이 하므로 반드시 도착해야 한다.
    func sendProgramSessionCompleted(_ result: SessionResult, totalReps: Int) {
        guard let data = try? JSONEncoder().encode(result) else { return }
        sendReliably([
            WatchMessageKey.action: WatchAction.programSessionCompleted.rawValue,
            WatchMessageKey.sessionResult: data,
            WatchMessageKey.totalReps: totalReps,
            WatchMessageKey.timestamp: Date.now.timeIntervalSince1970
        ])
    }

    /// GTG 응답도 하루치 진행률에 반영되므로 보장 송신한다.
    func sendGTGAck(exercise: ExerciseKind, reps: Int) {
        sendReliably([
            WatchMessageKey.action: WatchAction.gtgPromptAcknowledged.rawValue,
            WatchMessageKey.exercise: exercise.rawValue,
            WatchMessageKey.reps: reps,
            // 큐잉된 응답이 자정을 넘겨 도착하면 엉뚱한 날짜에 적립된다.
            WatchMessageKey.timestamp: Date.now.timeIntervalSince1970
        ])
    }

    /// 실시간 표시용 — 유실돼도 다음 rep이 곧 덮어쓰므로 큐잉하지 않는다.
    private func sendMessage(_ message: [String: Any]) {
        guard let session, session.isReachable else { return }
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    /// 유실되면 안 되는 메시지. 도달 가능하면 즉시 전송(빠름) + 항상 지속 큐에도 적재(보장).
    /// 두 경로 모두 도착할 수 있으므로 `messageId`를 붙여 수신 측이 중복을 제거한다.
    private func sendReliably(_ message: [String: Any]) {
        guard let session else { return }
        var payload = message
        payload[WatchMessageKey.messageId] = UUID().uuidString

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
        session.transferUserInfo(payload)
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
        handleIncoming(message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleIncoming(applicationContext)
    }

    private func handleIncoming(_ message: [String: Any]) {
        guard let eventRaw = message[WatchMessageKey.event] as? String else { return }

        // 캘리브레이션 동기화 메시지 (민감도 / 자동 감지 토글)
        if eventRaw == CalibrationSyncKey.event {
            if let sens = message[CalibrationSyncKey.sensitivity] as? Double {
                CalibrationStore.setSensitivity(sens)
            }
            if let enabled = message[CalibrationSyncKey.autoDetectEnabled] as? Bool {
                AutoDetectSettings.setEnabled(enabled)
            }
            return
        }

        guard let event = PhoneEvent(rawValue: eventRaw) else { return }
        Task { @MainActor in
            switch event {
            case .programUpdated:
                if let data = message[WatchMessageKey.programSession] as? Data,
                   let program = try? JSONDecoder().decode(ProgramSession.self, from: data) {
                    self.programSession = program
                    self.programRestBonusSeconds = message[WatchMessageKey.restBonus] as? Int ?? 0
                }

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
