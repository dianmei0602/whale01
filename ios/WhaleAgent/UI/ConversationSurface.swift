import SwiftUI
import UIKit

/// The single conversation surface. Sending, voice and results all stay on the
/// home page; nothing is pushed and no voice sheet is presented.
///
/// The composer lives in the Assistant tab's safe-area inset; the message
/// surface owns its reading position independently of keyboard focus.
struct ConversationSurface: View {
    @ObservedObject var model: AppModel
    let bottomInset: CGFloat
    var onReturnToRecords: (() -> Void)? = nil
    @State private var followState = ConversationFollowState()
    @State private var userScrolling = false
    @State private var todoCandidate: MessageTodoCandidate?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            if !model.backendOnline || model.errorText != nil {
                connectionBanner
            }
            if model.highlightedMessageId != nil, let onReturnToRecords {
                HStack(spacing: 8) {
                    Image(systemName: "scope")
                        .foregroundStyle(WhaleTheme.accent)
                    Text("已定位到原消息")
                        .whaleFont(size: 13, weight: .semibold)
                        .foregroundStyle(WhaleTheme.ink)
                    Spacer()
                    Button("返回记录", action: onReturnToRecords)
                        .whaleFont(size: 13, weight: .semibold)
                        .foregroundStyle(WhaleTheme.accent)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 42)
                .background(WhaleTheme.accentSoft.opacity(0.72))
            }
            conversation
        }
        .background(WhaleIMessagePalette.canvas)
    }

    // MARK: - Conversation

    private var conversation: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if model.messages.isEmpty && model.pending.isEmpty && !model.isBusy { emptyConversation }
                        if let first = model.messages.first {
                            Text(dayLabel(first.createdAt))
                                .whaleFont(size: 11, weight: .medium)
                                .foregroundStyle(WhaleIMessagePalette.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                                .padding(.bottom, 9)
                        }
                        ForEach(Array(model.messages.enumerated()), id: \.element.id) { index, message in
                            MessageRow(
                                message: message,
                                isSpeaking: model.isSpeakingReply && model.speakingMessageId == message.id.uuidString,
                                isHighlighted: model.highlightedMessageId == message.id.uuidString,
                                isLastInGroup: isLastMessageInGroup(at: index),
                                onToggleSpeech: { model.toggleSpeech(for: message) },
                                onCreateTodo: message.role == .assistant
                                    ? { todoCandidate = MessageTodoCandidate(text: $0, messageID: message.id.uuidString) }
                                    : nil
                            )
                            .id(message.id)
                            .padding(.top, messageTopSpacing(at: index))
                        }
                        ForEach(model.pending) { item in
                            PendingActionCard(item: item, isBusy: model.isBusy) {
                                model.presentedConfirmation = item
                            }
                            .frame(maxWidth: 334, alignment: .leading)
                            .padding(.top, 12)
                            .id(item.id)
                        }
                        if !model.streamingReply.isEmpty {
                            StreamingReplyView(text: model.streamingReply)
                                .padding(.top, 10)
                                .id("streaming-reply")
                        }
                        AssistantActivityView(model: model)
                            .frame(maxWidth: 334, alignment: .leading)
                            .padding(.top, 10)
                        InteractionReceiptCard(model: model)
                            .frame(maxWidth: 334, alignment: .leading)
                            .padding(.top, 10)
                        Color.clear.frame(height: 20 + bottomInset).id(Self.bottomAnchor)
                            .background(GeometryReader { geometry in
                                Color.clear.preference(key: ConversationBottomKey.self, value: geometry.frame(in: .named("conversation-viewport")).maxY)
                            })
                    }.padding(.horizontal, 16).padding(.top, 10)
                }
                .coordinateSpace(name: "conversation-viewport")
                .scrollDismissesKeyboard(.interactively).scrollBounceBehavior(.basedOnSize).defaultScrollAnchor(.bottom)
                .background(ScrollOffsetMemory(key: "chat-" + model.composerContextID, onRestored: { near in followState.updatePosition(nearBottom: near) }, startAtBottom: true))
                .simultaneousGesture(DragGesture(minimumDistance: 2)
                    .onChanged { _ in userScrolling = true }
                    .onEnded { _ in Task { try? await Task.sleep(nanoseconds: 700_000_000); userScrolling = false } })
                .onPreferenceChange(ConversationBottomKey.self) { bottom in
                    let near = bottom <= viewport.size.height + 70
                    if near || userScrolling { followState.updatePosition(nearBottom: near) }
                }
                .onChange(of: model.messages.count) { old, new in
                    guard new > old else { return }
                    if followState.receive(new - old) { pinToBottom(proxy) }
                }
                .onChange(of: model.pending.count) { _, _ in
                    if followState.receive() { pinToBottom(proxy) }
                }
                .onChange(of: model.streamingReply) { _, _ in
                    if followState.nearBottom { pinToBottom(proxy, animated: false) }
                }
                .onChange(of: viewport.size.height) { _, _ in
                    if followState.nearBottom { pinToBottom(proxy, animated: false) }
                }
                .onChange(of: model.requestedMessageId) { _, messageId in
                    guard let messageId, let id = UUID(uuidString: messageId) else { return }
                    focus(messageId: id, proxy: proxy)
                }
                .task(id: model.requestedMessageId) {
                    guard let messageId = model.requestedMessageId,
                          let id = UUID(uuidString: messageId) else { return }
                    focus(messageId: id, proxy: proxy, delayed: true)
                }
                .overlay(alignment: .bottomTrailing) {
                    if followState.unread > 0 {
                        Button {
                            followState.follow(); pinToBottom(proxy)
                        } label: {
                            Label("\(followState.unread) 条新内容", systemImage: "arrow.down")
                                .font(.subheadline.weight(.medium)).padding(.horizontal, 14).frame(minHeight: 44)
                                .background(WhaleTheme.card, in: Capsule()).overlay(Capsule().stroke(WhaleTheme.line))
                        }.foregroundStyle(WhaleTheme.accent).padding(16)
                    }
                }
            }
        }
        .sheet(item: $todoCandidate) { candidate in
            TodoFromMessageSheet(candidate: candidate, model: model)
        }
    }

    private var emptyConversation: some View {
        VStack(spacing: 12) {
            WhaleMarkView(size: 62)
            Text("开始和鲸鱼说话")
                .whaleFont(size: 19, weight: .bold, design: .rounded)
                .foregroundStyle(WhaleTheme.ink)
            Text("直接输入，或点下方麦克风说一句。\n消息、执行结果和待确认操作都会留在这个页面。")
                .whaleFont(size: 13)
                .foregroundStyle(WhaleTheme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 72)
        .padding(.bottom, 24)
    }

    private static let bottomAnchor = "conversationBottom"

    private func messageTopSpacing(at index: Int) -> CGFloat {
        guard model.messages.indices.contains(index) else { return 2 }
        let previous = index > 0 ? model.messages[index - 1] : nil
        return WhaleIMessageLayout.verticalSpacing(
            previous: previous,
            current: model.messages[index]
        )
    }

    private func isLastMessageInGroup(at index: Int) -> Bool {
        guard model.messages.indices.contains(index),
              model.messages.indices.contains(index + 1) else { return true }
        return !WhaleIMessageLayout.isSameGroup(
            previous: model.messages[index],
            current: model.messages[index + 1]
        )
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }

    /// Keeps the newest message pinned. Only content changes move the list;
    /// typing never does, so the scroll position stays put while composing.
    private func pinToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        let scroll = { proxy.scrollTo(Self.bottomAnchor, anchor: .bottom) }
        if animated && !reduceMotion {
            withAnimation(.easeOut(duration: 0.22), scroll)
        } else {
            scroll()
        }
    }

    private func focus(messageId: UUID, proxy: ScrollViewProxy, delayed: Bool = false) {
        let scroll = {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
                proxy.scrollTo(messageId, anchor: .center)
            }
        }
        if delayed {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 180_000_000)
                scroll()
                try? await Task.sleep(nanoseconds: 160_000_000)
                proxy.scrollTo(messageId, anchor: .center)
                model.consumeMessageFocus()
            }
        } else {
            scroll()
        }
    }

    private var connectionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(WhaleTheme.warm)
            Text(model.errorText ?? "服务连接中断，请检查网络后重试。")
                .whaleFont(size: 13)
                .foregroundStyle(WhaleTheme.muted)
                .lineLimit(2)
            Spacer()
            Button("重试") {
                Task {
                    await model.retryCurrentRequest()
                    model.refreshPermissions()
                }
            }
            .whaleFont(size: 13, weight: .semibold)
            .tint(WhaleTheme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(WhaleTheme.warm.opacity(0.10))
    }

    private func send(_ text: String) {
        dismissKeyboard()
        Task { await model.send(text: text) }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

private struct StreamingReplyView: View {
    let text: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .whaleFont(size: 17)
                    .lineSpacing(2)
                    .foregroundStyle(WhaleIMessagePalette.text)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                ProgressView()
                    .controlSize(.mini)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                WhaleIMessagePalette.incoming,
                in: WhaleIMessagePalette.incomingShape()
            )
            .frame(maxWidth: 330, alignment: .leading)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("鲸鱼正在回答，\(text)")
    }
}

struct MessageTodoCandidate: Identifiable {
    let text: String
    let messageID: String
    var id: String { messageID }
}

private struct ConversationBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
