import Foundation
import SwiftData

/// 워치에서 올라온 결과를 SwiftData에 영속시킨다.
///
/// 이 타입이 생기기 전까지 `WorkoutSession` 을 insert 하는 코드는 UI 테스트용 목업
/// (`MockDataLoader`)뿐이었고, 실사용에서는 기록 화면이 영원히 비어 있었다.
/// `ModelContext` 만 받으므로 인메모리 컨테이너로 단독 테스트할 수 있다.
@MainActor
struct WorkoutIngestService {

    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// 종료된 운동을 기록으로 저장하고, 저장된 세션을 돌려준다.
    @discardableResult
    func ingest(_ report: WatchPayload.WorkoutReport) throws -> WorkoutSession {
        let session = WorkoutSession(
            startedAt: report.startedAt,
            endedAt: report.endedAt,
            exercise: report.exercise,
            mode: report.mode,
            totalReps: report.totalReps,
            avgTempoSeconds: report.avgTempo
        )
        // 워치는 아직 세트를 쪼개 보내지 않는다. 세트가 0개면 기록 화면에서
        // 세션을 펼쳤을 때 빈 칸이 되므로, 전체를 1세트로 기록해 둔다.
        if report.totalReps > 0 {
            session.sets = [
                WorkoutSet(
                    index: 0,
                    reps: report.totalReps,
                    startedAt: report.startedAt,
                    endedAt: report.endedAt,
                    avgTempoSeconds: report.avgTempo
                )
            ]
        }
        context.insert(session)
        try updatePersonalBest(exercise: report.exercise, singleSetReps: report.totalReps)
        try context.save()
        return session
    }

    /// 개인최고 갱신. 이것 역시 설정 화면의 스테퍼로만 바뀌고 실제 운동으로는
    /// 한 번도 갱신된 적이 없었다 — 대시보드의 "푸시업 최고"가 손으로 적은 숫자였다.
    ///
    /// 전용 필드가 있는 세 종목만 기록한다. 파이크/인버티드로우는 `bestFor` 가 읽기 쪽에서
    /// 각각 푸시업/풀업 기록을 빌려 쓰는데, 쓰기까지 합치면 더 어려운 변형의 낮은 횟수가
    /// 본 종목 기록을 오염시킨다.
    @discardableResult
    func updatePersonalBest(exercise: ExerciseKind, singleSetReps: Int) throws -> Int? {
        guard singleSetReps > 0 else { return nil }
        guard let profile = try context.fetch(FetchDescriptor<UserProfile>()).first else { return nil }

        switch exercise {
        case .pushUp where singleSetReps > profile.pushUpBest:
            profile.pushUpBest = singleSetReps
        case .pullUp where singleSetReps > profile.pullUpBest:
            profile.pullUpBest = singleSetReps
        case .dip where singleSetReps > profile.dipBest:
            profile.dipBest = singleSetReps
        default:
            return nil
        }
        return singleSetReps
    }

    /// GTG 응답을 오늘자 `GTGDay` 에 누적한다. 오늘 기록이 없으면 프로필 설정으로 만든다.
    @discardableResult
    func ingestGTG(exercise: ExerciseKind, repsDone: Int, at date: Date = .now) throws -> GTGDay {
        let day = try todayGTGDay(exercise: exercise, date: date)
        let prompt = GTGPrompt(
            firedAt: date,
            suggestedReps: repsDone,
            repsDone: repsDone,
            skipped: repsDone == 0
        )
        prompt.acknowledgedAt = date
        day.prompts.append(prompt)
        try context.save()
        return day
    }

    private func todayGTGDay(exercise: ExerciseKind, date: Date) throws -> GTGDay {
        let startOfDay = date.startOfDay
        let raw = exercise.rawValue
        var descriptor = FetchDescriptor<GTGDay>(
            predicate: #Predicate { $0.date == startOfDay && $0.exerciseRaw == raw }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first { return existing }

        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
        let day = GTGDay(
            date: startOfDay,
            exercise: exercise,
            targetReps: profile?.gtgDailyTarget ?? 50,
            promptCount: profile?.gtgPromptCount ?? 8
        )
        context.insert(day)
        return day
    }
}
