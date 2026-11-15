import Foundation
import AVFoundation
import MediaPlayer
import Combine

/// App 内播放器：读取系统音乐资料库里已经下载到本机的歌曲。
///
/// 不使用 `MPMusicPlayerController`，也不发布系统 Now Playing 信息，
/// 因此音乐播放时不会占用灵动岛或接管系统音乐状态。
@MainActor
final class MusicPlayer: NSObject, ObservableObject {

    static let shared = MusicPlayer()

    @Published private(set) var current: MusicTrack?
    @Published private(set) var isPlaying = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var errorText: String?

    private var player: AVAudioPlayer?
    private var queue: [MusicTrack] = []
    private var index: Int = 0
    private var ticker: Timer?

    override private init() {
        super.init()
    }

    // MARK: - 播放控制

    func play(_ track: MusicTrack, in tracks: [MusicTrack]) {
        queue = tracks.isEmpty ? [track] : tracks
        index = queue.firstIndex { $0.id == track.id } ?? 0
        start(track)
    }

    func toggle() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopTicker()
            deactivateSessionIfIdle()
        } else {
            configureSession()
            let resumed = player.play()
            isPlaying = resumed
            if resumed { startTicker() }
        }
    }

    func next() {
        guard !queue.isEmpty else { return }
        index = (index + 1) % queue.count
        start(queue[index])
    }

    func previous() {
        if let player, player.currentTime > 3 {
            player.currentTime = 0
            position = 0
            return
        }
        guard !queue.isEmpty else { return }
        index = (index - 1 + queue.count) % queue.count
        start(queue[index])
    }

    func seek(to seconds: Double) {
        guard let player else { return }
        let clamped = min(max(seconds, 0), max(0, player.duration))
        player.currentTime = clamped
        position = clamped
    }

    func stop() {
        player?.stop()
        player = nil
        current = nil
        isPlaying = false
        position = 0
        duration = 0
        stopTicker()
        deactivateSessionIfIdle()
    }

    // MARK: - 内部

    private func start(_ track: MusicTrack) {
        guard let url = track.mediaItem.assetURL else {
            errorText = "这首歌在云端或受版权保护。请先在「音乐」App 中下载到本机。"
            return
        }

        do {
            configureSession()
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            guard player.play() else {
                errorText = "这首歌暂时无法播放。"
                deactivateSessionIfIdle()
                return
            }

            self.player = player
            current = track
            isPlaying = true
            position = 0
            duration = player.duration
            errorText = nil
            startTicker()
        } catch {
            errorText = "无法播放这首歌：\(error.localizedDescription)"
            deactivateSessionIfIdle()
        }
    }

    private func configureSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func startTicker() {
        stopTicker()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                self.position = player.currentTime
                self.duration = player.duration
                if !player.isPlaying, self.isPlaying {
                    self.isPlaying = false
                }
            }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func deactivateSessionIfIdle() {
        guard !PetVoice.shared.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }
}

extension MusicPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.next()
        }
    }
}
