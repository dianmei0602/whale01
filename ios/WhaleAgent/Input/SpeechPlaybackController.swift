import AVFoundation
import Foundation

extension Notification.Name {
    /// Posted the moment any voice recording starts so playback can be cut off.
    static let whaleInterruptSpeech = Notification.Name("whale.speech.interrupt")
}

/// Speaks every in-app reading with iFlytek Xiaolu (`x4_yezi`).
/// Missing credentials or a synthesis failure stop playback and surface an
/// error; there is deliberately no system-voice fallback.
///
/// The speaker is intentionally interruptible: starting a new recording, sending
/// a new message, or tapping the stop control cancels the current utterance
/// immediately instead of queueing it behind the old one.
@MainActor
final class SpeechPlaybackController: ObservableObject {
    static let enabledKey = "whale.voiceReplyEnabled"

    @Published private(set) var isSpeaking = false
    @Published private(set) var lastErrorText: String?
    var onStateChange: ((Bool) -> Void)?
    var onError: ((String?) -> Void)?

    private var audioLease: UUID?
    private var playbackTask: Task<Void, Never>?
    private var player: AVAudioPlayer?
    private var playbackToken: UUID?
    private let configProvider: () -> XfyunConfig?
    private let synthesizer: (String, XfyunConfig) async throws -> Data

    init(
        configProvider: @escaping () -> XfyunConfig? = { XfyunConfig.current },
        synthesizer: @escaping (String, XfyunConfig) async throws -> Data = {
            try await XfyunTTSClient.synthesize($0, config: $1)
        }
    ) {
        self.configProvider = configProvider
        self.synthesizer = synthesizer
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        if !enabled {
            stop()
        }
    }

    @discardableResult
    func speak(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        stop()
        guard let config = configProvider() else {
            failPlayback("未配置讯飞小露 x4_yezi，App 朗读暂不可用")
            return false
        }
        guard activateSession() else {
            failPlayback("无法启动语音播放，请稍后重试")
            return false
        }

        let token = UUID()
        playbackToken = token
        lastErrorText = nil
        onError?(nil)
        isSpeaking = true
        onStateChange?(true)

        playbackTask = Task { [weak self] in
            guard let self else { return }
            do {
                let chunks = XfyunTTSClient.splitText(trimmed)
                for (index, chunk) in chunks.enumerated() {
                    let audio = try await self.synthesizer(chunk, config)
                    try Task.checkCancellation()
                    guard self.playbackToken == token else { return }
                    try await self.playCloud(
                        audio,
                        token: token,
                        finishAfterPlayback: index == chunks.count - 1
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, self.playbackToken == token else { return }
                self.failPlayback(
                    (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription
                )
            }
        }
        return true
    }

    func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        playbackToken = nil
        player?.stop()
        player = nil
        if isSpeaking {
            isSpeaking = false
            onStateChange?(false)
        }
        deactivateSession()
    }

    func clearError() {
        lastErrorText = nil
        onError?(nil)
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
        isSpeaking = false
        onStateChange?(false)
        deactivateSession()
    }

    private func failPlayback(_ message: String) {
        playbackTask?.cancel()
        playbackTask = nil
        playbackToken = nil
        player?.stop()
        player = nil
        lastErrorText = message
        onError?(message)
        if isSpeaking {
            isSpeaking = false
            onStateChange?(false)
        }
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
