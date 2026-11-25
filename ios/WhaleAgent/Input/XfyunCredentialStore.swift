import Foundation
import Security

struct XfyunCredentials {
    let appId: String
    let apiKey: String
    let apiSecret: String
}

enum XfyunCredentialStore {
    private static let service = "whale.xfyun"

    static var current: XfyunCredentials? {
        let values = (
            value(account: "app-id"),
            value(account: "api-key"),
            value(account: "api-secret")
        )
        guard
            let appId = values.0, !appId.isEmpty,
            let apiKey = values.1, !apiKey.isEmpty,
            let apiSecret = values.2, !apiSecret.isEmpty
        else { return nil }
        return XfyunCredentials(appId: appId, apiKey: apiKey, apiSecret: apiSecret)
    }

    static func save(appId: String, apiKey: String, apiSecret: String) throws {
        let appId = appId.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiSecret = apiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appId.isEmpty, !apiKey.isEmpty, !apiSecret.isEmpty else {
            throw ToolExecutionError(code: "xfyun_credentials_incomplete", message: "请完整填写讯飞 App ID、API Key 和 API Secret。")
        }
        try saveValue(appId, account: "app-id")
        try saveValue(apiKey, account: "api-key")
        try saveValue(apiSecret, account: "api-secret")
    }

    static func clear() throws {
        for account in ["app-id", "api-key", "api-secret"] {
            let status = SecItemDelete(query(account: account) as CFDictionary)
            guard [errSecSuccess, errSecItemNotFound].contains(status) else {
                throw ToolExecutionError(code: "keychain_failed", message: "讯飞凭据没有删除成功，请重试。")
            }
        }
    }

    private static func value(account: String) -> String? {
        var fields = query(account: account)
        fields[kSecReturnData as String] = true
        fields[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(fields as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func saveValue(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let base = query(account: account)
        let status = SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var fields = base
            fields[kSecValueData as String] = data
            fields[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(fields as CFDictionary, nil) == errSecSuccess else {
                throw ToolExecutionError(code: "keychain_failed", message: "讯飞凭据没有保存成功，请重试。")
            }
        } else if status != errSecSuccess {
            throw ToolExecutionError(code: "keychain_failed", message: "讯飞凭据没有保存成功，请重试。")
        }
    }

    private static func query(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
