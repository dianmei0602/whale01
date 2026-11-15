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

## 数据同步

内容包由内容构建器生成，不要直接编辑 `Resources/content-bundle.json`：

```powershell
cd ..\大明王朝文案
node .\build_content_bundle.js
node .\sync_native_resources.js
```

地图和画像资源尚未迁移到原生 target；原生地图是下一阶段工作，不在这一版骨架中伪装成已完成。
