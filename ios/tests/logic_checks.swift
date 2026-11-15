// 纯逻辑回归检查。不依赖 XCTest、不依赖模拟器：
//   swiftc 把这几个纯逻辑文件和本文件一起编译，直接跑。
// 覆盖：时间解析 / 意图路由 / 物理 / 朗读清洗。
//
// 本地：pwsh 里跑 tools/run_logic_checks.py
// CI：见 .github/workflows/ios.yml 的 "Logic checks" 步骤

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// 纯逻辑回归检查。
///
/// 用 `@main` 而不是顶层语句：多个文件一起编译时，
/// 只有 main.swift 允许写顶层代码，`@main` 不受这个限制。
@main
struct LogicChecks {

    static func main() {
        exit(run())
    }

    static func run() -> Int32 {


    var failures = 0
    var checks = 0

    func expect(_ condition: Bool, _ label: String) {
        checks += 1
        if !condition {
            failures += 1
            print("  ✗ \(label)")
        }
    }

    func expectEqual<T: Equatable>(_ a: T, _ b: T, _ label: String) {
        checks += 1
        if a != b {
            failures += 1
            print("  ✗ \(label)：得到 \(a)，期望 \(b)")
        }
    }

    // MARK: - 固定时间基准：2026-11-08 10:00 周日

    var components = DateComponents()
    components.year = 2026
    components.month = 11
    components.day = 8
    components.hour = 10
    components.minute = 0

    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "zh_CN")
    calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
    let now = calendar.date(from: components)!

    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "MM-dd HH:mm"

    // MARK: - 1. ScheduleParser 时间解析

    print("ScheduleParser")
    if let parsed = ScheduleParser.parse("明天下午三点开会", now: now, calendar: calendar) {
        expectEqual(formatter.string(from: parsed.start), "11-09 15:00", "明天下午三点")
        expectEqual(parsed.title, "开会", "标题提取")
    } else {
        expect(false, "明天下午三点开会 应该能解析")
    }

    if let parsed = ScheduleParser.parse("周五上午九点半评审", now: now, calendar: calendar) {
        expectEqual(formatter.string(from: parsed.start), "11-13 09:30", "周五上午九点半")
    } else {
        expect(false, "周五上午九点半评审 应该能解析")
    }

    if let parsed = ScheduleParser.parse("半小时后提醒我喝水", now: now, calendar: calendar) {
        expectEqual(formatter.string(from: parsed.start), "11-08 10:30", "半小时后")
    } else {
        expect(false, "半小时后 应该能解析")
    }

    expect(ScheduleParser.parse("今天天气不错", now: now, calendar: calendar) == nil,
           "没有时间的话不该解析出日程")

    // 改期
    if let move = ScheduleParser.parseMove("把三点的会改到四点", now: now, calendar: calendar) {
        expectEqual(formatter.string(from: move.newStart), "11-08 16:00", "改期新时间")
        if let old = move.oldStart {
            expectEqual(formatter.string(from: old), "11-08 15:00", "改期原时间")
        } else {
            expect(false, "改期应该识别出原时间")
        }
    } else {
        expect(false, "把三点的会改到四点 应该能解析改期")
    }

    // 取消
    expect(ScheduleParser.isCancelIntent("取消三点那个会"), "取消意图识别")
    expect(!ScheduleParser.isCancelIntent("三点开会"), "普通新建不该被当成取消")

    // MARK: - 2. ChatRouter 路由

    print("ChatRouter")

    func route(_ text: String) -> String {
        switch ChatRouter.intent(for: text, watchedCities: [], now: now, calendar: calendar) {
        case .cityWeather:    return "城市天气"
        case .weather:        return "天气"
        case .location:       return "位置"
        case .market(let term): return term.map { "行情(\($0))" } ?? "行情"
        case .weibo:          return "微博"
        case .zhihu:          return "知乎"
        case .game:           return "游戏"
        case .news:           return "新闻"
        case .intelligence:   return "情报"
        case .cancelSchedule: return "取消"
        case .reschedule:     return "改期"
        case .createSchedule: return "新增"
        case .schedule:       return "查日程"
        case .createTodo:     return "待办新建"
        case .queryTodo(let all): return all ? "待办全部" : "待办今天"
        case .completeTodo:   return "待办完成"
        case .music(let term): return term.map { "听音乐(\($0))" } ?? "听音乐(nil)"
        case .chat:           return "聊天"
        }
    }

    expectEqual(route("增加一个日程"), "新增", "增加一个日程")
    expectEqual(route("帮我加个日程"), "新增", "帮我加个日程")
    expectEqual(route("明天下午三点开会"), "新增", "明天下午三点开会")
    // 买药是"要办的事"，不是"要开的会" → 走待办
    expectEqual(route("帮我记一下十点买药"), "待办新建", "帮我记一下十点买药")
    expectEqual(route("今天有什么日程"), "查日程", "今天有什么日程")
    expectEqual(route("明天有什么安排"), "查日程", "明天有什么安排")
    expectEqual(route("把三点的会改到四点"), "改期", "把三点的会改到四点")
    expectEqual(route("取消四点那个会"), "取消", "取消四点那个会")
    expectEqual(route("天气怎么样"), "天气", "天气怎么样")
    expectEqual(route("我在哪"), "位置", "我在哪")
    expectEqual(route("贵州茅台股价"), "行情(贵州茅台)", "个股行情")
    expectEqual(route("今天大盘怎么样"), "行情", "大盘行情")
    expectEqual(route("微博热搜"), "微博", "微博热搜")
    expectEqual(route("知乎热榜"), "知乎", "知乎热榜")
    expectEqual(route("游戏动态"), "游戏", "游戏动态")
    expectEqual(route("今天有什么新闻"), "新闻", "新闻问句")
    expectEqual(route("今天的 AI 科技新闻"), "新闻", "AI 新闻")
    expectEqual(route("今天值得知道"), "情报", "今日情报简报")
    expectEqual(route("加个待办：明天买牛奶"), "待办新建", "加个待办")
    expectEqual(route("今天还有什么没做"), "待办今天", "问今天待办")
    expectEqual(route("全部待办"), "待办全部", "看全部待办")
    expectEqual(route("牛奶那条做完了"), "待办完成", "做完某条")
    expectEqual(route("提醒我明天下午三点开会"), "新增", "提醒我 + 开会 仍是日程")
    expectEqual(route("我三点才睡"), "聊天", "我三点才睡 不该建日程")
    expectEqual(route("讲个笑话"), "聊天", "讲个笑话")
    expectEqual(route("你好"), "聊天", "你好")

    // MARK: - 3. PhysicsBox 物理

    print("PhysicsBox")

    var body0 = BoxBody()
    // 竖直下落 2 秒，应该落到框底
    for _ in 0..<120 {
        PhysicsBox.step(&body0, dt: 1.0 / 60.0, gravityX: 0, gravityY: 1.0)
    }
    expect(body0.y > 0.85, "竖直下落应该落到框底（y=\(String(format: "%.2f", body0.y))）")
    expect(body0.x > 0.45 && body0.x < 0.55, "竖直下落不该横向漂移")

    // 倒过来：应该贴到顶部
    var body1 = BoxBody()
    for _ in 0..<120 {
        PhysicsBox.step(&body1, dt: 1.0 / 60.0, gravityX: 0, gravityY: -1.0)
    }
    expect(body1.y < 0.15, "重力反向应该贴到顶部（y=\(String(format: "%.2f", body1.y))）")

    // 右倾：应该滚到右边
    var body2 = BoxBody()
    for _ in 0..<240 {
        PhysicsBox.step(&body2, dt: 1.0 / 60.0, gravityX: 0.7, gravityY: 0.7)
    }
    expect(body2.x > 0.75, "右倾应该滚到右侧（x=\(String(format: "%.2f", body2.x))）")

    // 任何情况下都不该跑出盒子
    expect(body2.x >= PhysicsBox.radius - 0.001 && body2.x <= 1 - PhysicsBox.radius + 0.001,
           "位置不该越界")

    // 抛起来之后会重新落回
    var body3 = BoxBody()
    for _ in 0..<120 {
        PhysicsBox.step(&body3, dt: 1.0 / 60.0, gravityX: 0, gravityY: 1.0)
    }
    let restingY = body3.y
    PhysicsBox.toss(&body3)
    for _ in 0..<180 {
        PhysicsBox.step(&body3, dt: 1.0 / 60.0, gravityX: 0, gravityY: 1.0)
    }
    expect(abs(body3.y - restingY) < 0.1, "抛起后应该重新落回底部")

    // MARK: - 4. SpeechSanitizer 朗读清洗

    print("SpeechSanitizer")

    let s1 = SpeechSanitizer.prepare("**好**，我帮你安排上了～")
    expect(!s1.contains("*"), "星号应该被去掉")
    expect(!s1.contains("～"), "波浪号应该被去掉")

    let s2 = SpeechSanitizer.prepare("记下了：15:00，开会")
    expect(s2.contains("十五点"), "15:00 应读成十五点（得到 \(s2)）")

    let s3 = SpeechSanitizer.prepare("降水概率 60%")
    expect(s3.contains("百分之六十"), "60% 应读成百分之六十（得到 \(s3)）")

    let s4 = SpeechSanitizer.prepare("今天 24°C，PM2.5 是 15（空气质量优）")
    expect(!s4.contains("（"), "括号内容应该被去掉")
    expect(s4.contains("24度"), "24°C 应读成 24度")

    let s5 = SpeechSanitizer.prepare("有 3 件事：\n1. 十点开会\n2. 下午看牙")
    expect(!s5.contains("，。"), "不该留下 逗号+句号 的组合（得到 \(s5)）")
    expect(!s5.contains("1."), "编号应该被去掉")


    // MARK: - 5. NotificationPlanner 通知预算

    print("NotificationPlanner")

    let base = {
        calendar.date(from: components) ?? now
    }()

    func at(hour: Int, minute: Int, dayOffset: Int = 0) -> Date {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: base) ?? base
        var c = calendar.dateComponents([.year, .month, .day], from: day)
        c.hour = hour
        c.minute = minute
        return calendar.date(from: c) ?? base
    }

    // 一天塞 8 条候选，应该被压到 dailyLimit 以内
    var many: [NoticeCandidate] = []
    for i in 0..<8 {
        many.append(NoticeCandidate(kind: i % 2 == 0 ? .standUp : .meeting,
                                    fireAt: at(hour: 9 + i, minute: 0),
                                    key: "k\(i)",
                                    priority: i))
    }
    let planned = NotificationPlanner.plan(many, now: base, history: [])
    expect(planned.count <= NotificationPlanner.dailyLimit,
           "一天不该超过 \(NotificationPlanner.dailyLimit) 条（实际 \(planned.count)）")
    expect(planned.count > 0, "不该把全部候选都丢掉")

    // 优先级高的先保
    let urgent = [
        NoticeCandidate(kind: .meeting, fireAt: at(hour: 15, minute: 0), key: "urgent", priority: 9),
        NoticeCandidate(kind: .standUp, fireAt: at(hour: 10, minute: 0), key: "low1", priority: 0),
        NoticeCandidate(kind: .standUp, fireAt: at(hour: 11, minute: 0), key: "low2", priority: 0),
        NoticeCandidate(kind: .standUp, fireAt: at(hour: 14, minute: 0), key: "low3", priority: 0)
    ]
    let picked = NotificationPlanner.plan(urgent, now: base, history: [])
    expect(picked.contains { $0.key == "urgent" }, "高优先级的应该留下")

    // 24 小时内同一 key 不重复
    let repeatPlan = NotificationPlanner.plan(
        [NoticeCandidate(kind: .morning, fireAt: at(hour: 7, minute: 0, dayOffset: 1),
                         key: "morning-x", priority: 3)],
        now: base,
        history: [("morning-x", base)]
    )
    expect(repeatPlan.isEmpty, "24 小时内同一件事不该重复")

    // 过点的不排
    let past = NotificationPlanner.plan(
        [NoticeCandidate(kind: .rain, fireAt: at(hour: 8, minute: 0), key: "rain-old", priority: 5)],
        now: base,
        history: []
    )
    expect(past.isEmpty, "已经过点的不该再排")

    // 每种类型自己也有上限（久坐最多 2 条）
    var stands: [NoticeCandidate] = []
    for i in 0..<5 {
        stands.append(NoticeCandidate(kind: .standUp, fireAt: at(hour: 9 + i, minute: 0),
                                      key: "s\(i)", priority: 1))
    }
    let standPlan = NotificationPlanner.plan(stands, now: base, history: [])
    expect(standPlan.count <= (NotificationPlanner.perKindLimit[.standUp] ?? 99),
           "久坐不该超过类型上限（实际 \(standPlan.count)）")


    // MARK: - 6. 深链解析

    print("DeepLinkRoute")

    func route(_ text: String) -> DeepLinkRoute {
        guard let url = URL(string: text) else { return .home }
        return DeepLinkRoute.parse(url)
    }

    expectEqual(route("nomi://open"), .home, "nomi://open")
    expectEqual(route("nomi://today"), .today, "nomi://today")
    expectEqual(route("nomi://schedule"), .today, "日程深链落到今日")
    expectEqual(route("nomi://chat"), .chat, "nomi://chat")
    expectEqual(route("nomi://event/abc123"), .event(id: "abc123"), "事件深链")
    expectEqual(route("nomi://prepare/abc123"), .prepare(id: "abc123"), "准备深链")
    expectEqual(route("nomi://confirm/tok9"), .confirm(token: "tok9"), "确认深链")
    expectEqual(route("nomi://settings"), .settings, "设置深链")
    expectEqual(route("nomi://settings/privacy"), .privacy, "隐私深链")
    expectEqual(route("https://evil.com/x"), .home, "非 nomi scheme 回首页")
    expectEqual(route("nomi://whatever"), .home, "未知 host 回首页")


    // MARK: - 7. 待办解析

    print("TodoParser")

    func todo(_ text: String) -> TodoCommand {
        TodoParser.parse(text, now: now, calendar: calendar)
    }

    expectEqual(todo("今天还有什么没做"), .queryToday, "问今天待办")
    expectEqual(todo("全部待办列一下"), .queryAll, "要看全部")

    if case .create(let title, let due) = todo("加个待办：明天下午三点提醒我买牛奶") {
        expectEqual(title, "买牛奶", "标题剥掉了时间和提醒我")
        expect(due != nil, "能解析出明天 15:00")
    } else {
        expect(true == false, "加个待办 应该被识别为新建")
    }

    if case .create(let title, let due) = todo("记得买牛奶") {
        expectEqual(title, "买牛奶", "记得 也能建待办")
        expect(due == nil, "没说时间就不设截止")
    } else {
        expect(true == false, "记得买牛奶 应该建待办")
    }

    // 同样的"提醒我"，说了日程就该走日程
    expectEqual(todo("提醒我明天下午三点开会"), .none, "开会不是待办")

    if case .complete(let query) = todo("牛奶那条做完了") {
        expectEqual(query, "牛奶", "完成时抽出了关键词")
    } else {
        expect(true == false, "做完了 应该识别为完成")
    }

    expectEqual(todo("今天天气怎么样"), .none, "天气不掺和待办")


    // MARK: - 8. 待办分组

    print("TodoGrouper")

    var calG = Calendar(identifier: .gregorian)
    calG.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    let groupBase = calG.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 10, minute: 0))!

    func at(day: Int, hour: Int) -> Date {
        calG.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: 0))!
    }

    let todoItems = [
        TodoItem(id: "a", title: "交房租", due: at(day: 11, hour: 18)),
        TodoItem(id: "b", title: "买牛奶", due: at(day: 12, hour: 15)),
        TodoItem(id: "c", title: "续签护照", due: at(day: 20, hour: 9)),
        TodoItem(id: "d", title: "随便看看", due: nil),
        TodoItem(id: "e", title: "逾期的事", due: at(day: 10, hour: 9))
    ]

    let grouped = TodoGrouper.group(todoItems, now: groupBase, calendar: calG)
    expectEqual(grouped.count, 4, "应该分成 4 组")
    expectEqual(grouped.first?.title, "今天", "第一组是今天")
    // 逾期的排在今天组最前
    expectEqual(grouped.first?.items.first?.title, "逾期的事", "逾期排最前")
    if grouped.count == 4 {
        expectEqual(grouped[1].title, "明天", "第二组明天")
        expectEqual(grouped[2].title, "以后", "第三组以后")
        expectEqual(grouped[3].title, "没定时间", "最后是没定时间")
    }

    expectEqual(TodoGrouper.isOverdue(at(day: 10, hour: 9), now: groupBase), true, "昨天算逾期")
    expectEqual(TodoGrouper.isOverdue(at(day: 11, hour: 18), now: groupBase), false, "今晚没逾期")
    expectEqual(TodoGrouper.dueText(at(day: 10, hour: 9), now: groupBase, calendar: calG), "已过期", "逾期文案")


    // MARK: - 9. 本地音乐

    print("MusicUtil")

    expect(MusicUtil.isAudioFile("晴天.mp3"), "mp3 认得")
    expect(MusicUtil.isAudioFile("夜曲.M4A"), "大写后缀也认得")
    expect(MusicUtil.isAudioFile("cover.jpg") == false, "图片不是音频")
    expect(MusicUtil.isAudioFile("noext") == false, "没后缀不算")

    expectEqual(MusicUtil.title(fromFileName: "01 晴天.mp3"), "晴天", "去掉编号与后缀")
    expectEqual(MusicUtil.title(fromFileName: "my_song.m4a"), "my song", "下划线换空格")
    expectEqual(MusicUtil.title(fromFileName: ".mp3"), "未命名", "空名兜底")

    expectEqual(MusicUtil.timeText(0), "0:00", "0 秒")
    expectEqual(MusicUtil.timeText(67), "1:07", "一分零七")
    expectEqual(MusicUtil.timeText(3671), "1:01:11", "超过一小时")

    expectEqual(MusicUtil.cleanTerm("放点晴天"), "晴天", "剥掉 放点")
    expectEqual(MusicUtil.cleanTerm("放点音乐"), "", "光说音乐不留词")

    expectEqual(route("放点音乐"), "听音乐(nil)", "放点音乐 打开入口")

    // MARK: - 10. 每日鼓励文案

    print("DailyEncouragement")

    let classicsURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("App/Resources/classical_quotes.json")
    let classicalQuotes = ((try? ClassicalQuoteRepository.load(from: classicsURL)) ?? [])
        .map(DailyEncouragement.init(quote:))
    expectEqual(classicalQuotes.count, 365, "古籍库应收录 365 条原文")
    expect(classicalQuotes.allSatisfy { (15...30).contains($0.hanziCount) },
           "古籍原文应全部为 15–30 个汉字")
    expect(Set(classicalQuotes.map(\.text)).count == 365, "古籍原文不能重复")
    expect(Set(classicalQuotes.map(\.book)).count == 13, "古籍库应覆盖 13 部典籍")

    let encouragementSuite = "nomi.logic.encouragement.\(UUID().uuidString)"
    let encouragementDefaults = UserDefaults(suiteName: encouragementSuite)!
    var encouragementIDs = Set<String>()
    for dayOffset in 0..<30 {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
        encouragementIDs.insert(
            DailyEncouragement.today(
                now: day,
                calendar: calendar,
                defaults: encouragementDefaults,
                quotes: classicalQuotes
            ).id
        )
    }
    expectEqual(encouragementIDs.count, 30, "连续 30 天文案不重复")

    let sameDayFirst = DailyEncouragement.today(
        now: now,
        calendar: calendar,
        defaults: encouragementDefaults,
        quotes: classicalQuotes
    )
    let sameDaySecond = DailyEncouragement.today(
        now: now,
        calendar: calendar,
        defaults: encouragementDefaults,
        quotes: classicalQuotes
    )
    expectEqual(sameDaySecond.id, sameDayFirst.id, "同一天刷新后文案保持一致")

    let alternative = DailyEncouragement.alternative(
        to: sameDayFirst.id,
        defaults: encouragementDefaults,
        quotes: classicalQuotes
    )
    expect(alternative.id != sameDayFirst.id, "换一句应提供另一条古籍原文")
    DailyEncouragement.recordChoice(
        alternative,
        now: now,
        calendar: calendar,
        defaults: encouragementDefaults
    )
    let afterManualChoice = DailyEncouragement.today(
        now: now,
        calendar: calendar,
        defaults: encouragementDefaults,
        quotes: classicalQuotes
    )
    expectEqual(afterManualChoice.id, alternative.id, "手动选句后当日保持该句")
    encouragementDefaults.removePersistentDomain(forName: encouragementSuite)

    // MARK: - 11. 情报中心解析

    print("IntelligenceParsers")
    expectEqual(IntelligenceModule.news.homepageTitle, "时事", "首页时事入口")
    expectEqual(IntelligenceModule.ai.homepageTitle, "AI", "首页 AI 入口")
    expectEqual(IntelligenceModule.market.homepageTitle, "行情", "首页行情入口")
    expectEqual(IntelligenceModule.weibo.homepageTitle, "微博", "首页微博入口")
    expectEqual(IntelligenceModule.zhihu.homepageTitle, "知乎", "首页知乎入口")
    expectEqual(IntelligenceModule.game.homepageTitle, "游戏", "首页游戏入口")
    expectEqual(IntelligenceModule.news.pageTitle, "今日时事", "详情页时事标题")
    expectEqual(IntelligenceModule.game.pageTitle, "游戏雷达", "详情页游戏标题")
    let oldNewsDate = Date(timeIntervalSince1970: 100)
    let newNewsDate = Date(timeIntervalSince1970: 200)
    let oldArticle = NewsArticle(
        id: "old", title: "旧新闻", link: URL(string: "https://example.com/old")!,
        source: "测试", category: .domestic, publishedAt: oldNewsDate
    )
    let newArticle = NewsArticle(
        id: "new", title: "新新闻", link: URL(string: "https://example.com/new")!,
        source: "测试", category: .domestic, publishedAt: newNewsDate
    )
    var cachedDigest = IntelligenceDigest.empty()
    cachedDigest.news = [oldArticle]
    cachedDigest.moduleUpdatedAt[.news] = oldNewsDate
    var incomingDigest = IntelligenceDigest.empty()
    incomingDigest.news = [newArticle]
    incomingDigest.moduleUpdatedAt[.news] = newNewsDate
    cachedDigest.merge(incomingDigest, module: .news)
    expectEqual(cachedDigest.news.first?.title, "新新闻", "只合并目标板块内容")
    expectEqual(cachedDigest.lastSuccess(for: .news), newNewsDate, "保留板块最后成功时间")
    expect(cachedDigest.lastSuccess(for: .market) == nil, "未成功的板块不伪造更新时间")

    let codexArticle = NewsArticle(
        id: "codex",
        title: "OpenAI 发布新版 Codex",
        link: URL(string: "https://example.com/codex")!,
        source: "测试",
        category: .aiTechnology,
        publishedAt: now
    )
    expect(AIModelFocus.filter([codexArticle]).count == 1, "重点 AI 模型新闻保留")
    let modelArticle = NewsArticle(
        id: "model",
        title: "国产基础模型发布新版",
        link: URL(string: "https://example.com/model")!,
        source: "测试",
        category: .aiTechnology,
        publishedAt: now
    )
    expect(AIModelFocus.filter([modelArticle]).count == 1, "基础模型新闻保留")

    let quotePayload = """
    {"data":{"diff":[
      {"f2":3680.64,"f3":0.46,"f4":16.92,"f12":"000001","f13":1,"f14":"上证指数"},
      {"f2":1402.30,"f3":-2.55,"f4":-36.70,"f12":"600519","f13":1,"f14":"贵州茅台"}
    ]}}
    """
    let quoteSymbols = [
        StockSymbol(quoteID: "1.000001", code: "000001", name: "上证指数"),
        StockSymbol(quoteID: "1.600519", code: "600519", name: "贵州茅台")
    ]
    if let quotes = try? StockDataParser.parseQuotes(
        data: Data(quotePayload.utf8),
        symbols: quoteSymbols,
        fetchedAt: now
    ) {
        expectEqual(quotes.count, 2, "股票行情解析数量")
        if quotes.count == 2 {
            expectEqual(quotes[1].name, "贵州茅台", "股票名称解析")
            expectEqual(quotes[1].percentText, "-2.55%", "股票跌幅格式")
            expect(quotes[1].isFall, "下跌方向")
        }
    } else {
        expect(false, "股票行情样例应该能解析")
    }

    let tencentQuoteText = """
    v_s_sh000001="1~上证指数~000001~3680.64~16.92~0.46~433120083~73615479~~646127.31~ZS~";
    v_s_sh600519="1~贵州茅台~600519~1402.30~-36.70~-2.55~39848~563387~~17529.89~GP-A~";
    """
    if let quotes = try? TencentStockParser.parseQuotes(
        text: tencentQuoteText,
        symbols: quoteSymbols,
        fetchedAt: now
    ) {
        expectEqual(quotes.count, 2, "腾讯备用行情数量")
        if quotes.count == 2 {
            expectEqual(quotes[0].name, "上证指数", "腾讯指数名称")
            expectEqual(quotes[1].percentText, "-2.55%", "腾讯个股跌幅")
        }
    } else {
        expect(false, "腾讯备用行情样例应该能解析")
    }
    expectEqual(TencentStockParser.requestCode(for: quoteSymbols[0]), "sh000001", "腾讯指数代码")
    expectEqual(TencentStockParser.requestCode(for: quoteSymbols[1]), "sh600519", "腾讯 A 股代码")

    let profilePayload = """
    {"data":{"f84":1250081601,"f85":1250081601,"f116":1794192118651.26,"f117":1794192118651.26,"f162":20.87,"f167":6.62}}
    """
    if let profile = try? StockDetailParser.parseProfile(data: Data(profilePayload.utf8)) {
        expectEqual(profile.pe, 20.87, "股票市盈率解析")
        expect(profile.totalMarketCap > 1_000_000_000_000, "股票总市值解析")
    } else {
        expect(false, "股票概览样例应该能解析")
    }

    let flowPayload = """
    {"data":{"klines":["2026-11-13,289962976.0,-350064.0,-289612896.0,107835616.0,182127360.0"]}}
    """
    if let flows = try? StockDetailParser.parseFundFlow(data: Data(flowPayload.utf8)) {
        expectEqual(flows.count, 1, "资金流向数量")
        if let first = flows.first {
            expectEqual(first.superLargeNet, 182127360, "超大单资金")
        }
    } else {
        expect(false, "资金流向样例应该能解析")
    }

    let sectorPayload = """
    {"data":{"diff":[{"f12":"BK1300","f14":"院线","f3":12.5,"f62":769179824.0,"f184":27.39}]}}
    """
    if let sectors = try? StockDetailParser.parseSectors(data: Data(sectorPayload.utf8)) {
        expectEqual(sectors.first?.name, "院线", "板块名称")
        expectEqual(sectors.first?.mainNetRatio, 27.39, "板块资金占比")
    } else {
        expect(false, "板块样例应该能解析")
    }

    let financePayload = """
    {"data":[{"REPORT_DATE_NAME":"2026三季报","TOTALOPERATEREVE":133283652508.95,"PARENTNETPROFIT":64467425981.95,"ROEJQ":24.47,"XSMLL":89.58,"XSJLL":50.94}]}
    """
    if let finance = try? StockDetailParser.parseFinance(data: Data(financePayload.utf8)) {
        expectEqual(finance.reportName, "2026三季报", "财报报告期")
        expectEqual(finance.roe, 24.47, "财报 ROE")
    } else {
        expect(false, "财报样例应该能解析")
    }

    let capitalPayload = """
    {"gbjg":[{"TOTAL_SHARES":1250081601,"UNLIMITED_SHARES":1250081601,"LIMITED_SHARES":0}]}
    """
    if let capital = try? StockDetailParser.parseCapital(data: Data(capitalPayload.utf8)) {
        expectEqual(capital.totalShares, 1250081601, "股本结构")
    } else {
        expect(false, "股本样例应该能解析")
    }

    let holderPayload = """
    {"sdgd":[{"HOLDER_RANK":1,"HOLDER_NAME":"测试集团","HOLD_NUM_RATIO":54.5,"HOLD_NUM":681282935,"HOLD_NUM_CHANGE":"不变"}]}
    """
    if let holders = try? StockDetailParser.parseShareholders(data: Data(holderPayload.utf8)) {
        expectEqual(holders.first?.name, "测试集团", "股东名称")
        expectEqual(holders.first?.ratio, 54.5, "股东比例")
    } else {
        expect(false, "股东样例应该能解析")
    }

    let searchPayload = """
    {"QuotationCodeTable":{"Data":[
      {"Code":"600519","Name":"贵州茅台","QuoteID":"1.600519","Classify":"AStock","SecurityTypeName":"沪A"},
      {"Code":"03750","Name":"宁德时代","QuoteID":"116.03750","Classify":"HK","SecurityTypeName":"港股"},
      {"Code":"13112","Name":"宁德摩通七三购A","QuoteID":"116.13112","Classify":"HK","SecurityTypeName":"港股"}
    ]}}
    """
    if let results = try? StockDataParser.parseSearch(data: Data(searchPayload.utf8)) {
        expectEqual(results.count, 2, "股票搜索过滤衍生品")
        if results.count == 2 {
            expectEqual(results[0].quoteID, "1.600519", "A 股 QuoteID")
            expectEqual(results[1].quoteID, "116.03750", "港股 QuoteID")
        }
    } else {
        expect(false, "股票搜索样例应该能解析")
    }

    let tencentSearch = #"v_hint="sh~600519~\u8d35\u5dde\u8305\u53f0~gzmt~GP-A^us~tme.n~腾讯音乐~txyl~GP^hk~13005~\u8d35\u5dde\u8f6e\u8bc1~gz~QZ""#
    if let results = try? TencentStockParser.parseSearch(text: tencentSearch) {
        expectEqual(results.count, 2, "腾讯搜索过滤衍生品")
        if let first = results.first {
            expectEqual(first.name, "贵州茅台", "腾讯搜索 Unicode 名称")
            expectEqual(first.quoteID, "1.600519", "腾讯搜索 QuoteID")
        }
        if results.count == 2 {
            expectEqual(results[1].quoteID, "106.TME", "腾讯美股后缀归一化")
        }
    } else {
        expect(false, "腾讯搜索样例应该能解析")
    }

    expectEqual(MarketQueryParser.term(from: "贵州茅台股价"), "贵州茅台", "提取股票名称")
    expectEqual(MarketQueryParser.term(from: "贵州茅台的股价"), "贵州茅台", "去掉所属助词")
    expectEqual(MarketQueryParser.term(from: "帮我看看宁德时代行情"), "宁德时代", "提取前缀和后缀")
    expectEqual(MarketQueryParser.term(from: "今天大盘怎么样"), nil, "大盘问题不做个股搜索")

    let weiboPayload = """
    {"ok":1,"data":{"realtime":[
      {"word":"第一条热搜","num":379182,"label_name":"热"},
      {"word":"第二条热搜","num":257562,"label_name":"新"},
      {"word":"第一条热搜","num":100,"label_name":""}
    ]}}
    """
    if let topics = try? WeiboHotSearchParser.parse(data: Data(weiboPayload.utf8)) {
        expectEqual(topics.count, 2, "微博热搜去重")
        if let first = topics.first {
            expectEqual(first.rank, 1, "微博热搜排名")
            expectEqual(first.heatText, "37.9万", "微博热度格式")
            expect(!first.link.absoluteString.isEmpty, "微博话题链接")
        }
    } else {
        expect(false, "微博热搜样例应该能解析")
    }

    let zhihuPayload = """
    {"data":[
      {"target":{"title":"知乎第一条","url":"https://api.zhihu.com/questions/123"},"detail_text":"410 万热度","card_label":{"type":"hot"}},
      {"target":{"title":"知乎第二条","url":"https://api.zhihu.com/questions/456"},"detail_text":"235 万热度","card_label":{"type":""}}
    ]}
    """
    if let topics = try? ZhihuHotParser.parse(data: Data(zhihuPayload.utf8)) {
        expectEqual(topics.count, 2, "知乎热榜数量")
        if topics.count == 2 {
            expectEqual(topics[0].title, "知乎第一条", "知乎标题")
            expectEqual(topics[0].link.absoluteString, "https://www.zhihu.com/question/123", "知乎网页链接")
            expectEqual(topics[0].heatText, "410 万热度", "知乎热度")
        }
    } else {
        expect(false, "知乎热榜样例应该能解析")
    }

    let steamPayload = """
    {"top_sellers":{"items":[{"id":100,"name":"Steam 游戏 A","final_price":26800,"currency":"CNY","header_image":"https://example.com/a.jpg"}]},
     "coming_soon":{"items":[{"id":200,"name":"Steam 期待游戏","final_price":0,"currency":"CNY"}]}}
    """
    if let steam = try? SteamGameParser.parse(data: Data(steamPayload.utf8)) {
        expectEqual(steam.top.first?.name, "Steam 游戏 A", "Steam 畅销榜")
        expectEqual(steam.top.first?.priceText, "CNY 268.00", "Steam 价格")
        expectEqual(steam.coming.first?.name, "Steam 期待游戏", "Steam 期待榜")
        expectEqual(steam.coming.first?.priceText, "价格待定", "Steam 期待价格")
    } else {
        expect(false, "Steam 榜单样例应该能解析")
    }

    let appStorePayload = """
    {"feed":{"entry":[
      {"im:name":{"label":"测试游戏"},"id":{"attributes":{"im:id":"123"}},"category":{"attributes":{"im:id":"6014","term":"Games","label":"游戏"}},"im:artist":{"label":"测试厂商"},"summary":{"label":"游戏简介"},"im:image":[{"label":"https://example.com/icon.png"}],"link":[{"attributes":{"href":"https://apps.apple.com/cn/app/id123"}}]},
      {"im:name":{"label":"购物应用"},"id":{"attributes":{"im:id":"456"}},"category":{"attributes":{"im:id":"6024","term":"Shopping","label":"购物"}}}
    ]}}
    """
    if let games = try? AppStoreGameParser.parse(
        data: Data(appStorePayload.utf8),
        source: "App Store 免费榜",
        idPrefix: "ios-free"
    ) {
        expectEqual(games.count, 1, "App Store 只保留游戏")
        expectEqual(games.first?.name, "测试游戏", "App Store 游戏名称")
        expectEqual(games.first?.rank, 1, "App Store 游戏排名")
    } else {
        expect(false, "App Store 游戏榜样例应该能解析")
    }

    let appStoreDetailPayload = """
    {"results":[{"description":"这是一款测试游戏。","sellerName":"测试开发商","artistName":"测试发行商","releaseDate":"2026-01-01T00:00:00Z","genres":["游戏","策略"],"screenshotUrls":["https://example.com/shot1.png"],"averageUserRating":4.8,"userRatingCount":1234,"version":"1.2.0","formattedPrice":"免费"}]}
    """
    if let detail = try? GameDetailParser.parseAppStore(data: Data(appStoreDetailPayload.utf8)) {
        expectEqual(detail.developer, "测试开发商", "App Store 游戏开发商")
        expectEqual(detail.screenshots.count, 1, "App Store 游戏截图")
        expectEqual(detail.rating, 4.8, "App Store 游戏评分")
    } else {
        expect(false, "App Store 游戏详情应该能解析")
    }

    let steamDetailPayload = """
    {"123":{"success":true,"data":{"detailed_description":"<p>Steam 游戏介绍</p>","developers":["开发商 A"],"publishers":["发行商 B"],"release_date":{"date":"2026 年 1 月"},"genres":[{"description":"动作"},{"description":"冒险"}],"screenshots":[{"path_full":"https://example.com/steam-shot.jpg"}],"price_overview":{"final_formatted":"¥ 98.00"}}}}
    """
    if let detail = try? GameDetailParser.parseSteam(data: Data(steamDetailPayload.utf8), appID: "123") {
        expectEqual(detail.description, "Steam 游戏介绍", "Steam 游戏介绍清洗")
        expectEqual(detail.genres.count, 2, "Steam 游戏类型")
        expectEqual(detail.screenshots.count, 1, "Steam 游戏截图")
    } else {
        expect(false, "Steam 游戏详情应该能解析")
    }

    let gameNewsXML = """
    <rss><channel><item>
      <title><![CDATA[测试游戏新闻]]></title>
      <link>https://www.yystv.cn/p/1</link>
      <pubDate>Fri, 13 Nov 2026 21:15:00 +0800</pubDate>
    </item></channel></rss>
    """
    let gameNewsParser = GameNewsParser()
    let gameXMLParser = XMLParser(data: Data(gameNewsXML.utf8))
    gameXMLParser.delegate = gameNewsParser
    expect(gameXMLParser.parse(), "游戏新闻 XML 应该能解析")
    expectEqual(gameNewsParser.articles.first?.title, "测试游戏新闻", "游戏新闻标题")
    expectEqual(gameNewsParser.articles.first?.category.rawValue, "游戏", "游戏新闻分类")

    let stockSuite = "nomi.logic.stock.\(UUID().uuidString)"
    let stockDefaults = UserDefaults(suiteName: stockSuite)!
    for index in 0..<StockWatchlistStore.limit {
        let symbol = StockSymbol(
            quoteID: "1.90\(index)",
            code: "90\(index)",
            name: "股票\(index)"
        )
        expect(StockWatchlistStore.add(symbol, defaults: stockDefaults), "自选股第 \(index + 1) 只应添加成功")
    }
    let extra = StockSymbol(quoteID: "1.999", code: "999", name: "超出上限")
    expect(!StockWatchlistStore.add(extra, defaults: stockDefaults), "自选股不能超过上限")
    expect(!StockWatchlistStore.add(
        StockSymbol(quoteID: "1.900", code: "900", name: "重复股票"),
        defaults: stockDefaults
    ), "自选股不能重复")
    expectEqual(StockWatchlistStore.load(defaults: stockDefaults).count, 8, "自选股持久化数量")
    StockWatchlistStore.remove(quoteID: "1.900", defaults: stockDefaults)
    expectEqual(StockWatchlistStore.load(defaults: stockDefaults).count, 7, "自选股移除")
    stockDefaults.removePersistentDomain(forName: stockSuite)

    // MARK: - 汇总

    print("")
    if failures == 0 {
        print("✅ 全部通过：\(checks) 项检查")
        exit(0)
    } else {
        print("❌ \(failures) 项失败 / 共 \(checks) 项")
        exit(1)
    }
    }
}
