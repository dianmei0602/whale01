import SwiftUI
import Foundation
import UIKit

/// Nomi 页：点它说话。没有输入框——摸它、敲它、它会自己动。
struct AssistantView: View {
    @Binding var showingChat: Bool
    @Binding var voiceVisible: Bool
    var isVisible: Bool = true
    /// 页眉右上角设置入口。
    var onOpenSettings: () -> Void = { }
    /// 首页资讯入口直接切到 RootView 的“值得知道”主入口
    var onOpenIntelligence: (IntelligenceModule) -> Void = { _ in }
    /// 深链带过来的预填话术：只填进输入框，不自动发送
    var initialDraft: String = ""

    @Environment(AppState.self) private var state
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject private var musicPlayer = MusicPlayer.shared

    // MARK: - 消息模型

    struct ChatItem: Identifiable {
        let id = UUID()
        let mine: Bool
        let date: Date
        var text: String?
        var schedule: SchedulePayload?
        var weather: Weather? = nil
        var location: LocationFix? = nil
        var intelligence: IntelligenceDigest? = nil
        var intelligenceModule: IntelligenceModule = .news
        /// 这条气泡下面要不要显示「确认 / 算了」
        var showConfirm: Bool = false
    }

    struct SchedulePayload {
        var today: [MeetingItem]
        var tomorrow: [MeetingItem]
    }

    enum Phase: Equatable {
        case idle, listening, thinking
    }

    @State private var items: [ChatItem] = []

    /// 输入栏草稿
    @State private var draft = ""
    @FocusState private var composerFocused: Bool
    @State private var phase: Phase = .idle
    @State private var speech = SpeechRecognizer()
    @State private var thinkingTask: Task<Void, Never>?
    @State private var showWeatherDetail = false
    @State private var homeDigest = IntelligenceDigest.empty()
    /// 主卡栈当前页：0 下一件事 / 1 天气 / 2 步数
    @State private var glanceIndex = 0
    /// 对话页默认隐藏完整 Nomi，需要时可从顶栏临时唤回
    @State private var showFloatingPet = false
    /// 小人被拖到哪了。nil = 默认位置（底部中央）
    @State private var petPosition: CGPoint?
    @State private var dragStart: CGPoint?
    @State private var dragFeedbackTick = 0
    @State private var petTapFeedbackTick = 0
    @State private var petAnimationTrigger = 0
    @State private var homePetOffset: CGSize = .zero
    @State private var homePetDragStart: CGSize?

    // 生活系统
    @State private var life = PetLife()
    @State private var voice = PetVoice.shared
    @State private var expression: PetExpression = .calm

    /// 正在念答案：这时表情跟着句子走，不做别的动作
    @State private var isSpeaking = false
    /// 看见你的时候蹦一下
    @State private var hopUntil = Date.distantPast
    @State private var greetedAt = Date.distantPast
    @State private var speakHeadTilt: Double = 0
    @State private var speakBaseTilt: Double = 0
    /// 刚问过「几点」：下一句直接当时间补上
    @State private var pendingCreate = false
    /// 正在重播哪一条：点气泡后闪一下
    @State private var replayingID: UUID?
    /// 等着用户点确认的动作
    @State private var pendingAction: PendingMeetingAction?
    /// 等确认的待办动作（新建 / 完成），确认了才写系统
    @State private var pendingTodo: PendingTodoAction?
    /// 全部待办页
    @State private var showTodos = false
    /// 听音乐面板
    @State private var showMusic = false
    @State private var showMusicPlayer = false
    /// 面板里的预填搜索词
    @State private var musicTerm = ""
    @State private var encouragement = DailyEncouragement.today()
    @State private var classicalQuotes = DailyEncouragement.phrases.isEmpty
        ? [DailyEncouragement.fallback]
        : DailyEncouragement.phrases
    @State private var showClassicalLibrary = false
    @State private var pendingItemID: UUID?
    @State private var showConfirmSheet = false

    /// 锁屏重力：陀螺仪 + 物理体 + 后台推帧
    @State private var speakTask: Task<Void, Never>?
    @State private var caption = ""
    @State private var expressionUntil = Date.distantPast
    @State private var nextEventAt = Date().addingTimeInterval(14 * PetLife.pace)
    @State private var walkTick = 0
    // 锁屏是它的家：目标位置和自己的位置，0…1
    @State private var roamTarget: Double = 0.5
    @State private var roamPos: Double = 0.5
    @State private var walkAccum: Double = 0

    private let cyan = CardPalette.accent

    /// 按屏宽放大一点。iPhone 16 Pro 是 402pt 宽，元素照 390 排会显空。
    private func scale(for width: CGFloat) -> CGFloat {
        min(1.16, max(1.0, width / 390))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    if showingChat {
                        header
                    }

                    Group {
                        if showingChat {
                            chatScroll
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            homeDashboard
                                .transition(.opacity)
                        }
                    }
                    .animation(NomiMotion.base, value: showingChat)

                    ChatComposer(draft: $draft,
                                 onSend: sendDraft,
                                 onTalk: handleTalk,
                                 focused: $composerFocused)
                        // 往上推输入坞 = 拉开对话（弹簧抽屉）
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 14).onEnded { value in
                                guard !showingChat, value.translation.height < -40 else { return }
                                openChat()
                            }
                        )
                }

                // 对话页默认让出阅读空间，完整角色可从顶栏按需显示。
                if showingChat, showFloatingPet {
                    floatingPet(in: geo)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: phase) { _, newPhase in
            switch newPhase {
            case .listening:
                speech.startIfNeeded()
            case .idle, .thinking:
                if speech.isRecording { speech.stop() }
            }
            syncIsland(newPhase)
            if newPhase == .idle, voiceVisible {
                scheduleVoiceOverlayDismissal()
            }
        }
        .onChange(of: isSpeaking) { _, speaking in
            if !speaking, phase == .idle, voiceVisible {
                scheduleVoiceOverlayDismissal()
            }
        }
        .onChange(of: expression) { _, _ in
            petAnimationTrigger &+= 1
        }
        .onDisappear {
            if speech.isRecording { speech.stop() }
            voiceVisible = false
            state.suspendFaceFollow()
        }
        .onAppear {
            voice.isEnabled = state.settings.voiceEnabled
            restoreChatIfNeeded()
        }
        .onChange(of: initialDraft) { _, newValue in
            // 不自动发送：用户按发送才发给 Nomi
            if !newValue.isEmpty { draft = newValue }
        }
        .onChange(of: isVisible) { _, visible in
            guard visible else { return }
            Task {
                homeDigest = await IntelligenceService.cached() ?? .empty()
            }
        }
        .onChange(of: state.settings.voiceEnabled) { _, enabled in
            voice.isEnabled = enabled
            if !enabled { voice.stop() }
        }
        .onChange(of: state.faceTracker.hasFace) { _, hasFace in
            if hasFace {
                greetLook()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                poseForFreeze()
            } else {
                encouragement = DailyEncouragement.today(quotes: classicalQuotes)
                syncIsland(phase)
                // 回到前台：摄像头跟着恢复，不然"跟着你看"就断了
                if state.settings.followFace {
                    state.setFaceFollow(true)
                }
            }
        }
        .task {
            syncIsland(.idle)
            homeDigest = await IntelligenceService.cached() ?? .empty()
            if state.settings.followFace {
                state.setFaceFollow(true)
            }
            await lifeLoop()
        }
        .sheet(isPresented: $showWeatherDetail) { weatherDetail }
        .sheet(isPresented: $showConfirmSheet) { confirmationSheet }
        .sheet(isPresented: $showTodos) { TodosView(state: state) }
        .sheet(isPresented: $showMusic) { MusicSheet(initialTerm: musicTerm) }
        .fullScreenCover(isPresented: $showClassicalLibrary) {
            ClassicalQuoteLibraryView(
                quotes: classicalQuotes,
                currentQuoteID: encouragement.id,
                onSelect: chooseClassicalQuote
            )
        }
        .fullScreenCover(isPresented: $showMusicPlayer) {
            VinylPlayerPage(player: musicPlayer) {
                showMusicPlayer = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    musicTerm = ""
                    showMusic = true
                }
            }
        }
        .overlay {
            if voiceVisible {
                WhaleVoiceOverlay(
                    stage: voiceOverlayStage,
                    caption: voiceOverlayCaption,
                    onClose: closeVoiceOverlay,
                    onConfirm: {
                        if phase == .listening {
                            finishVoiceCapture()
                        } else {
                            closeVoiceOverlay()
                        }
                    }
                )
                .zIndex(200)
            }
        }

    }

    private var voiceOverlayStage: NomiVoiceStage {
        switch phase {
        case .listening: return .listening
        case .thinking:  return .thinking
        case .idle:      return voiceIsActuallySpeaking ? .speaking : .listening
        }
    }

    private var voiceIsActuallySpeaking: Bool {
        isSpeaking && state.settings.voiceEnabled
    }

    private var voiceOverlayCaption: String {
        switch phase {
        case .listening:
            let spoken = speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            return spoken.isEmpty ? caption : "「\(spoken)」"
        case .thinking:
            return "正在结合日程、位置和你的偏好。"
        case .idle:
            if isSpeaking {
                return items.last?.text ?? caption
            }
            return caption
        }
    }

    private func closeVoiceOverlay() {
        if speech.isRecording { speech.stop() }
        voice.stop()
        speakTask?.cancel()
        isSpeaking = false
        phase = .idle
        voiceVisible = false
    }

    private func finishVoiceCapture() {
        let spoken = speech.transcript
        phase = .idle
        voiceVisible = false
        let trimmed = spoken.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty {
            send(trimmed, keepVoiceOverlay: true)
        } else {
            caption = "没听清，再说一次"
            openChat()
        }
    }

    // MARK: - 背景

    // MARK: - 头

    private var header: some View {
        HStack(alignment: .center, spacing: 11) {
            Button(action: returnToHome) {
                Image(systemName: "chevron.left")
                    .font(.nomiScaled(size: 17, weight: .semibold))
                    .foregroundColor(CardPalette.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回 Nomi 首页")

            Button {
                dismissComposerKeyboard()
                onOpenSettings()
            } label: {
                NomiAvatar(size: 30, expression: expression)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开设置")

            VStack(alignment: .leading, spacing: 3) {
                Text("Nomi")
                    .font(.nomiScaled(size: 24, weight: .semibold))
                    .foregroundColor(CardPalette.ink)
                Text(followStatus)
                    .font(.nomiScaled(size: 12))
                    .foregroundColor(CardPalette.subtle)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                    showFloatingPet.toggle()
                }
            } label: {
                Image(systemName: showFloatingPet ? "eye.slash" : "eye")
                    .font(.nomiScaled(size: 14, weight: .semibold))
                    .foregroundColor(showFloatingPet ? CardPalette.accent : CardPalette.subtle)
                    .frame(width: 44, height: 44)
                    .background(CardPalette.surface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(CardPalette.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showFloatingPet ? "隐藏 Nomi" : "显示 Nomi")

            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 5, height: 5)

                Text(phaseWord)
                    .font(.nomiScaled(size: 11.5, weight: .medium))
                    .foregroundColor(CardPalette.subtle)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(CardPalette.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(CardPalette.line, lineWidth: 1))
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 7)
        .background {
            Rectangle().fill(CardPalette.chrome.opacity(0.96))
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CardPalette.line)
                .frame(height: 0.6)
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissComposerKeyboard()
            }
        )
    }

    private var phaseWord: String {
        switch phase {
        case .idle:      return "在呢"
        case .listening: return "在听"
        case .thinking:  return "在想"
        }
    }

    private var dotColor: Color {
        switch phase {
        case .idle:      return cyan
        case .listening: return Color(red: 0.94, green: 0.42, blue: 0.37)
        case .thinking:  return Color(red: 1.00, green: 0.74, blue: 0.38)
        }
    }

    // MARK: - 可点的小人

    /// 浮在内容上方的小人：默认贴底，可以随便拖
    private func floatingPet(in geo: GeometryProxy) -> some View {
        let uiScale = scale(for: geo.size.width)
        // 拖拽区一直延伸到输入栏上方；不再用比初始位置更高的上限把小人弹回去
        let minY = 54 * uiScale
        let maxY = max(minY, geo.size.height - 110 * uiScale)
        let defaultPoint = CGPoint(x: geo.size.width / 2, y: maxY)
        let rawPoint = petPosition ?? defaultPoint
        let point = CGPoint(x: min(max(0, rawPoint.x), geo.size.width),
                            y: min(max(minY, rawPoint.y), maxY))

        // -1 = 贴左边缘，+1 = 贴右边缘
        // 全部按 Double 算：.opacity() 和 .degrees() 都要 Double，
        // 混进 CGFloat 会报 ambiguous use of operator '-'
        let peek: Double = Double((point.x - geo.size.width / 2) / (geo.size.width / 2))
        // 只有真的靠近边缘（|peek| > 0.55）才开始探头
        let nearEdge: Double = max(0.0, min(1.0, (abs(peek) - 0.55) / 0.45))
        let tilt: Double = peek * 9.0 * nearEdge

        // 提示文字贴着头像右上角：从头顶右侧起，留 6pt 间隙
        return characterArea(width: geo.size.width)
            .overlay(alignment: .topLeading) {
                captionLine
                    .offset(x: 90, y: 7)
                    .opacity(1 - nearEdge)
            }
            .rotationEffect(.degrees(tilt), anchor: .center)
            .opacity(1 - nearEdge * 0.15)
            .scaleEffect(dragStart == nil ? 1 : 1.04)
            .animation(.spring(response: 0.28, dampingFraction: 0.78),
                       value: dragStart == nil)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .local)
                    .onChanged { value in
                        if dragStart == nil {
                            dragStart = petPosition ?? defaultPoint
                        }
                        let base = dragStart ?? defaultPoint
                        let x = base.x + value.translation.width
                        let y = base.y + value.translation.height
                        petPosition = CGPoint(
                            x: min(max(0, x), geo.size.width),
                            y: min(max(minY, y), maxY)
                        )
                    }
                    .onEnded { _ in
                        let current = petPosition ?? defaultPoint
                        let snappedY = current.y > maxY - 20 * uiScale ? maxY : current.y
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                            petPosition = CGPoint(
                                x: min(max(0, current.x), geo.size.width),
                                y: min(max(minY, snappedY), maxY)
                            )
                        }
                        dragStart = nil
                        dragFeedbackTick &+= 1
                    }
            )
            .position(x: point.x, y: point.y)
        .sensoryFeedback(.impact(weight: .light), trigger: dragFeedbackTick)
    }

    private func characterArea(width: CGFloat, startsVoiceOnTap: Bool = true) -> some View {
        let uiScale = scale(for: width)
        // 只有小人本身，没有光圈、没有圆环线
        return PetCharacterView(action: currentAction,
                         followFace: faceFollow,
                         size: 88 * uiScale,
                         eyeOpen: expression.eyeOpen,
                         eyeScale: expression.eyeScale,
                         eyeTint: expression.eyeTint,
                         showShadow: false,
                         headTilt: speakHeadTilt,
                         blinkSpeed: blinkSpeedNow,
                         isPaused: !isVisible || showWeatherDetail || showConfirmSheet
                            || showTodos || showMusic || showMusicPlayer
                            || voiceVisible
                            || showClassicalLibrary,
                         expression: expression,
                         trigger: petAnimationTrigger)
            .frame(width: 104 * uiScale, height: 124 * uiScale)
            .offset(homePetOffset)
            .contentShape(Rectangle())
            .onTapGesture {
                if startsVoiceOnTap {
                    handleTap()
                } else {
                    handleHomePetTap()
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        guard !startsVoiceOnTap else { return }
                        let base = homePetDragStart ?? homePetOffset
                        if homePetDragStart == nil {
                            homePetDragStart = base
                        }
                        homePetOffset = CGSize(
                            width: min(max(base.width + value.translation.width, -22), 22),
                            height: min(max(base.height + value.translation.height, -14), 14)
                        )
                    }
                    .onEnded { _ in
                        guard !startsVoiceOnTap else { return }
                        homePetDragStart = nil
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            homePetOffset = .zero
                        }
                    }
            )
            .sensoryFeedback(.impact(weight: .light), trigger: petTapFeedbackTick)
        }

    private var currentAction: PetMotionAction {
        // 看见你：先蹦一下
        if Date() < hopUntil { return .hop }

        // 念答案时站着说，脸在动、身子别跳
        if isSpeaking { return .idle }

        switch phase {
        case .listening: return .hop
        case .thinking:  return .nod
        case .idle:      return expression.action
        }
    }

    /// 顶部那行小字：让你知道摄像头到底有没有在看你
    private var followStatus: String {
        guard state.settings.followFace else { return "安静陪着你" }
        return state.faceTracker.hasFace ? "正在看着你" : "在找你"
    }

    private var faceFollow: Double {
        let tracker = state.faceTracker
        guard state.settings.followFace, tracker.hasFace else { return 0 }
        return tracker.offsetX
    }


    // MARK: - 让它自己说

    /// 事实由本地查（准），措辞交给模型（活）。
    ///
    /// 以前天气/日程/位置这几条都是模板字符串拼的，句式永远一样，
    /// 听起来像播报机。现在把事实丢给模型，让它用自己的话讲；
    /// 模型不可用就退回模板——永远有话说，也永远不说假数字。
    private func narrate(facts: String, fallback: String) async -> String {
        let key = Keychain.load("deepseek.key") ?? ""
        guard !key.isEmpty else { return fallback }

        let system = """
        你是 Nomi，住在用户手机里，只有眼睛没有嘴。
        现在把刚查到的事实，用你自己的话讲给用户听。

        要求：
        - 一到两句话，口语，像朋友随口说
        - 必须用给的事实里的数字，不许改、不许加、不许猜
        - 不要列表、编号、括号、星号
        - 不要「我查到了」「为您播报」这类开场，直接说事

        事实：
        \(facts)
        """

        do {
            let history = ChatStore.recentForModel()
            let reply = try await LLMClient(apiKey: key).chat(system: system, history: history)
            let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
            // 太短或明显跑偏就退回模板
            if trimmed.count < 4 { return fallback }
            return trimmed
        } catch {
            return fallback
        }
    }

    // MARK: - 看见你

    /// 摄像头一认出你的脸：笑一下、蹦一下、说句话。
    /// 6 秒内不重复，否则你稍微偏一下头它就蹦，很吵。
    private func greetLook() {
        let now = Date()
        guard state.settings.followFace,
              phase == .idle,
              !isSpeaking,
              now.timeIntervalSince(greetedAt) > 6
        else { return }

        greetedAt = now
        hopUntil = now.addingTimeInterval(0.95 * PetLife.pace)

        withAnimation(.easeOut(duration: 0.18 * PetLife.pace)) {
            expression = .happy
        }
        expressionUntil = now.addingTimeInterval(2.6 * PetLife.pace)
        caption = ["你来啦", "看见你了", "嘿，是你", "你终于看我了", "在呢"].randomElement() ?? "你来啦"

        syncIsland(.idle)
    }

    // MARK: - 说话时的神态

    /// 念得越快，眨得越勤：语速 50 是基准，每快 1 就再快 1.2%
    private var blinkSpeedNow: Double {
        guard isSpeaking else { return 1.0 }

        // 语速 50 是基准；每快 1 眨眼再快 2%
        // 56（最快语气）→ 0.30，44（最慢）→ 0.54
        let speed = Double(PetVoice.xunfeiSpeed(for: expression))
        let scale = 0.42 - (speed - 50.0) * 0.020
        return max(0.20, min(0.65, scale))
    }

    /// 一种语气 → 一种表情 + 头部倾斜（度）
    private func face(for tone: SpeechTone) -> (PetExpression, Double) {
        switch tone {
        case .neutral:  return (.calm, 0)      // 平铺直叙
        case .warm:     return (.calm, -1)     // 温和：头略抬
        case .cheerful: return (.happy, -2)    // 好事：眼睛亮一点
        case .serious:  return (.think, 2)     // 提醒：专注，头略低
        case .worried:  return (.sad, 7)       // 没拿到：垂头
        case .thinking: return (.curious, -4)  // 反问：抬头看你
        }
    }

    /// 边念边演：现在用它替换 `voice.speak`
    private func speakWithFace(_ text: String, base: PetExpression, force: Bool = false) {
        // 屏幕上看原文，念出来用整理过的版本（去掉符号、括号、把 15:00 读成十五点）
        let spoken = SpeechSanitizer.prepare(text)
        voice.speak(spoken, expression: base, force: force)

        speakTask?.cancel()

        let beats = SpeechPerformance.beats(for: spoken)
        let total = SpeechPerformance.totalDuration(beats)
        guard total > 0 else { return }

        isSpeaking = true

        speakTask = Task { @MainActor in
            let startedAt = Date()
            var lastTone: SpeechTone?

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startedAt)
                if elapsed > total + 0.45 { break }

                if let beat = SpeechPerformance.beat(at: elapsed, in: beats),
                   beat.tone != lastTone {
                    let (faceExpression, tilt) = face(for: beat.tone)
                    withAnimation(.easeOut(duration: 0.16 * PetLife.pace)) {
                        expression = faceExpression
                    }
                    speakBaseTilt = tilt
                    expressionUntil = Date().addingTimeInterval(beat.duration + 0.2 * PetLife.pace)
                    lastTone = beat.tone
                    syncIsland(.idle)
                }

                // 念字时头轻微起伏，代替"嘴在动"
                speakHeadTilt = speakBaseTilt + sin(elapsed * 7.2) * 1.6

                try? await Task.sleep(nanoseconds: 110_000_000)
            }

            if !Task.isCancelled {
                isSpeaking = false
                speakHeadTilt = 0
                speakBaseTilt = 0
                expression = .calm
                syncIsland(.idle)
            }
        }
    }

    // MARK: - 台词

    private var captionLine: some View {
        Text(captionText)
            .font(.nomiScaled(size: 12.5))
            .foregroundColor(caption.isEmpty ? CardPalette.subtle : cyan.opacity(0.9))
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .frame(width: 108, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .animation(.easeOut(duration: 0.2), value: caption)
            .allowsHitTesting(false)
    }

    private var captionText: String {
        if !caption.isEmpty { return caption }
        switch phase {
        case .listening: return "在听…再点一下结束"
        case .thinking:  return "在想…"
        case .idle:      return "敲我玩 · 按住说话"
        }
    }

    // MARK: - 开合对话

    /// 所有「打开对话」都走这里，动画一致
    private func openChat() {
        dismissComposerKeyboard()
        withAnimation(NomiMotion.base) {
            showingChat = true
        }
    }

    /// 所有「回到首页」都走这里
    private func closeChat() {
        dismissComposerKeyboard()
        withAnimation(NomiMotion.base) {
            showingChat = false
        }
    }

    // MARK: - 鲸鱼 UI · 深海极光首页

    private var homeDashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                whaleHomeHeader
                whaleGlanceStack
                classicalDailyCard
                if !state.loading && (state.errorText != nil || state.currentTemperature == nil) {
                    degradeBanner
                }
                homeWorthKnowingPanel
                homeFlowAndTodos
                whaleToolsRow

                freshnessLine
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissComposerKeyboard()
            }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 14).onEnded { value in
                if value.translation.height > 20 {
                    dismissComposerKeyboard()
                }
            }
        )
        .onChange(of: composerFocused) { _, focused in
            guard focused, !showingChat else { return }
            openChat()
        }
    }

    private var whaleHomeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                WhaleBrandLockup()

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        dismissComposerKeyboard()
                        openChat()
                    } label: {
                        HStack(spacing: 6) {
                            Text("和 Nomi 说")
                                .font(.nomiScaled(size: 10.5, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.nomiScaled(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(CardPalette.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .frame(minHeight: 44)
                        .background(CardPalette.accent.opacity(0.09))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(CardPalette.accent.opacity(0.16), lineWidth: 1)
                        }
                    }
                    .buttonStyle(WhalePressStyle())
                    .accessibilityLabel("打开 Nomi 对话")

                    Button {
                        dismissComposerKeyboard()
                        onOpenSettings()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.nomiScaled(size: 15, weight: .semibold))
                            .foregroundStyle(CardPalette.subtle)
                            .frame(width: 44, height: 44)
                            .background(CardPalette.surface)
                            .clipShape(Circle())
                            .overlay {
                                Circle().stroke(CardPalette.line, lineWidth: 1)
                            }
                    }
                    .buttonStyle(WhalePressStyle())
                    .accessibilityLabel("打开设置")
                }
            }

            if let track = musicPlayer.current {
                Button {
                    showMusicPlayer = true
                } label: {
                    HStack(spacing: 9) {
                        MiniVinylStatusIcon(isPlaying: musicPlayer.isPlaying)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(musicPlayer.isPlaying ? "正在播放" : "已暂停")
                                .font(.nomiScaled(size: 9.5, weight: .medium))
                                .foregroundStyle(CardPalette.accent)
                            Text(track.title)
                                .font(.nomiScaled(size: 12.5, weight: .semibold))
                                .foregroundStyle(CardPalette.ink)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "waveform")
                            .font(.nomiScaled(size: 14, weight: .semibold))
                            .foregroundStyle(CardPalette.accent)

                        Image(systemName: "chevron.right")
                            .font(.nomiScaled(size: 9.5, weight: .semibold))
                            .foregroundStyle(CardPalette.faint)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(CardPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(CardPalette.line, lineWidth: 1)
                    }
                }
                .buttonStyle(WhalePressStyle(scale: 0.985))
                .accessibilityLabel("打开 Nomi 黑胶播放页，正在播放 \(track.title)")
            }
        }
    }

    private var classicalDailyCard: some View {
        ClassicalDailyQuoteCard(
            quote: encouragement,
            onNext: chooseAnotherClassicalQuote,
            onOpenLibrary: { showClassicalLibrary = true }
        )
    }

    private func chooseAnotherClassicalQuote() {
        let next = DailyEncouragement.alternative(
            to: encouragement.id,
            quotes: classicalQuotes
        )
        DailyEncouragement.recordChoice(next)
        withAnimation(.easeOut(duration: 0.18)) {
            encouragement = next
        }
    }

    private func chooseClassicalQuote(_ quote: DailyEncouragement) {
        DailyEncouragement.recordChoice(quote)
        withAnimation(.easeOut(duration: 0.18)) {
            encouragement = quote
        }
    }

    /// 主卡栈：一屏只突出三张里的���张，左右甩切换
    private var whaleGlanceStack: some View {
        NomiCardStack(index: $glanceIndex, count: 3) { page in
            switch page {
            case 0: nextActionGlance
            case 1: weatherGlance
            default: stepsGlance
            }
        }
    }

    /// 第一张：现在最该做的一件事；没有就明确说没有
    @ViewBuilder
    private var nextActionGlance: some View {
        if let item = homeNextAction {
            Button {
                send(item.prompt)
            } label: {
                NomiGlanceCard(symbol: item.symbol,
                               eyebrow: item.meta,
                               title: item.title,
                               detail: "点一下，问问 Nomi 怎么办")
            }
            .buttonStyle(WhalePressStyle(scale: 0.99))
            .accessibilityLabel("下一件事，\(item.title)。问问 Nomi")
        } else {
            NomiGlanceCard(symbol: "checkmark.circle",
                           eyebrow: "下一件事",
                           title: "今天没有安排",
                           detail: calendarAccessHint)
        }
    }

    /// 第二张：现在天气
    private var weatherGlance: some View {
        let now = state.currentTemperature ?? state.dayStatus.temperature
        let text = state.dayStatus.weatherText
        let tempText = now.map { "\(Int($0.rounded()))°" } ?? "没拿到"
        let detail = (now == nil)
            ? "天气没连上，下面显示的是上次的或空的"
            : (text.isEmpty ? "当前温度" : text)

        return NomiGlanceCard(symbol: "cloud.sun",
                              eyebrow: "现在",
                              title: tempText,
                              detail: detail,
                              accent: CardPalette.accent2)
    }

    /// 第三张：今天步数
    private var stepsGlance: some View {
        let steps = state.dayStatus.steps
        let goal = max(1, state.settings.stepGoal)
        let ratio = Double(steps ?? 0) / Double(goal)

        return NomiGlanceCard(symbol: "figure.walk",
                              eyebrow: "今天走了",
                              title: steps.map { "\($0)" } ?? "没拿到",
                              detail: steps == nil
                                  ? "没给运动权限，所以没有步数"
                                  : "目标 \(goal)",
                              progress: steps == nil ? nil : ratio)
    }

    private struct HomeNextItem {
        let title: String
        let meta: String
        let prompt: String
        let symbol: String
    }

    private var homeNextAction: HomeNextItem? {
        let now = Date()
        let overdueTodo = state.pendingTodos
            .filter { todo in
                guard let due = todo.due else { return false }
                return due < now
            }
            .sorted {
                ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture)
            }
            .first

        if let todo = overdueTodo {
            return HomeNextItem(
                title: todo.title,
                meta: "已到期 · 待办",
                prompt: "帮我把「\(todo.title)」拆成下一步",
                symbol: "exclamationmark.circle"
            )
        }

        let meeting = nextMeeting
        let nextTodo = state.pendingTodos
            .compactMap { todo -> (Date, TodoItem)? in
                guard let due = todo.due, due >= now else { return nil }
                return (due, todo)
            }
            .sorted { $0.0 < $1.0 }
            .first?.1

        if let meeting, let todo = nextTodo {
            let due = todo.due ?? .distantFuture
            if due < meeting.start {
                return HomeNextItem(
                    title: todo.title,
                    meta: dueText(due),
                    prompt: "帮我把「\(todo.title)」拆成下一步",
                    symbol: "checklist"
                )
            }
            return HomeNextItem(
                title: meeting.title,
                meta: meeting.isAllDay ? "全天 · 日程" : "\(shortTime(meeting.start)) · 日程",
                prompt: "帮我准备一下「\(meeting.title)」",
                symbol: "calendar"
            )
        }

        if let meeting {
            return HomeNextItem(
                title: meeting.title,
                meta: meeting.isAllDay ? "全天 · 日程" : "\(shortTime(meeting.start)) · 日程",
                prompt: "帮我准备一下「\(meeting.title)」",
                symbol: "calendar"
            )
        }

        if let todo = nextTodo {
            return HomeNextItem(
                title: todo.title,
                meta: todo.due.map { dueText($0) } ?? "待办",
                prompt: "帮我把「\(todo.title)」拆成下一步",
                symbol: "checklist"
            )
        }

        return nil
    }

    private var homeWorthKnowingPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("值得知道")
                    .font(.nomiScaled(size: 18, weight: .bold))
                    .foregroundStyle(CardPalette.ink)

                Spacer()

                Button {
                    dismissComposerKeyboard()
                    onOpenIntelligence(.news)
                } label: {
                    HStack(spacing: 3) {
                        Text("全部")
                        Image(systemName: "chevron.right")
                            .font(.nomiScaled(size: 9, weight: .semibold))
                    }
                    .font(.nomiScaled(size: 11.5, weight: .medium))
                    .foregroundStyle(CardPalette.subtle)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开今天值得知道")
            }

            HStack(spacing: 16) {
                homeIntelligenceCategory(.news, count: homeDigest.news.count)
                homeIntelligenceCategory(.ai, count: homeDigest.ai.count)
                homeIntelligenceCategory(.market, count: homeDigest.market.count)
            }

            if let article = homeDigest.news.first {
                Button {
                    onOpenIntelligence(.news)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text("时事")
                            .font(.nomiScaled(size: 10.5, weight: .bold))
                            .foregroundStyle(CardPalette.accent2)
                            .frame(width: 30, alignment: .leading)

                        Text(article.title)
                            .font(.nomiScaled(size: 13.5, weight: .medium))
                            .foregroundStyle(CardPalette.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开\(article.title)")
            } else if let article = homeDigest.ai.first {
                Button {
                    onOpenIntelligence(.ai)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text("AI")
                            .font(.nomiScaled(size: 10.5, weight: .bold))
                            .foregroundStyle(CardPalette.rose)
                            .frame(width: 30, alignment: .leading)

                        Text(article.title)
                            .font(.nomiScaled(size: 13.5, weight: .medium))
                            .foregroundStyle(CardPalette.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开\(article.title)")
            } else {
                Button {
                    onOpenIntelligence(.news)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.nomiScaled(size: 11, weight: .semibold))
                        Text("打开后更新时事、AI 与行情")
                            .font(.nomiScaled(size: 12.5, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(CardPalette.subtle)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            if !homeDigest.market.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(homeDigest.market.prefix(3))) { quote in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(quote.name)
                                .font(.nomiScaled(size: 9.5, weight: .medium))
                                .foregroundStyle(CardPalette.subtle)
                                .lineLimit(1)
                            Text(quote.percentText)
                                .font(.nomiScaled(size: 12.5, weight: .bold))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .animation(NomiMotion.base, value: quote.percentText)
                                .foregroundStyle(homeMarketColor(quote))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                Text("公开行情可能延迟，不构成投资建议")
                    .font(.nomiScaled(size: 9.5))
                    .foregroundStyle(CardPalette.faint)
            }
        }
        .padding(14)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        }
    }

    private func homeIntelligenceCategory(
        _ module: IntelligenceModule,
        count: Int
    ) -> some View {
        Button {
            onOpenIntelligence(module)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: module.symbol)
                    .font(.nomiScaled(size: 10, weight: .semibold))
                Text(module.homepageTitle)
                    .font(.nomiScaled(size: 11.5, weight: .semibold))
                if count > 0 {
                    Text("\(count)")
                        .font(.nomiScaled(size: 12.5, weight: .semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(NomiMotion.base, value: count)
                        .foregroundStyle(CardPalette.faint)
                }
            }
            .foregroundStyle(homeModuleColor(module))
            .frame(minHeight: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(module.homepageTitle)，\(count) 条")
    }

    @ViewBuilder
    private var homeFlowAndTodos: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                homeFlowPanel
                homeTodoRail
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                homeFlowPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                homeTodoRail
                    .frame(width: 132, alignment: .top)
            }
        }
    }

    private var homeFlowPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("今天的流向")
                    .font(.nomiScaled(size: 14, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                Spacer()
                Text(state.meetings.isEmpty ? "空" : "\(state.meetings.count) 项")
                    .font(.nomiScaled(size: 10.5))
                    .foregroundStyle(CardPalette.subtle)
            }

            if state.meetings.isEmpty {
                Text(calendarAccessHint)
                    .font(.nomiScaled(size: 11.5))
                    .foregroundStyle(CardPalette.subtle)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(state.meetings.prefix(3))) { meeting in
                        Button {
                            send("帮我准备一下「\(meeting.title)」")
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                VStack(spacing: 3) {
                                    Text(meeting.isAllDay ? "全天" : shortTime(meeting.start))
                                        .font(.nomiScaled(size: 10.5, weight: .semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(
                                            meeting.id == (nextMeeting?.id ?? "")
                                            ? CardPalette.accent
                                            : CardPalette.subtle
                                        )
                                    Circle()
                                        .fill(meeting.id == (nextMeeting?.id ?? "")
                                              ? CardPalette.accent
                                              : CardPalette.lineStrong)
                                        .frame(width: 5, height: 5)
                                }
                                .frame(width: 35)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(meeting.title)
                                        .font(.nomiScaled(size: 12.5, weight: .semibold))
                                        .foregroundStyle(CardPalette.ink)
                                        .lineLimit(1)
                                    if let place = meeting.location, !place.isEmpty {
                                        Text(place)
                                            .font(.nomiScaled(size: 9.5))
                                            .foregroundStyle(CardPalette.faint)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        }
    }

    private var homeTodoRail: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text("待办")
                    .font(.nomiScaled(size: 14, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                Spacer(minLength: 0)
                Text("\(state.pendingTodos.count)")
                    .font(.nomiScaled(size: 9.5, weight: .bold))
                    .foregroundStyle(CardPalette.navyInk)
                    .frame(width: 19, height: 19)
                    .background(CardPalette.accent)
                    .clipShape(Circle())
            }

            if state.pendingTodos.isEmpty {
                Text("没有待办")
                    .font(.nomiScaled(size: 10.5))
                    .foregroundStyle(CardPalette.faint)
                    .padding(.vertical, 7)
            } else {
                ForEach(Array(state.pendingTodos.prefix(3))) { todo in
                    HStack(alignment: .top, spacing: 5) {
                        Button {
                            Task { _ = await state.completeTodo(id: todo.id) }
                        } label: {
                            Image(systemName: "circle")
                                .font(.nomiScaled(size: 13))
                                .foregroundStyle(CardPalette.accent)
                                .frame(width: 20, height: 26)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("完成 \(todo.title)")

                        VStack(alignment: .leading, spacing: 1) {
                            Text(todo.title)
                                .font(.nomiScaled(size: 10.5, weight: .medium))
                                .foregroundStyle(CardPalette.ink)
                                .lineLimit(2)
                            if let due = todo.due {
                                Text(dueText(due))
                                    .font(.nomiScaled(size: 8.8))
                                    .foregroundStyle(due < Date() ? CardPalette.amberInk : CardPalette.faint)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer(minLength: 0)

            Button {
                showTodos = true
            } label: {
                Text("全部待办")
                    .font(.nomiScaled(size: 10.5, weight: .semibold))
                    .foregroundStyle(CardPalette.accent)
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(11)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        }
    }

    private func homeModuleColor(_ module: IntelligenceModule) -> Color {
        switch module {
        case .news: return CardPalette.accent2
        case .ai: return CardPalette.rose
        case .market: return CardPalette.amber
        case .weibo: return CardPalette.amber
        case .zhihu: return CardPalette.accent
        case .game: return CardPalette.success
        }
    }

    private func homeMarketColor(_ quote: StockQuote) -> Color {
        if quote.isRise { return CardPalette.rose }
        if quote.isFall { return CardPalette.success }
        return CardPalette.subtle
    }

    private var whaleToolsRow: some View {
        HStack(spacing: 8) {
            homeToolButton(
                title: state.currentTemperature.map { "\(Int($0.rounded()))° 天气" } ?? "天气",
                symbol: "cloud.sun"
            ) {
                dismissComposerKeyboard()
                showWeatherDetail = true
            }

            homeToolButton(title: "音乐", symbol: "music.note") {
                dismissComposerKeyboard()
                musicTerm = ""
                showMusic = true
            }

            homeToolButton(title: "位置", symbol: "location") {
                send("帮我看看我现在的位置")
            }
        }
    }

    private func homeToolButton(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.nomiScaled(size: 12, weight: .semibold))
                Text(title)
                    .font(.nomiScaled(size: 12.5, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(CardPalette.subtle)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(CardPalette.raised)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(WhalePressStyle(scale: 0.97))
    }

    private var whaleTodaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            WhaleSectionTitle(
                title: "今天的安排",
                subtitle: todayDateLine,
                trailing: "\(state.meetings.count) 项"
            )

            WhaleGlassCard(radius: 22, padding: 15) {
                VStack(spacing: 0) {
                    ForEach(Array(state.meetings.prefix(3).enumerated()), id: \.element.id) { index, meeting in
                        whaleAgendaRow(meeting, isLast: index == min(3, state.meetings.count) - 1)
                    }
                }
            }
        }
    }

    private func whaleAgendaRow(_ meeting: MeetingItem, isLast: Bool) -> some View {
        let now = Date()
        let end = meeting.end ?? meeting.start
        let isNow = meeting.start <= now && end > now
        let isPast = end <= now

        return VStack(spacing: 0) {
            HStack(spacing: 11) {
                VStack(spacing: 2) {
                    Text(meeting.isAllDay ? "全天" : shortTime(meeting.start))
                        .font(.nomiScaled(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(isNow ? CardPalette.accent : CardPalette.subtle)
                    if !meeting.isAllDay {
                        Circle()
                            .fill(isNow ? CardPalette.accent : CardPalette.lineStrong)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(width: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(meeting.title)
                        .font(.nomiScaled(size: 14, weight: isNow ? .semibold : .medium))
                        .foregroundStyle(isPast ? CardPalette.subtle : CardPalette.ink)
                        .lineLimit(1)

                    if let place = meeting.location, !place.isEmpty {
                        Text(place)
                            .font(.nomiScaled(size: 10.5))
                            .foregroundStyle(CardPalette.faint)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)

                if isNow {
                    WhalePill(text: "进行中", color: CardPalette.accent)
                }
            }
            .padding(.vertical, 9)

            if !isLast {
                WhaleRowDivider(leading: 53)
            }
        }
    }

    private var whaleTodoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("待办")
                    .font(.nomiScaled(size: 18, weight: .bold))
                    .foregroundStyle(CardPalette.ink)
                Spacer()
                Button("查看全部") {
                    showTodos = true
                }
                .font(.nomiScaled(size: 11.5, weight: .medium))
                .foregroundStyle(CardPalette.subtle)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                ForEach(Array(state.pendingTodos.prefix(3).enumerated()), id: \.element.id) { index, todo in
                    HStack(spacing: 11) {
                        Button {
                            Task { _ = await state.completeTodo(id: todo.id) }
                        } label: {
                            Image(systemName: "circle")
                                .font(.nomiScaled(size: 18, weight: .regular))
                                .foregroundStyle(CardPalette.accent)
                                .frame(width: 34, height: 38)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("完成 \(todo.title)")

                        VStack(alignment: .leading, spacing: 3) {
                            Text(todo.title)
                                .font(.nomiScaled(size: 13.5, weight: .medium))
                                .foregroundStyle(CardPalette.ink)
                                .lineLimit(1)
                            if let due = todo.due {
                                Text(dueText(due))
                                    .font(.nomiScaled(size: 10))
                                    .foregroundStyle(due < Date() ? CardPalette.amberInk : CardPalette.subtle)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)

                    if index < min(3, state.pendingTodos.count) - 1 {
                        WhaleRowDivider(leading: 50)
                    }
                }
            }
            .background(CardPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(CardPalette.line, lineWidth: 1)
            }
        }
    }

    private var todayDateLine: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: Date())
    }

    /// 现在最该做什么：下一个会
    private var nextMeeting: MeetingItem? {
        let now = Date()
        if let upcoming = state.meetings.first(where: { $0.start > now }) {
            return upcoming
        }
        return state.meetings.first { ($0.end ?? $0.start) > now }
    }

    /// 参考稿的首屏层级：日期在上，问候是唯一的大标题。
    private var homeHeading: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(greetingSubtitle)
                .font(.nomiScaled(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(CardPalette.subtle)

            Text(greetingText)
                .font(.nomiScaled(size: 34, weight: .bold))
                .tracking(-0.7)
                .foregroundColor(CardPalette.ink)
        }
    }

    /// 完整 Nomi 是首屏主角，不再是问候旁边的小装饰。
    private func characterHero(width: CGFloat) -> some View {
        VStack(spacing: 12) {
            characterArea(width: width, startsVoiceOnTap: false)
                .accessibilityLabel("Nomi")
                .accessibilityHint("点一下看看它的表情和动作")

            Text(caption.isEmpty
                 ? "\(expressionName) · \(expression.statusWord)"
                 : caption)
                .font(.nomiScaled(size: 12.5))
                .foregroundColor(CardPalette.subtle)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .animation(.easeOut(duration: 0.18), value: caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private var expressionName: String {
        switch expression {
        case .calm:    return "平静"
        case .happy:   return "开心"
        case .laugh:   return "大笑"
        case .curious: return "好奇"
        case .angry:   return "生气"
        case .sad:     return "低落"
        case .cry:     return "难过"
        case .doze:    return "打盹"
        case .sigh:    return "叹气"
        case .think:   return "思考"
        case .startle: return "吓一跳"
        case .bored:   return "无聊"
        case .excited: return "兴奋"
        case .running: return "跑步"
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:  return "早上好"
        case 11..<14: return "中午好"
        case 14..<18: return "下午好"
        case 18..<23: return "晚上好"
        default:      return "该睡了"
        }
    }

    private var greetingSubtitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: Date())
    }

    /// 重点卡：深蓝底，信息顺序 时间/地点 → 事件名 → 一句提示 → 两个动作
    private func primaryCard(_ meeting: MeetingItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(cardTimeLine(meeting))
                    .font(.nomiScaled(size: 12.5, weight: .medium))
                    .foregroundColor(CardPalette.navyInk.opacity(0.72))

                Spacer()

                Text(countdownText(meeting))
                    .font(.nomiScaled(size: 17, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(CardPalette.navyInk)
            }

            Text(meeting.title)
                .font(.nomiScaled(size: 24, weight: .bold))
                .foregroundColor(CardPalette.navyInk)
                .lineLimit(2)

            Text(prepareHint(meeting))
                .font(.nomiScaled(size: 13.5))
                .foregroundColor(CardPalette.navyInk.opacity(0.82))
                .lineLimit(2)

            HStack(spacing: 10) {
                Button {
                    send("这次要准备什么")
                } label: {
                    Text("问它一句")
                        .font(.nomiScaled(size: 14, weight: .semibold))
                        .foregroundColor(CardPalette.navy)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(CardPalette.navyInk)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    openMaps(for: meeting)
                } label: {
                    Text("怎么去")
                        .font(.nomiScaled(size: 14, weight: .semibold))
                        .foregroundColor(CardPalette.navyInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(CardPalette.navyInk.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardPalette.navy)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func cardTimeLine(_ meeting: MeetingItem) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"

        var line = formatter.string(from: meeting.start)
        if let end = meeting.end {
            line += "–" + formatter.string(from: end)
        }
        if let place = meeting.location, !place.isEmpty {
            line += " · " + place
        }
        return line
    }

    private func countdownText(_ meeting: MeetingItem) -> String {
        let seconds = meeting.start.timeIntervalSince(Date())
        guard seconds > 0 else { return "进行中" }

        let minutes = Int(seconds / 60)
        if minutes < 1 { return "马上" }
        if minutes < 60 { return "\(minutes) 分钟后" }
        return "\(minutes / 60) 小时后"
    }

    private func prepareHint(_ meeting: MeetingItem) -> String {
        if let place = meeting.location, !place.isEmpty {
            return "在 \(place)。材料可以先在对话里过一遍。"
        }
        return "准备好了吗？需要的话让它把要点理一遍。"
    }

    private var homeContextLine: String {
        var parts: [String] = []

        if let temperature = state.currentTemperature {
            parts.append("\(state.dayStatus.cityName) \(Int(temperature.rounded()))° \(state.dayStatus.weatherText)")
        }

        if let steps = state.dayStatus.steps {
            parts.append("\(steps.formatted()) / \(state.dayStatus.stepGoal.formatted()) 步")
        }

        return parts.joined(separator: " · ")
    }

    private var homeContext: some View {
        HStack(spacing: 7) {
            Image(systemName: "location")
                .font(.nomiScaled(size: 11, weight: .medium))

            Text(homeContextLine)
                .font(.nomiScaled(size: 12.5))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .foregroundColor(CardPalette.subtle)
    }

    private func openMaps(for meeting: MeetingItem) {
        let query = meeting.location ?? meeting.title
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://maps.apple.com/?q=\(encoded)")
        else { return }
        UIApplication.shared.open(url)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// 今天没安排：不编造，说清是"真没安排"还是"没权限看不到"
    private var noPlanCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.nomiScaled(size: 17, weight: .medium))
                    .foregroundColor(CardPalette.accent)

                Text("今天没有安排")
                    .font(.nomiScaled(size: 20, weight: .semibold))
                    .foregroundColor(CardPalette.ink)
            }

            Text(calendarAccessHint)
                .font(.nomiScaled(size: 13))
                .foregroundColor(CardPalette.subtle)
                .fixedSize(horizontal: false, vertical: true)

            if !state.dayStatus.hasCalendarAccess {
                Button {
                    openSystemSettings()
                } label: {
                    Text("去开日历权限")
                        .font(.nomiScaled(size: 13, weight: .semibold))
                        .foregroundColor(CardPalette.accent)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    handleTalk()
                } label: {
                    HStack(spacing: 5) {
                        Text("告诉 Nomi")
                        Image(systemName: "arrow.up.right")
                            .font(.nomiScaled(size: 11, weight: .semibold))
                    }
                    .font(.nomiScaled(size: 13, weight: .semibold))
                    .foregroundColor(CardPalette.accent)
                    .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        )
    }

    /// 断网 / 天气没拿到时的降级卡：说清哪一块不可用，别装作一切正常
    private var degradeBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "cloud.slash")
                    .font(.nomiScaled(size: 15))
                    .foregroundColor(CardPalette.amberInk)

                VStack(alignment: .leading, spacing: 3) {
                    Text("天气暂时没更新")
                        .font(.nomiScaled(size: 14, weight: .semibold))
                        .foregroundColor(CardPalette.amberInk)

                    Text(degradeDetail)
                        .font(.nomiScaled(size: 12))
                        .foregroundColor(CardPalette.amberInk.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 16) {
                if state.canRequestLocation {
                    Button("允许定位") {
                        requestLocationAndRefresh()
                    }
                } else if state.locationPermissionDenied {
                    Button("去系统设置") {
                        openSystemSettings()
                    }
                }

                Button("重试天气") {
                    Task { await state.refresh(useCurrentLocation: false) }
                }
            }
            .font(.nomiScaled(size: 12, weight: .semibold))
            .foregroundColor(CardPalette.amberInk)
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardPalette.amberSoft)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var degradeDetail: String {
        var parts: [String] = []

        if state.currentTemperature == nil {
            parts.append(state.weatherFailureText ?? "天气还没有更新")
            if state.locationPermissionDenied {
                parts.append("定位已关闭，使用设置城市「\(state.settings.cityName)」")
            } else if state.canRequestLocation {
                parts.append("未使用定位，使用设置城市「\(state.settings.cityName)」")
            }
        }
        parts.append(
            state.weatherUpdatedAt == .distantPast
                ? "还没有成功更新过"
                : "上次成功 " + relativeTime(since: state.weatherUpdatedAt)
        )
        return parts.joined(separator: " · ")
    }

    private func relativeTime(since date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 90 { return "刚刚" }
        if seconds < 3600 { return "\(Int(seconds / 60)) 分钟前" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "M月d日 HH:mm"
        return formatter.string(from: date)
    }

    private var calendarAccessHint: String {
        state.dayStatus.hasCalendarAccess
            ? "想安排点什么，直接跟我说；也可以现在告诉我。"
            : "没给日历权限，所以这里看不到你的安排。去设置里开一下。"
    }

    /// 高优待办：最多两条
    private var taskList: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("要做的事", trailing: "\(state.pendingTodos.count) 件")

            VStack(spacing: 0) {
                ForEach(Array(state.pendingTodos.prefix(2))) { todo in
                    taskRow(todo)
                    Rectangle().fill(CardPalette.line).frame(height: 0.5)
                }

                Button {
                    showTodos = true
                } label: {
                    HStack(spacing: 4) {
                        Text("全部 \(state.pendingTodos.count) 件")
                            .font(.nomiScaled(size: 12.5, weight: .semibold))
                            .foregroundColor(CardPalette.accent)
                        Image(systemName: "chevron.right")
                            .font(.nomiScaled(size: 10, weight: .semibold))
                            .foregroundColor(CardPalette.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
            }
            .background(CardPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(CardPalette.line, lineWidth: 1)
            )
        }
    }

    private func taskRow(_ todo: TodoItem) -> some View {
        HStack(spacing: 12) {
            Button {
                Task { _ = await state.completeTodo(id: todo.id) }
            } label: {
                Image(systemName: "circle")
                    .font(.nomiScaled(size: 19))
                    .foregroundColor(CardPalette.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("完成 \(todo.title)")

            VStack(alignment: .leading, spacing: 3) {
                Text(todo.title)
                    .font(.nomiScaled(size: 15, weight: .medium))
                    .foregroundColor(CardPalette.ink)
                    .lineLimit(1)

                if let due = todo.due {
                    Text(dueText(due))
                        .font(.nomiScaled(size: 12))
                        .foregroundColor(due < Date() ? CardPalette.amberInk : CardPalette.subtle)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func dueText(_ date: Date) -> String {
        let calendar = Calendar.current
        if date < Date() { return "已过期" }
        if calendar.isDateInToday(date) {
            return "今天 " + shortTime(date)
        }
        if calendar.isDateInTomorrow(date) { return "明天" }
        return "过几天"
    }

    /// 今天的节奏：紧凑时间线（最多 4 条）
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("今天的节奏",
                          trailing: state.meetings.isEmpty ? "空" : "\(state.meetings.count) 项")

            if state.meetings.isEmpty {
                Text(calendarAccessHint)
                    .font(.nomiScaled(size: 13))
                    .foregroundColor(CardPalette.subtle)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(state.meetings.prefix(4))) { meeting in
                        timelineRow(meeting)
                    }
                }
                .background(CardPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(CardPalette.line, lineWidth: 1)
                )
            }
        }
    }

    private func timelineRow(_ meeting: MeetingItem) -> some View {
        let now = Date()
        let endTime = meeting.end ?? meeting.start
        let isNow = meeting.start <= now && endTime > now
        let isPast = endTime <= now

        return HStack(alignment: .top, spacing: 12) {
            Text(shortTime(meeting.start))
                .font(.nomiScaled(size: 12.5, weight: .medium))
                .monospacedDigit()
                .foregroundColor(isNow ? CardPalette.accent : CardPalette.subtle)
                .frame(width: 46, alignment: .leading)

            Circle()
                .fill(isNow ? CardPalette.accent : CardPalette.line)
                .frame(width: 6, height: 6)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title)
                    .font(.nomiScaled(size: 14.5, weight: .medium))
                    .foregroundColor(isPast ? CardPalette.subtle : CardPalette.ink)
                    .lineLimit(1)

                if let place = meeting.location, !place.isEmpty {
                    Text(place)
                        .font(.nomiScaled(size: 11.5))
                        .foregroundColor(CardPalette.subtle)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func sectionHeader(_ title: String, trailing: String) -> some View {
        HStack {
            Text(title)
                .font(.nomiScaled(size: 13, weight: .semibold))
                .foregroundColor(CardPalette.subtle)
            Spacer()
            Text(trailing)
                .font(.nomiScaled(size: 12))
                .foregroundColor(CardPalette.subtle)
        }
    }

    /// 数据来源与新鲜度：不写这一行，就等于让人猜数据新旧
    private var freshnessLine: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.nomiScaled(size: 10))
            Text(sourceLine)
                .font(.nomiScaled(size: 11))
        }
        .foregroundColor(CardPalette.subtle.opacity(0.85))
        .padding(.top, 2)
    }

    private var sourceLine: String {
        var parts: [String] = []

        parts.append(state.dayStatus.hasCalendarAccess ? "日程来自系统日历" : "没有日历权限")

        if let temp = state.currentTemperature {
            parts.append("天气 \(Int(temp.rounded()))° 来自 Open-Meteo")
        } else if state.errorText != nil {
            parts.append("天气没拿到")
        }

        parts.append("更新于 " + freshnessText)
        return parts.joined(separator: " · ")
    }

    private var freshnessText: String {
        let seconds = Date().timeIntervalSince(state.lastRefreshAt)
        guard seconds < 3600 else { return "较早" }
        if seconds < 90 { return "刚刚" }
        return "\(Int(seconds / 60)) 分钟前"
    }

    private var chatScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if items.isEmpty && phase == .idle {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("想聊什么？")
                                .font(.nomiScaled(size: 24, weight: .bold))
                                .foregroundStyle(CardPalette.ink)
                            Text("可以直接问今天的安排，也可以让我帮你整理一件事。")
                                .font(.nomiScaled(size: 14))
                                .foregroundStyle(CardPalette.subtle)
                                .lineSpacing(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 42)
                        .padding(.horizontal, 4)
                    }

                    ForEach(items) { item in
                        Group {
                            if let schedule = item.schedule {
                                ScheduleCardView(payload: schedule)
                            } else if let weather = item.weather {
                                WeatherCardView(weather: weather,
                                                city: cityName,
                                                pm25: state.airPM25) {
                                    showWeatherDetail = true
                                }
                            } else if let intelligence = item.intelligence {
                                IntelligenceCardView(
                                    digest: intelligence,
                                    initialModule: item.intelligenceModule
                                )
                            } else if let location = item.location {
                                LocationCardView(fix: location)
                            } else {
                                bubble(item)
                            }
                        }
                        .id(item.id)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                    }

                    if phase == .thinking {
                        NomiTypingIndicator()
                            .id("nomi-thinking")
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 96)
                .animation(.spring(response: 0.38, dampingFraction: 0.86),
                           value: items.count)
                .animation(.easeOut(duration: 0.18), value: phase)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissComposerKeyboard()
                }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 14).onEnded { value in
                    if value.startLocation.x <= 28,
                       value.translation.width > 70,
                       abs(value.translation.width) > abs(value.translation.height) * 1.2 {
                        returnToHome()
                    } else if value.translation.height > 20 {
                        dismissComposerKeyboard()
                    }
                }
            )
            .onChange(of: items.count) { _, _ in
                if let last = items.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: phase) { _, newPhase in
                if newPhase == .thinking {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                        withAnimation(.easeOut(duration: 0.18)) {
                            proxy.scrollTo("nomi-thinking", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private func bubble(_ item: ChatItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if item.mine {
                Spacer(minLength: 46)
            } else {
                visorAvatar
            }

            VStack(alignment: item.mine ? .trailing : .leading, spacing: 5) {
                Text(captionLine(for: item))
                    .font(.nomiScaled(size: 11, weight: .medium))
                    .foregroundColor(CardPalette.subtle)
                    .tracking(0.8)

                Text(item.text ?? "")
                    .font(.nomiScaled(size: 16))
                    .foregroundColor(item.mine ? .white : CardPalette.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(item.mine ? CardPalette.bubbleMine : CardPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(item.mine ? Color.clear : CardPalette.line, lineWidth: 1)
                    )
                    .scaleEffect(replayingID == item.id ? 0.97 : 1)
                    .animation(.easeOut(duration: 0.12), value: replayingID)
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .onTapGesture {
                        // 点它说的话 → 再念一遍（只有它说的才念）
                        guard !item.mine else { return }
                        replay(item)
                    }

                // 确认按钮放在整条气泡下面，不能插在修饰符链中间
                if item.showConfirm, pendingItemID == item.id {
                    confirmRow(for: item)
                        .padding(.top, 2)
                }
            }

            if !item.mine { Spacer(minLength: 30) }
        }
    }

    /// 气泡下面的确认按钮：只有这一条在等确认时才出现
    private func confirmRow(for item: ChatItem) -> some View {
        HStack(spacing: 8) {
            Button {
                if pendingTodo != nil {
                    confirmTodoAction()
                } else {
                    confirmPendingAction()
                }
            } label: {
                Text("确认")
                    .font(.nomiScaled(size: 13.5, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(CardPalette.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                dismissPendingAction()
            } label: {
                Text("算了")
                    .font(.nomiScaled(size: 13.5))
                    .foregroundColor(CardPalette.subtle)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(CardPalette.raised)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var confirmationSheet: some View {
        if let action = pendingAction {
            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(CardPalette.lineStrong)
                    .frame(width: 38, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                HStack(spacing: 11) {
                    WhaleIconTile(
                        symbol: action.kind == .cancel ? "calendar.badge.minus" : "calendar.badge.clock",
                        color: CardPalette.amber,
                        size: 42
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("执行前确认")
                            .font(.nomiScaled(size: 10.5, weight: .medium))
                            .foregroundStyle(CardPalette.faint)
                        Text(action.kind == .cancel ? "取消这场安排" : "调整这场安排")
                            .font(.nomiScaled(size: 19, weight: .bold))
                            .foregroundStyle(CardPalette.ink)
                    }

                    Spacer()

                    Button {
                        showConfirmSheet = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.nomiScaled(size: 12, weight: .semibold))
                            .foregroundStyle(CardPalette.subtle)
                            .frame(width: 32, height: 32)
                            .background(CardPalette.raised)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(WhalePressStyle())
                    .accessibilityLabel("关闭确认")
                }
                .padding(.bottom, 15)

                WhaleGlassCard(radius: 18, padding: 14, tint: CardPalette.amber) {
                    VStack(alignment: .leading, spacing: 11) {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(action.title)
                                    .font(.nomiScaled(size: 16, weight: .semibold))
                                    .foregroundStyle(CardPalette.ink)
                                    .lineLimit(2)
                                Text("原时间 · \(whenFormatter.string(from: action.start))")
                                    .font(.nomiScaled(size: 11))
                                    .foregroundStyle(CardPalette.subtle)
                            }

                            Spacer(minLength: 6)

                            if let newStart = action.newStart {
                                Text(shortTime(newStart))
                                    .font(.nomiScaled(size: 14, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(CardPalette.accent)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(CardPalette.accent.opacity(0.11))
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            }
                        }

                        WhaleRowDivider()

                        Text(action.question)
                            .font(.nomiScaled(size: 13))
                            .foregroundStyle(CardPalette.subtle)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.shield")
                        .font(.nomiScaled(size: 13, weight: .semibold))
                        .foregroundStyle(CardPalette.accent)
                        .padding(.top, 1)
                    Text("只在你确认后写入系统日历。确认前不会取消、改期或发送任何消息。")
                        .font(.nomiScaled(size: 11.5))
                        .foregroundStyle(CardPalette.subtle)
                        .lineSpacing(2)
                }
                .padding(12)
                .background(CardPalette.accent.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 12)

                Button {
                    confirmPendingAction()
                } label: {
                    Text(action.kind == .cancel ? "确认取消" : "确认改期")
                        .font(.nomiScaled(size: 14.5, weight: .bold))
                        .foregroundStyle(CardPalette.navyInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 49)
                        .background(CardPalette.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(WhalePressStyle())
                .padding(.top, 15)

                Button {
                    showConfirmSheet = false
                } label: {
                    Text("再想想")
                        .font(.nomiScaled(size: 13.5, weight: .medium))
                        .foregroundStyle(CardPalette.subtle)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 20)
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(CardPalette.solid)
        }
    }

    /// 点气泡：把这句话再念一遍，脸也跟着演
    private func replay(_ item: ChatItem) {
        guard let text = item.text, !text.isEmpty else { return }

        replayingID = item.id
        speakWithFace(text, base: expression, force: true)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            replayingID = nil
        }
    }

    private var visorAvatar: some View {
        NomiAvatar(size: 28, expression: expression)
            .padding(.top, 12)
    }

    private func captionLine(for item: ChatItem) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return (item.mine ? "你" : "NOMI") + " · " + formatter.string(from: item.date)
    }

    // MARK: - 聊天记录

    /// 重开 App 时把上次的对话接上（只恢复文字，卡片重新查）
    private func restoreChatIfNeeded() {
        guard items.isEmpty else { return }

        let turns = ChatStore.load()
        guard !turns.isEmpty else { return }

        items = turns.map { turn in
            ChatItem(mine: turn.mine, date: turn.date, text: turn.text, schedule: nil)
        }
    }

    /// 卡片类回答也写进记录，下次问「刚才天气多少」它接得住
    private func rememberAssistant(_ text: String) {
        ChatStore.append(ChatTurn(mine: false, text: text, date: Date()))
    }

    // MARK: - 手势

    private func dismissComposerKeyboard() {
        composerFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func returnToHome() {
        dismissComposerKeyboard()
        withAnimation(.easeOut(duration: 0.2)) {
            closeChat()
        }
    }

    /// 点一下：它会有反应；不生气的话再开/关麦克风
    /// 底部「说话」按钮用：直接开始听
    private func handleTalk() {
        guard phase == .idle else { return }
        dismissComposerKeyboard()
        voice.stop()
        caption = ""
        voiceVisible = true
        phase = .listening
    }

    /// 首页的大 Nomi 只负责互动表演，不自动切入语音或聊天。
    private func handleHomePetTap() {
        dismissComposerKeyboard()
        petAnimationTrigger &+= 1
        let now = Date().timeIntervalSinceReferenceDate
        let base = life.tap(at: now)

        let chosen: PetExpression
        switch base {
        case .angry:
            chosen = .angry
            caption = "别敲了。"
        case .cry:
            chosen = .cry
            caption = "……别敲了"
        default:
            let reaction = life.randomReaction(roll: Double.random(in: 0...0.9999))
            chosen = reaction.expression
            caption = reaction.text
        }

        withAnimation(.easeOut(duration: 0.14 * PetLife.pace)) {
            expression = chosen
        }
        expressionUntil = Date().addingTimeInterval(2.4 * PetLife.pace)
        petTapFeedbackTick &+= 1
        syncIsland(.idle)
    }

    /// 点一下：开始听；再点一下：结束并发送给模型。
    /// 连敲 4 下会生气（不录音），这是「别烦我」的反馈。
    private func handleTap() {
        dismissComposerKeyboard()
        petAnimationTrigger &+= 1
        let now = Date().timeIntervalSinceReferenceDate
        let base = life.tap(at: now)

        expressionUntil = Date().addingTimeInterval(2.4 * PetLife.pace)

        // 连敲 → 生气 / 哭，不进录音
        if base == .angry {
            withAnimation(.easeOut(duration: 0.12 * PetLife.pace)) { expression = .angry }
            caption = "别敲了。"
            speakWithFace(caption, base: .angry)
            return
        }
        if base == .cry {
            withAnimation(.easeOut(duration: 0.12 * PetLife.pace)) { expression = .cry }
            caption = "……别敲了"
            speakWithFace(caption, base: .cry)
            return
        }

        // 正在听 → 结束并发送
        if phase == .listening {
            finishVoiceCapture()
            return
        }

        // 待机 → 给个反应，然后开始听
        let pick = life.randomReaction(roll: Double.random(in: 0...0.9999))
        withAnimation(.easeOut(duration: 0.15 * PetLife.pace)) { expression = pick.expression }
        caption = pick.text
        voiceVisible = true
        phase = .listening
    }

    // MARK: - 它自己的生活

    /// 切到后台 / 锁屏前，把这帧定格成「坐下打盹」。
    /// iOS 会挂起 App 不再推帧，这样冻住的画面看起来是在休息，而不是卡在待机。
    private func poseForFreeze() {
        PetActivityController.sync(mood: state.currentMood,
                                   glow: state.pet.look.glow,
                                   line: items.last?.text ?? "随时可以问我",
                                   title: "打盹",
                                   phase: "idle",
                                   walkTick: walkTick,
                                   action: "sit",
                                   tintHex: expression.eyeTintHex,
                                   posX: roamPos,
                                   eyeOpen: 0.32,
                                   headTilt: 15,
                                   enabled: true)
    }

    @MainActor
    private func lifeLoop() async {
        var last = Date()

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 650_000_000)

            let now = Date()
            guard scenePhase == .active, isVisible else {
                last = now
                continue
            }
            let dt = now.timeIntervalSince(last)
            last = now

            life.tick(dt)

            // 锁屏上的小人低频更新，降低后台能耗
            walkAccum += dt
            if walkAccum >= 4.2 {
                walkAccum = 0
                walkTick &+= 1

                // 缓慢靠近目标；到了就换一个新地方待着
                roamPos += (roamTarget - roamPos) * 0.34
                if abs(roamTarget - roamPos) < 0.05 || walkTick % 7 == 0 {
                    roamTarget = Double.random(in: 0.12...0.88)
                }

                pushIslandFrame()
            }

            // 到点了，自己做个动作
            if phase == .idle, !isSpeaking, now >= nextEventAt, now >= expressionUntil {
                let event = life.pickEvent(roll: Double.random(in: 0...0.999))
                expression = event.expression
                caption = event.text
                expressionUntil = now.addingTimeInterval(event.seconds * PetLife.pace)
                nextEventAt = now.addingTimeInterval(life.nextEventDelay(roll: Double.random(in: 0...1)))

                // 没人碰它的时候不出声——它自己动，但安静
                continue
            }

            // 表情到期，回到平静
            if now >= expressionUntil, !isSpeaking, expression != .calm {
                withAnimation(.easeOut(duration: 0.25 * PetLife.pace)) {
                    expression = .calm
                }
                caption = ""
            }
        }
    }

    // MARK: - 发出去

    /// 点发送：把输入栏里的字送出去
    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        send(text)
    }

    private func fetchIntelligence(
        module: IntelligenceModule,
        requestText: String,
        marketTerm: String? = nil
    ) {
        dismissComposerKeyboard()
        openChat()
        phase = .thinking
        thinkingTask?.cancel()

        items.append(ChatItem(mine: true, date: Date(), text: requestText, schedule: nil))
        ChatStore.append(ChatTurn(mine: true, text: requestText, date: Date()))

        thinkingTask = Task {
            if let marketTerm {
                do {
                    guard let quote = try await StockService.findQuote(matching: marketTerm) else {
                        await showIntelligenceMessage(
                            "没有找到「\(marketTerm)」对应的股票。可以试试公司简称或股票代码。",
                            expression: .sad
                        )
                        return
                    }
                    if Task.isCancelled { return }
                    let digest = IntelligenceDigest(
                        news: [],
                        market: [quote],
                        trends: [],
                        zhihu: [],
                        game: .empty(),
                        ai: [],
                        fetchedAt: Date(),
                        failures: [:]
                    )
                    let reply = "\(quote.name)（\(quote.code)）最新价格 \(StockDisplay.priceText(quote.price))，"
                        + "\(quote.changePercent >= 0 ? "涨" : "跌") \(String(format: "%.2f", abs(quote.changePercent)))%。"
                        + "公开行情可能延迟。"
                    await MainActor.run {
                        phase = .idle
                        appendIntelligence(digest, reply: reply, initialModule: .market)
                    }
                } catch {
                    await showIntelligenceMessage(
                        "股票行情暂时没拿到。我没有补造价格，稍后可以再试一次。",
                        expression: .sad
                    )
                }
                return
            }

            let digest = await IntelligenceService.load(force: true)
            if Task.isCancelled { return }

            if digest.isEmpty {
                await showIntelligenceMessage(
                    "几个信息源暂时都没连上。我没有补造内容，稍后可以再试一次。",
                    expression: .sad
                )
                return
            }

            let reply: String
            switch module {
            case .news:
                reply = "我把今天值得看的要闻、市场、热搜和 AI 动态放在一起了。"
            case .market:
                reply = "主要指数和你的自选股已经更新。公开行情可能延迟，不构成投资建议。"
            case .weibo:
                reply = "这是目前的微博热搜。点击标题可以在 Nomi 内继续查看。"
            case .zhihu:
                reply = "这是目前的知乎热榜，保留了热度和讨论入口。"
            case .game:
                reply = "我把游戏新闻、Steam 和手游榜单整理到了一起。"
            case .ai:
                reply = "这是最近的 AI 科技动态，保留了来源和发布时间。"
            }
            await MainActor.run {
                phase = .idle
                appendIntelligence(digest, reply: reply, initialModule: module)
            }
        }
    }

    @MainActor
    private func appendIntelligence(
        _ digest: IntelligenceDigest,
        reply: String,
        initialModule: IntelligenceModule = .news
    ) {
        items.append(ChatItem(mine: false, date: Date(), text: reply, schedule: nil))
        items.append(ChatItem(
            mine: false,
            date: Date(),
            text: nil,
            schedule: nil,
            intelligence: digest,
            intelligenceModule: initialModule
        ))
        rememberAssistant(reply)
        speakWithFace(reply, base: .calm)
        syncIsland(.idle)
    }

    @MainActor
    private func showIntelligenceMessage(
        _ reply: String,
        expression: PetExpression
    ) {
        items.append(ChatItem(mine: false, date: Date(), text: reply, schedule: nil))
        rememberAssistant(reply)
        phase = .idle
        speakWithFace(reply, base: expression)
        syncIsland(.idle)
    }

    private func send(_ text: String, keepVoiceOverlay: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        dismissComposerKeyboard()
        if !keepVoiceOverlay {
            voiceVisible = false
        }
        openChat()

        items.append(ChatItem(mine: true, date: Date(), text: trimmed, schedule: nil))
        ChatStore.append(ChatTurn(mine: true, text: trimmed, date: Date()))

        // 说了别的事：之前那条待确认的动作作废，别留着误导
        if pendingAction != nil || pendingTodo != nil {
            if let itemID = pendingItemID,
               let index = items.firstIndex(where: { $0.id == itemID }) {
                items[index].showConfirm = false
            }
            pendingAction = nil
            pendingTodo = nil
            pendingItemID = nil
            showConfirmSheet = false
        }

        // 刚问过「几点」：这句就是回答时间
        if pendingCreate {
            pendingCreate = false
            if ScheduleParser.parse(trimmed) != nil {
                createSchedule(from: trimmed)
                return
            }
        }

        // 分流交给 ChatRouter（纯逻辑，本地可测）：
        // 顺序是 城市天气 → 天气 → 位置 → 待办 → 取消 → 改期 → 新增 → 查日程 → 聊天
        switch ChatRouter.intent(for: trimmed, watchedCities: state.settings.watchedCities) {

        case .cityWeather(let name):
            if let city = state.settings.watchedCities.first(where: { $0.name == name }) {
                askWeather(for: city)
            } else {
                askWeather()
            }
            return

        case .weather:
            askWeather()
            return

        case .location:
            askLocation()
            return

        case .market(let term):
            fetchIntelligence(
                module: .market,
                requestText: trimmed,
                marketTerm: term
            )
            return

        case .weibo:
            fetchIntelligence(module: .weibo, requestText: trimmed)
            return

        case .zhihu:
            fetchIntelligence(module: .zhihu, requestText: trimmed)
            return

        case .game:
            fetchIntelligence(module: .game, requestText: trimmed)
            return

        case .news:
            fetchIntelligence(module: .news, requestText: trimmed)
            return

        case .intelligence:
            fetchIntelligence(module: .news, requestText: trimmed)
            return

        case .cancelSchedule:
            cancelSchedule(from: trimmed)
            return

        case .reschedule:
            if let move = ScheduleParser.parseMove(trimmed) {
                rescheduleSchedule(to: move, from: trimmed)
            }
            return

        case .music(let term):
            musicTerm = term ?? ""
            showMusic = true
            return

        case .createTodo(let title, let due):
            prepareCreateTodo(title: title, due: due)
            return

        case .queryTodo(let all):
            askTodos(all: all)
            return

        case .completeTodo(let query):
            prepareCompleteTodo(query: query)
            return

        case .createSchedule:
            createSchedule(from: trimmed)
            return

        case .schedule:
            askSchedule()
            return

        case .chat:
            break
        }

        phase = .thinking

        let context = AnswerEngine.Context(cards: state.cards,
                                           temperature: state.currentTemperature,
                                           now: Date(),
                                           stage: state.pet.stage)
        let key = Keychain.load("deepseek.key") ?? ""

        thinkingTask?.cancel()
        thinkingTask = Task {
            var reply: String

            var source = "模型"
            var failure: String?

            if key.isEmpty {
                reply = AnswerEngine.answer(to: trimmed, context: context)
                    + "（没填 key，这是本地回答）"
                source = "本地"
                failure = "钥匙串里没有 key"
            } else {
                do {
                    // 带上最近 12 轮，它才接得住上下文
                    let history = ChatStore.recentForModel()
                    reply = try await LLMClient(apiKey: key)
                        .chat(system: systemPrompt, history: history)
                } catch {
                    // 把原因写在回复里——不然用户只会觉得"傻"，不知道是没连上
                    failure = (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription
                    reply = AnswerEngine.answer(to: trimmed, context: context)
                        + "（模型没连上：\(failure ?? "未知")）"
                    source = "本地"
                }
            }

            ChatDiagnostics.record(source: source, error: failure, preview: reply)

            if Task.isCancelled { return }

            await MainActor.run {
                items.append(ChatItem(mine: false, date: Date(), text: reply, schedule: nil))
                ChatStore.append(ChatTurn(mine: false, text: reply, date: Date()))
                phase = .idle
                speakWithFace(reply, base: .calm)
                syncIsland(.idle)
            }
        }
    }

    @MainActor
    private func scheduleVoiceOverlayDismissal() {
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard phase == .idle, voiceVisible, !voiceIsActuallySpeaking else { return }
            withAnimation(.easeOut(duration: 0.20)) {
                voiceVisible = false
            }
        }
    }

    // MARK: - 意图

    private var cityName: String {
        state.locationFix?.cityName ?? state.settings.cityName
    }

    // MARK: - 取消 / 改期

    private var whenFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEE HH:mm"
        return formatter
    }

    /// 只在「用户点了时间」且确实有一场在附近时才返回。
    ///
    /// 之前找不到就回退到"下一场还没开始的"——用户说「取消四点的会」，
    /// 四点没有会，就会把五点那场删掉。这种猜测绝对不能有。
    private func pickTarget(from meetings: [MeetingItem], near target: Date?) -> MeetingItem? {
        guard let target else { return nil }

        return meetings
            .filter { abs($0.start.timeIntervalSince(target)) < 30 * 60 }
            .min { abs($0.start.timeIntervalSince(target)) < abs($1.start.timeIntervalSince(target)) }
    }

    /// 找不到时说清楚有哪些可选，让用户自己点
    private func nearestHint(from meetings: [MeetingItem], near target: Date?) -> String {
        let upcoming = meetings.filter { $0.start > Date() }.prefix(3)
        guard !upcoming.isEmpty else { return "这两天没有别的安排。" }

        let list = upcoming
            .map { "\(whenFormatter.string(from: $0.start)) \($0.title)" }
            .joined(separator: "、")

        let prefix = target == nil ? "你说哪个？" : "没找到那个时间的会。"
        return "\(prefix)现在有：\(list)"
    }

    /// 等确认的待办动作：新建和完成都要点一下才写系统
    struct PendingTodoAction {
        enum Kind { case create, complete }

        let kind: Kind
        let title: String
        let due: Date?

        var question: String {
            switch kind {
            case .create:
                if let due {
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "zh_CN")
                    formatter.dateFormat = "M月d日 EEE HH:mm"
                    return "要加这条待办吗？「\(title)」\(formatter.string(from: due))"
                }
                return "要加这条待办吗？「\(title)」，没设时间"
            case .complete:
                return "把「\(title)」标成完成吗？"
            }
        }
    }

    /// 追加一条它说的话，同时写进历史
    private func appendReply(_ text: String) {
        items.append(ChatItem(mine: false, date: Date(), text: text, schedule: nil))
        ChatStore.append(ChatTurn(mine: false, text: text, date: Date()))
    }

    // MARK: - 待办

    /// 说「加个待办」：先出确认卡，不直接写
    private func prepareCreateTodo(title: String, due: Date?) {
        let action = PendingTodoAction(kind: .create, title: title, due: due)
        pendingTodo = action

        var item = ChatItem(mine: false, date: Date(), text: action.question, schedule: nil)
        item.showConfirm = true
        items.append(item)
        ChatStore.append(ChatTurn(mine: false, text: action.question, date: Date()))
        pendingItemID = item.id
    }

    /// 说「牛奶那条做完了」：匹配到唯一一条才问，多就列出来
    private func prepareCompleteTodo(query: String) {
        guard CalendarService.hasReminderAccess else {
            Task {
                if await state.requestReminderAccess() {
                    prepareCompleteTodo(query: query)
                }
            }
            return
        }

        let matches = state.pendingTodos.filter { $0.title.contains(query) || query.contains($0.title) }

        guard let target = matches.first, matches.count == 1 else {
            let list = state.pendingTodos.prefix(5).map(\.title).joined(separator: "、")
            let reply = state.pendingTodos.isEmpty
                ? "现在没有未完成的待办。"
                : "你说的是哪条？现在有：\(list)"
            appendReply(reply)
            return
        }

        let action = PendingTodoAction(kind: .complete, title: target.title, due: target.due)
        pendingTodo = action

        var item = ChatItem(mine: false, date: Date(), text: action.question, schedule: nil)
        item.showConfirm = true
        items.append(item)
        ChatStore.append(ChatTurn(mine: false, text: action.question, date: Date()))
        pendingItemID = item.id
    }

    /// 说「今天还有什么没做」
    private func askTodos(all: Bool) {
        guard CalendarService.hasReminderAccess else {
            Task {
                if await state.requestReminderAccess() {
                    askTodos(all: all)
                }
            }
            return
        }

        let todos = state.pendingTodos
        guard !todos.isEmpty else {
            appendReply("没有未完成的待办，今天可以轻松点。")
            return
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"

        let shown = all ? todos : Array(todos.prefix(5))
        let lines = shown.map { todo -> String in
            if let due = todo.due {
                return "· \(todo.title)（\(formatter.string(from: due))）"
            }
            return "· \(todo.title)"
        }

        var reply = "还有 \(todos.count) 件没做：\n" + lines.joined(separator: "\n")
        if !all, todos.count > shown.count {
            reply += "\n…说「全部待办」看剩下的"
        }
        appendReply(reply)
    }

    /// 点了「确认」：待办才真正写系统
    private func confirmTodoAction() {
        guard let action = pendingTodo else { return }

        showConfirmSheet = false
        pendingTodo = nil
        let itemID = pendingItemID
        pendingItemID = nil

        if let itemID, let index = items.firstIndex(where: { $0.id == itemID }) {
            items[index].showConfirm = false
        }

        phase = .thinking

        Task { @MainActor in
            var reply: String

            switch action.kind {
            case .create:
                let done = await state.createTodo(title: action.title, due: action.due)
                reply = done
                    ? "已加：\(action.title)。说「今天还有什么没做」就能看到。"
                    : "没写进去——提醒事项权限可能没开，去设置里看一下。"

            case .complete:
                let target = state.pendingTodos.first { $0.title == action.title }
                var done = false
                if let target {
                    done = await state.completeTodo(id: target.id)
                }
                reply = done ? "已完成：\(action.title)。" : "没标成功，提醒事项权限可能没开。"
            }

            phase = .idle
            items.append(ChatItem(mine: false, date: Date(), text: reply, schedule: nil))
            ChatStore.append(ChatTurn(mine: false, text: reply, date: Date()))
            speakWithFace(reply, base: expression)
        }
    }

    /// 等确认的会议动作：取消和改期都不直接执行
    struct PendingMeetingAction {
        enum Kind: Equatable { case cancel, move }

        let kind: Kind
        let meetingID: String
        let title: String
        let start: Date
        let newStart: Date?

        var question: String {
            let formatted = whenFormatter
            switch kind {
            case .cancel:
                return "要取消「\(title)」吗？\(formatted.string(from: start))"
            case .move:
                let to = newStart.map { formatted.string(from: $0) } ?? "新时间"
                return "要把「\(title)」挪到 \(to) 吗？原来是 \(formatted.string(from: start))"
            }
        }

        private var whenFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日 EEE HH:mm"
            return formatter
        }
    }

    /// 点了「确认」才真的写日历
    private func confirmPendingAction() {
        guard let action = pendingAction else { return }

        showConfirmSheet = false
        pendingAction = nil
        let itemID = pendingItemID
        pendingItemID = nil

        if let itemID, let index = items.firstIndex(where: { $0.id == itemID }) {
            items[index].showConfirm = false
        }

        phase = .thinking

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEE HH:mm"

        Task {
            var reply = ""

            switch action.kind {
            case .cancel:
                let done = await CalendarService.deleteEvent(id: action.meetingID)
                reply = done
                    ? "取消了：\(action.title)，\(formatter.string(from: action.start))。"
                    : "没删掉，日历权限可能没给。"

            case .move:
                if let newStart = action.newStart {
                    let done = await CalendarService.moveEvent(id: action.meetingID, to: newStart)
                    reply = done
                        ? "改好了：\(action.title) 挪到了 \(formatter.string(from: newStart))。"
                        : "没改动，日历权限可能没给。"
                }
            }

            if Task.isCancelled { return }

            await MainActor.run {
                items.append(ChatItem(mine: false, date: Date(), text: reply, schedule: nil))
                rememberAssistant(reply)
                phase = .idle
                speakWithFace(reply, base: .calm)
                syncIsland(.idle)
            }

            await state.refresh()
        }
    }

    /// 点了「算了」
    private func dismissPendingAction() {
        showConfirmSheet = false
        pendingAction = nil
        pendingTodo = nil
        if let itemID = pendingItemID,
           let index = items.firstIndex(where: { $0.id == itemID }) {
            items[index].showConfirm = false
        }
        pendingItemID = nil

        let reply = "好，没动。"
        items.append(ChatItem(mine: false, date: Date(), text: reply, schedule: nil))
        rememberAssistant(reply)
    }

    private func cancelSchedule(from text: String) {
        phase = .thinking
        thinkingTask?.cancel()

        thinkingTask = Task {
            _ = await CalendarService.requestEventAccess()
            let candidates = await CalendarService.upcomingTwoDays()
            let targetTime = ScheduleParser.cancelTargetTime(text)

            guard let target = pickTarget(from: candidates, near: targetTime) else {
                await MainActor.run {
                    let reply = nearestHint(from: candidates, near: targetTime)
                    items.append(ChatItem(mine: false, date: Date(), text: reply, schedule: nil))
                    rememberAssistant(reply)
                    phase = .idle
                    speakWithFace(reply, base: .curious)
                    syncIsland(.idle)
                }
                return
            }

            // 不直接删：先问一句，等用户点确认
            let action = PendingMeetingAction(kind: .cancel,
                                              meetingID: target.id,
                                              title: target.title,
                                              start: target.start,
                                              newStart: nil)

            if Task.isCancelled { return }

            await MainActor.run {
                let bubble = ChatItem(mine: false, date: Date(),
                                      text: action.question, schedule: nil,
                                      showConfirm: true)
                items.append(bubble)
                pendingItemID = bubble.id
                pendingAction = action
                showConfirmSheet = true
                rememberAssistant(action.question)
                phase = .idle
                voice.speak(SpeechSanitizer.prepare(action.question), expression: .curious)
                syncIsland(.idle)
            }
        }
    }

    private func rescheduleSchedule(to move: ScheduleParser.MoveRequest, from text: String) {
        phase = .thinking
        thinkingTask?.cancel()

        thinkingTask = Task {
            _ = await CalendarService.requestEventAccess()
            let candidates = await CalendarService.upcomingTwoDays()

            guard let target = pickTarget(from: candidates, near: move.oldStart) else {
                await MainActor.run {
                    let reply = nearestHint(from: candidates, near: move.oldStart)
                    items.append(ChatItem(mine: false, date: Date(), text: reply, schedule: nil))
                    rememberAssistant(reply)
                    phase = .idle
                    speakWithFace(reply, base: .curious)
                    syncIsland(.idle)
                }
                return
            }

            let action = PendingMeetingAction(kind: .move,
                                              meetingID: target.id,
                                              title: target.title,
                                              start: target.start,
                                              newStart: move.newStart)

            if Task.isCancelled { return }

            await MainActor.run {
                let bubble = ChatItem(mine: false, date: Date(),
                                      text: action.question, schedule: nil,
                                      showConfirm: true)
                items.append(bubble)
                pendingItemID = bubble.id
                pendingAction = action
                showConfirmSheet = true
                rememberAssistant(action.question)
                phase = .idle
                voice.speak(SpeechSanitizer.prepare(action.question), expression: .curious)
                syncIsland(.idle)
            }
        }
    }

    // MARK: - 一句话新增日程

    private func createSchedule(from text: String) {
        phase = .thinking
        thinkingTask?.cancel()

        let now = Date()
        thinkingTask = Task {
            _ = await CalendarService.requestEventAccess()
            guard let parsed = ScheduleParser.parse(text, now: now) else {
                await MainActor.run {
                    let reply = "几点？说个时间，比如「明天下午三点」。"
                    items.append(ChatItem(mine: false, date: Date(),
                                          text: reply, schedule: nil))
                    rememberAssistant(reply)
                    pendingCreate = true
                    phase = .idle
                    voice.speak(reply, expression: .curious)
                    syncIsland(.idle)
                }
                return
            }

            let wrote = await CalendarService.addEvent(title: parsed.title,
                                                       start: parsed.start,
                                                       alarmMinutes: 10)

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日 EEE HH:mm"
            let when = formatter.string(from: parsed.start)

            let reply: String
            if wrote {
                reply = "记下了：\(when)，\(parsed.title)。提前 10 分钟提醒你。"
            } else {
                reply = "写不进日历，看看设置里日历权限给没给。"
            }

            if Task.isCancelled { return }

            await MainActor.run {
                items.append(ChatItem(mine: false, date: Date(), text: reply, schedule: nil))
                rememberAssistant(reply)
                phase = .idle
                speakWithFace(reply, base: wrote ? .happy : .sad)
                syncIsland(.idle)
            }

            if wrote {
                await state.refresh()
            }
        }
    }

    // MARK: - 三种卡片

    private func askSchedule() {
        phase = .thinking
        thinkingTask?.cancel()
        thinkingTask = Task {
            _ = await CalendarService.requestEventAccess()
            let today = await CalendarService.meetings(on: Date())
            let tomorrowDay = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let tomorrow = await CalendarService.meetings(on: tomorrowDay)

            if Task.isCancelled { return }

            let payload = SchedulePayload(today: today, tomorrow: tomorrow)
            let template = scheduleLead(today: today)

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "HH:mm"

            var factLines: [String] = ["今天是 \(formatter.string(from: Date())) 前后"]
            if today.isEmpty {
                factLines.append("今天没有安排")
            } else {
                factLines.append("今天有 \(today.count) 件事：")
                for item in today {
                    factLines.append("- \(formatter.string(from: item.start)) \(item.title)")
                }
            }
            factLines.append("明天有 \(tomorrow.count) 件事")

            let lead = await narrate(facts: factLines.joined(separator: "\n"), fallback: template)
            if Task.isCancelled { return }

            await MainActor.run {
                items.append(ChatItem(mine: false, date: Date(), text: lead, schedule: nil))
                rememberAssistant(lead)
                items.append(ChatItem(mine: false, date: Date(), text: nil, schedule: payload))
                phase = .idle
                syncIsland(.idle)
            }
        }
    }

    private func scheduleLead(today: [MeetingItem]) -> String {
        if today.isEmpty {
            return "今天没有安排。明天我也整理好了。"
        }
        let first = today[0]
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "今天 \(today.count) 项，最近的是 \(formatter.string(from: first.start)) 的\(first.title)。"
    }

    /// city 传了就查那个城市，不传就用当前位置/设置城市
    private func askWeather(for city: WatchedCity? = nil) {
        phase = .thinking
        thinkingTask?.cancel()
        thinkingTask = Task {
            var weather: Weather?
            var cityName = city?.name ?? ""

            if let city {
                weather = try? await WeatherService(latitude: city.latitude,
                                                    longitude: city.longitude).load()
            } else {
                weather = state.weatherNow
                if weather == nil {
                    let lat = state.locationFix?.latitude ?? state.settings.latitude
                    let lon = state.locationFix?.longitude ?? state.settings.longitude
                    weather = try? await WeatherService(latitude: lat, longitude: lon).load()
                }
                cityName = state.locationFix?.cityName ?? state.settings.cityName
            }

            guard !Task.isCancelled else { return }

            guard let w = weather else {
                await MainActor.run {
                    items.append(ChatItem(mine: false, date: Date(),
                                          text: "天气没拿到，等会儿再问。", schedule: nil))
                    phase = .idle
                    syncIsland(.idle)
                }
                return
            }

            let prefix = cityName.isEmpty ? "" : "\(cityName)："
            let template = "\(prefix)现在 \(Int(w.currentTemperature.rounded()))°，\(WeatherCode.text(w.weatherCode))。今天 \(Int(w.todayMin.rounded()))° 到 \(Int(w.todayMax.rounded()))°。"

            let rainChance = w.hours
                .filter { $0.time > Date() && $0.time.timeIntervalSince(Date()) < 6 * 3600 }
                .map { $0.precipitationProbability }
                .max() ?? 0
            let cloth = ClothingAdvice.advice(maxTemp: w.todayMax,
                                             minTemp: w.todayMin,
                                             weatherCode: w.weatherCode,
                                             rainChance: rainChance,
                                             windKmh: w.windSpeed)

            let facts = """
            \(cityName.isEmpty ? "当前位置" : cityName)
            现在 \(Int(w.currentTemperature.rounded()))°，\(WeatherCode.text(w.weatherCode))
            今天 \(Int(w.todayMin.rounded()))° 到 \(Int(w.todayMax.rounded()))°
            体感 \(Int(w.feelsLike.rounded()))°，湿度 \(Int(w.humidity.rounded()))%，风 \(Int(w.windSpeed.rounded())) 公里每小时
            未来 6 小时降水概率最高 \(Int(rainChance.rounded()))%
            """

            let lead = await narrate(facts: facts, fallback: template)
            if Task.isCancelled { return }

            await MainActor.run {
                items.append(ChatItem(mine: false, date: Date(), text: lead, schedule: nil))
                rememberAssistant(lead)
                items.append(ChatItem(mine: false, date: Date(), text: nil, schedule: nil, weather: w))
                // 穿衣建议单独一句，卡片里也有
                items.append(ChatItem(mine: false, date: Date(),
                                      text: "穿：\(cloth)", schedule: nil))
                rememberAssistant("穿：" + cloth)
                phase = .idle
                syncIsland(.idle)
            }
        }
    }

    private func askLocation() {
        phase = .thinking
        thinkingTask?.cancel()
        thinkingTask = Task {
            var fix = state.locationFix
            if fix == nil {
                fix = await state.requestLocationNow()
            }

            guard !Task.isCancelled else { return }

            guard let f = fix else {
                await MainActor.run {
                    items.append(ChatItem(mine: false, date: Date(),
                                          text: "拿不到位置，检查一下定位授权。", schedule: nil))
                    phase = .idle
                    syncIsland(.idle)
                }
                return
            }

            let template = "你现在在「\(f.fullAddress)」，定位精度约 \(Int(f.horizontalAccuracy.rounded())) 米。"
            let facts = """
            地址：\(f.fullAddress)
            定位精度：约 \(Int(f.horizontalAccuracy.rounded())) 米
            城市：\(f.cityName.flatMap { $0.isEmpty ? nil : $0 } ?? "不确定")
            """
            let lead = await narrate(facts: facts, fallback: template)
            if Task.isCancelled { return }

            await MainActor.run {
                items.append(ChatItem(mine: false, date: Date(), text: lead, schedule: nil))
                rememberAssistant(lead)
                items.append(ChatItem(mine: false, date: Date(), text: nil, schedule: nil, location: f))
                phase = .idle
                syncIsland(.idle)
            }
        }
    }

    // MARK: - 天气详情

    private var weatherDetail: some View {
        NavigationStack {
            ScrollView {
                if let w = state.weatherNow {
                    WeatherCardView(weather: w, city: cityName, pm25: state.airPM25, onTap: {})
                        .padding(20)
                } else {
                    weatherUnavailableDetail
                        .padding(20)
                }
            }
            .background(CardPalette.screen)
            .navigationTitle("天气")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { showWeatherDetail = false }
                }
            }
        }
        .preferredColorScheme(state.settings.appearance.colorScheme)
    }

    private var weatherUnavailableDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "cloud.slash")
                .font(.nomiScaled(size: 34, weight: .medium))
                .foregroundColor(CardPalette.amber)

            VStack(alignment: .leading, spacing: 7) {
                Text("天气暂时没有更新")
                    .font(.nomiScaled(size: 24, weight: .bold))
                    .foregroundColor(CardPalette.ink)
                Text(degradeDetail)
                    .font(.nomiScaled(size: 14))
                    .foregroundColor(CardPalette.subtle)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 9) {
                if state.canRequestLocation {
                    Button("允许定位并按当前位置更新") {
                        requestLocationAndRefresh()
                    }
                    .buttonStyle(WhalePressStyle())
                    .foregroundColor(CardPalette.navyInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(CardPalette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                } else if state.locationPermissionDenied {
                    Button("去系统设置开启定位") {
                        openSystemSettings()
                    }
                    .buttonStyle(WhalePressStyle())
                    .foregroundColor(CardPalette.navyInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(CardPalette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }

                Button("用设置城市「\(state.settings.cityName)」重试") {
                    Task { await state.refresh(useCurrentLocation: false) }
                }
                .font(.nomiScaled(size: 14, weight: .semibold))
                .foregroundColor(CardPalette.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }

            Text("日程、待办和对话不依赖天气，仍可正常使用。")
                .font(.nomiScaled(size: 12))
                .foregroundColor(CardPalette.subtle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func requestLocationAndRefresh() {
        Task {
            _ = await state.requestLocationAccess()
            await state.refresh()
        }
    }

    // MARK: - 灵动岛

    /// 锁屏事件卡要用的字段：取最近一场还没结束的日程
    private var islandEvent: (title: String, place: String, time: String,
                              countdown: String, hint: String, kind: String, id: String) {
        let now = Date()
        let next = state.meetings.first { ($0.end ?? $0.start) > now }
            ?? state.meetings.first { $0.start > now }

        guard let event = next else {
            return ("", "", "", "", "", "idle", "")
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"

        var time = formatter.string(from: event.start)
        if let end = event.end {
            time += "–" + formatter.string(from: end)
        }

        let seconds = event.start.timeIntervalSince(now)
        let countdown: String
        let kind: String

        if seconds <= 0 {
            countdown = "进行中"
            kind = "now"
        } else {
            let minutes = Int(seconds / 60)
            countdown = minutes < 60 ? "\(minutes) 分钟后" : "\(minutes / 60) 小时后"
            kind = minutes <= 10 ? "soon" : "upcoming"
        }

        let hint = event.location?.isEmpty == false
            ? "在 \(event.location!)。要出发就点下面。"
            : "点下面看看要准备什么。"

        return (event.title, event.location ?? "", time, countdown, hint, kind, event.id)
    }

    private func syncIsland(_ phase: Phase) {
        let title: String
        let key: String

        switch phase {
        case .idle:      title = expression.statusWord; key = "idle"
        case .listening: title = "在听"; key = "listening"
        case .thinking:  title = "在想"; key = "thinking"
        }

        PetActivityController.sync(mood: state.currentMood,
                                   glow: state.pet.look.glow,
                                   line: items.last?.text ?? "随时可以问我",
                                   title: title,
                                   phase: key,
                                   walkTick: walkTick,
                                   action: islandNow.action,
                                   tintHex: expression.eyeTintHex,
                                   posX: roamPos,
                                   eyeOpen: islandNow.eyeOpen,
                                   headTilt: islandNow.headTilt,
                                   eventTitle: islandEvent.title,
                                   eventPlace: islandEvent.place,
                                   eventTime: islandEvent.time,
                                   countdown: islandEvent.countdown,
                                   eventHint: islandEvent.hint,
                                   eventKind: islandEvent.kind,
                                   eventID: islandEvent.id,
                                   enabled: true)
    }

    /// 锁屏上的一个姿态：动作 + 脑袋倾斜 + 眼皮，持续几个 tick
    private struct IslandPose {
        let action: String
        let headTilt: Double
        let eyeOpen: Double
        let ticks: Int
    }

    /// 它的"家常行为"循环。总长 21 tick ≈ 19 秒转一圈。
    /// 不是随机抖动——是有节奏地溜达、停下来、耷拉脑袋、慢慢爬。
    private let islandBehaviors: [IslandPose] = [
        IslandPose(action: "walk",  headTilt: 0,   eyeOpen: 1.0,  ticks: 6),  // 溜达
        IslandPose(action: "idle",  headTilt: 0,   eyeOpen: 1.0,  ticks: 2),  // 停下张望
        IslandPose(action: "sit",   headTilt: 16,  eyeOpen: 0.45, ticks: 5),  // 坐下耷拉脑袋
        IslandPose(action: "crawl", headTilt: 8,   eyeOpen: 0.80, ticks: 5),  // 慢慢爬
        IslandPose(action: "idle",  headTilt: -6,  eyeOpen: 0.90, ticks: 3)   // 抬头看看
    ]

    private var islandPose: IslandPose {
        let total = islandBehaviors.reduce(0) { $0 + $1.ticks }
        guard total > 0 else {
            return IslandPose(action: "idle", headTilt: 0, eyeOpen: 1, ticks: 1)
        }

        var index = walkTick % total
        for pose in islandBehaviors {
            if index < pose.ticks { return pose }
            index -= pose.ticks
        }
        return islandBehaviors[0]
    }

    /// 当前该推什么：说话时不表演动作，空闲时走行为循环
    private var islandNow: (action: String, headTilt: Double, eyeOpen: Double) {
        if phase != .idle { return ("idle", 0, 1.0) }

        let pose = islandPose
        // 跟它当下的表情取更小的开合：打盹时即使循环里睁着，也眯着
        return (pose.action, pose.headTilt, min(pose.eyeOpen, expression.eyeOpen))
    }


    /// 低频推一帧：锁屏上的小人靠这个缓慢移动
    private func pushIslandFrame() {
        guard phase == .idle else { return }
        syncIsland(.idle)
    }

    private var systemPrompt: String {
        var parts: [String] = []

        // ① 身份：必须让它知道自己跑在什么模型上，否则被问就会否认
        parts.append("你是 Nomi，一个住在用户手机里的助理宠物，只有眼睛没有嘴。" +
                     "你由 DeepSeek 的 deepseek-chat 模型驱动，App 通过 API 调用你来回答。")
        parts.append("用户问「你是不是接了 DeepSeek / 你是什么模型」时，照实说：是，我跑在 DeepSeek deepseek-chat 上。" +
                     "不要说自己没接、也不要说是别的模型。")

        parts.append("语气规则：用「我」「你」，口语。一般讲两句，别只丢一句就完；用户要求解释时可以多讲。")
        parts.append("这是要念出来的话，所以：不要用列表、编号、括号、星号；不要「首先/其次/综上」；" +
                     "时间说成「三点」「三点十分」，不要写 15:00；数字直接写阿拉伯数字就行。")
        parts.append("不说教、不评价用户；不用「建议您」「温馨提示」「综上」这类词；不用表情符号。")

        // ② 能力清单：说清它真的能做什么，避免它把"我不知道"当成"我做不到"
        parts.append("你的 App 已经给你打开了这些能力，你可以照实告诉用户你能做：")
        parts.append("- 看日历：今天、明天的安排")
        parts.append("- 加日程：用户说「时间 + 事情」，App 会写进系统日历并设提前提醒")
        parts.append("- 改期、取消日程")
        parts.append("- 天气：现在温度、今天最高最低、未来三天、体感、湿度、风；也能查关注的城市（比如「北京天气」）")
        parts.append("- 穿衣建议：按温度、温差、雨雪、风给一句建议")
        parts.append("- 位置：当前在哪、打开高德；步数；待办数量")
        parts.append("- 提醒：下雨、就寝、早报、会前 10 分钟、久坐（都是本机通知）")

        // ③ 数据边界：区分"有数据"和"没能力"
        parts.append("天气、日程、位置、步数这些数据，App 已经把当前值写在下面了，直接用。" +
                     "如果下面某一项没出现（比如没开定位），就说这次没拿到，不要说「我没有这个能力」。")
        parts.append("可以编的边界只有两条：具体数字用下面给的、别自己猜；" +
                     "别的 App 里的东西（微信、支付宝、相册）你拿不到，被问就直说拿不到。")
        parts.append("除此之外的问题——常识、解释、建议、闲聊——正常回答，可以推理，可以有自己的看法，不要假装不知道。")

        // 日期时间放进上下文，它才分得清「明天」「下周三」
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE HH:mm"
        parts.append("现在是 \(formatter.string(from: Date()))。")

        // 固定偏好：称呼、作息、常用城市
        if !state.settings.nickname.isEmpty {
            parts.append("用户的称呼是「\(state.settings.nickname)」，叫他这个，不要叫「用户」。")
        }
        let profileNote = state.settings.profileNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !profileNote.isEmpty {
            parts.append("用户填写的个人介绍：\(profileNote)。这是用户主动提供的信息，可用来理解他的称呼和偏好。")
        }
        parts.append("用户的作息：\(state.settings.wakeHour) 点起床，\(state.settings.bedtimeHour) 点睡觉。")
        if !state.settings.cityName.isEmpty {
            parts.append("用户常在 \(state.settings.cityName)。")
        }

        if state.cards.isEmpty {
            parts.append("用户的日历：今天没有安排。")
        } else {
            parts.append("用户的日历：")
            for card in state.cards {
                parts.append("- \(card.time) \(card.fact)；\(card.advice)")
            }
        }

        if let temp = state.currentTemperature {
            parts.append("现在气温 \(Int(temp.rounded())) 度。")
        }
        parts.append("你现在的状态：\(state.pet.stage.title)。")
        return parts.joined(separator: "\n")
    }
}

private struct MiniVinylStatusIcon: View {
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 15.0,
            paused: !isPlaying || reduceMotion
        )) { context in
            disc(angle: discAngle(at: context.date))
        }
    }

    private func discAngle(at date: Date) -> Double {
        guard isPlaying, !reduceMotion else { return 0 }
        let seconds = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: 4.2)
        return seconds / 4.2 * 360
    }

    private func disc(angle: Double) -> some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.055))
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.6)
                    .padding(4 + CGFloat(index) * 3)
            }
            Circle()
                .fill(CardPalette.accent)
                .frame(width: 9, height: 9)
            Circle()
                .fill(Color.black.opacity(0.8))
                .frame(width: 2.5, height: 2.5)
        }
        .frame(width: 30, height: 30)
        .rotationEffect(.degrees(angle))
    }
}
