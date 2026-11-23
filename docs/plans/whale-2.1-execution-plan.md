# 鲸鱼 2.1–2.3 升级方案：说快、读厚、连起来

- 日期：2026-11-22
- 基线：`2.0.4 (204.1)`，构建源码 `69298d4`；工作分支 `ui-sea-salt-0.8` 上已有 `594d825`
  （本地工作区、桌面组件、分享收件箱）
- 依据：`CHANGELOG.md`、`docs/logs/2026-11-21-v2.0.4-assistant-desktop.md`、
  `docs/plans/whale-2.0-execution-plan.md`，以及本次对 `ios/WhaleAgent` 的逐文件复核
- 性质：**方案，不含实现**。所有"现状"都点到文件行号，所有"改法"都不触碰
  README「产品边界」的六条。

---

## 0. 先说结论

2.0 已经把**骨架**做对了：计划器 → 工具循环 → 证据守卫 → 发送前审查，四段都在代码里，
不是 PPT。所以 2.1 不该再堆功能，而是补三个**结构性缺口**：

| 缺口 | 证据 | 用户感受 |
|---|---|---|
| 全链路非流式 | `stream: false` 出现在 `LocalAgentEngine.swift:573`、`AgentReasoningClient.swift:240`；主引擎 `max_tokens` 最高 4096（`LocalAgentEngine.swift:137-144`） | 一轮要等「规划 + 工具 + 合成」三次完整生成才看到第一个字 |
| 一次成型的计划，不会改 | `analyze()` 只跑一次（`AgentReasoningClient.swift:19`），工具失败只触发"修复措辞"，不触发"换路径" | 第一步查不到就整轮作废 |
| 正文不进 App | 资讯一律 `InAppSafari(url:)`（`DiscoverChannelPages.swift:470`、`:771`） | 列表有摘要，点进去就跳出鲸鱼，读完什么也没留下 |

**优先级判断**：流式 > 计划修订 > 阅读器。理由很实在——流式是一天能做完、所有回答都受益的
确定性收益；阅读器要动 4 个文件但用户每天都在读；计划修订收益大但容易把 2.0 刚稳住的
证据链搞乱，放最后。

---

## 1. 已核实基线（动手前请复核）

| 事实 | 位置 |
|---|---|
| 39 个工具 / 8 个技能域（travel、schedule、health、content、communication、music、memory、research） | `contracts/v1/tools.v1.json` |
| 单轮工具预算 = 6 批，超限回"达到预算、保留记录" | `LocalAgentEngine.swift:300` |
| 计划器置信度 < 0.45 或 general 时**放开全部工具** | `LocalAgentEngine.swift:623-633` |
| 任务状态单独作 system 注入，不随历史截断 | `LocalAgentEngine.swift:548-551` |
| 历史按 30 条裁剪，工具消息成对保留 | `LocalAgentEngine.swift:556`、`:740` |
| 情景记忆：120 条容量、180 天窗口、字面 bigram 余弦、取前 4 条 | `AgentMemoryStore.swift:21`、`:56-78` |
| 情景记忆会把**当时的模型回复**（最多 260 字）回灌进 prompt | `AgentMemoryStore.swift:76` |
| 双层校验：`RealDataGuard`（缺证据就重写）+ `review`（发送前审查） | `LocalAgentEngine.swift:396-456` |
| 聚类 = 标题前 4 个 token 建桶，≥2 条即成一簇，`count` 是"同 token 条目数" | `DiscoverV2.swift:102-124` |
| 阅读库只有 `SavedArticle` + `isReadLater: Bool`，上限 80 | `DiscoverV2.swift:4-24`、`:74` |
| 正文抽取能力已存在，但只被工具用：`WebContentExecutor` 仅被 `NativeToolRouter` 与 `MerchantPriceExecutor` 引用 | `Execution/WebContentExecutor.swift:8` |
| 有 `ModelRequestMetrics`（请求 id、耗时、usage），但只在内部记录 | `App/ModelRequestMetrics.swift` |
| 新工作区模型已落地（记录/网页/文件/图片/对话/阅读、项目、跟进、日复盘、专注模式），**还没有对应工具** | `Models/WhaleWorkspace.swift` |
| 98 项单元测试通过；Actions 走 `ios-sideload-ipa` + 模拟器/UI 回归 | `CHANGELOG.md:12`、`.github/workflows/` |

---

## 2. 2.1「说快、答准」

### S1 · 流式输出（P0，1 天，收益最大）

**做法**

1. `LocalAgentEngine.callModel` 增加 `stream: true` 分支，解析 SSE：`delta.content` 逐段回调，
   `delta.tool_calls` **只累积不渲染**（工具调用阶段本来就没有正文，不会闪空泡）。
2. 引擎仍是 actor，但对外加一个 `AsyncStream<AgentStreamEvent>`：
   `.text(片段)` / `.toolStarted(name)` / `.needConfirm(pending)` / `.finished(response)`。
3. `AppModel` 收到 `.text` 就追加到同一条消息的气泡（已有消息 id 复用，不要新建一行）。
4. 工具轮次（`advance` 返回 pending 那条路径）**保持非流式**——参数必须是完整 JSON，
   半截 JSON 没有任何用处。只有"最终合成"那次调用流式。
5. 失败重试：现在 `:618` 是 `sleep 700ms` 后整体重发。流式下要求"已经上屏的内容不清空"，
   重试只在**首字之前**触发；首字之后出错就保留半截 + 一条"没说完，点重试"。

**验收**
- 问"今天的 AI 新闻"：第一个字在 1.5s 内出现（现在是整段生成完才显示），全程可中止。
- 工具轮次没有出现半截 JSON 气泡。
- 弱网断在首字之后：保留已显示内容，出现重试。
- 单测：SSE 解析器（拆包、半包、`[DONE]`、错误帧）、"工具轮不流式"路径。

### S2 · 计划可在失败后修订（P1，1 天）

**做法**

- 新增 `AgentPlanRevision`（纯逻辑 + 一次轻量调用）：当某批工具结果 **全部失败**
  且 `analysis.tasks.count > 1` 时，调一次 `reasoning` 生成"替代路径"，注入为 system：
  "上一步失败的原因 + 可替代的工具/角度"。
- **每轮最多 1 次**，记在 `turn.revisions`；已用满就不再调，直接按现有逻辑如实说明。
- 不允许修订改变用户目标，也不允许把"换个工具试试"变成"编个结果"。

**验收**
- Steam 超时 → 自动改用 `search_web` 找同一榜单 → 回答带来源，并说明"原接口超时"。
- 修订次数超限后，回答里出现未完成步骤清单，不出现"已完成"。

**顺带（半天，成本极低）**：`relevantTools`（`:623-633`）按计划收窄时，**永远保留一组核心工具**
（`get_tech_news`、`get_stock_quote`、`search_web`、`list_calendar_events`、`get_current_location`）。
现在计划器一旦把"今天天气"判成 general 之外的窄技能，模型就看不到天气工具，
只能回"我没这个能力"——这是最不像"聪明"的一种失败。

### S3 · 工具预算按任务复杂度（P1，半天）

- `batchBudget` 从固定 6 改为 `min(10, max(3, analysis.tasks.count + 2))`，无计划时仍 6。
- 超限文案保留现有那句（`:304`），并在后面追加"剩余步骤：…"（从 `taskState.remaining` 取）。
- 记录每轮 `batches`、`calls`、`seconds`、`tokens` 到 `ModelRequestMetrics`，设置页
  「诊断」可见一行"上一轮：6 次调用 / 12.4s / 3.1k tokens"。

**验收**：单步任务不会因为预算放宽而多调工具（回归 3 个典型问法，调用次数不增加）。

### S4 · 等待有内容（P2，半天）

- 首次调用前先显示由 `analysis` 推出的"正在做什么"（读 `tasks[0]`），不显示裸 spinner。
- 超过 8s 追加一句"还在查，可以点停止"。
- 全部走 `InteractionV2` 已有状态机，不新增状态。

---

## 3. 2.2「读得厚」

### R1 · 原生阅读器（P0，2 天）

**做法**

1. 新增 `Reading/ArticleReader.swift`：`URLSession` 取 HTML → 复用 `WebContentExecutor` 的
   正文抽取思路（抽 `<article>`/最长 `<p>` 序列）→ 输出 `[ArticleParagraph]`。
   抽取失败**不降级成 Safari**，而是明确"这篇读不到正文，用原文打开"，给按钮。
2. `Reading/ArticleReaderView.swift`：原生排版（字号 3 档、行距、深色跟随主题）、
   顶部进度、底部"原文 / 划重点 / 摘录 / 收藏"。
3. 替换 `InAppSafari` 调用点（两处），保留 `InAppSafari` 给"打开原文"兜底。
4. 缓存：按 URL + 日期存磁盘（照 `DiscoverDiskCache` 的写法），离线可读最后 30 篇。

**验收**：量子位、游戏葡萄、BBC 中文、InfoQ 各 3 篇，抽取成功率 ≥ 80%；
失败时按钮可见且提示准确；断网能打开已缓存的文章。

### R2 · 划重点（P1，1 天）

- 阅读器内一次调用（复用 `AgentReasoningClient.chineseGuide` 的形态，新增
  `keyPoints(title:body:)`）：3 条要点 + 1 句"为什么重要" + 关键数字列表。
- 每条要点必须能在正文里定位到原句（存 `range`），点要点跳到那段并高亮。
- 正文少于 300 字不生成（短讯没有要点可划）。
- 失败/超时不显示入口，不显示空卡。

**验收**：抽查 5 篇，要点不含正文没有的数字；点击能定位；重复打开不重复调用。

### R3 · 事件聚类 v2（P1，1 天，纯逻辑）

现有实现的问题很具体：`buckets[token]` 会让一条新闻同时进 4 个簇，簇标题是个词（"苹果"）
而不是一件事，`count` 也不是"几家报道"。

**新算法**（`NewsTopicClusterer` 重写，接口不变，只加字段）：
1. 时间窗 36h（`publishedAt` 缺失的进 `undated` 桶，不参与聚合）。
2. 两两算标题相似度：去标点后的字 bigram Jaccard ≥ 0.42 **或**共享 ≥2 个非停用实体 token。
3. 并查集聚类，簇内 `source` 去重后 ≥2 才算"多源事件"。
4. 簇标题取"最短且包含最多实体的标题"，不再用 token。
5. 输出增加 `sources: [String]`、`firstAt: Date`、`latestAt: Date`、`isMultiSource: Bool`。

**验收**：给 10 组人工标注样本（同事件/不同事件各半），准确率 ≥ 8/10；
列表上"3 家 · 2 小时前"数字与簇内实际来源数一致。

### R4 · 阅读队列 + 摘录到工作区（P1，1 天）

- `SavedArticle` 增 `state: enum { later, reading, done }`、`progress: Double`、`excerptCount`；
  兼容旧数据（`isReadLater == true` → `.later`）。
- 阅读器记录滚动进度，回列表显示"读到 62%"。
- 「摘录」= 选中段落 → 写 `WorkspaceCapture(kind: .reading, sourceURL: 原文, body: 段落)`
  （2.0 刚落地的 `WhaleWorkspace` 正好接住，不用新建模型）。
- 库视图分三段：在读 / 待读 / 读完，支持按频道筛。

### R5 · 列表信息卡（P2，可选，半天）

- 每条从"标题 + 摘要"升级为**可折叠三行**：发生了什么 / 关键数字 / 谁受影响。
- 只对当前可见前 8 条按需生成，当天缓存；无 key 或无正文时退回现有两行，不显示空占位。
- 不做"利好/利空"判断，不做买卖建议（红线）。

---

## 4. 2.3「连起来」

| 项 | 做什么 | 依赖 | 验收 |
|---|---|---|---|
| W1 工作区工具化 | 新增 `search_workspace` / `save_capture` / `list_followups` / `add_followup`；写入走确认 | R4 | 问"我上周记的那个报价"能检索到；保存前有确认卡 |
| W2 每日复盘 | 用当天任务记录 + 阅读摘要生成 3 行复盘，可编辑；周日生成周报 | W1 | 没有记录的日子不生成空模板 |
| W3 关注词提醒 | 用户设 2–3 个词，本地匹配已抓取资讯，每天最多 3 条通知 | R3 | 通知里写明"本地匹配，非推送新闻" |
| W4 快捷指令 | 「问鲸鱼」「记一笔」两个 App Intent，结果写回 Workspace | W1 | 不打开 App 也能记，落库可见 |
| W5 组件 | 当前任务 + 待读数量（复用 `WhaleQuoteWidget` 的刷新链路） | R4 | 减少动态效果时不抖动 |

---

## 5. 明确不做

- **不做运行时多 Agent**（README 产品边界第一条）。计划/审查/合成是同一次任务的阶段，
  不是三个 Agent 互相开会。
- **不引入向量库或 Embedding**。本地词法检索 + 结构已经够用，加向量意味着上传内容或
  在设备上跑模型，隐私与耗电都不划算。真不够用再谈。
- **不接付费第三方数据源**（Sensor Tower、data.ai 类）。没有授权就不显示估算数字。
- **不改三个主入口、不改底部栏结构**。
- **不做"利好利空"、不做买卖建议**。

---

## 6. 交付门槛（沿用 2.0 规格）

- 新领域模型一律有单元测试；现有 98 项必须全绿。
- Actions 必须完成 app 与测试目标编译；UI 相关改动跑 `ios-ui-tests`。
- 动公开数据、EventKit、语音链路 → 模拟器回归 + 真机验收，缺一不算完成。
- 只有本轮 `tool.result.status == success` 才能说"已完成"。
- 侧载 IPA 记录版本、源码 SHA、IPA SHA256；含讯飞凭据的包不进 Git、不公开转发。

---

## 7. 排期与待决策

| 周 | 内容 | 产出 |
|---|---|---|
| 第 1 周 | S1 流式 + S3 预算 + S4 等待态 | `2.1.0`：首字 ≤1.5s、成本可见 |
| 第 2 周 | R1 阅读器 + R4 队列/摘录 | `2.2.0`：正文进 App、读完不丢 |
| 第 3 周 | R2 划重点 + R3 聚类 v2 | `2.2.1`：多源事件 + 可定位要点 |
| 第 4 周 | S2 计划修订 + W1 工作区工具 | `2.3.0`：失败能换路、资料能搜 |

**需要你拍板的四件事**：

1. 流式先做"文字答案"，工具参数仍非流式——接受吗？（不接受的话成本翻倍，要写增量 JSON 解析）
2. 计划修订要不要允许它**改变工具选择**（例如原计划用 `get_game_rank`，失败后改用
   `search_web`）？这会放宽"证据必须来自指定工具"的约束，`RealDataGuard` 要同步放宽。
3. 情景记忆里的"当时答复"要不要**停止回灌**？我建议停：那条答复本身可能不准，
   回灌等于把旧错误当事实。停掉后记忆只剩"用户说过什么"，上下文会变薄但更安全。
4. 关注词提醒要不要后台刷新？要的话得加 `BGAppRefreshTask`，耗电和审核说明都要提前想。
