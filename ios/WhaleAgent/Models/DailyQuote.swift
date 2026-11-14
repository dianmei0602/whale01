import Foundation

/// 每日一句：每 30 分钟轮换一次。480 条有明确出处的金句构成一个
/// 10 天（240 小时）的不重复循环；37 与 480 互质，任意连续 480 个
/// 半小时时段正好覆盖整池，循环结束后重新排列。
enum DailyQuote {
    typealias Item = DailyQuoteCorpus.Item

    static let slotsPerDay = 48
    static let slotMinutes = 30
    static let items: [Item] = DailyQuoteCorpus.items
    static let pool: [String] = items.map(\.displayText)
    static let poolCycleHours = 240
    static let poolCycleDays = poolCycleHours / 24

    static func slotIndex(at date: Date, calendar: Calendar = .current) -> Int {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let halfHour = min(1, max(0, minute / slotMinutes))
        let slot = min(slotsPerDay - 1, max(0, hour * 2 + halfHour))
        let globalSlot = day * slotsPerDay + slot
        return ((globalSlot * 37) % pool.count + pool.count) % pool.count
    }

    static func item(at date: Date, calendar: Calendar = .current) -> Item {
        items[slotIndex(at: date, calendar: calendar)]
    }

    static func text(at date: Date, calendar: Calendar = .current) -> String {
        pool[slotIndex(at: date, calendar: calendar)]
    }
}
