import Foundation

// GTG 알림 스케줄러
protocol GTGSchedulerProtocol: AnyObject {
    /// 사용자 프로필 기준으로 오늘의 알림을 다시 예약한다.
    func scheduleToday(profile: UserProfile) async throws
    /// 모든 GTG 알림 취소
    func cancelAll() async
    /// 권한 요청
    func requestAuthorization() async -> Bool
}

enum GTGSchedulerError: LocalizedError {
    case notAuthorized
    case invalidWindow

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "알림 권한이 필요합니다."
        case .invalidWindow: return "GTG 시간 범위가 올바르지 않습니다."
        }
    }
}
