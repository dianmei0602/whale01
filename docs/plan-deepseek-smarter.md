# Nomi 智能升级施工单 · 让 DeepSeek 会查、会想、不乱答

> 交接对象：执行者（人或 AI 代理）。按 **P0 → P1 → P2 → P3 →（可选）P4** 顺序做，
> 每个阶段单独提交、单独验收。遇到需要产品决策的地方**停下来问**，不要自己定。
>
> 仓库：`https://github.com/dianmei0602/jinri1-ios`（私有）· 分支 `main`
> 工程：`phone-agent/ios-app` · 当前基线：`0ac4aa9`（Nomi 1.4 build 18 准备中）
> 开发机：Windows，**不能编译 iOS**；只能用 `swiftc -parse` + 静态检查 + 纯逻辑测试，SwiftUI 类型错误靠 CI。
> 当前基线（`0ac4aa9` 上实测）：`verify_source.ps1` → **124 个 Swift 文件解析通过 / 178 项逻辑回归通过**。

---

## 0. 先遵守仓库不变量（`ios-app/AGENTS.md`）

违反这些的提交一律打回：

1. 保留钛合金 Nomi 本体、黑玻璃脸、蓝眼、表情/眨眼/视线跟随/拖拽/物理；**黑底双眼图标只是小 logo**。
2. 三个主入口保持：**对话 / 待办 / 设置**。
3. 权限按需申请，启动时不批量要权限。
4. **音乐只来自 iPhone「音乐」资料库**（`MPMediaQuery`），不做文件导入；不能占灵动岛。
5. 资讯必须是中文，且在 Nomi 内打开。
6. 绝不编造新闻、已完成动作、授权状态、交易结果。
7. 保留整屏背景与现有滑动/键盘交互。
8. **未经用户明确要求，不 push、不发版、不触发部署。**（所以：本地 commit 完成后**停下汇报，等指令再推**。）

---

## 1. 现状核对（已按 `0ac4aa9` 验证，写代码前请再确认一次）

| 事实 | 位置 |
|---|---|
| 模型接口只有纯文本，**没有工具调用、没有流式** | `Core/LLMClient.swift`：`chat(system:user:)` L23、`chat(system:history:)` L32、`post()` L47；L57–59 写死 `temperature 0.75 / max_tokens 320 / stream false` |
| 对话主路径：有 key 调模型，**失败静默退本地规则库** | `UI/AssistantView.swift` L2566–2587（`if key.isEmpty` → `LLMClient` → `catch { AnswerEngine.answer(...) }`） |
| 第二处模型调用：给事实"换措辞"，**失败静默退模板** | `UI/AssistantView.swift` `narrate(facts:fallback:)` L541–569 |
| 本地规则库只认 6 类，其余固定话术 | `Core/AnswerEngine.swift` L82 `case .unknown: return "这个我还不会..."` |
| 意图仍靠关键词/正则，现在有 14 类 | `Core/ChatRouter.swift` L11–29（含 market / weibo / zhihu / game / news / intelligence） |
| 已有可当工具用的服务 | `IntelligenceService.load(module:)`、`NewsService.load(limit:)`、`WeiboHotSearchService.load()`、`ZhihuHotService.load()`、`MusicLibrary`(MPMediaQuery)、`MusicPlayer` |
| 诊断只有"上次谁答的、什么错" | `Core/ChatDiagnostics.swift` |

**结论**：不是模型差，是三条链路把它框住——(a) 只能纯文本、(b) 失败就退固定话术、(c) 固定几类走模板。

---

## 2. 阶段施工

### P0 · 先停止"假装聪明"（0.5 天）

**目标**：对话主路径失败必须可见、可重试；不再用固定话术冒充模型回答。

改 `UI/AssistantView.swift` L2566–2585：

1. `key.isEmpty`：保留本地回答，但开头加标记「（本地回答，未启用模型）」。
2. 有 key：先请求；抛错 → **等 400ms 重试 1 次**；两次都失败：
   - **不要**调用 `AnswerEngine`；
   - 追加一条消息：`模型没连上：<LLMClient.Failure.localizedDescription>`
   - 这条消息下挂「重试」按钮：重发上一条用户消息（新增 `@State private var retryText: String?`，按钮 action 调 `send(retryText)`）。
3. `narrate()`：同样重试 1 次；仍失败允许退回模板（**因为事实是本地查的，模板不含假数据**），但要在 `ChatDiagnostics` 里记 `narrateFailed`，便于排查。
4. `ChatDiagnostics.record` 增加 `attempts: Int` 与 `stage: String`（`chat` / `narrate`）。

**验收**
- 填错 key → 看到「模型没连上：key 无效 401」，**不是**"这个我还不会。"
- 联网恢复后点「重试」→ 正常回答。
- 天气问答仍能拿到本地事实（narrate 失败也有内容）。

**提交**：`P0 模型失败不再静默退话术：对话路径重试一次、失败明说、诊断记录次数与阶段`

---

### P1 · 工具调用（1 天，核心）

**目标**：模型自己决定"要不要查、查什么"，再基于真实结果回答。

#### P1.1 新增 `Core/NomiToolDefs.swift`（纯逻辑，可本地测）

```swift
struct NomiTool {
    let name: String
    let description: String
    let parameters: [String: Any]   // JSON Schema
}

enum NomiToolDefs {
    static var readOnly: [NomiTool] { [...] }
    static func openAITools(_ tools: [NomiTool]) -> [[String: Any]]
}
```

只读工具（**P1 只做这些**，写操作在 P2）：

| name | 参数 | 数据来源 | 拿不到时返回 |
|---|---|---|---|
| `get_weather` | `city?: string` | `AppState.dayStatus` / `currentTemperature` / `weatherNow` | `"没有天气数据"` |
| `get_schedule` | `day: "today" \| "tomorrow"` | `AppState.meetings` | `"没有日历权限"` |
| `get_todos` | `scope: "today" \| "all"` | `AppState.pendingTodos` | `"没有提醒事项权限"` |
| `get_steps` | — | `AppState.dayStatus.steps` | `"没有运动权限"` |
| `get_news` | `module: "news" \| "ai" \| "international"` | `NewsService.load(...)` | 已缓存则给缓存并标时间；没有则 `"资讯没拿到"` |
| `get_hot_topics` | `board: "weibo" \| "zhihu"` | `WeiboHotSearchService` / `ZhihuHotService` | `"热搜没拿到"` |
| `get_market` | `keyword?: string` | `IntelligenceService` 里已有行情模块 | `"行情没拿到"` |
| `get_now_playing` | — | `MusicPlayer.current`（Music 资料库） | `"没在播音乐"` |

#### P1.2 改 `Core/LLMClient.swift`

**保留**现有 `chat(system:user:)` 与 `chat(system:history:)`（其它调用点还在用），新增：

```swift
struct ToolCall { let id: String; let name: String; let argumentsJSON: String }
enum LLMReply { case text(String); case tools([ToolCall]) }

func chatWithTools(system: String,
                   history: [ChatTurn],
                   tools: [[String: Any]]) async throws -> LLMReply
```

- 请求体加 `"tools"`、`"tool_choice": "auto"`。
- 解析 `choices[0].message`：有 `tool_calls` → `.tools`；否则 `.text`。
- 为了后续多轮，需要能发送 `assistant(tool_calls)` 与 `role: "tool"` 消息：
  新增内部 `postRaw(messages: [ [String: Any] ])`，`post` 保持旧行为不变。

#### P1.3 新增 `Core/NomiToolRunner.swift`

```swift
@MainActor
struct NomiToolRunner {
    let state: AppState
    func run(_ call: ToolCall) async -> String   // 永远返回字符串，绝不 throw
}
```

**硬规则**：只返回事实；拿不到返回中文说明；不许编数字；单次工具超时 6 秒（网络类工具），超时返回 `"查询超时"`。

#### P1.4 在 `AssistantView` 接入工具循环

替换 L2566–2585 的"直连 chat"：

```
最多 4 轮：
  reply = try await client.chatWithTools(system, history, tools)
  .text  → 用它做回答
  .tools → 逐个 runner.run()，结果作为 role:"tool" 消息追加，继续
超过 4 轮 → 回答"这个问题我查了几次还没结论，换个说法？"
```

`systemPrompt`（L3421 起）追加：

```
你可以调用工具拿真实数据。规则：
- 需要天气/日程/待办/步数/资讯/热搜/行情/正在播的音乐时，先调工具，再回答。
- 工具说"没有…"就照实说，不要猜数字，不要编新闻标题。
- 只读工具可以自己调；写操作（加日程、改期、取消、加待办）不要直接做，交给确认卡。
```

**验收（CI 绿后装机）**
- 「今天适合穿什么」→ 至少调 `get_weather`；回答数字与首页卡片一致。
- 「我今天还有几件事」→ 调 `get_schedule` 或 `get_todos`；数量与页面一致。
- 「微博上有什么热搜」→ 调 `get_hot_topics(board:"weibo")`，**标题必须来自工具返回**。
- 「讲个笑话」→ 不调工具，直接回答。
- 没授权日历时问日程 → "没拿到日历权限"，不是"我没有这个能力"。

**提交**：`P1 工具调用：只读工具集 + chatWithTools 循环 + 工具执行器`

---

### P2 · 写操作也能交给模型"提议"，但必须经确认卡（0.5 天）

前提：P1 通过。

1. 新增 `propose_*` 工具（**只生成待确认动作，不执行**）：
   - `propose_create_event(title, startISO, durationMinutes?)`
   - `propose_update_event(keywordOrTime, newStartISO)`
   - `propose_cancel_event(keywordOrTime)`
   - `propose_create_todo(title, dueISO?)`
2. runner 收到 `propose_*`：返回 `"已生成待确认动作"`，同时回调把动作交给 `AssistantView`，复用现有 `PendingMeetingAction` / `PendingTodoAction` 与确认行（`pendingItemID` 机制）。
3. `systemPrompt` 明确：**"写操作只能提议，用户点确认才执行；不要声称已经改好了。"**

**验收**
- 「把四点的会改到五点」→ 出确认卡（原时间/新时间）；点「算了」日历不变。
- 「加个待办：明天买牛奶」→ 确认卡；确认后系统「提醒事项」出现。
- 模型提到的会议不存在 → 不出确认卡，回答"没找到"。

**提交**：`P2 写操作提议化：模型只能生成待确认动作，执行仍由确认卡触发`

---

### P3 · 参数、上下文与（可选）流式（0.2 天）

1. `chatWithTools` 参数：`max_tokens` 700、`temperature` 0.6、`timeoutInterval` 25。
   `narrate` 单独用短预算（`max_tokens 160`），别为一句天气付 700 的延迟。
2. `systemPrompt` 注入记忆条目（若 `ChatStore` 有偏好/事实列表，取最近 20 条，格式 `- 偏好：…`）。
3. 可选：SSE 流式（`stream: true`，解析 `data:` 行，逐字更新气泡）。**来不及就跳过，不阻塞交付。**

**验收**：长回答不被截断；同一问题两次措辞可不同、数字一致；缓存与首字延迟没有明显变差。

**提交**：`P3 参数调优 + 记忆注入（+可选流式）`

---

### P4 · 可选：真联网搜索（1 天，需用户先给 key，默认关闭）

> **DeepSeek API 本身不联网。** 这一阶段才谈"搜索"。

1. 新增 `Core/WebSearchClient.swift`：`search(query:) async throws -> [SearchHit]`，8 秒超时、最多 3 条（title/snippet/url）。
2. 服务商三选一（由用户决定）：Tavily（最省事）/ Bing Web Search（最全）/ Brave（便宜）。
3. 设置「高级」新增：搜索开关（默认关）+ key 输入 + 服务商选择。key 存 Keychain（`search.key`），**不许写进代码**。
4. 工具 `search_web(query)`：未开/无 key → `"没有开启联网搜索"`；成功 → 3 条结果；每轮对话最多 1 次。
5. `systemPrompt`：用搜索回答要带来源域名；结果无关就直说没查到。

**验收**
- 关着开关问「今天有什么新闻」→ 回答"没开联网搜索"，**不编新闻**。
- 开着 → 回答含具体内容与来源域名。
- key 错 → 明确报错。

**提交**：`P4 可选联网搜索：Tavily/Bing/Brave，默认关闭、每轮最多一次`

---

## 3. 每个阶段提交前必须通过

```powershell
# 仓库自带验证（AGENTS.md 指定）
powershell -NoProfile -File "$env:USERPROFILE\.codex\skills\nomi-project-maintainer\scripts\verify_source.ps1"

# 现有检查工具（在 phone-agent 下）
$py = "C:\Users\Administrator\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe"
$base = "C:\Users\Administrator\Documents\deepseek-harness\default-workspace\phone-agent"
& $py "$base\tools\run_logic_checks.py"   # 已改为转发仓库验证脚本，别再加文件清单
& $py "$base\tools\check_swiftui.py"
& $py "$base\tools\check_state.py"
& $py "$base\tools\check_arg_order.py"
& $py "$base\tools\check_enum_switches.py"

# 语法（Swift 在 PATH）
Get-ChildItem "$base\ios-app\ios\App" -Recurse -Filter *.swift | ForEach-Object {
  & swiftc -parse "$($_.FullName)" 2>$null
  if ($LASTEXITCODE -ne 0) { "FAIL: $($_.Name)" }
}
```

**新增纯逻辑文件必须登记**：
- `phone-agent/tools/run_logic_checks.py` 的 `SOURCES`
- `ios-app/.github/workflows/ios.yml` 的编译文件列表

并补纯逻辑测试：工具 JSON Schema 结构、`tool_calls` 解析、`propose_*` 无副作用。

**CI**：push 后看 `build-ipa`。红了只贴第一条 `error:` 回来修；**一次只推一件事**，别叠着推。

---

## 4. 完成标准（DoD）

- [ ] P0：断网明确报错 + 可重试；固定话术不再冒充模型回答
- [ ] P1：4 类开放问题都触发正确工具；数字与页面一致；资讯标题来自工具
- [ ] P2：加/改/取消日程、加待办全部经确认卡；模型不声称"已改好"
- [ ] P3：长回答不截断；记忆进入 prompt
- [ ] P4（若做）：默认关闭；开着出带来源的回答；关着明确说没开
- [ ] `verify_source.ps1` 通过；逻辑回归全过；CI 绿
- [ ] 角色资产 7 文件 `git status` 干净
- [ ] 每个阶段一个 commit，message 用本文给出的那句

---

## 5. 汇报格式（每个 commit 后）

```
P1 完成 · commit abc1234（未推送，等指令）
- 改：LLMClient.swift / NomiToolDefs.swift / NomiToolRunner.swift / AssistantView.swift
- 检查：verify_source 通过 · 语法 0 失败 · 逻辑回归 N 项全过
- CI：未运行（按仓库规则未推送）
- 待确认：是否需要推送触发 build
```

---

## 6. 风险与红线

| 风险 | 处理 |
|---|---|
| 模型编数字 | 只允许引用工具返回；`systemPrompt` 明令禁止猜测；测试用例专门验 |
| 模型直接写日历 | 架构上不给写工具，只给 `propose_*`；执行路径只有确认卡 |
| 工具循环死循环 | 最多 4 轮，超限给兜底话术 |
| 网络类工具拖慢对话 | 单工具 6 秒超时，超时返回"查询超时"，模型照实说 |
| CI 类型错误 | 小步提交；每次只改一两个文件；红了先修再继续 |
| 误改角色/音乐 | 动手前后 `git status` 核对 `PetCharacterView/PetCharacterCanvas/PetLife/PetMotionEngine/PetMood/FaceTracker/PhysicsBox` 与 `MusicLibrary.swift` |
