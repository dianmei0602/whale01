# 华章 · ChineseChronicles

一个离线优先的中国朝代编年史 iPhone App。首版目标是先把时间、政权关系、关键事件和资料出处做准确，而不是让语言模型替用户“回忆历史”。

## 当前版本

- iOS 17+ / SwiftUI / XcodeGen
- 零第三方运行时依赖
- 23 个政权或时期条目
- 57 个事件档案
- 66 位人物
- 23 个历史地点
- 31 个制度与文明主题
- 19 个传统文献与研究参考
- 支持主线王朝、分裂时期、并立政权和争议纪年
- 总览、并排时间轴、本地检索、政权、事件、人物、地点与主题详情

当前内容是可审核的种子版，不是完整历史数据库。先秦年代和一些分期采用明确注明的通行框架，页面会保留“约数”“存在异说”等状态。

## 工程结构

```text
ios/
  ChineseChronicles/
    App/                App 入口
    Models/             历史日期、资料模型、检索与时间轴布局
    UI/                 SwiftUI 界面
    Resources/          编年史 JSON、内容清单、构建身份文件
    Assets.xcassets/    App 图标与启动色
  ChineseChroniclesTests/
  ChineseChroniclesUITests/
tools/
  validate_chronicles.mjs   资料完整性、引用和数量校验
  build_identity.py         生成非敏感构建身份
  verify_ipa.py             IPA 身份、内容和密钥检查
  publish_ipa.ps1           下载并核对侧载包
.github/workflows/          macOS 云编译、完整测试和侧载出包
web/demo/                   iPhone UI 的可交互 HTML 原型
```

## 资料校验

```powershell
node tools/validate_chronicles.mjs
node tools/validate_chronicles.mjs --check
```

第一条命令会在资料通过校验后更新 `content-manifest.v1.json`；第二条命令只做校验，与 CI 使用的门禁一致。

## 云编译

工程使用 XcodeGen，不提交 `.xcodeproj`。在 macOS 上：

```bash
brew install xcodegen
python3 tools/build_identity.py
cd ios
xcodegen generate
xcodebuild -project ChineseChronicles.xcodeproj \
  -scheme ChineseChronicles \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build-for-testing
```

Windows 上通过两个 GitHub Actions 工作流验证：

- `Push Quick Validation`：资料校验、Swift 编译和测试目标编译
- `iOS Manual Interaction Tests`：原生单测和 UI 用例
- `Chinese Chronicles Sideload`：生成无签名 IPA，供 AltStore / SideStore 用本人 Apple 账号重签

私有仓库遇到 Actions 账单限额时，使用公开 fork 的构建分支继续验证。具体流程见
[docs/FORK_ACTIONS.md](docs/FORK_ACTIONS.md)。

## 数据规则

1. 事件和政权必须有出处。
2. 不把模型记忆当成史料。
3. 有争议就标出，不把推定年份写成唯一答案。
4. 并存政权不能压成一条单线王朝。
5. 新增一批资料前先保留已审核快照，再扩充、合并和校验。

详细字段约定见 [docs/DATA_GUIDE.md](docs/DATA_GUIDE.md)。
具体的内容分层、扩写顺序和编辑标准见 [docs/CONTENT_ENRICHMENT.md](docs/CONTENT_ENRICHMENT.md)。

## HTML 交互演示

```powershell
python -m http.server 8765 --bind 127.0.0.1
```

打开 `http://127.0.0.1:8765/web/demo/index.html`。演示包含长河、卷目、并立、索引、朝代详情、事件详情与夜读模式，使用同一份编年史资料。

## 当前验证边界

Windows 本机已完成：

- JSON 结构与引用完整性检查
- 13 个 Swift 文件语法解析
- 4 个纯数据模型文件 `swiftc -typecheck`
- Info.plist、entitlements 和 asset catalog JSON 校验

Xcode 编译、原生单测、UI 测试和真机安装需要 GitHub macOS runner 或 Mac，不能在这台 Windows 机器上宣称已经通过。

