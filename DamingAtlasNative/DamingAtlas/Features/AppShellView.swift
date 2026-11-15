import SwiftUI

struct AppShellView: View {
    @State private var router = AppRouter()
    @State private var readingProgress = ReadingProgressStore()

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.homePath) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { RouteDestinationView(route: $0) }
            }
            .tag(AppTab.home)
            .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.symbol) }

            NavigationStack(path: $router.timelinePath) {
                TimelineView()
                    .navigationDestination(for: AppRoute.self) { RouteDestinationView(route: $0) }
            }
            .tag(AppTab.timeline)
            .tabItem { Label(AppTab.timeline.title, systemImage: AppTab.timeline.symbol) }

            NavigationStack(path: $router.peoplePath) {
                PeopleView()
                    .navigationDestination(for: AppRoute.self) { RouteDestinationView(route: $0) }
            }
            .tag(AppTab.people)
            .tabItem { Label(AppTab.people.title, systemImage: AppTab.people.symbol) }

            NavigationStack(path: $router.libraryPath) {
                LibraryView()
                    .navigationDestination(for: AppRoute.self) { RouteDestinationView(route: $0) }
            }
            .tag(AppTab.library)
            .tabItem { Label(AppTab.library.title, systemImage: AppTab.library.symbol) }

            NavigationStack(path: $router.choicePath) {
                ChoiceView()
                    .navigationDestination(for: AppRoute.self) { RouteDestinationView(route: $0) }
            }
            .tag(AppTab.choice)
            .tabItem { Label(AppTab.choice.title, systemImage: AppTab.choice.symbol) }
        }
        .tint(DamingTheme.accent)
        .environment(router)
        .environment(readingProgress)
    }
}

struct RouteDestinationView: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .person(let id): PersonDossierView(personID: id)
        case .event(let id): EventDetailView(eventID: id)
        case .chapter(let number): ChapterDetailView(chapterNumber: number)
        case .memorial(let id): MemorialDetailView(memorialID: id)
        case .work(let id): ReferenceWorkDetailView(workID: id)
        case .source(let id): SourceDetailView(sourceID: id)
        }
    }
}
