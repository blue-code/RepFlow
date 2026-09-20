import Foundation
import SwiftData
import WatchConnectivity

@Observable
final class PhoneSessionService: NSObject {

    static let shared = PhoneSessionService()

    var isWatchReachable: Bool = false
    var lastRepCountFromWatch: Int = 0
    var lastWorkoutSummary: WatchPayload.WorkoutReport?

    /// 테스트에서 인메모리 컨텍스트를 끼워 넣기 위한 훅. 평소에는 nil이고,
    /// 실제 앱은 `activeIngest` 가 앱 컨테이너를 그때그때 집어온다.
    ///
    /// 주입 대신 지연 조회를 쓰는 이유: 워치가 백그라운드로 폰을 깨우면 Scene 의 `.task` 가
    /// 돌지 않아 주입 시점이 없고, 바로 그 순간 도착하는 메시지가 저장돼야 할 기록이다.
    @ObservationIgnored
    var ingestOverride: WorkoutIngestService?

    @MainActor
    private var activeIngest: WorkoutIngestService {
        ingestOverride ?? WorkoutIngestService(context: PersistenceService.shared.mainContext)
    }

    /// 완료된 운동 세션 누적 카운트 (UserDefaults 영속) — 리뷰 프롬프트 트리거에 사용
    var totalCompletedSessions: Int {
        get { UserDefaults.standard.integer(forKey: "repflow.totalCompletedSessions") }
        set { UserDefaults.standard.set(newValue, forKey: "repflow.totalCompletedSessions") }
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

    // MARK: - 송신

    /// Watch에 GTG 프롬프트 즉시 트리거 (포어그라운드일 때 빠른 핸드오프)
    func sendGTGPrompt(exercise: ExerciseKind, suggestedReps: Int) {
        sendMessage([
            WatchMessageKey.event: PhoneEvent.gtgPrompt.rawValue,
            WatchMessageKey.exercise: exercise.rawValue,
            WatchMessageKey.reps: suggestedReps
        ])
    }

    /// Watch에 민감도 변경 동기화
    func sendSensitivityUpdate(_ value: Double) {
        let payload: [String: Any] = [
            WatchMessageKey.event: CalibrationSyncKey.event,
            CalibrationSyncKey.sensitivity: value
        ]
        // applicationContext를 사용하면 워치가 백그라운드여도 다음 활성화 시 적용됨
        try? session?.updateApplicationContext(payload)
        // 활성 시에는 즉시 sendMessage도 시도
        sendMessage(payload)
    }

    /// Watch에 자동 감지 활성화 여부 동기화 (실험적 기능 토글)
    func sendAutoDetectEnabled(_ enabled: Bool) {
        let payload: [String: Any] = [
            WatchMessageKey.event: CalibrationSyncKey.event,
            CalibrationSyncKey.autoDetectEnabled: enabled
        ]
        try? session?.updateApplicationContext(payload)
        sendMessage(payload)
    }

    /// 다음 프로그램 세션을 워치로 민다.
    ///
    /// `updateApplicationContext` 라서 워치가 꺼져 있었어도 다음 활성화 때 최신 세션을 받는다.
    /// 워치가 폰 없이 세션을 완주할 수 있어야 하므로 "요청하면 준다"가 아니라 미리 밀어둔다.
    func sendProgramSession(_ program: ProgramSession?, restBonusSeconds: Int) {
        guard let program, let data = try? JSONEncoder().encode(program) else { return }
        let payload: [String: Any] = [
            WatchMessageKey.event: PhoneEvent.programUpdated.rawValue,
            WatchMessageKey.programSession: data,
            WatchMessageKey.restBonus: restBonusSeconds
        ]
        try? session?.updateApplicationContext(payload)
        sendMessage(payload)
    }

    private func sendMessage(_ message: [String: Any]) {
        guard let session, session.isReachable else { return }
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    // MARK: - 수신 (단일 디스패처)

    /// 모든 수신 경로가 여기로 모인다. 경로별로 처리를 나눠 두면 한쪽만 고치는 사고가 난다.
    @MainActor
    func handle(_ message: [String: Any]) {
        guard let payload = WatchPayload.parse(message) else { return }
        guard !ProcessedMessageLog.isDuplicate(payload.messageId) else { return }

        switch payload.kind {
        case .repCounted(let totalReps):
            lastRepCountFromWatch = totalReps

        case .workoutEnded(let report):
            lastWorkoutSummary = report
            do {
                try activeIngest.ingest(report)
            } catch {
                // 저장 실패는 조용히 넘기지 않는다 — 기록이 통째로 사라지는 경로다.
                assertionFailure("운동 기록 저장 실패: \(error)")
            }
            totalCompletedSessions += 1
            ReviewPromptService.sessionCompleted(totalCount: totalCompletedSessions)

        case .programSessionCompleted(let result, let totalReps, let endedAt):
            do {
                try activeIngest.ingestProgramSession(
                    result, totalReps: totalReps, endedAt: endedAt
                )
            } catch {
                assertionFailure("프로그램 세션 저장 실패: \(error)")
            }
            totalCompletedSessions += 1
            ReviewPromptService.sessionCompleted(totalCount: totalCompletedSessions)

        case .gtgAcknowledged(let exercise, let repsDone, let doneAt):
            do {
                try activeIngest.ingestGTG(exercise: exercise, repsDone: repsDone, at: doneAt)
            } catch {
                assertionFailure("GTG 응답 저장 실패: \(error)")
            }
        }

        ProcessedMessageLog.remember(payload.messageId)
    }
}

// MARK: - 중복 제거

/// 종료 리포트는 sendMessage 와 transferUserInfo 로 이중 송신되므로 같은 내용이 두 번 도착한다.
/// 앱을 껐다 켜도 큐에 남은 사본이 다시 배달될 수 있어 UserDefaults 에 남긴다.
enum ProcessedMessageLog {
    private static let key = "repflow.processedMessageIds"
    private static let capacity = 50

    static func isDuplicate(_ id: String?) -> Bool {
        guard let id else { return false }   // ID 없는 실시간 메시지는 중복 판정하지 않는다
        return stored().contains(id)
    }

    static func remember(_ id: String?) {
        guard let id else { return }
        var ids = stored()
        guard !ids.contains(id) else { return }
        ids.append(id)
        if ids.count > capacity { ids.removeFirst(ids.count - capacity) }
        UserDefaults.standard.set(ids, forKey: key)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private static func stored() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }
}

// MARK: - WCSessionDelegate

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
        Task { @MainActor in self.handle(message) }
    }

    /// 워치가 폰에 닿지 못할 때 쓰는 지속 큐 경로. 이 구현이 없어서
    /// 비행기모드·워치 단독 운동의 결과가 전부 버려지고 있었다.
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in self.handle(userInfo) }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.handle(applicationContext) }
    }
}
