import Foundation

/// 小人的内部状态：心情、精力、无聊。
/// 纯逻辑，可以在任何平台跑测试。
struct PetLife {

    var mood: Double = 60      // 0…100
    var energy: Double = 100   // 0…100
    var boredom: Double = 0    // 0…100

    private var recentTaps: [Double] = []
    /// 生气 / 哭的冷却期：这段时间内再敲还是同样的反应
    private var upsetUntil: Double = 0
    /// 这一次情绪爆发是"生气"还是"哭"
    private var upsetKind: PetExpression = .angry

    // MARK: - 时间流逝

    mutating func tick(_ dt: Double) {
        // 精力约 90 分钟耗尽，无聊约 42 分钟满
        energy = max(0, energy - 0.018 * dt)
        boredom = min(100, boredom + 0.04 * dt)
        mood += (58 - mood) * 0.006 * dt
    }

    /// 被摸了一下（长按）
    mutating func pet() {
        mood = min(100, mood + 14)
        boredom = max(0, boredom - 22)
        upsetUntil = 0
    }

    /// 被敲了一下。返回它该有什么反应。
    mutating func tap(at now: Double) -> PetExpression {
        recentTaps = recentTaps.filter { now - $0 < 1.6 }
        recentTaps.append(now)

        energy = min(100, energy + 2)
        boredom = max(0, boredom - 12)

        // 1.6 秒内连敲 8 下以上 → 哭了。
        // 这一条必须排在"闹脾气"前面，否则连敲到第 8 下时
        // 会先被生气的冷却挡住，永远哭不出来。
        if recentTaps.count >= 8 {
            recentTaps.removeAll()
            mood = max(0, mood - 14)
            upsetUntil = now + 4.0
            upsetKind = .cry
            return .cry
        }

        // 还在闹脾气：给同一个反应，别一秒一变
        if now < upsetUntil {
            return upsetKind
        }

        // 连敲 4 下 → 生气
        if recentTaps.count >= 4 {
            mood = max(0, mood - 8)
            upsetUntil = now + 3.0
            upsetKind = .angry
            return .angry
        }

        mood = min(100, mood + 4)
        return .calm   // 具体反应交给 randomReaction，那边会看心情
    }

    // MARK: - 敲一下的那个反应（受心情影响）

    /// `roll` 是 0…1 的随机数（方便测试）
    func randomReaction(roll: Double) -> PetIdleEvent {
        let r = max(0, min(0.9999, roll))

        let pool: [PetIdleEvent]
        if mood > 70 {
            // 心情好 → 多是开心的
            pool = [
                PetIdleEvent(expression: .happy,   text: "在呢",   seconds: 2.2),
                PetIdleEvent(expression: .laugh,   text: "哈哈",   seconds: 2.0),
                PetIdleEvent(expression: .excited, text: "嗯！",   seconds: 1.9),
                PetIdleEvent(expression: .happy,   text: "怎么了", seconds: 2.2),
                PetIdleEvent(expression: .curious, text: "嗯？",   seconds: 2.2),
                PetIdleEvent(expression: .bored,   text: "陪我玩", seconds: 2.4)
            ]
        } else if mood < 30 {
            // 心情差 → 多是丧的
            pool = [
                PetIdleEvent(expression: .sad,     text: "……",     seconds: 2.6),
                PetIdleEvent(expression: .sigh,    text: "唉",     seconds: 2.6),
                PetIdleEvent(expression: .doze,    text: "不想动",  seconds: 3.0),
                PetIdleEvent(expression: .sad,     text: "有点空",  seconds: 2.6),
                PetIdleEvent(expression: .curious, text: "怎么了",  seconds: 2.4),
                PetIdleEvent(expression: .happy,   text: "嗯",     seconds: 2.0)
            ]
        } else {
            // 平时：什么都可能
            pool = [
                PetIdleEvent(expression: .curious, text: "嗯？",   seconds: 2.2),
                PetIdleEvent(expression: .happy,   text: "在呢",   seconds: 2.2),
                PetIdleEvent(expression: .laugh,   text: "哈哈",   seconds: 2.0),
                PetIdleEvent(expression: .startle, text: "诶！",   seconds: 1.8),
                PetIdleEvent(expression: .think,   text: "想想…",  seconds: 2.4),
                PetIdleEvent(expression: .doze,    text: "困了",   seconds: 3.0),
                PetIdleEvent(expression: .sigh,    text: "唉",     seconds: 2.6),
                PetIdleEvent(expression: .sad,     text: "有点空",  seconds: 2.6),
                PetIdleEvent(expression: .excited, text: "嘿",     seconds: 1.8),
                PetIdleEvent(expression: .curious, text: "怎么了",  seconds: 2.2)
            ]
        }

        let index = Int(r * Double(pool.count)) % pool.count
        return pool[index]
    }

    /// 表情节奏倍率。
    ///
    /// 所有「表情持续多久」「多久换下一个」都乘它：
    /// 1.0 = 原始节奏，0.8 = 快 20%（同样时间里能看到更多表情）。
    /// 想整体调速只改这一个数。
    static let pace: Double = 0.8

    // MARK: - 自己找事做

    /// `roll` 是 0…1 的随机数（方便测试）
    func pickEvent(roll: Double) -> PetIdleEvent {
        let r = max(0, min(0.9999, roll))

        // 精力低 → 打盹
        if energy < 30, r < 0.22 {
            return PetIdleEvent(expression: .doze, text: "……", seconds: 3.4)
        }

        // 心情低 → 丧 / 哭
        if mood < 32, r >= 0.22, r < 0.44 {
            if r < 0.32 {
                return PetIdleEvent(expression: .cry, text: "有点难受", seconds: 2.8)
            }
            return PetIdleEvent(expression: .sad, text: "突然有点空", seconds: 2.6)
        }

        // 无聊 → 走来走去
        if boredom > 45, r >= 0.44, r < 0.62 {
            return PetIdleEvent(expression: .bored, text: "走走", seconds: 2.8)
        }

        // 精力足 → 蹦 / 跑
        if energy > 80, r >= 0.62, r < 0.74 {
            if r < 0.68 {
                return PetIdleEvent(expression: .excited, text: "嘿！", seconds: 1.8)
            }
            return PetIdleEvent(expression: .running, text: "跑一圈", seconds: 2.2)
        }

        let table: [PetIdleEvent] = [
            PetIdleEvent(expression: .doze,    text: "……",          seconds: 3.2),
            PetIdleEvent(expression: .sigh,    text: "有点没劲",      seconds: 2.6),
            PetIdleEvent(expression: .think,   text: "在想晚饭",      seconds: 2.4),
            PetIdleEvent(expression: .curious, text: "那是什么声音",   seconds: 2.4),
            PetIdleEvent(expression: .happy,   text: "今天还行",      seconds: 2.0),
            PetIdleEvent(expression: .laugh,   text: "哈哈",          seconds: 1.8),
            PetIdleEvent(expression: .sad,     text: "突然有点空",    seconds: 2.6),
            PetIdleEvent(expression: .angry,   text: "谁惹我",        seconds: 2.0)
        ]
        let index = Int(r * Double(table.count)) % table.count
        return table[index]
    }

    /// 下一次自主事件隔多久（秒）
    func nextEventDelay(roll: Double) -> Double {
        var base = (9.0 + roll * 14.0) * PetLife.pace   // 7.2–18.4 秒
        if boredom > 65 { base *= 0.55 }               // 越无聊越折腾
        return base
    }
}

// MARK: - 输出

enum PetExpression: String {
    case calm, happy, laugh, curious, angry, sad, cry
    case doze, sigh, think, startle
    case bored      // 无聊：走来走去
    case excited    // 兴奋：蹦一下
    case running    // 跑一圈

    /// 眼睛开合（1 = 正常）
    var eyeOpen: Double {
        switch self {
        case .calm, .happy, .curious, .think: return 1.0
        case .laugh:   return 0.25
        case .angry:   return 0.55
        case .sad:     return 0.72
        case .cry:     return 0.42
        case .doze:    return 0.12
        case .sigh:    return 0.08
        case .startle: return 1.35
        case .bored:   return 0.85
        case .excited: return 1.20
        case .running: return 1.10
        }
    }

    /// 眼睛缩放
    var eyeScale: Double {
        switch self {
        case .happy:   return 1.20
        case .curious: return 1.10
        case .think:   return 1.05
        case .angry:   return 0.92
        case .startle: return 1.18
        case .excited: return 1.22
        default:       return 1.0
        }
    }

    /// 眼睛的颜色（十六进制）。
    /// 色温跟着情绪走：暖 → 冷 → 红。
    /// 放在纯逻辑层，Windows 上也能验证，不用 SwiftUI。
    var eyeTintHex: String {
        switch self {
        case .calm:    return "5CEBFF"   // 中性青
        case .curious: return "6BF0FF"
        case .think:   return "58D8FF"
        case .bored:   return "3FA8D8"   // 降饱和

        case .happy:   return "7CFFE8"   // 偏暖的薄荷
        case .laugh:   return "8CFFD8"
        case .excited: return "A6FFC9"   // 最暖
        case .running: return "5CEBFF"

        case .startle: return "CFFBFF"   // 接近白

        case .sad:     return "4F8BFF"   // 冷蓝
        case .cry:     return "3D6FF0"   // 更冷更深
        case .doze:    return "2F6FA8"   // 暗
        case .sigh:    return "3570B8"

        case .angry:   return "FF5A4E"   // 红
        }
    }

    /// 一句话状态词，锁屏和灵动岛上显示。
    /// 用「打盹」「溜达」这种，比「待机」更像在形容它在干嘛。
    var statusWord: String {
        switch self {
        case .calm:    return "待机"
        case .curious: return "看什么"
        case .think:   return "发呆"
        case .bored:   return "溜达"
        case .happy:   return "高兴"
        case .laugh:   return "笑"
        case .excited: return "兴奋"
        case .running: return "跑"
        case .startle: return "吓一跳"
        case .sad:     return "低落"
        case .cry:     return "难过"
        case .doze:    return "打盹"
        case .sigh:    return "叹气"
        case .angry:   return "生气"
        }
    }

    /// 这个表情配什么动作
    var action: PetMotionAction {
        switch self {
        case .happy, .startle: return .hop
        case .laugh, .think:   return .nod
        case .doze, .sigh, .cry: return .sit
        case .bored:           return .walk
        case .excited:         return .jump
        case .running:         return .run
        default:               return .idle
        }
    }
}

struct PetIdleEvent {
    let expression: PetExpression
    let text: String
    let seconds: Double
}
