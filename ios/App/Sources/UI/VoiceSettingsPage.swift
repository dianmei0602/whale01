import SwiftUI

/// 声音与音色：把 11-11 清理掉的那几个入口补回来。
///
/// 之前只留了一个开关，用户看不出"现在到底用哪套声音、为什么没声"，
/// 也没地方重新填讯飞密钥。这页解决三件事：
/// - 现在用的是什么声音（讯飞·叶子 / 系统语音）
/// - 上次为什么失败（`PetVoice.lastError`）
/// - 重新填讯飞 AppID / APIKey / APISecret（只存本机钥匙串）
struct VoiceSettingsPage: View {

    var state: AppState

    @State private var appId = ""
    @State private var apiKey = ""
    @State private var secret = ""
    @State private var status = ""
    @State private var testing = false

    var body: some View {
        Form {
            switchSection
            statusSection
            keySection
            noteSection
        }
        .scrollContentBackground(.hidden)
        .background(CardPalette.screen)
        .navigationTitle("声音与音色")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadKeys)
    }

    // MARK: - 开关

    private var switchSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { state.settings.voiceEnabled },
                set: { newValue in
                    var value = state.settings
                    value.voiceEnabled = newValue
                    state.updateSettings(value)
                    PetVoice.shared.isEnabled = newValue
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("朗读回答")
                    Text("关掉后只显示文字，不出声")
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                }
            }
        } footer: {
            Text("这个开关之前被一次性迁移关掉过，所以老用户升级后默认是静的。打开就会生效。")
        }
    }

    // MARK: - 状态

    private var statusSection: some View {
        Section {
            HStack {
                Text("当前声音")
                Spacer()
                Text(PetVoice.shared.usesXunfei ? "讯飞 · 叶子" : "系统语音")
                    .foregroundColor(PetVoice.shared.usesXunfei ? CardPalette.accent : .secondary)
            }

            if let error = PetVoice.shared.lastError, !error.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("上次失败")
                        .font(.system(size: 13))
                    Text(error)
                        .font(.system(size: 12.5))
                        .foregroundColor(CardPalette.amberInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                preview()
            } label: {
                HStack {
                    Image(systemName: "play.circle")
                    Text(testing ? "正在念…" : "试听一句")
                    Spacer()
                }
                .foregroundColor(CardPalette.accent)
            }
            .disabled(testing)
        } header: {
            Text("状态")
        } footer: {
            Text("试听不受「朗读回答」开关限制。讯飞连不上时会自动用系统语音，这里会显示原因。")
        }
    }

    // MARK: - 密钥

    private var keySection: some View {
        Section {
            SecureField("AppID", text: $appId)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("APIKey", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("APISecret", text: $secret)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("保存") { saveKeys() }
                .disabled(!hasAnyInput)

            Button("清空，改回内置", role: .destructive) { clearKeys() }
        } header: {
            Text("讯飞语音")
        } footer: {
            Text("留空就用 App 内置的密钥；填了会覆盖。三个都只保存在本机钥匙串，不上传。改完点「试听一句」确认能出声。")
        }
    }

    private var noteSection: some View {
        Section {
            if !status.isEmpty {
                Text(status)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Text("公开测试包有时不内置讯飞密钥，这时候朗读会走系统语音——填上你自己的三个值就能恢复叶子音色。")
                .font(.system(size: 12.5))
                .foregroundColor(.secondary)
        } header: {
            Text("说明")
        }
    }

    // MARK: - 动作

    private var hasAnyInput: Bool {
        !appId.trimmingCharacters(in: .whitespaces).isEmpty
            || !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
            || !secret.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func loadKeys() {
        appId = Keychain.load("xunfei.appid") ?? ""
        apiKey = Keychain.load("xunfei.apikey") ?? ""
        secret = Keychain.load("xunfei.secret") ?? ""
        PetVoice.shared.isEnabled = state.settings.voiceEnabled
    }

    private func saveKeys() {
        let id = appId.trimmingCharacters(in: .whitespaces)
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        let sec = secret.trimmingCharacters(in: .whitespaces)

        // 只存填了的；留空表示"用内置"
        if id.isEmpty { Keychain.delete("xunfei.appid") } else { Keychain.save(id, for: "xunfei.appid") }
        if key.isEmpty { Keychain.delete("xunfei.apikey") } else { Keychain.save(key, for: "xunfei.apikey") }
        if sec.isEmpty { Keychain.delete("xunfei.secret") } else { Keychain.save(sec, for: "xunfei.secret") }

        status = PetVoice.shared.usesXunfei ? "已保存，现在用的是讯飞语音" : "已保存，但密钥不完整，仍会用系统语音"
        preview()
    }

    private func clearKeys() {
        Keychain.delete("xunfei.appid")
        Keychain.delete("xunfei.apikey")
        Keychain.delete("xunfei.secret")
        appId = ""
        apiKey = ""
        secret = ""
        status = PetVoice.shared.usesXunfei
            ? "已清空，改回内置密钥"
            : "已清空，且内置密钥不可用，现在会用系统语音"
        preview()
    }

    private func preview() {
        testing = true
        PetVoice.shared.speak("我在，声音开好了。", expression: .calm, force: true)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            testing = false
        }
    }
}
