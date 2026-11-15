import Foundation

/// 一件待办（提醒事项）
struct TodoItem: Identifiable, Hashable {
    let id: String
    let title: String
    let due: Date?
    var completedAt: Date? = nil
}
