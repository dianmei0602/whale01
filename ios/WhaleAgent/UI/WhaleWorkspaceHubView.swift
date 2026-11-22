import SwiftUI
import UIKit

struct WhaleWorkspaceHubView: View {
    @ObservedObject var model: AppModel
    @Binding var mode: WhaleWorkspaceHubMode
    let onOpenMusic: () -> Void
    let onOpenChat: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                TodoView(
                    model: model,
                    embedded: true,
                    onBackToChat: nil,
                    bottomBarInset: 0,
                    showsHeader: false
                )
                .opacity(mode == .tasks ? 1 : 0)
                .allowsHitTesting(mode == .tasks)
                .accessibilityHidden(mode != .tasks)

                WhaleWorkspaceView(
                    model: model,
                    embedded: true,
                    onOpenMusic: onOpenMusic,
                    onOpenChat: onOpenChat
                )
                .opacity(mode == .workspace ? 1 : 0)
                .allowsHitTesting(mode == .workspace)
                .accessibilityHidden(mode != .workspace)
            }
        }
        .background(WhaleIMessagePalette.canvas)
        .accessibilityIdentifier("workspace-hub")
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("工作台")
                .whaleFont(size: 20, weight: .bold, design: .rounded)
                .foregroundStyle(WhaleIMessagePalette.text)

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                ForEach(WhaleWorkspaceHubMode.allCases) { item in
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            mode = item
                        }
                    } label: {
                        Label(item.title, systemImage: item.icon)
                            .whaleFont(size: 12, weight: .semibold)
                            .foregroundStyle(
                                mode == item
                                    ? WhaleIMessagePalette.outgoingText
                                    : WhaleIMessagePalette.text
                            )
                            .padding(.horizontal, 11)
                            .frame(minHeight: 34)
                            .background(
                                mode == item
                                    ? WhaleIMessagePalette.outgoing
                                    : WhaleIMessagePalette.field,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("workspace-hub-mode-" + item.rawValue)
                    .accessibilityAddTraits(mode == item ? .isSelected : [])
                }
            }
        }
        .padding(.horizontal, 15)
        .frame(minHeight: 56)
        .background(WhaleIMessagePalette.header)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WhaleIMessagePalette.line)
                .frame(height: 0.5)
        }
    }
}
