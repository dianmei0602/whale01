import SwiftUI

/// Root conversation page. ExyteChat owns the mature message list, long-content
/// menus, media/document input and pagination; Whale supplies the Life Agent
/// shell, theme and application state.
struct ConversationTabView: View {
    @ObservedObject var model: AppModel
    @Binding var entryMode: ConversationEntryMode
    let bottomInset: CGFloat
    let onOpenRecords: () -> Void
    let onOpenSettings: () -> Void
    let onOpenMusic: () -> Void
    let onOpenTodo: () -> Void
    let onOpenDiscover: (DiscoverChannel) -> Void
    let onOpenWorkspace: () -> Void
    @State private var chatDraft = ""
    @StateObject private var voice = VoiceInputController()
    @State private var showsVoice = false

    var body: some View {
        ZStack {
            homePage
                .opacity(entryMode == .home ? 1 : 0)
                .allowsHitTesting(entryMode == .home)
                .accessibilityHidden(entryMode != .home)

            chatPage
                .opacity(entryMode == .chat ? 1 : 0)
                .allowsHitTesting(entryMode == .chat)
                .accessibilityHidden(entryMode != .chat)
        }
        .background(WhaleIMessagePalette.canvas)
        .tint(WhaleIMessagePalette.outgoing)
        .fullScreenCover(isPresented: $showsVoice) {
            VoiceView(
                voice: voice,
                onInsert: insertVoiceDraft,
                onCancel: { showsVoice = false }
            )
            .presentationBackground(.clear)
        }
    }

    private var homePage: some View {
        WhaleHomeCanvas(
            model: model,
            bottomInset: bottomInset,
            onOpenRecords: onOpenRecords,
            onOpenMusic: onOpenMusic,
            onOpenTodo: onOpenTodo,
            onOpenDiscover: onOpenDiscover,
            onOpenConversation: { entryMode = .chat },
            onOpenWorkspace: onOpenWorkspace
        )
    }

    private var chatPage: some View {
        VStack(spacing: 0) {
            header
            WhaleAgentChatSurface(
                inputText: $chatDraft,
                model: model,
                bottomInset: bottomInset,
                onOpenRecords: onOpenRecords,
                onOpenMusic: onOpenMusic,
                onOpenWorkspace: onOpenWorkspace
            )
        }
    }

    private var header: some View {
        ZStack {
            HStack(spacing: 2) {
                headerStatus
                Spacer()
                Button {
                    showsVoice = true
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(WhaleIMessagePalette.outgoing)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(model.isBusy || model.isExtractingDocument)
                .opacity(model.isBusy || model.isExtractingDocument ? 0.45 : 1)
                .accessibilityLabel("语音输入")
                .accessibilityHint("打开鲸鱼语音听写，识别后填入草稿")
                .accessibilityIdentifier("whale-chat-voice")

                Menu {
                    Button("鲸鱼工作台", systemImage: "square.stack.3d.up", action: onOpenWorkspace)
                    Button("新对话", systemImage: "square.and.pencil") { model.newConversation() }
                        .disabled(model.isBusy || !model.pending.isEmpty)
                    Button("执行记录", systemImage: "clock.arrow.circlepath", action: onOpenRecords)
                    Divider()
                    Button("设置", systemImage: "gearshape", action: onOpenSettings)
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 21, weight: .medium))
                        .whaleTouchTarget()
                }
                .accessibilityLabel("更多操作")
                .accessibilityIdentifier("assistant-settings")
            }

            HStack(spacing: 8) {
                WhaleMarkView(size: 28)
                Text("鲸鱼")
                    .whaleFont(size: 16, weight: .semibold)
                    .foregroundStyle(WhaleIMessagePalette.text)
            }
            .fixedSize()
            .allowsHitTesting(false)
        }
        .foregroundStyle(WhaleIMessagePalette.outgoing)
        .padding(.horizontal, 15)
        .frame(minHeight: 50)
        .background(WhaleIMessagePalette.header)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WhaleIMessagePalette.line)
                .frame(height: 0.5)
        }
    }

    private var statusText: String {
        headerState.statusText
    }

    private var statusColor: Color {
        if model.isBusy || model.isExecutingTool { return WhaleIMessagePalette.outgoing }
        if !model.backendOnline { return .orange }
        return .green
    }

    private var headerState: WhaleChatHeaderState {
        WhaleChatHeaderPresenter.content(
            isExecutingTool: model.isExecutingTool,
            isBusy: model.isBusy,
            backendOnline: model.backendOnline,
            isPlayingMusic: model.playback.track != nil && model.playback.isPlaying
        )
    }

    private var headerStatus: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(statusText)
                .whaleFont(size: 11, weight: .medium)
                .foregroundStyle(WhaleIMessagePalette.muted)
                .lineLimit(1)

            if headerState.showsMusicIcon,
               let track = model.playback.track {
                MiniVinylView(
                    track: track,
                    isPlaying: true,
                    diameter: 20
                )
                .accessibilityLabel("正在播放 \(track.title)")
                .accessibilityIdentifier("chat-now-playing")
            }
        }
        .frame(maxWidth: 150, alignment: .leading)
        .allowsHitTesting(false)
    }

    private func insertVoiceDraft(_ transcript: String) {
        chatDraft = WhaleAgentDraftPlan.mergingVoice(
            transcript: transcript,
            currentDraft: chatDraft
        )
        voice.reset()
        showsVoice = false
    }
}

/// Small spinning vinyl record shown in the header while music is active.
/// It keeps playback controls out of the bottom safe area.
private struct MiniVinylView: View {
    let track: MusicTrackItem
    let isPlaying: Bool
    var diameter: CGFloat = 38

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var anchor = Date()
    @State private var baseAngle: Double = 0

    private let degreesPerSecond: Double = 36

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying || reduceMotion)) { context in
            vinyl(angle: currentAngle(at: context.date))
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .onChange(of: isPlaying) { _, playing in
            if playing {
                anchor = Date()
            } else {
                baseAngle = liveAngle(at: Date()).truncatingRemainder(dividingBy: 360)
            }
        }
        .accessibilityElement(children: .ignore)
    }

    private func currentAngle(at date: Date) -> Double {
        guard isPlaying, !reduceMotion else { return baseAngle }
        return liveAngle(at: date).truncatingRemainder(dividingBy: 360)
    }

    private func liveAngle(at date: Date) -> Double {
        baseAngle + max(0, date.timeIntervalSince(anchor)) * degreesPerSecond
    }

    private func vinyl(angle: Double) -> some View {
        ZStack {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.33), Color(white: 0.18), Color(white: 0.09)],
                            center: UnitPoint(x: 0.40, y: 0.36),
                            startRadius: 1,
                            endRadius: diameter * 0.60
                        )
                    )

                ForEach([0.92, 0.83, 0.74, 0.65, 0.56], id: \.self) { scale in
                    Circle()
                        .strokeBorder(Color.white.opacity(0.11), lineWidth: 0.55)
                        .frame(width: diameter * scale, height: diameter * scale)
                    Circle()
                        .strokeBorder(Color.black.opacity(0.30), lineWidth: 0.45)
                        .frame(width: diameter * scale - 0.9, height: diameter * scale - 0.9)
                }

                Circle()
                    .trim(from: 0.02, to: 0.10)
                    .stroke(Color.white.opacity(0.30), lineWidth: 1.2)
                    .padding(2.2)
                    .rotationEffect(.degrees(-54))

                label
                    .frame(width: diameter * 0.44, height: diameter * 0.44)
                    .clipShape(Circle())
                    .overlay {
                        Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.6)
                    }
                    .shadow(color: .black.opacity(0.38), radius: 1.5, y: 0.5)

                Circle()
                    .fill(Color.black.opacity(0.82))
                    .frame(
                        width: max(1.8, diameter * 0.068),
                        height: max(1.8, diameter * 0.068)
                    )
            }
            .rotationEffect(.degrees(angle))

            Circle()
                .fill(
                    AngularGradient(
                        stops: [
                            .init(color: .white.opacity(0.28), location: 0.00),
                            .init(color: .white.opacity(0.03), location: 0.14),
                            .init(color: .clear, location: 0.33),
                            .init(color: .white.opacity(0.09), location: 0.50),
                            .init(color: .clear, location: 0.69),
                            .init(color: .white.opacity(0.15), location: 0.86),
                            .init(color: .white.opacity(0.28), location: 1.00)
                        ],
                        center: .center
                    )
                )
                .blendMode(.screen)
                .allowsHitTesting(false)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.20), .clear],
                        center: UnitPoint(x: 0.30, y: 0.24),
                        startRadius: 0,
                        endRadius: diameter * 0.52
                    )
                )
                .blendMode(.screen)
                .allowsHitTesting(false)

            Circle()
                .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.8)
                .allowsHitTesting(false)
        }
        .shadow(color: Color.black.opacity(0.24), radius: 6, y: 3)
    }

    @ViewBuilder
    private var label: some View {
        if let image = track.artwork {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [WhaleTheme.accent, WhaleTheme.accentDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                Image(systemName: "music.note")
                    .whaleFont(size: max(7, diameter * 0.34), weight: .bold)
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
    }
}
