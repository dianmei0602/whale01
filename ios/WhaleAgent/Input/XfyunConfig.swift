import Foundation

struct XfyunConfig {
    enum Source: Equatable {
        case keychain
        case embedded
    }

    let appId: String
    let apiKey: String
    let apiSecret: String
    var source: Source = .embedded

    static let ttsVoice = XfyunTTSRequest.voice
    static let ttsVoiceName = "叶子 · x4_yezi"

    static var current: XfyunConfig? {
        if let credentials = XfyunCredentialStore.current {
            return XfyunConfig(
                appId: credentials.appId,
                apiKey: credentials.apiKey,
                apiSecret: credentials.apiSecret,
                source: .keychain
            )
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

    static var currentCredentials: XfyunCredentials? {
        guard let current else { return nil }
        return XfyunCredentials(appId: current.appId, apiKey: current.apiKey, apiSecret: current.apiSecret)
    }

    static var isConfigured: Bool { current != nil }

    static var statusText: String {
        guard let current else { return "讯飞未配置 · 使用系统语音" }
        let source = current.source == .keychain ? "本机钥匙串" : "构建配置"
        return "讯飞 \(ttsVoiceName) · \(source)"
    }
}
