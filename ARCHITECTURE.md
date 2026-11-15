# 《大明王朝》内容与客户端架构

## 当前阶段

高保真 Web 原型已完成当前 P0/P1 可视化验收，并建立 SwiftUI 源码骨架。Windows 环境无法执行 Xcode 编译和 iOS Simulator 验收，原生三线时间带、章节矩阵与事件因果页仍待迁移。

## 唯一内容源

原始数据位于 `大明王朝文案/content/`：

- `roster.json`：人物 ID 与阵营
- `batch/*.json`：人物档案和事件
- `published/*.json`：发布前校订事件
- `bios_*.json`：核心人物详传
- `history.json`：三线、制度与五幕长文
- `places.json`：结构化地点与关键词
- `sources.json`：史料书目
- `memorials.json`：奏疏馆目录与原文状态
- `published/portraits.json`：人物画像与授权状态
- `schema.json`：内容契约说明

不要直接修改生成文件。

## 构建顺序

```text
content sources
  ↓
build_content_bundle.js
  ↓
content-bundle.json + content-bundle.js
  ├─ iOS HTML prototype
  └─ sync_panorama_from_bundle.js → panorama HTML
```

完整构建命令：

```powershell
cd D:\AI_work\workbuddy\大明王朝\大明王朝文案
node .\build_all.js
```

兼容入口 `build_people_index.js` 和 `build_panorama.js` 都会调用唯一构建器。`legacy_*` 文件只供迁移比对，不用于发布。

## 内容约定

- 事件地点使用 `placeRefs`，关键词匹配必须保留 `inferred` 状态。
- 时间使用 `time.precision`，不得把只到月份的日期显示为精确日期。
- 关系使用独立 `Relation`，并保留证据事件和 `reviewStatus`。
- 第一人称自述标记为 `literaryReconstruction`。
- 史料目前到“书目级”，卷次、篇目和页码通过 `sourceRefs[].locator` 继续补齐。
- 没有可靠传世画像的人物显示“档案形象”，不得冒充历史肖像。

## 客户端信息架构

```text
卷首
时序
  事件航路
  三线压力
    五幕同步时间带
    章节 × 三线矩阵
    事件因果三栏
  历史地图
人物
  帝王世系
  名将 / 权臣阉党 / 能臣
  全部人物
典籍
  奏疏
  长文
  史料出处
甲申
```

## 原生工程目标

```text
App
Navigation（Typed Route / NavigationPath）
Domain（Person / Event / Chapter / Place / Relation / Source）
Data（ContentRepository / MapRepository）
Features（Home / Timeline / People / Map / Event / Dossier / Library / Choice）
DesignSystem
Services（Search / Bookmark / ReadingProgress / DeepLink）
Resources（content-bundle.json / map data / portraits）
Tests
```

原生导航只能保存路由和对象 ID，不能复制 Web 原型的 `{title,html}` 详情栈。

## 可视化回归

三线视图的数据规则是“事件唯一归属主章节”，因果前因只能来自同一压力线且时间严格早于当前事件。手机端先读“本年主线 → 三线状态 → 近十年走势”，294 年全景曲线折叠为次级视图；0—100 压力指数明确标为叙事阅读辅助，不作为原始统计。iPhone 16 Pro 逻辑视口为 `402×874`，因果三栏改为纵向三阶段，以免每栏被压到约 110px。

```powershell
cd D:\AI_work\workbuddy\大明王朝\大明王朝iOS
node .\scripts\three-line-regression.mjs
```

该脚本检查五幕键、1449 年全部同步事件、20 章矩阵标题与触控尺寸、全部 238 个事件的前因方向与压力线关联，并输出截图和 `output/playwright/iphone16pro/three-line-regression.json`。

## 声音与朗读

- 背景音乐为 Web Audio 实时合成的原创古琴风格配乐《松风入卷》，不是历史古琴录音，也不依赖外部音频站点。
- 朗读由 `大明王朝iOS/audio-experience.js` 提取当前页面正文。生产路径调用本地 `server.mjs`，由服务端使用讯飞 WebAPI 签名，浏览器端不能接触 `XFYUN_API_SECRET`。
- 未配置讯飞凭据、直接以 `file:` 打开或服务不可用时，明确降级为设备系统中文语音。

配置与启动：

```powershell
cd D:\AI_work\workbuddy\大明王朝\大明王朝iOS
Copy-Item .env.example .env
# 在 .env 填写 XFYUN_APP_ID、XFYUN_API_KEY、XFYUN_API_SECRET
node .\server.mjs
```

打开 `http://127.0.0.1:4173`。音频回归命令：

```powershell
node .\scripts\audio-experience-regression.mjs
```
