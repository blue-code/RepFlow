import Foundation

/// 카메라 거치가 제대로 됐는지 판정한다. 순수 계산이라 단독 테스트된다.
///
/// 푸시업은 바닥 자세다. 폰을 세워 정측면에서 전신을 담지 않으면 Vision 이 관절을 못 잡고,
/// 그 상태로 세션을 시작하면 카운트가 0으로 끝난다. 그래서 **시작 전에 막는 게 이 모드의 MVP**다.
///
/// ⚠️ 여기 좌표는 **화면 기준**(가로로 누운 몸 = span > height)이다. Vision 의 정규화 좌표는
/// `VNImageRequestHandler` 의 orientation 에 따라 축이 돌아가므로, 그 값이 틀리면
/// 멀쩡히 누운 사람이 세로로 길게 들어와 `notSideView` 가 영원히 걸린다. §14.9 참조.
struct PlacementCheck {

    /// 핵심 관절이 이 신뢰도는 넘어야 한다.
    var minConfidence: Double = 0.3
    /// 프레임 가장자리에서 이만큼(정규화 좌표) 안쪽에 있어야 "전신이 들어왔다"로 본다.
    var edgeMargin: Double = 0.03
    /// 몸통이 프레임에서 차지하는 가로 비율의 하한 — 너무 멀면 관절이 뭉갠다.
    var minBodySpan: Double = 0.30
    /// 상한 — 이보다 꽉 차면 조금만 움직여도 팔다리가 잘린다.
    /// `edgeMargin` 때문에 span 은 최대 `1 - 2×edgeMargin` 이라, 그보다 낮게 잡아야 의미가 있다.
    var maxBodySpan: Double = 0.88
    /// 이만큼 연속으로 통과해야 시작을 허용한다.
    var requiredStableDuration: TimeInterval = 3.0

    enum Problem: Equatable, Sendable {
        case noPerson
        case lowConfidence
        case outOfFrame
        case tooFar
        case tooClose
        /// 정측면이 아니라 위/앞에서 찍고 있다 — 몸이 가로로 눕지 않았다.
        case notSideView

        var message: String {
            switch self {
            case .noPerson:      return "사람이 보이지 않습니다"
            case .lowConfidence: return "몸이 잘 보이지 않습니다 — 조명을 밝게"
            case .outOfFrame:    return "전신이 들어오도록 폰을 뒤로"
            case .tooFar:        return "조금 더 가까이 (1.5~2m)"
            case .tooClose:      return "조금 더 멀리 (1.5~2m)"
            case .notSideView:   return "폰을 바닥에 세워 옆에서 찍어주세요"
            }
        }
    }

    enum Verdict: Equatable, Sendable {
        case ok
        case problem(Problem)

        var isOK: Bool { self == .ok }
    }

    /// 한 프레임 판정.
    func evaluate(pose: PoseGeometry.Pose?, confidence: Double) -> Verdict {
        guard let pose else { return .problem(.noPerson) }
        guard confidence >= minConfidence else { return .problem(.lowConfidence) }

        var points = [pose.shoulder, pose.elbow, pose.wrist, pose.hip]
        if let ankle = pose.ankle { points.append(ankle) }
        if let knee = pose.knee { points.append(knee) }

        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return .problem(.noPerson) }

        guard minX >= edgeMargin, maxX <= 1 - edgeMargin,
              minY >= edgeMargin, maxY <= 1 - edgeMargin else { return .problem(.outOfFrame) }

        let span = maxX - minX

        // 각도 판정이 거리 판정보다 먼저다. 서 있는 사람은 가로 폭이 좁아서
        // 순서를 바꾸면 "더 가까이 오세요"라는 엉뚱한 안내가 나간다.
        // 푸시업 자세는 몸이 가로로 눕는다 — 세로로 길면 서 있거나 위에서 찍는 중이다.
        guard span > (maxY - minY) else { return .problem(.notSideView) }

        guard span >= minBodySpan else { return .problem(.tooFar) }
        guard span <= maxBodySpan else { return .problem(.tooClose) }

        return .ok
    }
}

/// 연속으로 통과한 시간을 재는 게이트. 한 프레임 잘 나왔다고 시작시키면 안 된다.
struct PlacementGate {

    var check = PlacementCheck()

    private(set) var verdict: PlacementCheck.Verdict = .problem(.noPerson)
    private var okSince: TimeInterval?

    /// 연속 통과 시간(초).
    private(set) var stableFor: TimeInterval = 0

    /// 시작해도 되는가.
    var isReady: Bool { verdict.isOK && stableFor >= check.requiredStableDuration }

    /// 0~1 진행률 — 게이지에 그린다.
    var progress: Double {
        guard check.requiredStableDuration > 0 else { return 1 }
        return min(stableFor / check.requiredStableDuration, 1)
    }

    mutating func update(pose: PoseGeometry.Pose?, confidence: Double, at time: TimeInterval) {
        verdict = check.evaluate(pose: pose, confidence: confidence)
        guard verdict.isOK else {
            okSince = nil
            stableFor = 0
            return
        }
        let since = okSince ?? time
        okSince = since
        stableFor = max(0, time - since)
    }
}
