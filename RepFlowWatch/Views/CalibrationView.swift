import SwiftUI
import WatchKit

/// 캘리브레이션 화면 — 사용자가 5회 정상 동작을 수행하면 평균 amplitude를 측정해 저장.
/// 실시간 신호 bar로 사용자가 자기 동작 신호 강도를 확인하고 자세/sensitivity를 조정할 수 있게 함.
struct CalibrationView: View {

    let exercise: ExerciseKind

    @Environment(WatchCoordinator.self) private var coord
    @State private var phase: Phase = .ready
    @State private var detected: Int = 0
    @State private var error: String?
    @State private var signal: Double = 0
    @State private var threshold: Double = 0
    @State private var isBaselineReady: Bool = false
    private let target = 5

    enum Phase { case ready, baseline, running, done }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "scope").foregroundStyle(.orange)
                Text("캘리브레이션")
                Text("·")
                Text(exercise.displayName)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Spacer(minLength: 4)

            switch phase {
            case .ready: readyView
            case .baseline: baselineView
            case .running: runningView
            case .done: doneView
            }

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .onDisappear { coord.detector.stop() }
    }

    private var readyView: some View {
        VStack(spacing: 8) {
            Text("평소 속도로\n\(target)회 진행하세요")
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
            Text("시작 후 1.5초간 정지 유지\n(잡음 측정)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                start()
            } label: {
                Label("시작", systemImage: "play.fill")
            }
        }
    }

    private var baselineView: some View {
        VStack(spacing: 6) {
            ProgressView()
            Text("정지 유지")
                .font(.subheadline.weight(.bold))
            Text("잡음 측정 중…")
                .font(.caption2)
                .foregroundStyle(.secondary)
            signalBar
        }
    }

    private var runningView: some View {
        VStack(spacing: 4) {
            Text("\(detected)")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(.orange)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("/ \(target)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            signalBar
        }
    }

    private var doneView: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(.green)
            Text("저장됨")
                .font(.subheadline.weight(.bold))
            Button("닫기") { coord.backToMenu() }
                .font(.caption)
        }
    }

    /// 실시간 신호 수준 표시: 현재 |signal| / (threshold × 2)를 0~1로 정규화.
    /// threshold 선이 50% 지점에 그려져, signal이 그 선을 넘어야 rep로 인식됨.
    private var signalBar: some View {
        GeometryReader { geo in
            let denom = max(threshold * 2, 0.05)
            let normalized = min(1.0, abs(signal) / denom)
            let thresholdRatio = threshold > 0 ? min(1.0, threshold / denom) : 0.5
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.gray.opacity(0.25))
                RoundedRectangle(cornerRadius: 3)
                    .fill(signal > threshold || -signal > threshold ? Color.green : Color.orange)
                    .frame(width: geo.size.width * normalized)
                Rectangle()
                    .fill(.white.opacity(0.7))
                    .frame(width: 1, height: geo.size.height)
                    .offset(x: geo.size.width * thresholdRatio)
            }
        }
        .frame(height: 6)
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    private func start() {
        phase = .baseline
        detected = 0
        isBaselineReady = false
        coord.detector.onRepDetected = { count, _ in
            detected = count
            coord.haptic(.click)
            if count >= target {
                finalize()
            }
        }
        coord.detector.onSignalUpdate = { value, t, isCalibrated in
            signal = value
            threshold = t
            if isCalibrated && !isBaselineReady {
                isBaselineReady = true
                phase = .running
                coord.haptic(.start)
            }
        }
        do {
            try coord.detector.start(for: exercise, mode: .calibrate)
        } catch {
            self.error = error.localizedDescription
            phase = .ready
        }
    }

    private func finalize() {
        coord.detector.stop()
        let cal = coord.detector.finalizeCalibration(for: exercise)
        if cal != nil {
            phase = .done
            coord.haptic(.success)
        } else {
            phase = .ready
            coord.haptic(.failure)
        }
    }
}
