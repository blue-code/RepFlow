import Foundation

protocol HealthKitServiceProtocol: AnyObject {
    func requestAuthorization() async throws
    func saveWorkout(
        exercise: ExerciseKind,
        start: Date,
        end: Date,
        totalReps: Int,
        kcal: Double?
    ) async throws
}

enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "이 기기에서 HealthKit을 사용할 수 없습니다."
        case .notAuthorized: return "건강 앱 권한이 필요합니다."
        }
    }
}
