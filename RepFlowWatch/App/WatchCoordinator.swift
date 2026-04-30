import Foundation
import SwiftUI
import WatchKit

@Observable
final class WatchCoordinator {

    enum Screen: Equatable {
        case menu
        case workout(ExerciseKind, WorkoutMode)
        case interval(IntervalProgram)
        case gtgQuick(ExerciseKind, Int)   // suggestedReps
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

    func backToMenu() {
        screen = .menu
    }

    func haptic(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}
