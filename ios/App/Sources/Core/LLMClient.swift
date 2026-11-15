import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 走 DeepSeek 的 OpenAI 兼容接口。
/// 只用它"怎么说"，不靠它"决定做什么"——规则引擎才是决策层。
struct LLMClient {
    var apiKey: String
    var model: String = "deepseek-chat"

    private var endpoint: URL {
        URL(string: "https://api.deepseek.com/chat/completions")!
    }

    enum Failure: Error {
        case badStatus(Int)
        case empty
        case decode
    }

    /// 单轮（兼容老调用）
    func chat(system: String, user: String) async throws -> String {
        let messages: [[String: String]] = [
            ["role": "system", "content": system],
            ["role": "user", "content": user]
        ]
        return try await post(messages)
    }

    /// 多轮：带上最近的聊天记录，它才记得你说过什么
    func chat(system: String, history: [ChatTurn]) async throws -> String {
        var messages: [[String: String]] = [
            ["role": "system", "content": system]
        ]

        for turn in history {
            messages.append([
                "role": turn.mine ? "user" : "assistant",
                "content": turn.text
            ])
        }

        return try await post(messages)
    }

    private func post(_ messages: [[String: String]]) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.75,
            "max_tokens": 320,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw Failure.badStatus(code)
        }

        struct Envelope: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }

        guard let parsed = try? JSONDecoder().decode(Envelope.self, from: data) else {
            throw Failure.decode
        }
        let text = parsed.choices.first?.message.content ?? ""
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.empty }
        return trimmed
    }
}