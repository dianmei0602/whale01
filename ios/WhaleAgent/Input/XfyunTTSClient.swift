import CryptoKit
import Foundation

enum XfyunTTSRequest {
    static let voice = "x4_yezi"

    static func payload(appId: String, text: String) -> [String: Any] {
        [
            "common": ["app_id": appId],
            "business": [
                "aue": "lame",
                "sfl": 1,
                "vcn": voice,
                "tte": "UTF8",
                "speed": 50,
                "volume": 50,
                "pitch": 50
            ],
            "data": [
                "status": 2,
                "text": Data(text.utf8).base64EncodedString()
            ]
        ]
    }
}

final class XfyunTTSClient {
    private struct Response: Decodable {
        let code: Int
        let message: String?
        let data: AudioData?
    }

    private struct AudioData: Decodable {
        let audio: String?
        let status: Int?
    }

    private let config: XfyunCredentials
    private let host = "tts-api.xfyun.cn"

    init?(config: XfyunCredentials? = XfyunConfig.currentCredentials) {
        guard let config else { return nil }
        self.config = config
    }

    func synthesize(_ text: String) async throws -> Data {
        guard let url = authorizationURL() else {
            throw NSError(domain: "XfyunTTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法生成讯飞语音合成鉴权地址"])
        }
        let socket = URLSession.shared.webSocketTask(with: url)
        socket.resume()
        defer { socket.cancel(with: .normalClosure, reason: nil) }
        let timeout = Task {
            do {
                try await Task.sleep(nanoseconds: 20_000_000_000)
                socket.cancel(with: .goingAway, reason: nil)
            } catch {}
        }
        defer { timeout.cancel() }

        let boundedText = Self.utf8Bounded(text, maxBytes: 7_800)
        let payload = XfyunTTSRequest.payload(appId: config.appId, text: boundedText)
        let requestData = try JSONSerialization.data(withJSONObject: payload)
        guard let requestText = String(data: requestData, encoding: .utf8) else {
            throw NSError(domain: "XfyunTTS", code: -2, userInfo: [NSLocalizedDescriptionKey: "讯飞语音请求编码失败"])
        }
        try await socket.send(.string(requestText))

        return try await withTaskCancellationHandler {
            var audio = Data()
            while true {
                let message = try await socket.receive()
                let data: Data
                switch message {
                case .string(let text):
                    data = Data(text.utf8)
                case .data(let value):
                    data = value
                @unknown default:
                    continue
                }
                let response = try JSONDecoder().decode(Response.self, from: data)
                guard response.code == 0 else {
                    throw NSError(
                        domain: "XfyunTTS",
                        code: response.code,
                        userInfo: [NSLocalizedDescriptionKey: response.message ?? "讯飞语音合成失败（\(response.code)）"]
                    )
                }
                if let chunk = response.data?.audio, let decoded = Data(base64Encoded: chunk) {
                    audio.append(decoded)
                }
                if response.data?.status == 2 { break }
            }
            guard !audio.isEmpty else {
                throw NSError(domain: "XfyunTTS", code: -3, userInfo: [NSLocalizedDescriptionKey: "讯飞没有返回音频数据"])
            }
            return audio
        } onCancel: {
            socket.cancel(with: .goingAway, reason: nil)
        }
    }

    private func authorizationURL() -> URL? {
        let date = Self.rfc1123(Date())
        let origin = "host: \(host)\ndate: \(date)\nGET /v2/tts HTTP/1.1"
        let key = SymmetricKey(data: Data(config.apiSecret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(origin.utf8), using: key)
        let signatureBase64 = Data(signature).base64EncodedString()
        let authorization = "api_key=\"\(config.apiKey)\", algorithm=\"hmac-sha256\", headers=\"host date request-line\", signature=\"\(signatureBase64)\""
        let encodedAuth = Data(authorization.utf8).base64EncodedString()

        var components = URLComponents()
        components.scheme = "wss"
        components.host = host
        components.path = "/v2/tts"
        components.queryItems = [
            URLQueryItem(name: "authorization", value: encodedAuth),
            URLQueryItem(name: "date", value: date),
            URLQueryItem(name: "host", value: host)
        ]
        return components.url
    }

    private static func rfc1123(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.string(from: date)
    }

    private static func utf8Bounded(_ text: String, maxBytes: Int) -> String {
        let bytes = Array(text.utf8)
        guard bytes.count > maxBytes else { return text }
        var end = maxBytes
        while end > 0 {
            if let value = String(bytes: bytes[0..<end], encoding: .utf8) {
                return value
            }
            end -= 1
        }
        return ""
    }
}
