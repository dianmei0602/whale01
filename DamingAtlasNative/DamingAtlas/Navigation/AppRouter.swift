import Foundation
import Observation

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home, timeline, people, library, choice

    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: "卷首"
        case .timeline: "时序"
        case .people: "人物"
        case .library: "典籍"
        case .choice: "甲申"
        }
    }

    var symbol: String {
        switch self {
        case .home: "scroll"
        case .timeline: "clock"
        case .people: "person.2"
        case .library: "books.vertical"
        case .choice: "seal"
        }
    }
}

enum AppRoute: Hashable, Identifiable {
    case person(String)
    case event(String)
    case chapter(Int)
    case memorial(String)
    case work(String)
    case source(String)

    var id: String {
        switch self {
        case .person(let id): "person:\(id)"
        case .event(let id): "event:\(id)"
        case .chapter(let id): "chapter:\(id)"
        case .memorial(let id): "memorial:\(id)"
        case .work(let id): "work:\(id)"
        case .source(let id): "source:\(id)"
        }
    }
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    var homePath: [AppRoute] = []
    var timelinePath: [AppRoute] = []
    var peoplePath: [AppRoute] = []
    var libraryPath: [AppRoute] = []
    var choicePath: [AppRoute] = []

    func push(_ route: AppRoute) {
        switch selectedTab {
        case .home: homePath.append(route)
        case .timeline: timelinePath.append(route)
        case .people: peoplePath.append(route)
        case .library: libraryPath.append(route)
        case .choice: choicePath.append(route)
        }
    }
}
