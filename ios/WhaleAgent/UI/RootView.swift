import Combine
import SwiftUI
import UIKit

@MainActor
struct RootView: View {
    @StateObject private var model = AppModel()
    @StateObject private var keyboard = KeyboardObserver()
    @StateObject private var theme = ThemeManager.shared
    @State private var page = NavigationHabits.restoredTab(UserDefaults.standard.string(forKey: "whale.root.tab"))
    @State private var showRecords = false
    @State private var showSettings = false
    @State private var settingsDetailOpen = false
    @State private var composerDraft = ""
    @State private var composerFocused = false
    @AppStorage("whale.discover.selectedChannel") private var discoverChannel: DiscoverChannel = .ai
    @AppStorage("whale.appearance") private var appearance = "system"
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var systemTextSize

    var body: some View {
        Group {
            tabContent
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomChrome }
            .tint(WhaleTheme.accent)
            .preferredColorScheme(colorScheme)
            .dynamicTypeSize(preferredTextSize)
            .sheet(item: $model.presentedConfirmation) { item in ConfirmationSheet(model: model, item: item) }
            .sheet(isPresented: $showRecords) { RecordsView(model: model, showsClose: true, onClose: { showRecords = false }) }
            .sheet(isPresented: $showSettings) {
                SettingsView(model: model, isDetailOpen: $settingsDetailOpen, onBackToChat: { showSettings = false })
                    .presentationDragIndicator(.visible)
            }
        }
        // 样式切换时重建整棵子树，让所有 WhaleTheme 计算属性取到新 Token。
        // 外观（系统/浅/深）不需要这里参与：动态色随系统自动更新。
        .id(theme.style)
        .environmentObject(theme)
        .environmentObject(model.speech)
        .task {
#if DEBUG
            let environment = ProcessInfo.processInfo.environment
            if let raw = environment["WHALE_DEMO_INITIAL_CHANNEL"], let channel = DiscoverChannel(rawValue: raw) { discoverChannel = channel }
            if environment["WHALE_DEMO_HOME"] == "1" || environment["WHALE_DEMO_WEATHER"] == "1" { page = .conversation }
            if environment["WHALE_DEMO_TODO"] == "1" { page = .records }
            if environment["WHALE_DEMO_HUB"] == "1" { page = .discover }
            if environment["WHALE_DEMO_SETTINGS"] == "1" { showSettings = true }
            if environment["WHALE_DEMO_DISCOVER"] == "1" { openDiscover(.market) }
            if environment["WHALE_DEMO_GAME"] == "1" { openDiscover(.game) }
            if let raw = environment["WHALE_DEMO_CHANNEL"], let channel = DiscoverChannel(rawValue: raw) { openDiscover(channel) }
#endif
            await model.health()
            await model.reconcileUnknownWrites()
            await model.flushResultOutbox()
            await model.resumeActiveTurnIfNeeded()
            model.refreshPermissions()
            await model.refreshDashboard(force: true)
            await model.drainSharedInbox()
        }
        .onOpenURL { url in Task { await model.handleSharedURL(url) } }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await model.flushResultOutbox(); await model.drainSharedInbox() }
        }
        .onChange(of: page) { _, tab in
            UserDefaults.standard.set(tab.rawValue, forKey: "whale.root.tab")
            composerFocused = false
            UISelectionFeedbackGenerator().selectionChanged()
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .whaleOpenChat)) { _ in
            showRecords = false; showSettings = false; page = .conversation
        }
    }

    private var tabContent: some View {
        RootTabContent(
            page: $page,
            discoverChannel: $discoverChannel,
            model: model,
            onOpenRecords: { showRecords = true },
            onOpenSettings: { showSettings = true },
            onOpenMusic: { openDiscover(.music) },
            onOpenTodo: { move(to: .records) },
            onOpenDiscover: { openDiscover($0) },
            onMove: { move(to: $0) }
        )
    }

    /// Composer and tabs share one bottom inset. This avoids nested safe-area
    /// insets placing the composer underneath the tab bar. While the keyboard
    /// is present the tab bar yields its space to the composer.
    @ViewBuilder
    private var bottomChrome: some View {
        VStack(spacing: 0) {
            if page == .conversation {
                ConversationComposerBar(model: model, externalFocused: $composerFocused, draft: $composerDraft)
            }
            if RootBottomChromePolicy.tabBarVisible(
                page: page,
                composerFocused: composerFocused,
                keyboardVisible: keyboard.isVisible
            ) {
                WhaleRootTabBar(selection: $page)
            }
        }
    }

    private func move(to tab: AppTab) {
        guard tab != page else { return }
        page = tab
    }

    private func openDiscover(_ channel: DiscoverChannel) {
        discoverChannel = channel
        move(to: .discover)
    }
    private var colorScheme: ColorScheme? {
        appearance == "light" ? .light : appearance == "dark" ? .dark : nil
    }
    private var preferredTextSize: DynamicTypeSize {
#if DEBUG
        if ProcessInfo.processInfo.environment["WHALE_DEMO_LARGE_TEXT"] == "1" { return .accessibility3 }
#endif
        return systemTextSize
    }
}

/// iOS bottom tabs switch the selected page directly. Hidden pages stay mounted
/// so drafts, scroll positions and in-flight work survive tab changes.
private struct RootTabContent: View {
    @Binding var page: AppTab
    @Binding var discoverChannel: DiscoverChannel
    @ObservedObject var model: AppModel
    let onOpenRecords: () -> Void
    let onOpenSettings: () -> Void
    let onOpenMusic: () -> Void
    let onOpenTodo: () -> Void
    let onOpenDiscover: (DiscoverChannel) -> Void
    let onMove: (AppTab) -> Void

    var body: some View {
        ZStack {
            conversationPage
                .opacity(page == .conversation ? 1 : 0)
                .allowsHitTesting(page == .conversation)
                .accessibilityHidden(page != .conversation)
                .zIndex(page == .conversation ? 1 : 0)
            discoverPage
                .opacity(page == .discover ? 1 : 0)
                .allowsHitTesting(page == .discover)
                .accessibilityHidden(page != .discover)
                .zIndex(page == .discover ? 1 : 0)
            recordsPage
                .opacity(page == .records ? 1 : 0)
                .allowsHitTesting(page == .records)
                .accessibilityHidden(page != .records)
                .zIndex(page == .records ? 1 : 0)
        }
    }

    private var conversationPage: some View {
        ConversationTabView(
            model: model,
            bottomInset: 0,
            onOpenRecords: onOpenRecords,
            onOpenSettings: onOpenSettings,
            onOpenMusic: onOpenMusic,
            onOpenTodo: onOpenTodo,
            onOpenDiscover: onOpenDiscover
        )
    }

    private var discoverPage: some View {
        DiscoverView(
            selection: $discoverChannel,
            appModel: model,
            onSettings: onOpenSettings
        )
    }

    private var recordsPage: some View {
        TodoView(model: model, embedded: true, onBackToChat: { onMove(.conversation) }, bottomBarInset: 0)
    }
}

enum RootBottomChromePolicy {
    static func tabBarVisible(
        page: AppTab,
        composerFocused: Bool,
        keyboardVisible: Bool
    ) -> Bool {
        guard !keyboardVisible else { return false }
        return page != .conversation || !composerFocused
    }
}

/// Opaque bottom bar using direct iOS tab selection.
struct WhaleRootTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            item(.conversation, title: "助手", icon: "bubble.left.and.bubble.right")
            item(.discover, title: "发现", icon: "square.grid.2x2")
            item(.records, title: "待办", icon: "checklist")
        }
        .padding(.top, 7)
        .padding(.bottom, 1)
        .background(WhaleTheme.chrome)
        .overlay(alignment: .top) {
            Rectangle().fill(WhaleTheme.line.opacity(0.7)).frame(height: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("root-tab-bar")
    }

    private func item(_ tab: AppTab, title: String, icon: String) -> some View {
        let selected = selection == tab
        return Button {
            guard selection != tab else { return }
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .symbolVariant(selected ? .fill : .none)
                Text(title)
                    .font(.system(size: 10.5, weight: selected ? .semibold : .medium))
            }
            .foregroundStyle(selected ? WhaleTheme.accent : WhaleTheme.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.whalePress)
        .accessibilityLabel(title)
        .accessibilityIdentifier("tab-" + tab.rawValue)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ConfirmationSheet: View {
    @ObservedObject var model: AppModel
    let item: PendingTool
    @State private var calendarPreview: CalendarWritePreview?
    @State private var previewError: String?
    @State private var checkingPreview = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        WhaleIconTile(systemName: ToolPresentation.icon(item.tool), size: 50)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ToolPresentation.title(item.tool))
                                .font(.headline)
                                .foregroundStyle(WhaleTheme.ink)
                            Text("执行前确认")
                                .font(.caption)
                                .foregroundStyle(WhaleTheme.muted)
                        }
                    }

                    Text(ToolPresentation.detail(for: item))
                        .whaleFont(size: 17, weight: .medium)
                        .foregroundStyle(WhaleTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .whaleCard()

                    if checkingPreview {
                        ProgressView("正在核对操作信息…")
                    }
                    if let preview = calendarPreview {
                        Label(preview.detail, systemImage: preview.conflictCount > 0 ? "exclamationmark.calendar" : "calendar.badge.checkmark")
                            .font(.subheadline).foregroundStyle(WhaleTheme.muted)
                    }
                    if let previewError {
                        Text(previewError).font(.footnote).foregroundStyle(WhaleTheme.danger)
                        Button("重新核对") { Task { await loadPreview() } }
                    }

                    Label(ToolPresentation.confirmationNote(item.tool), systemImage: "checkmark.shield")
                        .font(.subheadline)
                        .foregroundStyle(WhaleTheme.muted)

                    if let error = model.errorText, !error.isEmpty {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(WhaleTheme.danger)
                    }

                    Button {
                        Task { await model.confirm(item, calendarFingerprint: calendarPreview?.fingerprint) }
                    } label: {
                        Text(ToolPresentation.confirmationAction(item.tool, conflictCount: calendarPreview?.conflictCount ?? 0)).whalePrimaryButton()
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isBusy || checkingPreview || previewError != nil)
                    .padding(.top, 8)

                    Button(role: .destructive) {
                        Task { await model.skip(item) }
                    } label: {
                        Text("跳过本次，不执行")
                            .whaleFont(size: 15)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                    }
                    .disabled(model.isBusy)
                }
                .padding(20)
            }
            .background(WhaleBackdrop())
            .navigationTitle("确认操作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("稍后处理") { model.dismissConfirmation() }
                }
            }
        }
        .task(id: item.id) { await loadPreview() }
        .onChange(of: model.errorText) { _, value in
            if value?.contains("日历内容已变化") == true { Task { await loadPreview() } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    private func loadPreview() async {
        checkingPreview = true
        previewError = nil
        defer { checkingPreview = false }
        do { calendarPreview = try await model.calendarPreview(item) }
        catch { previewError = error.localizedDescription }
    }

}
