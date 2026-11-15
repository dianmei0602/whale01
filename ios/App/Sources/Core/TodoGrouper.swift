import Foundation

/// 一组待办：今天 / 明天 / 以后 / 没定时间。
struct TodoGroup: Identifiable, Equatable {
    let id: String
    let title: String
    var items: [TodoItem]
}

/// 把一堆待办按时间分组。
///
/// 纯逻辑：不碰 EventKit，可以在本地跑断言，
/// 免得"今天/明天"这种边界每次都要真机看。
enum TodoGrouper {

    static func group(_ todos: [TodoItem],
                      now: Date = Date(),
                      calendar: Calendar = .current) -> [TodoGroup] {

        var today: [TodoItem] = []
        var tomorrow: [TodoItem] = []
        var later: [TodoItem] = []
        var someday: [TodoItem] = []
        let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now

        for todo in todos {
            guard let due = todo.due else {
                someday.append(todo)
                continue
            }

            // 过期的也算"今天"，而且排在今天最前面
            if due < now || calendar.isDate(due, inSameDayAs: now) {
                today.append(todo)
            } else if calendar.isDate(due, inSameDayAs: tomorrowDate) {
                tomorrow.append(todo)
            } else {
                later.append(todo)
            }
        }

        let byDue: (TodoItem, TodoItem) -> Bool = {
            ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture)
        }

        today.sort(by: byDue)
        tomorrow.sort(by: byDue)
        later.sort(by: byDue)

        var groups: [TodoGroup] = []
        if !today.isEmpty { groups.append(TodoGroup(id: "today", title: "今天", items: today)) }
        if !tomorrow.isEmpty { groups.append(TodoGroup(id: "tomorrow", title: "明天", items: tomorrow)) }
        if !later.isEmpty { groups.append(TodoGroup(id: "later", title: "以后", items: later)) }
        if !someday.isEmpty { groups.append(TodoGroup(id: "someday", title: "没定时间", items: someday)) }
        return groups
    }

    /// 截止时间怎么写：逾期只标"已过期"，不渲染具体时间差
    static func dueText(_ due: Date?,
                        now: Date = Date(),
                        calendar: Calendar = .current) -> String? {
        guard let due else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")

        if due < now { return "已过期" }

        if calendar.isDate(due, inSameDayAs: now) {
            formatter.dateFormat = "HH:mm"
            return "今天 " + formatter.string(from: due)
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        if calendar.isDate(due, inSameDayAs: tomorrow) {
            formatter.dateFormat = "HH:mm"
            return "明天 " + formatter.string(from: due)
        }

        formatter.dateFormat = "M月d日"
        return formatter.string(from: due)
    }

    static func isOverdue(_ due: Date?, now: Date = Date()) -> Bool {
        guard let due else { return false }
        return due < now
    }
}
