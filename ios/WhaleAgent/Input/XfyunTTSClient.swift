import CryptoKit
import Foundation

enum XfyunTTSError: LocalizedError {
    case invalidResponse
    case service(Int, String?)
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "讯飞朗读返回了无法识别的数据"
        case .service(let code, let message):
            return "讯飞朗读失败（\(code)）：\(message ?? "未知错误")"
        case .emptyAudio:
            return "讯飞朗读没有返回音频"
        }
    }
}

enum XfyunTTSClient {
    private static let host = "tts-api.xfyun.cn"
    private static let path = "/v2/tts"

    private struct Response: Decodable {
        let code: Int
        let message: String?
        let data: Payload?
    }

    private struct Payload: Decodable {
        let audio: String?
        let status: Int?
    }

    static func synthesize(_ text: String, config: XfyunConfig) async throws -> Data {
        guard let url = authorizationURL(config: config) else {
            throw XfyunTTSError.invalidResponse
        }
        let socket = URLSession.shared.webSocketTask(with: url)
        socket.resume()
        defer {
            socket.cancel(with: .normalClosure, reason: nil)
        }

        let encodedText = Data(text.utf8).base64EncodedString()
        let payload: [String: Any] = [
            "common": ["app_id": config.appId],
            "business": [
                "aue": "lame",
                "sfl": 1,
                "auf": "audio/L16;rate=16000",
                "speed": 55,
                "volume": 65,
                "pitch": 48,
                "tte": "UTF8",
                "bgs": 0,
                "reg": "2",
                "rdn": "3",
                "vcn": XfyunConfig.ttsVoice
            ],
            "data": [
                "status": 2,
                "text": encodedText
            ]
        ]
        let request = try JSONSerialization.data(withJSONObject: payload)
        guard let requestText = String(data: request, encoding: .utf8) else {
            throw XfyunTTSError.invalidResponse
        }
        try await socket.send(.string(requestText))

        var audio = Data()
        while true {
            try Task.checkCancellation()
            let message = try await socket.receive()
            let data: Data
            switch message {
            case .data(let value):
                data = value
            case .string(let value):
                data = Data(value.utf8)
            @unknown default:
                throw XfyunTTSError.invalidResponse
            }
            let response = try JSONDecoder().decode(Response.self, from: data)
            guard response.code == 0 else {
                throw XfyunTTSError.service(response.code, response.message)
            }
            if let chunk = response.data?.audio, let decoded = Data(base64Encoded: chunk) {
                audio.append(decoded)
            }
            if response.data?.status == 2 {
                break
            }
        }
        guard !audio.isEmpty else {
            throw XfyunTTSError.emptyAudio
        }
        return audio
    }

    static func splitText(_ text: String, limit: Int = 1600) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let characters = Array(normalized.joined(separator: "。"))
        guard characters.count > limit else {
            return characters.isEmpty ? [] : [String(characters)]
        }
        return stride(from: 0, to: characters.count, by: limit).map {
            String(characters[$0..<min($0 + limit, characters.count)])
        }
    }

    static func authorizationURL(config: XfyunConfig, now: Date = Date()) -> URL? {
        let date = rfc1123(now)
        let origin = "host: \(host)\ndate: \(date)\nGET \(path) HTTP/1.1"
        let key = SymmetricKey(data: Data(config.apiSecret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(origin.utf8), using: key)
        let authorization = "api_key=\"\(config.apiKey)\", algorithm=\"hmac-sha256\", headers=\"host date request-line\", signature=\"\(Data(signature).base64EncodedString())\""

        var components = URLComponents()
        components.scheme = "wss"
        components.host = host
        components.path = path
        components.queryItems = [
            URLQueryItem(name: "authorization", value: Data(authorization.utf8).base64EncodedString()),
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
}
