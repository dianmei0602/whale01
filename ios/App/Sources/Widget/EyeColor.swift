import SwiftUI

extension Color {
    /// "5CEBFF" → Color
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

/// 眼睛的默认色。
/// 这里不能引用 PetExpression——那个类型只在 App target 里，
/// Widget Extension 编译这个文件时会找不到。
enum EyePalette {
    static let `default` = Color(hex: "5CEBFF")
}
