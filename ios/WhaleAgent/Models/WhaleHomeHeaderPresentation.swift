import Foundation

struct WhaleHomeHeaderPresentation: Equatable {
    let showsMusicIcon: Bool
    let musicAccessibilityLabel: String?

    static func content(
        isPlayingMusic: Bool,
        trackTitle: String?
    ) -> WhaleHomeHeaderPresentation {
        guard isPlayingMusic else {
            return WhaleHomeHeaderPresentation(
                showsMusicIcon: false,
                musicAccessibilityLabel: nil
            )
        }
        let title = trackTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        return WhaleHomeHeaderPresentation(
            showsMusicIcon: true,
            musicAccessibilityLabel: title.flatMap { $0.isEmpty ? nil : "正在播放 \($0)" }
                ?? "正在播放"
        )
    }
}
