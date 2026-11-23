import SwiftUI

enum WorkspaceSheet: Identifiable {
    case captureEditor
    case captureDetail(String)

    var id: String {
        switch self {
        case .captureEditor:
            return "capture-editor"
        case .captureDetail(let id):
            return "capture-" + id
        }
    }
}

private struct WhaleDraftDismissGuard: ViewModifier {
    let hasChanges: Bool
    let isBusy: Bool

    func body(content: Content) -> some View {
        content.interactiveDismissDisabled(hasChanges || isBusy)
    }
}

extension View {
    func whaleDraftGuard(
        hasChanges: Bool,
        isBusy: Bool = false
    ) -> some View {
        modifier(
            WhaleDraftDismissGuard(
                hasChanges: hasChanges,
                isBusy: isBusy
            )
        )
    }
}
