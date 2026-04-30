import SwiftUI

struct RootWatchView: View {
    @Environment(WatchCoordinator.self) private var coord
    @State private var session = WatchSessionService.shared

    var body: some View {
        ZStack {
            switch coord.screen {
            case .menu:
                MenuView()
            case let .workout(exercise, mode):
                WorkoutLiveView(exercise: exercise, mode: mode)
            case let .interval(program):
                IntervalRunView(program: program)
            case let .gtgQuick(exercise, reps):
                GTGQuickView(exercise: exercise, suggestedReps: reps)
            case let .calibrate(exercise):
                CalibrationView(exercise: exercise)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: coord.screen)
        .onChange(of: session.pendingGTGPrompt?.reps) { _, _ in
            if let prompt = session.pendingGTGPrompt {
                coord.openGTGQuick(exercise: prompt.exercise, reps: prompt.reps)
                session.pendingGTGPrompt = nil
            }
        }
    }
}
