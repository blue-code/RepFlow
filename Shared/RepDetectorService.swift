import Foundation
import CoreMotion

/// 가속도/자이로 기반 푸시업·풀업 자동 카운트 (적응형 임계값).
///
/// 알고리즘:
/// 1. Device motion user acceleration의 Y/Z 합성 → EMA 저역 필터
/// 2. 양/음 peak detection (히스테리시스): up-stroke 시작 → up peak 갱신 → down peak로 사이클 완료 = 1 rep
/// 3. 임계값 결정:
///    - 사용자 캘리브레이션 있음: 평균 amplitude × 0.55 × sensitivity
///    - 없음: 기본값 × sensitivity
/// 4. 검증: amplitude > threshold + minInterval ≤ 사이클 시간 ≤ maxInterval
/// 5. 캘리브레이션 모드(.calibrate): 임계값 낮춰 모든 피크 수집, 카운트는 함
final class RepDetectorService: RepDetectorProtocol {

    private let motion = CMMotionManager()
    private let queue = OperationQueue()
    private let userDefaults: UserDefaults

    private(set) var repCount: Int = 0
    private(set) var lastRepTempoSeconds: Double = 0
    private(set) var avgTempoSeconds: Double = 0
    private(set) var collectedPeakAmplitudes: [Double] = []

    var onRepDetected: ((_ index: Int, _ tempo: Double) -> Void)?

    private var exercise: ExerciseKind = .pushUp
    private var mode: RepDetectorMode = .detect
    private var lastRepAt: Date?
    private var smoothed: Double = 0
    private var inUpStroke = false
    private var lastUpPeak: Double = 0
    private var lastDownPeak: Double = 0

    // 동적 임계값
    private var upThreshold: Double = 0.18
    private var downThreshold: Double = -0.15
    private var minRepInterval: TimeInterval = 0.5
    private var maxRepInterval: TimeInterval = 5.0
    private var smoothingAlpha: Double = 0.25

    private var tempos: [Double] = []

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    private struct BaselineTuning {
        let upThreshold: Double
        let downThreshold: Double
        let minInterval: TimeInterval
        let maxInterval: TimeInterval
        let smoothing: Double
    }

    private func baseline(for exercise: ExerciseKind) -> BaselineTuning {
        switch exercise {
        case .pushUp, .pikePushUp:
            return .init(upThreshold: 0.18, downThreshold: -0.15, minInterval: 0.5, maxInterval: 4.0, smoothing: 0.25)
        case .pullUp, .inverseRow:
            return .init(upThreshold: 0.22, downThreshold: -0.18, minInterval: 0.7, maxInterval: 5.0, smoothing: 0.30)
        case .dip:
            return .init(upThreshold: 0.20, downThreshold: -0.16, minInterval: 0.6, maxInterval: 4.5, smoothing: 0.25)
        }
    }

    func start(for exercise: ExerciseKind, mode: RepDetectorMode = .detect) throws {
        guard motion.isDeviceMotionAvailable else {
            throw RepDetectorError.motionUnavailable
        }
        guard !motion.isDeviceMotionActive else {
            throw RepDetectorError.alreadyRunning
        }

        self.exercise = exercise
        self.mode = mode
        reset()
        applyThresholds()

        motion.deviceMotionUpdateInterval = 1.0 / 50.0
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
        lastUpPeak = 0
        lastDownPeak = 0
        tempos.removeAll()
        collectedPeakAmplitudes.removeAll()
    }

    private func applyThresholds() {
        let base = baseline(for: exercise)
        let sensitivity = CalibrationStore.sensitivityMultiplier(from: userDefaults)
        smoothingAlpha = base.smoothing
        minRepInterval = base.minInterval
        maxRepInterval = base.maxInterval

        if mode == .calibrate {
            // 매우 낮은 임계값 — 거의 모든 피크를 수집
            upThreshold = base.upThreshold * 0.45
            downThreshold = base.downThreshold * 0.45
            return
        }

        if let cal = CalibrationStore.load(exercise, from: userDefaults), cal.sampleCount >= 3 {
            // 캘리브레이션 적용: 사용자 평균 amplitude의 55%를 컷오프로
            upThreshold = cal.avgUpAmplitude * 0.55 * sensitivity
            downThreshold = cal.avgDownAmplitude * 0.55 * sensitivity
            minRepInterval = max(0.4, min(base.minInterval, cal.avgCycleSeconds * 0.5))
        } else {
            upThreshold = base.upThreshold * sensitivity
            downThreshold = base.downThreshold * sensitivity
        }
    }

    private func process(_ data: CMDeviceMotion) {
        let raw = data.userAcceleration.y * 0.3 + data.userAcceleration.z * 0.7
        smoothed = smoothed + smoothingAlpha * (raw - smoothed)

        let now = Date()

        if !inUpStroke && smoothed > upThreshold {
            inUpStroke = true
            lastUpPeak = max(lastUpPeak, smoothed)
        } else if inUpStroke {
            if smoothed > lastUpPeak {
                lastUpPeak = smoothed
            }
            if smoothed < downThreshold {
                inUpStroke = false
                lastDownPeak = min(lastDownPeak, smoothed)

                let interval = lastRepAt.map { now.timeIntervalSince($0) } ?? 0
                let validInterval = lastRepAt == nil ||
                    (interval >= minRepInterval && interval <= maxRepInterval)

                if validInterval {
                    countRep(at: now, interval: interval, upPeak: lastUpPeak, downPeak: lastDownPeak)
                }

                lastUpPeak = 0
                lastDownPeak = 0
            }
        }

        // 너무 오래 동작이 없으면 cycle 상태 리셋
        if let last = lastRepAt, now.timeIntervalSince(last) > maxRepInterval * 2 {
            inUpStroke = false
            lastUpPeak = 0
            lastDownPeak = 0
        }
    }

    private func countRep(at now: Date, interval: Double, upPeak: Double, downPeak: Double) {
        repCount += 1
        lastRepAt = now
        if interval > 0 {
            tempos.append(interval)
            lastRepTempoSeconds = interval
            avgTempoSeconds = tempos.reduce(0, +) / Double(tempos.count)
        }
        if mode == .calibrate {
            collectedPeakAmplitudes.append(upPeak)
            collectedPeakAmplitudes.append(abs(downPeak))
        }

        let count = repCount
        let tempo = lastRepTempoSeconds
        DispatchQueue.main.async { [weak self] in
            self?.onRepDetected?(count, tempo)
        }
    }

    /// 캘리브레이션 모드에서 수집된 피크들로 UserCalibration 생성·저장
    @discardableResult
    func finalizeCalibration(for exercise: ExerciseKind) -> UserCalibration? {
        guard mode == .calibrate else { return nil }
        guard repCount >= 3 else { return nil }

        var ups: [Double] = []
        var downs: [Double] = []
        for (i, v) in collectedPeakAmplitudes.enumerated() {
            if i % 2 == 0 { ups.append(v) } else { downs.append(v) }
        }
        let avgUp = ups.isEmpty ? 0 : ups.reduce(0, +) / Double(ups.count)
        let avgDown = downs.isEmpty ? 0 : downs.reduce(0, +) / Double(downs.count)
        let avgCycle = tempos.isEmpty ? 0 : tempos.reduce(0, +) / Double(tempos.count)

        let cal = UserCalibration(
            exerciseRaw: exercise.rawValue,
            avgUpAmplitude: avgUp,
            avgDownAmplitude: -avgDown,
            avgCycleSeconds: avgCycle,
            sampleCount: repCount,
            calibratedAt: .now
        )
        CalibrationStore.save(cal, to: userDefaults)
        return cal
    }
}
