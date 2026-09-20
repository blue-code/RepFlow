import AVFoundation
import SwiftUI

/// 카메라 모드 시작 전 거치 확인.
///
/// 이 화면이 카메라 모드의 실질적 MVP다. 푸시업은 바닥 자세라 셀피 각도로는 절대 잡히지 않는데,
/// 안내 없이 "카메라로 세기"만 열어두면 대부분 천장을 찍다가 0개로 끝난다.
/// 3초 연속 조건을 만족해야만 시작 버튼이 열린다.
struct PlacementGuideView: View {

    let counter: CameraRepCounter
    let onReady: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var gate = PlacementGate()
    @State private var status: String?
    @State private var startedAt = Date.now

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
            counter.onStatus = { status = $0 }
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

            Text("폰을 바닥에 세워 옆에서 1.5~2m. 영상은 기기 안에서만 분석되고 저장되지 않습니다.")
                .font(.rfCaptionSm)
                .foregroundStyle(RFColor.fgMuted)
                .multilineTextAlignment(.center)

            ProgressView(value: gate.progress)
                .tint(RFColor.success)

            Button("시작") {
                counter.onPose = nil
                onReady()
            }
            .buttonStyle(RFPrimaryButton())
            .disabled(!gate.isReady)

            Button("탭으로 세기") { dismiss() }
                .buttonStyle(RFSecondaryButton())
        }
        .padding(RFSpace.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RFRadius.lg))
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
