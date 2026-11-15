import AVFoundation
import Foundation

extension Notification.Name {
    /// Posted the moment any voice recording starts so playback can be cut off.
    static let whaleInterruptSpeech = Notification.Name("whale.speech.interrupt")
}

/// Speaks assistant replies with iFlytek Xiaolu (`x4_yezi`) and falls back to
/// the system Chinese voice only when Xfyun is unavailable.
///
/// The speaker is intentionally interruptible: starting a new recording, sending
/// a new message, or tapping the stop control cancels the current utterance
/// immediately instead of queueing it behind the old one.
@MainActor
final class SpeechPlaybackController: NSObject, ObservableObject {
    static let enabledKey = "whale.voiceReplyEnabled"

    @Published private(set) var isSpeaking = false
    var onStateChange: ((Bool) -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private var audioLease: UUID?
    private var currentUtterance: AVSpeechUtterance?
    private var playbackTask: Task<Void, Never>?
    private var player: AVAudioPlayer?
    private var playbackToken: UUID?

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

        let token = UUID()
        playbackToken = token
        isSpeaking = true
        onStateChange?(true)

        playbackTask = Task { [weak self] in
            guard let self else { return }
            if let config = XfyunConfig.current {
                do {
                    let chunks = XfyunTTSClient.splitText(trimmed)
                    for (index, chunk) in chunks.enumerated() {
                        let audio = try await XfyunTTSClient.synthesize(chunk, config: config)
                        try Task.checkCancellation()
                        guard self.playbackToken == token else { return }
                        try await self.playCloud(
                            audio,
                            token: token,
                            finishAfterPlayback: index == chunks.count - 1
                        )
                    }
                    return
                } catch {
                    guard !Task.isCancelled, self.playbackToken == token else { return }
                }
            }
            self.speakWithSystem(trimmed)
        }
    }

    private func speakWithSystem(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.05

        currentUtterance = utterance
        synthesizer.speak(utterance)
    }

    func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        playbackToken = nil
        player?.stop()
        player = nil
        currentUtterance = nil
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        if isSpeaking {
            isSpeaking = false
            onStateChange?(false)
        }
        deactivateSession()
    }

    private func playCloud(_ audio: Data, token: UUID, finishAfterPlayback: Bool) async throws {
        let player = try AVAudioPlayer(data: audio)
        player.prepareToPlay()
        guard player.play() else {
            throw XfyunTTSError.emptyAudio
        }
        self.player = player
        try await Task.sleep(
            nanoseconds: UInt64((max(player.duration, 0.1) + 0.12) * 1_000_000_000)
        )
        guard !Task.isCancelled, playbackToken == token else { return }
        self.player = nil
        if finishAfterPlayback {
            finishPlayback()
        }
    }

    private func finishPlayback() {
        playbackTask = nil
        playbackToken = nil
        currentUtterance = nil
        isSpeaking = false
        onStateChange?(false)
        deactivateSession()
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

}

extension SpeechPlaybackController: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.currentUtterance === utterance else { return }
            self.finishPlayback()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.currentUtterance === utterance else { return }
            self.finishPlayback()
        }
    }
}
