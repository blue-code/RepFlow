import Foundation
import SwiftData

// 한 번의 운동 세션 (여러 세트 포함 가능)
@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var exerciseRaw: String
    var modeRaw: String
    var totalReps: Int
    var avgTempoSeconds: Double          // 평균 1rep 소요 시간(초)
    var rpe: Int?                         // 1~10, 사용자 입력
    var notes: String?
    @Relationship(deleteRule: .cascade) var sets: [WorkoutSet] = []

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        exercise: ExerciseKind,
        mode: WorkoutMode,
        totalReps: Int = 0,
        avgTempoSeconds: Double = 0,
        rpe: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.exerciseRaw = exercise.rawValue
        self.modeRaw = mode.rawValue
        self.totalReps = totalReps
        self.avgTempoSeconds = avgTempoSeconds
        self.rpe = rpe
        self.notes = notes
    }

    var exercise: ExerciseKind {
        ExerciseKind(rawValue: exerciseRaw) ?? .pushUp
    }

    var mode: WorkoutMode {
        WorkoutMode(rawValue: modeRaw) ?? .freeCount
    }

    var durationSeconds: TimeInterval {
        guard let endedAt else { return 0 }
        return endedAt.timeIntervalSince(startedAt)
    }
}

@Model
final class WorkoutSet {
    @Attribute(.unique) var id: UUID
    var index: Int
    var reps: Int
    var startedAt: Date
    var endedAt: Date?
    var avgTempoSeconds: Double          // 이 세트의 평균 rep 속도

    init(
        id: UUID = UUID(),
        index: Int,
        reps: Int = 0,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        avgTempoSeconds: Double = 0
    ) {
        self.id = id
        self.index = index
        self.reps = reps
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.avgTempoSeconds = avgTempoSeconds
    }
}
