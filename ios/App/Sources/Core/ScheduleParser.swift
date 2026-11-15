import Foundation

/// 从一句话里解析出「什么时候」「做什么」。
///
/// 纯逻辑，不碰 SwiftUI / EventKit，所以能在任何平台跑测试。
///
/// 支持的说法：
///   明天下午三点开会
///   后天上午十点半和客户吃饭
///   今晚7点健身
///   周五下午两点产品评审
///   15:30 站会
///   半小时后喝水
///   明天提醒我交周报
struct ParsedSchedule: Equatable {
    let title: String
    let start: Date
}

enum ScheduleParser {

    // MARK: - 主入口

    /// 解析不出时间就返回 nil（调用方应该回一句"几点？"）
    static func parse(_ text: String,
                      now: Date = Date(),
                      calendar: Calendar = .current) -> ParsedSchedule? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        // ① 相对时间：半小时后 / 20分钟后 / 一小时后
        if let relative = parseRelative(normalized, now: now, calendar: calendar) {
            return ParsedSchedule(title: extractTitle(normalized), start: relative)
        }

        // ② 绝对时间：X 点 / X:XX
        guard let (hour, minute, consumed) = parseTime(normalized) else { return nil }

        // ③ 哪一天
        let dayOffset = parseDayOffset(normalized, now: now, calendar: calendar)

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        if let offset = dayOffset {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
            components = calendar.dateComponents([.year, .month, .day], from: day)
        }
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard var start = calendar.date(from: components) else { return nil }

        // 没说是哪天，而且时间已经过了 → 顺延到明天
        if dayOffset == nil, start < now {
            guard let next = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
            start = next
        }

        _ = consumed
        return ParsedSchedule(title: extractTitle(normalized), start: start)
    }

    // MARK: - 时间

    /// 返回 (小时, 分钟, 匹配到的文字)
    static func parseTime(_ text: String) -> (Int, Int, String)? {
        // ① 15:30 / 15：30
        if let r = text.range(of: #"(\d{1,2})\s*[:：]\s*(\d{1,2})"#, options: .regularExpression) {
            let matched = String(text[r])
            let digits = matched.components(separatedBy: CharacterSet(charactersIn: ":："))
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if digits.count == 2, (0...23).contains(digits[0]), (0...59).contains(digits[1]) {
                return (adjustHour(digits[0], in: text, near: r), digits[1], matched)
            }
        }

        // ② X点 / X点半 / X点 Y分
        let pattern = #"(\d{1,2}|[零一二三四五六七八九十两]{1,3})\s*点\s*(半|(\d{1,2})\s*分?)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text,
                                           range: NSRange(text.startIndex..., in: text)),
              let full = Range(match.range, in: text)
        else { return nil }

        let ns = text as NSString
        let hourText = ns.substring(with: match.range(at: 1))
        guard var hour = Int(hourText) ?? chineseNumber(hourText) else { return nil }

        var minute = 0
        if match.range(at: 2).location != NSNotFound {
            let suffix = ns.substring(with: match.range(at: 2))
            if suffix.contains("半") {
                minute = 30
            } else if match.range(at: 3).location != NSNotFound {
                minute = Int(ns.substring(with: match.range(at: 3))) ?? 0
            }
        }

        hour = adjustHour(hour, in: text, near: full)
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return (hour, minute, String(text[full]))
    }

    /// 把「下午三点」的 3 修成 15
    private static func adjustHour(_ hour: Int, in text: String, near range: Range<String.Index>) -> Int {
        // 只看时间词前面 4 个字
        let head = text[text.startIndex..<range.lowerBound]
        let tail = String(head.suffix(4))

        // 注意「今晚」「明早」这种两字词：不能用「晚上」去匹配
        if tail.contains("凌晨") { return hour == 12 ? 0 : hour }

        if tail.contains("中午") { return hour < 11 ? hour + 12 : hour }

        // 下午 / 傍晚 / 晚 / 夜
        if tail.contains("下午") || tail.contains("傍晚")
            || tail.contains("晚") || tail.contains("夜") {
            return hour < 12 ? hour + 12 : hour
        }

        // 上午 / 早上 / 早
        if tail.contains("上午") || tail.contains("早上") || tail.contains("早") {
            return hour == 12 ? 0 : hour
        }

        // 没说上下午：1~6 点默认是下午
        if hour >= 1 && hour <= 6 { return hour + 12 }
        return hour
    }

    // MARK: - 哪一天

    private static func parseDayOffset(_ text: String,
                                       now: Date,
                                       calendar: Calendar) -> Int? {
        if text.contains("大后天") { return 3 }
        if text.contains("后天") { return 2 }
        if text.contains("明天") || text.contains("明日") { return 1 }
        if text.contains("今天") || text.contains("今日") || text.contains("今晚")
            || text.contains("今早") || text.contains("今晚") { return 0 }

        // 周X / 星期X / 礼拜X
        let names: [String: Int] = [
            "一": 2, "二": 3, "三": 4, "四": 5, "五": 6, "六": 7, "日": 1, "天": 1
        ]
        for (name, weekday) in names {
            if text.contains("周\(name)") || text.contains("星期\(name)")
                || text.contains("礼拜\(name)") {
                let current = calendar.component(.weekday, from: now)
                var delta = weekday - current
                if delta <= 0 { delta += 7 }
                if delta == 7 { delta = 0 }        // 今天正好是周X
                return delta
            }
        }
        return nil
    }

    // MARK: - 相对时间

    private static func parseRelative(_ text: String,
                                      now: Date,
                                      calendar: Calendar) -> Date? {
        if text.contains("半小时后") {
            return calendar.date(byAdding: .minute, value: 30, to: now)
        }
        if text.contains("一小时后") || text.contains("1小时后") {
            return calendar.date(byAdding: .hour, value: 1, to: now)
        }

        let pattern = #"(\d{1,3}|[一二三四五六七八九十]{1,3})\s*(分钟|小时)后"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let full = Range(match.range, in: text)
        else { return nil }

        let ns = text as NSString
        _ = full
        let numberText = ns.substring(with: match.range(at: 1))
        let unit = ns.substring(with: match.range(at: 2))
        guard let value = Int(numberText) ?? chineseNumber(numberText) else { return nil }

        return unit == "小时"
            ? calendar.date(byAdding: .hour, value: value, to: now)
            : calendar.date(byAdding: .minute, value: value, to: now)
    }

    // MARK: - 标题

    /// 把时间词、语气词去掉，剩下的当标题
    static func extractTitle(_ text: String) -> String {
        var result = text

        // 去掉时间和日期片段
        let patterns = [
            #"\d{1,2}\s*[:：]\s*\d{1,2}"#,
            #"(\d{1,2}|[零一二三四五六七八九十两]{1,3})\s*点\s*(半|(\d{1,2})\s*分?)?"#,
            #"(大后天|后天|明天|明日|今天|今日|今晚|今早|明晚|明早|昨晚|昨夜)"#,
            #"(周|星期|礼拜)[一二三四五六日天]"#,
            #"(凌晨|上午|早上|中午|下午|傍晚|晚上|夜里)"#,
            #"(半|一|\d{1,3})\s*(小时|分钟)后"#,
            #"(提醒我|帮我|帮忙|记一下|记录一下|加一个|加个|加到日程|安排一下|安排我|安排|新建|创建)"#
        ]
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern,
                                                 with: " ",
                                                 options: .regularExpression)
        }

        let cleaned = result
            .replacingOccurrences(of: "，", with: " ")
            .replacingOccurrences(of: "。", with: " ")
            .replacingOccurrences(of: "、", with: " ")
            .replacingOccurrences(of: "　", with: " ")
            .split(separator: " ")
            .joined()

        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "日程" : trimmed
    }


    // MARK: - 改期 / 取消

    /// 改期请求：新的开始时间；如果句子里提到了原来的时间，也带出来
    struct MoveRequest {
        let newStart: Date
        let oldStart: Date?
    }

    private static let moveKeywords = [
        "改到", "改成", "改在", "推迟到", "推迟", "提前到", "提前", "延后到", "延后", "挪到"
    ]

    private static let cancelKeywords = [
        "取消", "删掉", "删了", "不去了", "别去了", "去掉"
    ]

    static func isCancelIntent(_ text: String) -> Bool {
        cancelKeywords.contains { text.contains($0) }
    }

    /// 改期：关键字后面的时间是新时间，前面的时间（如果有）是原时间
    static func parseMove(_ text: String,
                          now: Date = Date(),
                          calendar: Calendar = .current) -> MoveRequest? {
        guard let keyword = moveKeywords.first(where: { text.contains($0) }),
              let range = text.range(of: keyword)
        else { return nil }

        let after = String(text[range.upperBound...])
        let before = String(text[..<range.lowerBound])

        guard let newParts = parseTime(after) else { return nil }

        let dayOffset = parseDayOffset(text, now: now, calendar: calendar)
        guard let newStart = makeDate(hour: newParts.0,
                                      minute: newParts.1,
                                      dayOffset: dayOffset,
                                      now: now,
                                      calendar: calendar)
        else { return nil }

        var oldStart: Date?
        if let oldParts = parseTime(before) {
            oldStart = makeDate(hour: oldParts.0,
                                minute: oldParts.1,
                                dayOffset: dayOffset,
                                now: now,
                                calendar: calendar)
        }

        return MoveRequest(newStart: newStart, oldStart: oldStart)
    }

    /// 取消：句子里如果点了时间就带上，没点就给 nil（由调用方按"下一个会"处理）
    static func cancelTargetTime(_ text: String,
                                 now: Date = Date(),
                                 calendar: Calendar = .current) -> Date? {
        guard let parts = parseTime(text) else { return nil }
        let dayOffset = parseDayOffset(text, now: now, calendar: calendar)
        return makeDate(hour: parts.0,
                        minute: parts.1,
                        dayOffset: dayOffset,
                        now: now,
                        calendar: calendar)
    }

    // MARK: - 拼日期

    private static func makeDate(hour: Int,
                                 minute: Int,
                                 dayOffset: Int?,
                                 now: Date,
                                 calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: now)

        if let offset = dayOffset,
           let day = calendar.date(byAdding: .day, value: offset, to: now) {
            components = calendar.dateComponents([.year, .month, .day], from: day)
        }

        components.hour = hour
        components.minute = minute
        components.second = 0

        guard var date = calendar.date(from: components) else { return nil }

        if dayOffset == nil, date < now {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return date
    }

    // MARK: - 中文数字

    static func chineseNumber(_ text: String) -> Int? {
        let digits: [Character: Int] = [
            "零": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
            "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
        ]

        if text == "十" { return 10 }
        if text.contains("十") {
            let parts = text.split(separator: "十", omittingEmptySubsequences: false)
            let tens = parts.first.flatMap { $0.isEmpty ? 1 : digits[$0.first!] } ?? 1
            let ones = parts.count > 1 ? (parts[1].first.flatMap { digits[$0] } ?? 0) : 0
            return tens * 10 + ones
        }
        if let first = text.first, let value = digits[first] {
            return value
        }
        return nil
    }
}
