import Foundation

/// 一句话先分类，再决定交给谁处理。
///
/// 抽成纯逻辑的原因：以前这段散在 `AssistantView` 里，
/// 只能在真机上试，出了问题也不知道是哪条规则抢走的。
/// 现在可以在本地跑一批真实说法，看清楚每句会被送到哪。
enum ChatRouter {

    enum Intent: Equatable {
        case cityWeather(String)          // 「北京天气」
        case weather
        case location
        case market(String?)
        case weibo
        case zhihu
        case game
        case news
        case intelligence
        case cancelSchedule
        case reschedule
        case createSchedule
        case schedule
        case createTodo(String, Date?)
        case queryTodo(all: Bool)
        case completeTodo(String)
        /// 听音乐；带搜索词时非空
        case music(String?)
        case chat
    }

    // MARK: - 关键词

    private static let weatherKeys = ["天气", "气温", "温度", "下雨", "带伞", "几度", "冷不冷", "热不热"]
    private static let locationKeys = ["在哪", "位置", "附近", "定位", "这是哪"]
    private static let marketKeys = ["股票", "股价", "行情", "大盘", "上证", "深证",
                                     "恒生", "纳指", "纳斯达克", "A股", "港股", "美股"]
    private static let weiboKeys = ["微博热搜", "热搜", "微博榜"]
    private static let zhihuKeys = ["知乎热榜", "知乎"]
    private static let gameKeys = ["游戏动态", "游戏新闻", "Steam", "steam",
                                   "手游榜", "畅销榜", "期待榜"]
    private static let intelligenceKeys = ["值得知道", "今日简报", "今天简报", "情报中心",
                                           "今天发生了什么", "今日情报"]
    private static let newsKeys = ["新闻", "时事", "AI科技", "AI 科技", "科技新闻"]
    private static let scheduleKeys = ["日程", "安排", "会议", "开会", "空档", "时间线", "今天有事", "明天有事"]

    /// 建日程必须有这些「动作词」或「事件名词」之一。
    /// 以前只要求"能解析出时间"，导致「我三点才睡」也会被建一个日程。
    /// 明确的"给我建一个"：有它就一定是要新增
    private static let strongCreateVerbs = [
        "加一个", "加个", "加到", "加一下", "增加", "新增", "添加",
        "记一下", "帮我记", "记录一下", "记个", "建个", "建一个",
        "提醒我", "提醒一下", "约", "订", "新建", "创建", "排一下"
    ]

    /// 弱动作词："安排" 既可能是"帮我安排"，也可能是"今天有什么安排"
    private static let weakCreateVerbs = ["安排"]

    private static let eventNouns = [
        "会", "会议", "开会", "见面", "面试", "评审", "汇报", "对稿",
        "吃饭", "饭局", "约会", "健身", "上课", "课程", "挂号", "就诊",
        "接机", "送机", "出差", "航班", "高铁", "火车", "买票", "看牙"
    ]

    /// 这些词说明是在讲已经发生的事，不该建日程
    private static let pastMarks = ["已经", "刚才", "昨天", "上周", "才睡", "睡着了"]

    private static let questionMarks = ["吗", "什么", "几", "有没有", "是不是", "哪", "?", "？"]

    /// 听音乐：动作词 + 音乐名词，或只说"音乐"也认
    private static let musicVerbs = ["放点", "放首", "放一首", "放个", "来点", "来首", "来一首",
                                     "我想听", "想听", "听一首", "听首", "播放", "放歌", "唱歌"]
    private static let musicNouns = ["音乐", "歌", "音乐吧", "歌单", "music"]

    // MARK: - 主入口

    static func intent(for text: String,
                       watchedCities: [WatchedCity],
                       now: Date = Date(),
                       calendar: Calendar = .current) -> Intent {

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .chat }

        if weiboKeys.contains(where: { trimmed.contains($0) })
            || (trimmed.contains("微博")
                && ["什么", "在聊", "讨论"].contains(where: { trimmed.contains($0) })) {
            return .weibo
        }
        if zhihuKeys.contains(where: { trimmed.contains($0) }) {
            return .zhihu
        }
        if gameKeys.contains(where: { trimmed.contains($0) }) {
            return .game
        }
        if intelligenceKeys.contains(where: { trimmed.contains($0) }) {
            return .intelligence
        }
        if marketKeys.contains(where: { trimmed.contains($0) }) {
            return .market(MarketQueryParser.term(from: trimmed))
        }
        if newsKeys.contains(where: { trimmed.contains($0) }) {
            return .news
        }

        // ① 点名某个关注城市
        if isWeatherQuestion(trimmed) {
            if let city = watchedCities.first(where: { trimmed.contains($0.name) }) {
                return .cityWeather(city.name)
            }
        }

        if isWeatherQuestion(trimmed) { return .weather }
        if locationKeys.contains(where: { trimmed.contains($0) }) { return .location }

        // 听音乐：要排在日程之前，否则「放首歌」里的"放"会被别的规则抢走
        if let music = musicIntent(trimmed) { return music }

        // ② 待办优先于日程：
        //    「提醒我买牛奶」是待办，「提醒我三点开会」是日程——靠事件名词区分
        switch TodoParser.parse(trimmed, now: now, calendar: calendar) {
        case .create(let title, let due):
            return .createTodo(title, due)
        case .queryAll:
            return .queryTodo(all: true)
        case .queryToday:
            return .queryTodo(all: false)
        case .complete(let query):
            return .completeTodo(query)
        case .none:
            break
        }

        // ③ 日程三动作：取消 → 改期 → 新增
        if ScheduleParser.isCancelIntent(trimmed) { return .cancelSchedule }

        if ScheduleParser.parseMove(trimmed, now: now, calendar: calendar) != nil {
            return .reschedule
        }

        if isCreatingSchedule(trimmed, now: now, calendar: calendar) { return .createSchedule }

        // ③ 问日程
        if !isWeatherQuestion(trimmed),
           scheduleKeys.contains(where: { trimmed.contains($0) }) {
            return .schedule
        }

        return .chat
    }

    // MARK: - 细则

    static func isWeatherQuestion(_ text: String) -> Bool {
        weatherKeys.contains { text.contains($0) }
    }

    /// 听音乐：认「音乐/歌」这类名词，或"听/放"开头的短句
    ///
    /// 「听周杰伦」要能识别，但「听说明天要下雨」不能——
    /// 所以裸"听"只在一句话里没有别的动作词时才认。
    static func musicIntent(_ text: String) -> Intent? {
        let hasNoun = musicNouns.contains { text.contains($0) }
        var hasVerb = musicVerbs.contains { text.contains($0) }

        if !hasVerb, !hasNoun, text.hasPrefix("听") {
            let rest = String(text.dropFirst())
            let guardWords = ["说", "要", "会", "吗", "怎么", "几", "下", "事"]
            let looksLikeSentence = guardWords.contains { rest.contains($0) }
            hasVerb = !looksLikeSentence && rest.count <= 12
        }

        guard hasNoun || hasVerb else { return nil }

        // 混句（问天气顺带说音乐）让天气赢，别抢
        guard !isWeatherQuestion(text) else { return nil }
        guard !pastMarks.contains(where: { text.contains($0) }) else { return nil }

        let term = MusicUtil.cleanTerm(text)
        return .music(term.isEmpty ? nil : term)
    }

    /// 建日程：必须同时满足
    /// ① 能解析出时间
    /// ② 有动作词或事件名词
    /// ③ 不是问句、不是在讲过去
    /// ④ 不是「日程」类提问
    static func isCreatingSchedule(_ text: String,
                                   now: Date = Date(),
                                   calendar: Calendar = .current) -> Bool {

        if pastMarks.contains(where: { text.contains($0) }) { return false }

        let hasStrong = strongCreateVerbs.contains { text.contains($0) }
        let hasWeak = weakCreateVerbs.contains { text.contains($0) }
        let hasNoun = eventNouns.contains { text.contains($0) }
        let isQuestion = questionMarks.contains { text.contains($0) }

        // 问句只认"明确的建"，否则「明天有什么安排」会被当成新增
        if isQuestion, !hasStrong { return false }

        // 提到日程但没有任何动作词 → 是在查
        if text.contains("日程"), !hasStrong, !hasWeak { return false }

        guard hasStrong || hasWeak || hasNoun else { return false }

        // 时间能解析出来：建
        if ScheduleParser.parse(text, now: now, calendar: calendar) != nil { return true }

        // 没说时间：只有"明确的建"才追问几点；「安排」这种模糊的交给查日程
        return hasStrong
    }
}
