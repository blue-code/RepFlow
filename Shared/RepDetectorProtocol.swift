import Foundation

// 워치 모션 센서로 푸시업/풀업 rep 자동 디텍션
protocol RepDetectorProtocol: AnyObject {
    var repCount: Int { get }
    var lastRepTempoSeconds: Double { get }
    var avgTempoSeconds: Double { get }
    var onRepDetected: ((_ index: Int, _ tempo: Double) -> Void)? { get set }

    func start(for exercise: ExerciseKind) throws
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
