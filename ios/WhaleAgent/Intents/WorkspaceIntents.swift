import AppIntents
import Foundation

struct CaptureToWorkspaceIntent: AppIntent {
    static var title: LocalizedStringResource = "记录到鲸鱼收件箱"
    static var description = IntentDescription("保存一句话到鲸鱼工作台，不自动创建待办或日程。")
    static var openAppWhenRun = false

    @Parameter(
        title: "内容",
        requestValueDialog: "要记录什么？",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("记录 \(\.$text) 到鲸鱼收件箱")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return .result(dialog: "没有收到可以保存的内容。")
        }
        await MainActor.run {
            _ = WhaleWorkspaceStore.shared.capture(
                title: "",
                body: cleaned,
                kind: .note
            )
        }
        return .result(dialog: "已保存到鲸鱼收件箱，尚未创建待办或日程。")
    }
}

struct OpenWorkspaceIntent: AppIntent {
    static var title: LocalizedStringResource = "打开鲸鱼工作台"
    static var description = IntentDescription("打开收件箱、晨晚报、知识库、项目和跟进。")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            UserDefaults.standard.set(true, forKey: "whale.open.workspace.pending")
            NotificationCenter.default.post(name: .whaleOpenWorkspace, object: nil)
        }
        return .result()
    }
}

struct ReadDailyQuoteIntent: AppIntent {
    static var title: LocalizedStringResource = "朗读今日一句"
    static var description = IntentDescription("让 Siri 读出鲸鱼今天显示的每日一句。")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let quote = DailyQuote.item(at: Date())
        return .result(dialog: "\(quote.text)。出处：\(quote.source)")
    }
}
