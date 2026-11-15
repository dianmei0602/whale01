# DamingAtlas Native

SwiftUI 原生骨架，目标 iOS 17+。

## 已建立

- 五个入口：卷首、时序、人物、典籍、甲申
- Typed `AppRoute` 与每 Tab 独立导航路径
- `ContentRepository` 从统一 `content-bundle.json` 读取人物、事件、章节、关系、地点、来源和奏疏
- 人物分册、帝王/名将/能臣/权臣入口
- 人物画像位与“无可靠传世画像”的明确标注
- 事件、章节、人物、奏疏、史料详情路由
- 全库搜索基础实现

## 生成工程

工程文件由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 生成，仓库不保存易冲突的 `project.pbxproj`：

```bash
brew install xcodegen
cd DamingAtlasNative
xcodegen generate
open DamingAtlas.xcodeproj
```

当前机器是 Windows，无法执行 Xcode 编译或 iOS Simulator 真机验收。请在 macOS 上生成工程并用 iPhone 16 Pro 模拟器验证。

## 自动构建 IPA

公开构建分支 `daming-atlas-build` 会通过 GitHub Actions 的 macOS runner 生成未签名真机 IPA，并发布到仓库 Releases。工作流位于根目录 `.github/workflows/build-daming-atlas-ipa.yml`。

未签名 IPA 不能直接安装到普通 iPhone。下载后使用 Sideloadly 或 AltStore，以自己的 Apple ID 重新签名；免费开发者签名通常 7 天到期。正式分发需要 Apple Developer 证书与匹配的 provisioning profile。

当前 IPA 内嵌完整 Web 原型，并将讯飞朗读通过局域网连接到开发电脑的 `http://192.168.110.10:4173`。真机测试前先运行 `大明王朝iOS/server.mjs`，让 iPhone 与电脑连接同一 Wi-Fi，并允许 Node.js 通过 Windows 专用网络防火墙。若电脑 IP 改变，需要同步修改 `DamingTTSServer`。

## 数据同步

内容包由内容构建器生成，不要直接编辑 `Resources/content-bundle.json`：

```powershell
cd ..\大明王朝文案
node .\build_content_bundle.js
node .\sync_native_resources.js
```

地图和画像资源尚未迁移到原生 target；原生地图是下一阶段工作，不在这一版骨架中伪装成已完成。
