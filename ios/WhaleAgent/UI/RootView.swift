import Combine
import SwiftUI
import UIKit

@MainActor
struct RootView: View {
    @StateObject private var model = AppModel()
    @StateObject private var keyboard = KeyboardObserver()
    @State private var page = NavigationHabits.restoredTab(UserDefaults.standard.string(forKey: "whale.root.tab"))
    @State private var showRecords = false
    @State private var showSettings = false
    @State private var settingsDetailOpen = false
    @State private var composerDraft = ""
    @State private var composerFocused = false
    @AppStorage("whale.discover.selectedChannel") private var discoverChannel: DiscoverChannel = .ai
    @AppStorage("whale.appearance") private var appearance = "system"
    @AppStorage(WhalePaletteStyle.storageKey) private var paletteRaw = WhalePaletteStyle.seaSalt.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var systemTextSize

    var body: some View {
        pager
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomChrome }
        .tint(WhaleTheme.accent)
        .environment(\.whalePaletteStyle, selectedPalette)
        .preferredColorScheme(colorScheme)
        .dynamicTypeSize(preferredTextSize)
        .sheet(item: $model.presentedConfirmation) { item in ConfirmationSheet(model: model, item: item) }
        .sheet(isPresented: $showRecords) {
            RecordsView(
                model: model,
                onOpenTask: { task in
                    guard model.requestMessageFocus(for: task) else { return false }
                    showRecords = false
                    page = .conversation
                    return true
                },
                showsClose: true,
                onClose: { showRecords = false }
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(model: model, isDetailOpen: $settingsDetailOpen, onBackToChat: { showSettings = false })
                .presentationDragIndicator(.visible)
        }
        .task {
#if DEBUG
            let environment = ProcessInfo.processInfo.environment
            if let raw = environment["WHALE_DEMO_INITIAL_CHANNEL"], let channel = DiscoverChannel(rawValue: raw) { discoverChannel = channel }
            if environment["WHALE_DEMO_HOME"] == "1" || environment["WHALE_DEMO_WEATHER"] == "1" { page = .conversation }
            if let raw = environment["WHALE_DEMO_PALETTE"],
               let palette = WhalePaletteStyle(rawValue: raw) {
                paletteRaw = palette.rawValue
            }
            if environment["WHALE_DEMO_CONTEXT"] == "1" {
                model.seedDemoWorkingContext()
            }
            if environment["WHALE_DEMO_PREVIEW"] == "1" {
                model.presentedConfirmation = PendingTool(
                    tool: "create_reminder",
                    toolCallId: "demo-preview",
                    operationId: "demo-preview-operation",
                    arguments: [
                        "title": .string("给周报安排时间"),
                        "dueAt": .string(ToolDate.iso(Date().addingTimeInterval(86_400))),
                        "notes": .string("演示统一操作预览")
                    ],
                    requiresConfirmation: true
                )
            }
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

    // MARK: - Main pages

    /// Keep all three pages mounted so drafts and scroll positions survive tab
    /// changes, but do not compete with channel, reading and back-swipe gestures.
    private var pager: some View {
        ZStack {
            conversationPage
                .opacity(page == .conversation ? 1 : 0)
                .accessibilityHidden(page != .conversation)
                .allowsHitTesting(page == .conversation)
            discoverPage
                .opacity(page == .discover ? 1 : 0)
                .accessibilityHidden(page != .discover)
                .allowsHitTesting(page == .discover)
            recordsPage
                .opacity(page == .records ? 1 : 0)
                .accessibilityHidden(page != .records)
                .allowsHitTesting(page == .records)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.16), value: page)
    }

    private var conversationPage: some View {
        ConversationTabView(model: model, bottomInset: 0,
            onOpenRecords: { showRecords = true }, onOpenSettings: { showSettings = true },
            onOpenMusic: { openDiscover(.music) }, onOpenTodo: { page = .records }, onOpenDiscover: openDiscover)
    }

    /// Composer and tabs share one bottom inset. This avoids nested safe-area
    /// insets placing the composer underneath the tab bar. While the keyboard
    /// is present the tab bar yields its space to the composer.
    @ViewBuilder
    private var bottomChrome: some View {
        if page == .conversation {
            VStack(spacing: 0) {
                ConversationComposerBar(model: model, externalFocused: $composerFocused, draft: $composerDraft)
                if RootBottomChromePolicy.tabBarVisible(
                    page: page,
                    composerFocused: composerFocused,
                    keyboardVisible: keyboard.isVisible
                ) {
                    WhaleRootTabBar(selection: $page)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        } else if RootBottomChromePolicy.tabBarVisible(
            page: page,
            composerFocused: composerFocused,
            keyboardVisible: keyboard.isVisible
        ) {
            WhaleRootTabBar(selection: $page)
        }
    }

    private var discoverPage: some View {
        DiscoverView(selection: $discoverChannel, appModel: model,
                     onSettings: { showSettings = true },
                     onSwitchTab: { tab in move(to: tab) })
    }

    private var recordsPage: some View {
        TodoView(model: model, embedded: true, onBackToChat: { page = .conversation }, bottomBarInset: 0)
    }

    private func move(to tab: AppTab) {
        guard tab != page else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.easeInOut(duration: 0.16)) { page = tab }
    }

    private func openDiscover(_ channel: DiscoverChannel) {
        discoverChannel = channel
        move(to: .discover)
    }
    private var colorScheme: ColorScheme? {
        appearance == "light" ? .light : appearance == "dark" ? .dark : nil
    }
    private var selectedPalette: WhalePaletteStyle {
        WhalePaletteStyle(rawValue: paletteRaw) ?? .seaSalt
    }
    private var preferredTextSize: DynamicTypeSize {
#if DEBUG
        if ProcessInfo.processInfo.environment["WHALE_DEMO_LARGE_TEXT"] == "1" { return .accessibility3 }
#endif
        return systemTextSize
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

/// Opaque bottom bar that keeps the old native tab bar metrics while the
/// content above it can be paged horizontally.
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
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.88)) { selection = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .symbolVariant(selected ? .fill : .none)
                Text(title)
                    .font(.system(size: 11, weight: selected ? .semibold : .medium))
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
                    OperationPreviewCard(.pending(item)) {
                        VStack(alignment: .leading, spacing: 12) {
                            if checkingPreview {
                                HStack(spacing: 8) {
                                    ProgressView().controlSize(.small)
                                    Text("正在核对系统数据…")
                                        .whaleFont(size: 12)
                                        .foregroundStyle(WhaleTheme.muted)
                                }
                            }
                            if let preview = calendarPreview {
                                Label(
                                    preview.detail,
                                    systemImage: preview.conflictCount > 0
                                        ? "exclamationmark.calendar"
                                        : "calendar.badge.checkmark"
                                )
                                .font(.subheadline)
                                .foregroundStyle(preview.conflictCount > 0 ? WhaleTheme.warm : WhaleTheme.muted)
                            }
                            if let previewError {
                                Text(previewError)
                                    .font(.footnote)
                                    .foregroundStyle(WhaleTheme.danger)
                                Button("重新核对") { Task { await loadPreview() } }
                            }
                            if let error = model.errorText, !error.isEmpty {
                                Label(error, systemImage: "exclamationmark.triangle")
                                    .font(.footnote)
                                    .foregroundStyle(WhaleTheme.danger)
                            }

                            Button {
                                Task { await model.confirm(item, calendarFingerprint: calendarPreview?.fingerprint) }
                            } label: {
                                Text(ToolPresentation.confirmationAction(
                                    item.tool,
                                    conflictCount: calendarPreview?.conflictCount ?? 0
                                ))
                                .whalePrimaryButton()
                            }
                            .buttonStyle(.plain)
                            .disabled(model.isBusy || checkingPreview || previewError != nil)

                            Button(role: .destructive) {
                                Task { await model.skip(item) }
                            } label: {
                                Text("取消，不执行")
                                    .whaleFont(size: 14, weight: .medium)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 40)
                            }
                            .disabled(model.isBusy)
                        }
                    }
                }
                .padding(20)
            }
            .background(WhaleBackdrop())
            .navigationTitle("操作预览")
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
