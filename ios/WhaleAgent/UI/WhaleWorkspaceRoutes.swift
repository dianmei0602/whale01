import SwiftUI

struct WhaleWorkspaceRouteView: View {
    let route: WorkspaceRoute
    @ObservedObject var model: AppModel
    @EnvironmentObject private var todoStore: TodoTimelineStore

    @ViewBuilder
    var body: some View {
        switch route {
        case .todos:
            TodoView(
                model: model,
                embedded: true,
                bottomBarInset: 0,
                showsHeader: false,
                hidesNavigationBar: false
            )
            .navigationTitle("待办")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("workspace-todo-list")
        case .todoDetail(let id):
            if let item = todoStore.items.first(where: { $0.id == id }) {
                TodoDetailPage(item: item, model: model)
                    .navigationTitle("待办详情")
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView(
                    "待办已不存在",
                    systemImage: "checklist",
                    description: Text("它可能已在其他页面删除或完成。")
                )
            }
        }
    }
}
