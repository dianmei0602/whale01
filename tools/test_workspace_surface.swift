import Foundation

@main
struct WorkspaceSurfaceContract {
    static func main() {
        let surfaces = WhaleWorkspaceSurface.allCases
        require(
            surfaces.map(\.rawValue) == ["todos", "notes", "brief"],
            "工作台只能保留待办、记事、晨晚报三个一级入口"
        )
        require(
            surfaces.map(\.title) == ["待办", "记事", "晨晚报"],
            "工作台一级入口标题不符合产品契约"
        )
        require(
            surfaces.map(\.accessibilityIdentifier) == [
                "workspace-section-todos",
                "workspace-section-notes",
                "workspace-section-brief"
            ],
            "工作台一级入口缺少稳定的可访问性标识"
        )
        require(
            surfaces.map(\.icon) == [
                "checklist",
                "note.text",
                "sun.horizon"
            ],
            "工作台一级入口图标不符合契约"
        )

        print("WORKSPACE_SURFACE_CONTRACT_OK")
    }

    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
