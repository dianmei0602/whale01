import Foundation

/// 小组件用的快照：App 写，Widget 读。
///
/// 共享容器用 App Group（`group.com.jinri.app`）。
/// 免费签名环境拿不到这个容器时，写入会失败——所以读的一方必须能识别"没有快照"，
/// 并且**不许显示旧数据或猜的数据**，只显示"打开 App 同步"。
struct WidgetSnapshot: Codable, Equatable {

    /// 下一件事的名称（空 = 今天没安排）
    var eventTitle: String = ""
    /// 开始时间（用于算倒计时）
    var startAt: Date?
    /// "16:00–17:00"
    var timeText: String = ""
    /// 地点
    var place: String = ""
    /// upcoming / soon / now / done
    var kind: String = "idle"
    /// 数据来源，例如"系统日历"
    var source: String = ""
    /// 快照生成时间；界面要显示"几分钟前"
    var updatedAt: Date = .distantPast
    /// 今天还剩几件事
    var remainingCount: Int = 0

    static let groupID = "group.com.jinri.app"

    private static var shared: UserDefaults? {
        UserDefaults(suiteName: groupID)
    }

    // MARK: - 写（App 侧）

    /// 返回是否真的写进了共享容器；false 表示免费签名环境下不可共享
    @discardableResult
    static func save(_ snapshot: WidgetSnapshot) -> Bool {
        guard let defaults = shared else { return false }
        guard let data = try? JSONEncoder().encode(snapshot) else { return false }
        defaults.set(data, forKey: "widget.snapshot")
        return defaults.data(forKey: "widget.snapshot") != nil
    }

    // MARK: - 读（Widget 侧）

    static func load() -> WidgetSnapshot? {
        guard let defaults = shared,
              let data = defaults.data(forKey: "widget.snapshot"),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return nil }

        // 超过 2 小时的快照视为过期：宁可显示"打开 App 同步"，也不显示旧数据
        if Date().timeIntervalSince(snapshot.updatedAt) > 2 * 60 * 60 { return nil }
        return snapshot
    }

    /// 快照是否足够新（30 分钟内），用于界面上的"刚刚更新"
    var isFresh: Bool {
        Date().timeIntervalSince(updatedAt) < 30 * 60
    }

    var freshnessText: String {
        let seconds = Date().timeIntervalSince(updatedAt)
        if seconds < 90 { return "刚刚更新" }
        if seconds < 3600 { return "\(Int(seconds / 60)) 分钟前" }
        return "较早"
    }

    var countdownText: String {
        guard let startAt else { return "—" }
        let seconds = startAt.timeIntervalSince(Date())
        if seconds <= 0 { return "进行中" }
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "马上" }
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h"
    }
}
