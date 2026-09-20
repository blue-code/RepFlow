import SwiftUI
import WatchKit

/// 인터벌 모드 (EMOM/Tabata/AMRAP). 기본 입력은 **탭** + **크라운**, 자동 감지는 opt-in.
struct IntervalRunView: View {
    let program: IntervalProgram

    @Environment(WatchCoordinator.self) private var coord
    @State private var state: IntervalState = .init(
        phase: .idle, currentRound: 0, totalRounds: 0, remainingSeconds: 0, repsThisRound: 0
    )
    @State private var totalReps = 0
    @State private var crownAccum: Double = 0

    @FocusState private var crownFocused: Bool

    private let autoDetectEnabled: Bool = AutoDetectSettings.isEnabled()

    var body: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)

            Text("\(state.remainingSeconds)")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(phaseColor)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.2), value: state.remainingSeconds)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            HStack(spacing: 4) {
                Text(phaseLabel).fontWeight(.bold).foregroundStyle(phaseColor)
                Text("·")
                Text("R\(state.currentRound)/\(state.totalRounds)").monospacedDigit()
                Text("·")
                Text("\(totalReps)reps").monospacedDigit()
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Text(program.name)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            tapHint

            Spacer(minLength: 2)

            HStack(spacing: 6) {
                Button {
                    applyDelta(+1)
                } label: {
                    Image(systemName: "plus")
                }
                .tint(.accentColor)
                .frame(maxWidth: .infinity)
                .disabled(state.phase != .work)

                Button {
                    applyDelta(-1)
                } label: {
                    Image(systemName: "minus")
                }
                .frame(maxWidth: .infinity)
                .disabled(totalReps == 0)

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
        .contentShape(Rectangle())
        .onTapGesture {
            if state.phase == .work { applyDelta(+1) }
        }
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
            guard state.phase == .work else { return }
            let delta = Int(newValue) - Int(oldValue)
            if delta != 0 { applyDelta(delta) }
        }
        .onAppear {
            crownFocused = true
            start()
        }
        .onDisappear {
            coord.intervalTimer.stop()
            if autoDetectEnabled { coord.detector.stop() }
        }
    }

    @ViewBuilder
    private var tapHint: some View {
        if state.phase == .work && totalReps == 0 {
            Text("화면 탭 = +1")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var phaseLabel: String {
        switch state.phase {
        case .work: return "운동"
        case .rest: return "휴식"
        case .complete: return "완료!"
        case .idle: return "준비"
        }
    }

    private var phaseColor: Color {
        switch state.phase {
        case .work: return Color.accentColor
        case .rest: return .green
        case .complete: return .yellow
        case .idle: return .secondary
        }
    }

    private func applyDelta(_ delta: Int) {
        let newValue = max(0, totalReps + delta)
        guard newValue != totalReps else { return }
        totalReps = newValue
        if delta > 0 {
            coord.haptic(.click)
            coord.intervalTimer.registerRep()
        } else {
            coord.haptic(.directionDown)
        }
        WatchSessionService.shared.sendRepCount(totalReps)
    }

    private func start() {
        WatchWorkoutManager.shared.start(exercise: program.exercise)
        coord.intervalTimer.onStateChange = { newState in
            state = newState
        }
        coord.intervalTimer.onPhaseTransition = { phase in
            switch phase {
            case .work: coord.haptic(.start)
            case .rest: coord.haptic(.stop)
            case .complete: coord.haptic(.success)
            case .idle: break
            }
        }
        coord.intervalTimer.start(program: program)

        if autoDetectEnabled {
            coord.detector.onRepDetected = { _, _ in
                applyDelta(+1)
            }
            coord.detector.onSignalUpdate = { _, _, _ in }
            try? coord.detector.start(for: program.exercise, mode: .detect)
        }
    }

    private func finish() {
        coord.intervalTimer.stop()
        if autoDetectEnabled { coord.detector.stop() }
        WatchWorkoutManager.shared.stop(totalReps: totalReps, exercise: program.exercise)
        WatchSessionService.shared.sendWorkoutEnded(
            exercise: program.exercise,
            mode: program.mode,
            totalReps: totalReps,
            durationSec: program.workSeconds * program.rounds,
            avgTempo: 0
        )
        coord.haptic(.success)
        coord.backToMenu()
    }
}
