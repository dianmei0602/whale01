import SwiftUI
import UIKit

enum WhaleMotion {
    static let channel = Animation.easeInOut(duration: 0.16)
    static let control = Animation.easeOut(duration: 0.08)
}

/// Native-feeling pressed state for cards, tabs and compact controls.
struct WhalePressButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.985

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(WhaleMotion.control, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == WhalePressButtonStyle {
    static var whalePress: WhalePressButtonStyle {
        WhalePressButtonStyle()
    }
}

/// Makes visible reading content start or stop iFlytek `x4_yezi` playback.
/// The interaction is intentionally attached to the text instead of adding a
/// second set of speaker buttons across every feed.
private struct WhaleSpeakableTextModifier: ViewModifier {
    let text: String

    @EnvironmentObject private var speech: SpeechPlaybackController

    private var isCurrent: Bool {
        speech.isSpeaking && speech.currentText == text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.65)
                speech.speakOrStop(text)
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text(isCurrent ? "再次点按停止朗读" : "点按朗读这段文字"))
            .accessibilityValue(Text(isCurrent ? "正在朗读" : "点按朗读"))
            .accessibilityAction(named: Text(isCurrent ? "停止朗读" : "朗读")) {
                speech.speakOrStop(text)
            }
    }
}

extension View {
    func whaleSpeakable(_ text: String) -> some View {
        modifier(WhaleSpeakableTextModifier(text: text))
    }
}
