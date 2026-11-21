import Combine
import Foundation

@MainActor
final class HomeShortcutLayoutStore: ObservableObject {
    static let orderKey = "whale.home.shortcuts.order.v1"
    static let hiddenKey = "whale.home.shortcuts.hidden.v1"

    @Published private(set) var order: [DiscoverChannel]
    @Published private(set) var hidden: Set<DiscoverChannel>

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        order = Self.restoredOrder(defaults.stringArray(forKey: Self.orderKey) ?? [])
        hidden = Set(
            (defaults.stringArray(forKey: Self.hiddenKey) ?? [])
                .compactMap(DiscoverChannel.init(rawValue:))
        )
    }

    var visibleChannels: [DiscoverChannel] {
        order.filter { !hidden.contains($0) }
    }

    func move(_ source: DiscoverChannel, before target: DiscoverChannel) {
        guard source != target,
              order.contains(source),
              order.contains(target),
              let sourceIndex = order.firstIndex(of: source) else {
            return
        }
        order.remove(at: sourceIndex)
        let targetIndex = order.firstIndex(of: target) ?? order.endIndex
        order.insert(source, at: targetIndex)
        persist()
    }

    func hide(_ channel: DiscoverChannel) {
        hidden.insert(channel)
        persist()
    }

    func showAll() {
        hidden.removeAll()
        persist()
    }

    func reset() {
        order = DiscoverChannel.allCases
        hidden.removeAll()
        persist()
    }

    private func persist() {
        defaults.set(order.map(\.rawValue), forKey: Self.orderKey)
        defaults.set(hidden.map(\.rawValue).sorted(), forKey: Self.hiddenKey)
    }

    private static func restoredOrder(_ rawValues: [String]) -> [DiscoverChannel] {
        var seen = Set<DiscoverChannel>()
        var restored = rawValues
            .compactMap(DiscoverChannel.init(rawValue:))
            .filter { seen.insert($0).inserted }
        for channel in DiscoverChannel.allCases where !seen.contains(channel) {
            restored.append(channel)
        }
        return restored
    }
}
