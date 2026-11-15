import Foundation

/// 底部那三个建议。
///
/// 以前写死「今天的日程 / 天气怎么样 / 我的位置」，天天一样，像广告位。
/// 现在从它的技能池里随机抽三个，每次回来都换一批。
struct QuickSuggestion: Identifiable, Equatable {
    let id: String
    let symbol: String
    /// 按钮上显示的短句
    let title: String
    /// 真正发出去的那句话（可以比标题长）
    let phrase: String
}

enum QuickSuggestions {

    /// 一行会发出去的东西。覆盖率按 App 真实能处理的来：
    /// 日程三动作、天气、位置都能直出卡片；聊天类交给模型。
    static let all: [QuickSuggestion] = [
        // 日程 · 查
        QuickSuggestion(id: "s_today", symbol: "calendar",
                        title: "今天的日程", phrase: "今天的日程"),
        QuickSuggestion(id: "s_tomorrow", symbol: "calendar",
                        title: "明天有事吗", phrase: "明天有事吗"),
        QuickSuggestion(id: "s_free", symbol: "clock",
                        title: "我几点有空", phrase: "我几点有空"),

        // 日程 · 增改删
        QuickSuggestion(id: "s_add", symbol: "calendar.badge.plus",
                        title: "加个日程", phrase: "帮我记一下，明天下午三点开会"),
        QuickSuggestion(id: "s_move", symbol: "calendar.badge.clock",
                        title: "改个时间", phrase: "把三点的会改到四点"),
        QuickSuggestion(id: "s_cancel", symbol: "calendar.badge.minus",
                        title: "取消一个会", phrase: "取消四点那个会"),

        // 天气
        QuickSuggestion(id: "w_now", symbol: "sun.max",
                        title: "天气怎么样", phrase: "天气怎么样"),
        QuickSuggestion(id: "w_rain", symbol: "cloud.rain",
                        title: "明天会下雨吗", phrase: "明天会下雨吗"),
        QuickSuggestion(id: "w_temp", symbol: "thermometer.medium",
                        title: "现在几度", phrase: "现在几度"),
        QuickSuggestion(id: "w_wear", symbol: "tshirt",
                        title: "穿什么合适", phrase: "今天穿什么合适"),

        // 位置
        QuickSuggestion(id: "l_here", symbol: "location.fill",
                        title: "我的位置", phrase: "我在哪"),
        QuickSuggestion(id: "l_near", symbol: "map",
                        title: "附近有什么", phrase: "附近有什么"),

        // 情报
        QuickSuggestion(id: "i_brief", symbol: "newspaper",
                        title: "今天值得知道", phrase: "今天值得知道"),
        QuickSuggestion(id: "i_market", symbol: "chart.line.uptrend.xyaxis",
                        title: "今天大盘", phrase: "今天大盘怎么样"),
        QuickSuggestion(id: "i_weibo", symbol: "flame",
                        title: "微博热搜", phrase: "微博热搜"),
        QuickSuggestion(id: "i_ai", symbol: "cpu",
                        title: "AI 科技新闻", phrase: "今天的 AI 科技新闻"),

        // 随口聊（模型来答，有真实上下文）
        QuickSuggestion(id: "c_joke", symbol: "face.smiling",
                        title: "讲个笑话", phrase: "讲个笑话"),
        QuickSuggestion(id: "c_tired", symbol: "bed.double",
                        title: "我今天好累", phrase: "我今天好累"),
        QuickSuggestion(id: "c_food", symbol: "fork.knife",
                        title: "中午吃什么", phrase: "中午吃什么好"),
        QuickSuggestion(id: "c_like", symbol: "heart",
                        title: "你了解我吗", phrase: "你了解我吗"),
        QuickSuggestion(id: "c_skill", symbol: "sparkles",
                        title: "你能做什么", phrase: "你能做什么"),
        QuickSuggestion(id: "c_study", symbol: "book",
                        title: "帮我理一下", phrase: "我现在有点乱，帮我理一下今天的事"),
        QuickSuggestion(id: "c_tomorrow", symbol: "moon.stars",
                        title: "明天要准备什么", phrase: "明天要准备什么"),
        QuickSuggestion(id: "c_calm", symbol: "hand.raised",
                        title: "我有点焦虑", phrase: "我有点焦虑，聊两句")
    ]

    /// 抽 count 个，尽量不跟上一批重复
    static func pick(_ count: Int = 3,
                     avoiding previous: [QuickSuggestion] = []) -> [QuickSuggestion] {
        let used = Set(previous.map { $0.id })
        var pool = all.filter { !used.contains($0.id) }

        // 池子不够就允许重复
        if pool.count < count { pool = all }

        return Array(pool.shuffled().prefix(count))
    }
}
