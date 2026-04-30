import SwiftUI
import WatchKit

/// 캘리브레이션 화면 — 사용자가 5회 정상 동작을 수행하면 평균 amplitude를 측정해 저장
struct CalibrationView: View {

    let exercise: ExerciseKind

    @Environment(WatchCoordinator.self) private var coord
    @State private var phase: Phase = .ready
    @State private var detected: Int = 0
    @State private var error: String?
    private let target = 5

    enum Phase { case ready, running, done }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "scope").foregroundStyle(.orange)
                Text("캘리브레이션")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(exercise.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            switch phase {
            case .ready:
                readyView
            case .running:
                runningView
            case .done:
                doneView
            }

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 4)
        .onDisappear { coord.detector.stop() }
    }

    private var readyView: some View {
        VStack(spacing: 8) {
            Text("평소 속도로\n\(target)회 진행하세요")
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
            Button {
                start()
            } label: {
                Label("시작", systemImage: "play.fill")
            }
        }
    }

    private var runningView: some View {
        VStack(spacing: 4) {
            Text("\(detected)")
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(.orange)
                .contentTransition(.numericText())
            Text("/ \(target)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
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

    private func start() {
        phase = .running
        detected = 0
        coord.detector.onRepDetected = { count, _ in
            detected = count
            coord.haptic(.click)
            if count >= target {
                finalize()
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
            // 측정 부족
            phase = .ready
            coord.haptic(.failure)
        }
    }
}
