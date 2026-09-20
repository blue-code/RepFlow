import SwiftUI
import WatchKit

/// 프리 카운트 실시간 화면.
/// 기본 입력: **탭** (카운터 영역 = +1) + **크라운 회전** (±1).
/// 자동 카운트는 AutoDetectSettings.isEnabled() 가 true일 때만 보조로 동작.
struct WorkoutLiveView: View {
    let exercise: ExerciseKind
    let mode: WorkoutMode

    @Environment(WatchCoordinator.self) private var coord
    @State private var workoutManager = WatchWorkoutManager.shared
    @State private var reps: Int = 0
    @State private var elapsed: Int = 0
    @State private var startedAt: Date = .now
    @State private var ticker: Timer?
    @State private var error: String?
    @State private var baselineReady: Bool = false
    @State private var crownAccum: Double = 0
    @State private var lastTapAt: Date?

    @FocusState private var crownFocused: Bool

    private let autoDetectEnabled: Bool = AutoDetectSettings.isEnabled()

    var body: some View {
        VStack(spacing: 4) {
            metaRow

            Spacer(minLength: 0)

            counterTapArea

            Spacer(minLength: 2)

            HStack(spacing: 6) {
                Button {
                    undoRep()
                } label: {
                    Image(systemName: "minus")
                }
                .frame(maxWidth: .infinity)
                .disabled(reps == 0)

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
        .focusable()
        .focused($crownFocused)
        .digitalCrownRotation(
            $crownAccum,
            from: -9999, through: 9999, by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: false
        )
        .onChange(of: crownAccum) { oldValue, newValue in
            let delta = Int(newValue) - Int(oldValue)
            if delta != 0 {
                applyDelta(delta)
            }
        }
        .onAppear {
            crownFocused = true
            start()
        }
        .onDisappear { stop() }
        .alert("오류", isPresented: .constant(error != nil), actions: {
            Button("확인") { error = nil; coord.backToMenu() }
        }, message: {
            Text(error ?? "")
        })
    }

    // MARK: - 구성

    private var metaRow: some View {
        HStack(spacing: 4) {
            Text(exercise.displayName)
            Text("·")
            Text(timeString(elapsed)).monospacedDigit()
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
    }

    private var counterTapArea: some View {
        VStack(spacing: 2) {
            Text("\(reps)")
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .contentTransition(.numericText())
                .foregroundStyle(Color.accentColor)
                .animation(.spring(duration: 0.25), value: reps)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if autoDetectEnabled && !baselineReady {
                Text("정지 유지 (잡음 측정)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            } else if reps == 0 {
                Text("화면 탭 = +1")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 92)
        .contentShape(Rectangle())
        .onTapGesture { addRep() }
    }

    // MARK: - 카운트 동작

    private func addRep() {
        applyDelta(+1)
    }

    private func undoRep() {
        applyDelta(-1)
    }

    private func applyDelta(_ delta: Int) {
        let newValue = max(0, reps + delta)
        guard newValue != reps else { return }
        reps = newValue
        coord.haptic(delta > 0 ? .click : .directionDown)
        sendUpdate()
    }

    // MARK: - 라이프사이클

    private func start() {
        startedAt = .now
        baselineReady = false
        workoutManager.start(exercise: exercise)

        if autoDetectEnabled {
            coord.detector.onRepDetected = { _, _ in
                applyDelta(+1)
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
        }

        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsed = Int(Date.now.timeIntervalSince(startedAt))
        }
    }

    private func stop() {
        if autoDetectEnabled { coord.detector.stop() }
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
            avgTempo: 0
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
