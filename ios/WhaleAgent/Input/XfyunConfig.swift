import Foundation

struct XfyunConfig {
    let appId: String
    let apiKey: String
    let apiSecret: String

    static let ttsVoice = "x4_yezi"
    static let ttsVoiceName = "小露"
    static let ttsEndpoint = "wss://tts-api.xfyun.cn/v2/tts"

    static var current: XfyunConfig? {
        if let stored = XfyunCredentialStore.load() {
            return stored
        }
        let info = Bundle.main.infoDictionary ?? [:]
        func value(_ key: String) -> String {
            if let raw = info[key] as? String { return raw }
            return ProcessInfo.processInfo.environment[key] ?? ""
        }
        let appId = value("XFYUN_APP_ID").trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = value("XFYUN_API_KEY").trimmingCharacters(in: .whitespacesAndNewlines)
        let apiSecret = value("XFYUN_API_SECRET").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appId.isEmpty, !apiKey.isEmpty, !apiSecret.isEmpty else { return nil }
        return XfyunConfig(appId: appId, apiKey: apiKey, apiSecret: apiSecret)
    }

    static var isConfigured: Bool { current != nil }

    static var statusText: String {
        isConfigured ? "讯飞小露 x4_yezi 已配置" : "讯飞小露未配置（App 朗读暂不可用）"
    }
}
