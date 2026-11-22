import ExyteChat
import SwiftUI
import UIKit

/// The selected "Life Agent" conversation. ExyteChat owns bubble grouping,
/// pagination, long-message menus and the media/document input workflow.
struct WhaleAgentChatSurface: View {
    @Binding var inputText: String
    @ObservedObject var model: AppModel
    let bottomInset: CGFloat
    let onOpenRecords: () -> Void
    let onOpenMusic: () -> Void
    let onOpenWorkspace: () -> Void

    @State private var draftError: String?
    @State private var draftContext: String?
    private let drafts = ComposerDraftStore()

    private static let currentUser = ExyteChat.User(
        id: "whale-current-user",
        name: "你",
        avatarURL: nil,
        isCurrentUser: true
    )
    private static let whaleUser = ExyteChat.User(
        id: "whale-agent",
        name: "鲸鱼",
        avatarURL: nil,
        type: .other
    )
    private static let systemUser = ExyteChat.User(
        id: "whale-system",
        name: "鲸鱼",
        avatarURL: nil,
        type: .system
    )

    var body: some View {
        chatView
            .chatTheme(theme)
            .setAvailableInputs([.text, .media, .document])
            .assetsPickerLimit(assetsPickerLimit: 4)
            .showAvatar(false)
            .showUsername(false)
            .showTimeView(true)
            .setMessageFont(UIFont.systemFont(ofSize: 16, weight: .regular))
            .messageLinkPreviewLimit(2)
            .showScrollToBottomButton(true)
            .showDateHeaders(true)
            .showMessageMenuOnLongPress(true)
            .keyboardDismissMode(.interactive)
            .messageMenuAnimationDuration(0.22)
            .contentInsets(top: 8, bottom: max(8, bottomInset + 8))
            .inputViewText($inputText)
            .localization(Self.localization)
            .mainHeaderBuilder {
                AnyView(
                    Group {
                        if model.messages.isEmpty, model.pending.isEmpty, !model.isBusy {
                            WhaleAgentWelcomeHeader(
                                model: model,
                                onUsePrompt: { inputText = $0 },
                                onOpenRecords: onOpenRecords,
                                onOpenMusic: onOpenMusic,
                                onOpenWorkspace: onOpenWorkspace
                            )
                        } else {
                            EmptyView()
                        }
                    }
                )
            }
            .betweenListAndInputViewBuilder {
                AnyView(chatNotice)
            }
            .task {
                if draftContext == nil {
                    draftContext = model.composerContextID
                    inputText = drafts.load(context: model.composerContextID)
                }
            }
            .onChange(of: inputText) { _, text in
                guard let draftContext else { return }
                drafts.save(text, context: draftContext)
            }
            .onChange(of: model.composerContextID) { _, context in
                if let old = draftContext {
                    drafts.save(inputText, context: old)
                }
                draftContext = context
                inputText = drafts.load(context: context)
            }
            .onReceive(NotificationCenter.default.publisher(for: .whalePrefillDraft)) { notification in
                guard let text = notification.userInfo?["text"] as? String else { return }
                inputText = inputText.isEmpty ? text : inputText + "\n" + text
            }
        .background(WhaleIMessagePalette.canvas)
        .accessibilityIdentifier("whale-agent-chat-surface")
    }

    private var chatView: some View {
        ChatView(
            messages: exyteMessages,
            didSendMessage: handleDraft,
            messageBuilder: { params in
                AnyView(
                    WhaleAgentMessageContent(
                        params: params,
                        model: model,
                        onOpenRecords: onOpenRecords
                    )
                )
            },
            messageMenuAction: { (action: WhaleAgentMessageMenuAction, defaultAction, message) in
                switch action {
                case .copy:
                    defaultAction(message, .copy)
                case .speak:
                    speak(message)
                case .save:
                    save(message)
                }
            }
        )
    }

    private var exyteMessages: [ExyteChat.Message] {
        var values = model.messages.map { message -> ExyteChat.Message in
            let user: ExyteChat.User
            let kind: String
            switch message.role {
            case .user:
                user = Self.currentUser
                kind = "message"
            case .assistant:
                user = Self.whaleUser
                kind = "message"
            case .tool:
                user = Self.systemUser
                kind = "tool"
            }
            return ExyteChat.Message(
                id: message.id.uuidString,
                user: user,
                createdAt: message.createdAt,
                text: message.text,
                customData: [
                    "whaleKind": kind,
                    "whaleMessageID": message.id.uuidString
                ]
            )
        }

        values.append(contentsOf: model.pending.map { item in
            ExyteChat.Message(
                id: "pending-\(item.toolCallId)",
                user: Self.systemUser,
                createdAt: Date(),
                text: item.tool,
                customData: [
                    "whaleKind": "pending",
                    "pendingID": item.toolCallId
                ]
            )
        })

        if !model.streamingReply.isEmpty {
            values.append(
                ExyteChat.Message(
                    id: "whale-streaming-reply",
                    user: Self.whaleUser,
                    createdAt: Date(),
                    text: model.streamingReply,
                    customData: ["whaleKind": "streaming"]
                )
            )
        } else if model.isBusy {
            values.append(
                ExyteChat.Message(
                    id: "whale-activity",
                    user: Self.systemUser,
                    createdAt: Date(),
                    text: model.activityDescription,
                    customData: ["whaleKind": "activity"]
                )
            )
        }

        if let receipt = model.operationReceipts.first,
           Date().timeIntervalSince(receipt.createdAt) < 15 * 60 {
            values.append(
                ExyteChat.Message(
                    id: "receipt-\(receipt.id)",
                    user: Self.systemUser,
                    createdAt: receipt.createdAt,
                    text: receipt.title,
                    customData: ["whaleKind": "receipt"]
                )
            )
        }
        return values
    }

    private var theme: ChatTheme {
        ChatTheme(
            colors: .init(
                mainBG: WhaleIMessagePalette.canvas,
                mainTint: WhaleIMessagePalette.outgoing,
                mainText: WhaleIMessagePalette.text,
                mainCaptionText: WhaleIMessagePalette.muted,
                messageMyBG: WhaleIMessagePalette.chatOutgoingBubble,
                messageMyText: WhaleIMessagePalette.outgoingText,
                messageMyTimeText: WhaleIMessagePalette.outgoingText.opacity(0.72),
                messageFriendBG: WhaleIMessagePalette.chatIncomingBubble,
                messageFriendText: WhaleIMessagePalette.text,
                messageFriendTimeText: WhaleIMessagePalette.muted,
                messageSystemBG: WhaleIMessagePalette.incoming,
                messageSystemText: WhaleIMessagePalette.text,
                messageSystemTimeText: WhaleIMessagePalette.muted,
                inputBG: WhaleIMessagePalette.field,
                inputText: WhaleIMessagePalette.text,
                inputPlaceholderText: WhaleIMessagePalette.muted,
                menuBG: WhaleIMessagePalette.header,
                menuText: WhaleIMessagePalette.text,
                menuTextDelete: .red,
                sendButtonBackground: WhaleIMessagePalette.outgoing,
                recordDot: .red
            )
        )
    }

    @ViewBuilder
    private var chatNotice: some View {
        if let draftError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                Text(draftError)
                    .whaleFont(size: 12)
                Spacer()
                Button("关闭") { self.draftError = nil }
                    .whaleFont(size: 12, weight: .semibold)
            }
            .foregroundStyle(WhaleIMessagePalette.muted)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(WhaleIMessagePalette.field)
        } else if !model.backendOnline || model.errorText != nil {
            HStack(spacing: 8) {
                Image(systemName: "wifi.exclamationmark")
                Text(model.errorText ?? "服务连接中断，联网后可继续。")
                    .whaleFont(size: 12)
                    .lineLimit(2)
                Spacer()
                Button("重试") {
                    Task { await model.retryCurrentRequest() }
                }
                .whaleFont(size: 12, weight: .semibold)
            }
            .foregroundStyle(WhaleIMessagePalette.muted)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(WhaleIMessagePalette.field)
        }
    }

    private func handleDraft(_ draft: ExyteChat.DraftMessage) {
        draftError = nil
        Task { @MainActor in
            let document = draft.documents.first
            var imageURL: URL?
            var videoCount = 0
            if !draft.medias.isEmpty {
                let message = await ExyteChat.Message.makeMessage(
                    id: "draft-\(UUID().uuidString)",
                    user: Self.currentUser,
                    draft: draft
                )
                imageURL = message.attachments.first(where: { $0.type == .image })?.full
                videoCount = message.attachments.filter { $0.type == .video }.count
            }

            let plan = WhaleAgentDraftPlan(
                text: draft.text,
                documentURL: document?.url,
                documentLabel: document.map {
                    $0.fileName.lowercased().hasSuffix(".pdf") ? "PDF" : "文件"
                },
                imageURL: imageURL,
                unsupportedVideoCount: videoCount
            )
            guard !plan.isEmpty else { return }

            if let documentURL = plan.documentURL {
                await model.ingestDocument(
                    url: documentURL,
                    label: plan.documentLabel ?? "文件"
                )
            } else if let imageURL = plan.imageURL {
                await model.ingestDocument(url: imageURL, label: "照片")
            } else if !plan.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let text = plan.text
                await model.send(text: text, onAccepted: {
                    guard inputText == text else { return }
                    inputText = ""
                    if let draftContext {
                        drafts.save("", context: draftContext)
                    }
                })
            } else if plan.unsupportedVideoCount > 0 {
                draftError = "当前只能识别图片和 PDF，视频内容还没有接入。"
            }
        }
    }

    private func speak(_ message: ExyteChat.Message) {
        if let original = model.messages.first(where: { $0.id.uuidString == message.id }) {
            model.toggleSpeech(for: original)
        } else {
            model.toggleContentSpeech(text: message.text, contentId: message.id)
        }
    }

    private func save(_ message: ExyteChat.Message) {
        guard !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        _ = WhaleWorkspaceStore.shared.capture(
            title: String(message.text.prefix(60)),
            body: message.text,
            kind: .chat,
            sourceURL: "whaleagent://message/\(message.id)",
            isKnowledge: true
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private static let localization = ChatLocalization(
        inputPlaceholder: "给鲸鱼发消息",
        signatureText: "添加说明",
        cancelButtonText: "取消",
        recentToggleText: "最近",
        waitingForNetwork: "等待网络",
        recordingText: "正在录音…",
        replyToText: "回复",
        attachMediaText: "照片或视频",
        attachCameraText: "相机",
        attachDocumentText: "文件",
        attachLocationText: "位置"
    )
}

private enum WhaleAgentMessageMenuAction: String, MessageMenuAction, CaseIterable {
    case copy
    case speak
    case save

    func title() -> String {
        switch self {
        case .copy: return "复制"
        case .speak: return "朗读"
        case .save: return "保存到知识库"
        }
    }

    func icon() -> Image {
        switch self {
        case .copy: return Image(systemName: "doc.on.doc")
        case .speak: return Image(systemName: "speaker.wave.2")
        case .save: return Image(systemName: "books.vertical")
        }
    }

    static func menuItems(for message: ExyteChat.Message) -> [WhaleAgentMessageMenuAction] {
        [.copy, .speak, .save]
    }
}

private struct WhaleAgentMessageContent: View {
    let params: MessageBuilderParameters
    @ObservedObject var model: AppModel
    let onOpenRecords: () -> Void

    var body: some View {
        let kind = params.message.customData["whaleKind"] as? String
        switch kind {
        case "tool":
            if let message = originalMessage {
                WhaleAgentWeChatCardRow(layout: .resolve(isCurrentUser: false)) {
                    MessageRow(
                        message: message,
                        isSpeaking: model.isSpeakingReply && model.speakingMessageId == message.id.uuidString,
                        isHighlighted: model.highlightedMessageId == message.id.uuidString,
                        onToggleSpeech: { model.toggleSpeech(for: message) }
                    )
                }
            } else {
                defaultContent(layout: .resolve(isCurrentUser: false))
            }
        case "pending":
            if let pendingID = params.message.customData["pendingID"] as? String,
               let item = model.pending.first(where: { $0.toolCallId == pendingID }) {
                WhaleAgentWeChatCardRow(layout: .resolve(isCurrentUser: false)) {
                    PendingActionCard(item: item, isBusy: model.isBusy) {
                        model.presentedConfirmation = item
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                defaultContent(layout: .resolve(isCurrentUser: false))
            }
        case "streaming":
            WhaleAgentWeChatTextRow(
                text: params.message.text,
                layout: .resolve(isCurrentUser: false),
                isStreaming: true
            )
        case "activity":
            WhaleAgentWeChatCardRow(layout: .resolve(isCurrentUser: false)) {
                AssistantActivityView(model: model)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case "receipt":
            WhaleAgentWeChatCardRow(layout: .resolve(isCurrentUser: false)) {
                InteractionReceiptCard(model: model)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            let layout = WhaleChatMessageLayout.resolve(
                isCurrentUser: params.message.user.isCurrentUser
            )
            if params.message.attachments.isEmpty {
                WhaleAgentWeChatTextRow(
                    text: params.message.text,
                    layout: layout
                )
            } else {
                defaultContent(layout: layout)
            }
        }
    }

    private func defaultContent(layout: WhaleChatMessageLayout) -> some View {
        WhaleAgentWeChatMessageFrame(layout: layout) {
            params.defaultMessageView()
                .frame(
                    maxWidth: 292,
                    alignment: layout.bubblePointsRight ? .trailing : .leading
                )
        }
    }

    private var originalMessage: ChatMessage? {
        guard let id = params.message.customData["whaleMessageID"] as? String,
              let uuid = UUID(uuidString: id) else { return nil }
        return model.messages.first { $0.id == uuid }
    }
}

private struct WhaleAgentWelcomeHeader: View {
    @ObservedObject var model: AppModel
    let onUsePrompt: (String) -> Void
    let onOpenRecords: () -> Void
    let onOpenMusic: () -> Void
    let onOpenWorkspace: () -> Void

    private var items: [WhaleIMessageStarterItem] {
        WhaleIMessageStarterBuilder.items(
            events: model.upcomingEvents,
            quote: DailyQuote.item(at: Date()),
            playback: model.playback,
            pendingCount: model.pending.count
        ).filter { $0.kind != .greeting }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WhaleIMessageStarterBuilder.greeting(at: Date()))
                .whaleFont(size: 24, weight: .bold)
                .foregroundStyle(WhaleIMessagePalette.text)
            Text("今天想处理什么，直接告诉我就好。")
                .whaleFont(size: 14)
                .foregroundStyle(WhaleIMessagePalette.muted)

            ForEach(items) { item in
                HStack(alignment: .top, spacing: 9) {
                    WhaleMarkView(size: 27)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(item.text)
                            .whaleFont(size: 16)
                            .foregroundStyle(WhaleIMessagePalette.text)
                        if let detail = item.detail, !detail.isEmpty {
                            Text(detail)
                                .whaleFont(size: 13)
                                .foregroundStyle(WhaleIMessagePalette.muted)
                        }
                        if let actionTitle = item.actionTitle, let action = item.action {
                            Button(actionTitle) { perform(action) }
                                .whaleFont(size: 13, weight: .semibold)
                                .foregroundStyle(WhaleIMessagePalette.outgoing)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(WhaleIMessagePalette.incoming, in: WhaleIMessagePalette.incomingShape())
                    Spacer(minLength: 0)
                }
            }

            Text("你可以这样说")
                .whaleFont(size: 12, weight: .semibold)
                .foregroundStyle(WhaleIMessagePalette.muted)
                .padding(.top, 3)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(WhaleIMessageStarterBuilder.suggestions, id: \.self) { prompt in
                    Button(prompt) {
                        onUsePrompt(prompt)
                    }
                    .whaleFont(size: 13)
                    .foregroundStyle(WhaleIMessagePalette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 11)
                    .frame(minHeight: 38)
                    .background(WhaleIMessagePalette.incoming, in: Capsule())
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("agent-prompt-\(prompt)")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityIdentifier("agent-welcome-header")
    }

    private func perform(_ action: WhaleIMessageStarterAction) {
        switch action {
        case .calendar:
            onUsePrompt("看看我今天的安排")
        case .records:
            onOpenRecords()
        case .music:
            onOpenMusic()
        case .workspace:
            onOpenWorkspace()
        case .prompt(let prompt):
            onUsePrompt(prompt)
        }
    }
}
