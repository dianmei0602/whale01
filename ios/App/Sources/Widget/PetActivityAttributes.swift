import Foundation
import ActivityKit

/// 灵动岛的数据约定。App 负责更新，Widget 负责画。
struct PetActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var moodID: String     // calm / happy / excited / curious / focus / sideeye / tired / sleep / talk
        var glow: Double       // 光晕强度，随宠物年龄变化
        var line: String       // 展开时显示的一行正文

        /// 状态词，比如「待机」「在听」「在想」
        var title: String = "待机"
        /// 英文副标，比如 IDLE / LISTENING / THINKING
        var phase: String = "idle"

        /// 走路的帧号：App 每秒推一次，锁屏上的小人才会动
        var walkTick: Int = 0
        /// 它在做什么：idle / walk / run
        var action: String = "walk"
        /// 眼睛颜色，跟着 App 里的情绪走
        var tintHex: String = "5CEBFF"
        /// 横向位置 0…1（0 最左，1 最右）。锁屏是它的家，随便走。
        var posX: Double = 0.5
        /// 眼睛开合 0…1：打盹时眯起来
        var eyeOpen: Double = 1.0
        /// 脑袋倾斜（度）：正数是低头耷拉，负数是抬头看
        var headTilt: Double = 0
        /// 纵向位置 0…1：开了「锁屏重力」之后，它会掉到框底
        var posY: Double = 0.5
        /// 整体旋转（度）：被重力摔得翻滚
        var bodyRotate: Double = 0

        // MARK: 锁屏事件卡（没有事件时全为空，只显示角色）

        /// 事件名
        var eventTitle: String = ""
        /// 地点（可以空）
        var eventPlace: String = ""
        /// "16:00–17:00"
        var eventTime: String = ""
        /// "22 分钟后" / "进行中"
        var countdown: String = ""
        /// 一行准备提示
        var eventHint: String = ""
        /// idle / upcoming / soon / now
        var eventKind: String = "idle"
        /// 事件 id：动作按钮的深链要用
        var eventID: String = ""
    }

    var startedAt: Date
}
