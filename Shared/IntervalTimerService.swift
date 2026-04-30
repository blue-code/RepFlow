import Foundation

final class IntervalTimerService: IntervalTimerProtocol {

    private(set) var state: IntervalState = .init(
        phase: .idle,
        currentRound: 0,
        totalRounds: 0,
        remainingSeconds: 0,
        repsThisRound: 0
    )

    var onStateChange: ((IntervalState) -> Void)?
    var onPhaseTransition: ((IntervalState.Phase) -> Void)?

    private var timer: Timer?
    private var program: IntervalProgram?
    private var pausedRemaining: Int?

    func start(program: IntervalProgram) {
        self.program = program
        state = .init(
            phase: .work,
            currentRound: 1,
            totalRounds: program.rounds,
            remainingSeconds: program.workSeconds,
            repsThisRound: 0
        )
        emit()
        notifyPhase(.work)
        startTicker()
    }

    func pause() {
        guard timer != nil else { return }
        timer?.invalidate()
        timer = nil
        pausedRemaining = state.remainingSeconds
    }

    func resume() {
        guard timer == nil, pausedRemaining != nil else { return }
        startTicker()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        program = nil
        state = .init(phase: .idle, currentRound: 0, totalRounds: 0, remainingSeconds: 0, repsThisRound: 0)
        emit()
    }

    func registerRep() {
        state.repsThisRound += 1
        emit()
    }

    private func startTicker() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    private func tick() {
        guard let program else { return }
        if state.remainingSeconds > 1 {
            state.remainingSeconds -= 1
            emit()
        } else {
            advancePhase(program: program)
        }
    }

    private func advancePhase(program: IntervalProgram) {
        switch state.phase {
        case .work:
            // 작업 끝 → 휴식 또는 다음 라운드 / 종료
            if program.restSeconds > 0 && state.currentRound < program.rounds {
                state = .init(
                    phase: .rest,
                    currentRound: state.currentRound,
                    totalRounds: state.totalRounds,
                    remainingSeconds: program.restSeconds,
                    repsThisRound: 0
                )
                emit()
                notifyPhase(.rest)
            } else if state.currentRound < program.rounds {
                state = .init(
                    phase: .work,
                    currentRound: state.currentRound + 1,
                    totalRounds: state.totalRounds,
                    remainingSeconds: program.workSeconds,
                    repsThisRound: 0
                )
                emit()
                notifyPhase(.work)
            } else {
                complete()
            }
        case .rest:
            // 휴식 끝 → 다음 라운드 작업
            state = .init(
                phase: .work,
                currentRound: state.currentRound + 1,
                totalRounds: state.totalRounds,
                remainingSeconds: program.workSeconds,
                repsThisRound: 0
            )
            emit()
            notifyPhase(.work)
        case .idle, .complete:
            break
        }
    }

    private func complete() {
        timer?.invalidate()
        timer = nil
        state = .init(phase: .complete, currentRound: state.totalRounds, totalRounds: state.totalRounds, remainingSeconds: 0, repsThisRound: 0)
        emit()
        notifyPhase(.complete)
    }

    private func emit() {
        let s = state
        DispatchQueue.main.async { [weak self] in
            self?.onStateChange?(s)
        }
    }

    private func notifyPhase(_ phase: IntervalState.Phase) {
        DispatchQueue.main.async { [weak self] in
            self?.onPhaseTransition?(phase)
        }
    }
}
