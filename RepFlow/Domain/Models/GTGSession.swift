import Foundation
import SwiftData

// GTG (Grease the Groove) 하루 단위 트래킹
@Model
final class GTGDay {
    @Attribute(.unique) var id: UUID
    var date: Date                        // 자정 기준
    var exerciseRaw: String
    var targetReps: Int                   // 하루 목표 (e.g. 50)
    var promptCount: Int                  // 알림 횟수 (e.g. 10)
    var dailyMaxRPE: Int                  // 알림 당 RPE 상한 (e.g. 5 = max 50% effort)
    @Relationship(deleteRule: .cascade) var prompts: [GTGPrompt] = []

    init(
        id: UUID = UUID(),
        date: Date = .now.startOfDay,
        exercise: ExerciseKind,
        targetReps: Int = 50,
        promptCount: Int = 10,
        dailyMaxRPE: Int = 5
    ) {
        self.id = id
        self.date = date
        self.exerciseRaw = exercise.rawValue
        self.targetReps = targetReps
        self.promptCount = promptCount
        self.dailyMaxRPE = dailyMaxRPE
    }

    var exercise: ExerciseKind {
        ExerciseKind(rawValue: exerciseRaw) ?? .pushUp
    }

    var completedReps: Int {
        prompts.reduce(0) { $0 + $1.repsDone }
    }

    var progressRatio: Double {
        guard targetReps > 0 else { return 0 }
        return min(Double(completedReps) / Double(targetReps), 1.0)
    }
}

@Model
final class GTGPrompt {
    @Attribute(.unique) var id: UUID
    var firedAt: Date                     // 알림 시각
    var acknowledgedAt: Date?             // 사용자가 응답한 시각
    var suggestedReps: Int                // 추천 횟수
    var repsDone: Int                     // 실제로 한 횟수
    var skipped: Bool

    init(
        id: UUID = UUID(),
        firedAt: Date = .now,
        suggestedReps: Int,
        repsDone: Int = 0,
        skipped: Bool = false
    ) {
        self.id = id
        self.firedAt = firedAt
        self.suggestedReps = suggestedReps
        self.repsDone = repsDone
        self.skipped = skipped
    }
}

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
