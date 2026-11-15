import Foundation

// MARK: - 它的一生
//
// 三个状态变量：Age（有数据的天数）、Trust（信任）、Know（认知度）。
// 派生：阶段 / 权限 / 确定度 / 外观 / 一天能说几句。
//
// 三条铁律（写死在类型里，不靠自觉）：
//   1. 不喂食、不掉状态、不会死 —— 没有 hunger 这类字段
//   2. 成长 = 变准，不是变饱 —— 只涨 know，不涨"经验值"
//   3. 长期不用只降认知，不降信任 —— onAbsence 只碰 know

enum PetStage: String, CaseIterable, Equatable {
    case stranger    // 1–3 天
    case familiar    // 4–14
    case attuned     // 15–60
    case symbiotic   // 61+

    var title: String {
        switch self {
        case .stranger:  return "陌生"
        case .familiar:  return "熟悉"
        case .attuned:   return "默契"
        case .symbiotic: return "共生"
        }
    }

    /// 这一天它最多说几句
    var dailyCardLimit: Int {
        switch self {
        case .stranger:  return 3
        case .familiar:  return 2
        case .attuned:   return 1
        case .symbiotic: return 1
        }
    }

    /// 敢不敢拒绝你（劝阻）。这是成熟标志，不是解锁奖励
    var canRefuse: Bool {
        self == .attuned || self == .symbiotic
    }

    var maxPermission: Permission {
        switch self {
        case .stranger:  return .suggest
        case .familiar:  return .confirm
        case .attuned:   return .confirm
        case .symbiotic: return .automatic
        }
    }
}

enum Permission: Int, Comparable, Equatable {
    case suggest = 1     // L1 只给判断
    case confirm = 2     // L2 点一下才做
    case automatic = 3   // L3 授权后自动

    static func < (lhs: Permission, rhs: Permission) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .suggest:   return "L1 建议"
        case .confirm:   return "L2 确认后执行"
        case .automatic: return "L3 授权自动"
        }
    }
}

enum Certainty: Equatable {
    case hedged      // "可能"
    case confident   // 直接下结论

    var label: String {
        switch self {
        case .hedged:    return "可能"
        case .confident: return "确定"
        }
    }
}

enum PetEvent: Equatable {
    case accepted    // 采纳了建议
    case dismissed   // 划掉了卡片（中性，不扣分）
    case mistake     // 它判错了，被撤销
}

/// 外观随年龄变化：光晕变实、动作变少。尺寸是设计常量，不随年龄变
struct PetLook: Equatable {
    var scale: Double
    var glow: Double
    var saccadeMin: Double
    var saccadeMax: Double
    var blinkMin: Double
    var blinkMax: Double
}

struct PetState: Codable, Equatable {
    /// 只统计"有数据的天"，没打开的日子不推进
    private(set) var daysWithData: Int = 0
    private(set) var trust: Int = 0
    private(set) var know: Int = 0
    private(set) var idleDays: Int = 0

    init(daysWithData: Int = 0, trust: Int = 0, know: Int = 0, idleDays: Int = 0) {
        self.daysWithData = max(0, daysWithData)
        self.trust = min(100, max(0, trust))
        self.know = min(100, max(0, know))
        self.idleDays = max(0, idleDays)
    }

    // MARK: 派生

    var stage: PetStage {
        switch daysWithData {
        case 0...3:   return .stranger
        case 4...14:  return .familiar
        case 15...60: return .attuned
        default:      return .symbiotic
        }
    }

    var permission: Permission {
        let byTrust: Permission
        if trust >= 40 {
            byTrust = .automatic
        } else if trust >= 10 {
            byTrust = .confirm
        } else {
            byTrust = .suggest
        }
        return min(byTrust, stage.maxPermission)
    }

    var certainty: Certainty {
        // 长期不用也算不确定：不能只看认知分。空了 90 天回来，它没资格下结论
        (idleDays >= 30 || know < 30) ? .hedged : .confident
    }

    var canRefuse: Bool { stage.canRefuse }

    var dailyCardLimit: Int { stage.dailyCardLimit }

    /// 0 = 第 1 天，1 = 第 90 天以后（夹在中间线性插值）
    var ageProgress: Double {
        let t = Double(daysWithData) / 90.0
        return min(max(t, 0), 1)
    }

    var look: PetLook {
        let t = ageProgress
        return PetLook(
            scale:      1.6,               // 设计常量：眼睛占岛高 39%
            glow:       0.5 + 0.4 * t,     // 越老光越实
            saccadeMin: 1.6 + 2.4 * t,     // 越老越少动
            saccadeMax: 3.4 + 4.0 * t,
            blinkMin:   2.4 + 1.6 * t,
            blinkMax:   4.5 + 3.0 * t
        )
    }

    // MARK: 变更

    /// 过了一天。hadData = 这一天它有东西可看（天气/日程/运动任一项）
    mutating func advanceDay(hadData: Bool) {
        if hadData {
            daysWithData += 1
            idleDays = 0
            know = min(100, know + 1)
        } else {
            idleDays += 1
        }
    }

    mutating func apply(_ event: PetEvent) {
        switch event {
        case .accepted:
            trust = min(100, trust + 2)
            know = min(100, know + 1)
        case .dismissed:
            // 中性的"不感兴趣"。不扣信任 —— 惩罚用户的选择是最差的设计
            break
        case .mistake:
            trust = max(0, trust - 3)
        }
    }

    /// 长时间没用：只降认知，不降信任，不触发任何情绪
    mutating func onAbsence(days: Int) {
        guard days >= 30 else { return }
        idleDays = days
        know = max(0, know - (days / 30) * 15)
    }

    /// 启动时跟今天对齐。gap = 距上次活跃过了几天
    mutating func sync(daysSinceLastActive gap: Int, hadDataToday: Bool) {
        guard gap > 0 else { return }

        if gap == 1 {
            advanceDay(hadData: hadDataToday)
            return
        }

        // 中间那些天没打开
        idleDays += (gap - 1)
        if gap >= 30 {
            know = max(0, know - (gap / 30) * 15)
        }
        if hadDataToday {
            daysWithData += 1
            know = min(100, know + 1)
        }
    }

    func can(_ permission: Permission) -> Bool {
        return permission <= self.permission
    }
}