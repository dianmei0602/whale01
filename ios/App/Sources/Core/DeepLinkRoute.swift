import Foundation

/// 深度链接解析：只认 `nomi://` 且校验 host。
///
/// 未知参数一律回退到首页，不做任何猜测。
enum DeepLinkRoute: Equatable {
    case home
    case today
    case chat
    /// 打开某个日程（事件 id 可能来自小组件或锁屏动作）
    case event(id: String)
    /// 让它准备某个日程：只把话填进输入框，发送由用户决定
    case prepare(id: String)
    /// 确认某个待执行动作；token 必须能在当前待确认动作里找到
    case confirm(token: String)
    case settings
    case privacy

    static func parse(_ url: URL) -> DeepLinkRoute {
        guard url.scheme == "nomi" else { return .home }

        let host = url.host ?? ""
        // 路径形如 nomi://event/xxx → host = "event", path = "/xxx"
        let rest = url.pathComponents
            .filter { $0 != "/" && !$0.isEmpty }
            .joined(separator: "/")

        switch host {
        case "today", "schedule":
            return .today

        case "chat":
            return .chat

        case "event":
            return rest.isEmpty ? .today : .event(id: rest)

        case "prepare":
            return rest.isEmpty ? .home : .prepare(id: rest)

        case "confirm":
            return rest.isEmpty ? .home : .confirm(token: rest)

        case "settings":
            // nomi://settings/privacy 直接进隐私页
            return rest == "privacy" ? .privacy : .settings

        case "open", "":
            return .home

        default:
            return .home
        }
    }
}
