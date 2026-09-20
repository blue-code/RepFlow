import Foundation

/// Vision 관절 좌표에서 푸시업 깊이와 폼 지표를 뽑는 순수 계산.
///
/// Vision 을 import 하지 않는다 — 입력은 그냥 점 몇 개다. 그래서 시뮬레이터에서
/// 합성 좌표로 단독 테스트할 수 있다(실기기 없이 검증 가능한 유일한 부분).
enum PoseGeometry {

    struct Point: Equatable, Sendable {
        var x: Double
        var y: Double
        init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    }

    /// 푸시업 한 순간의 관절. 정측면 촬영이라 **카메라를 향한 쪽** 팔다리만 쓴다
    /// (반대쪽은 몸에 가려 Vision 이 저신뢰 좌표를 낸다).
    struct Pose: Equatable, Sendable {
        var shoulder: Point
        var elbow: Point
        var wrist: Point
        var hip: Point
        /// 정자세 힙라인 기준점.
        var ankle: Point?
        /// 무릎 푸시업(L1) 힙라인 기준점.
        var knee: Point?
    }

    /// 세 점이 이루는 각(도). 가운데가 꼭짓점.
    static func angle(_ a: Point, _ vertex: Point, _ b: Point) -> Double {
        let v1 = (x: a.x - vertex.x, y: a.y - vertex.y)
        let v2 = (x: b.x - vertex.x, y: b.y - vertex.y)
        let dot = v1.x * v2.x + v1.y * v2.y
        let m1 = (v1.x * v1.x + v1.y * v1.y).squareRoot()
        let m2 = (v2.x * v2.x + v2.y * v2.y).squareRoot()
        guard m1 > 0, m2 > 0 else { return 180 }
        return acos(min(max(dot / (m1 * m2), -1), 1)) * 180 / .pi
    }

    /// 팔꿈치 각 — 어깨·팔꿈치·손목.
    static func elbowAngle(_ pose: Pose) -> Double {
        angle(pose.shoulder, pose.elbow, pose.wrist)
    }

    /// 힙라인 각 — 180°에 가까울수록 몸이 곧다.
    ///
    /// 무릎 푸시업이면 발목이 아니라 **무릎**을 기준점으로 쓴다. 안 그러면 L1 사용자의
    /// 모든 rep이 "허리 처짐"으로 오판된다.
    static func hipLineAngle(_ pose: Pose, kneeVariant: Bool) -> Double? {
        let reference = kneeVariant ? pose.knee : pose.ankle
        guard let reference else { return nil }
        return angle(pose.shoulder, pose.hip, reference)
    }

    // MARK: - 깊이 신호

    /// 깊이 신호 산출 방식. **M5 실기기 튜닝에서 기준 영상으로 비교 후 하나를 고른다.**
    enum DepthMethod: String, CaseIterable, Sendable {
        /// 팔꿈치 각. 직관적이지만 팔꿈치를 벌리면 투영에서 각이 압축된다.
        case elbowAngle
        /// 어깨 높이 ÷ 몸통 길이. 카메라 거리·체격에 불변.
        case shoulderDrop
    }

    /// 락아웃으로 보는 팔꿈치 각.
    static let lockoutAngle: Double = 170
    /// 바닥으로 보는 팔꿈치 각.
    static let bottomAngle: Double = 85

    /// 0(락아웃) ~ 1(바닥) 정규화 깊이.
    ///
    /// `shoulderDrop` 은 세션 시작 시 잰 락아웃 기준값(`baselineShoulderGap`)이 필요하다.
    static func depth(
        _ pose: Pose,
        method: DepthMethod,
        baselineShoulderGap: Double? = nil
    ) -> Double? {
        switch method {
        case .elbowAngle:
            let theta = elbowAngle(pose)
            return clamp01((lockoutAngle - theta) / (lockoutAngle - bottomAngle))

        case .shoulderDrop:
            // 몸통 길이로 나눠 카메라 거리·체격을 상쇄한다.
            let torso = distance(pose.shoulder, pose.hip)
            guard torso > 0, let baseline = baselineShoulderGap, baseline > 0 else { return nil }
            let normalized = shoulderGroundGap(pose) / torso
            // 락아웃일 때 1.0, 바닥에서 0에 가까워진다.
            return clamp01(1 - normalized / baseline)
        }
    }

    /// 손목 높이를 바닥으로 보고 잰 어깨 높이. 화면 좌표계는 아래로 갈수록 y가 크다고 가정한다.
    static func shoulderGroundGap(_ pose: Pose) -> Double {
        abs(pose.wrist.y - pose.shoulder.y)
    }

    /// 락아웃 자세에서의 기준값(몸통 길이 대비 어깨 높이).
    static func baselineGap(_ pose: Pose) -> Double? {
        let torso = distance(pose.shoulder, pose.hip)
        guard torso > 0 else { return nil }
        return shoulderGroundGap(pose) / torso
    }

    // MARK: - 폼 지표

    /// 한 rep 동안 모인 관절로 매기는 폼 점수.
    struct FormScore: Equatable, Sendable {
        /// 최저점의 팔꿈치 각. 작을수록 깊다.
        var minElbowAngle: Double
        /// 최고점의 팔꿈치 각. 클수록 완전히 폈다.
        var maxElbowAngle: Double
        /// 180°에서 가장 많이 벗어난 힙라인 각. 측정 불가면 nil.
        var worstHipDeviation: Double?

        /// 가슴이 충분히 내려갔는가.
        var isDeepEnough: Bool { minElbowAngle <= 95 }
        /// 팔을 다 폈는가.
        var isLockedOut: Bool { maxElbowAngle >= 160 }
        /// 허리가 무너졌는가.
        var isBodyStraight: Bool { (worstHipDeviation ?? 0) <= 20 }
    }

    /// rep 한 번 동안의 자세들로 폼 점수를 낸다.
    static func formScore(for poses: [Pose], kneeVariant: Bool) -> FormScore? {
        guard !poses.isEmpty else { return nil }
        let angles = poses.map(elbowAngle)
        let deviations = poses.compactMap { hipLineAngle($0, kneeVariant: kneeVariant) }
            .map { abs(180 - $0) }
        return FormScore(
            minElbowAngle: angles.min() ?? 180,
            maxElbowAngle: angles.max() ?? 180,
            worstHipDeviation: deviations.max()
        )
    }

    // MARK: -

    private static func distance(_ a: Point, _ b: Point) -> Double {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }

    private static func clamp01(_ v: Double) -> Double { min(max(v, 0), 1) }
}
