import Foundation

/// 一句话 → 待办动作。
///
/// 纯逻辑，不碰 EventKit：这样可以在本地把常见说法跑一遍，
/// 看清楚哪句会被当成"新建"、哪句会被当成"查询"。
enum TodoCommand: Equatable {
    case create(title: String, due: Date?)
    case queryToday
    case queryAll
    case complete(query: String)
    case none
}

enum TodoParser {

    // MARK: - 词表

    private static let todoNouns = ["待办", "代办", "todo", "to do", "清单"]

    /// 这些词出现，说明讲的是"日程"，不是"待办"
    private static let eventNouns = [
        "会", "会议", "开会", "见面", "面试", "评审", "汇报", "对稿",
        "吃饭", "饭局", "约会", "健身", "上课", "课程", "挂号", "就诊",
        "接机", "送机", "出差", "航班", "高铁", "火车", "买票", "看牙"
    ]

    private static let completeVerbs = [
        "做完了", "做完", "做掉了", "做了", "完成了", "完成",
        "搞定了", "搞定", "勾掉", "勾了", "打勾", "删掉", "删了", "划掉"
    ]

    private static let queryMarkers = ["？", "?", "吗", "多少", "几条", "几件", "哪些", "还有什么", "有什么", "列一下", "看看", "看一下", "剩"]

    private static let allMarkers = ["全部", "所有", "这周", "本周", "最近", "整个", "所有待办"]

    private static let remindPhrases = ["提醒我", "提醒一下", "记得", "别忘了", "别忘", "帮我记", "记一下"]

    /// 建待办时要剥掉的引导词（长词优先，避免"加个待办"只剥一半）
    private static let triggerTokens = [
        "加一个待办", "加个待办", "新增待办", "添加待办", "新建待办", "记个待办",
        "待办事项", "待办", "代办", "清单",
        "帮我记一下", "帮我记", "记一下", "记个", "记得", "提醒我", "提醒一下",
        "别忘了", "别忘", "帮我", "给我", "一下"
    ]

    private static let dayTokens = [
        "大后天", "后天", "今天", "明天", "明早", "明晚", "今晚", "今天晚些时候",
        "上午", "中午", "下午", "晚上", "早上",
        "周一", "周二", "周三", "周四", "周五", "周六", "周日", "周天",
        "星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日", "星期天",
        "下周", "本周", "这周"
    ]

    // MARK: - 主入口

    static func parse(_ text: String,
                      now: Date = Date(),
                      calendar: Calendar = .current) -> TodoCommand {

        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return .none }
        let lower = raw.lowercased()

        // ① 完成：有完成动作词，而且不是在问
        if let verb = completeVerbs.first(where: { raw.contains($0) }) {
            let isQuestion = raw.contains("？") || raw.contains("?") || raw.hasSuffix("吗")
            if !isQuestion {
                let query = queryFragment(raw, removing: [verb])
                if !query.isEmpty { return .complete(query: query) }
            }
        }

        let hasTodoNoun = todoNouns.contains { lower.contains($0) }
        // 「今天还有什么没做」不提"待办"两个字，但意思一样
        let asksUndone = ["没做", "要做", "没完成", "还没做", "剩下"].contains { raw.contains($0) }
        let mentionsTodo = hasTodoNoun || asksUndone

        // ② 查询：提到待办 + 有疑问/列全部
        if mentionsTodo {
            let asksAll = allMarkers.contains { raw.contains($0) }
            let asksList = queryMarkers.contains { raw.contains($0) }
            if asksAll { return .queryAll }
            if asksList { return .queryToday }
        }

        // ③ 新建：提到待办，或"提醒我/记得"且不是在说日程
        if hasTodoNoun || (isRemindPhrase(raw) && !asksUndone) {
            let due = ScheduleParser.parse(raw, now: now, calendar: calendar)?.start
            let title = extractTitle(raw)
            if !title.isEmpty { return .create(title: title, due: due) }
        }

        return .none
    }

    // MARK: - 细则

    /// 「提醒我」这类说法，如果同时出现日程名词就不算待办
    static func isRemindPhrase(_ text: String) -> Bool {
        guard remindPhrases.contains(where: { text.contains($0) }) else { return false }
        return !eventNouns.contains { text.contains($0) }
    }

    /// 从「做完牛奶那条」里剥出「牛奶」
    static func queryFragment(_ text: String, removing verbs: [String]) -> String {
        var s = text
        for verb in verbs { s = s.replacingOccurrences(of: verb, with: " ") }
        for token in ["那条", "这条", "这个", "那个", "的待办", "待办", "代办", "把", "帮我", "给它", "标成完成", "标记"] {
            s = s.replacingOccurrences(of: token, with: " ")
        }
        return clean(s)
    }

    /// 从整句话里抽出待办标题
    static func extractTitle(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 冒号后面通常就是要做的事，最干净
        if let range = s.range(of: "：") ?? s.range(of: ":") {
            let after = String(s[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !after.isEmpty { s = after }
        }

        // 去掉时间短语（用解析器的匹配结果，避免误删标题里的数字）
        if let (_, _, consumed) = ScheduleParser.parseTime(s), !consumed.isEmpty {
            s = s.replacingOccurrences(of: consumed, with: " ")
        }
        for token in dayTokens { s = s.replacingOccurrences(of: token, with: " ") }
        for token in triggerTokens { s = s.replacingOccurrences(of: token, with: " ") }

        return clean(s)
    }

    /// 去掉标点、多余空格
    private static func clean(_ text: String) -> String {
        var s = text
        for mark in ["，", "。", "！", "？", "；", "、", ",", ".", "!", "?", ";", "~", "～"] {
            s = s.replacingOccurrences(of: mark, with: " ")
        }
        s = s.replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return s
    }
}
