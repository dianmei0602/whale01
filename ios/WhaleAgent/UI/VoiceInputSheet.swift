import SwiftUI

/// The single voice-conversation surface used by every screen.
/// Callers provide only how the finished text enters their own flow.
struct WhaleVoiceInputSheet: View {
    @StateObject private var voice = VoiceInputController()
    let onSend: (String) -> Void
    let onUseText: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VoiceView(
            voice: voice,
            onSend: onSend,
            onClose: onUseText,
            onCancel: onCancel
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voice-sheet")
        .task {
            guard !voice.isRecording else { return }
            await voice.start()
        }
        .presentationDetents([.height(460)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(WhaleTheme.card)
    }
}
