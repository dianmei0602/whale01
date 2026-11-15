import Foundation

/// 回答引擎：纯逻辑，不碰 UI、不碰网络。
/// 只回答它真的知道的事——不知道就说不知道，不编。
struct AnswerEngine {

    struct Context {
        var cards: [DayCard]
        var temperature: Double?
        var now: Date
        var stage: PetStage
    }

    enum Intent: Equatable {
        case today
        case weather
        case umbrella
        case exercise
        case sleep
        case identity
        case unknown
    }

    static func intent(for text: String) -> Intent {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if matches(t, ["你是谁", "你叫什么", "你能做什么", "你会什么"]) { return .identity }
        if matches(t, ["带伞", "下雨", "雨伞", "淋雨"]) { return .umbrella }
        if matches(t, ["天气", "多少度", "几度", "冷不冷", "热不热"]) { return .weather }
        if matches(t, ["运动", "跑步", "锻炼", "健身", "跑"]) { return .exercise }
        if matches(t, ["睡", "几点睡", "困", "休息"]) { return .sleep }
        if matches(t, ["今天", "什么事", "安排", "干嘛", "做什么"]) { return .today }
        return .unknown
    }

    private static func matches(_ text: String, _ keys: [String]) -> Bool {
        for key in keys where text.contains(key) {
            return true
        }
        return false
    }

    static func answer(to text: String, context: Context) -> String {
        switch intent(for: text) {
        case .identity:
            return "我是它。知道你的天气、日程和该动一动的时候。别的还不会。"

        case .today:
            if context.cards.isEmpty {
                return "今天没什么事。别硬找。"
            }
            let lines = context.cards.prefix(3).map { $0.time + " " + $0.fact }
            return "今天 \(context.cards.count) 件事。" + lines.joined(separator: "；")

        case .weather:
            if let card = context.cards.first(where: { $0.id == "rain" }) {
                return card.fact + "。" + card.advice
            }
            guard let temp = context.temperature else {
                return "天气没拿到。等会儿再问。"
            }
            return "现在 \(Int(temp.rounded()))°，没有雨。"

        case .umbrella:
            if let card = context.cards.first(where: { $0.id == "rain" }) {
                return card.fact + "。" + card.advice
            }
            return "不用带伞。今天没有雨。"

        case .exercise:
            if let card = context.cards.first(where: { $0.id == "sport" || $0.id == "sportLite" }) {
                return card.fact + "。" + card.advice
            }
            return "今天没有合适的运动窗口。要不歇一天。"

        case .sleep:
            if let card = context.cards.first(where: { $0.id == "sleep" }) {
                return card.fact + "。" + card.advice
            }
            return "还早。今晚 23:00 前睡就行。"

        case .unknown:
            return "这个我还不会。现在只会说天气、日程、运动、睡觉这几件事。"
        }
    }
}