import SwiftUI
import UIKit
import AVFoundation
import EventKit
import CoreLocation
import UserNotifications
import MediaPlayer

enum SettingsRoute: Hashable {
    case profile
    case assistantPreferences
    case permissions
    case appearance
    case connectionData
    case privacy
}

/// 鲸鱼 UI 的设置主页。所有授权状态都从系统读取，
/// 行点进去会打开系统设置，不在 App 内伪造「已授权」。
struct SettingsTabView: View {
    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL
    @Binding var path: NavigationPath
    var resetToken: Int = 0
    var onClose: (() -> Void)?

    @State private var showMemory = false
    @State private var showPhysicsBox = false
    @State private var notificationGranted = false

    private var memoryCount: Int { ChatStore.count }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        profileCard
                        categoryGroup
                        versionCard
                    }
                    .id("settings-top")
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, onClose == nil ? 104 : 26)
                }
                .scrollIndicators(.hidden)
                .onChange(of: resetToken) { _, _ in
                    withAnimation(.easeOut(duration: 0.22)) {
                        proxy.scrollTo("settings-top", anchor: .top)
                    }
                }
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .privacy:
                    PrivacyPage(state: state)
                case .profile:
                    ProfileSettingsPage()
                case .assistantPreferences:
                    AssistantPreferencesSettingsPage()
                case .permissions:
                    PermissionsSettingsPage()
                case .appearance:
                    AppearanceSettingsPage()
                case .connectionData:
                    ConnectionDataSettingsPage(
                        showPhysicsBox: $showPhysicsBox,
                        onOpenMemory: { showMemory = true }
                    )
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showMemory) {
                MemoryView()
            }
            .sheet(isPresented: $showPhysicsBox) {
                PhysicsBoxView()
            }
        }
        .background(Color.clear)
        .preferredColorScheme(state.settings.appearance.colorScheme)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("设置")
                    .font(.nomiScaled(size: 30, weight: .bold))
                    .tracking(-0.9)
                    .foregroundStyle(CardPalette.ink)
                Text("按类别管理 Nomi")
                    .font(.nomiScaled(size: 11.5))
                    .foregroundStyle(CardPalette.subtle)
            }

            Spacer()

            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.nomiScaled(size: 13, weight: .semibold))
                        .foregroundStyle(CardPalette.subtle)
                        .frame(width: 44, height: 44)
                        .background(CardPalette.surface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(CardPalette.line, lineWidth: 1))
                }
                .buttonStyle(WhalePressStyle())
                .accessibilityLabel("关闭设置")
            }
        }
    }

    private var profileCard: some View {
        NavigationLink(value: SettingsRoute.profile) {
            WhaleGlassCard(radius: 24, padding: 17) {
                HStack(spacing: 13) {
                    NomiAvatar(size: 54, expression: .happy)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profileName)
                            .font(.nomiScaled(size: 20, weight: .bold))
                            .foregroundStyle(CardPalette.ink)

                        Text(profileSubtitle)
                            .font(.nomiScaled(size: 11.5))
                            .foregroundStyle(CardPalette.subtle)
                            .lineLimit(2)

                        HStack(spacing: 5) {
                            Circle()
                                .fill(CardPalette.success)
                                .frame(width: 5, height: 5)
                            Text("个人资料保存在本机")
                                .font(.nomiScaled(size: 10.5, weight: .medium))
                                .foregroundStyle(CardPalette.success)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.nomiScaled(size: 12, weight: .semibold))
                        .foregroundStyle(CardPalette.faint)
                }
            }
        }
        .buttonStyle(WhalePressStyle(scale: 0.985))
    }

    private var profileName: String {
        state.settings.nickname.isEmpty ? "填写个人资料" : state.settings.nickname
    }

    private var profileSubtitle: String {
        let note = state.settings.profileNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { return note }
        if state.settings.nickname.isEmpty {
            return "补充称呼和一段个人介绍，让 Nomi 更了解你"
        }
        return "Nomi 已记住 \(memoryCount) 条本机记录"
    }

    private var categoryGroup: some View {
        VStack(spacing: 0) {
            NavigationLink(value: SettingsRoute.assistantPreferences) {
                settingsCategoryRow(
                    symbol: "sparkles",
                    title: "助手偏好",
                    subtitle: "语音回应、主动提醒与执行确认",
                    color: CardPalette.accent2
                )
            }
            .buttonStyle(WhalePressStyle(scale: 0.985))

            WhaleRowDivider(leading: 50)

            NavigationLink(value: SettingsRoute.permissions) {
                settingsCategoryRow(
                    symbol: "hand.raised",
                    title: "能力与授权",
                    subtitle: "位置、麦克风、日历、提醒、音乐与通知",
                    color: CardPalette.accent
                )
            }
            .buttonStyle(WhalePressStyle(scale: 0.985))

            WhaleRowDivider(leading: 50)

            NavigationLink(value: SettingsRoute.appearance) {
                settingsCategoryRow(
                    symbol: "circle.lefthalf.filled",
                    title: "外观与体验",
                    subtitle: "深海、晨雾与跟随人脸",
                    color: CardPalette.amber
                )
            }
            .buttonStyle(WhalePressStyle(scale: 0.985))

            WhaleRowDivider(leading: 50)

            NavigationLink(value: SettingsRoute.connectionData) {
                settingsCategoryRow(
                    symbol: "externaldrive",
                    title: "连接与数据",
                    subtitle: "DeepSeek、隐私、记忆和高级设置",
                    color: CardPalette.rose
                )
            }
            .buttonStyle(WhalePressStyle(scale: 0.985))
        }
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        }
    }

    private func settingsCategoryRow(
        symbol: String,
        title: String,
        subtitle: String,
        color: Color
    ) -> some View {
        HStack(spacing: 11) {
            WhaleIconTile(symbol: symbol, color: color)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.nomiScaled(size: 15, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                Text(subtitle)
                    .font(.nomiScaled(size: 10.5))
                    .foregroundStyle(CardPalette.subtle)
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.nomiScaled(size: 10.5, weight: .semibold))
                .foregroundStyle(CardPalette.faint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    private var permissionSection: some View {
        settingsSection(title: "能力与授权", subtitle: "来自系统真实状态") {
            VStack(spacing: 0) {
                permissionRow(
                    symbol: "location",
                    title: "位置",
                    subtitle: "天气、附近地点与本地路线",
                    granted: locationGranted,
                    color: CardPalette.accent
                )
                WhaleRowDivider(leading: 50)
                permissionRow(
                    symbol: "mic",
                    title: "麦克风",
                    subtitle: "语音输入与播报",
                    granted: microphoneGranted,
                    color: CardPalette.accent2
                )
                WhaleRowDivider(leading: 50)
                permissionRow(
                    symbol: "calendar",
                    title: "日历",
                    subtitle: "读取安排 · 确认后写入",
                    granted: calendarGranted,
                    color: CardPalette.amber
                )
                WhaleRowDivider(leading: 50)
                permissionRow(
                    symbol: "bell",
                    title: "通知",
                    subtitle: "任务完成与主动提醒",
                    granted: notificationGranted,
                    color: CardPalette.rose
                )
            }
            .background(CardPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(CardPalette.line, lineWidth: 1)
            }
        }
    }

    private func permissionRow(
        symbol: String,
        title: String,
        subtitle: String,
        granted: Bool,
        color: Color
    ) -> some View {
        Button {
            openSystemSettings()
        } label: {
            HStack(spacing: 11) {
                WhaleIconTile(symbol: symbol, color: color)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.nomiScaled(size: 14.5, weight: .semibold))
                        .foregroundStyle(CardPalette.ink)
                    Text(subtitle)
                        .font(.nomiScaled(size: 10.5))
                        .foregroundStyle(CardPalette.subtle)
                }

                Spacer(minLength: 6)

                HStack(spacing: 4) {
                    Circle()
                        .fill(granted ? CardPalette.success : CardPalette.faint)
                        .frame(width: 5, height: 5)
                    Text(granted ? "已授权" : "未开启")
                        .font(.nomiScaled(size: 10, weight: .semibold))
                }
                .foregroundStyle(granted ? CardPalette.success : CardPalette.faint)

                Image(systemName: "chevron.right")
                    .font(.nomiScaled(size: 10.5, weight: .semibold))
                    .foregroundStyle(CardPalette.faint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(WhalePressStyle(scale: 0.985))
    }

    private var assistantSection: some View {
        settingsSection(title: "助手偏好", subtitle: "随时可改") {
            VStack(spacing: 0) {
                toggleRow(
                    symbol: "speaker.wave.2",
                    title: "语音回应",
                    subtitle: "回答时同时播放语音",
                    color: CardPalette.accent2,
                    binding: Binding(
                        get: { state.settings.voiceEnabled },
                        set: { newValue in
                            var value = state.settings
                            value.voiceEnabled = newValue
                            state.updateSettings(value)
                        }
                    )
                )

                WhaleRowDivider(leading: 50)

                toggleRow(
                    symbol: "sparkles",
                    title: "主动提醒",
                    subtitle: "行程冲突、天气变化与作息",
                    color: CardPalette.amber,
                    binding: Binding(
                        get: { anyNoticeOn },
                        set: { setAllNotices($0) }
                    )
                )

                WhaleRowDivider(leading: 50)

                HStack(spacing: 11) {
                    WhaleIconTile(symbol: "lock.shield", color: CardPalette.accent)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("执行前确认")
                            .font(.nomiScaled(size: 14.5, weight: .semibold))
                            .foregroundStyle(CardPalette.ink)
                        Text("写日历、发消息等动作必须先确认")
                            .font(.nomiScaled(size: 10.5))
                            .foregroundStyle(CardPalette.subtle)
                    }

                    Spacer(minLength: 6)

                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.nomiScaled(size: 8.5))
                        Text("始终开启")
                            .font(.nomiScaled(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(CardPalette.accent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
            }
            .background(CardPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(CardPalette.line, lineWidth: 1)
            }
        }
    }

    private func toggleRow(
        symbol: String,
        title: String,
        subtitle: String,
        color: Color,
        binding: Binding<Bool>
    ) -> some View {
        HStack(spacing: 11) {
            WhaleIconTile(symbol: symbol, color: color)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.nomiScaled(size: 14.5, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                Text(subtitle)
                    .font(.nomiScaled(size: 10.5))
                    .foregroundStyle(CardPalette.subtle)
            }

            Spacer(minLength: 6)

            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(CardPalette.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }

    private var appearanceSection: some View {
        settingsSection(title: "外观", subtitle: "深海 / 晨雾 / 跟随系统") {
            HStack(spacing: 9) {
                appearanceOption(
                    .dark,
                    title: "深海",
                    preview: Color(red: 0.016, green: 0.043, blue: 0.063)
                )
                appearanceOption(.light, title: "晨雾", preview: Color(red: 0.94, green: 0.98, blue: 0.97))
                appearanceOption(
                    .system,
                    title: "自动",
                    preview: Color(red: 0.30, green: 0.48, blue: 0.49)
                )
            }
        }
    }

    private func appearanceOption(
        _ mode: AppearanceMode,
        title: String,
        preview: Color
    ) -> some View {
        let selected = state.settings.appearance == mode
        let previewInk = mode == .light
            ? Color(red: 0.04, green: 0.15, blue: 0.18)
            : Color.white

        return Button {
            var value = state.settings
            value.appearance = mode
            withAnimation(.easeOut(duration: 0.20)) {
                state.updateSettings(value)
            }
        } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(preview)
                    .frame(height: 70)
                    .overlay {
                        VStack(alignment: .leading, spacing: 5) {
                            Capsule()
                                .fill(CardPalette.accent.opacity(0.70))
                                .frame(width: 34, height: 5)
                            Capsule()
                                .fill(previewInk.opacity(0.24))
                                .frame(width: 51, height: 4)
                            Capsule()
                                .fill(previewInk.opacity(0.13))
                                .frame(width: 40, height: 4)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(11)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(
                                selected ? CardPalette.accent : CardPalette.line,
                                lineWidth: selected ? 1.5 : 1
                            )
                    }

                Text(title)
                    .font(.nomiScaled(size: 11.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? CardPalette.accent : CardPalette.subtle)
            }
            .padding(7)
            .background(selected ? CardPalette.accent.opacity(0.08) : CardPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(WhalePressStyle())
    }

    private var connectionSection: some View {
        settingsSection(title: "服务连接", subtitle: "只显示真实接入") {
            VStack(spacing: 0) {
                connectionRow(
                    symbol: "d.circle",
                    title: "DeepSeek",
                    subtitle: "对话与任务规划",
                    connected: deepSeekConfigured,
                    color: CardPalette.accent2
                )
                WhaleRowDivider(leading: 50)
                connectionRow(
                    symbol: "waveform",
                    title: "系统语音",
                    subtitle: "语音识别与本机播报",
                    connected: true,
                    color: CardPalette.accent
                )
                WhaleRowDivider(leading: 50)
                NavigationLink {
                    AdvancedPage(state: state, showPhysicsBox: $showPhysicsBox)
                } label: {
                    linkRow(
                        symbol: "slider.horizontal.3",
                        title: "高级设置",
                        subtitle: "API Key、位置、作息和物理盒子",
                        color: CardPalette.amber
                    )
                }
                .buttonStyle(WhalePressStyle(scale: 0.985))
            }
            .background(CardPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(CardPalette.line, lineWidth: 1)
            }
        }
    }

    private func connectionRow(
        symbol: String,
        title: String,
        subtitle: String,
        connected: Bool,
        color: Color
    ) -> some View {
        HStack(spacing: 11) {
            WhaleIconTile(symbol: symbol, color: color)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.nomiScaled(size: 14.5, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                Text(subtitle)
                    .font(.nomiScaled(size: 10.5))
                    .foregroundStyle(CardPalette.subtle)
            }

            Spacer(minLength: 6)
            WhalePill(
                text: connected ? "已配置" : "未配置",
                color: connected ? CardPalette.success : CardPalette.amber
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }

    private var moreSection: some View {
        VStack(spacing: 0) {
            Button {
                showMemory = true
            } label: {
                linkRow(
                    symbol: "brain",
                    title: "记忆",
                    subtitle: "\(memoryCount) 条，可逐条查看和删除",
                    color: CardPalette.rose
                )
            }
            .buttonStyle(WhalePressStyle(scale: 0.985))

            WhaleRowDivider(leading: 50)

            NavigationLink {
                PermissionPage(state: state)
            } label: {
                linkRow(
                    symbol: "hand.raised",
                    title: "全部系统权限",
                    subtitle: "相机、麦克风、日历、提醒和运动",
                    color: CardPalette.accent
                )
            }
            .buttonStyle(WhalePressStyle(scale: 0.985))
        }
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        }
    }

    private func linkRow(
        symbol: String,
        title: String,
        subtitle: String,
        color: Color
    ) -> some View {
        HStack(spacing: 11) {
            WhaleIconTile(symbol: symbol, color: color)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.nomiScaled(size: 14.5, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                Text(subtitle)
                    .font(.nomiScaled(size: 10.5))
                    .foregroundStyle(CardPalette.subtle)
            }

            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.nomiScaled(size: 10.5, weight: .semibold))
                .foregroundStyle(CardPalette.faint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private var versionCard: some View {
        HStack(spacing: 12) {
            NomiAvatar(size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text("Nomi")
                    .font(.nomiScaled(size: 14, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                Text("1.2 (11) · 鲸鱼 UI v9")
                    .font(.nomiScaled(size: 10.5))
                    .foregroundStyle(CardPalette.subtle)
            }
            Spacer()
            Text("ABYSS AURORA")
                .font(.nomiScaled(size: 8, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(CardPalette.accent)
        }
        .padding(14)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        }
    }

    private func settingsSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title)
                    .font(.nomiScaled(size: 13, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                Spacer()
                Text(subtitle)
                    .font(.nomiScaled(size: 10))
                    .foregroundStyle(CardPalette.faint)
            }
            content()
        }
    }

    private var anyNoticeOn: Bool {
        state.settings.rainAlertEnabled
            || state.settings.bedtimeAlertEnabled
            || state.settings.morningBriefingEnabled
            || state.settings.meetingAlertEnabled
            || state.settings.standUpEnabled
    }

    private func setAllNotices(_ on: Bool) {
        var value = state.settings
        value.rainAlertEnabled = on
        value.bedtimeAlertEnabled = on
        value.morningBriefingEnabled = on
        value.meetingAlertEnabled = on
        value.standUpEnabled = on
        state.updateSettings(value)

        if on {
            Task {
                _ = await NotificationService.requestPermission()
                await refreshNotificationPermission()
                await state.refresh()
            }
        }
    }

    private var deepSeekConfigured: Bool {
        !(Keychain.load("deepseek.key") ?? "").isEmpty
    }

    private var microphoneGranted: Bool {
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        }
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }

    private var calendarGranted: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) { return status == .fullAccess }
        return status == .authorized
    }

    private var locationGranted: Bool {
        let status = CLLocationManager().authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    @MainActor
    private func refreshNotificationPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationGranted = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - 个人资料

private struct ProfileSettingsPage: View {
    @Environment(AppState.self) private var state

    @State private var nickname = ""
    @State private var profileNote = ""
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                WhaleGlassCard(radius: 22, padding: 16) {
                    HStack(spacing: 13) {
                        NomiAvatar(size: 54, expression: .happy)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("个人资料")
                                .font(.nomiScaled(size: 20, weight: .bold))
                                .foregroundStyle(CardPalette.ink)
                            Text("这些信息保存在本机，并作为 Nomi 的对话上下文使用。")
                                .font(.nomiScaled(size: 11.5))
                                .foregroundStyle(CardPalette.subtle)
                                .lineSpacing(2)
                        }
                    }
                }

                WhaleGlassCard(radius: 20, padding: 15) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Nomi 怎么称呼你")
                            .font(.nomiScaled(size: 11.5, weight: .semibold))
                            .foregroundStyle(CardPalette.subtle)
                        TextField("例如：小王、阿哲", text: $nickname)
                            .font(.nomiScaled(size: 16))
                            .foregroundStyle(CardPalette.ink)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                WhaleGlassCard(radius: 20, padding: 15) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text("个人介绍")
                                .font(.nomiScaled(size: 11.5, weight: .semibold))
                                .foregroundStyle(CardPalette.subtle)
                            Spacer()
                            Text("\(profileNote.count)/300")
                                .font(.nomiScaled(size: 9.5))
                                .foregroundStyle(CardPalette.faint)
                        }

                        ZStack(alignment: .topLeading) {
                            if profileNote.isEmpty {
                                Text("例如：在上海工作，喜欢简洁直接的回答；周末常去徒步。")
                                    .font(.nomiScaled(size: 14))
                                    .foregroundStyle(CardPalette.faint)
                                    .padding(.top, 7)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }

                            TextEditor(text: $profileNote)
                                .font(.nomiScaled(size: 14.5))
                                .foregroundStyle(CardPalette.ink)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 120)
                                .onChange(of: profileNote) { _, value in
                                    if value.count > 300 {
                                        profileNote = String(value.prefix(300))
                                    }
                                }
                        }
                    }
                }

                Button {
                    save()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: saved ? "checkmark" : "square.and.arrow.down")
                            .font(.nomiScaled(size: 12, weight: .bold))
                        Text(saved ? "已保存" : "保存个人资料")
                            .font(.nomiScaled(size: 14.5, weight: .bold))
                    }
                    .foregroundStyle(CardPalette.navyInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 49)
                    .background(CardPalette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(WhalePressStyle())
                .sensoryFeedback(.success, trigger: saved)

                Text("修改后会立即用于之后的对话；聊天记录和这份资料仍保存在本机。")
                    .font(.nomiScaled(size: 10.5))
                    .foregroundStyle(CardPalette.faint)
                    .lineSpacing(2)
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Color.clear)
        .navigationTitle("个人资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear(perform: load)
    }

    private func load() {
        nickname = state.settings.nickname
        profileNote = state.settings.profileNote
        saved = false
    }

    private func save() {
        var value = state.settings
        value.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        value.profileNote = profileNote.trimmingCharacters(in: .whitespacesAndNewlines)
        state.updateSettings(value)
        saved = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            saved = false
        }
    }
}

// MARK: - 助手偏好

private struct AssistantPreferencesSettingsPage: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                WhaleGlassCard(radius: 20, padding: 0) {
                    VStack(spacing: 0) {
                        toggleRow(
                            symbol: "speaker.wave.2",
                            title: "语音回应",
                            subtitle: "回答时同时播放语音",
                            color: CardPalette.accent2,
                            isOn: Binding(
                                get: { state.settings.voiceEnabled },
                                set: { newValue in
                                    var value = state.settings
                                    value.voiceEnabled = newValue
                                    state.updateSettings(value)
                                }
                            )
                        )

                        WhaleRowDivider(leading: 50)

                        toggleRow(
                            symbol: "bell",
                            title: "主动提醒",
                            subtitle: "行程冲突、天气变化与作息",
                            color: CardPalette.amber,
                            isOn: Binding(
                                get: { noticesEnabled },
                                set: { setAllNotices($0) }
                            )
                        )
                    }
                }

                WhaleGlassCard(radius: 20, padding: 14) {
                    HStack(spacing: 11) {
                        WhaleIconTile(symbol: "lock.shield", color: CardPalette.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("执行前确认")
                                .font(.nomiScaled(size: 14.5, weight: .semibold))
                                .foregroundStyle(CardPalette.ink)
                            Text("写日历、发消息等动作必须先确认")
                                .font(.nomiScaled(size: 10.5))
                                .foregroundStyle(CardPalette.subtle)
                        }
                        Spacer()
                        Text("始终开启")
                            .font(.nomiScaled(size: 10.5, weight: .semibold))
                            .foregroundStyle(CardPalette.accent)
                    }
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .navigationTitle("助手偏好")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var noticesEnabled: Bool {
        state.settings.rainAlertEnabled
            || state.settings.bedtimeAlertEnabled
            || state.settings.morningBriefingEnabled
            || state.settings.meetingAlertEnabled
            || state.settings.standUpEnabled
    }

    private func setAllNotices(_ on: Bool) {
        var value = state.settings
        value.rainAlertEnabled = on
        value.bedtimeAlertEnabled = on
        value.morningBriefingEnabled = on
        value.meetingAlertEnabled = on
        value.standUpEnabled = on
        state.updateSettings(value)

        if on {
            Task {
                _ = await NotificationService.requestPermission()
                await state.refresh()
            }
        }
    }

    private func toggleRow(
        symbol: String,
        title: String,
        subtitle: String,
        color: Color,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 11) {
            WhaleIconTile(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.nomiScaled(size: 14.5, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                Text(subtitle)
                    .font(.nomiScaled(size: 10.5))
                    .foregroundStyle(CardPalette.subtle)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(CardPalette.accent)
        }
        .padding(14)
    }
}

// MARK: - 权限

private enum SettingsPermissionKind: String, CaseIterable, Identifiable {
    case location = "位置"
    case microphone = "麦克风"
    case calendar = "日历"
    case reminders = "提醒事项"
    case musicLibrary = "音乐资料库"
    case notifications = "通知"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .location: return "天气、附近地点和路线"
        case .microphone: return "只在语音输入时使用"
        case .calendar: return "读取安排，写入前仍会确认"
        case .reminders: return "新建和完成待办"
        case .musicLibrary: return "读取手机「音乐」中的歌曲"
        case .notifications: return "主动提醒和任务回执"
        }
    }

    var symbol: String {
        switch self {
        case .location: return "location"
        case .microphone: return "mic"
        case .calendar: return "calendar"
        case .reminders: return "checklist"
        case .musicLibrary: return "music.note"
        case .notifications: return "bell"
        }
    }

    var color: Color {
        switch self {
        case .location: return CardPalette.accent
        case .microphone: return CardPalette.accent2
        case .calendar: return CardPalette.amber
        case .reminders: return CardPalette.success
        case .musicLibrary: return CardPalette.accent2
        case .notifications: return CardPalette.rose
        }
    }
}

private enum SettingsPermissionAccess: Equatable {
    case granted
    case notDetermined
    case denied

    var text: String {
        switch self {
        case .granted: return "已开启"
        case .notDetermined: return "按需启用"
        case .denied: return "已关闭"
        }
    }

    var color: Color {
        switch self {
        case .granted: return CardPalette.success
        case .notDetermined: return CardPalette.subtle
        case .denied: return CardPalette.amber
        }
    }
}

private struct PermissionsSettingsPage: View {
    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var notificationAccess: SettingsPermissionAccess = .notDetermined
    @State private var requesting: SettingsPermissionKind?
    @State private var refreshTick = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("权限不会在启动时批量申请。只有你在这里启用，或第一次使用对应能力时，系统才会询问。")
                    .font(.nomiScaled(size: 12))
                    .foregroundStyle(CardPalette.subtle)
                    .lineSpacing(3)
                    .padding(.horizontal, 2)

                VStack(spacing: 0) {
                    ForEach(Array(SettingsPermissionKind.allCases.enumerated()), id: \.element.id) { index, kind in
                        permissionRow(kind)
                        if index < SettingsPermissionKind.allCases.count - 1 {
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

                NavigationLink {
                    PermissionPage(state: state)
                } label: {
                    HStack {
                        Text("相机、运动等其他系统权限")
                            .font(.nomiScaled(size: 13.5, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.nomiScaled(size: 10.5, weight: .semibold))
                    }
                    .foregroundStyle(CardPalette.ink)
                    .padding(14)
                    .background(CardPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(WhalePressStyle(scale: 0.985))
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .navigationTitle("能力与授权")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task(id: refreshTick) {
            await refreshNotificationStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshTick &+= 1
            }
        }
    }

    private func permissionRow(_ kind: SettingsPermissionKind) -> some View {
        let access = access(for: kind)

        return HStack(spacing: 11) {
            WhaleIconTile(symbol: kind.symbol, color: kind.color)

            VStack(alignment: .leading, spacing: 3) {
                Text(kind.rawValue)
                    .font(.nomiScaled(size: 14.5, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                Text(kind.subtitle)
                    .font(.nomiScaled(size: 10.5))
                    .foregroundStyle(CardPalette.subtle)
            }

            Spacer(minLength: 6)

            if requesting == kind {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(CardPalette.accent)
            } else if access == .granted {
                WhalePill(text: access.text, color: access.color)
            } else if access == .denied {
                Button("去设置") {
                    openSystemSettings()
                }
                .font(.nomiScaled(size: 11, weight: .semibold))
                .foregroundStyle(CardPalette.amber)
                .frame(minWidth: 44, minHeight: 44)
            } else {
                Button("启用") {
                    request(kind)
                }
                .font(.nomiScaled(size: 11, weight: .semibold))
                .foregroundStyle(CardPalette.accent)
                .frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }

    private func access(for kind: SettingsPermissionKind) -> SettingsPermissionAccess {
        switch kind {
        case .location:
            switch CLLocationManager().authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                return .granted
            case .notDetermined:
                return .notDetermined
            default:
                return .denied
            }

        case .microphone:
            switch AVAudioApplication.shared.recordPermission {
            case .granted: return .granted
            case .undetermined: return .notDetermined
            default: return .denied
            }

        case .calendar:
            let status = EKEventStore.authorizationStatus(for: .event)
            if #available(iOS 17.0, *) {
                return status == .fullAccess ? .granted : (status == .notDetermined ? .notDetermined : .denied)
            }
            return status == .authorized ? .granted : (status == .notDetermined ? .notDetermined : .denied)

        case .reminders:
            let status = EKEventStore.authorizationStatus(for: .reminder)
            if #available(iOS 17.0, *) {
                return status == .fullAccess ? .granted : (status == .notDetermined ? .notDetermined : .denied)
            }
            return status == .authorized ? .granted : (status == .notDetermined ? .notDetermined : .denied)

        case .musicLibrary:
            switch MPMediaLibrary.authorizationStatus() {
            case .authorized: return .granted
            case .notDetermined: return .notDetermined
            default: return .denied
            }

        case .notifications:
            return notificationAccess
        }
    }

    private func request(_ kind: SettingsPermissionKind) {
        guard requesting == nil else { return }
        requesting = kind

        Task {
            switch kind {
            case .location:
                _ = await state.requestLocationAccess()
            case .microphone:
                let recognizer = SpeechRecognizer()
                _ = await recognizer.requestPermission()
            case .calendar:
                _ = await state.requestCalendarAccess()
            case .reminders:
                _ = await state.requestReminderAccess()
            case .musicLibrary:
                let status: MPMediaLibraryAuthorizationStatus = await withCheckedContinuation { continuation in
                    MPMediaLibrary.requestAuthorization { newStatus in
                        continuation.resume(returning: newStatus)
                    }
                }
                _ = status
                await state.refresh()
            case .notifications:
                _ = await NotificationService.requestPermission()
                await state.refresh()
            }

            await refreshNotificationStatus()
            requesting = nil
            refreshTick &+= 1
        }
    }

    @MainActor
    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let status = settings.authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral:
            notificationAccess = .granted
        case .notDetermined:
            notificationAccess = .notDetermined
        default:
            notificationAccess = .denied
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - 外观

private struct AppearanceSettingsPage: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 9) {
                    appearanceOption(.dark, title: "深海", preview: Color(red: 0.016, green: 0.043, blue: 0.063))
                    appearanceOption(.light, title: "晨雾", preview: Color(red: 0.94, green: 0.98, blue: 0.97))
                    appearanceOption(.system, title: "自动", preview: Color(red: 0.30, green: 0.48, blue: 0.49))
                }

                WhaleGlassCard(radius: 20, padding: 14) {
                    Toggle(isOn: Binding(
                        get: { state.settings.followFace },
                        set: { newValue in
                            var value = state.settings
                            value.followFace = newValue
                            state.updateSettings(value)
                            state.setFaceFollow(newValue)
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("跟着你看")
                                .font(.nomiScaled(size: 14.5, weight: .semibold))
                                .foregroundStyle(CardPalette.ink)
                            Text("开启时才请求相机权限，画面只在本机处理")
                                .font(.nomiScaled(size: 10.5))
                                .foregroundStyle(CardPalette.subtle)
                        }
                    }
                    .tint(CardPalette.accent)
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .navigationTitle("外观与体验")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func appearanceOption(
        _ mode: AppearanceMode,
        title: String,
        preview: Color
    ) -> some View {
        let selected = state.settings.appearance == mode
        return Button {
            var value = state.settings
            value.appearance = mode
            state.updateSettings(value)
        } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(preview)
                    .frame(height: 84)
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(
                                selected ? CardPalette.accent : CardPalette.line,
                                lineWidth: selected ? 1.5 : 1
                            )
                    }
                Text(title)
                    .font(.nomiScaled(size: 11.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? CardPalette.accent : CardPalette.subtle)
            }
            .padding(7)
            .background(selected ? CardPalette.accent.opacity(0.08) : CardPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(WhalePressStyle())
    }
}

// MARK: - 连接与数据

private struct ConnectionDataSettingsPage: View {
    @Environment(AppState.self) private var state
    var showPhysicsBox: Binding<Bool>
    var onOpenMemory: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                statusRow(
                    symbol: "d.circle",
                    title: "DeepSeek",
                    subtitle: "对话与任务规划",
                    connected: deepSeekConfigured,
                    color: CardPalette.accent2
                )

                WhaleRowDivider(leading: 50)

                NavigationLink {
                    AdvancedPage(state: state, showPhysicsBox: showPhysicsBox)
                } label: {
                    navigationRow(
                        symbol: "slider.horizontal.3",
                        title: "高级设置",
                        subtitle: "API Key、城市、作息和物理盒子",
                        color: CardPalette.amber
                    )
                }
                .buttonStyle(WhalePressStyle(scale: 0.985))

                WhaleRowDivider(leading: 50)

                NavigationLink {
                    PrivacyPage(state: state)
                } label: {
                    navigationRow(
                        symbol: "checkmark.shield",
                        title: "隐私与数据",
                        subtitle: "查看哪些内容会发送给外部服务",
                        color: CardPalette.accent
                    )
                }
                .buttonStyle(WhalePressStyle(scale: 0.985))

                WhaleRowDivider(leading: 50)

                Button(action: onOpenMemory) {
                    navigationRow(
                        symbol: "brain",
                        title: "记忆",
                        subtitle: "\(ChatStore.count) 条本机记录",
                        color: CardPalette.rose
                    )
                }
                .buttonStyle(WhalePressStyle(scale: 0.985))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .background(CardPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(CardPalette.line, lineWidth: 1)
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .navigationTitle("连接与数据")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var deepSeekConfigured: Bool {
        !(Keychain.load("deepseek.key") ?? "").isEmpty
    }

    private func statusRow(
        symbol: String,
        title: String,
        subtitle: String,
        connected: Bool,
        color: Color
    ) -> some View {
        HStack(spacing: 11) {
            WhaleIconTile(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.nomiScaled(size: 14.5, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                Text(subtitle)
                    .font(.nomiScaled(size: 10.5))
                    .foregroundStyle(CardPalette.subtle)
            }
            Spacer()
            WhalePill(
                text: connected ? "已配置" : "未配置",
                color: connected ? CardPalette.success : CardPalette.amber
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }

    private func navigationRow(
        symbol: String,
        title: String,
        subtitle: String,
        color: Color
    ) -> some View {
        HStack(spacing: 11) {
            WhaleIconTile(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.nomiScaled(size: 14.5, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                Text(subtitle)
                    .font(.nomiScaled(size: 10.5))
                    .foregroundStyle(CardPalette.subtle)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.nomiScaled(size: 10.5, weight: .semibold))
                .foregroundStyle(CardPalette.faint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}
