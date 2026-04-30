import Foundation
import CoreMotion

/// 가속도/자이로 기반 푸시업·풀업 자동 카운트.
/// 알고리즘: 디바이스 모션 user acceleration의 수직 성분 → 저역필터 → 피크 디텍션.
/// - 푸시업: 가슴이 내려갔다 올라올 때 양의 피크
/// - 풀업: 손목이 위로 올라갔다 내려올 때 양의 피크 (자세 다름 → 임계값 분리)
final class RepDetectorService: RepDetectorProtocol {

    private let motion = CMMotionManager()
    private let queue = OperationQueue()

    private(set) var repCount: Int = 0
    private(set) var lastRepTempoSeconds: Double = 0
    private(set) var avgTempoSeconds: Double = 0

    var onRepDetected: ((_ index: Int, _ tempo: Double) -> Void)?

    private var exercise: ExerciseKind = .pushUp
    private var lastRepAt: Date?
    private var smoothed: Double = 0
    private var inUpStroke = false
    private var lastDirectionChange: Date?

    private var tempos: [Double] = []

    // 운동별 임계값/쿨다운
    private struct Tuning {
        let upThreshold: Double          // 양의 피크 임계
        let downThreshold: Double        // 음의 피크 임계
        let minRepInterval: TimeInterval // 최소 rep 간격 (초)
        let smoothingAlpha: Double       // EMA 계수
    }

    private func tuning(for exercise: ExerciseKind) -> Tuning {
        switch exercise {
        case .pushUp, .pikePushUp:
            return .init(upThreshold: 0.18, downThreshold: -0.15, minRepInterval: 0.6, smoothingAlpha: 0.25)
        case .pullUp, .inverseRow:
            return .init(upThreshold: 0.22, downThreshold: -0.18, minRepInterval: 0.8, smoothingAlpha: 0.30)
        case .dip:
            return .init(upThreshold: 0.20, downThreshold: -0.16, minRepInterval: 0.7, smoothingAlpha: 0.25)
        }
    }

    func start(for exercise: ExerciseKind) throws {
        guard motion.isDeviceMotionAvailable else {
            throw RepDetectorError.motionUnavailable
        }
        guard !motion.isDeviceMotionActive else {
            throw RepDetectorError.alreadyRunning
        }

        self.exercise = exercise
        reset()

        motion.deviceMotionUpdateInterval = 1.0 / 50.0    // 50Hz
        motion.startDeviceMotionUpdates(to: queue) { [weak self] data, _ in
            guard let self, let data else { return }
            self.process(data)
        }
    }

    func stop() {
        if motion.isDeviceMotionActive {
            motion.stopDeviceMotionUpdates()
        }
    }

    func reset() {
        repCount = 0
        lastRepTempoSeconds = 0
        avgTempoSeconds = 0
        lastRepAt = nil
        smoothed = 0
        inUpStroke = false
        lastDirectionChange = nil
        tempos.removeAll()
    }

    private func process(_ data: CMDeviceMotion) {
        let cfg = tuning(for: exercise)

        // 중력 방향 보정된 user acceleration의 크기 + 부호
        // 푸시업/풀업의 핵심 축은 디바이스 Y축(워치 기준)
        let raw = data.userAcceleration.y * 0.3 + data.userAcceleration.z * 0.7
        smoothed = smoothed + cfg.smoothingAlpha * (raw - smoothed)

        let now = Date()

        // 상승 → 하강 전환 감지
        if !inUpStroke && smoothed > cfg.upThreshold {
            inUpStroke = true
            lastDirectionChange = now
        } else if inUpStroke && smoothed < cfg.downThreshold {
            // 한 사이클 완성 = 1 rep
            inUpStroke = false

            if let last = lastRepAt {
                let interval = now.timeIntervalSince(last)
                if interval >= cfg.minRepInterval {
                    countRep(at: now, interval: interval)
                }
            } else {
                countRep(at: now, interval: 0)
            }
        }
    }

    private func countRep(at now: Date, interval: Double) {
        repCount += 1
        lastRepAt = now
        if interval > 0 {
            tempos.append(interval)
            lastRepTempoSeconds = interval
            avgTempoSeconds = tempos.reduce(0, +) / Double(tempos.count)
        }
        let count = repCount
        let tempo = lastRepTempoSeconds
        DispatchQueue.main.async { [weak self] in
            self?.onRepDetected?(count, tempo)
        }
    }
}
