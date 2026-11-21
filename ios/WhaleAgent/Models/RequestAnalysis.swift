import Foundation

enum AgentSkill: String, CaseIterable, Codable, Sendable {
    case general
    case schedule
    case travel
    case health
    case music
    case messaging
    case research
    case finance
    case memory
    case writing
    case coding
    case entertainment

    var tools: Set<String> {
        ToolRegistry.availableToolNames(for: self)
    }

    static func normalize(_ rawSkills: [String]) -> [AgentSkill] {
        let values = Set(rawSkills.compactMap { raw in
            AgentSkill(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        })
        return values.isEmpty ? [.general] : values.sorted { $0.rawValue < $1.rawValue }
    }
}

struct RequestAnalysis: Codable, Equatable, Sendable {
    var goal: String
    var tasks: [String]
    var skills: [String]
    var suggestedTools: [String]
    var needsFreshData: Bool
    var needsDeviceAction: Bool
    var missingInformation: [String]
    var riskLevel: String
    var answerFocus: String
    var searchAngles: [String]
    var confidence: Double
    var clarificationQuestion: String?

    var normalizedSkills: [AgentSkill] { AgentSkill.normalize(skills) }

    var isMultiStep: Bool { tasks.count > 1 }
    var isHighRisk: Bool { ["medium", "high"].contains(riskLevel.lowercased()) }

    var shouldVerify: Bool {
        isMultiStep || needsFreshData || isHighRisk || !missingInformation.isEmpty ||
            normalizedSkills.contains(.research) || normalizedSkills.contains(.finance)
    }

    func selectedToolNames(available: Set<String>) -> Set<String> {
        var names = Set(suggestedTools.filter { available.contains($0) })
        for skill in normalizedSkills {
            names.formUnion(skill.tools.filter { available.contains($0) })
        }
        // Retrieval and explicit memory are broadly useful and safe to expose.
        names.formUnion(
            ["list_memory", "set_memory", "search_web", "research_web", "fetch_web_content"]
                .filter { available.contains($0) }
        )
        names.formUnion(AgentPlanningPolicy.coreToolNames.filter { available.contains($0) })
        return names.isEmpty ? available : names
    }

    var promptText: String {
        let taskText = tasks.isEmpty ? "直接回答或执行当前目标" : tasks.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        let skillText = normalizedSkills.map(\.rawValue).joined(separator: ", ")
        let tools = suggestedTools.isEmpty ? "由模型从当前技能工具中选择" : suggestedTools.joined(separator: ", ")
        let missing = missingInformation.isEmpty ? "无" : missingInformation.joined(separator: "；")
        let search = searchAngles.isEmpty ? "无" : searchAngles.joined(separator: "；")
        return """
        目标：\(goal)
        任务步骤：
        \(taskText)
        相关技能：\(skillText)
        首选工具：\(tools)
        需要最新外部数据：\(needsFreshData ? "是" : "否")
        需要设备执行：\(needsDeviceAction ? "是" : "否")
        暂缺信息：\(missing)
        风险级别：\(riskLevel)
        回答重点：\(answerFocus)
        搜索角度：\(search)
        """
    }

    init(
        goal: String,
        tasks: [String] = [],
        skills: [String] = ["general"],
        suggestedTools: [String] = [],
        needsFreshData: Bool = false,
        needsDeviceAction: Bool = false,
        missingInformation: [String] = [],
        riskLevel: String = "low",
        answerFocus: String = "",
        searchAngles: [String] = [],
        confidence: Double = 0.6,
        clarificationQuestion: String? = nil
    ) {
        self.goal = goal
        self.tasks = tasks
        self.skills = skills
        self.suggestedTools = suggestedTools
        self.needsFreshData = needsFreshData
        self.needsDeviceAction = needsDeviceAction
        self.missingInformation = missingInformation
        self.riskLevel = riskLevel
        self.answerFocus = answerFocus
        self.searchAngles = searchAngles
        self.confidence = confidence
        self.clarificationQuestion = clarificationQuestion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goal = try container.decodeIfPresent(String.self, forKey: .goal) ?? "理解并回答用户请求"
        tasks = try container.decodeIfPresent([String].self, forKey: .tasks) ?? []
        skills = try container.decodeIfPresent([String].self, forKey: .skills) ?? ["general"]
        suggestedTools = try container.decodeIfPresent([String].self, forKey: .suggestedTools) ?? []
        needsFreshData = try container.decodeIfPresent(Bool.self, forKey: .needsFreshData) ?? false
        needsDeviceAction = try container.decodeIfPresent(Bool.self, forKey: .needsDeviceAction) ?? false
        missingInformation = try container.decodeIfPresent([String].self, forKey: .missingInformation) ?? []
        riskLevel = try container.decodeIfPresent(String.self, forKey: .riskLevel) ?? "low"
        answerFocus = try container.decodeIfPresent(String.self, forKey: .answerFocus) ?? ""
        searchAngles = try container.decodeIfPresent([String].self, forKey: .searchAngles) ?? []
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0.6
        clarificationQuestion = try container.decodeIfPresent(String.self, forKey: .clarificationQuestion)
    }

    static func heuristic(for text: String) -> RequestAnalysis {
        let compact = text.replacingOccurrences(of: " ", with: "")
        var skills: Set<AgentSkill> = []
        var tools: Set<String> = []
        var tasks: [String] = []
        var fresh = false
        var deviceAction = false
        var risk = "low"

        func add(_ skill: AgentSkill, task: String, candidates: Set<String>) {
            skills.insert(skill)
            tools.formUnion(candidates)
            if !tasks.contains(task) { tasks.append(task) }
        }

        if contains(compact, ["提醒", "日程", "会议", "空档", "安排", "明天", "后天", "每周", "每月", "几点"]) {
            add(.schedule, task: "读取或准备日程与提醒", candidates: AgentSkill.schedule.tools)
            if contains(compact, ["提醒我", "帮我记", "别忘了"]) {
                deviceAction = true
                risk = "medium"
            }
        }
        if contains(compact, ["天气", "下雨", "带伞", "温度", "附近", "导航", "怎么走", "地点", "位置"]) {
            add(.travel, task: "查询位置、天气或地点信息", candidates: AgentSkill.travel.tools)
            fresh = true
        }
        if contains(compact, ["新闻", "最新", "搜索", "查一下", "资料", "比较", "分析一下", "为什么", "是什么", "怎么实现", "推荐", "价格", "多少钱"]) {
            add(.research, task: "查找并核对相关信息", candidates: AgentSkill.research.tools)
            fresh = fresh || contains(compact, ["新闻", "最新", "现在", "今天", "价格", "多少钱"])
        }
        if contains(compact, ["股票", "基金", "行情", "股价", "指数", "涨跌", "自选"]) {
            add(.finance, task: "查询真实行情或自选数据", candidates: AgentSkill.finance.tools)
            fresh = true
        }
        if contains(compact, ["音乐", "听歌", "歌曲", "专辑", "播放", "上一首", "下一首", "暂停"]) {
            add(.music, task: "准备音乐查询或播放控制", candidates: AgentSkill.music.tools)
            deviceAction = deviceAction || contains(compact, ["播放", "暂停", "上一首", "下一首"])
        }
        if contains(compact, ["短信", "邮件", "发给", "告诉", "联系"]) {
            add(.messaging, task: "准备联系人或消息草稿", candidates: AgentSkill.messaging.tools)
            risk = "medium"
        }
        if contains(compact, ["记住", "以后", "偏好", "我叫", "家庭地址", "住址", "记一下", "记下来", "保存到工作区", "上周记", "跟进"]) {
            add(.memory, task: "读取或保存用户偏好", candidates: AgentSkill.memory.tools)
        }
        if contains(compact, ["写", "改写", "润色", "总结", "提纲", "文案"]) {
            add(.writing, task: "组织文字内容", candidates: [])
        }
        if contains(compact, ["代码", "Swift", "Python", "接口", "报错", "架构"]) {
            add(.coding, task: "分析技术问题并给出方案", candidates: [])
        }

        if skills.isEmpty { skills = [.general] }
        if tasks.isEmpty { tasks = [compact] }
        return RequestAnalysis(
            goal: compact,
            tasks: Array(tasks.prefix(5)),
            skills: skills.map(\.rawValue).sorted(),
            suggestedTools: Array(tools).sorted(),
            needsFreshData: fresh,
            needsDeviceAction: deviceAction,
            riskLevel: risk,
            answerFocus: "直接解决用户真正的问题",
            searchAngles: [],
            confidence: skills == [.general] ? 0.45 : 0.65
        )
    }

    private static func contains(_ text: String, _ values: [String]) -> Bool {
        values.contains { text.localizedCaseInsensitiveContains($0) }
    }
}

struct AnswerReview: Codable, Equatable, Sendable {
    var approved: Bool
    var needsUserInput: Bool
    var issues: [String]
    var correctionInstruction: String

    init(
        approved: Bool,
        needsUserInput: Bool = false,
        issues: [String] = [],
        correctionInstruction: String = ""
    ) {
        self.approved = approved
        self.needsUserInput = needsUserInput
        self.issues = issues
        self.correctionInstruction = correctionInstruction
    }
}
