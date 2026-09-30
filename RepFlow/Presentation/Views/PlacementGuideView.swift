import AVFoundation
import SwiftUI

/// 카메라 모드 시작 전 거치 확인.
///
/// 이 화면이 카메라 모드의 실질적 MVP다. **전면 렌즈**라 사용자는 여기서 자기 모습을 보며
/// 폰 위치를 맞춘다 — 그래도 손에 들고 셀피처럼 내려다보면 몸이 가로로 눕지 않아 통과하지 못한다.
/// 폰을 바닥에 세워 옆에서 찍어야 한다.
///
/// ⚠️ **시작 버튼은 없다.** 자세를 3초 유지하면 스스로 시작한다. 예전엔 "준비 완료" 후에
/// 시작 버튼을 눌러야 했는데, 버튼은 1.5~2m 밖 바닥에 있는 폰 화면에 있다. 누르러 가는 순간
/// 자세가 풀려 게이트가 리셋되고 버튼이 다시 비활성화된다 — 혼자서는 절대 시작할 수 없는
/// 구조였다. 안내와 카운트다운은 **소리**로 한다. 그 거리에서 글자는 읽을 수 없다.
struct PlacementGuideView: View {

    let counter: CameraRepCounter
    /// 화면을 볼 수 없는 거리라 안내는 소리로 나간다.
    let speech: SpeechCounter
    /// true = 거치 확인 통과, false = 사용자가 포기(탭 모드로 되돌린다).
    let onFinish: (Bool) -> Void

    @State private var gate = PlacementGate()
    @State private var status: String?
    @State private var startedAt = Date.now
    @State private var permissionDenied = false
    @State private var hasStarted = false
    @State private var lastSpokenGuidance: String?
    @State private var lastGuidanceAt = Date.distantPast

    /// 안내가 바뀌어도 이만큼은 쉬었다 말한다 — 관절이 튈 때마다 떠들면 못 쓴다.
    private let guidanceMinGap: TimeInterval = 1.5
    /// 같은 문제가 계속되면 이 주기로 다시 말한다. 화면을 못 보는 사람에겐 침묵이 곧 정보 없음이다.
    private let guidanceRepeatGap: TimeInterval = 5.0

    var body: some View {
        ZStack {
            CameraPreview(session: counter.previewSession)
                .ignoresSafeArea()

            // 가로로 누운 실루엣 가이드 — 어디에 어떻게 누우면 되는지 보여준다.
            silhouette

            VStack {
                Spacer()
                panel
            }
            .padding(RFSpace.lg)
        }
        .navigationTitle("거치 확인")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            counter.onStatus = { message in
                status = message
                // 권한 거부는 화면에서 빠져나갈 길을 줘야 한다.
                permissionDenied = message?.contains("권한") == true
            }
            counter.onPose = { pose, confidence in
                gate.update(
                    pose: pose, confidence: confidence,
                    at: Date.now.timeIntervalSince(startedAt)
                )
                // 안내는 여기서 흘린다. `onChange(of: message)` 로 하면 문제가 A→B→A 로
                // 튈 때 스로틀에 먹힌 안내가 영영 다시 나오지 않는다.
                speakGuidanceIfNeeded(message)
            }
            counter.start()
        }
        .onDisappear { counter.onPose = nil }
        .onChange(of: countdown) { _, remaining in
            if let remaining, remaining > 0 { speech.announceStartCountdown(remaining) }
        }
        .onChange(of: gate.isReady) { _, ready in
            if ready { beginCounting() }
        }
    }

    /// 자세를 잡은 사람은 화면을 못 본다 — 3초 게이트를 그대로 카운트다운으로 쓴다.
    private var countdown: Int? {
        guard gate.verdict.isOK else { return nil }
        let remaining = gate.check.requiredStableDuration - gate.stableFor
        return max(0, Int(remaining.rounded(.up)))
    }

    private func beginCounting() {
        guard !hasStarted else { return }
        hasStarted = true
        speech.announceStart()
        counter.onPose = nil
        onFinish(true)
    }

    private func speakGuidanceIfNeeded(_ text: String) {
        // 통과한 뒤에는 카운트다운이 말을 이어받는다.
        guard !hasStarted, !gate.verdict.isOK else { return }
        let elapsed = Date.now.timeIntervalSince(lastGuidanceAt)
        let changed = text != lastSpokenGuidance
        guard elapsed >= (changed ? guidanceMinGap : guidanceRepeatGap) else { return }
        lastSpokenGuidance = text
        lastGuidanceAt = .now
        speech.announcePlacement(text)
    }

    private var silhouette: some View {
        RoundedRectangle(cornerRadius: RFRadius.lg)
            .stroke(gate.verdict.isOK ? RFColor.success : RFColor.fgSubtle,
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .padding(.horizontal, RFSpace.xl)
            .overlay {
                if let countdown, countdown > 0 {
                    Text("\(countdown)")
                        .font(.system(size: 96, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(RFColor.success)
                } else if !gate.verdict.isOK {
                    Text("여기에 옆모습이 들어오게")
                        .font(.rfCaption)
                        .foregroundStyle(RFColor.fgMuted)
                }
            }
    }

    private var panel: some View {
        VStack(spacing: RFSpace.md) {
            Text(message)
                .font(.rfTitleMd)
                .foregroundStyle(gate.verdict.isOK ? RFColor.success : RFColor.fg)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.rfCaptionSm)
                .foregroundStyle(RFColor.fgMuted)
                .multilineTextAlignment(.center)

            ProgressView(value: gate.progress)
                .tint(RFColor.success)

            if permissionDenied {
                Button("설정에서 카메라 켜기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(RFPrimaryButton())
            }

            // 시작 버튼은 두지 않는다 — 누르러 가면 자세가 풀린다(위 주석).
            // 빠져나갈 길만 남긴다.
            Button("탭으로 세기") {
                counter.onPose = nil
                counter.stop()
                onFinish(false)
            }
            .buttonStyle(RFSecondaryButton())
        }
        .padding(RFSpace.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RFRadius.lg))
    }

    /// 전신이 안 들어와도 시작할 수 있다는 걸 여기서 알려준다 — 모르면 다들 뒤로 물러나기만 한다.
    private var subtitle: String {
        guard gate.verdict.isOK else {
            return "폰을 바닥에 세워 옆에서 — 화면이 나를 보게. 전신이 안 들어와도 상체만 보이면 셀 수 있습니다."
        }
        switch gate.framing {
        case .fullBody:
            return "전신이 들어왔습니다 — 폼 점수까지 나옵니다."
        case .upperBody:
            return "상체 기준으로 셉니다 — 카운트는 되고 폼 점수는 없습니다. 다리까지 넣으려면 조금 더 뒤로."
        }
    }

    private var message: String {
        if let status { return status }
        switch gate.verdict {
        case .ok:
            return gate.isReady ? "시작합니다" : "그대로 유지하세요"
        case .problem(let problem):
            return problem.message
        }
    }
}

/// AVCaptureSession 미리보기.
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
