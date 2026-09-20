import Foundation
import Testing
@testable import RepFlow

/// Vision 없이 합성 좌표로 검증한다. 실기기 없이 확인할 수 있는 유일한 카메라 관련 부분이다.
/// (실제 관절 추정 정확도는 기준 영상으로만 검증 가능 — M5 실기기 과제.)
@Suite("자세 기하")
struct PoseGeometryTests {

    typealias P = PoseGeometry.Point

    /// 화면 좌표계: 아래로 갈수록 y가 크다. 손목이 바닥, 어깨가 그 위.
    private func pose(elbowBend: Double, shoulderHeight: Double = 1.0, hipSag: Double = 0) -> PoseGeometry.Pose {
        // 팔꿈치를 꼭짓점으로, 손목 방향(아래)에서 elbowBend 만큼 벌어진 곳에 어깨를 둔다.
        // 180°면 손목·팔꿈치·어깨가 일직선(팔을 편 상태).
        let radians = elbowBend * .pi / 180
        let elbow = P(0, 1)
        let wrist = P(0, 2)                                   // 팔꿈치 바로 아래(바닥)
        let shoulder = P(sin(radians), 1 + cos(radians))
        return PoseGeometry.Pose(
            shoulder: shoulder,
            elbow: elbow,
            wrist: wrist,
            hip: P(shoulder.x + 1.2, shoulder.y + hipSag),
            ankle: P(shoulder.x + 2.6, shoulder.y),
            knee: P(shoulder.x + 1.9, shoulder.y)
        )
    }

    @Test("세 점이 이루는 각을 잰다", arguments: [
        (P(0, -1), P(1, 0), 90.0),
        (P(0, -1), P(0, -2), 0.0),
        (P(0, -1), P(0, 1), 180.0)
    ])
    func computesAngle(a: P, b: P, expected: Double) {
        let result = PoseGeometry.angle(a, P(0, 0), b)
        #expect(abs(result - expected) < 0.01)
    }

    @Test("팔을 펴면 깊이 0, 접으면 1에 가깝다")
    func depthFollowsElbowAngle() {
        let locked = PoseGeometry.depth(pose(elbowBend: 178), method: .elbowAngle)!
        let bottom = PoseGeometry.depth(pose(elbowBend: 80), method: .elbowAngle)!
        #expect(locked == 0, "락아웃은 0으로 붙는다")
        #expect(bottom == 1, "바닥은 1로 붙는다")
    }

    @Test("깊이는 팔을 굽힐수록 단조 증가한다")
    func depthIsMonotonic() {
        var previous = -1.0
        for bend in stride(from: 175.0, through: 80.0, by: -5.0) {
            let d = PoseGeometry.depth(pose(elbowBend: bend), method: .elbowAngle)!
            #expect(d >= previous, "\(bend)도에서 깊이가 줄었다")
            previous = d
        }
    }

    @Test("중간 각도는 중간 깊이다")
    func depthInMiddle() {
        let mid = PoseGeometry.depth(pose(elbowBend: 127.5), method: .elbowAngle)!
        #expect(abs(mid - 0.5) < 0.05)
    }

    @Test("어깨 높이 방식은 기준값 없이는 판단하지 않는다")
    func shoulderDropNeedsBaseline() {
        #expect(PoseGeometry.depth(pose(elbowBend: 120), method: .shoulderDrop) == nil)
    }

    @Test("어깨 높이 방식도 굽힐수록 깊이가 커진다")
    func shoulderDropWorksWithBaseline() throws {
        let top = pose(elbowBend: 175)
        let baseline = try #require(PoseGeometry.baselineGap(top))

        let atTop = PoseGeometry.depth(top, method: .shoulderDrop, baselineShoulderGap: baseline)!
        let atBottom = PoseGeometry.depth(pose(elbowBend: 85), method: .shoulderDrop, baselineShoulderGap: baseline)!
        #expect(atTop < 0.1, "락아웃에서는 거의 0")
        #expect(atBottom > atTop, "굽히면 깊이가 커진다")
    }

    @Test("곧은 몸은 힙라인이 180°에 가깝다")
    func straightBody() throws {
        let angle = try #require(PoseGeometry.hipLineAngle(pose(elbowBend: 170), kneeVariant: false))
        #expect(abs(180 - angle) < 5)
    }

    @Test("허리가 처지면 힙라인이 180°에서 벌어진다")
    func sagIsDetected() throws {
        let straight = try #require(PoseGeometry.hipLineAngle(pose(elbowBend: 170), kneeVariant: false))
        let sagging = try #require(PoseGeometry.hipLineAngle(pose(elbowBend: 170, hipSag: 0.5), kneeVariant: false))
        #expect(abs(180 - sagging) > abs(180 - straight))
    }

    @Test("무릎 푸시업은 발목이 아니라 무릎을 기준으로 잰다")
    func kneeVariantUsesKnee() throws {
        var p = pose(elbowBend: 170)
        // 무릎까지는 곧지만 발목은 들려 있는, 전형적인 무릎 푸시업 자세.
        p.ankle = P(p.hip.x + 0.3, p.hip.y - 1.2)

        let asStandard = try #require(PoseGeometry.hipLineAngle(p, kneeVariant: false))
        let asKnee = try #require(PoseGeometry.hipLineAngle(p, kneeVariant: true))

        #expect(abs(180 - asStandard) > 20, "발목 기준이면 허리가 무너진 것처럼 보인다")
        #expect(abs(180 - asKnee) < 10, "무릎 기준이면 곧은 자세로 나온다")
    }

    @Test("기준점이 없으면 힙라인을 재지 않는다")
    func hipLineNeedsReference() {
        var p = pose(elbowBend: 170)
        p.ankle = nil
        p.knee = nil
        #expect(PoseGeometry.hipLineAngle(p, kneeVariant: false) == nil)
        #expect(PoseGeometry.hipLineAngle(p, kneeVariant: true) == nil)
    }

    @Test("한 rep 동안의 자세로 폼 점수를 낸다")
    func scoresGoodRep() throws {
        let rep = [pose(elbowBend: 175), pose(elbowBend: 120), pose(elbowBend: 88),
                   pose(elbowBend: 120), pose(elbowBend: 175)]
        let score = try #require(PoseGeometry.formScore(for: rep, kneeVariant: false))
        #expect(score.isDeepEnough)
        #expect(score.isLockedOut)
        #expect(score.isBodyStraight)
    }

    @Test("얕은 rep은 깊이 미달로 잡힌다")
    func flagsShallowRep() throws {
        let rep = [pose(elbowBend: 175), pose(elbowBend: 130), pose(elbowBend: 175)]
        let score = try #require(PoseGeometry.formScore(for: rep, kneeVariant: false))
        #expect(score.isDeepEnough == false)
        #expect(score.isLockedOut)
    }

    @Test("끝까지 펴지 않으면 락아웃 미달로 잡힌다")
    func flagsMissingLockout() throws {
        let rep = [pose(elbowBend: 140), pose(elbowBend: 85), pose(elbowBend: 140)]
        let score = try #require(PoseGeometry.formScore(for: rep, kneeVariant: false))
        #expect(score.isDeepEnough)
        #expect(score.isLockedOut == false)
    }

    @Test("허리가 처진 rep은 자세 불량으로 잡힌다")
    func flagsSag() throws {
        let rep = [pose(elbowBend: 175, hipSag: 0.6), pose(elbowBend: 88, hipSag: 0.6)]
        let score = try #require(PoseGeometry.formScore(for: rep, kneeVariant: false))
        #expect(score.isBodyStraight == false)
    }

    @Test("자세가 하나도 없으면 점수가 없다")
    func noPosesNoScore() {
        #expect(PoseGeometry.formScore(for: [], kneeVariant: false) == nil)
    }
}
