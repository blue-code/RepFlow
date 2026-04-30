import Foundation
import SwiftData

/// UI 테스트/스크린샷 캡처용 mock 데이터 주입.
/// 앱 실행 시 launchArguments에 "UI_TESTING_MOCK_DATA"가 있으면 적용.
@MainActor
enum MockDataLoader {
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UI_TESTING")
    }

    static var shouldInjectMockData: Bool {
        ProcessInfo.processInfo.arguments.contains("UI_TESTING_MOCK_DATA")
    }

    static var shouldSkipOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("UI_TESTING_SKIP_ONBOARDING")
    }

    static var shouldSimulatePro: Bool {
        ProcessInfo.processInfo.arguments.contains("UI_TESTING_PRO")
    }

    static func inject(into context: ModelContext) {
        guard shouldInjectMockData else { return }

        // Profile
        let profile = UserProfile(
            displayName: "Athlete",
            pushUpBest: 47,
            pullUpBest: 12,
            dipBest: 18,
            preferredGTGExercise: ExerciseKind.pushUp.rawValue,
            gtgEnabled: true,
            gtgStartHour: 9,
            gtgEndHour: 21,
            gtgDailyTarget: 80,
            gtgPromptCount: 8
        )
        context.insert(profile)

        // Recent sessions (지난 7일 분포)
        let now = Date.now
        let mockSessions: [(ExerciseKind, WorkoutMode, Int, Double, TimeInterval)] = [
            (.pushUp, .freeCount, 38, 1.4, -3600 * 1),
            (.pullUp, .emom, 24, 2.2, -3600 * 5),
            (.pushUp, .tabata, 56, 1.1, -3600 * 24),
            (.dip, .freeCount, 18, 1.8, -3600 * 30),
            (.pushUp, .amrap, 42, 1.3, -3600 * 50),
            (.pullUp, .freeCount, 14, 2.6, -3600 * 72),
            (.pushUp, .emom, 60, 1.0, -3600 * 96)
        ]

        for (exercise, mode, reps, tempo, offset) in mockSessions {
            let started = now.addingTimeInterval(offset)
            let s = WorkoutSession(
                startedAt: started,
                endedAt: started.addingTimeInterval(60 * 5),
                exercise: exercise,
                mode: mode,
                totalReps: reps,
                avgTempoSeconds: tempo
            )
            context.insert(s)
        }

        // Today's GTG
        let gtgToday = GTGDay(
            date: now.startOfDay,
            exercise: .pushUp,
            targetReps: 80,
            promptCount: 8
        )
        for i in 0..<5 {
            let prompt = GTGPrompt(
                firedAt: now.addingTimeInterval(TimeInterval(-3600 * (5 - i))),
                suggestedReps: 10,
                repsDone: 10
            )
            gtgToday.prompts.append(prompt)
        }
        context.insert(gtgToday)

        try? context.save()
    }
}
