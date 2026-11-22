import SwiftUI
import UIKit

struct WhaleAgentWeChatMessageFrame<Content: View>: View {
    let layout: WhaleChatMessageLayout
    private let content: Content

    init(
        layout: WhaleChatMessageLayout,
        @ViewBuilder content: () -> Content
    ) {
        self.layout = layout
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if layout.avatarIsLeading {
                WhaleAgentWeChatAvatar(kind: layout.avatar)
                content
                Spacer(minLength: 22)
            } else {
                Spacer(minLength: 42)
                content
                WhaleAgentWeChatAvatar(kind: layout.avatar)
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: layout.avatarIsLeading ? .leading : .trailing
        )
        .accessibilityIdentifier(
            layout.avatarIsLeading ? "wechat-row-incoming" : "wechat-row-outgoing"
        )
    }
}

struct WhaleAgentWeChatAvatar: View {
    let kind: WhaleChatAvatar

    var body: some View {
        Group {
            switch kind {
            case .whale:
                WhaleMarkView(size: 34)
            case .person:
                ZStack {
                    Circle()
                        .fill(WhaleIMessagePalette.userAvatarBackground)
                    Image(systemName: "person.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(WhaleIMessagePalette.userAvatarInk)
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.58), lineWidth: 0.8)
                }
            }
        }
        .frame(width: 34, height: 34)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind == .whale ? "鲸鱼头像" : "我的头像")
        .accessibilityIdentifier(
            kind == .whale ? "wechat-avatar-whale" : "wechat-avatar-person"
        )
    }
}

struct WhaleAgentWeChatTextRow: View {
    let text: String
    let layout: WhaleChatMessageLayout
    var isStreaming = false

    var body: some View {
        WhaleAgentWeChatMessageFrame(layout: layout) {
            VStack(
                alignment: layout.bubblePointsRight ? .trailing : .leading,
                spacing: 4
            ) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(text)
                        .whaleFont(size: 16)
                        .lineSpacing(3)
                        .foregroundStyle(
                            layout.bubblePointsRight
                                ? WhaleIMessagePalette.outgoingText
                                : WhaleIMessagePalette.text
                        )
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)

                    if isStreaming {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(
                                layout.bubblePointsRight
                                    ? WhaleIMessagePalette.outgoingText
                                    : WhaleIMessagePalette.outgoing
                            )
                    }
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .padding(.leading, layout.bubblePointsRight ? 0 : 8)
                .padding(.trailing, layout.bubblePointsRight ? 8 : 0)
                .background {
                    WhaleAgentWeChatBubbleBackground(
                        pointsRight: layout.bubblePointsRight
                    )
                }
                .shadow(
                    color: layout.bubblePointsRight ? .clear : .black.opacity(0.055),
                    radius: 1.4,
                    y: 1
                )
            }
            .frame(
                maxWidth: 292,
                alignment: layout.bubblePointsRight ? .trailing : .leading
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            layout.bubblePointsRight ? "我说：\(text)" : "鲸鱼说：\(text)"
        )
    }
}

struct WhaleAgentWeChatCardRow<Content: View>: View {
    let layout: WhaleChatMessageLayout
    private let content: Content

    init(
        layout: WhaleChatMessageLayout,
        @ViewBuilder content: () -> Content
    ) {
        self.layout = layout
        self.content = content()
    }

    var body: some View {
        WhaleAgentWeChatMessageFrame(layout: layout) {
            content
                .frame(maxWidth: 292, alignment: .leading)
        }
    }
}

private struct WhaleAgentWeChatBubbleBackground: View {
    let pointsRight: Bool

    private var fill: Color {
        pointsRight
            ? WhaleIMessagePalette.chatOutgoingBubble
            : WhaleIMessagePalette.chatIncomingBubble
    }

    var body: some View {
        WhaleAgentWeChatBubbleShape(pointsRight: pointsRight)
            .fill(fill)
    }
}

private struct WhaleAgentWeChatBubbleShape: Shape {
    let pointsRight: Bool

    func path(in rect: CGRect) -> Path {
        let tailWidth: CGFloat = 8
        let bodyRect = pointsRight
            ? CGRect(
                x: rect.minX,
                y: rect.minY,
                width: max(0, rect.width - tailWidth),
                height: rect.height
            )
            : CGRect(
                x: rect.minX + tailWidth,
                y: rect.minY,
                width: max(0, rect.width - tailWidth),
                height: rect.height
            )
        var path = Path(
            roundedRect: bodyRect,
            cornerRadius: 16
        )
        let attachTop = bodyRect.minY + 10
        let attachBottom = bodyRect.minY + 22
        let tipY = bodyRect.minY + 16

        if pointsRight {
            path.move(to: CGPoint(x: bodyRect.maxX - 1, y: attachTop))
            path.addLine(to: CGPoint(x: rect.maxX, y: tipY))
            path.addLine(to: CGPoint(x: bodyRect.maxX - 1, y: attachBottom))
        } else {
            path.move(to: CGPoint(x: bodyRect.minX + 1, y: attachTop))
            path.addLine(to: CGPoint(x: rect.minX, y: tipY))
            path.addLine(to: CGPoint(x: bodyRect.minX + 1, y: attachBottom))
        }
        path.closeSubpath()
        return path
    }
}
