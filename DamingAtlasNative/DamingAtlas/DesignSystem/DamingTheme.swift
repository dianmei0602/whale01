import SwiftUI

enum DamingTheme {
    static let ground = Color(red: 0.949, green: 0.937, blue: 0.910)
    static let surface = Color(red: 0.992, green: 0.984, blue: 0.965)
    static let raised = Color(red: 0.969, green: 0.953, blue: 0.918)
    static let ink = Color(red: 0.110, green: 0.106, blue: 0.098)
    static let secondary = Color(red: 0.404, green: 0.380, blue: 0.349)
    static let accent = Color(red: 0.608, green: 0.173, blue: 0.141)
    static let frontier = Color(red: 0.059, green: 0.431, blue: 0.337)
    static let finance = Color(red: 0.663, green: 0.463, blue: 0.106)
    static let separator = Color.black.opacity(0.12)
    static let corner: CGFloat = 16
}

struct DamingCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(DamingTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: DamingTheme.corner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DamingTheme.corner, style: .continuous)
                    .stroke(DamingTheme.separator, lineWidth: 1)
            }
    }
}
