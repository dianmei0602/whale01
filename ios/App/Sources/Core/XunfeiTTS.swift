import Foundation
import AVFoundation
import CryptoKit

/// 讯飞在线语音合成（WebSocket）。
///
/// 鉴权用的是**新版方案**（我用真实密钥在本地实测过）：
/// ```
/// Authorization: api_key="...", algorithm="hmac-sha256",
///                headers="host date request-line", signature="..."
/// Date: <RFC1123 GMT>
/// ```
/// 早期文档里那套「签名拼进 query 的 authorization 参数」现在会返回
/// 401 `enforced header 'host' not used for signature creation`，不要再照抄。
enum XunfeiTTS {

    static let host = "tts-api.xfyun.cn"
    static let path = "/v2/tts"

    // 内置一份密钥：用户不填也能直接用（设置页填了会覆盖）
    private static let bundledAppId  = ""
    private static let bundledApiKey = ""
    private static let bundledSecret = ""

    struct Credentials {
        let appId: String
        let apiKey: String
        let secret: String
    }

    static var isConfigured: Bool { credentials() != nil }

    static func credentials() -> Credentials? {
        let appId = (Keychain.load("xunfei.appid") ?? "").isEmpty
            ? bundledAppId : (Keychain.load("xunfei.appid") ?? bundledAppId)
        let apiKey = (Keychain.load("xunfei.apikey") ?? "").isEmpty
            ? bundledApiKey : (Keychain.load("xunfei.apikey") ?? bundledApiKey)
        let secret = (Keychain.load("xunfei.secret") ?? "").isEmpty
            ? bundledSecret : (Keychain.load("xunfei.secret") ?? bundledSecret)

        guard !appId.isEmpty, !apiKey.isEmpty, !secret.isEmpty else { return nil }
        return Credentials(appId: appId, apiKey: apiKey, secret: secret)
    }

    // MARK: - 合成

    static func synthesize(text: String,
                           voice: String,
                           speed: Int,
                           pitch: Int,
                           volume: Int) async throws -> Data {
        guard let credentials = credentials() else { throw XunfeiError.notConfigured }

        // 签名和 Date 头必须用同一个时间字符串；分两次取会跨秒对不上
        let date = gmtDate()

        var request = URLRequest(url: URL(string: "wss://\(host)\(path)")!)
        request.setValue(authorizationHeader(credentials: credentials, date: date),
                         forHTTPHeaderField: "Authorization")
        request.setValue(date, forHTTPHeaderField: "Date")

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: request)
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil) }

        let payload: [String: Any] = [
            "common": ["app_id": credentials.appId],
            "business": [
                "aue": "lame",
                "sfl": 1,
                "auf": "audio/L16;rate=16000",
                "vcn": voice,
                "speed": speed,
                "pitch": pitch,
                "volume": volume,
                "tte": "UTF8"
            ],
            "data": [
                "status": 2,
                "text": Data(text.utf8).base64EncodedString()
            ]
        ]

        let json = try JSONSerialization.data(withJSONObject: payload)
        guard let jsonText = String(data: json, encoding: .utf8) else {
            throw XunfeiError.badPayload
        }
        try await task.send(.string(jsonText))

        var audio = Data()
        var finished = false
        var rounds = 0

        while !finished {
            let message = try await task.receive()
            rounds += 1
            if rounds > 300 { break }

            // 用 var + continue：@unknown default 里的 break 只跳出 switch，
            // 常量还没赋值就往下走会报 "constant used before being initialized"
            var payload = Data()
            switch message {
            case .data(let value):
                payload = value
            case .string(let text):
                payload = Data(text.utf8)
            @unknown default:
                finished = true
                continue
            }

            guard let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
                continue
            }

            if let code = object["code"] as? Int, code != 0 {
                let message = object["message"] as? String ?? ""
                throw XunfeiError.server(code: code, message: message)
            }

            if let chunk = object["data"] as? [String: Any] {
                if let base64 = chunk["audio"] as? String,
                   let decoded = Data(base64Encoded: base64) {
                    audio.append(decoded)
                }
                if let status = chunk["status"] as? Int, status == 2 {
                    finished = true
                }
            }
        }

        guard !audio.isEmpty else { throw XunfeiError.emptyAudio }
        return audio
    }

    // MARK: - 鉴权

    private static func gmtDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter.string(from: Date())
    }

    /// 新版签名：放 Authorization 头，不走 query
    private static func authorizationHeader(credentials: Credentials, date: String) -> String {
        let origin = "host: \(host)\ndate: \(date)\nGET \(path) HTTP/1.1"

        let key = SymmetricKey(data: Data(credentials.secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(origin.utf8), using: key)
        let signature = Data(mac).base64EncodedString()

        return "api_key=\"\(credentials.apiKey)\", "
            + "algorithm=\"hmac-sha256\", "
            + "headers=\"host date request-line\", "
            + "signature=\"\(signature)\""
    }

    // MARK: - 播放

    @MainActor
    static func play(_ data: Data) -> AVAudioPlayer? {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
        try? session.setActive(true, options: [])

        guard let player = try? AVAudioPlayer(data: data) else { return nil }
        player.volume = 0.9
        player.prepareToPlay()
        player.play()
        return player
    }

    // MARK: - 错误

    enum XunfeiError: LocalizedError {
        case notConfigured
        case badPayload
        case emptyAudio
        case server(code: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "还没填讯飞的密钥"
            case .badPayload:    return "请求构造失败"
            case .emptyAudio:    return "讯飞没返回音频"
            case .server(let code, let message):
                return "讯飞返回 \(code)：\(message)"
            }
        }
    }
}
