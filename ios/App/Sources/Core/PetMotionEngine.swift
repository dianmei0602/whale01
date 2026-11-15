import Foundation

/// 小人的运动规格：**关键帧驱动**，不做物理模拟。
///
/// 设计约束（从这一轮的讨论里定下来的）：
/// 1. 头永远刚性——缩放只作用在脖子和脚上；
/// 2. 呼吸不规则：吸气快、屏一下、呼气慢、隔一阵喘口大气；
/// 3. 跑步是转身（绕 Y 轴），不是压扁；
/// 4. 所有量都是"关键帧 + 缓动"，没有弹簧的余震。
///
/// 这里是纯函数，不依赖 SwiftUI，可以在任何平台上跑测试。

// MARK: - 输出

struct MotionValues: Equatable {
    /// 整体上下位移（px，负 = 上升）
    var bodyY: Double = 0
    /// 整体倾角（度）
    var bodyRotate: Double = 0
    /// 头部额外旋转（度）——跟随身体但滞后
    var headRotate: Double = 0
    /// 绕 Y 轴转身（度）——跑步时变侧面
    var rotateY: Double = 0

    /// 肢体压缩：只作用在脖子 + 脚
    var limbScaleY: Double = 1
    var limbScaleX: Double = 1

    /// 两只脚的角度
    var footL: Double = 0
    var footR: Double = 0

    /// 眼睛：位移、开合、缩放
    var eyeShiftX: Double = 0
    var eyeOpen: Double = 1
    var eyeScale: Double = 1
}

// MARK: - 动作

enum PetMotionAction: String, CaseIterable {
    case idle
    case walk
    case run
    case jump
    case hop
    case sit
    case nod
}

// MARK: - 缓动

enum Easing {
    case linear
    case easeIn
    case easeOut
    case easeInOut

    func apply(_ x: Double) -> Double {
        let t = max(0, min(1, x))
        switch self {
        case .linear:
            return t
        case .easeIn:
            return t * t
        case .easeOut:
            return 1 - (1 - t) * (1 - t)
        case .easeInOut:
            if t < 0.5 { return 2 * t * t }
            let u = -2 * t + 2
            return 1 - (u * u) / 2
        }
    }
}

struct MotionKey {
    let time: Double
    let value: Double
    let easing: Easing

    init(_ time: Double, _ value: Double, _ easing: Easing = .easeInOut) {
        self.time = time
        self.value = value
        self.easing = easing
    }
}

// MARK: - 引擎

enum PetMotionEngine {

    // MARK: 呼吸参数

    /// 一轮呼吸的四个阶段（吸气 / 屏住 / 呼气 / 歇）
    private struct BreathCycle {
        let inhale: Double
        let hold: Double
        let exhale: Double
        let rest: Double
        let amplitude: Double
        var total: Double { inhale + hold + exhale + rest }
    }

    /// 普通呼吸和"喘大气"两种循环，按周期交替
    private static let normalBreath = BreathCycle(inhale: 1.25, hold: 0.30, exhale: 2.05, rest: 0.75, amplitude: 1.2)
    private static let deepBreath = BreathCycle(inhale: 1.70, hold: 0.50, exhale: 2.70, rest: 0.80, amplitude: 3.6)

    /// 每 6 轮普通呼吸来 1 轮大气
    private static let deepEvery = 6

    private static func breathing(at time: Double) -> (y: Double, stretch: Double) {
        var t = time
        var cycleIndex = 0

        // 把时间切成一轮一轮
        while true {
            let isDeep = (cycleIndex % (deepEvery + 1)) == deepEvery
            let cycle = isDeep ? deepBreath : normalBreath
            if t < cycle.total {
                return sampleBreath(cycle, t)
            }
            t -= cycle.total
            cycleIndex += 1
            if cycleIndex > 5000 { break }   // 防御：不应发生
        }
        return (0, 1)
    }

    private static func sampleBreath(_ c: BreathCycle, _ t: Double) -> (y: Double, stretch: Double) {
        if t < c.inhale {
            let p = Easing.easeOut.apply(t / c.inhale)
            return (-c.amplitude * p, 1 + 0.022 * p)
        }
        let afterInhale = t - c.inhale
        if afterInhale < c.hold {
            return (-c.amplitude, 1.022)
        }
        let afterHold = afterInhale - c.hold
        if afterHold < c.exhale {
            let p = Easing.easeInOut.apply(afterHold / c.exhale)
            return (-c.amplitude * (1 - p), 1 + 0.022 * (1 - p))
        }
        return (0, 1)
    }

    // MARK: 走路 / 跑步的周期

    private static func walkCycle(_ t: Double) -> (y: Double, tilt: Double, fl: Double, fr: Double) {
        let period = 0.72
        let phase = (t.truncatingRemainder(dividingBy: period)) / period * 2 * .pi
        let s = sin(phase)
        return (
            y: -abs(s) * 6.5,
            tilt: s * 4.5,
            fl: max(0, s) * 26,
            fr: max(0, -s) * 26
        )
    }

    private static func runCycle(_ t: Double) -> (y: Double, tilt: Double, fl: Double, fr: Double, ry: Double) {
        // 转身用 0.38 秒走完，之后保持侧面
        let turn: Double
        if t < 0.38 {
            turn = -62 * Easing.easeOut.apply(t / 0.38)
        } else {
            turn = -62
        }

        let gait = sin(t * 10.5)
        return (
            y: -abs(cos(t * 10.5)) * 2.5,
            tilt: -9 + gait * 2.0,
            fl: gait * 46,
            fr: -gait * 46,
            ry: turn
        )
    }

    // MARK: 一次性动作的关键帧

    private static let jumpKeysY: [MotionKey] = [
        MotionKey(0.00, 0, .easeIn),
        MotionKey(0.14, 6, .easeOut),      // 预备：蹲
        MotionKey(0.52, -46, .easeInOut),  // 腾空
        MotionKey(0.88, 0, .easeIn),       // 落地
        MotionKey(1.05, 0, .easeOut)
    ]

    private static let jumpKeysSquash: [MotionKey] = [
        MotionKey(0.00, 1, .linear),
        MotionKey(0.14, 0.90, .easeInOut), // 蹲时压
        MotionKey(0.30, 1.06, .easeOut),   // 起跳拉长
        MotionKey(0.88, 0.88, .easeIn),    // 落地压
        MotionKey(1.05, 1, .easeOut)
    ]

    private static let sitKeysY: [MotionKey] = [
        MotionKey(0.00, 0, .easeInOut),
        MotionKey(0.32, 27, .easeOut),
        MotionKey(0.62, 21, .easeInOut),
        MotionKey(0.82, 25, .easeInOut),
        MotionKey(1.00, 24, .easeOut)
    ]

    private static let sitKeysFeet: [MotionKey] = [
        MotionKey(0.00, 0, .easeInOut),
        MotionKey(0.38, 96, .easeOut),
        MotionKey(0.68, 76, .easeInOut),
        MotionKey(1.00, 82, .easeOut)
    ]

    private static let sitKeysLimb: [MotionKey] = [
        MotionKey(0.00, 1, .easeInOut),
        MotionKey(0.32, 0.90, .easeOut),
        MotionKey(0.62, 1.03, .easeInOut),
        MotionKey(1.00, 0.96, .easeOut)
    ]

    private static let nodKeys: [MotionKey] = [
        MotionKey(0.00, 0, .easeOut),
        MotionKey(0.16, 7, .easeInOut),
        MotionKey(0.34, -2, .easeInOut),
        MotionKey(0.50, 3, .easeInOut),
        MotionKey(0.66, 0, .easeOut)
    ]

    private static let hopKeysY: [MotionKey] = [
        MotionKey(0.00, 0, .easeIn),
        MotionKey(0.10, 4, .easeOut),
        MotionKey(0.34, -26, .easeInOut),
        MotionKey(0.52, 0, .easeIn),
        MotionKey(0.62, 0, .easeOut)
    ]

    // MARK: 采样

    private static func sample(_ keys: [MotionKey], _ t: Double) -> Double {
        guard let first = keys.first else { return 0 }
        if t <= first.time { return first.value }
        guard let last = keys.last else { return 0 }
        if t >= last.time { return last.value }

        for i in 0..<(keys.count - 1) {
            let a = keys[i]
            let b = keys[i + 1]
            if t >= a.time && t <= b.time {
                let span = b.time - a.time
                let p = span > 0 ? (t - a.time) / span : 1
                let eased = b.easing.apply(p)
                return a.value + (b.value - a.value) * eased
            }
        }
        return last.value
    }

    /// 一次性动作播完了吗
    static func isFinished(action: PetMotionAction, elapsed: Double) -> Bool {
        switch action {
        case .idle, .walk, .run:
            return false
        case .jump:  return elapsed >= 1.05
        case .hop:   return elapsed >= 0.62
        case .sit:   return elapsed >= 1.00
        case .nod:   return elapsed >= 0.66
        }
    }

    // MARK: 主入口

    /// - Parameters:
    ///   - action: 当前动作
    ///   - time: 全局时间（用于呼吸和循环动作）
    ///   - elapsed: 当前动作开始到现在（用于一次性动作）
    ///   - followFace: 跟随人脸时的水平偏移（-1…1）
    static func values(action: PetMotionAction,
                       time: Double,
                       elapsed: Double,
                       followFace: Double = 0,
                       eyeOpen: Double = 1,
                       eyeScale: Double = 1) -> MotionValues {

        var v = MotionValues()

        // 呼吸：所有动作都在呼吸，只是幅度被动作盖住
        let breath = breathing(at: time)
        v.bodyY = breath.y
        v.limbScaleY = 1.0 / breath.stretch
        v.bodyRotate = breath.y * 0.35

        switch action {
        case .idle:
            break

        case .walk:
            let w = walkCycle(time)
            v.bodyY += w.y
            v.bodyRotate += w.tilt
            v.footL = w.fl
            v.footR = w.fr

        case .run:
            let r = runCycle(elapsed)
            v.rotateY = r.ry
            v.bodyY += r.y
            v.bodyRotate = r.tilt
            v.footL = r.fl
            v.footR = r.fr

        case .jump:
            v.bodyY = sample(jumpKeysY, elapsed)
            let squash = sample(jumpKeysSquash, elapsed)
            v.limbScaleY = squash
            v.limbScaleX = 1 / squash
            v.bodyRotate = 0

        case .hop:
            v.bodyY = sample(hopKeysY, elapsed)
            v.bodyRotate = 0

        case .sit:
            let y = sample(sitKeysY, elapsed)
            v.bodyY = y
            let feet = sample(sitKeysFeet, elapsed)
            v.footL = feet
            v.footR = -feet
            let limb = sample(sitKeysLimb, elapsed)
            v.limbScaleY = limb
            v.limbScaleX = 1 / limb
            v.bodyRotate = y * 0.08

        case .nod:
            v.headRotate = sample(nodKeys, elapsed)
        }

        // 头部轻微滞后（关键帧版：固定系数，不做弹簧）
        v.headRotate += v.bodyRotate * 0.38

        // 跟随人脸：眼睛先走，头跟一半
        // 3.5 太小了，肉眼看不出在跟；加到 7.0 才有"它在看我"的感觉
        v.eyeShiftX = followFace * 7.0
        v.headRotate += followFace * 3.0

        // 表情：眼睛开合与缩放
        v.eyeOpen = eyeOpen
        v.eyeScale = eyeScale

        return v
    }
}
