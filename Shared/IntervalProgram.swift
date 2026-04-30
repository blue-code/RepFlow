import Foundation

// 인터벌 프로그램 정의 (코드 시간 / 휴식 시간 / 라운드)
struct IntervalProgram: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var mode: WorkoutMode
    var exercise: ExerciseKind
    var workSeconds: Int
    var restSeconds: Int
    var rounds: Int
    var targetRepsPerRound: Int?

    init(
        id: UUID = UUID(),
        name: String,
        mode: WorkoutMode,
        exercise: ExerciseKind,
        workSeconds: Int,
        restSeconds: Int,
        rounds: Int,
        targetRepsPerRound: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.exercise = exercise
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.rounds = rounds
        self.targetRepsPerRound = targetRepsPerRound
    }

    static func tabata(_ exercise: ExerciseKind) -> Self {
        .init(
            name: "타바타 (20s/10s × 8)",
            mode: .tabata,
            exercise: exercise,
            workSeconds: 20,
            restSeconds: 10,
            rounds: 8
        )
    }

    static func emom(_ exercise: ExerciseKind, reps: Int, rounds: Int) -> Self {
        .init(
            name: "EMOM \(rounds)분 × \(reps)개",
            mode: .emom,
            exercise: exercise,
            workSeconds: 60,
            restSeconds: 0,
            rounds: rounds,
            targetRepsPerRound: reps
        )
    }

    static func amrap(_ exercise: ExerciseKind, minutes: Int) -> Self {
        .init(
            name: "AMRAP \(minutes)분",
            mode: .amrap,
            exercise: exercise,
            workSeconds: minutes * 60,
            restSeconds: 0,
            rounds: 1
        )
    }
}

// 라이브 진행 중인 인터벌 상태
struct IntervalState: Equatable {
    enum Phase: String { case idle, work, rest, complete }
    var phase: Phase
    var currentRound: Int       // 1-based
    var totalRounds: Int
    var remainingSeconds: Int
    var repsThisRound: Int
}
