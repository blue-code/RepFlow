import Foundation
import HealthKit

/// 워치 HKWorkoutSession 라이프사이클 관리.
/// 운동 시작 시 세션을 시작하면 워치가 백그라운드 CPU 시간을 받아서
/// 화면이 꺼져도 rep 디텍션과 햅틱이 계속 동작한다.
@Observable
final class WatchWorkoutManager: NSObject {

    static let shared = WatchWorkoutManager()

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private(set) var isRunning: Bool = false
    private(set) var heartRate: Double = 0
    private(set) var activeKcal: Double = 0
    private(set) var startedAt: Date?
    private(set) var lastError: String?

    override private init() {
        super.init()
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        var typesToRead: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { typesToRead.insert(hr) }
        if let kcal = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            typesToRead.insert(kcal)
        }
        do {
            try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func start(exercise: ExerciseKind) {
        guard HKHealthStore.isHealthDataAvailable(), session == nil else { return }

        let activity: HKWorkoutActivityType
        switch exercise {
        case .pushUp, .pikePushUp, .dip: activity = .functionalStrengthTraining
        case .pullUp, .inverseRow:       activity = .traditionalStrengthTraining
        }

        let config = HKWorkoutConfiguration()
        config.activityType = activity
        config.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self

            let now = Date()
            session.startActivity(with: now)
            builder.beginCollection(withStart: now) { [weak self] _, error in
                if let error {
                    self?.lastError = error.localizedDescription
                }
            }

            self.session = session
            self.builder = builder
            self.startedAt = now
            self.isRunning = true
            self.lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stop(totalReps: Int, exercise: ExerciseKind) {
        guard let session, let builder else {
            isRunning = false
            return
        }
        let now = Date()
        session.end()
        builder.endCollection(withEnd: now) { [weak self] _, _ in
            // 메타데이터로 rep 수와 운동 종류 기록
            let metadata: [String: Any] = [
                "RepFlowReps": totalReps,
                "RepFlowExercise": exercise.rawValue
            ]
            builder.addMetadata(metadata) { _, _ in
                builder.finishWorkout { _, _ in
                    Task { @MainActor in
                        self?.session = nil
                        self?.builder = nil
                        self?.isRunning = false
                    }
                }
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        // No-op for now — UI driven by isRunning
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.lastError = error.localizedDescription
            self.isRunning = false
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let qType = type as? HKQuantityType else { continue }
            guard let stats = workoutBuilder.statistics(for: qType) else { continue }

            switch qType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                if let hr = stats.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                    Task { @MainActor in self.heartRate = hr }
                }
            case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                if let kcal = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                    Task { @MainActor in self.activeKcal = kcal }
                }
            default:
                break
            }
        }
    }
}
