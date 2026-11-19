# 工程复盘页：设计方向与验收记录

- 页面：`web/engineering-review/index.html`
- 方向：`product-performs`
- Seed：`1116773355`
- 完成日期：2026-11-19

## 设计决定

### Idea

在页面上，鲸鱼“听见→理解→执行→留痕”的真实工作轨迹成为可检查的界面片段，而不是用营销卡片概括功能。

### Live thing

“十二组 Skill，不越权一步”中的 Skill 选择器可以切换日程、出行、研究、行情、音乐、消息、记忆、健康、写作、技术、娱乐和通用能力。每一项即时显示真实工具数量和停止条件。

### 方向调整

- 首段从“窄列 + 大片留白”改成 5/7 分栏，保留安静语气，同时让页面在第二屏仍有完整信息。
- 截图画廊取消 sticky 标题，避免大标题在滚动时压过截图。
- 平板与手机上的四层执行图取消 sticky，按正常阅读顺序放在说明之前，消除文字被覆盖。
- 阅读截图完整展示；其余原生截图以同一高度的顶部裁切形成图集，保留真实状态而不把小字号硬缩到不可读。

## 图像

页面使用 6 张项目自有截图，没有外部图库素材：

- `app-home.png`
- `app-settings.png`
- `discovery-dark.jpg`
- `reader-view.png`
- `market-view.png`
- `task-records.png`

没有视频。仓库没有本轮功能的真实录屏，因此不拿无关素材冒充产品视频；唯一的持续运动是深色发现页截图的缓慢缩放。

## 浏览器检查

最终检查：

| 宽度 | 结果 |
| --- | --- |
| 1440 | 0 FAIL；1 WARN（没有视频，已说明原因） |
| 768 | 0 FAIL；0 WARN |
| 390 | 0 FAIL；0 WARN |

源码 `lint.mjs`：0 FAIL，0 WARN。

## 评审记录

ROUND 1

Seen in one second: 薄荷色执行面板与“鲸鱼 Agent 0.8.3 建造记录”。

Idea (one sentence): 让鲸鱼的真实执行轨迹和 Skill 边界成为页面本身。

Live thing: 切换 12 组 Skill，查看工具数量、路径和拒绝条件。

Layout words by section: hero=非对称分栏 / intro=双栏陈述 / stats=深色数据带 / process=图文双栏 / skills=索引与面板 / gallery=大图与错落图集 / timeline=两端列表 / lessons=交替长文 / FAQ=问答索引 / map=两端目录 / CTA=表单式收据。

Scores: design 7.4 · usability 7.2 · creativity 8.0 · content 8.3 → overall 7.71.

Caps applied: 移动端 Hero 中的执行片段被压成窄条；记录需遵守图片与半空屏规则。

Top three problems:

1. 390px Hero 的执行片段只占一个网格列，文字纵向断裂。
2. 平板过程章节的 sticky 图覆盖正文说明。
3. 多处滚动揭示使用透明隐藏，截图检查时产生大块空白。

ROUND 2

Seen in one second: 深色大标题、薄荷色执行片段、真实的 iPhone 工作流。

Idea (one sentence): 页面用同一个 Agent 闭环证明能力，而不是罗列“AI 功能”。

Live thing: Skill 索引即时切换工具集合与安全边界。

Layout words by section: hero=非对称分栏 / intro=双栏陈述 / stats=深色数据带 / process=图文双栏 / skills=索引与面板 / gallery=大图与错落图集 / timeline=两端列表 / lessons=交替长文 / FAQ=问答索引 / map=两端目录 / CTA=收据与行动。

Scores: design 8.3 · usability 8.6 · creativity 8.2 · content 9.0 → overall 8.51.

Caps applied: none.

Top three remaining problems:

1. 没有真实录屏；静态产品阅读是对的，但动态体验仍缺少视频证据。
2. 图片来自不同开发阶段，部分截图不是最终 0.8.3 界面。
3. 真机手势、朗读和复制反馈仍需要安装后人工确认，网页不能替代。
