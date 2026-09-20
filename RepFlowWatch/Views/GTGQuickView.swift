import SwiftUI
import WatchKit

/// GTG 알림 응답 화면. 기본 입력은 **탭 카운트** + **크라운**.
/// AutoDetectSettings.isEnabled() 가 true일 때만 자동 감지가 보조로 동작.
struct GTGQuickView: View {
    let exercise: ExerciseKind
    let suggestedReps: Int

    @Environment(WatchCoordinator.self) private var coord
    @State private var done: Int = 0
    @State private var started: Bool = false
    @State private var baselineReady: Bool = false
    @State private var crownAccum: Double = 0

    @FocusState private var crownFocused: Bool

    private let autoDetectEnabled: Bool = AutoDetectSettings.isEnabled()

    var body: some View {
        VStack(spacing: 4) {
            metaRow

            Spacer(minLength: 0)

            counterArea

            Spacer(minLength: 2)

            actionRow
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
            guard started else { return }
            let delta = Int(newValue) - Int(oldValue)
            if delta != 0 {
                applyDelta(delta)
            }
        }
        .onAppear { crownFocused = true }
        .onDisappear { if autoDetectEnabled { coord.detector.stop() } }
    }

    private var metaRow: some View {
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
    }

    private var counterArea: some View {
        VStack(spacing: 2) {
            Text("\(done)")
                .font(.system(size: 60, weight: .heavy, design: .rounded))
                .foregroundStyle(.orange)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.2), value: done)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if started && autoDetectEnabled && !baselineReady {
                Text("정지 유지 (잡음 측정)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            } else if started && done == 0 {
                Text("화면 탭 = +1")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 88)
        .contentShape(Rectangle())
        .onTapGesture {
            if started { applyDelta(+1) } else { start() }
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: 6) {
            if started {
                Button {
                    applyDelta(-1)
                } label: {
                    Image(systemName: "minus")
                }
                .frame(maxWidth: .infinity)
                .disabled(done == 0)

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

    private func applyDelta(_ delta: Int) {
        let newValue = max(0, done + delta)
        guard newValue != done else { return }
        let crossedTarget = (done < suggestedReps) && (newValue >= suggestedReps)
        done = newValue
        if crossedTarget {
            coord.haptic(.success)
        } else {
            coord.haptic(delta > 0 ? .click : .directionDown)
        }
    }

    private func start() {
        started = true
        baselineReady = false

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
            try? coord.detector.start(for: exercise, mode: .detect)
        } else {
            coord.haptic(.start)
        }
    }

    private func complete() {
        if autoDetectEnabled { coord.detector.stop() }
        WatchSessionService.shared.sendGTGAck(exercise: exercise, reps: done)
        coord.haptic(.success)
        coord.backToMenu()
    }

    private func skip() {
        if autoDetectEnabled { coord.detector.stop() }
        WatchSessionService.shared.sendGTGAck(exercise: exercise, reps: 0)
        coord.haptic(.failure)
        coord.backToMenu()
    }
}
