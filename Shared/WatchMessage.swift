import Foundation

// Watch ↔ iPhone 통신 키
enum WatchMessageKey {
    static let action = "action"
    static let event = "event"
    static let exercise = "exercise"
    static let mode = "mode"
    static let reps = "reps"
    static let setIndex = "setIndex"
    static let totalSets = "totalSets"
    static let restSeconds = "restSeconds"
    static let workSeconds = "workSeconds"
    static let totalReps = "totalReps"
    static let durationSec = "durationSec"
    static let avgTempo = "avgTempo"
    static let timestamp = "timestamp"
    static let payload = "payload"
    /// 메시지 고유 ID. 종료 리포트는 sendMessage + transferUserInfo로 이중 송신되므로
    /// 수신 측이 이 값으로 중복을 제거한다.
    static let messageId = "messageId"
    /// 폰 → 워치: 다음 프로그램 세션(JSON). 워치가 폰 없이 진행할 수 있도록 미리 밀어둔다.
    static let programSession = "programSession"
    static let restBonus = "restBonus"
    /// 워치 → 폰: 끝난 프로그램 세션 결과(JSON).
    static let sessionResult = "sessionResult"
}

// Watch → iPhone
enum WatchAction: String {
    case workoutStarted
    case workoutEnded
    case repCounted
    case setCompleted
    case gtgPromptAcknowledged
    case requestProgram
    /// 프로그램 세션 완료. 폰이 주간 판정까지 한다.
    case programSessionCompleted
}

// iPhone → Watch
enum PhoneEvent: String {
    case startWorkout         // 운동 시작 명령
    case stopWorkout
    case gtgPrompt            // GTG 알림: "지금 5개"
    /// 다음 프로그램 세션이 바뀜(주차 진행·훈련최대 변경). applicationContext 로 밀어
    /// 워치가 꺼져 있었어도 다음 활성화 때 최신 세션을 갖게 한다.
    case programUpdated
}

// 공유 운동 종류
enum ExerciseKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case pushUp
    case pullUp
    case dip
    case inverseRow
    case pikePushUp

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pushUp: return "푸시업"
        case .pullUp: return "풀업"
        case .dip: return "딥스"
        case .inverseRow: return "인버티드 로우"
        case .pikePushUp: return "파이크 푸시업"
        }
    }

    /// 커스텀 픽토그램 자산 이름 (Asset Catalog에 imageset으로 등록됨, template-rendering).
    /// SF Symbols에는 push-up/pull-up 전용 심볼이 없어 직접 디자인.
    var assetName: String {
        switch self {
        case .pushUp:     return "exercise_pushup"
        case .pullUp:     return "exercise_pullup"
        case .dip:        return "exercise_dip"
        case .inverseRow: return "exercise_row"
        case .pikePushUp: return "exercise_pike"
        }
    }

    /// 호환성을 위해 SF Symbol fallback 유지 (사용처 마이그레이션 후 제거 가능).
    var symbol: String { assetName }
}

#if canImport(SwiftUI)
import SwiftUI

extension ExerciseKind {
    /// 커스텀 픽토그램. .template renderingMode → SwiftUI .foregroundStyle 로 색 적용.
    var pictogram: Image {
        Image(assetName).renderable()
    }
}

private extension Image {
    func renderable() -> Image {
        self.renderingMode(.template)
    }
}
#endif

// 운동 모드
enum WorkoutMode: String, Codable, CaseIterable, Hashable {
    case freeCount     // 자유 카운트
    case sets          // 정해진 세트 (예: 5x10)
    case emom          // EMOM
    case tabata        // 20초 운동/10초 휴식 x 8
    case amrap         // 정해진 시간 동안 최대 횟수
    case gtgQuick      // GTG: 즉석 5-10개

    var displayName: String {
        switch self {
        case .freeCount: return "프리 카운트"
        case .sets: return "세트 모드"
        case .emom: return "EMOM"
        case .tabata: return "타바타"
        case .amrap: return "AMRAP"
        case .gtgQuick: return "GTG 퀵"
        }
    }
}
