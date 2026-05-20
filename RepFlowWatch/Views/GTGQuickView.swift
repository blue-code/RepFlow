import SwiftUI
import WatchKit

struct GTGQuickView: View {
    let exercise: ExerciseKind
    let suggestedReps: Int

    @Environment(WatchCoordinator.self) private var coord
    @State private var done: Int = 0
    @State private var started: Bool = false
    @State private var baselineReady: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)

            Text("\(done)")
                .font(.system(size: 60, weight: .heavy, design: .rounded))
                .foregroundStyle(.orange)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.2), value: done)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if started && !baselineReady {
                Text("정지 유지 (잡음 측정)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 4) {
                Image(systemName: "bolt.heart.fill").foregroundStyle(.orange)
                Text("GTG")
                Text("·")
                Text(exercise.displayName)
                Text("·")
                Text("/ \(suggestedReps)개").monospacedDigit()
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Spacer(minLength: 2)

            HStack(spacing: 6) {
                if started {
                    Button {
                        complete()
                    } label: {
                        Label("완료", systemImage: "checkmark")
                    }
                    .tint(.green)
                    .frame(maxWidth: .infinity)
                } else {
                    Button {
                        start()
                    } label: {
                        Label("시작", systemImage: "play.fill")
                    }
                    .tint(.accentColor)
                    .frame(maxWidth: .infinity)

                    Button(role: .destructive) {
                        skip()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .frame(width: 40)
                }
            }
            .controlSize(.small)
            .font(.footnote)
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .onDisappear { coord.detector.stop() }
    }

    private func start() {
        started = true
        baselineReady = false
        coord.detector.onRepDetected = { count, _ in
            done = count
            coord.haptic(.click)
            if done >= suggestedReps {
                coord.haptic(.success)
            }
        }
        coord.detector.onSignalUpdate = { _, _, isCalibrated in
            if isCalibrated && !baselineReady {
                baselineReady = true
                coord.haptic(.start)
            }
        }
        try? coord.detector.start(for: exercise, mode: .detect)
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
