import Foundation

/// 把模型的回答整理成"能念出来"的样子。
///
/// 屏幕上看没问题的东西，念出来很怪：
///   - 星号、井号、列表符号会被念成"星号""井号"
///   - 括号里的补充说明会打断语气
///   - `15:00` 这种时间念成"十五比零"
///   - `24°` 念成"二十四度"要自己补字
/// 所以显示用原文，朗读用这份清洗后的文本。
enum SpeechSanitizer {

    static func prepare(_ text: String) -> String {
        var result = text

        // ① 去掉 markdown 标记
        for mark in ["**", "__", "*", "`", "#", "> ", "- ", "• "] {
            result = result.replacingOccurrences(of: mark, with: "")
        }

        // ② 去掉括号和里面的补充说明
        result = removeParentheses(result)

        // ③ 数字编号开头（"1. " "2、"）去掉
        result = removeNumberedLeads(result)

        // ④ 时间 15:00 → 十五点 / 十五点十分
        result = replaceTimes(result)

        // ⑤ 单位念法
        result = replacePercents(result)
        result = result
            .replacingOccurrences(of: "°C", with: "度")
            .replacingOccurrences(of: "°", with: "度")
            .replacingOccurrences(of: "¥", with: "块")
            .replacingOccurrences(of: "PM2.5", with: "PM二点五")

        // ⑥ 去掉 emoji 和多余符号
        result = removeEmoji(result)
        result = result.replacingOccurrences(of: "·", with: "，")
        result = result.replacingOccurrences(of: "|", with: "，")
        result = result.replacingOccurrences(of: "/", with: "，")
        result = result.replacingOccurrences(of: "~", with: "")
            .replacingOccurrences(of: "～", with: "")

        // ⑦ 冒号在口语里停顿更自然
        result = result.replacingOccurrences(of: "：", with: "，")
        result = result.replacingOccurrences(of: ":", with: "，")
        result = result.replacingOccurrences(of: "；", with: "。")
        result = result.replacingOccurrences(of: ";", with: "。")

        // ⑧ 换行变句号
        result = result.replacingOccurrences(of: "\n", with: "。")

        // ⑨ 连续标点合并（必须在换行处理之后，否则会留下「，。」）
        while result.contains("，，") { result = result.replacingOccurrences(of: "，，", with: "，") }
        while result.contains("。。") { result = result.replacingOccurrences(of: "。。", with: "。") }
        while result.contains("，。") { result = result.replacingOccurrences(of: "，。", with: "。") }
        while result.contains("。，") { result = result.replacingOccurrences(of: "。，", with: "。") }
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // ⑩ 结尾补标点，TTS 才有收尾语气
        if let last = result.last, !"。！？".contains(last) {
            result += "。"
        }
        return result
    }

    // MARK: - 细节

    private static func removeParentheses(_ text: String) -> String {
        var result = ""
        var depth = 0

        for character in text {
            if "（(".contains(character) {
                depth += 1
                continue
            }
            if "）)".contains(character) {
                depth = max(0, depth - 1)
                continue
            }
            if depth == 0 {
                result.append(character)
            }
        }
        return result
    }

    private static func removeNumberedLeads(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let cleaned = lines.map { line -> String in
            var trimmed = String(line).trimmingCharacters(in: .whitespaces)
            for pattern in ["一、", "二、", "三、", "四、", "五、"] {
                if trimmed.hasPrefix(pattern) {
                    trimmed.removeFirst(pattern.count)
                }
            }
            // "1. " / "2、" 这种
            var index = trimmed.startIndex
            var digits = 0
            while index < trimmed.endIndex, trimmed[index].isNumber {
                index = trimmed.index(after: index)
                digits += 1
            }
            if digits > 0, index < trimmed.endIndex,
               (trimmed[index] == "." || trimmed[index] == "、"),
               trimmed.distance(from: trimmed.startIndex, to: index) < 3 {
                trimmed = String(trimmed[trimmed.index(after: index)...])
                    .trimmingCharacters(in: .whitespaces)
            }
            return trimmed
        }
        return cleaned.joined(separator: "\n")
    }

    private static func replaceTimes(_ text: String) -> String {
        var result = ""
        var buffer = ""
        let iterator = Array(text)

        var i = 0
        while i < iterator.count {
            let character = iterator[i]

            if character.isNumber {
                buffer.append(character)
                i += 1
                continue
            }

            // 形如 15:00
            if character == ":", buffer.count == 2,
               i + 2 < iterator.count,
               iterator[i + 1].isNumber, iterator[i + 2].isNumber {

                let minute = "\(iterator[i + 1])\(iterator[i + 2])"
                result += "\(chineseNumber(buffer))点"
                if minute != "00" {
                    result += "\(chineseNumber(minute))分"
                }
                buffer = ""
                i += 3
                continue
            }

            if !buffer.isEmpty {
                result += buffer
                buffer = ""
            }
            result.append(character)
            i += 1
        }

        if !buffer.isEmpty { result += buffer }
        return result
    }

    private static func chineseNumber(_ digits: String) -> String {
        guard let value = Int(digits) else { return digits }
        let names = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

        switch value {
        case 0..<10:
            return names[value]
        case 10..<20:
            return value == 10 ? "十" : "十" + names[value - 10]
        case 20..<100:
            return names[value / 10] + "十" + (value % 10 == 0 ? "" : names[value % 10])
        default:
            return digits
        }
    }

    /// 60% 念成「百分之六十」
    private static func replacePercents(_ text: String) -> String {
        var result = ""
        var digits = ""

        for character in text {
            if character.isNumber {
                digits.append(character)
                continue
            }

            if character == "%", !digits.isEmpty {
                result += "百分之" + chineseNumber(digits)
                digits = ""
                continue
            }

            if !digits.isEmpty {
                result += digits
                digits = ""
            }
            result.append(character)
        }

        if !digits.isEmpty { result += digits }
        return result
    }

    private static func removeEmoji(_ text: String) -> String {
        text.unicodeScalars.filter { scalar in
            !scalar.properties.isEmojiPresentation && !scalar.properties.isEmojiModifier
        }
        .map(String.init)
        .joined()
    }
}
