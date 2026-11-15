# 今日 · iOS M0（真正可安装的原生版）

一个只出现在锁屏和主屏上的手机助理。这是 **M0**：目标不是功能全，而是**让你手机上真的出现一个原生 App 图标，点开能用真天气**。

---

## ✅ 验证状态

上一版我说"代码没编译过"。这一版不一样：我在本机装了 **Swift 6.4.2 for Windows**，能真的调编译器了。

| 层 | 文件 | 怎么验的 | 结果 |
|---|---|---|---|
| **逻辑** | RulesEngine · AppState · DayCard · Weather · WeatherService | `swiftc -typecheck`（Swift 5 模式，真编译） | ✅ **通过** |
| **UI** | JinriApp · TodayView · CardRow · Palette | 只能 `swiftc -parse`（SwiftUI 是 Apple 私有框架，Windows 没有） | ✅ 语法通过，**未类型检查** |
| **工程** | project.yml · ios.yml · Assets | YAML 解析 + 路径/资源一致性校验 | ✅ 通过 |

**剩下的风险只集中在 SwiftUI 那 4 个文件里。** 都是标准 `VStack` / `Text` / modifier 用法，但修饰符签名我若记错一个，还是会挂。

### 为此做的一处结构调整

`AppState` 从 Combine 换成了 iOS 17 的 `@Observable`。

不是为了追新——是因为 **Combine 在非 Apple 平台不存在**，换掉之后这一层才能被真编译。顺带让逻辑层彻底不依赖 UI：`DayCard` 里的颜色改成语义枚举 `CardTint`，映射放到 `Palette.swift`。

---

## 这一版有什么

| 有 | 没有（后续里程碑） |
|---|---|
| 原生 SwiftUI 今日页 | 提醒事项（M2） |
| 真天气（Open-Meteo） | 健康数据（M3） |
| 空气质量规则 | HomeKit（M4） |
| 规则引擎（6 条，纯函数） | Widget / 锁屏组件（M5） |
| 左滑划掉、右滑完成 | 设置页、城市切换 |
| App 图标 | 推送通知 |

城市写死在 `WeatherService.swift` 的 `latitude/longitude`（当前上海）。改一行即可。

---

## 安装路线：三条，先选一条

iOS 上任何 App 都必须被 Apple 签名，**没有例外**。

| 路线 | 成本 | 限制 | 适合 |
|---|---|---|---|
| **A. 免费签名（AltStore）** | 0 元 | **每 7 天重签**，最多 3 个 App | 自己先用 |
| **B. TestFlight** | $99/年 | 90 天有效，可邀请别人 | 自己 + 家人朋友 |
| **C. App Store** | $99/年 | 需要审核 | 公开上架 |

**A 和 B 的第一步完全一样**：都是先构建出 IPA。下面是 A 的完整流程。

---

## 第 1 步：把代码推上 GitHub

```bash
cd ios-app
git init
git add .
git commit -m "M0"
git branch -M main
git remote add origin https://github.com/你的用户名/jinri-ios.git
git push -u origin main
```

没有仓库就在 GitHub 网页上新建一个空仓库（**不要**勾选 README）。

> 公开仓库 Actions 免费不限时长；私有仓库每月有免费额度，一次构建约 4 分钟，也够用。

## 第 2 步：等它自动构建

推送后打开仓库的 **Actions** 标签，会看到 `build-ipa` 在跑（约 3–5 分钟）。

跑完在页面底部下载 **Jinri-unsigned** 这个 artifact，解压得到 `Jinri-unsigned.ipa`。

如果构建失败：点开红色那一步，把报错贴给我。

## 第 3 步：用 AltStore 装到 iPhone

Windows 上：

1. 装 **iTunes**（Apple 官网版）和 **iCloud**（Microsoft Store 版）
2. 从 [altstore.io](https://altstore.io/) 下载安装 **AltServer for Windows**
3. iPhone 用数据线连电脑，**信任这台电脑**
4. 托盘里 AltServer → `Install AltStore` → 选你的 iPhone → 输入 **Apple ID 和密码**
5. 手机上：设置 → 通用 → VPN与设备管理 → 信任你的开发者证书
6. 把 `Jinri-unsigned.ipa` 传到手机（AirDrop / iCloud Drive / 微信文件传输）
7. 打开 AltStore → My Apps → 左上角 `+` → 选那个 IPA

装好后桌面出现蓝底白太阳的「今日」。点开：**原生 App，全屏，没有地址栏。**

## 第 4 步：每 7 天续签

免费 Apple ID 签的 App **7 天后会打不开**。

- 让 AltServer 在电脑上后台运行，手机和电脑连同一个 WiFi
- AltStore 会在后台自动续签（通常在你睡觉时）
- 不放心就每周手动打开一次 AltStore 点 Refresh

**嫌麻烦的那一天，就是该考虑 $99 的时候。**

---

## 本地构建（如果你以后有 Mac）

```bash
brew install xcodegen
cd ios
xcodegen generate
open Jinri.xcodeproj
```

Xcode 里选自己的真机，配置签名 Team，直接 Run。

---

## 代码结构

```
ios-app/
├─ .github/workflows/ios.yml    # 云端构建出 IPA
└─ ios/
   ├─ project.yml               # XcodeGen 工程定义（不提交 .xcodeproj）
   └─ App/
      ├─ Sources/
      │  ├─ JinriApp.swift
      │  ├─ Models/  DayCard.swift  Weather.swift
      │  ├─ Core/    RulesEngine.swift  AppState.swift
      │  ├─ Services/ WeatherService.swift
      │  └─ UI/      TodayView.swift  CardRow.swift
      └─ Resources/Assets.xcassets/AppIcon
```

**为什么用 XcodeGen 而不是提交 `.xcodeproj`**：`.xcodeproj` 是二进制式工程文件，多人改必冲突，而且我这边没法生成合法的它。`project.yml` 是纯文本，Actions 里一条命令生成。

## 规则引擎

`RulesEngine.cards(for:)` 是纯函数：输入状态，输出卡片。不碰网络、不碰 UI，所以能单测（M1 加测试目标）。

| 规则 | 触发 |
|---|---|
| R13 待办 | 有未完成待办 |
| R10 睡前 | 距就寝 ≤ 60 分钟 |
| R01 带伞 | 未来 12 小时降水概率 ≥ 50% |
| R03 空气 | PM2.5 > 75 |
| R02 保暖 | 比昨天低 ≥ 6°，或最低 < 5° |
| R06 运动窗口 | 今天剩余时段里连续 2 小时温度 10–28°、降水 < 30%、空气达标 |

最多 4 张，按 `rank` 排序截断。

## 已知缺口

1. **待办数量是 0**：M0 没接 EventKit，所以那张卡不会出现
2. **没有设置页**：城市、就寝时间写死
3. **没有 Widget**：M5
4. **代码未编译验证**（见开头）
