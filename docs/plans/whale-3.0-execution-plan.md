# 鲸鱼 3.0 执行方案：从能办事，到留得住

- 日期：2026-11-22
- 基线：`2.0.4 (204.1)`，构建源码 `69298d4`；工作分支 `ui-sea-salt-0.8` 的 HEAD 为 `594d825`
  （本地工作区、桌面组件、分享收件箱、快捷指令，**未进 CHANGELOG**）
- 依据：`CHANGELOG.md`、`docs/plans/whale-2.0-execution-plan.md`、
  `docs/plans/whale-2.1-execution-plan.md`、`18_下一步推进事项.md`、
  `19_目标版本完整技能与任务目录.md`，以及本次对 `ios/WhaleAgent` 的逐文件行号复核
- 性质：**方案，不含实现**。所有「现状」落到本次复核的文件行号；所有「改法」不触碰
  README「产品边界」的六条。
- 与 2.1 方案的分工：**2.1–2.3 是功能补课（第 1–4 周），本文是 3.0 架构跃迁（第 5–10 周）**。
  同时把 `18_下一步推进事项` 第三批与 `19_目标技能目录` 中尚未归口的能力并入 3.0，
  三份规划到此归一，不再各排各的。

---

## 0. 先说结论

2.0 把骨架做对了：计划器 → 工具循环 → 证据守卫 → 发送前审查，四段都在代码里。
11-22 又落了本地工作区，方向也对。但当前是**「能力已经铺开，地基仍是原型级」**：

| 缺口 | 证据 | 用户感受 |
|---|---|---|
| 3300 行新代码未入册 | `594d825` 新增 22 个文件，`CHANGELOG.md:3` 仍停在 2.0.4 | 不知道手机上跑的到底是哪版 |
| 工作区 Agent 够不着 | 全仓无 `search_workspace` / `save_capture`；`WhaleWorkspaceStore` 只有 UI 在调 | 记了东西，问「我上周记的那个报价」答不上来 |
| 中心装配点过大 | `App/AppModel.swift` 1664 行、40+ 个 `@Published`（`:77-125`） | 每加一个能力都要改同一个文件 |
| 数据层没有迁移能力 | 全靠 `UserDefaults` + 硬编码 key（`WhaleWorkspace.swift:151` 等） | 3.0 要改结构，老数据不敢动 |

**优先级判断**：先收口，再补课，最后跃迁。理由很实在——`594d825` 没跑完整回归就谈重构，
等于在流沙上盖楼；2.1–2.3 方案已经写好且成本明确，照做即可，不需要在 3.0 里重新设计；
真正属于 3.0 的活是**让工作区从「一个页面」变成「产品的组织方式」**，并顺手还清架构债。

---

## 1. 已核实基线（动手前请复核）

| 事实 | 位置 |
|---|---|
| 版本与构建号 | `ios/project.yml:14-15`（`204` / `2.0.4`）；`README.md:7`；`CHANGELOG.md:3` |
| 引擎为单次规划 + 工具循环，`analyze()` 只跑一次 | `Networking/AgentReasoningClient.swift:19`；`LocalAgentEngine.swift:360` |
| 全链路非流式 | `LocalAgentEngine.swift:573` `stream: false`、`:574` `max_tokens`；`AgentReasoningClient.swift:240` |
| 模型请求入口、工具暴露 | `LocalAgentEngine.swift:525` `callModel`、`:533` `relevantTools`、`:623` 定义 |
| 双层证据守卫 | `LocalAgentEngine.swift:396-458`；`Execution/RealDataGuard.swift:30` |
| 39 个工具；分发表 39 个 case | `contracts/v1/tools.v1.json`；`Execution/NativeToolRouter.swift:762-858` |
| 工具契约在两处副本加载 | `LocalAgentEngine.swift:824-825`（`tools.v1`）；`Execution/AgentSkillManifest.swift:36-37`（`skills.v2`） |
| 工作区模型与 Store（441 行） | `Models/WhaleWorkspace.swift:135`、`:136` `shared` |
| 工作区**已有**本地检索 | `WhaleWorkspace.swift:319` `searchKnowledge`、`:329` `searchAll` |
| 工作区视图 1738 行、7 个分区 | `UI/WhaleWorkspaceView.swift:6-13`；`:135` 打开原文 |
| 工作区入口是 sheet，不是主入口 | `UI/RootView.swift:13`、`:55-72`；三页结构 `:155-172`、`:259-261` |
| 中心状态与消息链路 | `App/AppModel.swift:76`、`:130`、`:362`、`:529`、`:676`、`:1465`、`:1506`、`:1599` |
| 死代码：`ChatView.swift` 981 行全仓零引用 | `UI/ChatView.swift`（在用视图为 `UI/ConversationSurface.swift`） |
| 展示映射另有两处 | `Models/AgentModels.swift:108` `ToolCatalog`；`Models/AppPresentation.swift:533` `ToolPresentation` |
| 阅读库只有 `SavedArticle` + `isReadLater`，上限 80 | `Models/DiscoverV2.swift:4`、`:12`、`:74`；聚类 `:102` |
| 正文抽取能力已存在，只被工具用 | `Execution/WebContentExecutor.swift`（290 行） |
| 情景记忆：120 条上限、独立 JSON 文件 | `Execution/AgentMemoryStore.swift:15`、`:21`、`:26` |
| 后台能力只有 `audio` | `ios/WhaleAgent/Info.plist:52-55` |
| 分享通道同时兼容 App Group 与侧载 URL scheme | `ios/Shared/SharedInbox.swift`（40 行） |
| 三个新增 App Intent | `Intents/WorkspaceIntents.swift`（59 行，3 个 Intent） |
| 测试：101 个单测函数 | `ios/WhaleAgentTests/`（6 个文件，含 `WorkspaceTests.swift` 63 行） |

### 本次复核修正的 5 处（重要，2.1 方案的行号已漂移）

1. **S3 工具预算已部分实施**：`LocalAgentEngine.swift:222` 现为
   `min(max(analysis.tasks.count + 3, 6), 8)`，不再是固定 6。3.0 不再重复「把 6 改成动态」，
   只需补 `:300` 超限文案里的剩余步骤与 `App/ModelRequestMetrics.swift` 的诊断展示。
2. **技能域是 12 个，不是 8 个**：`ios/WhaleAgent/Resources/skills.v2.json:4-15`
   （general / schedule / travel / health / music / messaging / research / finance /
   memory / writing / coding / entertainment）。新增工作区工具应挂新域或并入 memory。
3. **`InAppSafari` 是 6 处，不是 2 处**：`UI/DiscoverChannelPages.swift:471`、`:772`，
   `UI/NewsDetailView.swift:85`，`UI/DiscoverLibraryView.swift:71`，
   `UI/GameDetailView.swift:54`，`UI/WhaleWorkspaceView.swift:135`。阅读器要替换全部 6 处。
4. **工作区工具化的工作量小于 2.1 方案估计**：`WhaleWorkspace.swift:319`、`:329`
   已有词法检索，W1 主要缺「工具注册 + 路由 + 确认」，不是「从零建检索」。
5. **`AgentMemoryStore` 在 `Execution/`，不在 `Models/`**；2.1 方案 `:21` 的容量数字正确，
   但文件路径需订正。

---

## 2. P0 · 收口（第 0 周，必做，不然后面全是空中楼阁）

### P0-1 把 `594d825` 变成有身份的版本

**做法**

1. 对 `594d825` 跑完整回归：单元（现 101 项）+ UI 专项 + 侧载构建，
   工作流见 `.github/workflows/`；结果写入 `docs/logs/` 新建日志。
2. `ios/project.yml:14-15` 版本号提升为 `3.0` 规划前的过渡版（`2.1.0` / `210`），
   `CHANGELOG.md` 新增条目，列明 22 个新增文件、共享收件箱与 3 个 App Intent。
3. `README.md:7-12` 同步版本、构建源码与安装包 SHA256；`docs/README.md` 补新文件索引。
4. 真机补验三项：分享扩展交接、App Intent 不打开 App 写入、`WhaleQuoteWidget` 刷新。

**验收**

- 单测 + UI 全绿，侧载 IPA 记录版本、源码 SHA、IPA SHA256。
- `README` 与 `CHANGELOG` 的当前版本一致，不再出现「HEAD 比文档新」。
- 质量不达标则明确回滚该提交，并记录原因，不允许「先放着」。

**排期**：第 0 周（约 2–3 天）。

---

## 3. 第一阶段 · 2.1–2.3 照做（第 1–4 周）

`docs/plans/whale-2.1-execution-plan.md` 已给出完整做法与验收，本阶段**不重新设计**，
仅按上文的「5 处修正」替换锚点后执行。归口表如下，每项交付门槛沿用 2.0 规格：

| 周 | 内容 | 修正后的落点 | 验收要点 |
|---|---|---|---|
| 1 | S1 流式 / S3 预算收尾 / S4 等待态 | `LocalAgentEngine.swift:525`、`:573`；`AppModel.swift:1506`；`ModelRequestMetrics.swift` | 首字 ≤1.5s；工具轮不流式；半截内容可重试 |
| 2 | R1 原生阅读器 / R4 阅读队列与摘录 | 替换 6 处 `InAppSafari`；`WebContentExecutor.swift`；`DiscoverV2.swift:4`、`:74`；写入 `WhaleWorkspace.swift:186` | 抽取成功率 ≥80%；摘录落 `WorkspaceCapture` |
| 3 | R2 划重点 / R3 事件聚类 v2 | `AgentReasoningClient.swift:186`；`DiscoverV2.swift:102` | 要点可定位原句；同事件准确率 ≥8/10 |
| 4 | S2 计划修订 / W1 工作区工具化 / W4 快捷指令验收 | `LocalAgentEngine.swift:360`；`NativeToolRouter.swift:762`；`WorkspaceIntents.swift` | 失败能换路；「上周记的报价」能检索到 |

**本阶段结束的定义**：正文进 App、工作区有数据流入且 Agent 能读到，
`18_下一步推进事项` 第一、二批中与「信息获取」相关的条目全部有证据。
**排期**：第 1–4 周。

---

## 4. 第二阶段 · 3.0 主体（第 5–10 周）

### A1 · 工作区扶正为主入口（定位跃迁）

**做法**

1. `UI/RootView.swift:155-172` 的 `pager` 目前是三页常驻 `ZStack`，
   `:259-261` 的 `WhaleRootTabBar` 只有「助手 / 发现 / 待办」。3.0 增加工作区为第四个主入口，
   把 `:55-72` 的 `.sheet(isPresented: $showWorkspace)` 改为根级页面。
2. 保留 `:13` 的 `showWorkspace` 仅用于外部深链（`:120` `onOpenURL`、
   `:143` `.whaleOpenWorkspace`），不再承载主导航。
3. `UI/WhaleWorkspaceView.swift:6-13` 的 7 个分区按「收件箱 / 项目 / 知识库 / 阅读 / 晨晚报 /
   专注 / 跟进」重排为 4 个主分段，避免 1738 行单文件继续膨胀（配合 A3 拆分）。
4. 首页 `UI/WhaleHomeCanvas.swift`（1355 行）增加「工作区最近 3 条」组件，
   数据取 `WhaleWorkspace.swift:165` `inbox`。

**验收**：不打开 sheet 即可进入工作区；三页原有手势、草稿保留与滚动位置回归全过；
`WHALE_DEMO_*` 环境变量（`RootView.swift:77-107`）不因结构变化失效。
**排期**：第 5 周。

### A2 · 工作区工具化（W1 修正版）

**做法**

1. 在 `contracts/v1/tools.v1.json` 与 `ios/WhaleAgent/Resources/tools.v1.json`
   **同步**新增 4 个工具：`search_workspace` / `save_capture` / `list_followups` / `add_followup`。
   `skills.v2.json:4-15` 增 `workspace` 域（`kind: tool`），guidance 写明「写入先给预览」。
2. `Execution/NativeToolRouter.swift:762-858` 的 `route` 分发表新增 4 个 case；
   两个写工具必须经 `:43` `execute` → `:165` 写入分发表 → 确认流程，
   沿用 `create_reminder` 的 `operationId` 去重策略（`:240-300`）。
3. 实现直接复用 `WhaleWorkspaceStore` 现成方法：检索 → `:329` `searchAll`，
   保存 → `:186` `capture`，跟进 → `:284` `addFollowUp` / `:341` `review`。
   **不要另建一套存储或索引**。
4. `Models/AppPresentation.swift:533` `ToolPresentation` 补 4 个工具的确认文案与展示名。

**验收**：真机问「我上周记的那个报价」返回真实条目且带来源；
「把这个记下来」先出操作预览再落库；断网重启不重复写入；39→43 个工具的契约测试通过。
**排期**：第 5–6 周（与 A1 并行）。

### A3 · 拆 `AppModel`

**做法**

1. 以 `App/AppModel.swift:77-125` 的 40+ 个 `@Published` 按域分组，
   抽出 `ConversationStore`（`:362` `appendMessage`、`:1506` `appendReplyIfNeeded`、
   `:1599` `appendReceipt`）、`ExecutionStore`（`:467`、`:1465`）、
   `DashboardStore`（`:97-99`）、`SpeechStore`（`:205-228`、`:113-120`）。
2. `AppModel` 保留为薄装配层：持有各 Store 与 `:130` `localEngine`，
   `send`（`:529`）只做编排，不再直接读写所有状态。
3. 引入最小依赖注入（构造器注入 Store，`RootView.swift:7-9` 的 `@StateObject` 改为显式装配），
   让单测可以构造独立 Store 而不启动整个 AppModel。
4. 顺手处理 `:116` 一类散落的 `UserDefaults.standard.string(forKey:)`（配合 A5）。

**验收**：`AppModel.swift` 降到 400 行以内；现有 101 项单测全绿且不改断言；
新增 4 个 Store 各有独立单测；无 UI 行为回归。
**排期**：第 6–7 周。

### A4 · 工具契约单一来源

**做法**

1. 现状三处并存：`contracts/v1/tools.v1.json`（后端契约）、
   `ios/WhaleAgent/Resources/tools.v1.json`（App 资源，由 `LocalAgentEngine.swift:824-825` 加载）、
   `skills.v2.json`（`AgentSkillManifest.swift:36-37`），
   外加 `Models/AgentModels.swift:108` 与 `Models/AppPresentation.swift:533` 两处展示映射。
2. 用 `tools/` 下新增的生成脚本，以 `contracts/v1/tools.v1.json` 为唯一源，
   生成 App 资源副本、Swift 工具名常量与展示映射骨架；生成物进 Git，CI 加「重新生成后无 diff」检查。
3. `skills.v2.json` 的 `tools` 数组改为引用工具名，不再复制一份列表。

**验收**：新增一个工具只需改一处；契约测试与生成一致性检查通过；
`NativeToolRouter.swift:762` 的分发表有「缺 case 即编译失败」的保障（改用 enum 或宏）。
**排期**：第 7 周。

### A5 · 数据层与迁移

**做法**

1. 盘点所有持久化点：`WhaleWorkspace.swift:151` `whale.workspace.archive.v1`、
   `:410` `persist`、`:424` `load`；`AgentMemoryStore.swift:26` `agent-memory-v1.json`；
   `SharedInbox.swift` `pending.share.v1`；以及全仓 `whale.*` 前缀的 `UserDefaults` key。
2. 引入 `PersistenceStore` 协议 + 版本化迁移层（`schemaVersion`，逐版本 migrate 函数，
   迁移前后各跑一次一致性校验）。评估 SwiftData（部署目标 iOS 17，`project.yml:5` 已满足）；
   若采用，工作区、跟进、复盘三张表先行，`SavedArticle`（`DiscoverV2.swift:4`）随后。
3. 迁移必须覆盖：旧 `isReadLater: Bool`（`:12`）→ 新 `state` 枚举；
   旧工作区归档 → 新实体。旧数据只读回退，不允许静默丢弃。
4. 侧载构建无 App Group（`SharedInbox.swift` 已用 URL scheme 兜底），
   迁移方案必须同时验证正式签名与 `FREE_SIGNING` 两条路径。

**验收**：构造 v1 归档样本升级到 v2，条数、内容、项目关联、跟进状态零丢失；
迁移失败时保留原数据并明确报错；两条签名路径各跑一次。
**排期**：第 8–9 周（**A2/A3 完成后再动**，否则会与拆 Store 冲突）。

### A6 · 长期记忆与可编辑偏好（并入 `18_` 第三批 MEMORY-01）

**做法**

1. `Execution/AgentMemoryStore.swift:15-26` 目前是「字面 bigram 余弦 + 120 条 + 把旧模型回复回灌」。
   3.0 拆成两层：情景记忆（保留，但**停止把当时答复回灌进 prompt**，只留用户说过什么）；
   显式偏好（走 `NativeToolRouter.swift:810-814` 的 `list_memory` / `set_memory` /
   `delete_memory` 与 `skills.v2.json:12` memory 域）。
2. 工作区新增「我告诉过鲸鱼什么」页，可查看、更正、删除，每条能定位来源对话。
3. 偏好不自动成为操作授权（README 产品边界第 3 条）。

**验收**：「记住我不吃辣」→ 新会话生效 → 「你记住了我什么」可列出 → 「忘掉」后不再使用；
旧答复不再污染新回答；`19_目标技能目录` 2.16 的完成标准满足。
**排期**：第 9 周。

### A7 · 周期服务与关注词（并入 `18_` 第三批 ROUTINE-01、2.1 方案 W3）

**做法**

1. `ios/WhaleAgent/Info.plist:52-55` 的 `UIBackgroundModes` 目前只有 `audio`，
   要支持「每天早上有雨提醒带伞」需评估 `BGAppRefreshTask` + 本地通知，
   并在 `project.yml` 两个 target 同步。
2. 流程保存前必须有一次成功的一次性执行（沿用 `19_目标技能目录` 2.17 的完成标准）；
   每次运行独立记录成功／失败／等待，通知里写明数据来源与时间。
3. 关注词提醒只做**本地匹配已抓取资讯**，通知文案注明「本地匹配，非推送新闻」。

**验收**：试跑成功、暂停/恢复/删除可用、逐次运行日志可查；
耗电与审核说明提前写进 `docs/logs/`；做不到后台刷新就如实降级为「打开 App 时补算」，
不假称后台已读。
**排期**：第 9–10 周。**若第 4 个待决策项选择不引入后台，本项降级为前台方案。**

### A8 · 测试与质量

**做法**

1. 现状 101 项单测偏纯函数与契约，缺网络层、执行层端到端与视图测试。
   补：`LocalAgentEngine` 的「规划→工具失败→修订→合成」E2E、
   `NativeToolRouter` 写入去重链路、A2 四个工具的成功/失败/取消路径。
2. A1 的四入口导航补 UI 测试；A5 迁移补快照测试。
3. `docs/logs/` 每阶段一篇，沿用 2.0.1–2.0.4 的格式（目标、做法、验收、证据链接）。

**验收**：核心链路 E2E 覆盖；现有单测全绿；CI 的 app 与测试目标编译通过；
动 EventKit、语音或公开数据的改动分别跑模拟器回归 + 真机验收。
**排期**：贯穿第 5–10 周，每阶段随交付补测。

---

## 5. 明确不做

- **不做运行时多 Agent**（README 产品边界第 1 条）。规划、审查、合成是同一次任务的阶段。
- **不引入向量库或 Embedding**。`WhaleWorkspace.swift:319`、`:329` 的词法检索已够用，
  加向量意味着上传内容或设备端跑模型，隐私与耗电都不划算。
- **不接付费第三方数据源**，没有授权就不显示估算数字。
- **不做「利好利空」、不做买卖建议**（`skills.v2.json:11` finance 域 guidance 已写明）。
- **不因 3.0 恢复已废弃的 UI 方案**（`13_UI方案废弃决定.md`）。
- **不把 WeatherKit / HealthKit 的条件能力写成「已支持」**；
  `FREE_SIGNING` 下仍按 `19_目标技能目录` 2.6 / 2.7 标注受限。
- **不改 README 产品边界六条**；工作区云同步若被否决，全部数据保持本机。

---

## 6. 交付门槛（沿用 2.0 规格，不放松）

- 新领域模型一律有单元测试；现有 101 项必须全绿。
- GitHub Actions 完成 app 与测试目标编译；UI 相关改动跑 `ios-ui-tests`。
- 动公开数据、EventKit、语音链路 → 模拟器回归 + 真机验收，缺一不算完成。
- 只有本轮 `tool.result.status == success` 才能说「已完成」。
- 侧载 IPA 记录版本、源码 SHA、IPA SHA256；含讯飞凭据的包不进 Git、不公开转发。
- 每个阶段结束必须更新 `CHANGELOG.md`、`README.md:7-12` 与 `docs/README.md`，
  不允许再出现 HEAD 比文档新的情况。

---

## 7. 排期与待决策

| 周 | 内容 | 产出 |
|---|---|---|
| 0 | P0 收口 `594d825` | `2.1.0`：新能力入册、全量回归、IPA 可核对 |
| 1 | S1 流式 + S3 收尾 + S4 | `2.1.x`：首字 ≤1.5s、成本可见 |
| 2 | R1 阅读器 + R4 队列/摘录 | `2.2.0`：正文进 App、读完不丢 |
| 3 | R2 划重点 + R3 聚类 v2 | `2.2.1`：多源事件 + 可定位要点 |
| 4 | S2 计划修订 + W1 工作区工具 | `2.3.0`：失败能换路、资料能搜 |
| 5 | A1 工作区主入口 + A2 工具化 | `3.0.0-alpha`：工作区成为组织方式 |
| 6–7 | A3 拆 AppModel + A4 契约单一源 | `3.0.0-beta`：可维护、可测试 |
| 8–9 | A5 数据层 + A6 记忆 + A7 周期 | `3.0.0-rc`：数据可迁移、记得住 |
| 10 | A8 回归 + 真机验收 + 出包 | `3.0.0`：完整签收 |

**需要你拍板的四件事**（拍板前不启动对应动作）：

1. **工作区当不当 3.0 主角？** 选「是」执行 A1（改 `RootView.swift:155-172` 的四入口结构，
   突破 2.1 方案「不改三个主入口」的约定）；选「否」则 A1 降级为首页组件，其余照做。
2. **A3/A4/A5 允许集中重构几周？** 默认 4 周（第 6–9 周）不新增功能；
   若要边交付边拆，需接受回归风险并延长到第 12 周。
3. **数据层上不上 SwiftData？** 上是 A5 的主路径；不上则改为「自建版本化迁移层 + 文件存储」，
   工作量相近但后续查询能力弱。
4. **工作区要不要云同步？** 涉及 README「隐私优先、不上传」的边界。
   选「否」则 A5 与 A7 全部按本机方案设计；选「是」需单独立项做端到端加密与账号体系。
