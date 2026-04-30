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
}

// Watch → iPhone
enum WatchAction: String {
    case workoutStarted
    case workoutEnded
    case repCounted
    case setCompleted
    case gtgPromptAcknowledged
    case requestProgram
}

// iPhone → Watch
enum PhoneEvent: String {
    case startWorkout         // 운동 시작 명령
    case stopWorkout
    case gtgPrompt            // GTG 알림: "지금 5개"
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

    /// SF Symbols 사용. iOS/watchOS 17+에 존재 검증된 것만 사용.
    /// 푸시업/풀업 전용 심볼은 없으므로 동작에 가장 가까운 figure 변형 사용.
    var symbol: String {
        switch self {
        case .pushUp:     return "figure.core.training"           // 플랭크/매트 자세
        case .pullUp:     return "figure.climbing"                // 매달려 끌어올리는 동작
        case .dip:        return "figure.strengthtraining.traditional"  // 바벨/딥스 바
        case .inverseRow: return "figure.rower"                   // 당기는 동작
        case .pikePushUp: return "figure.flexibility"             // 다운독 자세 유사
        }
    }
}

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
