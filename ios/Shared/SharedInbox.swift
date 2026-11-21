import Foundation

/// A shared item handed from the Share Extension to the main app.
/// The App Group channel is preferred; the URL scheme carries a copy so the
/// sideload build (which cannot use App Groups under free signing) still works.
struct SharedItem: Codable, Identifiable, Equatable {
    let id: String
    let text: String
    let url: String?
    let title: String?
    let createdAt: Date
    var attachmentName: String? = nil

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasBody: Bool {
        trimmedText.count >= 20
    }
}

enum SharedInbox {
    static let appGroup = "group.com.whale01.whaleagent"
    private static let key = "pending.share.v1"
    private static let attachmentFolder = "shared-attachments"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    /// Test hook so unit tests never touch the real App Group container.
    static var testDefaults: UserDefaults?

    private static var store: UserDefaults {
        testDefaults ?? sharedDefaults ?? .standard
    }

    static var supportsAttachments: Bool {
        sharedContainerURL != nil
    }

    static func save(_ item: SharedItem) {
        guard let data = try? JSONEncoder().encode(item) else { return }
        store.set(data, forKey: key)
        sharedDefaults?.synchronize()
    }

    static func pending() -> SharedItem? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SharedItem.self, from: data)
    }

    static func clear(id: String? = nil) {
        guard let current = pending() else { return }
        if let id, current.id != id { return }
        store.removeObject(forKey: key)
        if let attachmentName = current.attachmentName,
           let url = attachmentURL(for: attachmentName) {
            try? FileManager.default.removeItem(at: url)
        }
        sharedDefaults?.synchronize()
    }

    static func saveAttachment(_ data: Data, fileName: String) -> String? {
        guard !data.isEmpty,
              let base = sharedContainerURL else {
            return nil
        }
        let folder = base.appendingPathComponent(attachmentFolder, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let safeName = "\(UUID().uuidString)-\(fileName.replacingOccurrences(of: "/", with: "-"))"
            try data.write(to: folder.appendingPathComponent(safeName), options: .atomic)
            return safeName
        } catch {
            return nil
        }
    }

    static func attachmentURL(for fileName: String) -> URL? {
        guard let base = sharedContainerURL else {
            return nil
        }
        let url = base
            .appendingPathComponent(attachmentFolder, isDirectory: true)
            .appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }
}
extension Notification.Name {
    static let whaleOpenChat = Notification.Name("whale.open.chat")
}
