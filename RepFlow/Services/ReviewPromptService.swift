import Foundation
import StoreKit
import UIKit

/// SKStoreReviewController로 인앱 리뷰 요청 트리거.
/// 룰: 누적 운동 세션이 5개·15개·40개·100개에 도달했을 때 한 번씩만 요청
///     (Apple은 365일 이내 3회까지 허용 → 4번 임계만 사용).
/// ASO 룰: 리뷰 수와 평점은 검색 ranking에 강하게 영향.
@MainActor
enum ReviewPromptService {
    private static let triggerKey = "repflow.review.lastTriggerCount"
    private static let triggerCounts: [Int] = [5, 15, 40, 100]

    /// 운동 완료 후 호출. 임계값 도달 시 한 번 리뷰 요청.
    static func sessionCompleted(totalCount: Int) {
        guard triggerCounts.contains(totalCount) else { return }
        let last = UserDefaults.standard.integer(forKey: triggerKey)
        if last >= totalCount { return }   // 이미 트리거됨
        UserDefaults.standard.set(totalCount, forKey: triggerKey)

        // SKStoreReviewController 호출
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            // 약간의 지연으로 운동 완료 화면이 정착된 후 표시
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
}
