import AVFoundation
import Foundation
import Vision

/// 폰을 바닥에 세워두고 Vision 으로 세는 카메라 모드.
///
/// **거치 전제**: 푸시업은 바닥 자세라 셀피 각도로는 절대 잡히지 않는다. 폰을 바닥에 세워
/// **정측면, 1.5~2m, 가로 방향**이어야 한다. 그 조건을 `PlacementGuideView` 가 먼저 확인하고
/// 통과해야만 세션을 시작할 수 있다.
///
/// 판정 자체는 이 클래스가 하지 않는다 — 정규화 깊이를 `DepthRepDetector`(순수)에 넘긴다.
/// 관절 → 깊이 변환도 `PoseGeometry`(순수)에 있다. 여기 남는 건 캡처 파이프라인뿐이다.
///
/// ⚠️ 시뮬레이터에서는 카메라가 없어 아무것도 검증되지 않는다. 임계값은 실기기에서
/// 기준 영상 3종(정측면 / 30° 사선 / 저조도)으로 튜닝해야 한다.
@MainActor
final class CameraRepCounter: NSObject, RepSource {

    var onRep: (() -> Void)?
    var onStatus: ((String?) -> Void)?
    /// rep 한 번이 끝날 때의 폼 점수.
    var onForm: ((PoseGeometry.FormScore) -> Void)?
    /// 거치 가이드용 — 현재 자세와 신뢰도.
    var onPose: ((PoseGeometry.Pose?, Double) -> Void)?

    /// 무릎 변형이면 힙라인 기준점이 발목이 아니라 무릎이다.
    var kneeVariant: Bool = false
    /// 실기기 튜닝으로 확정할 항목. 기본은 팔꿈치 각.
    var depthMethod: PoseGeometry.DepthMethod = .elbowAngle

    /// 이 아래로 떨어진 관절은 믿지 않는다.
    private let minConfidence: Float = 0.3
    /// 신뢰도가 이만큼 연속으로 낮으면 카운트를 멈추고 알린다.
    private let signalLossGrace: TimeInterval = 1.0

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "repflow.camera", qos: .userInitiated)

    private var detector = DepthRepDetector()
    private var startedAt: Date?
    private var baselineGap: Double?
    /// 현재 rep 동안 모인 자세. 폼 점수용.
    private var currentRepPoses: [PoseGeometry.Pose] = []
    private var lastGoodSampleAt: TimeInterval?
    private var isSignalLost = false
    /// 프레임 스킵 카운터. 캡처 델리게이트는 단일 직렬 큐에서만 불리므로 락이 필요 없다.
    private final class FrameCounter: @unchecked Sendable {
        private var value = 0
        /// 두 프레임 중 하나만 처리한다.
        func shouldProcess() -> Bool {
            value += 1
            return value.isMultiple(of: 2)
        }
        func reset() { value = 0 }
    }
    private let frames = FrameCounter()

    var previewSession: AVCaptureSession { session }

    func start() {
        detector = DepthRepDetector()
        startedAt = .now
        baselineGap = nil
        currentRepPoses = []
        lastGoodSampleAt = nil
        isSignalLost = false

        Task { await configureAndRun() }
    }

    /// 캡처는 유지한 채 카운트만 처음으로 되돌린다.
    /// 거치 확인 중에 한 시험 동작이 세어지거나, 자세를 잡는 동안의 어깨 높이가
    /// 락아웃 기준값으로 굳는 걸 막는다.
    func resetCounting() {
        detector = DepthRepDetector()
        baselineGap = nil
        currentRepPoses = []
        lastGoodSampleAt = nil
        isSignalLost = false
        startedAt = .now
        frames.reset()
    }

    func stop() {
        if detector.flush(at: elapsed) { onRep?() }
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
        startedAt = nil
    }

    // MARK: - 캡처

    private func configureAndRun() async {
        guard await requestAccess() else {
            onStatus?("카메라 권한이 필요합니다")
            return
        }
        guard configureSession() else {
            onStatus?("카메라를 열 수 없습니다")
            return
        }
        onStatus?(nil)
        queue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    private func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    private func configureSession() -> Bool {
        guard session.inputs.isEmpty else { return true }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // 720p면 관절 추정에 충분하고, 그 이상은 발열과 배터리만 먹는다.
        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return false }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { return false }
        session.addOutput(output)
        return true
    }

    private var elapsed: TimeInterval {
        guard let startedAt else { return 0 }
        return Date.now.timeIntervalSince(startedAt)
    }

    // MARK: - 관절 → 깊이

    nonisolated private func handle(pose: PoseGeometry.Pose?, confidence: Double, at time: TimeInterval) {
        Task { @MainActor in
            self.process(pose: pose, confidence: confidence, at: time)
        }
    }

    private func process(pose: PoseGeometry.Pose?, confidence: Double, at time: TimeInterval) {
        onPose?(pose, confidence)

        guard let pose, confidence >= Double(minConfidence) else {
            // 잠깐 놓친 건 무시한다 — 매 프레임 경고를 띄우면 쓸 수 없다.
            if let last = lastGoodSampleAt, time - last > signalLossGrace, !isSignalLost {
                isSignalLost = true
                detector.signalLost()
                currentRepPoses = []
                onStatus?("몸이 화면에서 벗어났습니다")
            }
            return
        }

        if isSignalLost {
            isSignalLost = false
            onStatus?(nil)
        }
        lastGoodSampleAt = time

        // 첫 유효 자세를 락아웃 기준으로 삼는다(시작은 팔을 편 상태라는 전제).
        if baselineGap == nil { baselineGap = PoseGeometry.baselineGap(pose) }

        guard let depth = PoseGeometry.depth(
            pose, method: depthMethod, baselineShoulderGap: baselineGap
        ) else { return }

        currentRepPoses.append(pose)

        if detector.ingest(depth: depth, at: time) {
            onRep?()
            if let score = PoseGeometry.formScore(for: currentRepPoses, kneeVariant: kneeVariant) {
                onForm?(score)
            }
            currentRepPoses = []
        }
    }
}

// MARK: - Vision

extension CameraRepCounter: AVCaptureVideoDataOutputSampleBufferDelegate {

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // Vision 은 비싸다. 30fps 전부 돌리면 10분짜리 세션에서 발열로 스로틀링이 걸린다.
        // 푸시업 한 번이 최소 0.7초라 15fps로도 충분하다.
        guard frames.shouldProcess() else { return }
        let time = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up, options: [:])
        try? handler.perform([request])

        guard let observation = request.results?.first else {
            handle(pose: nil, confidence: 0, at: time)
            return
        }
        let (pose, confidence) = Self.extractPose(from: observation)
        handle(pose: pose, confidence: confidence, at: time)
    }

    /// 정측면 촬영이라 **카메라를 향한 쪽** 팔다리만 쓴다. 반대쪽은 몸에 가려
    /// Vision 이 저신뢰 좌표를 내고, 섞어 쓰면 깊이 신호가 튄다.
    /// 어느 쪽이 가까운지는 어깨·팔꿈치·손목 신뢰도 합이 높은 쪽으로 고른다.
    nonisolated static func extractPose(
        from observation: VNHumanBodyPoseObservation
    ) -> (PoseGeometry.Pose?, Double) {
        guard let points = try? observation.recognizedPoints(.all) else { return (nil, 0) }

        func point(_ name: VNHumanBodyPoseObservation.JointName) -> (PoseGeometry.Point, Double)? {
            guard let p = points[name], p.confidence > 0 else { return nil }
            return (PoseGeometry.Point(p.location.x, 1 - p.location.y), Double(p.confidence))
        }

        let sides: [(shoulder: VNHumanBodyPoseObservation.JointName,
                     elbow: VNHumanBodyPoseObservation.JointName,
                     wrist: VNHumanBodyPoseObservation.JointName,
                     hip: VNHumanBodyPoseObservation.JointName,
                     knee: VNHumanBodyPoseObservation.JointName,
                     ankle: VNHumanBodyPoseObservation.JointName)] = [
            (.leftShoulder, .leftElbow, .leftWrist, .leftHip, .leftKnee, .leftAnkle),
            (.rightShoulder, .rightElbow, .rightWrist, .rightHip, .rightKnee, .rightAnkle)
        ]

        var best: (PoseGeometry.Pose, Double)?
        for side in sides {
            guard let shoulder = point(side.shoulder),
                  let elbow = point(side.elbow),
                  let wrist = point(side.wrist),
                  let hip = point(side.hip) else { continue }

            let core = [shoulder.1, elbow.1, wrist.1, hip.1]
            let confidence = core.reduce(0, +) / Double(core.count)
            let pose = PoseGeometry.Pose(
                shoulder: shoulder.0, elbow: elbow.0, wrist: wrist.0, hip: hip.0,
                ankle: point(side.ankle)?.0, knee: point(side.knee)?.0
            )
            if confidence > (best?.1 ?? 0) { best = (pose, confidence) }
        }

        guard let best else { return (nil, 0) }
        return (best.0, best.1)
    }
}
