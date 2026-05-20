import SwiftUI
import WatchKit

struct WorkoutLiveView: View {
    let exercise: ExerciseKind
    let mode: WorkoutMode

    @Environment(WatchCoordinator.self) private var coord
    @State private var workoutManager = WatchWorkoutManager.shared
    @State private var reps: Int = 0
    @State private var elapsed: Int = 0
    @State private var avgTempo: Double = 0
    @State private var startedAt: Date = .now
    @State private var ticker: Timer?
    @State private var error: String?
    @State private var baselineReady: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)

            Text("\(reps)")
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .contentTransition(.numericText())
                .foregroundStyle(Color.accentColor)
                .animation(.spring(duration: 0.25), value: reps)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if !baselineReady {
                Text("정지 유지 (잡음 측정)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 4) {
                Text(exercise.displayName)
                Text("·")
                Text(timeString(elapsed)).monospacedDigit()
                if avgTempo > 0 {
                    Text("·")
                    Text(String(format: "%.1fs", avgTempo)).monospacedDigit()
                }
                if workoutManager.heartRate > 0 {
                    Text("·")
                    Image(systemName: "heart.fill").foregroundStyle(.red)
                    Text(String(format: "%.0f", workoutManager.heartRate)).monospacedDigit()
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Spacer(minLength: 2)

            HStack(spacing: 6) {
                Button {
                    reps += 1
                    coord.haptic(.click)
                    sendUpdate()
                } label: {
                    Image(systemName: "plus")
                }
                .tint(.accentColor)
                .frame(maxWidth: .infinity)

                Button(role: .destructive) {
                    finish()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
            .font(.footnote)
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 2)
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
        baselineReady = false
        workoutManager.start(exercise: exercise)
        coord.detector.onRepDetected = { count, tempo in
            reps = count
            avgTempo = coord.detector.avgTempoSeconds
            coord.haptic(.click)
            sendUpdate()
        }
        coord.detector.onSignalUpdate = { _, _, isCalibrated in
            if isCalibrated && !baselineReady {
                baselineReady = true
                coord.haptic(.start)
            }
        }
        do {
            try coord.detector.start(for: exercise, mode: .detect)
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
        workoutManager.stop(totalReps: reps, exercise: exercise)
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
