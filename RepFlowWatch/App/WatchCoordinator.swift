import Foundation
import SwiftUI
import WatchKit

@Observable
final class WatchCoordinator {

    enum Screen: Equatable {
        case menu
        case workout(ExerciseKind, WorkoutMode)
        case interval(IntervalProgram)
        case gtgQuick(ExerciseKind, Int)
        case calibrate(ExerciseKind)
        /// 「푸시업 100」 세션. 폰이 미리 밀어둔 세션을 워치 단독으로 진행한다.
        case program(ProgramSession, restBonusSeconds: Int)
    }

    var screen: Screen = .menu

    let detector: RepDetectorService = .init()
    let intervalTimer: IntervalTimerService = .init()

    func start(exercise: ExerciseKind, mode: WorkoutMode) {
        screen = .workout(exercise, mode)
    }

    func startInterval(program: IntervalProgram) {
        screen = .interval(program)
    }

    func openGTGQuick(exercise: ExerciseKind, reps: Int) {
        screen = .gtgQuick(exercise, reps)
    }

    func openCalibration(exercise: ExerciseKind) {
        screen = .calibrate(exercise)
    }

    func startProgram(_ session: ProgramSession, restBonusSeconds: Int) {
        screen = .program(session, restBonusSeconds: restBonusSeconds)
    }

    func backToMenu() {
        screen = .menu
    }

    func haptic(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}
