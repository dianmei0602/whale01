import Foundation

struct RulesInput {
    var now: Date
    var weather: Weather?
    var airPM25: Double?
    var openTodos: Int
    var firstTodo: String?
    var meetings: [MeetingItem]
    var bedtime: Date
    var dismissed: Set<String>
}

/// 规则引擎：纯函数，不碰网络、不碰 UI、不碰 SwiftUI。
/// 同一份逻辑在网页版也实现了一次，行为必须一致。
enum RulesEngine {
    static let maxCards = 4

    static func cards(for input: RulesInput) -> [DayCard] {
        var result: [DayCard] = []

        // R13 待办
        if input.openTodos > 0 && !input.dismissed.contains("todo") {
            result.append(DayCard(
                id: "todo",
                time: "今天",
                icon: "✅",
                tint: .teal,
                fact: input.openTodos == 1 ? (input.firstTodo ?? "有 1 件待办") : "今天有 \(input.openTodos) 件要交",
                advice: "右滑可以完成",
                rank: 0,
                canComplete: true
            ))
        }

        // R04 日程：未来 4 小时内的下一个会
        if !input.dismissed.contains("meeting") {
            let upcoming = input.meetings.first { meeting in
                !meeting.isAllDay
                    && meeting.start > input.now
                    && meeting.start.timeIntervalSince(input.now) <= 4 * 60 * 60
            }
            if let next = upcoming {
                let minutes = Int(next.start.timeIntervalSince(input.now) / 60)
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "zh_CN")
                formatter.dateFormat = "HH:mm"
                let timeText = formatter.string(from: next.start)
                let urgent = minutes <= 30

                result.append(DayCard(
                    id: "meeting",
                    time: timeText,
                    icon: "📌",
                    tint: .orange,
                    fact: urgent ? "\(minutes) 分钟后：\(next.title)" : next.title,
                    advice: urgent ? "现在别开新的事" : "还有 \(minutes / 60) 小时 \(minutes % 60) 分",
                    rank: 1,
                    canComplete: false
                ))
            }
        }

        // R10 睡前
        let minutesToBedtime = input.bedtime.timeIntervalSince(input.now) / 60
        if minutesToBedtime <= 60 && minutesToBedtime > -90 && !input.dismissed.contains("sleep") {
            result.append(DayCard(
                id: "sleep",
                time: "今晚",
                icon: "🌙",
                tint: .purple,
                fact: minutesToBedtime > 0
                    ? "距你定的就寝还有 \(Int(minutesToBedtime.rounded())) 分钟"
                    : "已经过了就寝时间",
                advice: minutesToBedtime > 0 ? "可以先关屏" : "别刷了，去睡",
                rank: 5,
                canComplete: false
            ))
        }

        guard let weather = input.weather else {
            return truncated(result)
        }

        let calendar = Calendar.current
        let horizon = input.now.addingTimeInterval(12 * 60 * 60)

        // R01 带伞
        if !input.dismissed.contains("rain") {
            let upcoming = weather.hours.first { hour in
                hour.time >= input.now
                    && hour.time <= horizon
                    && hour.precipitationProbability >= 50
            }
            if let hour = upcoming {
                let hourOfDay = calendar.component(.hour, from: hour.time)
                let label = String(format: "%02d:00", hourOfDay)
                result.append(DayCard(
                    id: "rain",
                    time: label,
                    icon: "🌧",
                    tint: .blue,
                    fact: "现在 \(Int(weather.currentTemperature.rounded()))°，\(label) 转雨",
                    advice: "降水概率 \(Int(hour.precipitationProbability))%，出门带伞",
                    rank: 1,
                    canComplete: false
                ))
            }
        }

        // R03 空气
        if let pm25 = input.airPM25, pm25 > 75, !input.dismissed.contains("air") {
            let level = pm25 > 150 ? "重度" : (pm25 > 115 ? "中度" : "轻度")
            result.append(DayCard(
                id: "air",
                time: "现在",
                icon: "😷",
                tint: .orange,
                fact: "PM2.5 \(Int(pm25.rounded()))（\(level)）",
                advice: "今天别在户外跑，改室内或换个时段",
                rank: 2,
                canComplete: false
            ))
        }

        // R02 保暖
        if !input.dismissed.contains("warm") {
            if let yesterdayMax = weather.yesterdayMax, weather.todayMax - yesterdayMax <= -6 {
                result.append(DayCard(
                    id: "warm",
                    time: "现在",
                    icon: "🧥",
                    tint: .green,
                    fact: "今天最高 \(Int(weather.todayMax.rounded()))°，比昨天低 \(Int((yesterdayMax - weather.todayMax).rounded()))°",
                    advice: "明显降温，出门加一件外套",
                    rank: 3,
                    canComplete: false
                ))
            } else if weather.todayMin < 5 {
                result.append(DayCard(
                    id: "warm",
                    time: "现在",
                    icon: "🧥",
                    tint: .green,
                    fact: "最低 \(Int(weather.todayMin.rounded()))°，早上很冷",
                    advice: "出门穿厚一点",
                    rank: 3,
                    canComplete: false
                ))
            }
        }

        // R06 运动窗口
        if !input.dismissed.contains("sport"), (input.airPM25 ?? 0) <= 75 {
            let upcomingHours = weather.hours.filter { $0.time >= input.now }
            var index = 0
            while index + 1 < upcomingHours.count {
                let first = upcomingHours[index]
                let second = upcomingHours[index + 1]
                let hourOfDay = calendar.component(.hour, from: first.time)
                let isToday = calendar.isDate(first.time, inSameDayAs: input.now)

                if isToday, hourOfDay >= 6, hourOfDay <= 19,
                   first.temperature >= 10, first.temperature <= 28,
                   second.temperature >= 10, second.temperature <= 28,
                   first.precipitationProbability < 30,
                   second.precipitationProbability < 30 {
                    let endHour = (calendar.component(.hour, from: second.time) + 1) % 24
                    let startText = String(format: "%02d", hourOfDay)
                    let endText = String(format: "%02d", endHour)
                    result.append(DayCard(
                        id: "sport",
                        time: label(hourOfDay),
                        icon: "🏃",
                        tint: .green,
                        fact: "运动窗口 \(startText):00–\(endText):00",
                        advice: "气温 \(Int(first.temperature.rounded()))°，降水概率 \(Int(first.precipitationProbability))%，适合出门",
                        rank: 4,
                        canComplete: false
                    ))
                    break
                }
                index += 1
            }
        }

        return truncated(result)
    }

    private static func label(_ hour: Int) -> String {
        return String(format: "%02d:00", hour)
    }

    private static func truncated(_ cards: [DayCard]) -> [DayCard] {
        let sorted = cards.sorted { $0.rank < $1.rank }
        if sorted.count <= maxCards {
            return sorted
        }
        return Array(sorted.prefix(maxCards))
    }
}
