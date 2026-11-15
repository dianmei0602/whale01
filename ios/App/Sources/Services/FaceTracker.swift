import Foundation
import AVFoundation
import Vision
import Observation

/// 前置摄像头 + Vision 人脸检测 → 「它看着你」。
///
/// 三条原则：
/// 1. 只在前台、只在助理页开着，切走立刻停；
/// 2. 分辨率压到最低（.low），每 3 帧才检测一次；
/// 3. 输出做低通平滑，否则人脸检测的抖动会让眼睛抽筋。
@Observable
@MainActor
final class FaceTracker {

    /// 归一化位置：-1 左 / +1 右，-1 上 / +1 下
    var offsetX: Double = 0
    var offsetY: Double = 0

    var hasFace = false
    var isRunning = false
    var isAuthorized = false
    var errorText: String?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "jinri.face.session")
    private let processor = FaceFrameProcessor()
    private var isConfigured = false

    // MARK: - 开关

    func start() async {
        guard !isRunning else { return }

        let granted = await requestCameraAccess()
        guard granted else {
            isAuthorized = false
            errorText = "没拿到相机权限"
            return
        }
        isAuthorized = true
        errorText = nil

        processor.onFace = { [weak self] center, _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.apply(center: center)
            }
        }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.isConfigured {
                self.configureSession()
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            Task { @MainActor in
                self.isRunning = true
            }
        }
    }

    func stop() {
        guard isRunning || session.isRunning else {
            reset()
            return
        }
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            Task { @MainActor in
                self.isRunning = false
                self.reset()
            }
        }
    }

    // MARK: - 内部

    private func requestCameraAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .low

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            session.commitConfiguration()
            Task { @MainActor in
                self.errorText = "找不到前置摄像头"
            }
            return
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(processor, queue: sessionQueue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        if let connection = output.connection(with: .video),
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        session.commitConfiguration()
        isConfigured = true
    }

    /// 检测结果 → 平滑后的偏移
    private func apply(center: CGPoint?) {
        guard let center = center else {
            if hasFace {
                hasFace = false
                // 人走了：慢慢回正，不是硬跳回
                offsetX *= 0.6
                offsetY *= 0.6
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    if !self.hasFace {
                        self.offsetX = 0
                        self.offsetY = 0
                    }
                }
            }
            return
        }

        hasFace = true

        // Vision 坐标原点在左下，转成屏幕方向
        let rawX = (center.x - 0.5) * 2
        let rawY = (0.5 - center.y) * 2

        // 人在画面里通常只占中间一小块，放大两倍才有可读的位移
        let gain = 2.2
        let targetX = max(-1, min(1, rawX * gain))
        let targetY = max(-1, min(1, rawY * gain))

        // 低通：新值只吃 18%，避免抖动
        offsetX = offsetX * 0.82 + targetX * 0.18
        offsetY = offsetY * 0.82 + targetY * 0.18
    }

    private func reset() {
        offsetX = 0
        offsetY = 0
        hasFace = false
    }
}


/// 帧处理：Vision 检测放在后台队列，每 3 帧才跑一次
final class FaceFrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    /// 回调：(人脸中心，归一化坐标，原点左下) —— 没人脸时给 nil
    var onFace: ((CGPoint?, Double) -> Void)?

    private let request = VNDetectFaceRectanglesRequest()
    private var frameCounter = 0
    private var isBusy = false

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        frameCounter += 1
        guard frameCounter % 3 == 0, !isBusy else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        isBusy = true
        defer { isBusy = false }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .up,
                                            options: [:])
        do {
            try handler.perform([request])
            let faces = request.results ?? []
            // 取最大的一张脸（最近的）
            if let face = faces.max(by: { $0.boundingBox.width < $1.boundingBox.width }) {
                let box = face.boundingBox
                onFace?(CGPoint(x: box.midX, y: box.midY), Double(box.width))
            } else {
                onFace?(nil, 0)
            }
        } catch {
            onFace?(nil, 0)
        }
    }
}
