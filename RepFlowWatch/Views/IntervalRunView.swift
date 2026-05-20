import SwiftUI
import WatchKit

struct IntervalRunView: View {
    let program: IntervalProgram

    @Environment(WatchCoordinator.self) private var coord
    @State private var state: IntervalState = .init(
        phase: .idle, currentRound: 0, totalRounds: 0, remainingSeconds: 0, repsThisRound: 0
    )
    @State private var totalReps = 0

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

            Spacer(minLength: 2)

            HStack(spacing: 6) {
                Button {
                    totalReps += 1
                    coord.haptic(.click)
                    coord.intervalTimer.registerRep()
                    WatchSessionService.shared.sendRepCount(totalReps)
                } label: {
                    Image(systemName: "plus")
                }
                .tint(.accentColor)
                .frame(maxWidth: .infinity)
                .disabled(state.phase != .work)

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
        .onDisappear { coord.intervalTimer.stop() }
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

    private func start() {
        WatchWorkoutManager.shared.start(exercise: program.exercise)
        // 모션 자동 카운트 + 인터벌 동시 진행
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

        coord.detector.onRepDetected = { count, _ in
            totalReps = count
            coord.haptic(.click)
            WatchSessionService.shared.sendRepCount(totalReps)
        }
        coord.detector.onSignalUpdate = { _, _, _ in }
        try? coord.detector.start(for: program.exercise, mode: .detect)
    }

    private func finish() {
        coord.intervalTimer.stop()
        coord.detector.stop()
        WatchWorkoutManager.shared.stop(totalReps: totalReps, exercise: program.exercise)
        WatchSessionService.shared.sendWorkoutEnded(
            exercise: program.exercise,
            mode: program.mode,
            totalReps: totalReps,
            durationSec: program.workSeconds * program.rounds,
            avgTempo: coord.detector.avgTempoSeconds
        )
        coord.haptic(.success)
        coord.backToMenu()
    }
}
