# Whale 001 UI Interaction Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every Whale 001 screen use one predictable navigation model, one shared todo state, one voice-capture experience, and one feedback/accessibility policy without changing the three-root-entry product structure.

**Architecture:** Keep the three root entries and the paged root container. Give Discover and Workspace independent typed navigation paths, move complete lists out of sheets into pushed pages, replace cross-screen todo arrays with one observable timeline store, centralize workspace modal state, and reuse one bottom-sheet voice component from Chat, Todo, and Workspace.

**Tech Stack:** Swift 5, SwiftUI, iOS 17, Combine/ObservableObject, ExyteChat 3.3.7, XCTest, XCUITest, GitHub Actions, XcodeGen.

**Spec:** `docs/plans/2026-11-23-whale-ui-interaction-refactor.md`

## Global Constraints

- Keep exactly three visible root entries: 首页, 发现, 工作台.
- Keep one product Agent. Do not introduce multiple runtime agents.
- Keep iOS deployment target `17.0`, Swift version `5.0`, and ExyteChat `3.3.7`.
- Keep permissions on demand; do not request all permissions at launch.
- Preserve real system data boundaries. Never fabricate reminders, calendar events, news, prices, playback, or completed operations.
- Any write to Reminders, Calendar, messages, preferences, or memories must be previewed or explicitly confirmed.
- Preserve the titanium whale, blue eyes, Life Agent tone, and the user's rejection of business-dashboard styling.
- Preserve draft text when voice capture is cancelled, interrupted, or loses network.
- Keep installation artifacts under `release/`; never default to the desktop.
- Do not push, tag, build an IPA, or publish a release unless the user explicitly asks.
- Preserve the untracked files `docs/plans/whale-2.1-execution-plan.md` and `docs/plans/whale-3.0-execution-plan.md`.
- One writer owns overlapping Swift files during execution.

## Time Budget

- Tasks 1-4: 1.5-2 working days
- Tasks 5-7: 1.5-2 working days
- Tasks 8-10: 2-2.5 working days
- Tasks 11-13: 1-1.5 working days
- Device acceptance and sideload build: 0.5-1 working day

## File Structure

### New source files

- `ios/WhaleAgent/Models/AppNavigation.swift`  
  Typed root navigation state, Workspace routes, and reselect behavior.
- `ios/WhaleAgent/Models/TodoTimelineStore.swift`  
  Single observable source for todo rows shared by Home, Workspace, Todo, and the daily review.
- `ios/WhaleAgent/Models/VoiceCapturePresentation.swift`  
  Voice target copy, voice phase, and reducer used by the unified voice sheet.
- `ios/WhaleAgent/Models/InteractionMotion.swift`  
  Shared motion durations, spring settings, and reduce-motion decisions.
- `ios/WhaleAgent/UI/WhaleVoiceCaptureSheet.swift`  
  The only bottom-sheet voice recorder used by all voice entry points.
- `ios/WhaleAgent/UI/WhaleSheetDestinations.swift`  
  Workspace and root sheet enums plus reusable draft dismissal/confirmation helpers.
- `ios/WhaleAgent/UI/TodoDetailPage.swift`  
  Pushed todo detail page that reuses existing detail controls without nesting another sheet.
- `ios/WhaleAgent/UI/WhaleWorkspaceRoutes.swift`  
  Workspace route destinations extracted from the main workspace file.

### New test files

- `ios/WhaleAgentTests/AppNavigationTests.swift`
- `ios/WhaleAgentTests/TodoTimelineStoreTests.swift`
- `ios/WhaleAgentTests/VoiceCapturePresentationTests.swift`
- `ios/WhaleAgentTests/InteractionMotionTests.swift`
- `tools/test_ui_interaction_contract.py`

### Existing files expected to change

- `ios/WhaleAgent/UI/RootView.swift`
- `ios/WhaleAgent/UI/DiscoverView.swift`
- `ios/WhaleAgent/UI/WhaleHomeCanvas.swift`
- `ios/WhaleAgent/UI/WhaleWorkspaceView.swift`
- `ios/WhaleAgent/UI/TodoView.swift`
- `ios/WhaleAgent/UI/TodoV2Sheets.swift`
- `ios/WhaleAgent/UI/ChatHomeView.swift`
- `ios/WhaleAgent/UI/VoiceView.swift`
- `ios/WhaleAgent/UI/MusicView.swift`
- `ios/WhaleAgent/UI/DiscoverLibraryView.swift`
- `ios/WhaleAgentUITests/InteractionUITests.swift`
- `.github/workflows/ios-simulator-build.yml`
- `.github/workflows/ios-ui-tests.yml`
- `README.md`
- `CHANGELOG.md`
- `docs/logs/`

### Files to remove only after reference checks

- `ios/WhaleAgent/UI/ConversationSurface.swift`
- `ios/WhaleAgent/UI/ConversationComposerBar.swift`
- `ios/WhaleAgent/UI/WhaleIMessageHomeView.swift`
- `ios/WhaleAgent/UI/QuickActionEditor.swift`
- `ios/WhaleAgent/UI/WhaleCompanionView.swift`

---

### Task 1: Repair the UI-test baseline

**Files:**
- Modify: `ios/WhaleAgentUITests/InteractionUITests.swift:40-115`
- Modify: `ios/WhaleAgentUITests/InteractionUITests.swift:270-300`
- Test: `ios/WhaleAgentUITests/InteractionUITests.swift`

**Interfaces:**
- Consumes: Existing launch helper and accessibility identifiers.
- Produces: Stable baseline tests for Home, Workspace, and the voice sheet; these identifiers are reused by later tasks.

- [ ] **Step 1: Replace the stale home assertion**

The current test searches for `home-primary-task`, but that identifier exists only in an unused view. Make the baseline assert components that are actually rendered today.

```swift
func testHomeRendersCurrentLandingContent() {
    let app = launch()

    XCTAssertTrue(
        app.descendants(matching: .any)["home-inspiration-card"]
            .waitForExistence(timeout: 10)
    )
    XCTAssertTrue(
        app.descendants(matching: .any)["home-today-card"]
            .waitForExistence(timeout: 10)
    )
    XCTAssertTrue(app.buttons["home-start-conversation"].exists)
    XCTAssertFalse(app.buttons["home-primary-task"].exists)
}
```

- [ ] **Step 2: Add the missing Workspace return regression**

```swift
func testWorkspaceTodoPageCanReturnToWorkspaceOverview() {
    let app = launch()
    tab(app, "records").tap()

    let openAll = app.buttons["workspace-open-todo"]
    XCTAssertTrue(openAll.waitForExistence(timeout: 10))
    openAll.tap()

    XCTAssertTrue(
        app.descendants(matching: .any)["workspace-todo-list"]
            .waitForExistence(timeout: 10)
    )

    let navigationBar = app.navigationBars.firstMatch
    XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))
    navigationBar.buttons.element(boundBy: 0).tap()

    XCTAssertTrue(
        app.descendants(matching: .any)["workspace-tasks-overview"]
            .waitForExistence(timeout: 5)
    )
}
```

- [ ] **Step 3: Add the shared voice identifier contract**

```swift
func testVoiceExperienceUsesOneSharedSheet() {
    let app = launch()
    openChat(app)

    let voice = app.buttons["whale-chat-voice"]
    XCTAssertTrue(voice.waitForExistence(timeout: 10))
    voice.tap()

    XCTAssertTrue(
        app.descendants(matching: .any)["whale-voice-capture-sheet"]
            .waitForExistence(timeout: 5)
    )
    XCTAssertTrue(app.buttons["whale-voice-cancel"].exists)
}
```

- [ ] **Step 4: Run the UI test suite and verify the new tests fail**

Push only after explicit user authorization, then dispatch:

```powershell
python tools/github_ci.py `
  --repo dianmei0602/whale01 `
  --branch ui-sea-salt-0.8 `
  --dispatch ios-ui-tests.yml `
  --input scope=ui
```

Expected:

- `testHomeRendersCurrentLandingContent` passes.
- First run of `testWorkspaceTodoPageCanReturnToWorkspaceOverview` fails because `workspace-todo-list` does not exist.
- First run of `testVoiceExperienceUsesOneSharedSheet` fails because `whale-voice-capture-sheet` does not exist.

- [ ] **Step 5: Commit only the test-baseline changes**

```powershell
git add ios/WhaleAgentUITests/InteractionUITests.swift
git commit -m "test: establish ui interaction regression baseline"
```

---

### Task 2: Add typed root navigation and reselect behavior

**Files:**
- Create: `ios/WhaleAgent/Models/AppNavigation.swift`
- Create: `ios/WhaleAgentTests/AppNavigationTests.swift`
- Modify: `ios/WhaleAgent/UI/RootView.swift:9-225`
- Modify: `ios/WhaleAgent/UI/DiscoverView.swift:1-115`
- Test: `ios/WhaleAgentTests/AppNavigationTests.swift`

**Interfaces:**

- Consumes:
  - `AppTab`
  - `DiscoverRoute`
- Produces:
  - `WorkspaceRoute`
  - `RootNavigationModel`
  - `RootNavigationModel.reselect(_:)`
  - `RootNavigationModel.openWorkspace(_:)`

- [ ] **Step 1: Write the failing navigation tests**

```swift
import XCTest
@testable import WhaleAgent

@MainActor
final class AppNavigationTests: XCTestCase {
    func testWorkspaceReselectPopsToRoot() {
        let navigation = RootNavigationModel(selectedTab: .records)
        navigation.workspacePath = [.todos, .todoDetail("task-1")]

        navigation.reselect(.records)

        XCTAssertTrue(navigation.workspacePath.isEmpty)
        XCTAssertEqual(navigation.selectedTab, .records)
    }

    func testDiscoverReselectPopsToChannelRoot() {
        let navigation = RootNavigationModel(selectedTab: .discover)
        navigation.discoverPath = [
            .news(
                NewsItem(
                    id: "news-1",
                    title: "标题",
                    summary: "摘要",
                    source: "来源",
                    link: "https://example.com",
                    publishedAt: nil,
                    channel: .ai,
                    rank: nil
                )
            )
        ]

        navigation.reselect(.discover)

        XCTAssertTrue(navigation.discoverPath.isEmpty)
    }

    func testHomeReselectReturnsToLandingMode() {
        let navigation = RootNavigationModel(selectedTab: .conversation)
        navigation.conversationMode = .chat

        navigation.reselect(.conversation)

        XCTAssertEqual(navigation.conversationMode, .home)
    }

    func testOpeningWorkspaceRouteSelectsWorkspaceAndPushesRoute() {
        let navigation = RootNavigationModel(selectedTab: .discover)

        navigation.openWorkspace(.todos)

        XCTAssertEqual(navigation.selectedTab, .records)
        XCTAssertEqual(navigation.workspacePath, [.todos])
    }
}
```

- [ ] **Step 2: Run the tests and verify they fail**

Run in GitHub Actions or on a macOS machine:

```bash
cd ios
xcodegen generate
xcodebuild \
  -project WhaleAgent.xcodeproj \
  -scheme WhaleAgent \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Expected: compile failure because `RootNavigationModel` and `WorkspaceRoute` do not exist.

- [ ] **Step 3: Implement the navigation model**

```swift
import Combine
import SwiftUI

enum WorkspaceRoute: Hashable {
    case todos
    case todoDetail(String)
}

@MainActor
final class RootNavigationModel: ObservableObject {
    @Published var selectedTab: AppTab
    @Published var conversationMode: ConversationEntryMode
    @Published var discoverPath: [DiscoverRoute]
    @Published var workspacePath: [WorkspaceRoute]

    init(
        selectedTab: AppTab = .conversation,
        conversationMode: ConversationEntryMode = .home,
        discoverPath: [DiscoverRoute] = [],
        workspacePath: [WorkspaceRoute] = []
    ) {
        self.selectedTab = selectedTab
        self.conversationMode = conversationMode
        self.discoverPath = discoverPath
        self.workspacePath = workspacePath
    }

    func select(_ tab: AppTab) {
        selectedTab = tab
    }

    func reselect(_ tab: AppTab) {
        selectedTab = tab
        switch tab {
        case .conversation:
            conversationMode = .home
        case .discover:
            discoverPath = []
        case .records:
            workspacePath = []
        case .settings:
            selectedTab = .conversation
            conversationMode = .home
        }
    }

    func openWorkspace(_ route: WorkspaceRoute? = nil) {
        selectedTab = .records
        workspacePath = route.map { [$0] } ?? []
    }
}
```

- [ ] **Step 4: Move RootView state into the navigation model**

Replace independent `page`, `conversationMode`, and navigation ownership with one model:

```swift
@StateObject private var navigation = RootNavigationModel(
    selectedTab: NavigationHabits.restoredTab(
        UserDefaults.standard.string(forKey: "whale.root.tab")
    )
)
```

Use bindings from the model:

```swift
ConversationTabView(
    model: model,
    entryMode: $navigation.conversationMode,
    bottomInset: 0,
    onOpenRecords: { showRecords = true },
    onOpenSettings: { showSettings = true },
    onOpenMusic: { openDiscover(.music) },
    onOpenTodo: { navigation.openWorkspace(.todos) },
    onOpenDiscover: openDiscover,
    onOpenWorkspace: { navigation.openWorkspace() }
)
```

Replace `page` references in persistence and tab selection:

```swift
.onChange(of: navigation.selectedTab) { _, tab in
    UserDefaults.standard.set(tab.rawValue, forKey: "whale.root.tab")
    UISelectionFeedbackGenerator().selectionChanged()
}
```

- [ ] **Step 5: Make Discover consume the shared typed path**

Change `DiscoverView` from local `NavigationPath` to an injected typed path:

```swift
struct DiscoverView: View {
    @Binding var selection: DiscoverChannel
    @Binding var path: [DiscoverRoute]
    // existing properties remain
}
```

Replace:

```swift
.onChange(of: selection) { _, _ in path = NavigationPath() }
```

with:

```swift
.onChange(of: selection) { _, _ in path = [] }
```

- [ ] **Step 6: Run the unit tests**

```bash
cd ios
xcodebuild \
  -project WhaleAgent.xcodeproj \
  -scheme WhaleAgent \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Expected: all `AppNavigationTests` pass and existing tests remain green.

- [ ] **Step 7: Commit**

```powershell
git add ios/WhaleAgent/Models/AppNavigation.swift `
  ios/WhaleAgentTests/AppNavigationTests.swift `
  ios/WhaleAgent/UI/RootView.swift `
  ios/WhaleAgent/UI/DiscoverView.swift
git commit -m "feat: add typed root navigation state"
```

---

### Task 3: Create one shared todo timeline store

**Files:**
- Create: `ios/WhaleAgent/Models/TodoTimelineStore.swift`
- Create: `ios/WhaleAgentTests/TodoTimelineStoreTests.swift`
- Modify: `ios/WhaleAgent/UI/RootView.swift`
- Test: `ios/WhaleAgentTests/TodoTimelineStoreTests.swift`

**Interfaces:**

- Consumes:
  - `TodoReminder`
- Produces:
  - `TodoTimelineStore.items`
  - `TodoTimelineStore.pending`
  - `TodoTimelineStore.completed`
  - `TodoTimelineStore.replaceLoaded(_:)`
  - `TodoTimelineStore.upsert(_:)`
  - `TodoTimelineStore.remove(id:)`
  - `TodoTimelineStore.markLoaded()`

- [ ] **Step 1: Write the failing store tests**

```swift
import XCTest
@testable import WhaleAgent

@MainActor
final class TodoTimelineStoreTests: XCTestCase {
    private func item(
        id: String,
        title: String,
        completed: Bool = false,
        dueAt: Date? = nil
    ) throws -> TodoReminder {
        var object: [String: JSONValue] = [
            "recordId": .string(id),
            "title": .string(title),
            "completed": .bool(completed),
            "listName": .string("提醒事项")
        ]
        if let dueAt {
            object["dueAt"] = .string(ToolDate.iso(dueAt))
        }
        return try XCTUnwrap(TodoReminder(json: .object(object)))
    }

    func testUpsertUpdatesEveryObserverOfTheSameIdentity() throws {
        let store = TodoTimelineStore()
        let original = try item(id: "1", title: "写周报")
        store.replaceLoaded([original])

        let completed = try item(id: "1", title: "写周报", completed: true)
        store.upsert(completed)

        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(store.items[0].completed)
    }

    func testPendingSortsDatedItemsBeforeUndatedItems() throws {
        let store = TodoTimelineStore()
        let undated = try item(id: "a", title: "整理桌面")
        let dueSoon = try item(
            id: "b",
            title: "取快递",
            dueAt: Date().addingTimeInterval(3_600)
        )

        store.replaceLoaded([undated, dueSoon])

        XCTAssertEqual(store.pending.map(\.id), ["b", "a"])
    }

    func testRemoveDropsOnlyTheRequestedIdentity() throws {
        let store = TodoTimelineStore()
        store.replaceLoaded([
            try item(id: "a", title: "一项"),
            try item(id: "b", title: "二项")
        ])

        store.remove(id: "a")

        XCTAssertEqual(store.items.map(\.id), ["b"])
    }
}
```

- [ ] **Step 2: Run the tests and verify compile failure**

```bash
cd ios
xcodegen generate
xcodebuild \
  -project WhaleAgent.xcodeproj \
  -scheme WhaleAgent \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Expected: compile failure because `TodoTimelineStore` does not exist.

- [ ] **Step 3: Implement the store**

```swift
import Combine
import Foundation

@MainActor
final class TodoTimelineStore: ObservableObject {
    @Published private(set) var items: [TodoReminder] = []
    @Published private(set) var lastLoadedAt: Date?

    var pending: [TodoReminder] {
        items
            .filter { !$0.completed }
            .sorted {
                ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture)
            }
    }

    var completed: [TodoReminder] {
        items.filter(\.completed)
    }

    func replaceLoaded(_ incoming: [TodoReminder]) {
        var unique: [String: TodoReminder] = [:]
        for item in incoming {
            unique[item.id] = item
        }
        items = unique.values.sorted {
            ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture)
        }
    }

    func upsert(_ item: TodoReminder) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
    }

    func markLoaded() {
        lastLoadedAt = Date()
    }
}
```

- [ ] **Step 4: Inject one store from RootView**

```swift
@StateObject private var todoStore = TodoTimelineStore()
```

Attach it to the root content:

```swift
pager
    .environmentObject(todoStore)
```

- [ ] **Step 5: Run the store tests**

```bash
cd ios
xcodebuild \
  -project WhaleAgent.xcodeproj \
  -scheme WhaleAgent \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Expected: all `TodoTimelineStoreTests` pass.

- [ ] **Step 6: Commit**

```powershell
git add ios/WhaleAgent/Models/TodoTimelineStore.swift `
  ios/WhaleAgentTests/TodoTimelineStoreTests.swift `
  ios/WhaleAgent/UI/RootView.swift
git commit -m "feat: add shared todo timeline store"
```

---

### Task 4: Migrate Home, Workspace, Todo, and daily review to the shared store

**Files:**
- Modify: `ios/WhaleAgent/UI/WhaleHomeCanvas.swift:28-80`
- Modify: `ios/WhaleAgent/UI/WhaleHomeCanvas.swift:1215-1285`
- Modify: `ios/WhaleAgent/UI/WhaleWorkspaceView.swift:48-380`
- Modify: `ios/WhaleAgent/UI/WhaleWorkspaceView.swift:1052-1270`
- Modify: `ios/WhaleAgent/UI/TodoView.swift:60-245`
- Modify: `ios/WhaleAgent/UI/TodoView.swift:880-1090`
- Test: `ios/WhaleAgentUITests/InteractionUITests.swift`

**Interfaces:**

- Consumes:
  - `TodoTimelineStore`
  - `AppModel.loadTodoReminders(includeCompleted:)`
  - `AppModel.createTodoReminder(...)`
  - `AppModel.setTodoReminder(_:completed:)`
  - `AppModel.rescheduleTodoReminder(_:dueAt:)`
  - `AppModel.deleteTodoReminder(_:)`
- Produces:
  - All todo-reading views observe one `TodoTimelineStore`.
  - Every successful todo mutation calls `upsert(_:)` or `remove(id:)`.

- [ ] **Step 1: Add a failing cross-view synchronization test**

Add a debug-only fixture to `RootView`:

```swift
#if DEBUG
if ProcessInfo.processInfo.environment["WHALE_DEMO_TODO_SYNC"] == "1" {
    todoStore.replaceLoaded([
        TodoReminder.demo(
            id: "demo-sync",
            title: "验证跨页面同步",
            completed: false
        )
    ])
}
#endif
```

Add the fixture helper in `TodoReminder` under `#if DEBUG`:

```swift
#if DEBUG
extension TodoReminder {
    static func demo(
        id: String,
        title: String,
        completed: Bool
    ) -> TodoReminder {
        TodoReminder(
            id: id,
            title: title,
            completed: completed,
            listName: "演示",
            dueAt: nil,
            notes: nil,
            deduplicated: false
        )
    }
}
#endif
```

Add an explicit internal initializer so tests do not synthesize JSON:

```swift
init(
    id: String,
    title: String,
    completed: Bool,
    listName: String,
    dueAt: Date?,
    notes: String?,
    deduplicated: Bool
) {
    self.id = id
    self.title = title
    self.completed = completed
    self.listName = listName
    self.dueAt = dueAt
    self.notes = notes
    self.deduplicated = deduplicated
}
```

Add UI test:

```swift
func testTodoCompletionRefreshesHomeAndWorkspaceSummary() {
    let app = launch(additionalEnvironment: [
        "WHALE_DEMO_TODO_SYNC": "1"
    ])

    tab(app, "records").tap()
    XCTAssertTrue(
        app.staticTexts["验证跨页面同步"].waitForExistence(timeout: 10)
    )
    app.buttons["完成 验证跨页面同步"].tap()

    tab(app, "conversation").tap()
    XCTAssertFalse(app.staticTexts["验证跨页面同步"].exists)

    tab(app, "records").tap()
    XCTAssertTrue(app.staticTexts["目前没有未完成事项。"].exists)
}
```

- [ ] **Step 2: Change the UI-test launch helper**

```swift
private func launch(
    additionalEnvironment: [String: String] = [:]
) -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchEnvironment["WHALE_DEMO_HOME"] = "1"
    app.launchEnvironment["WHALE_DEMO_INITIAL_CHANNEL"] = "ai"
    app.launchEnvironment["WHALE_DEMO_PALETTE"] = "seaSalt"
    for (key, value) in additionalEnvironment {
        app.launchEnvironment[key] = value
    }
    app.launch()
    return app
}
```

Run the UI test and verify it fails because Home and Workspace still own separate arrays.

- [ ] **Step 3: Migrate Home**

Replace:

```swift
@State private var homeTodos: [TodoReminder] = []
```

with:

```swift
@EnvironmentObject private var todoStore: TodoTimelineStore
```

Replace `loadHomeTodos()` with:

```swift
private func reloadTodoStore(using model: AppModel) async {
    guard model.permissionsSnapshot["reminder"] == "granted" else {
        todoStore.replaceLoaded([])
        return
    }
    do {
        let items = try await model.loadTodoReminders(includeCompleted: true)
        todoStore.replaceLoaded(items)
        todoStore.markLoaded()
    } catch {
        // Preserve the last known rows; surface the failure in Workspace.
    }
}
```

Use `todoStore.pending.first` for the today card and widget snapshot.

- [ ] **Step 4: Migrate Workspace**

Replace `@State private var taskItems` with:

```swift
@EnvironmentObject private var todoStore: TodoTimelineStore
```

Use:

```swift
private var pendingTasks: [TodoReminder] {
    todoStore.pending
}

private var completedTaskCount: Int {
    todoStore.completed.count
}
```

After every successful mutation:

```swift
let item = try await model.createTodoReminder(title: title, dueAt: nil)
todoStore.upsert(item)
```

```swift
let updated = try await model.setTodoReminder(item, completed: !item.completed)
todoStore.upsert(updated)
```

- [ ] **Step 5: Migrate TodoView**

Replace local `items` with store-backed access:

```swift
@EnvironmentObject private var todoStore: TodoTimelineStore
```

Replace `reload()` assignment:

```swift
let loaded = try await model.loadTodoReminders(includeCompleted: true)
todoStore.replaceLoaded(loaded)
todoStore.markLoaded()
```

Replace `upsert(item)` with `todoStore.upsert(item)` and `removeLocal(id)` with `todoStore.remove(id:)`.

- [ ] **Step 6: Migrate WorkspaceBriefSection**

Remove its private `reminders` array. Read `todoStore.items` and keep only the daily review text in local state:

```swift
@EnvironmentObject private var todoStore: TodoTimelineStore

private var pending: [TodoReminder] {
    todoStore.pending
}

private var completed: [TodoReminder] {
    todoStore.completed
}
```

- [ ] **Step 7: Run unit, compile, and UI tests**

```powershell
python tools/release_identity.py --check
```

```bash
cd ios
xcodegen generate
xcodebuild \
  -project WhaleAgent.xcodeproj \
  -scheme WhaleAgent \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

After explicit push authorization:

```powershell
python tools/github_ci.py `
  --repo dianmei0602/whale01 `
  --branch ui-sea-salt-0.8 `
  --dispatch ios-ui-tests.yml `
  --input scope=ui
```

Expected: `testTodoCompletionRefreshesHomeAndWorkspaceSummary` passes.

- [ ] **Step 8: Commit**

```powershell
git add ios/WhaleAgent/UI/WhaleHomeCanvas.swift `
  ios/WhaleAgent/UI/WhaleWorkspaceView.swift `
  ios/WhaleAgent/UI/TodoView.swift `
  ios/WhaleAgent/Models/CoreEntities.swift `
  ios/WhaleAgent/UI/RootView.swift `
  ios/WhaleAgentUITests/InteractionUITests.swift
git commit -m "refactor: synchronize todo state across screens"
```

---

### Task 5: Move the complete todo list from a sheet to a pushed page

**Files:**
- Modify: `ios/WhaleAgent/UI/RootView.swift:135-220`
- Modify: `ios/WhaleAgent/UI/WhaleWorkspaceView.swift:42-130`
- Modify: `ios/WhaleAgent/UI/WhaleWorkspaceView.swift:196-230`
- Modify: `ios/WhaleAgent/UI/TodoView.swift:120-275`
- Create: `ios/WhaleAgent/UI/WhaleWorkspaceRoutes.swift`
- Create: `ios/WhaleAgent/UI/TodoDetailPage.swift`
- Test: `ios/WhaleAgentUITests/InteractionUITests.swift`

**Interfaces:**

- Consumes:
  - `WorkspaceRoute.todos`
  - `WorkspaceRoute.todoDetail(String)`
  - `TodoTimelineStore.items`
  - `RootNavigationModel.workspacePath`
- Produces:
  - `WhaleWorkspaceRouteView`
  - `TodoDetailPage(item:model:)`
  - `TodoView` uses the outer navigation bar when pushed.

- [ ] **Step 1: Run the failing Workspace return test**

The test from Task 1 must currently fail because no `workspace-todo-list` exists.

- [ ] **Step 2: Wrap Workspace in a NavigationStack**

In `RootView`:

```swift
private var recordsPage: some View {
    NavigationStack(path: $navigation.workspacePath) {
        WhaleWorkspaceView(
            model: model,
            embedded: true,
            onOpenMusic: { openDiscover(.music) },
            onOpenChat: { prompt in
                navigation.selectedTab = .conversation
                navigation.conversationMode = .chat
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    NotificationCenter.default.post(
                        name: .whalePrefillDraft,
                        object: nil,
                        userInfo: ["text": prompt]
                    )
                }
            }
        )
        .navigationDestination(for: WorkspaceRoute.self) { route in
            WhaleWorkspaceRouteView(route: route, model: model)
        }
    }
    .environmentObject(navigation)
}
```

- [ ] **Step 3: Create the route destination**

```swift
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
                showsHeader: true,
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
```

- [ ] **Step 4: Create the pushed todo detail page**

`TodoDetailPage` owns the same real reminder operations but uses navigation rather than a nested sheet:

```swift
import SwiftUI

struct TodoDetailPage: View {
    @ObservedObject var model: AppModel
    @EnvironmentObject private var todoStore: TodoTimelineStore
    @Environment(\.dismiss) private var dismiss

    @State private var current: TodoReminder
    @State private var project: String
    @State private var priority: Int
    @State private var isBusy = false
    @State private var errorText: String?
    @State private var confirmDelete = false

    init(item: TodoReminder, model: AppModel) {
        self.model = model
        _current = State(initialValue: item)
        _project = State(initialValue: item.projectName ?? "")
        _priority = State(initialValue: item.priority)
    }

    var body: some View {
        Form {
            Section("任务") {
                Text(current.title)
                    .font(.headline)
                LabeledContent(
                    "状态",
                    value: current.completed ? "已完成" : "待办"
                )
                LabeledContent("系统列表", value: current.listName)
            }

            Section("本地组织") {
                TextField("项目", text: $project)
                Picker("优先级", selection: $priority) {
                    Text("高").tag(1)
                    Text("普通").tag(2)
                    Text("低").tag(3)
                }
                Button("保存项目与优先级") {
                    model.updateTodoMetadata(
                        current,
                        project: project,
                        priority: priority
                    )
                    todoStore.upsert(current)
                    dismiss()
                }
            }

            if let errorText {
                Section {
                    Label(
                        errorText,
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(WhaleTheme.warm)
                }
            }

            Section {
                Button(current.completed ? "恢复为待办" : "标记完成") {
                    Task { await toggleCompletion() }
                }
                .disabled(isBusy)

                Button("删除待办", role: .destructive) {
                    confirmDelete = true
                }
                .disabled(isBusy)
            }
        }
        .scrollContentBackground(.hidden)
        .background(WhaleBackdrop())
        .alert("删除这条待办？", isPresented: $confirmDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task { await deleteCurrent() }
            }
        } message: {
            Text(current.title)
        }
    }

    @MainActor
    private func toggleCompletion() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            current = try await model.setTodoReminder(
                current,
                completed: !current.completed
            )
            todoStore.upsert(current)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor
    private func deleteCurrent() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await model.deleteTodoReminder(current)
            todoStore.remove(id: current.id)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
```

- [ ] **Step 5: Push from the Workspace “全部” button**

Replace `showTodoManager = true` with:

```swift
@EnvironmentObject private var navigation: RootNavigationModel

Button("全部") {
    navigation.workspacePath.append(.todos)
}
```

- [ ] **Step 6: Delete the old todo sheet**

Remove:

- `@State private var showTodoManager`
- `.sheet(isPresented: $showTodoManager)`
- Nested `NavigationStack` and “完成” toolbar inside that sheet

- [ ] **Step 7: Push todo details instead of presenting another sheet**

In `TodoView`, remove:

- `@State private var detailItem`
- `.sheet(item: $detailItem)`

Add the shared navigation environment:

```swift
@EnvironmentObject private var navigation: RootNavigationModel
```

Replace row title and context menu detail actions:

```swift
.onTapGesture {
    navigation.workspacePath.append(.todoDetail(item.id))
}
```

```swift
Button("打开详情", systemImage: "info.circle") {
    navigation.workspacePath.append(.todoDetail(item.id))
}
```

After `rg -n "TodoDetailSheet" ios/WhaleAgent`, remove `TodoDetailSheet` from `TodoV2Sheets.swift` when the only remaining definition is the type itself.

- [ ] **Step 8: Stop TodoView from hiding its parent navigation bar**

Add:

```swift
var hidesNavigationBar: Bool = false
```

Replace:

```swift
.navigationBarHidden(true)
```

with:

```swift
.navigationBarHidden(hidesNavigationBar)
```

Change the header close button to render only when it has an action:

```swift
if !embedded || onBackToChat != nil {
    Button {
        if embedded {
            onBackToChat?()
        } else {
            dismiss()
        }
    } label: {
        Image(systemName: embedded ? "bubble.left.and.bubble.right" : "xmark")
    }
    .accessibilityLabel(embedded ? "回到对话" : "关闭待办")
}
```

- [ ] **Step 9: Run the Workspace return UI test**

```powershell
python tools/github_ci.py `
  --repo dianmei0602/whale01 `
  --branch ui-sea-salt-0.8 `
  --dispatch ios-ui-tests.yml `
  --input scope=ui
```

Expected:

- `workspace-todo-list` exists after tapping “全部”.
- Navigation back returns to `workspace-tasks-overview`.
- Swipe-down no longer dismisses the complete todo list.

- [ ] **Step 10: Commit**

```powershell
git add ios/WhaleAgent/UI/RootView.swift `
  ios/WhaleAgent/UI/WhaleWorkspaceView.swift `
  ios/WhaleAgent/UI/WhaleWorkspaceRoutes.swift `
  ios/WhaleAgent/UI/TodoDetailPage.swift `
  ios/WhaleAgent/UI/TodoView.swift `
  ios/WhaleAgent/UI/TodoV2Sheets.swift `
  ios/WhaleAgentUITests/InteractionUITests.swift
git commit -m "fix: push workspace todos onto navigation stack"
```

---

### Task 6: Remove the invisible todo filter and obsolete swipe state

**Files:**
- Modify: `ios/WhaleAgent/UI/TodoView.swift:1-430`
- Create: `tools/test_ui_interaction_contract.py`
- Modify: `.github/workflows/ios-simulator-build.yml:65-95`
- Test: `tools/test_ui_interaction_contract.py`

**Interfaces:**

- Consumes:
  - `TodoBoard`
- Produces:
  - Board is the only visible todo grouping control.
  - Horizontal swipes inside TodoView do not modify hidden state.

- [ ] **Step 1: Write a failing source contract**

```python
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TODO = (ROOT / "ios/WhaleAgent/UI/TodoView.swift").read_text(encoding="utf-8")


def test_todo_has_no_hidden_filter_machine():
    forbidden = [
        "private var filterBar",
        "private var statsCard",
        "private func stepFilter",
        ".onChange(of: filter)",
        ".horizontalTabSwipe(",
        "@AppStorage(\"whale.todo.filter\")",
    ]
    for token in forbidden:
        assert token not in TODO, token


if __name__ == "__main__":
    test_todo_has_no_hidden_filter_machine()
    print("TODO_INTERACTION_CONTRACT_OK")
```

- [ ] **Step 2: Run it and verify failure**

```powershell
python tools/test_ui_interaction_contract.py
```

Expected: assertion failure on `private var filterBar`.

- [ ] **Step 3: Remove dead filter state and UI**

Delete:

- `TodoFilter`
- `@AppStorage("whale.todo.filter")`
- `filterBar`
- `statsCard`
- `filterButton`
- `statMetric`
- `statDivider`
- `stepFilter`
- `.horizontalTabSwipe(...)`
- `.onChange(of: filter)`

Keep `TodoBoard` and `boardBar` as the sole grouping model.

- [ ] **Step 4: Run the contract and compile**

```powershell
python tools/test_ui_interaction_contract.py
```

Expected: `TODO_INTERACTION_CONTRACT_OK`.

```bash
cd ios
xcodegen generate
xcodebuild \
  -project WhaleAgent.xcodeproj \
  -scheme WhaleAgent \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Expected: build and all unit tests pass.

- [ ] **Step 5: Add the contract to CI**

In the `build` job:

```yaml
      - name: Run UI interaction source contract
        run: python tools/test_ui_interaction_contract.py
```

- [ ] **Step 6: Commit**

```powershell
git add ios/WhaleAgent/UI/TodoView.swift `
  tools/test_ui_interaction_contract.py `
  .github/workflows/ios-simulator-build.yml
git commit -m "refactor: remove hidden todo filter state"
```

---

### Task 7: Preserve Workspace section scroll position and reset intent

**Files:**
- Modify: `ios/WhaleAgent/UI/WhaleWorkspaceView.swift:120-180`
- Modify: `ios/WhaleAgent/UI/WhaleWorkspaceView.swift:380-430`
- Test: `ios/WhaleAgentUITests/InteractionUITests.swift`

**Interfaces:**

- Consumes:
  - `ScrollOffsetMemory`
  - `WhaleWorkspaceSection.rawValue`
- Produces:
  - Each Workspace section restores its own scroll offset.
  - Switching sections does not carry the previous offset into the new section.

- [ ] **Step 1: Add a failing section-scroll UI test**

```swift
func testWorkspaceSectionsKeepIndependentScrollPositions() {
    let app = launch()
    tab(app, "records").tap()

    let inbox = app.buttons["workspace-section-inbox"]
    XCTAssertTrue(inbox.waitForExistence(timeout: 10))
    app.swipeUp()
    app.swipeUp()

    let reading = app.buttons["workspace-section-reading"]
    if !reading.isHittable {
        app.swipeDown()
    }
    reading.tap()

    XCTAssertTrue(
        app.descendants(matching: .any)["workspace-section-content-reading"]
            .waitForExistence(timeout: 5)
    )

    inbox.tap()
    XCTAssertTrue(
        app.descendants(matching: .any)["workspace-section-content-inbox"]
            .waitForExistence(timeout: 5)
    )
}
```

Expected first run: identifier for selected section content is missing.

- [ ] **Step 2: Attach per-section scroll memory**

```swift
ScrollView {
    VStack(alignment: .leading, spacing: 16) {
        tasksOverview
        sectionSelector
        sectionContent
            .id("workspace-top-\(section.rawValue)")
            .accessibilityIdentifier(
                "workspace-section-content-\(section.rawValue)"
            )
    }
}
.background(
    ScrollOffsetMemory(
        key: "workspace-section-\(section.rawValue)"
    )
)
```

- [ ] **Step 3: Add reduced-motion-safe section transition**

```swift
Button {
    if reduceMotion {
        section = item
    } else {
        withAnimation(.easeOut(duration: 0.18)) {
            section = item
        }
    }
} label: {
    // existing label
}
```

Add:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
```

- [ ] **Step 4: Add a compact Workspace identity row**

Insert above `tasksOverview`:

```swift
HStack(spacing: 10) {
    WhaleMarkView(size: 28)
    VStack(alignment: .leading, spacing: 1) {
        Text("工作台")
            .whaleFont(size: 22, weight: .bold, design: .rounded)
            .foregroundStyle(WhaleTheme.ink)
        Text("待办、记录、阅读都在这里")
            .whaleFont(size: 12)
            .foregroundStyle(WhaleTheme.muted)
    }
    Spacer()
}
.accessibilityIdentifier("workspace-title")
```

- [ ] **Step 5: Run UI tests**

After explicit push authorization:

```powershell
python tools/github_ci.py `
  --repo dianmei0602/whale01 `
  --branch ui-sea-salt-0.8 `
  --dispatch ios-ui-tests.yml `
  --input scope=ui
```

Expected: the section-scroll test passes and all prior Workspace tests remain green.

- [ ] **Step 6: Commit**

```powershell
git add ios/WhaleAgent/UI/WhaleWorkspaceView.swift `
  ios/WhaleAgentUITests/InteractionUITests.swift
git commit -m "fix: preserve workspace section scroll positions"
```

---

### Task 8: Centralize Workspace sheets and protect unsaved drafts

**Files:**
- Create: `ios/WhaleAgent/UI/WhaleSheetDestinations.swift`
- Modify: `ios/WhaleAgent/UI/WhaleWorkspaceView.swift:42-130`
- Modify: `ios/WhaleAgent/UI/WhaleWorkspaceView.swift:1405-2024`
- Modify: `ios/WhaleAgent/UI/SettingsView.swift:1314-1480`
- Test: `ios/WhaleAgentUITests/InteractionUITests.swift`

**Interfaces:**

- Consumes:
  - `WhaleWorkspaceStore`
  - `DiscoverReadingLibrary`
- Produces:
  - `WorkspaceSheet`
  - `WhaleDraftDismissGuard`
  - One `.sheet(item:)` on Workspace.

- [ ] **Step 1: Write the failing unsaved-dismiss UI test**

```swift
func testWorkspaceEditorRejectsAccidentalSwipeDismiss() {
    let app = launch()
    tab(app, "records").tap()
    app.buttons["workspace-section-inbox"].tap()
    app.buttons["workspace-open-capture-editor"].tap()

    let editor = app.textViews.firstMatch
    XCTAssertTrue(editor.waitForExistence(timeout: 5))
    editor.tap()
    editor.typeText("未保存内容")

    app.swipeDown()
    XCTAssertTrue(editor.exists)
}
```

Expected: current editor disappears because swipe dismissal is not blocked.

- [ ] **Step 2: Add stable identifiers**

On the capture editor button:

```swift
.accessibilityIdentifier("workspace-open-capture-editor")
```

On the editor text area:

```swift
.accessibilityIdentifier("workspace-capture-body")
```

- [ ] **Step 3: Create the shared draft guard**

```swift
import SwiftUI

struct WhaleDraftDismissGuard: ViewModifier {
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
```

- [ ] **Step 4: Apply the guard to every editing sheet**

In `WorkspaceCaptureEditor`:

```swift
private var hasChanges: Bool {
    !title.isEmpty
        || !captureText.isEmpty
        || voice.isRecording
        || voice.isFinalizing
}
```

```swift
.whaleDraftGuard(
    hasChanges: hasChanges,
    isBusy: isImporting || voice.isFinalizing
)
```

Apply equivalent guards to:

- `WorkspaceCaptureDetailSheet`
- `WorkspaceProjectEditor`
- `WorkspaceReadingHighlightSheet`
- `WorkspaceFollowUpEditor`
- `ProfileEditorSheet`

- [ ] **Step 5: Replace seven Workspace sheet booleans with one enum**

```swift
enum WorkspaceSheet: Identifiable {
    case captureEditor
    case captureDetail(String)
    case projectEditor
    case followUpEditor
    case reader(SavedArticle)
    case highlight(SavedArticle)

    var id: String {
        switch self {
        case .captureEditor: return "capture-editor"
        case .captureDetail(let id): return "capture-" + id
        case .projectEditor: return "project-editor"
        case .followUpEditor: return "follow-up-editor"
        case .reader(let article): return "reader-" + article.id
        case .highlight(let article): return "highlight-" + article.id
        }
    }
}
```

Use one presentation:

```swift
@State private var sheet: WorkspaceSheet?

.sheet(item: $sheet) { destination in
    switch destination {
    case .captureEditor:
        WorkspaceCaptureEditor(store: store)
    case .captureDetail(let id):
        if let item = store.captures.first(where: { $0.id == id }) {
            WorkspaceCaptureDetailSheet(
                item: item,
                store: store,
                model: model,
                onOpenChat: onOpenChat,
                onShowToast: showToast
            )
        }
    case .projectEditor:
        WorkspaceProjectEditor(store: store)
    case .followUpEditor:
        WorkspaceFollowUpEditor(store: store)
    case .reader(let article):
        NativeArticleReaderView(
            item: newsItem(for: article),
            library: reading
        )
    case .highlight(let article):
        WorkspaceReadingHighlightSheet(article: article, store: store) {
            showToast("摘录已保存到私人知识库")
        }
    }
}
```

- [ ] **Step 6: Add confirmation and undo to destructive actions**

For Workspace capture archive/delete:

```swift
@State private var destructiveAction: WorkspaceDestructiveAction?
```

```swift
enum WorkspaceDestructiveAction {
    case archive
    case delete
}
```

Use:

```swift
.confirmationDialog(
    "处理这条记录？",
    isPresented: Binding(
        get: { destructiveAction != nil },
        set: { if !$0 { destructiveAction = nil } }
    ),
    titleVisibility: .visible
) {
    Button("移入归档") {
        store.archive(item)
        dismiss()
    }
    Button("删除", role: .destructive) {
        store.delete(item)
        dismiss()
    }
    Button("取消", role: .cancel) {}
}
```

For bookmark removal in `DiscoverLibraryView`, add an undo banner rather than immediate silent removal.

- [ ] **Step 7: Run UI tests**

Expected:

- The editor remains visible after a swipe-down when text is present.
- Explicit Cancel still dismisses.
- Saving dismisses.
- Only one Workspace sheet can be active.

- [ ] **Step 8: Commit**

```powershell
git add ios/WhaleAgent/UI/WhaleSheetDestinations.swift `
  ios/WhaleAgent/UI/WhaleWorkspaceView.swift `
  ios/WhaleAgent/UI/SettingsView.swift `
  ios/WhaleAgent/UI/DiscoverLibraryView.swift `
  ios/WhaleAgentUITests/InteractionUITests.swift
git commit -m "refactor: centralize sheets and protect drafts"
```

---

### Task 9: Add one voice-capture state machine and presentation model

**Files:**
- Create: `ios/WhaleAgent/Models/VoiceCapturePresentation.swift`
- Create: `ios/WhaleAgentTests/VoiceCapturePresentationTests.swift`
- Test: `ios/WhaleAgentTests/VoiceCapturePresentationTests.swift`

**Interfaces:**

- Consumes:
  - `VoiceInputController`
- Produces:
  - `VoiceCaptureTarget`
  - `VoiceCapturePhase`
  - `VoiceCapturePresentation`

- [ ] **Step 1: Write the failing state tests**

```swift
import XCTest
@testable import WhaleAgent

final class VoiceCapturePresentationTests: XCTestCase {
    func testChatListeningCopyIsConsistent() {
        let value = VoiceCapturePresentation.content(
            target: .chat,
            phase: .listening,
            transcript: ""
        )
        XCTAssertEqual(value.title, "给鲸鱼说")
        XCTAssertEqual(value.actionTitle, "完成")
        XCTAssertTrue(value.showsWaveform)
    }

    func testReviewDoesNotAutoCommit() {
        let value = VoiceCapturePresentation.content(
            target: .todo,
            phase: .review("明天下午提醒我取快递"),
            transcript: "明天下午提醒我取快递"
        )
        XCTAssertEqual(value.actionTitle, "填入待办")
        XCTAssertFalse(value.showsWaveform)
        XCTAssertTrue(value.actionEnabled)
    }

    func testFailureOffersOneRetryAction() {
        let value = VoiceCapturePresentation.content(
            target: .workspace,
            phase: .failed("没有收到最终结果"),
            transcript: ""
        )
        XCTAssertEqual(value.actionTitle, "再试一次")
        XCTAssertFalse(value.showsWaveform)
    }
}
```

- [ ] **Step 2: Run tests and verify compile failure**

```bash
cd ios
xcodegen generate
xcodebuild \
  -project WhaleAgent.xcodeproj \
  -scheme WhaleAgent \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Expected: compile failure because the voice presentation types do not exist.

- [ ] **Step 3: Implement the presentation model**

```swift
import Foundation

enum VoiceCaptureTarget: String, Equatable {
    case chat
    case todo
    case workspace

    var title: String {
        switch self {
        case .chat: return "给鲸鱼说"
        case .todo: return "记一件待办"
        case .workspace: return "记到工作台"
        }
    }

    var commitTitle: String {
        switch self {
        case .chat: return "填入输入框"
        case .todo: return "填入待办"
        case .workspace: return "填入记录"
        }
    }
}

enum VoiceCapturePhase: Equatable {
    case idle
    case listening
    case finalizing
    case review(String)
    case failed(String)
}

struct VoiceCaptureContent: Equatable {
    let title: String
    let message: String
    let actionTitle: String
    let actionEnabled: Bool
    let showsWaveform: Bool
}

enum VoiceCapturePresentation {
    static func content(
        target: VoiceCaptureTarget,
        phase: VoiceCapturePhase,
        transcript: String
    ) -> VoiceCaptureContent {
        switch phase {
        case .idle:
            return .init(
                title: target.title,
                message: "轻触开始说话",
                actionTitle: "开始说话",
                actionEnabled: true,
                showsWaveform: false
            )
        case .listening:
            return .init(
                title: target.title,
                message: transcript.isEmpty ? "正在听你说…" : transcript,
                actionTitle: "完成",
                actionEnabled: true,
                showsWaveform: true
            )
        case .finalizing:
            return .init(
                title: "正在整理…",
                message: transcript,
                actionTitle: "请稍候",
                actionEnabled: false,
                showsWaveform: false
            )
        case .review(let text):
            return .init(
                title: "听清了",
                message: text,
                actionTitle: target.commitTitle,
                actionEnabled: !text.isEmpty,
                showsWaveform: false
            )
        case .failed(let message):
            return .init(
                title: "没听清",
                message: message,
                actionTitle: "再试一次",
                actionEnabled: true,
                showsWaveform: false
            )
        }
    }
}
```

- [ ] **Step 4: Run tests**

Expected: all `VoiceCapturePresentationTests` pass.

- [ ] **Step 5: Commit**

```powershell
git add ios/WhaleAgent/Models/VoiceCapturePresentation.swift `
  ios/WhaleAgentTests/VoiceCapturePresentationTests.swift
git commit -m "feat: add unified voice capture presentation"
```

---

### Task 10: Replace all voice entry points with one bottom-sheet component

**Files:**
- Create: `ios/WhaleAgent/UI/WhaleVoiceCaptureSheet.swift`
- Modify: `ios/WhaleAgent/UI/ChatHomeView.swift:12-185`
- Modify: `ios/WhaleAgent/UI/TodoView.swift:60-245`
- Modify: `ios/WhaleAgent/UI/TodoView.swift:680-860`
- Modify: `ios/WhaleAgent/UI/WhaleWorkspaceView.swift:1405-1655`
- Delete after verification: `ios/WhaleAgent/UI/VoiceView.swift`
- Test: `ios/WhaleAgentUITests/InteractionUITests.swift`

**Interfaces:**

- Consumes:
  - `VoiceCaptureTarget`
  - `VoiceCapturePhase`
  - `VoiceCapturePresentation`
  - `VoiceInputController`
- Produces:
  - `WhaleVoiceCaptureSheet(target:onCommit:onCancel:)`
  - Accessibility identifiers:
    - `whale-voice-capture-sheet`
    - `whale-voice-action`
    - `whale-voice-cancel`

- [ ] **Step 1: Verify the shared voice UI test fails**

The Task 1 test must fail because the identifier and component do not exist.

- [ ] **Step 2: Implement the single voice sheet**

```swift
import SwiftUI

struct WhaleVoiceCaptureSheet: View {
    let target: VoiceCaptureTarget
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var voice = VoiceInputController()
    @State private var phase: VoiceCapturePhase = .listening
    @State private var finalText = ""
    @State private var didAutoStart = false

    private var content: VoiceCaptureContent {
        VoiceCapturePresentation.content(
            target: target,
            phase: phase,
            transcript: voice.transcript
        )
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(content.title)
                .whaleFont(size: 18, weight: .bold)
            Text(content.message)
                .whaleFont(size: 15)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .frame(minHeight: 48)
            waveform
            Button(action: primaryAction) {
                Text(content.actionTitle)
                    .whaleFont(size: 15, weight: .semibold)
                    .padding(.horizontal, 24)
                    .frame(minHeight: 46)
                    .background(WhaleTheme.accent, in: Capsule())
                    .foregroundStyle(WhaleTheme.onAccent)
            }
            .buttonStyle(.whalePress)
            .disabled(!content.actionEnabled)
            .accessibilityIdentifier("whale-voice-action")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            Button("取消") {
                voice.cancel()
                onCancel()
                dismiss()
            }
            .accessibilityIdentifier("whale-voice-cancel")
            .padding(16)
        }
        .accessibilityIdentifier("whale-voice-capture-sheet")
        .task { await startIfNeeded() }
        .onChange(of: voice.transcript) { _, text in
            if phase == .listening {
                phase = .listening
            }
            _ = text
        }
        .onChange(of: voice.finalResult) { _, result in
            guard let result, voice.errorText == nil else { return }
            finalText = result.text
            phase = .review(result.text)
        }
        .onChange(of: voice.errorText) { _, error in
            guard let error else { return }
            phase = .failed(error)
        }
        .onDisappear { voice.cancel() }
    }

    private var waveform: some View {
        HStack(spacing: 4) {
            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(WhaleTheme.accent.opacity(0.82))
                    .frame(
                        width: 4,
                        height: content.showsWaveform && !reduceMotion
                            ? CGFloat(12 + (index % 4) * 5)
                            : 16
                    )
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.7).repeatForever(),
            value: content.showsWaveform
        )
        .accessibilityHidden(true)
    }

    private func startIfNeeded() async {
        guard !didAutoStart else { return }
        didAutoStart = true
        await voice.start()
        if !voice.isRecording && voice.errorText == nil {
            phase = .idle
        }
    }

    private func primaryAction() {
        switch phase {
        case .idle:
            Task { await voice.start() }
        case .listening:
            phase = .finalizing
            voice.stop()
        case .finalizing:
            break
        case .review(let text):
            onCommit(text)
            dismiss()
        case .failed:
            voice.reset()
            phase = .idle
            Task { await voice.start() }
        }
    }
}
```

- [ ] **Step 3: Replace ChatHomeView voice state**

Remove:

- `@StateObject private var voice`
- `voicePrefix`
- all `voice.*` callbacks

Use:

```swift
@State private var showsVoice = false

.sheet(isPresented: $showsVoice) {
    WhaleVoiceCaptureSheet(
        target: .chat,
        onCommit: insertVoiceDraft,
        onCancel: {}
    )
    .presentationDetents([.height(310)])
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(28)
    .presentationBackground(WhaleIMessagePalette.canvas)
}
```

Allow dictation while the Agent is busy:

```swift
Button {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )
    showsVoice = true
} label: {
    Image(systemName: "mic.fill")
}
.disabled(model.isExtractingDocument)
```

- [ ] **Step 4: Replace TodoView inline voice**

Remove:

- `@StateObject private var voice`
- `voicePrefix`
- `voiceSessionID`
- `voiceDraftIsActive`
- inline `voiceStrip`

Add:

```swift
@State private var showsVoice = false
```

Mic button:

```swift
Button {
    composerFocused = false
    showsVoice = true
} label: {
    Image(systemName: "mic.fill")
}
.accessibilityLabel("语音新增待办")
```

Sheet:

```swift
.sheet(isPresented: $showsVoice) {
    WhaleVoiceCaptureSheet(
        target: .todo,
        onCommit: { text in
            draft = mergeVoiceDraft(prefix: draft, recognized: text)
            quickPreview = TodoQuickParser.parsePreview(draft)
            composerFocused = true
        },
        onCancel: {}
    )
    .presentationDetents([.height(310)])
}
```

- [ ] **Step 5: Replace Workspace inline voice**

Remove the embedded voice controller and toolbar recording state from `WorkspaceCaptureEditor`.

Use:

```swift
@State private var showsVoice = false
```

```swift
Button {
    focused = false
    showsVoice = true
} label: {
    Label("语音补一句", systemImage: "mic")
}
.accessibilityIdentifier("workspace-capture-voice")
```

```swift
.sheet(isPresented: $showsVoice) {
    WhaleVoiceCaptureSheet(
        target: .workspace,
        onCommit: { text in
            captureText = mergeVoiceDraft(
                prefix: captureText,
                recognized: text
            )
            focused = true
        },
        onCancel: {}
    )
    .presentationDetents([.height(310)])
}
```

- [ ] **Step 6: Remove VoiceView.swift**

First verify no references:

```powershell
rg -n "VoiceView" ios/WhaleAgent ios/WhaleAgentTests ios/WhaleAgentUITests
```

Expected: no output. Then delete `ios/WhaleAgent/UI/VoiceView.swift`.

- [ ] **Step 7: Run source, unit, and UI verification**

```powershell
$failed = @()
Get-ChildItem ios -Recurse -Filter *.swift | ForEach-Object {
    & swiftc -frontend -parse $_.FullName
    if ($LASTEXITCODE -ne 0) { $failed += $_.FullName }
}
if ($failed.Count -gt 0) { $failed; exit 1 }
python tools/test_ui_interaction_contract.py
python tools/release_identity.py --check
```

CI:

```powershell
python tools/github_ci.py `
  --repo dianmei0602/whale01 `
  --branch ui-sea-salt-0.8 `
  --dispatch ios-ui-tests.yml `
  --input scope=ui
```

Expected:

- Shared sheet appears from Chat, Todo, and Workspace.
- Stop produces a review state instead of auto-inserting.
- Cancel preserves the original draft.
- Reduce Motion freezes the waveform.

- [ ] **Step 8: Commit**

```powershell
git add ios/WhaleAgent/Models/VoiceCapturePresentation.swift `
  ios/WhaleAgent/UI/WhaleVoiceCaptureSheet.swift `
  ios/WhaleAgent/UI/ChatHomeView.swift `
  ios/WhaleAgent/UI/TodoView.swift `
  ios/WhaleAgent/UI/WhaleWorkspaceView.swift `
  ios/WhaleAgentUITests/InteractionUITests.swift
git rm ios/WhaleAgent/UI/VoiceView.swift
git commit -m "refactor: unify voice capture across app"
```

---

### Task 11: Rebuild the Home hierarchy around real attention state

**Files:**
- Modify: `ios/WhaleAgent/UI/WhaleHomeCanvas.swift:45-365`
- Modify: `ios/WhaleAgent/UI/WhaleHomeCanvas.swift:565-710`
- Modify: `ios/WhaleAgentUITests/InteractionUITests.swift`
- Test: `ios/WhaleAgentUITests/InteractionUITests.swift`

**Interfaces:**

- Consumes:
  - `AssistantCommandPlanner`
  - `TodoTimelineStore`
  - `WhaleWorkspaceStore`
- Produces:
  - Compact primary-task row only when real attention is needed.
  - Workspace launcher only when there is unprocessed Workspace content.

- [ ] **Step 1: Write the failing hierarchy test**

```swift
func testHomeDoesNotRepeatWorkspaceEntryWhenWorkspaceIsEmpty() {
    let app = launch(additionalEnvironment: [
        "WHALE_DEMO_WORKSPACE_EMPTY": "1"
    ])

    XCTAssertTrue(
        app.descendants(matching: .any)["home-inspiration-card"].exists
    )
    XCTAssertFalse(app.buttons["home-workspace"].exists)
    XCTAssertTrue(app.buttons["home-start-conversation"].exists)
}
```

Expected: fails because `workspaceLauncher` always renders.

- [ ] **Step 2: Reorder the Home body**

```swift
ScrollView {
    VStack(alignment: .leading, spacing: 12) {
        if showQuote {
            dailyQuote
        }
        assistantCommandCenter
        homeWidgetGrid
        categoryGrid
        conversationEntryButton
        if workspaceNeedsAttention {
            workspaceLauncher
        }
    }
}
```

- [ ] **Step 3: Hide the empty command center**

Change the `Group` in `assistantCommandCenter` to:

```swift
Group {
    if hasRealWork {
        // existing actionable button
    } else {
        EmptyView()
    }
}
```

Do not show a duplicate “和鲸鱼说一句” card above the final “开始对话” button.

- [ ] **Step 4: Add the Workspace attention condition**

```swift
private var workspaceNeedsAttention: Bool {
    !workspaceStore.inbox.isEmpty
        || !workspaceStore.pendingFollowUps.isEmpty
}
```

- [ ] **Step 5: Make “今天” open the task route**

Replace:

```swift
onOpenTodo()
```

with:

```swift
onOpenTodo()
```

At the root callback:

```swift
onOpenTodo: { navigation.openWorkspace(.todos) }
```

This means the callback name may stay, but its destination is now explicit.

- [ ] **Step 6: Run UI tests**

Expected:

- Empty Workspace does not produce a duplicate Home entry.
- Active context produces `home-primary-task`.
- “今天” opens the pushed Todo page.

- [ ] **Step 7: Commit**

```powershell
git add ios/WhaleAgent/UI/WhaleHomeCanvas.swift `
  ios/WhaleAgent/UI/RootView.swift `
  ios/WhaleAgentUITests/InteractionUITests.swift
git commit -m "refactor: simplify home information hierarchy"
```

---

### Task 12: Add shared motion, accessibility, and destructive feedback policies

**Files:**
- Create: `ios/WhaleAgent/Models/InteractionMotion.swift`
- Create: `ios/WhaleAgentTests/InteractionMotionTests.swift`
- Modify: `ios/WhaleAgent/UI/MusicView.swift:1-300`
- Modify: `ios/WhaleAgent/UI/WhaleWorkspaceView.swift:160-180`
- Modify: `ios/WhaleAgent/UI/TodoView.swift:150-185`
- Modify: `ios/WhaleAgent/UI/DiscoverLibraryView.swift`
- Test: `ios/WhaleAgentTests/InteractionMotionTests.swift`

**Interfaces:**

- Consumes:
  - `AccessibilityReduceMotion`
- Produces:
  - `InteractionMotion.press`
  - `InteractionMotion.page`
  - `InteractionMotion.sheet`
  - `InteractionMotion.waveform(reduceMotion:)`
  - `WhaleAccessibility.announce(_:)`

- [ ] **Step 1: Write the failing motion tests**

```swift
import XCTest
@testable import WhaleAgent

final class InteractionMotionTests: XCTestCase {
    func testReducedMotionUsesNoPageAnimation() {
        XCTAssertNil(InteractionMotion.page(reduceMotion: true))
    }

    func testNormalMotionUsesShortPageAnimation() {
        let animation = InteractionMotion.page(reduceMotion: false)
        XCTAssertNotNil(animation)
    }

    func testWaveformPausesForReducedMotion() {
        XCTAssertFalse(
            InteractionMotion.waveformEnabled(reduceMotion: true)
        )
        XCTAssertTrue(
            InteractionMotion.waveformEnabled(reduceMotion: false)
        )
    }
}
```

- [ ] **Step 2: Run tests and verify compile failure**

Expected: compile failure because `InteractionMotion` does not exist.

- [ ] **Step 3: Implement the motion policy**

```swift
import SwiftUI
import UIKit

enum InteractionMotion {
    static func page(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.20)
    }

    static func sheet(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.88)
    }

    static func waveformEnabled(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }
}

enum WhaleAccessibility {
    static func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
```

- [ ] **Step 4: Apply the motion policy to MusicView**

Add:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
```

Replace hard-coded album-switch delays with:

```swift
if reduceMotion {
    shiftAlbum(step)
    dragOffset = 0
    cardOpacity = 1
    isSwitchingAlbum = false
} else {
    completeAnimatedSwipe(step)
}
```

Keep `completeAnimatedSwipe` private and call it only from `completeSwipe`.

- [ ] **Step 5: Announce toasts**

Update Workspace:

```swift
private func showToast(_ text: String) {
    WhaleAccessibility.announce(text)
    withAnimation(.easeOut(duration: 0.18)) {
        toast = text
    }
}
```

Update Todo:

```swift
private func showToast(_ text: String, undo: Bool = false) {
    WhaleAccessibility.announce(
        undo ? "\(text)，可以撤销" : text
    )
    toast = text
}
```

- [ ] **Step 6: Fix silent music import failure**

Replace:

```swift
guard case .success(let urls) = result else { return }
```

with:

```swift
switch result {
case .success(let urls):
    Task { await model.importLocalMusic(from: urls) }
case .failure(let error):
    WhaleAccessibility.announce("导入音乐失败")
    model.musicError = "导入音乐失败：\(error.localizedDescription)"
}
```

If `musicError` is private-set, add:

```swift
func presentMusicImportError(_ message: String) {
    musicError = message
}
```

Call `model.presentMusicImportError(...)`.

- [ ] **Step 7: Standardize bookmark removal**

In `DiscoverLibraryView`, keep the removed `SavedArticle` in local state and show an Undo action for five seconds:

```swift
@State private var recentlyRemoved: SavedArticle?
@State private var undoExpiresAt = Date.distantPast
```

The trailing swipe action calls a method that:

1. stores the article,
2. toggles it out of the library,
3. announces “已移出稍后读，可撤销”.

- [ ] **Step 8: Run tests**

```powershell
python tools/test_ui_interaction_contract.py
python tools/release_identity.py --check
```

On CI:

```bash
cd ios
xcodebuild \
  -project WhaleAgent.xcodeproj \
  -scheme WhaleAgent \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Expected: motion tests pass and VoiceOver announcements compile.

- [ ] **Step 9: Commit**

```powershell
git add ios/WhaleAgent/Models/InteractionMotion.swift `
  ios/WhaleAgentTests/InteractionMotionTests.swift `
  ios/WhaleAgent/UI/MusicView.swift `
  ios/WhaleAgent/UI/WhaleWorkspaceView.swift `
  ios/WhaleAgent/UI/TodoView.swift `
  ios/WhaleAgent/UI/DiscoverLibraryView.swift `
  ios/WhaleAgent/App/AppModel.swift
git commit -m "feat: unify motion and accessibility feedback"
```

---

### Task 13: Remove verified dead UI code and split oversized routes

**Files:**
- Delete after verification:
  - `ios/WhaleAgent/UI/ConversationSurface.swift`
  - `ios/WhaleAgent/UI/ConversationComposerBar.swift`
  - `ios/WhaleAgent/UI/WhaleIMessageHomeView.swift`
  - `ios/WhaleAgent/UI/QuickActionEditor.swift`
  - `ios/WhaleAgent/UI/WhaleCompanionView.swift`
- Modify: `ios/WhaleAgent/UI/WhaleWorkspaceView.swift`
- Modify: `ios/WhaleAgent/UI/WhaleHomeCanvas.swift`
- Test: all existing tests

**Interfaces:**

- Consumes: Completed route and component extraction from Tasks 2-12.
- Produces: No unreachable legacy chat/home implementation and no unreferenced modal UI.

- [ ] **Step 1: Verify exact zero-reference status**

```powershell
$symbols = @(
  "ConversationSurface",
  "ConversationComposerBar",
  "WhaleIMessageHomeView",
  "QuickActionEditor",
  "WhaleCompanionView"
)
foreach ($symbol in $symbols) {
    $hits = rg -l "\b$symbol\b" ios/WhaleAgent --glob '*.swift'
    "$symbol"
    $hits
}
```

Expected: each symbol appears only in its defining file.

- [ ] **Step 2: Remove one file at a time**

```powershell
git rm ios/WhaleAgent/UI/ConversationSurface.swift
git commit -m "chore: remove unused conversation surface"

git rm ios/WhaleAgent/UI/ConversationComposerBar.swift
git commit -m "chore: remove unused conversation composer"
```

Repeat one commit per file so any unexpected reference is easy to isolate.

- [ ] **Step 3: Extract Workspace section views**

Move these out of `WhaleWorkspaceView.swift`:

- `WorkspaceKnowledgeSection` -> `ios/WhaleAgent/UI/WorkspaceKnowledgeSection.swift`
- `WorkspaceBriefSection` -> `ios/WhaleAgent/UI/WorkspaceBriefSection.swift`
- `WorkspaceFocusSection` -> `ios/WhaleAgent/UI/WorkspaceFocusSection.swift`

Keep the main file responsible for:

- header
- task overview
- section selector
- routing
- sheet presentation

- [ ] **Step 4: Extract Home cards**

Move these out of `WhaleHomeCanvas.swift`:

- `dailyQuote` -> `ios/WhaleAgent/UI/HomeQuoteCard.swift`
- weather detail views -> `ios/WhaleAgent/UI/HomeWeatherCard.swift`
- today/insight card -> `ios/WhaleAgent/UI/HomeTodaySection.swift`

Keep `WhaleHomeCanvas` responsible for layout, loading triggers, and navigation callbacks.

- [ ] **Step 5: Run all local static checks**

```powershell
$failed = @()
Get-ChildItem ios -Recurse -Filter *.swift | ForEach-Object {
    & swiftc -frontend -parse $_.FullName
    if ($LASTEXITCODE -ne 0) { $failed += $_.FullName }
}
if ($failed.Count -gt 0) { $failed; exit 1 }
python tools/test_ui_interaction_contract.py
python tools/release_identity.py --check
git diff --check
```

- [ ] **Step 6: Run backend tests**

```powershell
Push-Location backend
npm test
Pop-Location
```

Expected: all backend tests pass.

- [ ] **Step 7: Commit extraction changes**

```powershell
git add ios/WhaleAgent/UI/WorkspaceKnowledgeSection.swift `
  ios/WhaleAgent/UI/WorkspaceBriefSection.swift `
  ios/WhaleAgent/UI/WorkspaceFocusSection.swift `
  ios/WhaleAgent/UI/HomeQuoteCard.swift `
  ios/WhaleAgent/UI/HomeWeatherCard.swift `
  ios/WhaleAgent/UI/HomeTodaySection.swift `
  ios/WhaleAgent/UI/WhaleWorkspaceView.swift `
  ios/WhaleAgent/UI/WhaleHomeCanvas.swift
git commit -m "refactor: split oversized ui views"
```

---

### Task 14: Final verification, device acceptance, and release handoff

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `00_执行看板.md`
- Modify: `docs/logs/`
- Verify: `release/`

**Interfaces:**

- Consumes: All prior tasks.
- Produces: Verified source, CI evidence, device test record, and an optional IPA with traceable identity.

- [ ] **Step 1: Run local static verification**

```powershell
$failed = @()
Get-ChildItem ios -Recurse -Filter *.swift | ForEach-Object {
    & swiftc -frontend -parse $_.FullName
    if ($LASTEXITCODE -ne 0) { $failed += $_.FullName }
}
if ($failed.Count -gt 0) { $failed; exit 1 }
python tools/test_ui_interaction_contract.py
python -m unittest tools.test_release_identity -v
python tools/release_identity.py --check
git diff --check
```

- [ ] **Step 2: Run backend tests**

```powershell
Push-Location backend
npm test
Pop-Location
```

- [ ] **Step 3: Run CI compile and tests**

Push only after explicit authorization, then:

```powershell
python tools/github_ci.py `
  --repo dianmei0602/whale01 `
  --branch ui-sea-salt-0.8 `
  --dispatch ios-ui-tests.yml `
  --input scope=all
```

Expected:

- Release identity passes.
- App and both test targets compile.
- Unit tests pass.
- Full UI regression passes.
- Interaction screenshots are attached.

- [ ] **Step 4: Run physical-device acceptance**

Record each result explicitly:

- Workspace “全部” opens a pushed Todo page.
- Back button, edge swipe, and Workbench tab reselect all return to Workspace root.
- Chat, Todo, and Workspace microphones open the same bottom sheet.
- Stop shows review text before insertion.
- Cancel restores the original draft.
- Voice interruption and network failure show retry.
- Workspace section scroll positions remain independent.
- Dirty editors cannot be swipe-dismissed accidentally.
- Destructive actions have confirmation or Undo.
- Reduce Motion stops waveform and album animation.
- VoiceOver announces save, delete, and undo results.

- [ ] **Step 5: Build the IPA only after explicit user instruction**

If authorized:

```powershell
python tools/github_ci.py `
  --repo dianmei0602/whale01 `
  --branch ui-sea-salt-0.8 `
  --dispatch fork-ios-sideload-ipa.yml
```

Publish with the project-local default:

```powershell
powershell -ExecutionPolicy Bypass -File tools/publish-ipa.ps1 `
  -Repo dianmei0602/whale01 `
  -ExpectedSourceSHA "$(git rev-parse HEAD)"
```

Expected destination:

```text
release/WhaleAgent-Sideload.ipa
release/WhaleAgent-Sideload.ipa.manifest.json
release/WhaleAgent-Sideload.ipa.sha256
```

- [ ] **Step 6: Update release records**

Record:

- version and build
- source SHA
- CI run URL
- IPA size
- IPA SHA256
- tested device model and iOS version
- passed checks
- unverified checks

Do not claim a phone installation or feature pass unless it was observed.

- [ ] **Step 7: Commit documentation**

```powershell
git add README.md CHANGELOG.md 00_执行看板.md docs/logs
git commit -m "docs: record ui interaction refactor verification"
```

## Self-Review Checklist

- [ ] Every confirmed P0 issue has a dedicated task.
- [ ] Cross-screen todo synchronization is implemented before visual cleanup.
- [ ] All complete lists are pushed pages rather than sheets.
- [ ] All voice entry points use `WhaleVoiceCaptureSheet`.
- [ ] No editing sheet can lose text through an accidental swipe.
- [ ] Destructive actions have confirmation or Undo.
- [ ] Home shows real attention state and does not repeat an empty Workspace entry.
- [ ] Reduce Motion and VoiceOver have explicit acceptance steps.
- [ ] Stale tests and dead code are removed before release.
- [ ] IPA output remains under `release/`.
- [ ] No push, build, or release happens without explicit user authorization.
