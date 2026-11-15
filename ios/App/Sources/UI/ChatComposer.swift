import SwiftUI

/// 鲸鱼 UI 的固定输入栏。
///
/// 保持一条清晰的主路径：输入、说话或发送。
struct ChatComposer: View {
    @Binding var draft: String
    var onSend: () -> Void
    var onTalk: () -> Void
    @FocusState.Binding var focused: Bool

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("发消息，或点右侧说话", text: $draft, axis: .vertical)
                .font(.nomiScaled(size: 16))
                .foregroundStyle(CardPalette.ink)
                .lineLimit(1...4)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit {
                    if canSend { onSend() } else { onTalk() }
                }
                .padding(.horizontal, 4)
                .frame(minHeight: 40)

            if canSend {
                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.nomiScaled(size: 15, weight: .bold))
                        .foregroundStyle(CardPalette.navyInk)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [CardPalette.accent, CardPalette.accent2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(WhalePressStyle(scale: 0.91))
                .accessibilityLabel("发送")
                .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: onTalk) {
                    Image(systemName: "waveform")
                        .font(.nomiScaled(size: 16, weight: .semibold))
                        .foregroundStyle(CardPalette.accent)
                        .frame(width: 44, height: 44)
                        .background(CardPalette.accent.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(WhalePressStyle(scale: 0.91))
                .accessibilityLabel("开始语音输入")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.leading, 13)
        .padding(.trailing, 7)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(CardPalette.composer)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(
                    focused ? CardPalette.accent.opacity(0.48) : CardPalette.lineStrong,
                    lineWidth: focused ? 1.3 : 1
                )
        }
        .shadow(color: Color.black.opacity(0.13), radius: 12, y: 6)
        .animation(.spring(response: 0.30, dampingFraction: 0.82), value: canSend)
        .animation(.easeOut(duration: 0.16), value: focused)
        .sensoryFeedback(.selection, trigger: canSend)
        .padding(.horizontal, 14)
        .padding(.top, 7)
        .padding(.bottom, 8)
    }
}
