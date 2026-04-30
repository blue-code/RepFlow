import SwiftUI
import WatchKit

struct WorkoutLiveView: View {
    let exercise: ExerciseKind
    let mode: WorkoutMode

    @Environment(WatchCoordinator.self) private var coord
    @State private var reps: Int = 0
    @State private var elapsed: Int = 0
    @State private var avgTempo: Double = 0
    @State private var startedAt: Date = .now
    @State private var ticker: Timer?
    @State private var error: String?

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(exercise.displayName)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(timeString(elapsed))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Text("\(reps)")
                .font(.system(size: 90, weight: .heavy, design: .rounded))
                .contentTransition(.numericText())
                .foregroundStyle(Color.accentColor)
                .animation(.spring(duration: 0.25), value: reps)

            Text(avgTempo > 0 ? String(format: "%.1fs/rep", avgTempo) : "준비")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                Button {
                    reps += 1
                    coord.haptic(.click)
                    sendUpdate()
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)

                Button(role: .destructive) {
                    finish()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
        .onAppear { start() }
        .onDisappear { stop() }
        .alert("오류", isPresented: .constant(error != nil), actions: {
            Button("확인") { error = nil; coord.backToMenu() }
        }, message: {
            Text(error ?? "")
        })
    }

    private func start() {
        startedAt = .now
        coord.detector.onRepDetected = { count, tempo in
            reps = count
            avgTempo = coord.detector.avgTempoSeconds
            coord.haptic(.click)
            sendUpdate()
        }
        do {
            try coord.detector.start(for: exercise)
        } catch {
            self.error = error.localizedDescription
        }
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsed = Int(Date.now.timeIntervalSince(startedAt))
        }
    }

    private func stop() {
        coord.detector.stop()
        ticker?.invalidate()
        ticker = nil
    }

    private func finish() {
        stop()
        let duration = Int(Date.now.timeIntervalSince(startedAt))
        WatchSessionService.shared.sendWorkoutEnded(
            exercise: exercise,
            mode: mode,
            totalReps: reps,
            durationSec: duration,
            avgTempo: avgTempo
        )
        coord.haptic(.success)
        coord.backToMenu()
    }

    private func sendUpdate() {
        WatchSessionService.shared.sendRepCount(reps)
    }

    private func timeString(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}
