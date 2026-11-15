import Foundation
import Observation
import CoreLocation

@Observable
@MainActor
final class AppState {
    private(set) var cards: [DayCard] = []
    private(set) var loading = true
    private(set) var errorText: String?
    private(set) var weatherFailureText: String?
    private(set) var weatherUpdatedAt: Date = .distantPast
    private(set) var currentTemperature: Double?
    private(set) var weatherNow: Weather?
    private(set) var airPM25: Double?
    private(set) var locationFix: LocationFix?

    /// 它的一生：年龄 / 信任 / 认知
    private(set) var pet: PetState

    private var dismissed: Set<String> = []
    private(set) var pendingTodos: [TodoItem] = []
    /// 最近 30 天已完成的提醒事项
    private(set) var completedTodos: [TodoItem] = []
    /// 已经排过的通知（用来 24 小时去重）
    private var noticeHistory: [(key: String, at: Date)] = []
    private var openTodos = 0
    private var firstTodo: String?

    private let store = PetStore()
    private(set) var settings = AppSettingsStore.load()

    /// 首页顶部仪表盘的全部数据
    private(set) var dayStatus = DayStatus()

    private let locationService = LocationService()
    private let stepService = StepService()
    private(set) var faceTracker = FaceTracker()

    private var lastWeather: Weather?
    private var lastPM25: Double?
    private(set) var meetings: [MeetingItem] = []
    /// 上次刷新时间：界面上标「刚刚更新 / N 分钟前」
    private(set) var lastRefreshAt: Date = .distantPast

    init() {
        pet = store.load()
    }

    var canRequestLocation: Bool {
        locationService.authorizationStatus == .notDetermined
    }

    var locationPermissionDenied: Bool {
        switch locationService.authorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    private var bedtime: Date {
        settings.bedtime
    }

    func refresh(useCurrentLocation: Bool = true) async {
        loading = true
        errorText = nil
        weatherFailureText = nil

        // ① 本地数据先读，天气网络慢时不拖住日历和待办。
        let canReadEvents = CalendarService.hasEventAccess
        let todayEvents = canReadEvents ? await CalendarService.todayMeetings() : []
        let canReadReminders = CalendarService.hasReminderAccess
        let fetchedTodos = canReadReminders ? await CalendarService.openTodos() : []

        meetings = todayEvents
        pendingTodos = fetchedTodos
        completedTodos = canReadReminders
            ? await CalendarService.completedTodos(
                since: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            )
            : []
        openTodos = fetchedTodos.count
        firstTodo = fetchedTodos.first?.title

        // ② 步数（CoreMotion，不需要 HealthKit）
        let stepSummary = await stepService.todaySummary()

        dayStatus = makeStatus(city: settings.cityName,
                               usesLocation: locationFix != nil,
                               weather: lastWeather,
                               meetings: todayEvents,
                               todos: fetchedTodos,
                               canReadEvents: canReadEvents,
                               canReadReminders: canReadReminders,
                               steps: stepSummary?.steps,
                               motionOK: stepService.isAuthorized)
        rebuild()
        syncPet()
        lastRefreshAt = Date()
        loading = false

        // ③ 位置与天气独立刷新。
        var fix: LocationFix?
        var city = settings.cityName
        let locationStatus = locationService.authorizationStatus
        if useCurrentLocation,
           locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways {
            fix = await locationService.currentFix(requestPermission: false)
            if let name = fix?.cityName { city = name }
        }

        let latitude = fix?.latitude ?? settings.latitude
        let longitude = fix?.longitude ?? settings.longitude
        var weather = lastWeather

        do {
            weather = try await WeatherService(latitude: latitude, longitude: longitude).load()
            errorText = nil
            weatherFailureText = nil
        } catch {
            weatherFailureText = weatherFailureDescription(error)
            errorText = weatherFailureText
        }

        let fetchedPM25 = try? await AirService(latitude: latitude, longitude: longitude).load()
        let pm25 = fetchedPM25 ?? lastPM25

        currentTemperature = weather?.currentTemperature
        dayStatus = makeStatus(city: city,
                               usesLocation: fix != nil,
                               weather: weather,
                               meetings: todayEvents,
                               todos: fetchedTodos,
                               canReadEvents: canReadEvents,
                               canReadReminders: canReadReminders,
                               steps: stepSummary?.steps,
                               motionOK: stepService.isAuthorized)

        if weatherFailureText == nil {
            lastWeather = weather
            weatherUpdatedAt = Date()
        }
        lastPM25 = pm25
        weatherNow = weather
        airPM25 = pm25
        locationFix = fix
        rebuild()
        syncPet()

        // ④ 主动提醒：早报 / 会议前 / 久坐
        loadNoticeHistory()
        syncProactiveNotifications(weather: weather, meetings: todayEvents)

        lastRefreshAt = Date()

        // 给小组件留一份快照。免费签名下写不进共享容器，Widget 会显示"打开 App 同步"
        WidgetSnapshot.save(makeWidgetSnapshot(meetings: todayEvents,
                                              source: canReadEvents ? "系统日历" : "没有日历权限"))
    }

    private func weatherFailureDescription(_ error: Error) -> String {
        guard let urlError = error as? URLError else {
            return "天气服务暂时不可用。"
        }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "网络不可用，天气暂时没有更新。"
        case .timedOut:
            return "天气请求超时，暂时没有更新。"
        default:
            return "天气服务暂时不可用。"
        }
    }

    /// 早报 / 会议前 / 久坐 / 下雨：先算一遍通知预算，再排。
    ///
    /// 之前五种通知各排各的，一天能冒出十条以上。
    /// 现在统一交给 NotificationPlanner：每天有上限、同一件事 24 小时只说一次。
    func syncProactiveNotifications(weather: Weather?, meetings: [MeetingItem]) {
        let now = Date()
        var candidates: [NoticeCandidate] = []

        // 早报
        if settings.morningBriefingEnabled,
           let fire = nextFire(hour: settings.morningHour, minute: settings.morningMinute, after: now) {
            candidates.append(NoticeCandidate(kind: .morning,
                                              fireAt: fire,
                                              key: "morning-\(dayKey(fire))",
                                              priority: 3))
        }

        // 会前 10 分钟
        if settings.meetingAlertEnabled {
            for meeting in meetings {
                candidates.append(NoticeCandidate(kind: .meeting,
                                                  fireAt: meeting.start.addingTimeInterval(-600),
                                                  key: "meet-\(meeting.id)",
                                                  priority: 4))
            }
        }

        // 久坐
        if settings.standUpEnabled {
            for (index, slot) in NotificationService.standSlots.enumerated() {
                guard let fire = nextFire(hour: slot.0, minute: slot.1, after: now) else { continue }
                candidates.append(NoticeCandidate(kind: .standUp,
                                                  fireAt: fire,
                                                  key: "stand-\(dayKey(fire))-\(index)",
                                                  priority: 1))
            }
        }

        // 下雨
        var rainOutlook: (minutes: Int, chance: Int)?
        if settings.rainAlertEnabled, let weather {
            rainOutlook = NotificationService.rainOutlook(from: weather)
            if let outlook = rainOutlook {
                let fire = now.addingTimeInterval(TimeInterval(outlook.minutes * 60))
                candidates.append(NoticeCandidate(kind: .rain,
                                                  fireAt: max(fire, now.addingTimeInterval(60)),
                                                  key: "rain-\(dayKey(fire))",
                                                  priority: 5))
            }
        }

        let approved = NotificationPlanner.plan(candidates, now: now, history: noticeHistory)
        noticeHistory = NotificationPlanner.merge(history: noticeHistory, approved: approved, now: now)
        saveNoticeHistory()

        let kinds = Set(approved.map { $0.kind })

        // 先全部撤掉，再按批准的排：避免上一轮留下的旧通知
        NotificationService.cancelMorningBriefing()
        NotificationService.cancelMeetingAlerts()
        NotificationService.cancelStandUp()

        // 早报
        if kinds.contains(.morning) {
            var parts: [String] = []

            if let weather {
                parts.append("今天 \(Int(weather.todayMin.rounded()))°~\(Int(weather.todayMax.rounded()))°，\(WeatherCode.text(weather.weatherCode))")
            }

            if let first = meetings.first {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "zh_CN")
                formatter.dateFormat = "HH:mm"
                parts.append("第一件是 \(formatter.string(from: first.start)) 的\(first.title)")
            } else {
                parts.append("今天没有安排")
            }

            NotificationService.scheduleMorningBriefing(hour: settings.morningHour,
                                                        minute: settings.morningMinute,
                                                        body: parts.joined(separator: "；") + "。")
        }

        // 会前
        if kinds.contains(.meeting) {
            let approvedKeys = Set(approved.filter { $0.kind == .meeting }.map { $0.key })
            let list = meetings.filter { approvedKeys.contains("meet-\($0.id)") }
            NotificationService.scheduleMeetingAlerts(list)
        }

        // 久坐
        if kinds.contains(.standUp) {
            let count = approved.filter { $0.kind == .standUp }.count
            NotificationService.scheduleStandUp(limit: count)
        }

        // 下雨
        if kinds.contains(.rain), let outlook = rainOutlook {
            NotificationService.notifyRain(minutesAhead: outlook.minutes, chance: outlook.chance)
        }
    }

    // MARK: - 通知预算的辅助


    private static let noticeHistoryKey = "nomi.noticeHistory"

    private func saveNoticeHistory() {
        let encoded = noticeHistory.map { "\($0.key)|\($0.at.timeIntervalSince1970)" }
        UserDefaults.standard.set(encoded, forKey: Self.noticeHistoryKey)
    }

    private func loadNoticeHistory() {
        let raw = UserDefaults.standard.stringArray(forKey: Self.noticeHistoryKey) ?? []
        noticeHistory = raw.compactMap { line in
            let parts = line.split(separator: "|")
            guard parts.count == 2, let stamp = Double(parts[1]) else { return nil }
            return (String(parts[0]), Date(timeIntervalSince1970: stamp))
        }
    }

    /// 下一个 hh:mm（今天过了就明天）
    private func nextFire(hour: Int, minute: Int, after now: Date) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard var date = calendar.date(from: components) else { return nil }
        if date <= now {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return date
    }

    private func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    /// 就寝提醒跟着设置和开关走：开→重排，关→撤掉
    func syncBedtimeNotification() {
        if settings.bedtimeAlertEnabled {
            NotificationService.scheduleBedtime(hour: settings.bedtimeHour,
                                                minute: settings.bedtimeMinute)
        } else {
            NotificationService.cancelBedtime()
        }
    }

    /// 用户进入位置相关功能时再申请，启动刷新不弹窗。
    func requestLocationAccess() async -> Bool {
        let granted = await locationService.requestAuthorization()
        if granted { await refresh() }
        return granted
    }

    func requestCalendarAccess() async -> Bool {
        let granted = await CalendarService.requestEventAccess()
        if granted { await refresh() }
        return granted
    }

    func requestReminderAccess() async -> Bool {
        let granted = await CalendarService.requestReminderAccess()
        if granted { await refresh() }
        return granted
    }


    /// 从今天的日程整理出小组件要显示的那一件事
    private func makeWidgetSnapshot(meetings: [MeetingItem], source: String) -> WidgetSnapshot {
        let now = Date()
        let upcoming = meetings.filter { ($0.end ?? $0.start) > now }

        guard let next = upcoming.first else {
            return WidgetSnapshot(kind: "done", source: source, updatedAt: now, remainingCount: 0)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"

        var time = formatter.string(from: next.start)
        if let end = next.end { time += "–" + formatter.string(from: end) }

        let seconds = next.start.timeIntervalSince(now)
        let kind: String
        if seconds <= 0 {
            kind = "now"
        } else if seconds <= 10 * 60 {
            kind = "soon"
        } else {
            kind = "upcoming"
        }

        return WidgetSnapshot(eventTitle: next.title,
                              startAt: next.start,
                              timeText: time,
                              place: next.location ?? "",
                              kind: kind,
                              source: source,
                              updatedAt: now,
                              remainingCount: upcoming.count)
    }

    private func makeStatus(city: String,
                            usesLocation: Bool,
                            weather: Weather?,
                            meetings: [MeetingItem],
                            todos: [TodoItem],
                            canReadEvents: Bool,
                            canReadReminders: Bool,
                            steps: Int?,
                            motionOK: Bool) -> DayStatus {
        var status = DayStatus()
        status.cityName = city
        status.usesCurrentLocation = usesLocation
        status.temperature = weather?.currentTemperature
        status.weatherText = weatherSummary(weather)

        status.hasCalendarAccess = canReadEvents
        status.meetingCount = meetings.count

        let now = Date()
        if let next = meetings.first(where: { !$0.isAllDay && $0.start > now }) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "HH:mm"
            status.nextMeetingText = formatter.string(from: next.start) + " " + next.title
        }

        status.hasReminderAccess = canReadReminders
        status.todoCount = todos.count
        status.firstTodoText = todos.first?.title

        status.steps = steps
        status.hasMotionAccess = motionOK
        // 目标是用户自己定的，不是一个写死的 8000
        status.stepGoal = max(1000, settings.stepGoal)

        return status
    }

    private func weatherSummary(_ weather: Weather?) -> String {
        guard let weather = weather else { return "—" }
        let now = Date()
        if let hour = weather.hours.first(where: { $0.time >= now }) {
            if hour.precipitationProbability >= 50 { return "有雨" }
            if hour.precipitationProbability >= 30 { return "可能下雨" }
            return "无雨"
        }
        return "无雨"
    }

    // MARK: - 定位

    /// 按需再取一次位置（助理页问「我在哪」时用）
    func requestLocationNow() async -> LocationFix? {
        guard let fix = await locationService.currentFix() else { return nil }
        locationFix = fix
        return fix
    }

    // MARK: - 跟随人脸

    /// 打开/关闭前置摄像头跟随。只在助理页可见时才该开着。
    func setFaceFollow(_ on: Bool) {
        if on {
            Task { await faceTracker.start() }
        } else {
            faceTracker.stop()
        }
    }

    /// 进后台或切页时调用
    func suspendFaceFollow() {
        faceTracker.stop()
    }

    /// 设置改了之后：只重算卡片，不重新请求天气
    func updateSettings(_ value: AppSettings) {
        settings = value
        AppSettingsStore.save(value)
        rebuild()
        syncPet()
        Task { await refresh() }
    }

    private func rebuild() {
        let input = RulesInput(now: Date(),
                               weather: lastWeather,
                               airPM25: lastPM25,
                               openTodos: openTodos,
                               firstTodo: firstTodo,
                               meetings: meetings,
                               bedtime: bedtime,
                               dismissed: dismissed)
        cards = RulesEngine.cards(for: input)
    }

    // MARK: - 养成

    /// 每次启动跟今天对齐：过了几天、今天有没有东西可看
    private func syncPet() {
        let today = Self.dayKey(Date())
        let gap: Int
        if let last = store.lastActiveDay(), let days = Self.daysBetween(last, today) {
            gap = max(1, days)
        } else {
            gap = 1
        }

        pet.sync(daysSinceLastActive: gap, hadDataToday: !cards.isEmpty)
        store.markActive(today)
        store.save(pet)
    }

    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func daysBetween(_ from: String, _ to: String) -> Int? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let a = formatter.date(from: from), let b = formatter.date(from: to) else {
            return nil
        }
        return Calendar.current.dateComponents([.day], from: a, to: b).day
    }

    // MARK: - 交互（每一次都喂给它）

    func dismiss(_ id: String) {
        dismissed.insert(id)
        cards.removeAll { $0.id == id }
        pet.apply(.dismissed)   // 划掉是中性的，不扣信任
        store.save(pet)
    }

    /// 新建一条待办：写进系统提醒事项，然后刷新列表
    @discardableResult
    func createTodo(title: String, due: Date?) async -> Bool {
        if !CalendarService.hasReminderAccess {
            guard await CalendarService.requestReminderAccess() else { return false }
        }
        let created = await CalendarService.createReminder(title: title, due: due)
        guard created else { return false }

        pendingTodos = await CalendarService.openTodos()
        openTodos = pendingTodos.count
        firstTodo = pendingTodos.first?.title

        pet.apply(.accepted)
        store.save(pet)
        return true
    }

    /// 改一条待办的截止时间
    @discardableResult
    func rescheduleTodo(id: String, due: Date) async -> Bool {
        let ok = await CalendarService.updateReminderDue(id: id, due: due)
        guard ok else { return false }

        pendingTodos = await CalendarService.openTodos()
        openTodos = pendingTodos.count
        firstTodo = pendingTodos.first?.title
        return true
    }

    /// 删掉一条待办
    @discardableResult
    func deleteTodo(id: String) async -> Bool {
        let ok = await CalendarService.deleteReminder(id: id)
        guard ok else { return false }

        pendingTodos = await CalendarService.openTodos()
        openTodos = pendingTodos.count
        firstTodo = pendingTodos.first?.title
        return true
    }

    /// 真正完成一条待办：写回提醒事项，再从列表里去掉
    @discardableResult
    func completeTodo(id: String) async -> Bool {
        let done = await CalendarService.completeReminder(id: id)
        guard done else { return false }

        pendingTodos.removeAll { $0.id == id }
        completedTodos = await CalendarService.completedTodos(
            since: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        )
        openTodos = pendingTodos.count
        firstTodo = pendingTodos.first?.title

        pet.apply(.accepted)
        store.save(pet)
        return true
    }


    /// 用户撤销了它的判断
    func reportMistake() {
        pet.apply(.mistake)
        store.save(pet)
    }

    /// 调试时手动指定的表情；nil = 跟着卡片走
    private var moodOverride: PetMood?

    /// 现在该用什么表情
    var currentMood: PetMood {
        moodOverride ?? PetMood.mood(forCardID: cards.first?.id)
    }

    // MARK: - 调试面板

    /// 手动造一个场景，不用等真实天气
    func debugScenario(_ id: String) {
        moodOverride = nil
        currentTemperature = 18
        switch id {
        case "clear":
            cards = []
        case "rain":
            cards = [DayCard(id: "rain", time: "09:00", icon: "🌧", tint: .blue,
                             fact: "现在 18°，09:00 转小雨",
                             advice: "降水概率 70%，出门带伞", rank: 1, canComplete: false)]
        case "air":
            cards = [DayCard(id: "air", time: "现在", icon: "😷", tint: .orange,
                             fact: "PM2.5 118（中度）",
                             advice: "今天别在户外跑，改室内", rank: 2, canComplete: false)]
        case "warm":
            cards = [DayCard(id: "warm", time: "现在", icon: "🧥", tint: .green,
                             fact: "今天最高 14°，比昨天低 8°",
                             advice: "明显降温，出门加一件外套", rank: 3, canComplete: false)]
        case "meet":
            cards = [DayCard(id: "meet", time: "14:00", icon: "📌", tint: .orange,
                             fact: "方案评审，材料还差一页",
                             advice: "现在补，11:30 前发出", rank: 3, canComplete: false)]
        case "sport":
            cards = [DayCard(id: "sport", time: "17:00", icon: "🏃", tint: .green,
                             fact: "运动窗口 17:00–18:30",
                             advice: "气温 16°，适合慢跑 30 分钟", rank: 4, canComplete: false)]
        case "sleep":
            cards = [DayCard(id: "sleep", time: "今晚", icon: "🌙", tint: .purple,
                             fact: "昨晚 5h40m，比平时少 1.5h",
                             advice: "23:00 前睡", rank: 5, canComplete: false)]
        case "todo":
            cards = [DayCard(id: "todo", time: "今天", icon: "✅", tint: .teal,
                             fact: "季度报表今天到期，还没动",
                             advice: "右滑可以完成", rank: 0, canComplete: true)]
        default:
            break
        }
        syncPet()
    }

    func debugMood(_ mood: PetMood?) {
        moodOverride = mood
    }

    func debugAdvanceAge(_ days: Int) {
        for _ in 0..<days {
            pet.advanceDay(hadData: true)
        }
        store.save(pet)
    }

    func debugReset() {
        moodOverride = nil
        Task { await refresh() }
    }
}
