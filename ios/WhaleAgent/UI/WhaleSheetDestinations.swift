import SwiftUI

enum WorkspaceSheet: Identifiable {
    case captureEditor
    case captureDetail(String)
    case projectEditor
    case followUpEditor
    case reader(SavedArticle)
    case highlight(SavedArticle)

    var id: String {
        switch self {
        case .captureEditor:
            return "capture-editor"
        case .captureDetail(let id):
            return "capture-" + id
        case .projectEditor:
            return "project-editor"
        case .followUpEditor:
            return "follow-up-editor"
        case .reader(let article):
            return "reader-" + article.id
        case .highlight(let article):
            return "highlight-" + article.id
        }
    }
}

enum WorkspaceCaptureDestructiveAction: String, Identifiable {
    case archive
    case delete

    var id: String { rawValue }
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
