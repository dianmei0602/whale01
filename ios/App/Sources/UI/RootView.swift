import SwiftUI
import UIKit
import Combine

/// 底部主导航：对话、值得知道、待办；设置收进首页右上角。
struct RootView: View {
    @Environment(AppState.self) private var state

    enum Tab: String, CaseIterable, Identifiable, Hashable {
        case assistant
        case intelligence
        case records
        case settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .assistant: return "对话"
            case .intelligence: return "值得知道"
            case .records: return "待办"
            case .settings: return "设置"
            }
        }

        var symbol: String {
            switch self {
            case .assistant: return "bubble.left.and.bubble.right"
            case .intelligence: return "newspaper"
            case .records: return "checklist"
            case .settings: return "gearshape"
            }
        }

        var selectedSymbol: String {
            switch self {
            case .assistant: return "bubble.left.and.bubble.right.fill"
            case .intelligence: return "newspaper.fill"
            case .records: return "checklist.checked"
            case .settings: return "gearshape.fill"
            }
        }

        static let primaryCases: [Tab] = [.assistant, .intelligence, .records]
    }

    @State private var tab: Tab = .assistant
    @State private var showAssistantChat = false
    @State private var voiceVisible = false
    @State private var keyboardVisible = false
    @State private var pendingDraft = ""
    @State private var settingsPath = NavigationPath()
    @State private var recordsResetToken = 0
    @State private var settingsResetToken = 0
    @State private var tabReselectTick = 0
    @State private var intelligenceModule: IntelligenceModule = .news
    @State private var eventID: String?
    @State private var eventRequest = 0
    @GestureState private var pageDragOffset: CGFloat = 0
    @Namespace private var tabSelection

    var body: some View {
        ZStack {
            AppBackground()

            GeometryReader { geo in
                HStack(spacing: 0) {
                    AssistantView(
                        showingChat: $showAssistantChat,
                        voiceVisible: $voiceVisible,
                        isVisible: tab == .assistant,
                        onOpenSettings: { select(.settings) },
                        onOpenIntelligence: openIntelligence,
                        initialDraft: pendingDraft
                    )
                    .frame(width: geo.size.width, height: geo.size.height)

                    IntelligenceTabView(initialModule: $intelligenceModule)
                        .frame(width: geo.size.width, height: geo.size.height)

                    RecordsView(
                        onOpenAssistant: {
                            showAssistantChat = false
                            select(.assistant)
                        },
                        resetToken: recordsResetToken,
                        requestedEventID: eventID,
                        eventRequest: eventRequest
                    )
                    .frame(width: geo.size.width, height: geo.size.height)

                    SettingsTabView(
                        path: $settingsPath,
                        resetToken: settingsResetToken,
                        onClose: { select(.assistant) }
                    )
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(
                    width: geo.size.width * CGFloat(Tab.allCases.count),
                    height: geo.size.height,
                    alignment: .leading
                )
                .offset(x: -CGFloat(tabIndex) * geo.size.width + pageDragOffset)
                .animation(.spring(response: 0.40, dampingFraction: 0.86), value: tab)
                .clipped()
                .simultaneousGesture(interactivePageGesture(width: geo.size.width))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !keyboardVisible && !voiceVisible && tab != .settings {
                tabBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.20), value: keyboardVisible)
        .preferredColorScheme(state.settings.appearance.colorScheme)
        .task {
            await state.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .onChange(of: tab) { _, newValue in
            if newValue != .assistant {
                voiceVisible = false
                state.suspendFaceFollow()
            }
        }
        .onOpenURL(perform: handleDeepLink)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.primaryCases) { item in
                Button {
                    select(item, reselect: true)
                } label: {
                    VStack(spacing: 3) {
                        ZStack {
                            if item == .assistant {
                                NomiAvatar(size: 21, expression: tab == item ? .happy : .calm)
                                    .opacity(tab == item ? 1 : 0.72)
                            } else {
                                Image(systemName: tab == item ? item.selectedSymbol : item.symbol)
                                    .font(.nomiScaled(size: 18, weight: .semibold))
                            }
                        }
                        .frame(width: 27, height: 27)

                        Text(item.title)
                            .font(.nomiScaled(size: 10.5, weight: tab == item ? .semibold : .medium))
                    }
                    .foregroundStyle(tab == item ? CardPalette.accent : CardPalette.faint)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 54)
                    .background {
                        if tab == item {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(CardPalette.accent.opacity(0.10))
                                .matchedGeometryEffect(id: "selected-tab", in: tabSelection)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(WhalePressStyle(scale: 0.95))
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(CardPalette.tabbar)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(CardPalette.lineStrong, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.10), radius: 10, y: 4)
        .padding(.horizontal, 14)
        .padding(.bottom, 7)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: tab)
        .opacity(voiceVisible ? 0 : 1)
        .allowsHitTesting(!voiceVisible)
        .animation(.easeOut(duration: 0.18), value: voiceVisible)
        .sensoryFeedback(.selection, trigger: tab)
        .sensoryFeedback(.selection, trigger: tabReselectTick)
    }

    private func select(_ item: Tab, reselect: Bool = false) {
        if tab == item, reselect {
            switch item {
            case .assistant:
                showAssistantChat = false
            case .intelligence:
                intelligenceModule = .news
            case .records:
                recordsResetToken &+= 1
            case .settings:
                if settingsPath.isEmpty {
                    settingsResetToken &+= 1
                } else {
                    withAnimation(.easeOut(duration: 0.22)) {
                        settingsPath = NavigationPath()
                    }
                }
            }
            tabReselectTick &+= 1
            return
        }

        withAnimation(.spring(response: 0.40, dampingFraction: 0.86)) {
            tab = item
        }
    }

    private var tabIndex: Int {
        Tab.allCases.firstIndex(of: tab) ?? 0
    }

    /// 页面跟手横移，松手后吸附；对话和语音状态下完全让出横向手势。
    private func interactivePageGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($pageDragOffset) { value, offset, _ in
                guard !showAssistantChat, !voiceVisible, tab != .settings,
                      !(tab == .settings && !settingsPath.isEmpty),
                      abs(value.translation.width) > abs(value.translation.height)
                else { return }

                let movingRight = value.translation.width > 0
                let canMove = (movingRight && tab != .assistant)
                    || (!movingRight && tab != .settings)
                offset = canMove
                    ? value.translation.width
                    : value.translation.width * 0.18
            }
            .onEnded { value in
                guard !showAssistantChat, !voiceVisible, tab != .settings else { return }
                guard !(tab == .settings && !settingsPath.isEmpty) else { return }
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > max(56, width * 0.16),
                      abs(horizontal) > abs(vertical) * 1.25
                else { return }

                switch tab {
                case .assistant where horizontal < 0:
                    select(.intelligence)
                case .intelligence where horizontal < 0:
                    select(.records)
                case .records where horizontal > 0:
                    select(.intelligence)
                case .intelligence where horizontal > 0:
                    select(.assistant)
                default:
                    break
                }
            }
    }

    private func openIntelligence(_ module: IntelligenceModule) {
        intelligenceModule = module
        select(.intelligence)
    }

    private func handleDeepLink(_ url: URL) {
        switch DeepLinkRoute.parse(url) {
        case .settings:
            select(.settings)
        case .privacy:
            select(.settings)
            settingsPath = NavigationPath([SettingsRoute.privacy])

        case .today:
            showAssistantChat = false
            select(.records)
        case .event(let id):
            select(.records)
            eventID = id
            eventRequest &+= 1

        case .chat:
            showAssistantChat = true
            select(.assistant)

        case .prepare(let id):
            let title = state.meetings.first { $0.id == id }?.title ?? "接下来的事"
            pendingDraft = "帮我准备一下「\(title)」"
            showAssistantChat = true
            select(.assistant)

        case .confirm(_):
            showAssistantChat = true
            select(.assistant)

        case .home:
            showAssistantChat = false
            select(.assistant)
        }
    }
}
