import AppIntents
import Foundation

enum WhaleIntentError: LocalizedError {
    case reminderAccessDenied
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .reminderAccessDenied:
            return "没有提醒事项权限，请先在设置中允许鲸鱼访问提醒事项。"
        case .writeFailed(let message):
            return message
        }
    }
}

struct CreateReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "创建提醒"
    static var description = IntentDescription("把一件事写入系统提醒事项，并在指定时间提醒你。")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "事项", requestValueDialog: "要提醒你做什么？")
    var title: String

    @Parameter(title: "提醒时间")
    var dueDate: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("提醒我 \(\.$title)") {
            \.$dueDate
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let operationId = "intent_\(UUID().uuidString.lowercased())"
        var arguments: [String: JSONValue] = [
            "title": .string(title),
            "timezone": .string(TimeZone.current.identifier)
        ]
        if let dueDate {
            arguments["dueAt"] = .string(ToolDate.iso(dueDate))
        }
        let pending = PendingTool(
            tool: "create_reminder",
            toolCallId: operationId,
            operationId: operationId,
            arguments: arguments,
            requiresConfirmation: false
        )
        let result = await execute(pending)
        switch result.status {
        case "success":
            break
        case "needs_authorization":
            throw WhaleIntentError.reminderAccessDenied
        default:
            throw WhaleIntentError.writeFailed(
                result.error?.message ?? "提醒写入失败，请在鲸鱼 App 内查看诊断"
            )
        }

        if let dueDate {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日 HH:mm"
            return .result(dialog: "已创建提醒：\(title)，\(formatter.string(from: dueDate))")
        }
        return .result(dialog: "已创建提醒：\(title)")
    }

    @MainActor
    private func execute(_ pending: PendingTool) async -> ToolResultPayload {
        let router = NativeToolRouter(permissions: PermissionCenter())
        return await router.execute(pending)
    }
}

struct WhaleShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateReminderIntent(),
            phrases: [
                "用\(.applicationName)提醒我",
                "让\(.applicationName)记一件事"
            ],
            shortTitle: "创建提醒",
            systemImageName: "bell.badge"
        )

        AppShortcut(
            intent: CaptureToWorkspaceIntent(),
            phrases: [
                "用\(.applicationName)记到收件箱",
                "让\(.applicationName)记下来"
            ],
            shortTitle: "记录到收件箱",
            systemImageName: "tray.and.arrow.down"
        )

        AppShortcut(
            intent: OpenWorkspaceIntent(),
            phrases: [
                "打开\(.applicationName)工作台",
                "用\(.applicationName)看今天"
            ],
            shortTitle: "打开工作台",
            systemImageName: "square.stack.3d.up"
        )

        AppShortcut(
            intent: ReadDailyQuoteIntent(),
            phrases: [
                "用\(.applicationName)读今日一句",
                "让\(.applicationName)说句鼓励"
            ],
            shortTitle: "朗读今日一句",
            systemImageName: "text.quote"
        )
    }
}
