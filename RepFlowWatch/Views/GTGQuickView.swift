import SwiftUI
import WatchKit

struct GTGQuickView: View {
    let exercise: ExerciseKind
    let suggestedReps: Int

    @Environment(WatchCoordinator.self) private var coord
    @State private var done: Int = 0
    @State private var started: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "bolt.heart.fill")
                    .foregroundStyle(.orange)
                Text("GTG 퀵")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(exercise.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 2)

            Text("\(done)")
                .font(.system(size: 70, weight: .heavy, design: .rounded))
                .foregroundStyle(.orange)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.2), value: done)

            Text("/ \(suggestedReps)개")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                if started {
                    Button {
                        complete()
                    } label: {
                        Label("완료", systemImage: "checkmark")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Button {
                        start()
                    } label: {
                        Label("시작", systemImage: "play.fill")
                    }
                    .frame(maxWidth: .infinity)

                    Button(role: .destructive) {
                        skip()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .frame(width: 50)
                }
            }
        }
        .padding(.horizontal, 4)
        .onDisappear { coord.detector.stop() }
    }

    private func start() {
        started = true
        coord.detector.onRepDetected = { count, _ in
            done = count
            coord.haptic(.click)
            if done >= suggestedReps {
                coord.haptic(.success)
            }
        }
        try? coord.detector.start(for: exercise, mode: .detect)
        coord.haptic(.start)
    }

    private func complete() {
        coord.detector.stop()
        WatchSessionService.shared.sendGTGAck(exercise: exercise, reps: done)
        coord.haptic(.success)
        coord.backToMenu()
    }

    private func skip() {
        coord.detector.stop()
        WatchSessionService.shared.sendGTGAck(exercise: exercise, reps: 0)
        coord.haptic(.failure)
        coord.backToMenu()
    }
}
