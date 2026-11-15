import Foundation
import AVFoundation
import Observation

/// Nomi 的声音。
///
/// 之前的做法是「基础中文语音 + 音高 1.27」，听起来又尖又怪。
/// 现在两条原则：
/// ① **优先用高质量音色**（iOS 里叫「增强 / 高级」，音质接近真人）
/// ② **不做夸张变调**：音高只在 1.02–1.14 之间微动，靠语速表达情绪
@Observable
@MainActor
final class PetVoice: NSObject, AVSpeechSynthesizerDelegate {

    static let shared = PetVoice()

    var isEnabled: Bool = false

    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    /// 最近一次合成失败的原因（设置页可读）
    var lastError: String?

    /// 现在会不会走讯飞（内置密钥或用户填的，任一个齐全就算）
    var usesXunfei: Bool { XunfeiTTS.credentials() != nil }
    private var cachedVoice: AVSpeechSynthesisVoice?

    var isSpeaking: Bool {
        synthesizer.isSpeaking || player?.isPlaying == true
    }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - 发声

    /// force = 用户主动点了「念给我听」，那就别被全局开关挡住
    func speak(_ text: String, expression: PetExpression, force: Bool = false) {
        guard isEnabled || force else { return }

        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.replacingOccurrences(of: "…", with: "").count > 0 else { return }

        // 填了讯飞密钥就走讯飞，音质比系统合成好得多
        if XunfeiTTS.credentials() != nil {
            speakViaXunfei(clean, expression: expression)
            return
        }

        speakWithSystem(clean, expression: expression)
    }

    /// 音色固定为「叶子 · 女声」——实测比其它 6 个都自然
    static let chosenVoice = "x4_yezi"

    /// 系统语音（也是讯飞失败时的兜底）
    private func speakWithSystem(_ text: String, expression: PetExpression) {
        configureSessionIfNeeded()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice()
        utterance.pitchMultiplier = Self.pitch(for: expression)
        utterance.rate = Self.rate(for: expression)
        utterance.volume = 0.8
        utterance.preUtteranceDelay = 0.02
        utterance.postUtteranceDelay = 0.02

        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        player?.stop()
        player = nil
        deactivateSessionIfIdle()
    }

    // MARK: - 讯飞

    private func speakViaXunfei(_ text: String, expression: PetExpression) {
        let voice = Self.chosenVoice
        let speed = Self.xunfeiSpeed(for: expression)
        let pitch = Self.xunfeiPitch(for: expression)

        Task { @MainActor in
            do {
                let audio = try await XunfeiTTS.synthesize(text: text,
                                                           voice: voice,
                                                           speed: speed,
                                                           pitch: pitch,
                                                           volume: 75)
                player?.stop()
                guard let audioPlayer = XunfeiTTS.play(audio) else {
                    self.speakWithSystem(text, expression: expression)
                    return
                }
                player = audioPlayer

                Task { @MainActor [weak self] in
                    try? await Task.sleep(
                        nanoseconds: UInt64(max(1, audioPlayer.duration) * 1_000_000_000)
                    )
                    guard let self, self.player === audioPlayer, !audioPlayer.isPlaying else { return }
                    self.player = nil
                    self.deactivateSessionIfIdle()
                }
            } catch {
                // 讯飞挂了也要有声音，别让用户以为程序坏了
                self.lastError = error.localizedDescription
                self.speakWithSystem(text, expression: expression)
            }
        }
    }

    /// 讯飞音高 0–100。**50 才是真人的原始音高，不增不减。**
    /// 之前压到 38 听起来"假"，因为那是对真实录音做变调，会带上电音味。
    /// 情绪只用 ±5 微调。
    static func xunfeiPitch(for expression: PetExpression) -> Int {
        switch expression {
        case .calm:              return 50
        case .curious:           return 52
        case .think:             return 49
        case .bored:             return 48
        case .happy, .laugh:     return 53
        case .excited, .running: return 55
        case .startle:           return 54
        case .angry:             return 46
        case .sad, .cry:         return 47
        case .doze, .sigh:       return 45
        }
    }

    /// 语速 0–100。**50 是正常人的语速。**
    /// 说话的快慢比音高更能表达情绪，而且不会失真。
    static func xunfeiSpeed(for expression: PetExpression) -> Int {
        switch expression {
        case .calm:              return 50
        case .curious:           return 52
        case .think:             return 47
        case .bored:             return 46
        case .happy, .laugh:     return 54
        case .excited, .running: return 56
        case .startle:           return 55
        case .angry:             return 52
        case .sad, .cry:         return 45
        case .doze, .sigh:       return 42
        }
    }

    // MARK: - 音色

    private func configureSessionIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
        try? session.setActive(true, options: [])
    }

    private func deactivateSessionIfIdle() {
        guard !synthesizer.isSpeaking,
              player?.isPlaying != true,
              !MusicPlayer.shared.isPlaying
        else { return }
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.deactivateSessionIfIdle()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.deactivateSessionIfIdle()
        }
    }

    /// 优先找高质量的中文音色；找不到才退回基础音色。
    /// 高质量音色需要在 设置 → 辅助功能 → 朗读内容 里下载，装过就会自动用上。
    private func voice() -> AVSpeechSynthesisVoice? {
        if let cachedVoice { return cachedVoice }

        let all = AVSpeechSynthesisVoice.speechVoices()
        let chinese = all.filter { $0.language.hasPrefix("zh") }

        // ① 高级 / 增强
        if let best = chinese.first(where: { $0.quality == .premium })
            ?? chinese.first(where: { $0.quality == .enhanced }) {
            cachedVoice = best
            return best
        }

        // ② 普通话优先
        if let base = chinese.first(where: { $0.language == "zh-CN" })
            ?? chinese.first(where: { $0.language == "zh-TW" }) {
            cachedVoice = base
            return base
        }

        cachedVoice = AVSpeechSynthesisVoice(language: "zh-CN")
        return cachedVoice
    }

    // MARK: - 情绪 → 音高 / 语速

    /// 音高只在 1.02–1.14 动。1.27 那种是「电音」的源头。
    static func pitch(for expression: PetExpression) -> Float {
        switch expression {
        case .calm:              return 1.06
        case .curious:           return 1.09
        case .think:             return 1.05
        case .bored:             return 1.04
        case .happy, .laugh:     return 1.11
        case .excited, .running: return 1.14
        case .startle:           return 1.12
        case .angry:             return 1.02
        case .sad, .cry:         return 1.03
        case .doze, .sigh:       return 1.00
        }
    }

    /// 情绪主要靠语速表达
    static func rate(for expression: PetExpression) -> Float {
        switch expression {
        case .calm:              return 0.48
        case .curious:           return 0.50
        case .think:             return 0.45
        case .bored:             return 0.46
        case .happy, .laugh:     return 0.52
        case .excited, .running: return 0.54
        case .startle:           return 0.53
        case .angry:             return 0.52
        case .sad, .cry:         return 0.43
        case .doze, .sigh:       return 0.41
        }
    }
}
