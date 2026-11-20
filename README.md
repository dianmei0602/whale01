# 代号鲸鱼

鲸鱼是一个 iPhone 原生个人 Agent：DeepSeek 负责理解与规划，讯飞负责听写和朗读，Swift 原生工具负责读取真实数据或执行设备操作。

## 当前阶段

- 最新版本：`2.0.3 (203.1)`
- 构建源码：`5e23723`
- 单元测试：95 项全部通过
- 外观专项：[海盐、夜海、鎏金原位切换与首页复核通过](https://github.com/dianmei0602/whale01/actions/runs/44790194930)
- 侧载构建：[2.0.3 加密 IPA 构建通过](https://github.com/dianmei0602/whale01/actions/runs/44796942966)
- 当前阶段：2.0.3 真机外观验收

## 从这里开始

| 入口 | 用途 |
| --- | --- |
| [工程复盘 HTML](web/engineering-review/index.html) | 可视化查看 Agent、Skill、开发历程、经验与交付状态 |
| [2.0 执行规格](docs/plans/whale-2.0-execution-plan.md) | 能力 2.0、交互状态机和分阶段交付门槛 |
| [2.0 开发日志](docs/logs/2026-11-20-v2.0.0-interaction.md) | 本轮语音、助手、发现、待办与已知边界 |
| [2.0.1 外观配色](docs/logs/2026-11-20-v2.0.1-appearance-palettes.md) | 夜海、鎏金配色、对比度与截图证据 |
| [2.0.2 上下文与预览](docs/logs/2026-11-20-v2.0.2-context-preview.md) | 当前任务、首页主任务、统一操作预览和深色调整 |
| [2.0.3 外观一致性](docs/logs/2026-11-21-v2.0.3-appearance-consistency.md) | 真实配色预览、切换刷新和三主题截图复核 |
| [开发日志](docs/logs/2026-11-19-v0.8.3-handoff.md) | 查看 0.8.3 的完整变更、测试与已知边界 |
| [文件与目录索引](docs/README.md) | 按产品、设计、工程、质量、证据归类仓库内容 |
| [变更记录](CHANGELOG.md) | 查看版本级变化 |
| [执行看板](00_执行看板.md) | 查看历史里程碑与当前证据 |

## 工程入口

| 路径 | 内容 |
| --- | --- |
| `ios/WhaleAgent` | iOS 原生 App |
| `ios/WhaleAgentTests` | 单元测试 |
| `ios/WhaleAgentUITests` | UI 与导航回归 |
| `backend` | 可选会话后端与契约测试 |
| `contracts` | Tool、事件和统一输入契约 |
| `tools` | IPA 校验、讯飞注入、构建与发布工具 |
| `.github/workflows` | GitHub Actions 构建、Pages 与回归流程 |

## 安装包

含讯飞凭据的 2.0.3 IPA 只保存在本机安装目录，不进入 Git，也不得公开转发：

`E:\AI_work\AI_codex\代号鲸鱼001\代号鲸鱼001_2026-11-14\代号鲸鱼001\安装文件\WhaleAgent-Sideload-2.0.3-XFYUN.ipa`

当前 SHA256：

`c11f957f222575f16941b4b6e895760d460249672e5f1b4617c88143903708dc`

## 产品边界

- 一个 Agent，不做运行时多 Agent。
- Skill 是能力分组和工具边界，不直接执行设备操作。
- 会写入提醒、日历、自选或记忆的操作必须经过确认或明确授权。
- 外部搜索、行情、新闻和价格必须说明来源；没有取得数据时不编造。
- 打开地图、网易云或消息编辑器只表示已交接，不等于已到达、已播放或已发送。
