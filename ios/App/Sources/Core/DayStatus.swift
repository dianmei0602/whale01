import Foundation

/// 首页顶部那条状态栏的数据。全部是"已经算好的结论"，UI 不做判断。
struct DayStatus {
    var cityName: String = "—"
    var usesCurrentLocation: Bool = false
    var temperature: Double?
    var weatherText: String = "—"

    var meetingCount: Int = 0
    var nextMeetingText: String?
    var hasCalendarAccess: Bool = false

    var steps: Int?
    var stepGoal: Int = 8000
    var hasMotionAccess: Bool = false

    var todoCount: Int = 0
    var firstTodoText: String?
    var hasReminderAccess: Bool = false
}
