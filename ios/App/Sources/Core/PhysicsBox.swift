import Foundation

/// 盒子里那只被重力折腾的小人。
///
/// 坐标系：盒子是 0…1 的方块，(0,0) 左上、(1,1) 右下。
/// 重力来自设备倾斜（`gravity.x` 向右为正，`gravity.y` 向上为正，所以下落用 -gravity.y）。
struct BoxBody: Equatable {
    /// 位置（0…1）
    var x: Double = 0.5
    var y: Double = 0.18
    /// 速度（每秒移动多少个盒子高度）
    var vx: Double = 0
    var vy: Double = 0
    /// 旋转角度（度）
    var angle: Double = 0
    var angVel: Double = 0
    /// 压扁程度：1 = 正常，<1 = 被压扁
    var squash: Double = 1
    var squashVel: Double = 0
    /// 上一次撞击的强度，给 UI 做一下抖动
    var lastImpact: Double = 0
}

enum PhysicsBox {

    /// 小人占盒子短边的比例（当球用）
    static let radius: Double = 0.085

    /// 撞墙反弹保留多少速度
    static let restitution: Double = 0.42

    /// 落地摩擦
    static let friction: Double = 0.84

    /// 空气阻力（每秒保留比例）
    static let drag: Double = 0.995

    /// 速度上限，防止飞出去
    static let maxSpeed: Double = 3.4

    /// 推进一帧。dt 建议 1/60。
    static func step(_ body: inout BoxBody,
                     dt: Double,
                     gravityX gx: Double,
                     gravityY gy: Double) {

        guard dt > 0 else { return }
        let clamped = min(dt, 0.05)

        body.lastImpact = 0

        // ① 重力
        body.vx += gx * 2.1 * clamped
        body.vy += gy * 2.1 * clamped

        // ② 阻力 + 限速
        let damping = pow(drag, clamped * 60)
        body.vx *= damping
        body.vy *= damping

        let speed = (body.vx * body.vx + body.vy * body.vy).squareRoot()
        if speed > maxSpeed {
            let scale = maxSpeed / speed
            body.vx *= scale
            body.vy *= scale
        }

        // ③ 移动
        body.x += body.vx * clamped
        body.y += body.vy * clamped

        // ④ 撞墙
        let r = radius
        let epsilon = 0.06

        if body.x < r {
            body.x = r
            if body.vx < 0 {
                body.lastImpact = max(body.lastImpact, abs(body.vx))
                body.vx = -body.vx * restitution
            }
        } else if body.x > 1 - r {
            body.x = 1 - r
            if body.vx > 0 {
                body.lastImpact = max(body.lastImpact, abs(body.vx))
                body.vx = -body.vx * restitution
            }
        }

        if body.y < r {
            body.y = r
            if body.vy < 0 {
                body.lastImpact = max(body.lastImpact, abs(body.vy))
                body.vy = -body.vy * restitution
            }
        } else if body.y > 1 - r {
            body.y = 1 - r
            if body.vy > 0 {
                // 撞击强度要在反弹之前取，否则永远是小的
                let impact = abs(body.vy)
                body.lastImpact = max(body.lastImpact, impact)
                body.vy = -body.vy * restitution

                // 落地压扁一下
                if impact > 0.3 {
                    body.squashVel -= impact * 3.2
                }
            }
            // 地面摩擦
            let f = pow(friction, clamped * 60)
            body.vx *= f
        }

        // ⑤ 贴地滚动 / 空中翻转
        let onGround = body.y >= 1 - r - epsilon
        if onGround {
            // 滚动：ω ≈ v / r（半径按盒子比例换算成度/秒）
            let targetAngVel = body.vx * (180.0 / Double.pi) / r
            body.angVel += (targetAngVel - body.angVel) * min(1, 14 * clamped)
        } else {
            body.angVel *= pow(0.995, clamped * 60)
        }
        body.angle += body.angVel * clamped

        // ⑥ 压扁回弹（弹簧）
        let pull = (1 - body.squash) * 140 - body.squashVel * 13
        body.squashVel += pull * clamped
        body.squash += body.squashVel * clamped
        body.squash = min(1.25, max(0.55, body.squash))

        // ⑦ 旋转别转飞
        body.angVel = min(720, max(-720, body.angVel))
    }

    /// 点一下：往上抛一下
    static func toss(_ body: inout BoxBody) {
        body.vy -= 1.6
        body.vx += Double.random(in: -0.5...0.5)
        body.angVel += Double.random(in: -260...260)
        body.squashVel -= 1.2
    }
}
