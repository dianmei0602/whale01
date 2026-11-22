import SwiftUI
import UIKit

enum WhaleIMessagePalette {
    static let outgoing = Color(red: 45 / 255, green: 127 / 255, blue: 132 / 255)
    static let outgoingPressed = Color(red: 37 / 255, green: 105 / 255, blue: 109 / 255)
    static let outgoingText = Color.white
    static let chatOutgoingBubble = Color(
        red: 52 / 255,
        green: 116 / 255,
        blue: 211 / 255
    )

    static let canvas = adaptive(
        light: UIColor(red: 0.953, green: 0.969, blue: 0.961, alpha: 1),
        dark: UIColor(red: 0.055, green: 0.102, blue: 0.114, alpha: 1)
    )
    static let header = adaptive(
        light: UIColor(red: 0.976, green: 0.988, blue: 0.984, alpha: 1),
        dark: UIColor(red: 0.071, green: 0.129, blue: 0.145, alpha: 1)
    )
    static let incoming = adaptive(
        light: UIColor(red: 0.902, green: 0.937, blue: 0.925, alpha: 1),
        dark: UIColor(red: 0.090, green: 0.165, blue: 0.184, alpha: 1)
    )
    static let field = adaptive(
        light: UIColor.white,
        dark: UIColor(red: 0.086, green: 0.153, blue: 0.173, alpha: 1)
    )
    static let line = adaptive(
        light: UIColor(red: 0.839, green: 0.890, blue: 0.875, alpha: 1),
        dark: UIColor(red: 0.165, green: 0.247, blue: 0.273, alpha: 1)
    )
    static let muted = adaptive(
        light: UIColor(red: 0.380, green: 0.459, blue: 0.478, alpha: 1),
        dark: UIColor(red: 0.690, green: 0.780, blue: 0.800, alpha: 1)
    )
    static let text = adaptive(
        light: UIColor(red: 0.090, green: 0.196, blue: 0.220, alpha: 1),
        dark: UIColor(red: 0.929, green: 0.976, blue: 0.984, alpha: 1)
    )
    static let chatIncomingBubble = adaptive(
        light: UIColor.white,
        dark: UIColor(red: 0.115, green: 0.151, blue: 0.171, alpha: 1)
    )
    static let userAvatarBackground = adaptive(
        light: UIColor(red: 0.835, green: 0.859, blue: 0.871, alpha: 1),
        dark: UIColor(red: 0.255, green: 0.294, blue: 0.318, alpha: 1)
    )
    static let userAvatarInk = adaptive(
        light: UIColor(red: 0.365, green: 0.416, blue: 0.443, alpha: 1),
        dark: UIColor(red: 0.875, green: 0.902, blue: 0.914, alpha: 1)
    )

    static func incomingShape(isLast: Bool = true) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: isLast ? 5 : 18,
            bottomTrailingRadius: 18,
            topTrailingRadius: 18,
            style: .continuous
        )
    }

    static func outgoingShape(isLast: Bool = true) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: 18,
            bottomTrailingRadius: isLast ? 5 : 18,
            topTrailingRadius: 18,
            style: .continuous
        )
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

extension Notification.Name {
    static let whalePrefillDraft = Notification.Name("whale.composer.prefill")
}
