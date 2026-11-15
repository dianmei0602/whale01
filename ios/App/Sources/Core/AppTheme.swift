import Foundation
import SwiftUI

extension AppearanceMode {
    /// nil 表示交给系统
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
