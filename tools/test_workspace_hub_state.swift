import Foundation

@main
struct WorkspaceHubStateTest {
    static func main() {
        precondition(WhaleWorkspaceHubMode.defaultMode == .tasks)
        precondition(
            WhaleWorkspaceHubMode.transition(.tasks, action: .showWorkspace)
                == .workspace
        )
        precondition(
            WhaleWorkspaceHubMode.transition(.workspace, action: .showTasks)
                == .tasks
        )
        print("WORKSPACE_HUB_STATE_OK")
    }
}
