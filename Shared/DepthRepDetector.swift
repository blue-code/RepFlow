import Foundation

/// 0~1 깊이 신호에서 rep을 세는 순수 판정기.
///
/// 0 = 락아웃(팔 편 위), 1 = 바닥(가슴 내린 아래). 신호가 어디서 오는지는 모른다 —
/// 카메라(Vision 관절각)든 근접센서(가림/해제)든 같은 규칙으로 센다.
/// 프레임워크 의존이 없어 합성 신호로 단독 테스트된다.
///
/// 워치의 `RepDetectorService`(가속도 zero-crossing)와는 알고리즘이 다르다. 그쪽은
/// 손목 진폭이 노이즈와 겹치는 한계로 실험 기능으로 강등됐고(§12 #11), 이쪽은
/// 위치 자체를 보기 때문에 그 문제가 없다.
struct DepthRepDetector {

    /// 이 위(이상)면 "아래 구간".
    var downThreshold: Double = 0.75
    /// 이 아래(이하)면 "위 구간". 둘 사이는 중간 구간 — 히스테리시스다.
    var upThreshold: Double = 0.25
    /// 아래 구간을 **연속으로** 이만큼 유지해야 인정한다.
    /// 카메라처럼 노이즈가 있는 신호는 0.35초쯤 필요하지만, 근접센서처럼 하드웨어가
    /// 디바운스한 이진 신호는 **0이 맞다** — 닿았다는 이벤트 자체가 이미 진짜다.
    /// 여기가 길면 "머리가 스치듯 닿는" 실제 푸시업이 통째로 무시된다.
    var minDownDuration: TimeInterval = 0.35
    /// 위 구간(락아웃)을 이만큼 유지해야 인정한다. **아래를 0으로 풀 때 디바운스는 이쪽이 맡는다** —
    /// 센서가 near/far 를 빠르게 튕겨도 위 구간을 제대로 머물기 전엔 1회로 확정되지 않는다.
    var minUpDuration: TimeInterval = 0.35

    /// 양쪽을 같은 값으로 다루는 기존 호출부·테스트용.
    var minPhaseDuration: TimeInterval {
        get { max(minDownDuration, minUpDuration) }
        set { minDownDuration = newValue; minUpDuration = newValue }
    }

    /// 신호가 속한 구간.
    enum Zone: Equatable { case up, middle, down }

    enum Phase: Equatable {
        /// 위(락아웃). 시작 상태.
        case up
        /// 아래까지 내려간 상태. 여기서 위로 올라오면 1회.
        case down
    }

    private(set) var phase: Phase = .up
    private(set) var count: Int = 0

    private var currentZone: Zone = .middle
    private var zoneEnteredAt: TimeInterval?
    /// 위 구간을 한 번도 인정받은 적이 없으면(시작부터 엎드려 있으면) 첫 기상을 세지 않는다.
    private var hasBeenUp = false

    init() {}

    /// 소스 특성에 맞춰 구간별 체류를 따로 준다 (근접센서: 아래 0 · 위 0.25).
    init(minDownDuration: TimeInterval, minUpDuration: TimeInterval) {
        self.minDownDuration = minDownDuration
        self.minUpDuration = minUpDuration
    }

    /// 지금 머무는 구간을 인정받는 데 필요한 체류 시간.
    private var requiredDwell: TimeInterval {
        switch currentZone {
        case .down:   return minDownDuration
        case .up:     return minUpDuration
        case .middle: return 0   // 중간 구간은 인정해도 전이가 없다
        }
    }

    /// 신호 한 샘플. rep이 완성되면 true.
    ///
    /// `time` 은 샘플 시각(초). 시간 기반이라 프레임레이트가 흔들려도 판정이 흔들리지 않는다.
    ///
    /// 두 종류의 소스를 모두 받는다:
    /// - **연속 샘플링**(카메라 30fps) — 같은 구간이 이어지는 동안 체류 시간이 채워진다.
    /// - **희소 이벤트**(근접센서는 바뀔 때만 알려준다) — 구간을 **떠날 때** 직전 구간을
    ///   얼마나 유지했는지로 판정한다. 이게 없으면 구간마다 샘플이 하나뿐이라 아무것도 못 센다.
    @discardableResult
    mutating func ingest(depth: Double, at time: TimeInterval) -> Bool {
        let newZone = zone(for: depth)

        guard let enteredAt = zoneEnteredAt else {
            currentZone = newZone
            zoneEnteredAt = time
            return false
        }

        if newZone == currentZone {
            guard time - enteredAt >= requiredDwell else { return false }
            return confirmCurrentZone()
        }

        // 구간을 떠난다 — 충분히 머물렀다면 그 구간을 인정한다.
        let counted = (time - enteredAt >= requiredDwell) ? confirmCurrentZone() : false
        currentZone = newZone
        zoneEnteredAt = time
        return counted
    }

    /// 마지막 구간을 마무리한다. **희소 이벤트 소스는 세션을 끝낼 때 반드시 불러야 한다** —
    /// 안 그러면 마지막 1회가 다음 이벤트를 기다리다 영영 안 세어진다.
    @discardableResult
    mutating func flush(at time: TimeInterval) -> Bool {
        guard let enteredAt = zoneEnteredAt, time - enteredAt >= requiredDwell else { return false }
        return confirmCurrentZone()
    }

    /// 현재 구간을 인정하고 필요한 전이를 적용한다. 같은 구간을 여러 번 인정해도 결과는 같다.
    private mutating func confirmCurrentZone() -> Bool {
        switch (phase, currentZone) {
        case (.up, .down):
            phase = .down
            return false

        case (.down, .up):
            phase = .up
            // 시작부터 엎드려 있던 사람이 처음 일어난 것뿐이면 세지 않는다.
            guard hasBeenUp else {
                hasBeenUp = true
                return false
            }
            count += 1
            return true

        case (.up, .up):
            hasBeenUp = true
            return false

        default:
            return false
        }
    }

    /// 신호가 끊겼을 때(관절 신뢰도 하락 등) 호출. 진행 중이던 구간을 버린다.
    /// 카운트는 유지한다 — 이미 한 것까지 지우면 안 된다.
    mutating func signalLost() {
        phase = .up
        currentZone = .middle
        zoneEnteredAt = nil
    }

    private func zone(for depth: Double) -> Zone {
        let d = min(max(depth, 0), 1)
        if d >= downThreshold { return .down }
        if d <= upThreshold { return .up }
        return .middle
    }
}
