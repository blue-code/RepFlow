import AVFoundation
import SwiftUI

/// 카메라 모드 시작 전 거치 확인.
///
/// 이 화면이 카메라 모드의 실질적 MVP다. **전면 렌즈**라 사용자는 여기서 자기 모습을 보며
/// 폰 위치를 맞춘다 — 그래도 손에 들고 셀피처럼 내려다보면 몸이 가로로 눕지 않아 통과하지 못한다.
/// 폰을 바닥에 세워 옆에서 찍어야 한다. 3초 연속 조건을 만족해야만 시작 버튼이 열린다.
struct PlacementGuideView: View {

    let counter: CameraRepCounter
    /// true = 거치 확인 통과, false = 사용자가 포기(탭 모드로 되돌린다).
    let onFinish: (Bool) -> Void

    @State private var gate = PlacementGate()
    @State private var status: String?
    @State private var startedAt = Date.now
    @State private var permissionDenied = false

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
            }
            counter.start()
        }
        .onDisappear { counter.onPose = nil }
    }

    private var silhouette: some View {
        RoundedRectangle(cornerRadius: RFRadius.lg)
            .stroke(gate.verdict.isOK ? RFColor.success : RFColor.fgSubtle,
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .padding(.horizontal, RFSpace.xl)
            .overlay {
                if !gate.verdict.isOK {
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
            } else {
                Button("시작") {
                    counter.onPose = nil
                    onFinish(true)
                }
                .buttonStyle(RFPrimaryButton())
                .disabled(!gate.isReady)
            }

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
            return gate.isReady ? "준비 완료" : "자세 유지…"
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
