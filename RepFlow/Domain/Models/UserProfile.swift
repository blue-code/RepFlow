import Foundation
import SwiftData

// 사용자 1RM/Best Set 등 트래킹
@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var pushUpBest: Int                   // 한 세트 최고 기록
    var pullUpBest: Int
    var dipBest: Int
    var preferredGTGExercise: String      // ExerciseKind.rawValue
    var gtgEnabled: Bool
    var gtgStartHour: Int                 // 알림 시작 시각 (0~23)
    var gtgEndHour: Int                   // 알림 종료 시각
    var gtgDailyTarget: Int
    var gtgPromptCount: Int
    var notificationSoundEnabled: Bool
    var hapticEnabled: Bool

    init(
        id: UUID = UUID(),
        displayName: String = "Athlete",
        pushUpBest: Int = 0,
        pullUpBest: Int = 0,
        dipBest: Int = 0,
        preferredGTGExercise: String = ExerciseKind.pushUp.rawValue,
        gtgEnabled: Bool = false,
        gtgStartHour: Int = 9,
        gtgEndHour: Int = 21,
        gtgDailyTarget: Int = 50,
        gtgPromptCount: Int = 8,
        notificationSoundEnabled: Bool = true,
        hapticEnabled: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.pushUpBest = pushUpBest
        self.pullUpBest = pullUpBest
        self.dipBest = dipBest
        self.preferredGTGExercise = preferredGTGExercise
        self.gtgEnabled = gtgEnabled
        self.gtgStartHour = gtgStartHour
        self.gtgEndHour = gtgEndHour
        self.gtgDailyTarget = gtgDailyTarget
        self.gtgPromptCount = gtgPromptCount
        self.notificationSoundEnabled = notificationSoundEnabled
        self.hapticEnabled = hapticEnabled
    }

    var bestFor: (ExerciseKind) -> Int {
        { kind in
            switch kind {
            case .pushUp, .pikePushUp: return self.pushUpBest
            case .pullUp, .inverseRow: return self.pullUpBest
            case .dip: return self.dipBest
            }
        }
    }
}
