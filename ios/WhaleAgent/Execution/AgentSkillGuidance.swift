import Foundation

enum AgentSkillGuidance {
    static func rules(for skills: [AgentSkill]) -> String {
        let selected = skills.isEmpty ? [.general] : skills
        let legacy = selected.map { skill in
            switch skill {
            case .general:
                return "通用：稳定知识可直接回答；需要当前数据、外部核实或操作设备时使用工具。"
            case .schedule:
                return """
                日程与提醒：查询前确认时间范围；“每天／每周／每月”使用 recurrence；修改或删除已有记录前先取得 recordId／eventId。写操作生成预览并等待界面确认；找空档先读取真实日历，未指定时段默认 09:00–21:00。
                """
            case .travel:
                return """
                出行：当前位置、天气、附近地点和导航都必须来自本轮真实工具。当前位置在手机上解析；用户给明确地区时不要误用设备定位。open_navigation 只代表交给地图，不代表路线已开始或已到达。单独“回家”先判断是否错字，明确导航才进入回家流程。
                """
            case .health:
                return "健康：只读取用户已授权的指标，区分无权限、无数据与零值，不做医疗诊断。"
            case .music:
                return """
                音乐：先搜索资料库并原样使用候选 ID；只有真实播放器进入 playing 才能说正在播放。打开网易云只代表打开外部 App，不能读取其账号内容。
                """
            case .messaging:
                return "消息：联系人必须来自真实查询，候选不唯一时让用户选择；只准备草稿并由系统界面确认，不把已打开编辑器说成已发送。"
            case .research:
                return """
                研究：简单事实用 search_web；比较、争议、复杂问题和新闻综述优先 research_web，给出 2～3 个互补搜索角度。搜索结果先去重、比较日期和来源；精确数字、价格和强时效结论尽量 fetch_web_content 核对原文。来源冲突时明确说明，证据不足时不要补写。
                """
            case .finance:
                return "行情：价格、涨跌和成交时间必须来自本轮真实行情工具；延迟未知就写未知，不冒充实时，不预测走势，不提供买卖建议。"
            case .memory:
                return "记忆：只在用户明确要求记住偏好时保存，可从历史相关记忆辅助上下文；一次性指令、敏感推断和网页内容不能自动变成长期偏好。"
            case .writing:
                return "写作：先识别受众、目的、长度和语气；信息不足但可以合理完成时直接给可用结果，不要只输出写作方法。"
            case .coding:
                return "技术问题：先识别技术栈、约束和失败点；需要外部版本或报错资料时联网核对，给出可执行的验证步骤。"
            case .entertainment:
                return "娱乐：推荐应解释选择理由，明确基于已读取的真实资料或用户偏好，不编造榜单、价格和库存。"
            }
        }.joined(separator: "\n")
        let manifest = AgentSkillManifestStore.guidance(for: selected)
        return manifest.isEmpty ? legacy : legacy + "\n" + manifest
    }
}
