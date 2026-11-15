import Foundation
import Security

enum XfyunCredentialStore {
    private static let service = "com.whale01.agent.xfyun"
    private static let account = "credentials"

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static func load() -> XfyunConfig? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let stored = try? JSONDecoder().decode(StoredCredentials.self, from: data),
              !stored.appId.isEmpty,
              !stored.apiKey.isEmpty,
              !stored.apiSecret.isEmpty else {
            return nil
        }
        return XfyunConfig(
            appId: stored.appId,
            apiKey: stored.apiKey,
            apiSecret: stored.apiSecret
        )
    }

    static func save(_ config: XfyunConfig) throws {
        let data = try JSONEncoder().encode(
            StoredCredentials(
                appId: config.appId,
                apiKey: config.apiKey,
                apiSecret: config.apiSecret
            )
        )
        SecItemDelete(query as CFDictionary)
        var request = query
        request[kSecValueData as String] = data
        request[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(request as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "讯飞密钥保存失败（\(status)）"]
            )
        }
    }

    static func clear() {
        SecItemDelete(query as CFDictionary)
    }

    private struct StoredCredentials: Codable {
        let appId: String
        let apiKey: String
        let apiSecret: String
    }
}
