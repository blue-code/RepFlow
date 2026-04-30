import Foundation

// 동작 모드
enum RepDetectorMode {
    case detect       // 정상 카운트 모드
    case calibrate    // 캘리브레이션 모드 (피크 amplitude만 수집)
}

// 워치 모션 센서로 푸시업/풀업 rep 자동 디텍션
protocol RepDetectorProtocol: AnyObject {
    var repCount: Int { get }
    var lastRepTempoSeconds: Double { get }
    var avgTempoSeconds: Double { get }
    var collectedPeakAmplitudes: [Double] { get }

    var onRepDetected: ((_ index: Int, _ tempo: Double) -> Void)? { get set }

    func start(for exercise: ExerciseKind, mode: RepDetectorMode) throws
    func stop()
    func reset()
}

enum RepDetectorError: LocalizedError {
    case motionUnavailable
    case alreadyRunning

    var errorDescription: String? {
        switch self {
        case .motionUnavailable: return "이 기기에서 모션 센서를 사용할 수 없습니다."
        case .alreadyRunning: return "이미 카운트가 진행 중입니다."
        }
    }
}

// MARK: - 사용자 캘리브레이션

struct UserCalibration: Codable, Equatable {
    var exerciseRaw: String
    var avgUpAmplitude: Double
    var avgDownAmplitude: Double      // 음수로 저장
    var avgCycleSeconds: Double
    var sampleCount: Int
    var calibratedAt: Date

    var exercise: ExerciseKind {
        ExerciseKind(rawValue: exerciseRaw) ?? .pushUp
    }
}

enum CalibrationStore {
    private static func key(_ exercise: ExerciseKind) -> String {
        "repflow.calibration.\(exercise.rawValue)"
    }
    private static let sensitivityKey = "repflow.sensitivity"

    static func load(_ exercise: ExerciseKind, from defaults: UserDefaults = .standard) -> UserCalibration? {
        guard let data = defaults.data(forKey: key(exercise)) else { return nil }
        return try? JSONDecoder().decode(UserCalibration.self, from: data)
    }

    static func save(_ cal: UserCalibration, to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(cal) {
            defaults.set(data, forKey: key(cal.exercise))
        }
    }

    static func clear(_ exercise: ExerciseKind, from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key(exercise))
    }

    /// 0.7 (high sensitivity, lower threshold) ~ 1.3 (low sensitivity, higher threshold). default 1.0
    static func sensitivityMultiplier(from defaults: UserDefaults = .standard) -> Double {
        let v = defaults.double(forKey: sensitivityKey)
        return v == 0 ? 1.0 : v
    }

    static func setSensitivity(_ value: Double, to defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: sensitivityKey)
    }
}

// 캘리브레이션 동기화 메시지 키 (iPhone Settings 변경 → Watch UserDefaults 동기화)
enum CalibrationSyncKey {
    static let event = "calibrationSync"
    static let sensitivity = "sensitivity"
    static let exerciseRaw = "exercise"
    static let calibrationData = "calibrationData"
    static let clearCalibrationFor = "clearCalibration"
}
