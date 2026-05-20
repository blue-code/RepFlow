import Foundation
import CoreMotion

/// 가속도 + 자이로 결합 신호 기반 rep 자동 카운트 (v3).
///
/// 알고리즘:
/// 1. Device motion에서 두 신호 추출
///    - vertical: gravity 벡터에 user acceleration 투영 (자세 무관 수직 가속도)
///    - gyroMag: rotation rate 벡터 크기 (손목 회전 강도)
/// 2. 결합 신호 combined = sVertical + sign(sVertical) × sGyro × kGyro
///    푸시업 시 손목 자체 가속도가 작아도 회전 성분이 amplitude를 끌어올림.
/// 3. Adaptive baseline: 시작 후 noiseWindow(1.5초)간 사용자 정지 상태의
///    잡음을 95p로 측정 → noise floor × 2.5를 임계값으로 자동 설정.
///    그래서 사용자별/세션별 잡음 차이에 자동 적응.
/// 4. Zero-crossing detection: 결합 신호의 부호가 +threshold ↔ -threshold를
///    가로지를 때 half-cycle 완료. 두 half-cycle = 1 rep. 각 half-cycle 중
///    max |combined|가 threshold 이상이어야 valid (잡음 무시).
/// 5. 캘리브레이션 모드(.calibrate): 임계값을 낮춰 모든 사이클 수집.
final class RepDetectorService: RepDetectorProtocol {

    private let motion = CMMotionManager()
    private let queue = OperationQueue()
    private let userDefaults: UserDefaults

    private(set) var repCount: Int = 0
    private(set) var lastRepTempoSeconds: Double = 0
    private(set) var avgTempoSeconds: Double = 0
    private(set) var collectedPeakAmplitudes: [Double] = []

    var onRepDetected: ((_ index: Int, _ tempo: Double) -> Void)?
    var onSignalUpdate: ((_ value: Double, _ threshold: Double, _ isCalibrated: Bool) -> Void)?

    private var exercise: ExerciseKind = .pushUp
    private var mode: RepDetectorMode = .detect

    // EMA 신호
    private var sVertical: Double = 0
    private var sGyro: Double = 0

    // 적응형 baseline
    private let noiseWindow: TimeInterval = 1.5
    private var startedAt: Date?
    private var noiseSamples: [Double] = []
    private var baselineLocked: Bool = false
    private var threshold: Double = 0       // 최종 적용 임계값 (절댓값)

    // 사이클 상태
    private var lastSign: Int = 0
    private var halfCycleMaxAmp: Double = 0
    private var halfCycleCount: Int = 0
    private var lastRepAt: Date?

    private var tempos: [Double] = []

    // 튜닝
    private var smoothingAlpha: Double = 0.22
    private var gyroWeight: Double = 0.05    // gyro magnitude를 amplitude에 결합하는 비율
    private var minRepInterval: TimeInterval = 0.35
    private var maxRepInterval: TimeInterval = 8.0
    private var absoluteMinThreshold: Double = 0.02
    private var thresholdMultiplier: Double = 2.5

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    private struct BaselineTuning {
        let minInterval: TimeInterval
        let maxInterval: TimeInterval
        let smoothing: Double
        let gyroWeight: Double
        let thresholdMultiplier: Double
        let absoluteMinThreshold: Double
    }

    private func baseline(for exercise: ExerciseKind) -> BaselineTuning {
        switch exercise {
        case .pushUp, .pikePushUp:
            // 푸시업: 손목 자체 변위 작음 → gyro weight 높임, threshold mult 낮춤
            return .init(minInterval: 0.35, maxInterval: 8.0, smoothing: 0.22,
                         gyroWeight: 0.08, thresholdMultiplier: 2.2, absoluteMinThreshold: 0.020)
        case .pullUp, .inverseRow:
            // 풀업: 손목 변위 큼 → vertical 신호 비중 높임
            return .init(minInterval: 0.5, maxInterval: 8.0, smoothing: 0.25,
                         gyroWeight: 0.04, thresholdMultiplier: 2.5, absoluteMinThreshold: 0.040)
        case .dip:
            return .init(minInterval: 0.4, maxInterval: 8.0, smoothing: 0.22,
                         gyroWeight: 0.06, thresholdMultiplier: 2.3, absoluteMinThreshold: 0.030)
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
        applyTuning()

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
        sVertical = 0
        sGyro = 0
        lastSign = 0
        halfCycleMaxAmp = 0
        halfCycleCount = 0
        startedAt = nil
        noiseSamples.removeAll()
        baselineLocked = false
        threshold = 0
        tempos.removeAll()
        collectedPeakAmplitudes.removeAll()
    }

    private func applyTuning() {
        let base = baseline(for: exercise)
        let sensitivity = CalibrationStore.sensitivityMultiplier(from: userDefaults)
        smoothingAlpha = base.smoothing
        minRepInterval = base.minInterval
        maxRepInterval = base.maxInterval
        gyroWeight = base.gyroWeight
        // sensitivity > 1 = 덜 민감 (threshold 올림). < 1 = 더 민감.
        thresholdMultiplier = base.thresholdMultiplier * sensitivity
        absoluteMinThreshold = base.absoluteMinThreshold * sensitivity

        if mode == .calibrate {
            // 캘리브레이션 모드는 더 관대하게
            thresholdMultiplier *= 0.7
            absoluteMinThreshold *= 0.6
        }
    }

    private func process(_ data: CMDeviceMotion) {
        let g = data.gravity
        let a = data.userAcceleration
        let r = data.rotationRate

        // 수직 가속도 (gravity projection, +위 / -아래)
        let vertical = -(a.x * g.x + a.y * g.y + a.z * g.z)
        // 자이로 magnitude (rad/s)
        let gyroMag = sqrt(r.x * r.x + r.y * r.y + r.z * r.z)

        // EMA 저역 필터
        sVertical += smoothingAlpha * (vertical - sVertical)
        sGyro += smoothingAlpha * (gyroMag - sGyro)

        // 결합 신호: 수직 가속도에 gyro magnitude를 동부호로 보강
        let signCarrier: Double = sVertical >= 0 ? 1 : -1
        let combined = sVertical + signCarrier * sGyro * gyroWeight

        let now = Date()
        if startedAt == nil { startedAt = now }

        // Baseline 측정 단계
        if !baselineLocked {
            noiseSamples.append(abs(combined))
            if let start = startedAt, now.timeIntervalSince(start) >= noiseWindow {
                lockBaseline()
            }
            emitSignal(combined, isCalibrated: false)
            return
        }

        emitSignal(combined, isCalibrated: true)

        // Zero-crossing with threshold gate
        let absC = abs(combined)
        let sign: Int
        if combined > threshold { sign = 1 }
        else if combined < -threshold { sign = -1 }
        else { sign = 0 }

        if sign != 0 {
            if lastSign != 0 && sign != lastSign {
                // half-cycle 완료
                if halfCycleMaxAmp >= threshold {
                    halfCycleCount += 1
                    if halfCycleCount >= 2 {
                        completeRep(at: now, peakAmp: halfCycleMaxAmp)
                        halfCycleCount = 0
                    }
                }
                halfCycleMaxAmp = absC
            }
            lastSign = sign
        }
        halfCycleMaxAmp = max(halfCycleMaxAmp, absC)

        // 너무 오래 활동 없으면 cycle 상태 리셋 (false continuation 방지)
        if let last = lastRepAt, now.timeIntervalSince(last) > maxRepInterval * 1.5 {
            halfCycleCount = 0
            halfCycleMaxAmp = 0
            lastSign = 0
        }
    }

    private func lockBaseline() {
        baselineLocked = true
        let sorted = noiseSamples.sorted()
        let idx = sorted.isEmpty ? 0 : min(sorted.count - 1, Int(Double(sorted.count) * 0.95))
        let noiseFloor = sorted.isEmpty ? 0 : sorted[idx]
        threshold = max(noiseFloor * thresholdMultiplier, absoluteMinThreshold)
        noiseSamples.removeAll(keepingCapacity: false)
    }

    private func completeRep(at now: Date, peakAmp: Double) {
        let interval = lastRepAt.map { now.timeIntervalSince($0) } ?? 0
        let validInterval = lastRepAt == nil ||
            (interval >= minRepInterval && interval <= maxRepInterval)
        guard validInterval else { return }

        repCount += 1
        lastRepAt = now
        if interval > 0 {
            tempos.append(interval)
            lastRepTempoSeconds = interval
            avgTempoSeconds = tempos.reduce(0, +) / Double(tempos.count)
        }
        if mode == .calibrate {
            collectedPeakAmplitudes.append(peakAmp)
        }

        let count = repCount
        let tempo = lastRepTempoSeconds
        DispatchQueue.main.async { [weak self] in
            self?.onRepDetected?(count, tempo)
        }
    }

    private func emitSignal(_ value: Double, isCalibrated: Bool) {
        let t = threshold
        DispatchQueue.main.async { [weak self] in
            self?.onSignalUpdate?(value, t, isCalibrated)
        }
    }

    /// 캘리브레이션 모드에서 수집된 peak amplitude로 UserCalibration 저장.
    /// v3는 단일 amplitude만 사용 (zero-crossing 알고리즘이라 up/down 구분 불필요).
    @discardableResult
    func finalizeCalibration(for exercise: ExerciseKind) -> UserCalibration? {
        guard mode == .calibrate else { return nil }
        guard repCount >= 3 else { return nil }

        let avgAmp = collectedPeakAmplitudes.isEmpty
            ? 0
            : collectedPeakAmplitudes.reduce(0, +) / Double(collectedPeakAmplitudes.count)
        let avgCycle = tempos.isEmpty ? 0 : tempos.reduce(0, +) / Double(tempos.count)

        let cal = UserCalibration(
            exerciseRaw: exercise.rawValue,
            avgUpAmplitude: avgAmp,
            avgDownAmplitude: -avgAmp,
            avgCycleSeconds: avgCycle,
            sampleCount: repCount,
            calibratedAt: .now,
            algorithmVersion: RepDetectorAlgorithm.current
        )
        CalibrationStore.save(cal, to: userDefaults)
        return cal
    }
}
