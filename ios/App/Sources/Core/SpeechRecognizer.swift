import Foundation
import Speech
import AVFoundation
import Observation

/// 按住说话 → 实时转文字。
/// 只做一件事：把声音变成文本交给调用方，不做理解。
@Observable
@MainActor
final class SpeechRecognizer {
    var transcript = ""
    var isRecording = false
    var errorText: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func requestPermission() async -> Bool {
        let status: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        if status != .authorized {
            errorText = "没拿到语音识别权限"
            return false
        }
        let mic: Bool = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        if !mic {
            errorText = "没拿到麦克风权限"
            return false
        }
        return true
    }

    /// 从 UI 同步调用：内部自己开 Task
    func startIfNeeded() {
        guard !isRecording else { return }
        Task { await start() }
    }

    func start() async {
        guard !isRecording else { return }
        guard await requestPermission() else { return }
        guard let recognizer = recognizer, recognizer.isAvailable else {
            errorText = "语音识别暂时不可用"
            return
        }

        transcript = ""
        errorText = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }

            engine.prepare()
            try engine.start()
            isRecording = true

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }
                if let result = result {
                    Task { @MainActor in
                        self.transcript = result.bestTranscription.formattedString
                    }
                }
                if error != nil {
                    Task { @MainActor in
                        self.stop()
                    }
                }
            }
        } catch {
            errorText = "录音失败：\(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        if engine.isRunning {
            engine.stop()
        }
        if engine.inputNode.numberOfInputs > 0 {
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}