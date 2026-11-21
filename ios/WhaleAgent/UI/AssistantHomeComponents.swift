import SwiftUI
import UniformTypeIdentifiers

private struct WhaleHomeSoftShadow: ViewModifier {
    let elevated: Bool

    func body(content: Content) -> some View {
        content
            .shadow(
                color: Color.black.opacity(elevated ? 0.075 : 0.055),
                radius: elevated ? 18 : 14,
                x: 0,
                y: elevated ? 8 : 6
            )
            .shadow(
                color: Color.black.opacity(0.025),
                radius: 4,
                x: 0,
                y: 2
            )
    }
}

private struct WhaleDesktopWiggle: ViewModifier {
    let active: Bool
    let phase: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onChange(of: active, initial: true) { _, isActive in
                updateAnimation(isActive)
            }
            .onChange(of: reduceMotion) { _, _ in
                updateAnimation(active)
            }
    }

    private func updateAnimation(_ isActive: Bool) {
        guard isActive, !reduceMotion else {
            withAnimation(.easeOut(duration: 0.16)) { angle = 0 }
            return
        }
        let direction = phase.isMultiple(of: 2) ? 1.0 : -1.0
        angle = direction * 0.72
        withAnimation(.easeInOut(duration: 0.16).repeatForever(autoreverses: true)) {
            angle = direction * -0.72
        }
    }
}

extension View {
    func whaleHomeFloating(elevated: Bool = false) -> some View {
        modifier(WhaleHomeSoftShadow(elevated: elevated))
    }

    func whaleDesktopWiggle(active: Bool, phase: Int) -> some View {
        modifier(WhaleDesktopWiggle(active: active, phase: phase))
    }
}

struct AssistantShortcutTile: View {
    let channel: DiscoverChannel
    let lines: [String]
    let tickerDelay: Double
    let editing: Bool
    let phase: Int
    let onOpen: () -> Void
    let onHide: () -> Void

    var body: some View {
        Button {
            guard !editing else { return }
            onOpen()
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .center, spacing: 6) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(channel.entryInk.opacity(0.13))
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: channel.icon)
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(channel.entryInk)
                        }

                    Spacer(minLength: 2)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(channel.entryInk.opacity(0.72))
                }

                Text(channel.title)
                    .whaleFont(size: 14, weight: .semibold)
                    .foregroundStyle(channel.entryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                RollingSummaryText(
                    lines: lines,
                    delay: tickerDelay,
                    maxLines: 2,
                    fontSize: 11.5,
                    foreground: channel.entryInk.opacity(0.82)
                )
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .background(
                channel.homeCardBackground,
                in: RoundedRectangle(cornerRadius: 19, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .strokeBorder(channel.entryInk.opacity(0.09), lineWidth: 0.7)
            }
            .contentShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        }
        .buttonStyle(.whalePress)
        .overlay(alignment: .topLeading) {
            if editing {
                Button(action: onHide) {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(WhaleTheme.onAccent)
                        .frame(width: 26, height: 26)
                        .background(WhaleTheme.danger, in: Circle())
                        .overlay {
                            Circle().strokeBorder(WhaleTheme.chrome, lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
                .offset(x: -7, y: -7)
                .accessibilityLabel("隐藏\(channel.title)入口")
                .accessibilityIdentifier("home-channel-hide-\(channel.rawValue)")
            }
        }
        .whaleHomeFloating()
        .whaleDesktopWiggle(active: editing, phase: phase)
        .accessibilityLabel(channel.title)
        .accessibilityHint(editing ? "拖动调整顺序，点左上角减号隐藏" : "轻点打开，长按整理桌面")
        .accessibilityIdentifier("home-channel-" + channel.rawValue)
    }
}

struct AssistantShortcutDropDelegate: DropDelegate {
    let target: DiscoverChannel
    @Binding var dragged: DiscoverChannel?
    @ObservedObject var layout: HomeShortcutLayoutStore

    func dropEntered(info: DropInfo) {
        guard let dragged, dragged != target else { return }
        withAnimation(.snappy(duration: 0.2)) {
            layout.move(dragged, before: target)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragged = nil
        return true
    }
}
