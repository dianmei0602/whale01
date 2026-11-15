import Foundation

/// 一条主动通知的候选。
struct NoticeCandidate: Equatable {
    enum Kind: String {
        case rain       // 要下雨
        case meeting    // 会前
        case morning    // 早报
        case standUp    // 久坐
        case bedtime    // 就寝
    }

    let kind: Kind
    /// 什么时候发
    let fireAt: Date
    /// 去重用的键：同一件事 24 小时内只说一次
    let key: String
    /// 数字越大越重要，预算不够时优先保它
    let priority: Int
}

/// 主动通知的预算与去重。
///
/// 之前五种通知各排各的：早报 1 条、会前 N 条、久坐 5 条、下雨 1 条、就寝 1 条。
/// 一天最多能冒出 10 条以上，用户会关掉通知。
/// 这里统一算一遍：每天有上限、同一件事不重复、按重要性排队。
enum NotificationPlanner {

    /// 一天最多几条（含用户主动开的久坐）
    static let dailyLimit = 4

    /// 每种类型一天最多几条
    static let perKindLimit: [NoticeCandidate.Kind: Int] = [
        .morning: 1,
        .rain: 1,
        .bedtime: 1,
        .meeting: 2,
        .standUp: 2
    ]

    /// 同一 key 多久内不重复
    static let dedupeWindow: TimeInterval = 24 * 60 * 60

    /// 从候选里挑出真正要发的
    /// - Parameters:
    ///   - history: 最近已经发过的 (key, 时间)
    static func plan(_ candidates: [NoticeCandidate],
                     now: Date,
                     history: [(key: String, at: Date)],
                     calendar: Calendar = .current,
                     dailyLimit: Int = dailyLimit) -> [NoticeCandidate] {

        // ① 丢掉已经过点的
        var pool = candidates.filter { $0.fireAt > now }

        // ② 丢掉 24 小时内重复的
        let recentKeys = Set(history
            .filter { now.timeIntervalSince($0.at) < dedupeWindow }
            .map { $0.key })
        pool = pool.filter { !recentKeys.contains($0.key) }

        // ③ 按天分组：先按重要性，再按时间，超过上限的丢掉
        var byDay: [Date: [NoticeCandidate]] = [:]
        for candidate in pool {
            let day = calendar.startOfDay(for: candidate.fireAt)
            byDay[day, default: []].append(candidate)
        }

        var approved: [NoticeCandidate] = []

        for (_, sameDay) in byDay {
            var sorted = sameDay.sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.fireAt < rhs.fireAt
            }

            // 每种类型自己的上限
            var kindCount: [NoticeCandidate.Kind: Int] = [:]
            sorted = sorted.filter { candidate in
                let used = kindCount[candidate.kind, default: 0]
                guard used < (perKindLimit[candidate.kind] ?? dailyLimit) else { return false }
                kindCount[candidate.kind] = used + 1
                return true
            }

            approved.append(contentsOf: sorted.prefix(dailyLimit))
        }

        return approved.sorted { $0.fireAt < $1.fireAt }
    }

    /// 把已经排上的写进历史，供下次去重
    static func merge(history: [(key: String, at: Date)],
                      approved: [NoticeCandidate],
                      now: Date) -> [(key: String, at: Date)] {
        var merged = history.filter { now.timeIntervalSince($0.at) < dedupeWindow }
        for candidate in approved {
            merged.append((candidate.key, now))
        }
        return merged
    }
}
