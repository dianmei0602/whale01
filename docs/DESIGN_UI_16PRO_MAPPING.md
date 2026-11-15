# iPhone 16 Pro 设计稿与 SwiftUI 映射

设计源：`design/ui-design-iphone16pro.html`

| 设计项 | SwiftUI 实现 |
|---|---|
| 402 × 874 pt 与系统安全区 | `RootView`、`AssistantView`、`TodayView` |
| 素瓷 / 夜墨语义色 | `Palette.swift`、`AppBackground.swift` |
| 完整钛合金角色 | `PetCharacterView.swift`、`PetCharacterCanvas.swift` |
| 九档表情与眼睛参数 | `PetMood.swift`、`PetCharacterView.swift` |
| 眨眼、视线跟随、动作 | `PetMotionEngine.swift`、`FaceTracker.swift` |
| 对话表情节拍 | `SpeechPerformance.swift`、`AssistantView.swift` |
| 底部入口和设置按钮 | `RootView.swift`、`SettingsSheet.swift` |
| Live Activity | `PetLiveActivity.swift`、`PetActivityController.swift` |
| 灵动岛三态 | `PetLiveActivity.swift` |
| 小组件 | `TodayWidget.swift` |
| 物理盒子 | `PhysicsBox.swift`、`PhysicsBoxView.swift` |

## 保留的设备能力边界

- 灵动岛不能运行 WebView、视频、Lottie 或持续 60 fps 自绘动画。
- Live Activity 的刷新时间由系统预算控制，只在状态变化时更新。
- App Group 需要付费开发者账号；免费签名使用明确的降级状态。
