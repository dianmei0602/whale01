import Foundation

struct WhaleAgentDraftPlan: Equatable {
    let text: String
    let documentURL: URL?
    let documentLabel: String?
    let imageURL: URL?
    let unsupportedVideoCount: Int

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && documentURL == nil
            && imageURL == nil
            && unsupportedVideoCount == 0
    }

    var primaryAttachmentDescription: String? {
        if let documentLabel {
            return documentLabel
        }
        if imageURL != nil {
            return "照片"
        }
        if unsupportedVideoCount > 0 {
            return "视频"
        }
        return nil
    }
}
