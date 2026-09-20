import Foundation
import UIKit

/// 폰을 가슴 아래 바닥에 눕혀두고 근접센서로 센다.
///
/// 거치도 조명도 캘리브레이션도 필요 없는 제로 셋업 방식이고, **책상에서 손으로 검증할 수 있는
/// 유일한 모드**라 회귀 테스트의 기준점으로도 쓴다.
///
/// 근접센서는 상태가 바뀔 때만 알려준다. 그래서 `DepthRepDetector` 의 희소 이벤트 경로를 쓰고,
/// 마지막 1회가 다음 이벤트를 기다리다 사라지지 않도록 저주기 타이머로 현재 상태를 계속 흘린다.
@MainActor
final class ProximityRepCounter: RepSource {

    var onRep: (() -> Void)?
    var onStatus: ((String?) -> Void)?

    private var detector = DepthRepDetector()
    private var poller: Timer?
    private var startedAt: Date?
    private let device = UIDevice.current

    /// 근접센서를 켜면 화면이 꺼진다. 이 모드는 소리로 안내하는 게 전제다.
    func start() {
        // 세트마다 다시 시작되므로, 이전 옵저버와 타이머가 쌓이지 않게 먼저 정리한다.
        teardown()
        detector = DepthRepDetector()
        startedAt = .now
        device.isProximityMonitoringEnabled = true

        guard device.isProximityMonitoringEnabled else {
            onStatus?("이 기기에서는 근접센서를 쓸 수 없습니다")
            return
        }
        onStatus?(nil)

        NotificationCenter.default.addObserver(
            self, selector: #selector(proximityChanged),
            name: UIDevice.proximityStateDidChangeNotification, object: nil
        )
        // 이벤트만으로는 마지막 구간이 확정되지 않는다. 현재 상태를 주기적으로 다시 흘린다.
        poller = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    func stop() {
        teardown()
        // 마지막 1회를 흘리지 않는다. 콜백이 살아 있을 때 불러야 의미가 있다.
        if detector.flush(at: elapsed) { onRep?() }
        device.isProximityMonitoringEnabled = false
        startedAt = nil
    }

    private func teardown() {
        poller?.invalidate()
        poller = nil
        NotificationCenter.default.removeObserver(
            self, name: UIDevice.proximityStateDidChangeNotification, object: nil
        )
    }

    @objc private func proximityChanged() {
        Task { @MainActor in self.sample() }
    }

    private func sample() {
        // 가림 = 가슴이 내려온 상태 = 깊이 1.
        if detector.ingest(depth: device.proximityState ? 1 : 0, at: elapsed) {
            onRep?()
        }
    }

    private var elapsed: TimeInterval {
        guard let startedAt else { return 0 }
        return Date.now.timeIntervalSince(startedAt)
    }
}
