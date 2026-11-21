import XCTest
@testable import WhaleAgent

@MainActor
final class WorkspaceTests: XCTestCase {
    private func makeStore() -> WhaleWorkspaceStore {
        let suite = "workspace-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return WhaleWorkspaceStore(defaults: defaults, storageKey: "archive")
    }

    func testCaptureFallsBackToBodyAndSupportsKnowledgeSearch() {
        let store = makeStore()
        let item = store.capture(
            title: "",
            body: "周末整理旅行路线和酒店确认单",
            kind: .note,
            isKnowledge: true
        )

        XCTAssertEqual(store.inbox.count, 1)
        XCTAssertEqual(store.knowledge.count, 1)
        XCTAssertFalse(item.title.isEmpty)
        XCTAssertEqual(store.searchKnowledge("酒店").first?.id, item.id)
        XCTAssertTrue(store.searchKnowledge("不存在的关键词").isEmpty)
    }

    func testProjectAssignmentAndFollowUpArePersistedInStore() {
        let store = makeStore()
        let project = store.addProject(name: "春节旅行", summary: "交通、住宿与路线")
        let item = store.capture(
            title: "确认酒店入住时间",
            body: "周五前确认",
            kind: .note
        )
        store.assign(item, to: project?.id)
        _ = store.addFollowUp(
            subject: "确认酒店",
            detail: "检查入住和退房时间",
            dueAt: Date().addingTimeInterval(3_600),
            projectID: project?.id
        )

        XCTAssertEqual(store.captures.first?.projectID, project?.id)
        XCTAssertEqual(store.pendingFollowUps.count, 1)
        XCTAssertEqual(store.captures.first?.isArchived, false)
    }

    func testReviewAndFocusOnlyRecordExplicitActions() {
        let store = makeStore()
        let review = store.review()
        store.saveReview(review, morningFocus: "先完成报告", eveningNote: "报告已完成")
        store.startFocus(.writing)
        store.endFocus()

        XCTAssertEqual(store.review().morningFocus, "先完成报告")
        XCTAssertEqual(store.review().eveningNote, "报告已完成")
        XCTAssertNil(store.activeFocusMode)
        XCTAssertEqual(store.focusSessions.count, 1)
        XCTAssertNotNil(store.focusSessions.first?.endedAt)
    }

    func testLegacyWorkspaceArchiveLoadsAndMigratesWithoutLosingCaptures() {
        let suite = "workspace-legacy-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("{\"captures\":[]}".utf8), forKey: "archive")

        let store = WhaleWorkspaceStore(defaults: defaults, storageKey: "archive")
        XCTAssertNil(store.loadIssue)
        _ = store.capture(title: "新记录", body: "迁移后的内容", kind: .note)

        let restored = WhaleWorkspaceStore(defaults: defaults, storageKey: "archive")
        XCTAssertEqual(restored.captures.first?.title, "新记录")
    }

    func testCorruptWorkspaceArchiveIsBackedUpAndReported() {
        let suite = "workspace-corrupt-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let corrupt = Data("not-json".utf8)
        defaults.set(corrupt, forKey: "archive")

        let store = WhaleWorkspaceStore(defaults: defaults, storageKey: "archive")
        XCTAssertNotNil(store.loadIssue)
        XCTAssertEqual(defaults.data(forKey: "archive.corrupt-backup"), corrupt)
    }

    func testWorkspaceToolsRoundTripThroughNativeRouter() async throws {
        let router = NativeToolRouter(permissions: PermissionCenter())
        let marker = "router-\(UUID().uuidString)"
        let save = PendingTool(
            tool: "save_capture",
            toolCallId: "save-\(marker)",
            operationId: "save-op-\(marker)",
            arguments: [
                "body": .string("把 \(marker) 保存到工作区"),
                "title": .string(marker)
            ],
            requiresConfirmation: false
        )
        let saveResult = await router.execute(save)
        XCTAssertEqual(saveResult.status, "success")
        let savedID = try XCTUnwrap(saveResult.data?.objectValue?.optionalString("id"))

        let search = PendingTool(
            tool: "search_workspace",
            toolCallId: "search-\(marker)",
            operationId: "search-op-\(marker)",
            arguments: ["query": .string(marker)],
            requiresConfirmation: false
        )
        let searchResult = await router.execute(search)
        XCTAssertEqual(searchResult.status, "success")
        XCTAssertGreaterThanOrEqual(searchResult.data?.objectValue?.optionalInt("count") ?? 0, 1)

        if let item = WhaleWorkspaceStore.shared.captures.first(where: { $0.id == savedID }) {
            WhaleWorkspaceStore.shared.delete(item)
        }
    }
}

final class AgentPlanningPolicyTests: XCTestCase {
    func testBudgetUsesRequestedFormulaAndBounds() {
        XCTAssertEqual(AgentPlanningPolicy.batchBudget(for: 0), 3)
        XCTAssertEqual(AgentPlanningPolicy.batchBudget(for: 1), 3)
        XCTAssertEqual(AgentPlanningPolicy.batchBudget(for: 3), 5)
        XCTAssertEqual(AgentPlanningPolicy.batchBudget(for: 20), 10)
    }

    func testPlanRevisionRequiresAllFailedMultiStepAndNoPriorRevision() {
        let failed = ToolResultPayload(
            toolCallId: "a",
            status: "failed",
            error: ToolErrorPayload(code: "timeout", message: "超时")
        )
        XCTAssertTrue(
            AgentPlanningPolicy.shouldRevisePlan(results: [failed], taskCount: 2, previousRevisions: 0)
        )
        XCTAssertFalse(
            AgentPlanningPolicy.shouldRevisePlan(results: [failed], taskCount: 1, previousRevisions: 0)
        )
        XCTAssertFalse(
            AgentPlanningPolicy.shouldRevisePlan(results: [failed], taskCount: 2, previousRevisions: 1)
        )
        let success = ToolResultPayload(toolCallId: "b", status: "success")
        XCTAssertFalse(
            AgentPlanningPolicy.shouldRevisePlan(results: [failed, success], taskCount: 2, previousRevisions: 0)
        )
    }

    func testCoreToolsSurviveNarrowToolSelection() {
        let available = AgentPlanningPolicy.coreToolNames.union(["play_music", "research_web"])
        let analysis = RequestAnalysis(
            goal: "整理文字",
            tasks: ["组织文字"],
            skills: ["writing"],
            suggestedTools: [],
            confidence: 0.9
        )
        let selected = analysis.selectedToolNames(available: available)
        XCTAssertTrue(AgentPlanningPolicy.coreToolNames.isSubset(of: selected))
    }
}

@MainActor
final class AgentStreamingPipelineTests: XCTestCase {
    private actor StreamingTransport: AgentTransport {
        func health() async throws -> HealthResponse {
            HealthResponse(status: "ok", modelMode: "mock", executionMode: "ios", adapterConfigured: true, tools: 0, requiresDeferExecution: true, authRequired: false)
        }
        func turnSnapshot(turnId: String) async throws -> AgentTurnResponse { throw URLError(.unsupportedURL) }
        func startTurn(text: String, conversationId: String?, permissions: [String: String], deferExecution: Bool) async throws -> AgentTurnResponse {
            throw URLError(.unsupportedURL)
        }
        func submitToolResults(turnId: String, results: [ToolResultPayload]) async throws -> AgentTurnResponse {
            throw URLError(.unsupportedURL)
        }
        func startTurnStreaming(text: String, conversationId: String?, permissions: [String: String], deferExecution: Bool, onDelta: @escaping @Sendable (String) -> Void) async throws -> AgentTurnResponse {
            onDelta("流式")
            onDelta("完成")
            return AgentTurnResponse(
                contractVersion: "1.0",
                turnId: "turn-stream",
                conversationId: "conversation-stream",
                status: "completed",
                reply: "流式完成",
                modelMode: "mock",
                executionMode: "ios",
                events: [],
                pending: [],
                task: nil
            )
        }
    }

    func testStreamingDeltaFlowsThroughAppModelAndFinalReplyReplacesPreview() async {
        let model = AppModel(transport: StreamingTransport())
        model.setVoiceReply(false)
        await model.send(text: "测试流式")
        XCTAssertEqual(model.messages.last?.role, .assistant)
        XCTAssertEqual(model.messages.last?.text, "流式完成")
        XCTAssertTrue(model.streamingReply.isEmpty)
    }

    func testToolContractRegistryIsSingleSourceForSkills() {
        XCTAssertEqual(ToolRegistry.tools.count, 42)
        XCTAssertTrue(ToolRegistry.names.contains("search_workspace"))
        for skill in AgentSkill.allCases {
            XCTAssertTrue(skill.tools.isSubset(of: ToolRegistry.names))
        }
    }
}
