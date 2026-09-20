import Foundation
import Testing
@testable import RepFlow

/// 카메라·근접센서가 공유하는 판정기. 실기기 없이 합성 신호로 검증한다.
@Suite("깊이 신호 rep 판정")
struct DepthRepDetectorTests {

    /// 한 번의 푸시업: 위 → 아래 → 위.
    private func pushUps(
        _ count: Int,
        cadence: TimeInterval = 2.0,
        depth: Double = 1.0,
        samplesPerPhase: Int = 10
    ) -> [(Double, TimeInterval)] {
        var samples: [(Double, TimeInterval)] = []
        var t: TimeInterval = 0
        let step = cadence / Double(samplesPerPhase * 2)

        // 시작 자세 — 위에서 잠시 대기
        for _ in 0..<samplesPerPhase { samples.append((0.0, t)); t += step }

        for _ in 0..<count {
            for _ in 0..<samplesPerPhase { samples.append((depth, t)); t += step }
            for _ in 0..<samplesPerPhase { samples.append((0.0, t)); t += step }
        }
        return samples
    }

    private func run(_ samples: [(Double, TimeInterval)],
                     detector: DepthRepDetector = DepthRepDetector()) -> Int {
        var d = detector
        for (depth, t) in samples { d.ingest(depth: depth, at: t) }
        return d.count
    }

    @Test("정상 템포 20회를 정확히 센다")
    func countsTwenty() {
        #expect(run(pushUps(20)) == 20)
    }

    @Test("느린 템포도 빠른 템포도 센다", arguments: [1.0, 2.0, 4.0, 6.0])
    func countsAcrossCadence(cadence: TimeInterval) {
        #expect(run(pushUps(10, cadence: cadence)) == 10)
    }

    @Test("얕은 반복은 세지 않는다 — 깊이 임계에 못 미친다")
    func ignoresShallowReps() {
        // 0.6 은 downThreshold(0.75) 미만
        #expect(run(pushUps(10, depth: 0.6)) == 0)
    }

    @Test("가만히 있으면 세지 않는다")
    func ignoresStillness() {
        let still = (0..<200).map { (0.0, TimeInterval($0) * 0.03) }
        #expect(run(still) == 0)
    }

    @Test("엎드린 채 가만히 있어도 세지 않는다")
    func ignoresHoldingBottom() {
        let held = (0..<200).map { (1.0, TimeInterval($0) * 0.03) }
        #expect(run(held) == 0)
    }

    @Test("떨림(임계 근처 진동)은 한 번으로 세지 않는다")
    func ignoresJitter() {
        var samples: [(Double, TimeInterval)] = []
        var t: TimeInterval = 0
        for _ in 0..<10 { samples.append((0.0, t)); t += 0.03 }
        // 0.25~0.75 사이에서만 흔들린다 — 어느 임계도 넘지 않는다
        for i in 0..<300 {
            samples.append((0.5 + 0.2 * sin(Double(i) * 0.5), t))
            t += 0.03
        }
        #expect(run(samples) == 0)
    }

    @Test("사람이 낼 수 없는 속도는 세지 않는다")
    func rejectsImpossiblyFast() {
        // 0.05초마다 위아래 — 최소 구간 유지 시간(0.35s) 미만
        var samples: [(Double, TimeInterval)] = []
        var t: TimeInterval = 0
        samples.append((0.0, t)); t += 0.4
        for i in 0..<100 {
            samples.append((i % 2 == 0 ? 1.0 : 0.0, t))
            t += 0.05
        }
        #expect(run(samples) == 0)
    }

    @Test("시작부터 엎드려 있어도 첫 기상은 세지 않는다")
    func doesNotCountInitialRise() {
        var samples: [(Double, TimeInterval)] = []
        var t: TimeInterval = 0
        for _ in 0..<20 { samples.append((1.0, t)); t += 0.05 }   // 엎드린 채 시작
        for _ in 0..<20 { samples.append((0.0, t)); t += 0.05 }   // 일어남 — 세면 안 된다
        #expect(run(samples) == 0)
    }

    @Test("신호가 끊겨도 이미 센 것은 지우지 않는다")
    func keepsCountOnSignalLoss() {
        var d = DepthRepDetector()
        for (depth, t) in pushUps(5) { d.ingest(depth: depth, at: t) }
        #expect(d.count == 5)

        d.signalLost()
        #expect(d.count == 5)
        #expect(d.phase == .up)
    }

    @Test("신호가 끊겼다 돌아오면 이어서 센다")
    func resumesAfterSignalLoss() {
        var d = DepthRepDetector()
        for (depth, t) in pushUps(3) { d.ingest(depth: depth, at: t) }
        d.signalLost()
        for (depth, t) in pushUps(3).map({ ($0.0, $0.1 + 100) }) { d.ingest(depth: depth, at: t) }
        #expect(d.count == 6)
    }

    @Test("범위 밖 값이 들어와도 무너지지 않는다")
    func clampsOutOfRange() {
        var d = DepthRepDetector()
        var t: TimeInterval = 0
        for _ in 0..<10 { d.ingest(depth: -5, at: t); t += 0.05 }
        for _ in 0..<10 { d.ingest(depth: 99, at: t); t += 0.05 }
        for _ in 0..<10 { d.ingest(depth: -5, at: t); t += 0.05 }
        #expect(d.count == 1)
    }

    @Test("근접센서처럼 바뀔 때만 오는 희소 이벤트도 센다")
    func handlesSparseBinaryEvents() {
        // 근접센서는 중간값도, 주기적 샘플도 없다 — 가림(1) / 해제(0) 전이만 온다.
        var d = DepthRepDetector()
        var t: TimeInterval = 0
        d.ingest(depth: 0.0, at: t); t += 0.5
        for _ in 0..<10 {
            d.ingest(depth: 1.0, at: t); t += 0.6
            d.ingest(depth: 0.0, at: t); t += 0.6
        }
        // 마지막 1회는 다음 이벤트가 없으면 미완성으로 남는다 — 세션 종료 시 flush 해야 한다.
        #expect(d.count == 9, "flush 전에는 마지막 회차가 아직 확정되지 않는다")
        d.flush(at: t)
        #expect(d.count == 10)
    }

    @Test("flush 는 충분히 머물지 않은 구간까지 세지는 않는다")
    func flushDoesNotInventReps() {
        var d = DepthRepDetector()
        d.ingest(depth: 0.0, at: 0)
        d.ingest(depth: 1.0, at: 0.5)
        d.ingest(depth: 0.0, at: 1.1)
        let before = d.count
        d.flush(at: 1.2)            // 위 구간에 0.1초밖에 없었다
        #expect(d.count == before)
    }
}
