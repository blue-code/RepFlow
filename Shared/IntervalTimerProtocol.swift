import Foundation

protocol IntervalTimerProtocol: AnyObject {
    var state: IntervalState { get }
    var onStateChange: ((IntervalState) -> Void)? { get set }
    var onPhaseTransition: ((IntervalState.Phase) -> Void)? { get set }

    func start(program: IntervalProgram)
    func pause()
    func resume()
    func stop()
}
