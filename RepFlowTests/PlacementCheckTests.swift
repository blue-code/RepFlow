import Foundation
import Testing
@testable import RepFlow

/// 카메라 모드의 MVP는 카운터가 아니라 **시작을 막는 게이트**다.
/// 셀피 각도로 천장을 찍으면서 세션을 시작하면 카운트가 0으로 끝난다.
@Suite("카메라 거치 판정")
struct PlacementCheckTests {

    typealias P = PoseGeometry.Point

    /// 정측면으로 잘 누운 푸시업 자세 — 가로로 길다.
    private func goodPose() -> PoseGeometry.Pose {
        PoseGeometry.Pose(
            shoulder: P(0.25, 0.45),
            elbow: P(0.24, 0.60),
            wrist: P(0.23, 0.72),
            hip: P(0.55, 0.47),
            ankle: P(0.85, 0.50),
            knee: P(0.70, 0.48)
        )
    }

    private func shifted(_ pose: PoseGeometry.Pose, dx: Double = 0, dy: Double = 0) -> PoseGeometry.Pose {
        var p = pose
        for kp in [\PoseGeometry.Pose.shoulder, \.elbow, \.wrist, \.hip] {
            p[keyPath: kp] = P(p[keyPath: kp].x + dx, p[keyPath: kp].y + dy)
        }
        if let a = p.ankle { p.ankle = P(a.x + dx, a.y + dy) }
        if let k = p.knee { p.knee = P(k.x + dx, k.y + dy) }
        return p
    }

    private func scaled(_ pose: PoseGeometry.Pose, by factor: Double) -> PoseGeometry.Pose {
        var p = pose
        func s(_ pt: P) -> P { P(0.5 + (pt.x - 0.5) * factor, 0.5 + (pt.y - 0.5) * factor) }
        p.shoulder = s(p.shoulder); p.elbow = s(p.elbow); p.wrist = s(p.wrist); p.hip = s(p.hip)
        if let a = p.ankle { p.ankle = s(a) }
        if let k = p.knee { p.knee = s(k) }
        return p
    }

    @Test("제대로 거치하면 통과한다")
    func passesGoodPlacement() {
        #expect(PlacementCheck().evaluate(pose: goodPose(), confidence: 0.8) == .ok)
    }

    @Test("사람이 없으면 막는다")
    func blocksNoPerson() {
        #expect(PlacementCheck().evaluate(pose: nil, confidence: 0) == .problem(.noPerson))
    }

    @Test("어두우면 막는다")
    func blocksLowConfidence() {
        #expect(PlacementCheck().evaluate(pose: goodPose(), confidence: 0.1) == .problem(.lowConfidence))
    }

    @Test("몸이 프레임을 벗어나면 막는다")
    func blocksOutOfFrame() {
        let off = shifted(goodPose(), dx: 0.2)
        #expect(PlacementCheck().evaluate(pose: off, confidence: 0.8) == .problem(.outOfFrame))
    }

    @Test("너무 멀면 막는다")
    func blocksTooFar() {
        #expect(PlacementCheck().evaluate(pose: scaled(goodPose(), by: 0.3), confidence: 0.8)
                == .problem(.tooFar))
    }

    @Test("멀리 서 있는 사람에게는 '더 가까이'가 아니라 '옆에서 찍으라'고 한다")
    func sideViewCheckComesFirst() {
        let farStanding = PoseGeometry.Pose(
            shoulder: P(0.49, 0.30), elbow: P(0.48, 0.38), wrist: P(0.475, 0.45),
            hip: P(0.50, 0.52), ankle: P(0.505, 0.80), knee: P(0.50, 0.66)
        )
        #expect(PlacementCheck().evaluate(pose: farStanding, confidence: 0.8)
                == .problem(.notSideView))
    }

    @Test("너무 가까우면 막는다")
    func blocksTooClose() {
        // 프레임을 벗어나지는 않지만 가로로 꽉 차 조금만 움직여도 잘리는 자세
        var p = goodPose()
        p.shoulder = P(0.04, 0.45); p.elbow = P(0.05, 0.6); p.wrist = P(0.06, 0.72)
        p.hip = P(0.55, 0.47); p.knee = P(0.8, 0.48); p.ankle = P(0.95, 0.5)
        #expect(PlacementCheck().evaluate(pose: p, confidence: 0.8) == .problem(.tooClose))
    }

    @Test("서 있거나 위에서 찍으면 막는다 — 몸이 세로로 길다")
    func blocksNonSideView() {
        let standing = PoseGeometry.Pose(
            shoulder: P(0.48, 0.15), elbow: P(0.46, 0.28), wrist: P(0.45, 0.40),
            hip: P(0.50, 0.50), ankle: P(0.51, 0.90), knee: P(0.50, 0.70)
        )
        #expect(PlacementCheck().evaluate(pose: standing, confidence: 0.8) == .problem(.notSideView))
    }

    @Test("한 프레임 잘 나왔다고 시작시키지 않는다")
    func requiresStability() {
        var gate = PlacementGate()
        gate.update(pose: goodPose(), confidence: 0.8, at: 0)
        #expect(gate.verdict.isOK)
        #expect(gate.isReady == false)
        #expect(gate.progress == 0)
    }

    @Test("3초 연속 통과하면 시작을 허용한다")
    func readyAfterStableWindow() {
        var gate = PlacementGate()
        for t in stride(from: 0.0, through: 3.0, by: 0.1) {
            gate.update(pose: goodPose(), confidence: 0.8, at: t)
        }
        #expect(gate.isReady)
        #expect(gate.progress == 1)
    }

    @Test("중간에 틀어지면 처음부터 다시 잰다")
    func resetsOnInterruption() {
        var gate = PlacementGate()
        for t in stride(from: 0.0, through: 2.0, by: 0.1) {
            gate.update(pose: goodPose(), confidence: 0.8, at: t)
        }
        #expect(gate.progress > 0.5)

        gate.update(pose: nil, confidence: 0, at: 2.1)
        #expect(gate.isReady == false)
        #expect(gate.progress == 0)

        gate.update(pose: goodPose(), confidence: 0.8, at: 2.2)
        #expect(gate.isReady == false, "다시 3초를 채워야 한다")
    }

    @Test("문제마다 무엇을 고쳐야 하는지 알려준다")
    func everyProblemHasGuidance() {
        let problems: [PlacementCheck.Problem] = [
            .noPerson, .lowConfidence, .outOfFrame, .tooFar, .tooClose, .notSideView
        ]
        for problem in problems {
            #expect(problem.message.isEmpty == false)
        }
    }
}
