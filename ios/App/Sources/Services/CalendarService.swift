import Foundation
import EventKit

/// 读日历和提醒事项。
/// 只读，不写；没授权就返回空，不弹二次提示。
enum CalendarService {

    private static let eventStore = EKEventStore()
    private static let reminderStore = EKEventStore()

    // MARK: - 授权

    static var hasEventAccess: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }

    static var hasReminderAccess: Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }

    static func requestEventAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            return (try? await eventStore.requestFullAccessToEvents()) ?? false
        }
        return await withCheckedContinuation { continuation in
            eventStore.requestAccess(to: .event) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    static func requestReminderAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            return (try? await reminderStore.requestFullAccessToReminders()) ?? false
        }
        return await withCheckedContinuation { continuation in
            reminderStore.requestAccess(to: .reminder) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - 今日日程

    /// 读某一天的日程（默认今天）
    static func meetings(on day: Date = Date()) async -> [MeetingItem] {
        let status = EKEventStore.authorizationStatus(for: .event)
        let allowed: Bool
        if #available(iOS 17.0, *) {
            allowed = (status == .fullAccess)
        } else {
            allowed = (status == .authorized)
        }
        guard allowed else { return [] }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)

        return events
            .filter { !$0.isDetached }
            .map { event in
                MeetingItem(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "未命名日程",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    location: event.location
                )
            }
            .sorted { $0.start < $1.start }
    }

    static func todayMeetings(now: Date = Date()) async -> [MeetingItem] {
        await meetings(on: now)
    }

    static func tomorrowMeetings(now: Date = Date()) async -> [MeetingItem] {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        return await meetings(on: tomorrow)
    }

    private static func legacyTodayMeetings(now: Date = Date()) async -> [MeetingItem] {
        let status = EKEventStore.authorizationStatus(for: .event)
        let allowed: Bool
        if #available(iOS 17.0, *) {
            allowed = (status == .fullAccess)
        } else {
            allowed = (status == .authorized)
        }
        guard allowed else { return [] }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)

        return events
            .filter { !$0.isDetached }
            .map { event in
                MeetingItem(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "未命名日程",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    location: event.location
                )
            }
            .sorted { $0.start < $1.start }
    }

    // MARK: - 新增日程

    /// 写进系统日历，并挂一个提前提醒。成功返回 true。
    @discardableResult
    static func addEvent(title: String, start: Date, alarmMinutes: Int) async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        let allowed: Bool
        if #available(iOS 17.0, *) {
            allowed = (status == .fullAccess)
        } else {
            allowed = (status == .authorized)
        }
        guard allowed else { return false }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = start
        event.endDate = start.addingTimeInterval(60 * 60)
        event.calendar = eventStore.defaultCalendarForNewEvents

        if alarmMinutes > 0 {
            event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-alarmMinutes * 60)))
        }

        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }

    // MARK: - 改期 / 删除

    /// 找到某个事件（按 id）
    private static func event(withID id: String) -> EKEvent? {
        eventStore.event(withIdentifier: id)
    }

    /// 删掉一个日程
    static func deleteEvent(id: String) async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        let allowed: Bool
        if #available(iOS 17.0, *) {
            allowed = (status == .fullAccess)
        } else {
            allowed = (status == .authorized)
        }
        guard allowed, let event = event(withID: id) else { return false }

        do {
            try eventStore.remove(event, span: .thisEvent, commit: true)
            return true
        } catch {
            return false
        }
    }

    /// 把日程挪到新的开始时间，时长保持不变
    static func moveEvent(id: String, to newStart: Date) async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        let allowed: Bool
        if #available(iOS 17.0, *) {
            allowed = (status == .fullAccess)
        } else {
            allowed = (status == .authorized)
        }
        guard allowed, let event = event(withID: id) else { return false }

        let duration = max(600, event.endDate.timeIntervalSince(event.startDate))
        event.startDate = newStart
        event.endDate = newStart.addingTimeInterval(duration)

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            return true
        } catch {
            return false
        }
    }

    /// 今明两天的所有日程，按时间排
    static func upcomingTwoDays(now: Date = Date()) async -> [MeetingItem] {
        let today = await meetings(on: now)
        guard let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: now) else {
            return today
        }
        let tomorrow = await meetings(on: tomorrowDate)
        return (today + tomorrow).sorted { $0.start < $1.start }
    }

    // MARK: - 未完成待办

    /// 把一条提醒事项标记完成。
    /// 以前只是把卡片划走，提醒还留在「提醒事项」里——等于没完成。
    static func completeReminder(id: String) async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        let allowed: Bool
        if #available(iOS 17.0, *) {
            allowed = (status == .fullAccess)
        } else {
            allowed = (status == .authorized)
        }
        guard allowed else { return false }

        guard let item = reminderStore.calendarItem(withIdentifier: id) as? EKReminder else {
            return false
        }

        item.isCompleted = true
        do {
            try reminderStore.save(item, commit: true)
            return true
        } catch {
            return false
        }
    }

    /// 新建一条提醒事项。
    ///
    /// 写进系统「提醒事项」而不是自建数据库：Siri、提醒事项 App、手表天然同步。
    /// 有截止时间就同时挂一个到点闹钟，没见过用户的日历也能提醒。
    static func createReminder(title: String,
                               due: Date?,
                               notes: String = "") async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        let allowed: Bool
        if #available(iOS 17.0, *) {
            allowed = (status == .fullAccess)
        } else {
            allowed = (status == .authorized)
        }
        guard allowed else { return false }

        guard let defaultList = reminderStore.defaultCalendarForNewReminders() else {
            return false
        }

        let reminder = EKReminder(eventStore: reminderStore)
        reminder.title = title
        reminder.calendar = defaultList
        if !notes.isEmpty { reminder.notes = notes }

        if let due {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: due)
            reminder.addAlarm(EKAlarm(absoluteDate: due))
        }

        do {
            try reminderStore.save(reminder, commit: true)
            return true
        } catch {
            return false
        }
    }

    /// 改一条待办的截止时间（顺带把闹钟改成新的）
    static func updateReminderDue(id: String, due: Date) async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        let allowed: Bool
        if #available(iOS 17.0, *) {
            allowed = (status == .fullAccess)
        } else {
            allowed = (status == .authorized)
        }
        guard allowed else { return false }

        guard let item = reminderStore.calendarItem(withIdentifier: id) as? EKReminder else {
            return false
        }

        item.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: due)
        item.alarms?.forEach { item.removeAlarm($0) }
        item.addAlarm(EKAlarm(absoluteDate: due))

        do {
            try reminderStore.save(item, commit: true)
            return true
        } catch {
            return false
        }
    }

    /// 删掉一条待办（真删，不是隐藏）
    static func deleteReminder(id: String) async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        let allowed: Bool
        if #available(iOS 17.0, *) {
            allowed = (status == .fullAccess)
        } else {
            allowed = (status == .authorized)
        }
        guard allowed else { return false }

        guard let item = reminderStore.calendarItem(withIdentifier: id) as? EKReminder else {
            return false
        }

        do {
            try reminderStore.remove(item, commit: true)
            return true
        } catch {
            return false
        }
    }

    static func openTodos(now: Date = Date()) async -> [TodoItem] {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        let allowed: Bool
        if #available(iOS 17.0, *) {
            allowed = (status == .fullAccess)
        } else {
            allowed = (status == .authorized)
        }
        guard allowed else { return [] }

        let predicate = reminderStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            reminderStore.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        return reminders.map { reminder in
            let components = reminder.dueDateComponents
            let due: Date? = components.flatMap { Calendar.current.date(from: $0) }
            return TodoItem(
                id: reminder.calendarItemIdentifier,
                title: reminder.title ?? "未命名待办",
                due: due
            )
        }
        .sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
    }

    /// 最近完成过的提醒事项。用于待办页的“已完成”历史。
    static func completedTodos(since startDate: Date) async -> [TodoItem] {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        let allowed: Bool
        if #available(iOS 17.0, *) {
            allowed = (status == .fullAccess)
        } else {
            allowed = (status == .authorized)
        }
        guard allowed else { return [] }

        let predicate = reminderStore.predicateForCompletedReminders(
            withCompletionDateStarting: startDate,
            ending: nil,
            calendars: nil
        )

        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            reminderStore.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        return reminders.compactMap { reminder in
            guard let completedAt = reminder.completionDate else { return nil }
            let due = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
            return TodoItem(
                id: reminder.calendarItemIdentifier,
                title: reminder.title ?? "未命名待办",
                due: due,
                completedAt: completedAt
            )
        }
        .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }
}
