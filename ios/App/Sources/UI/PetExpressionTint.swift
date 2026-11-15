import SwiftUI

/// 情绪 → 眼睛颜色。
/// 只在 App target 里编译（Widget Extension 不包含 PetLife.swift）。
extension PetExpression {
    var eyeTint: Color { Color(hex: eyeTintHex) }
}
