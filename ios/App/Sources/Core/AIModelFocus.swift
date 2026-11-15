import Foundation

enum AIModelFocus {
    private static let keywords = [
        "openai", "codex", "chatgpt", "gpt-5", "gpt5", "sora",
        "claude", "anthropic", "gemini", "deepseek", "深度求索",
        "qwen", "通义", "豆包", "doubao", "seed", "火山引擎",
        "llama", "grok", "kimi", "月之暗面", "大模型", "基础模型",
        "开源模型", "多模态", "世界模型", "智能体", "agent"
    ]

    static func filter(_ articles: [NewsArticle]) -> [NewsArticle] {
        articles.filter { article in
            let text = (article.title + " " + article.source).lowercased()
            return keywords.contains { text.contains($0) }
        }
    }
}

