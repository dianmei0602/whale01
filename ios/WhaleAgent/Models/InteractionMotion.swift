import SwiftUI
import UIKit

enum InteractionMotion {
    static func page(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.20)
    }

    static func sheet(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.88)
    }

    static func press(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.20, dampingFraction: 0.70)
    }

    static func waveformEnabled(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }
}

enum WhaleAccessibility {
    static func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
