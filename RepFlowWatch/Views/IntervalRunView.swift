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
        VStack(spacing: 6) {
            HStack {
                Text(program.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text("R\(state.currentRound)/\(state.totalRounds)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Text("\(state.remainingSeconds)")
                .font(.system(size: 80, weight: .heavy, design: .rounded))
                .foregroundStyle(phaseColor)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.2), value: state.remainingSeconds)

            Text(phaseLabel)
                .font(.caption2.weight(.bold))
                .foregroundStyle(phaseColor)

            Text("총 \(totalReps) reps")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                Button {
                    totalReps += 1
                    coord.haptic(.click)
                    coord.intervalTimer.registerRep()
                    WatchSessionService.shared.sendRepCount(totalReps)
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .disabled(state.phase != .work)

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
        try? coord.detector.start(for: program.exercise)
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
