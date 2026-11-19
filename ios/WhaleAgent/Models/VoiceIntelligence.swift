import Foundation

struct VoiceCorrection: Identifiable, Equatable {
    let id: String
    let original: String
    let replacement: String
    let reason: String
}

struct VoiceDiagnostic: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
}

struct VoiceDraftAnalysis: Equatable {
    let rawText: String
    let correctedText: String
    let corrections: [VoiceCorrection]
    let intents: [String]
    let diagnostics: [VoiceDiagnostic]
    let confidence: Double?

    var needsReview: Bool {
        !corrections.isEmpty || intents.count > 1 || (confidence.map { $0 < 0.78 } ?? false)
    }
}

final class PersonalLanguageStore {
    static let shared = PersonalLanguageStore()
    private let storageKey = "whale.voice.personalLanguage.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func terms() -> [String: String] {
        defaults.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }

    func set(spoken: String, intended: String) {
        let source = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = intended.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty, !target.isEmpty, source != target else { return }
        var values = terms()
        values[source] = target
        defaults.set(values, forKey: storageKey)
    }

    func remove(spoken: String) {
        var values = terms()
        values.removeValue(forKey: spoken)
        defaults.set(values, forKey: storageKey)
    }
}

enum VoiceDraftAnalyzer {
    private static let builtInCorrections: [(String, String, String)] = [
        ("deep seek", "DeepSeek", "产品名"),
        ("deepseek", "DeepSeek", "产品名"),
        ("讯飞星火", "讯飞", "产品名"),
        ("爱屁屁", "App", "常见听写")
    ]

    static func analyze(
        _ rawText: String,
        engine: String,
        elapsed: TimeInterval?,
        confidence: Double? = nil,
        personalTerms: [String: String] = PersonalLanguageStore.shared.terms()
    ) -> VoiceDraftAnalysis {
        let raw = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        var text = raw
        var corrections: [VoiceCorrection] = []
        let replacements = builtInCorrections + personalTerms
            .sorted { $0.key.count > $1.key.count }
            .map { ($0.key, $0.value, "个人词库") }

        for (spoken, replacement, reason) in replacements {
            guard text.localizedCaseInsensitiveContains(spoken) else { continue }
            let before = text
            text = text.replacingOccurrences(
                of: spoken,
                with: replacement,
                options: [.caseInsensitive]
            )
            if before != text {
                corrections.append(
                    VoiceCorrection(
                        id: "\(spoken)-\(replacement)",
                        original: spoken,
                        replacement: replacement,
                        reason: reason
                    )
                )
            }
        }

        let intents = splitIntents(text)
        var diagnostics = [
            VoiceDiagnostic(id: "engine", label: "听写", value: engine),
            VoiceDiagnostic(id: "length", label: "识别", value: "\(text.count) 字")
        ]
        if let elapsed, elapsed > 0 {
            diagnostics.append(
                VoiceDiagnostic(id: "elapsed", label: "耗时", value: String(format: "%.1f 秒", elapsed))
            )
        }
        if intents.count > 1 {
            diagnostics.append(
                VoiceDiagnostic(id: "intents", label: "意图", value: "\(intents.count) 项")
            )
        }
        if let confidence {
            diagnostics.append(
                VoiceDiagnostic(
                    id: "confidence",
                    label: "置信度",
                    value: "\(Int((confidence * 100).rounded()))%"
                )
            )
        }

        return VoiceDraftAnalysis(
            rawText: raw,
            correctedText: text,
            corrections: corrections,
            intents: intents,
            diagnostics: diagnostics,
            confidence: confidence
        )
    }

    static func splitIntents(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let separators = ["然后", "接着", "顺便", "并且", "同时", "再帮我", "再"]
        var chunks = [trimmed]
        for separator in separators {
            chunks = chunks.flatMap { chunk in
                chunk.components(separatedBy: separator)
            }
        }
        let values = chunks
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "，,。；; ")) }
            .filter { $0.count >= 2 }
        return values.isEmpty ? [trimmed] : values
    }
}

struct VoiceCaptureTimeline {
    private(set) var startedAt: Date?
    private(set) var stoppedAt: Date?

    mutating func start(at date: Date = Date()) {
        startedAt = date
        stoppedAt = nil
    }

    mutating func stop(at date: Date = Date()) {
        if startedAt != nil { stoppedAt = date }
    }

    mutating func reset() {
        startedAt = nil
        stoppedAt = nil
    }

    var duration: TimeInterval? {
        guard let startedAt else { return nil }
        return max(0, (stoppedAt ?? Date()).timeIntervalSince(startedAt))
    }
}
