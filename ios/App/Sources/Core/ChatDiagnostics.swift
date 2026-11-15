import Foundation

/// 回答诊断：到底走的是模型还是本地规则，为什么失败。
///
/// 侧载装不上 Xcode 调试，所以把关键信息存下来，在设置页直接看。
enum ChatDiagnostics {

    private static let sourceKey = "nomi.chat.source"
    private static let errorKey = "nomi.chat.error"
    private static let previewKey = "nomi.chat.preview"
    private static let atKey = "nomi.chat.at"

    static var source: String {
        UserDefaults.standard.string(forKey: sourceKey) ?? "还没聊过"
    }

    static var lastError: String {
        UserDefaults.standard.string(forKey: errorKey) ?? "—"
    }

    static var preview: String {
        UserDefaults.standard.string(forKey: previewKey) ?? "—"
    }

    static var timeText: String {
        guard let date = UserDefaults.standard.object(forKey: atKey) as? Date else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    static func record(source: String, error: String?, preview: String) {
        let defaults = UserDefaults.standard
        defaults.set(source, forKey: sourceKey)
        defaults.set(error ?? "—", forKey: errorKey)
        defaults.set(String(preview.prefix(80)), forKey: previewKey)
        defaults.set(Date(), forKey: atKey)
    }
}

/// 给 LLMClient 的失败加上人话
extension LLMClient.Failure: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .badStatus(let code):
            switch code {
            case 401: return "key 无效 401"
            case 402: return "余额不足 402"
            case 429: return "请求太频繁 429"
            default:  return "HTTP \(code)"
            }
        case .empty:  return "模型返回空"
        case .decode: return "返回格式看不懂"
        }
    }
}
