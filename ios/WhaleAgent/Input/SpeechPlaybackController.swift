import AVFoundation
import Foundation

extension Notification.Name {
    /// Posted the moment any voice recording starts so playback can be cut off.
    static let whaleInterruptSpeech = Notification.Name("whale.speech.interrupt")
}

/// Speaks assistant replies with iFlytek `x4_yezi` when configured and falls
/// back to the system Chinese voice when credentials, network, or the voice
/// entitlement are unavailable.
///
/// The speaker is intentionally interruptible: starting a new recording, sending
/// a new message, or tapping the stop control cancels the current utterance
/// immediately instead of queueing it behind the old one.
@MainActor
final class SpeechPlaybackController: NSObject, ObservableObject {
    static let enabledKey = "whale.voiceReplyEnabled"

    @Published private(set) var isSpeaking = false
    @Published private(set) var currentText: String?
    @Published private(set) var lastError: String?
    @Published private(set) var engineLabel = XfyunConfig.isConfigured ? "讯飞 \(XfyunConfig.ttsVoiceName)" : "系统中文语音"
    var onStateChange: ((Bool) -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private var audioLease: UUID?
    private var currentUtterance: AVSpeechUtterance?
    private var player: AVAudioPlayer?
    private var synthesisTask: Task<Void, Never>?
    private var requestToken = UUID()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        if !enabled {
            stop()
        }
    }

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        stop()
        guard activateSession() else { return }

        requestToken = UUID()
        let token = requestToken
        currentText = trimmed
        lastError = nil
        isSpeaking = true
        onStateChange?(true)

        if let credentials = XfyunConfig.currentCredentials,
           let client = XfyunTTSClient(config: credentials) {
            engineLabel = "讯飞 \(XfyunConfig.ttsVoiceName)"
            synthesisTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let audio = try await client.synthesize(trimmed)
                    guard !Task.isCancelled, self.requestToken == token else { return }
                    try self.playXfyunAudio(audio)
                } catch is CancellationError {
                    return
                } catch {
                    guard self.requestToken == token else { return }
                    self.lastError = "讯飞 \(XfyunConfig.ttsVoiceName) 不可用，已回退系统语音：\(error.localizedDescription)"
                    self.startSystemSpeech(trimmed)
                }
            }
        } else {
            engineLabel = "系统中文语音"
            lastError = "讯飞未配置，当前使用系统中文语音"
            startSystemSpeech(trimmed)
        }
    }

    /// A second tap on the same reading content is a stop gesture. This keeps
    /// tap-to-read predictable across cards where no dedicated speaker button
    /// is visible.
    func speakOrStop(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if isSpeaking && currentText == trimmed {
            stop()
        } else {
            speak(trimmed)
        }
    }

    private func startSystemSpeech(_ text: String) {
        synthesisTask = nil
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { finish() ; return }
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.05

        currentUtterance = utterance
        synthesizer.speak(utterance)
    }

    private func playXfyunAudio(_ data: Data) throws {
        synthesisTask = nil
        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        player.prepareToPlay()
        self.player = player
        guard player.play() else {
            throw NSError(domain: "WhaleSpeech", code: -1, userInfo: [NSLocalizedDescriptionKey: "音频播放器没有启动"])
        }
    }

    func stop() {
        requestToken = UUID()
        synthesisTask?.cancel()
        synthesisTask = nil
        player?.stop()
        player = nil
        currentUtterance = nil
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        currentText = nil
        if isSpeaking {
            finish()
        } else {
            deactivateSession()
        }
    }

    private func activateSession() -> Bool {
        do {
            audioLease = try AudioSessionCoordinator.shared.acquire(.speech) { [weak self] in self?.stop() }
            return true
        } catch { return false }
    }

    private func deactivateSession() {
        AudioSessionCoordinator.shared.release(audioLease)
        audioLease = nil
    }

    private func finish() {
        guard isSpeaking else { return }
        isSpeaking = false
        onStateChange?(false)
        deactivateSession()
    }

}

extension SpeechPlaybackController: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.currentUtterance === utterance else { return }
            self.currentUtterance = nil
            self.currentText = nil
            self.finish()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.currentUtterance === utterance else { return }
            self.currentUtterance = nil
            self.currentText = nil
            self.finish()
        }
    }
}

extension SpeechPlaybackController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard self.player === player else { return }
            self.player = nil
            self.currentText = nil
            self.finish()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            guard self.player === player else { return }
            self.player = nil
            self.lastError = error?.localizedDescription ?? "讯飞音频解码失败"
            if let text = self.currentText {
                self.startSystemSpeech(text)
            } else {
                self.finish()
            }
        }
    }
}
