import Foundation
import UserNotifications

/// 本地通知。
///
/// 免费 Apple ID **不能**用远程推送（APNs），但**本地通知完全没问题**——
/// 它由系统在设备上按时触发，不需要服务器。
///
/// 目前两条：
/// ① 就寝提醒：每天固定时间，重复
/// ② 下雨提醒：未来几小时有雨时，当天提醒一次
enum NotificationService {

    private static let bedtimeID = "nomi.bedtime"
    private static let rainPrefix = "nomi.rain."

    // MARK: - 权限

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    // MARK: - 就寝

    static func scheduleBedtime(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [bedtimeID])

        let content = UNMutableNotificationContent()
        content.title = "该睡了"
        content.body = "差不多到点了，明天还得起来。"
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: bedtimeID,
                                            content: content,
                                            trigger: trigger)
        center.add(request)
    }

    static func cancelBedtime() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [bedtimeID])
    }

    // MARK: - 早报

    private static let morningID = "nomi.morning"

    /// 每天早上一条：今天的天气 + 第一件事。
    /// 内容在排程时算好，所以要在「打开 App 时」重新排一次，才够新。
    static func scheduleMorningBriefing(hour: Int, minute: Int, body: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [morningID])

        let content = UNMutableNotificationContent()
        content.title = "早上好"
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: morningID,
                                         content: content,
                                         trigger: trigger))
    }

    static func cancelMorningBriefing() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [morningID])
    }

    // MARK: - 会议前

    private static let meetingPrefix = "nomi.meeting."

    /// 今天剩下的会，每个提前 10 分钟响
    static func scheduleMeetingAlerts(_ meetings: [MeetingItem], leadMinutes: Int = 10) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(
            withIdentifiers: allMeetingIDs()
        )

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"

        for meeting in meetings {
            guard let fireDate = Calendar.current.date(byAdding: .minute,
                                                       value: -leadMinutes,
                                                       to: meeting.start),
                  fireDate > Date()
            else { continue }

            let content = UNMutableNotificationContent()
            content.title = "快要开始了"
            content.body = "\(formatter.string(from: meeting.start)) · \(meeting.title)，\(leadMinutes) 分钟后开始。"
            content.sound = .default

            var components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireDate)
            components.second = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let id = meetingPrefix + String(Int(meeting.start.timeIntervalSince1970))
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            if !meetingIDs.contains(id) {
                meetingIDs.append(id)
            }
        }
    }

    /// 清掉所有按 id 前缀排的会议提醒（system 不支持前缀，只能自己记）
    private static var meetingIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: "nomi.meetingIDs") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "nomi.meetingIDs") }
    }

    private static func allMeetingIDs() -> [String] { meetingIDs }

    static func cancelMeetingAlerts() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: meetingIDs)
        meetingIDs = []
    }

    // MARK: - 久坐

    private static let standIDs = (0..<5).map { "nomi.stand.\($0)" }

    /// 久坐提醒的固定时刻
    static let standSlots: [(Int, Int)] = [(10, 0), (11, 30), (14, 0), (15, 30), (17, 0)]

    /// limit = 这次允许排几个（由通知预算决定）
    static func scheduleStandUp(limit: Int = 5) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: standIDs)

        let slots = Array(standSlots.prefix(max(0, min(limit, standSlots.count))))

        for (index, slot) in slots.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "起来走两步"
            content.body = "坐挺久了，动一下再继续。"
            content.sound = .default

            var components = DateComponents()
            components.hour = slot.0
            components.minute = slot.1

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            center.add(UNNotificationRequest(identifier: standIDs[index],
                                             content: content,
                                             trigger: trigger))
        }
    }

    static func cancelStandUp() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: standIDs)
    }

    // MARK: - 下雨

    /// 今天已经提醒过就不再提醒（防打扰）
    private static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return rainPrefix + formatter.string(from: Date())
    }

    static func hasNotifiedRainToday() -> Bool {
        UserDefaults.standard.bool(forKey: todayKey())
    }

    /// 立刻发一条下雨提醒（5 秒后响，免得和 App 里的动作撞在一起）
    static func notifyRain(minutesAhead: Int, chance: Int) {
        guard !hasNotifiedRainToday() else { return }

        let content = UNMutableNotificationContent()
        content.title = "要下雨了"
        content.body = "大概 \(minutesAhead) 分钟后有雨，概率 \(chance)%，出门记得带伞。"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: todayKey(),
                                            content: content,
                                            trigger: trigger)
        UNUserNotificationCenter.current().add(request)

        UserDefaults.standard.set(true, forKey: todayKey())
    }

    /// 从未来几小时的降水概率里找最大值；返回 (多久之后, 概率)
    static func rainOutlook(from weather: Weather, now: Date = Date()) -> (minutes: Int, chance: Int)? {
        var best: (minutes: Int, chance: Int)?

        for hour in weather.hours {
            let delta = hour.time.timeIntervalSince(now)
            // 只看未来 6 小时内、且还没过去的
            guard delta > -600, delta <= 6 * 3600 else { continue }

            let chance = Int(hour.precipitationProbability.rounded())
            guard chance >= 60 else { continue }

            let minutes = max(1, Int(delta / 60))
            if best == nil || chance > best!.chance {
                best = (minutes, chance)
            }
        }
        return best
    }
}
