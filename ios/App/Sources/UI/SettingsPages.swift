import SwiftUI
import UIKit
import AVFoundation
import EventKit
import CoreLocation
import CoreMotion

// MARK: - 隐私页

struct PrivacyPage: View {
    var state: AppState

    private let rows: [(String, String, String)] = [
        ("DeepSeek", "你说的话、以及当前天气日程等上下文", "只在你说话时发送"),
        ("讯飞语音", "要朗读的那句话", "只在你让它说话时发送"),
        ("Open-Meteo", "城市经纬度", "不含任何个人信息"),
        ("高德", "地点名或坐标", "只有你点「打开高德」时才发")
    ]

    var body: some View {
        Form {
            Section {
                ForEach(rows, id: \.0) { row in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.0)
                            .font(.nomiScaled(size: 14.5, weight: .medium))
                        Text(row.1)
                            .font(.nomiScaled(size: 12.5))
                            .foregroundColor(.secondary)
                        Text(row.2)
                            .font(.nomiScaled(size: 11.5))
                            .foregroundColor(CardPalette.accent)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("会发给谁")
            } footer: {
                Text("除此之外的一切都留在这台手机上：聊天记录、偏好、步数、日程。")
            }

            Section {
                Text("删除 App 会一起删掉本机的聊天记录和偏好。云端不会留副本，因为本来就没有云端。")
                    .font(.nomiScaled(size: 12.5))
                    .foregroundColor(.secondary)
            } header: {
                Text("存在哪")
            }
        }
        .scrollContentBackground(.hidden)
        .background(CardPalette.screen)
        .navigationTitle("隐私与数据")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

// MARK: - 权限页

struct PermissionPage: View {
    var state: AppState

    @Environment(\.openURL) private var openURL

    private struct Item: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let granted: Bool
    }

    private var items: [Item] {
        [
            Item(symbol: "mic.fill", title: "麦克风", granted: microphoneGranted),
            Item(symbol: "camera.fill", title: "相机（跟着你看）", granted: cameraGranted),
            Item(symbol: "calendar", title: "日历", granted: calendarGranted),
            Item(symbol: "checklist", title: "提醒事项", granted: reminderGranted),
            Item(symbol: "location.fill", title: "位置", granted: locationGranted),
            Item(symbol: "figure.walk", title: "运动与健身", granted: motionGranted)
        ]
    }

    var body: some View {
        Form {
            Section {
                ForEach(items) { item in
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.symbol)
                                .font(.nomiScaled(size: 15))
                                .foregroundColor(item.granted ? CardPalette.accent : .secondary)
                                .frame(width: 24)

                            Text(item.title)
                                .font(.nomiScaled(size: 14.5))
                                .foregroundColor(.primary)

                            Spacer()

                            Text(item.granted ? "已允许" : "未授权")
                                .font(.nomiScaled(size: 12.5))
                                .foregroundColor(item.granted ? .secondary
                                                 : Color(red: 0.98, green: 0.66, blue: 0.16))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("iOS 不允许 App 自己改权限，点一行会跳到系统设置。")
            }
        }
        .scrollContentBackground(.hidden)
        .background(CardPalette.screen)
        .navigationTitle("系统权限")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var microphoneGranted: Bool {
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        }
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }

    private var cameraGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    private var calendarGranted: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) { return status == .fullAccess }
        return status == .authorized
    }

    private var reminderGranted: Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if #available(iOS 17.0, *) { return status == .fullAccess }
        return status == .authorized
    }

    private var locationGranted: Bool {
        let status = CLLocationManager().authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    private var motionGranted: Bool {
        CMMotionActivityManager.authorizationStatus() == .authorized
    }
}

// MARK: - 高级页

struct AdvancedPage: View {
    var state: AppState
    @Binding var showPhysicsBox: Bool

    @State private var apiKeyInput = ""
    @State private var editingKey = false
    @State private var cityInput = ""
    @State private var newCity = ""
    @State private var cityStatus = ""
    @State private var morningTime = Date()
    @State private var wakeTime = Date()
    @State private var bedtimeTime = Date()
    @State private var nicknameInput = ""

    var body: some View {
        Form {
            nicknameSection
            keySection
            locationSection
            reminderSection
            appearanceSection
            playSection
        }
        .scrollContentBackground(.hidden)
        .background(CardPalette.screen)
        .navigationTitle("高级")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear(perform: loadAll)
    }

    // MARK: 你

    private var nicknameSection: some View {
        Section {
            HStack {
                Text("它叫你")
                Spacer()
                TextField("比如 老王", text: $nicknameInput)
                    .multilineTextAlignment(.trailing)
                    .onSubmit {
                        var value = state.settings
                        value.nickname = nicknameInput.trimmingCharacters(in: .whitespaces)
                        state.updateSettings(value)
                    }
            }
        } header: {
            Text("称呼")
        }
    }

    // MARK: Key

    private var keySection: some View {
        Section {
            if editingKey {
                SecureField("sk-...", text: $apiKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("保存") { saveKey() }
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
            } else {
                HStack {
                    Text(keyDisplay)
                        .font(.nomiScaled(size: 14, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("修改") { editingKey = true }
                }
            }
        } header: {
            Text("DeepSeek API Key")
        } footer: {
            Text("没有 key 时只能本地回答；key 存在本机钥匙串。")
        }
    }

    // MARK: 位置

    private var locationSection: some View {
        Section {
            HStack {
                TextField("城市名，例如 杭州", text: $cityInput)
                Button("保存") { Task { await saveCity() } }
                    .disabled(cityInput.trimmingCharacters(in: .whitespaces) == state.settings.cityName)
            }

            ForEach(state.settings.watchedCities) { city in
                HStack {
                    Text(city.name)
                    Spacer()
                    Text(String(format: "%.2f, %.2f", city.latitude, city.longitude))
                        .font(.nomiScaled(size: 11.5))
                        .foregroundColor(.secondary)
                }
            }
            .onDelete { offsets in
                var value = state.settings
                value.watchedCities.remove(atOffsets: offsets)
                state.updateSettings(value)
            }

            HStack {
                TextField("加关注城市，例如 北京", text: $newCity)
                Button("添加") { Task { await addWatchedCity() } }
                    .disabled(newCity.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !cityStatus.isEmpty {
                Text(cityStatus)
                    .font(.nomiScaled(size: 12))
                    .foregroundColor(.secondary)
            }

            Picker("步数目标", selection: Binding(
                get: { state.settings.stepGoal },
                set: { newValue in
                    var value = state.settings
                    value.stepGoal = newValue
                    state.updateSettings(value)
                }
            )) {
                Text("6,000").tag(6000)
                Text("8,000").tag(8000)
                Text("10,000").tag(10000)
                Text("12,000").tag(12000)
            }
        } header: {
            Text("位置与天气")
        } footer: {
            Text("左滑删除关注城市；关注城市后可以直接问「北京天气」。")
        }
    }

    // MARK: 提醒

    @ViewBuilder
    private var reminderSection: some View {
        Section {
            DatePicker("起床", selection: $wakeTime, displayedComponents: .hourAndMinute)
                .onChange(of: wakeTime) { _, newValue in
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                    var value = state.settings
                    value.wakeHour = parts.hour ?? 7
                    value.wakeMinute = parts.minute ?? 0
                    state.updateSettings(value)
                }

            DatePicker("就寝", selection: $bedtimeTime, displayedComponents: .hourAndMinute)
                .onChange(of: bedtimeTime) { _, newValue in
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                    var value = state.settings
                    value.bedtimeHour = parts.hour ?? 23
                    value.bedtimeMinute = parts.minute ?? 0
                    state.updateSettings(value)
                    state.syncBedtimeNotification()
                }

            DatePicker("早报时间", selection: $morningTime, displayedComponents: .hourAndMinute)
                .onChange(of: morningTime) { _, newValue in
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                    var value = state.settings
                    value.morningHour = parts.hour ?? 7
                    value.morningMinute = parts.minute ?? 0
                    state.updateSettings(value)
                    Task { await state.refresh() }
                }
        } header: {
            Text("作息")
        } footer: {
            Text("早报和就寝提醒会用到这些时间。")
        }

        Section {
            noticeToggle("早报", "每天一次，几度、第一件事", \.morningBriefingEnabled)
            noticeToggle("会前 10 分钟", "", \.meetingAlertEnabled)
            noticeToggle("久坐提醒", "每天最多 2 次", \.standUpEnabled)
            noticeToggle("下雨提醒", "当天只说一次", \.rainAlertEnabled)
            noticeToggle("就寝提醒", "", \.bedtimeAlertEnabled)
        } header: {
            Text("主动提醒")
        } footer: {
            Text("统一排程，每天最多 3 条，同一件事 24 小时不重复。")
        }
    }

    private func noticeToggle(_ title: String,
                              _ subtitle: String,
                              _ key: WritableKeyPath<AppSettings, Bool>) -> some View {
        Toggle(isOn: Binding(
            get: { state.settings[keyPath: key] },
            set: { newValue in
                var value = state.settings
                value[keyPath: key] = newValue
                state.updateSettings(value)
                if newValue {
                    Task {
                        _ = await NotificationService.requestPermission()
                        await state.refresh()
                    }
                }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.nomiScaled(size: 11.5))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: 外观

    private var appearanceSection: some View {
        Section {
            Picker("外观", selection: Binding(
                get: { state.settings.appearance },
                set: { newValue in
                    var value = state.settings
                    value.appearance = newValue
                    state.updateSettings(value)
                }
            )) {
                Text("跟随系统").tag(AppearanceMode.system)
                Text("浅色").tag(AppearanceMode.light)
                Text("深色").tag(AppearanceMode.dark)
            }

            Toggle("跟着你看", isOn: Binding(
                get: { state.settings.followFace },
                set: { newValue in
                    var value = state.settings
                    value.followFace = newValue
                    state.updateSettings(value)
                    state.setFaceFollow(newValue)
                }
            ))
        } header: {
            Text("外观与跟随")
        } footer: {
            Text("跟着你看会用到前置摄像头，画面只在设备上处理。")
        }
    }

    // MARK: 玩

    private var playSection: some View {
        Section {
            Button("物理盒子") { showPhysicsBox = true }

        } header: {
            Text("玩")
        } footer: {
            Text("物理盒子在 App 里玩；锁屏不做持续动画。")
        }
    }

    // MARK: 存取

    private func loadAll() {
        apiKeyInput = ""
        editingKey = (Keychain.load("deepseek.key") ?? "").isEmpty
        cityInput = state.settings.cityName
        nicknameInput = state.settings.nickname

        morningTime = Calendar.current.date(bySettingHour: state.settings.morningHour,
                                            minute: state.settings.morningMinute,
                                            second: 0, of: Date()) ?? Date()
        wakeTime = Calendar.current.date(bySettingHour: state.settings.wakeHour,
                                         minute: state.settings.wakeMinute,
                                         second: 0, of: Date()) ?? Date()
        bedtimeTime = Calendar.current.date(bySettingHour: state.settings.bedtimeHour,
                                            minute: state.settings.bedtimeMinute,
                                            second: 0, of: Date()) ?? Date()
    }

    private func saveKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        Keychain.save(trimmed, for: "deepseek.key")
        if (Keychain.load("deepseek.key") ?? "") == trimmed {
            editingKey = false
            apiKeyInput = ""
        }
    }

    private func saveCity() async {
        let name = cityInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        guard let found = await GeocodingService.search(name) else {
            cityStatus = "没找到「\(name)」"
            return
        }

        var value = state.settings
        value.cityName = found.name
        value.latitude = found.latitude
        value.longitude = found.longitude
        state.updateSettings(value)
        cityStatus = "已改成 \(found.name)"
        await state.refresh()
    }

    private func addWatchedCity() async {
        let name = newCity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        guard let found = await GeocodingService.search(name) else {
            cityStatus = "没找到「\(name)」"
            return
        }

        var value = state.settings
        guard !value.watchedCities.contains(where: { $0.name == found.name }) else {
            cityStatus = "已经加过 \(found.name)"
            return
        }

        value.watchedCities.append(found)
        state.updateSettings(value)
        newCity = ""
        cityStatus = "已添加 \(found.name)"
    }

    /// 只显示尾部 4 位，别把整串 key 摊在屏幕上
    private var keyDisplay: String {
        let key = Keychain.load("deepseek.key") ?? ""
        guard !key.isEmpty else { return "未设置" }
        return "sk-····" + String(key.suffix(4))
    }
}
