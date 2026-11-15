import Foundation

/// 说话时的一小段"情绪节拍"。
///
/// 目的：它念答案时脸不能一直是同一个表情。
/// 把回答切成一个个短句，每句判断该用哪种神态，
/// 再按字数估出时间轴——念到哪一句，脸上就换成那一种。
enum SpeechTone: Equatable {
    case neutral    // 陈述
    case warm       // 温和、安慰
    case cheerful   // 好事、答应了
    case serious    // 提醒、注意
    case worried    // 没拿到、抱歉
    case thinking   // 反问、商量
}

struct SpeechBeat: Equatable {
    let tone: SpeechTone
    /// 这一句本身（调试用，也方便以后做逐句高亮）
    let text: String
    let start: Double
    let end: Double

    var duration: Double { max(0.1, end - start) }
}

enum SpeechPerformance {

    /// 讯飞叶子音色 speed=50 大致每秒 4.5 个字
    static let charsPerSecond: Double = 4.5

    /// 句间停顿
    static let pause: Double = 0.22

    // MARK: - 切句 + 判情绪

    static func beats(for text: String) -> [SpeechBeat] {
        let clauses = split(text)
        var beats: [SpeechBeat] = []
        var cursor: Double = 0

        for clause in clauses {
            let body = clause.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }

            let spoken = Double(body.count) / charsPerSecond
            let duration = max(0.75, spoken)

            beats.append(SpeechBeat(tone: tone(of: body),
                                    text: body,
                                    start: cursor,
                                    end: cursor + duration))
            cursor += duration + pause
        }

        // 一句都没切出来（比如全是符号）：给一个中性节拍
        if beats.isEmpty {
            return [SpeechBeat(tone: .neutral, text: text, start: 0, end: 1.2)]
        }
        return beats
    }

    static func totalDuration(_ beats: [SpeechBeat]) -> Double {
        beats.last?.end ?? 0
    }

    /// elapsed 落在哪个节拍里
    static func beat(at elapsed: Double, in beats: [SpeechBeat]) -> SpeechBeat? {
        if let hit = beats.first(where: { elapsed >= $0.start && elapsed < $0.end }) {
            return hit
        }
        // 句间停顿：延续上一句的神态，别突然弹回中性
        return beats.last { $0.end <= elapsed }
    }

    // MARK: - 情绪判断

    static func tone(of clause: String) -> SpeechTone {
        // ① 抱歉 / 没拿到
        let worried = ["没拿到", "没办法", "不能", "抱歉", "失败", "删不掉",
                       "改不动", "出错", "没找到", "还没", "不确定"]
        if worried.contains(where: { clause.contains($0) }) { return .worried }

        // ② 提醒 / 注意
        let serious = ["注意", "小心", "记得", "别忘了", "别忘", "重要", "提前",
                       "带伞", "早睡", "按时"]
        if serious.contains(where: { clause.contains($0) }) { return .serious }

        // ③ 反问 / 商量
        let asking = ["吗", "呢", "要不要", "是不是", "要不要我", "？", "?"]
        if asking.contains(where: { clause.contains($0) }) { return .thinking }

        // ④ 好事 / 答应
        let cheerful = ["好", "可以", "搞定", "记下了", "改好了", "取消了",
                        "完成", "棒", "不错", "没问题", "已经"]
        if cheerful.contains(where: { clause.contains($0) }) { return .cheerful }

        // ⑤ 安慰 / 亲近
        let warm = ["吧", "先", "慢慢", "辛苦", "休息", "陪你", "别急", "没事"]
        if warm.contains(where: { clause.contains($0) }) { return .warm }

        return .neutral
    }

    // MARK: - 切句

    private static func split(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""

        for character in text {
            current.append(character)

            switch character {
            case "。", "！", "？", "!", "?", "；", ";", "\n":
                result.append(current)
                current = ""
            default:
                break
            }
        }

        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(current)
        }
        return result
    }
}
