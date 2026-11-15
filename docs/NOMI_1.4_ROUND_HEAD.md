# Nomi 1.4 圆形头部角色替换

日期：2026-11-14  
目标版本：`1.4 (17)`
状态：Build 17 已修复 Lottie 布局溢出，等待云端构建和 iPhone 16 Pro 真机验收

## Build 17 构建结果

| 项目 | 当前值 |
|---|---|
| 功能提交 | `4ed8f52ced01f37e59c098a563af16f39d040c82` |
| GitHub Actions | #109，成功 |
| IPA 路径 | `C:\Users\Administrator\Desktop\Nomi-1.4-build17\Jinri-unsigned.ipa` |
| IPA 大小 | 11,622,655 bytes |
| SHA256 | `EFB1466D1DDB878EEC0C78A4EF7AC19B2E919A649A88DFC8F79F75819FBBF49F` |

主 App 与 Widget 版本均为 `1.4 (17)`。

## Build 17 · Lottie 尺寸修复

Build 16 的实机截图显示首页角色被放大并裁切，只显示机身局部。原因是 `LottieAnimationView` 按动画原始 `512×512` 内在尺寸绘制，SwiftUI 外框没有约束到其绘制层。

Build 17 修复：

- 给 Lottie 播放器传入显式 `size`。
- 实现 `UIViewRepresentable.sizeThatFits`。
- 同步更新 UIView 的 frame、bounds 和布局。
- 开启 `clipsToBounds`、`layer.masksToBounds` 和 `maskAnimationToBounds`。
- SwiftUI 层再增加一次 `.clipped()` 防护。

显示尺寸仍保持 Build 16 的缩小值，首页主角色为 88pt。

## Build 16 构建结果

| 项目 | 当前值 |
|---|---|
| 功能提交 | `3ab8dfa4f5ffd27c6c02ff453f3e39c766c4d60b` |
| GitHub Actions | #108，成功 |
| IPA 路径 | `C:\Users\Administrator\Desktop\Nomi-1.4-build16\Jinri-unsigned.ipa` |
| IPA 大小 | 11,622,536 bytes |
| SHA256 | `B8CB909AF351A21E05106783CDC37D71ADBFE50264F831E16D47EC2A9779371A` |

IPA 内含主 App、Widget、Lottie 表情资源和 App Icon；主 App 与 Widget 版本均为 `1.4 (16)`。

## Build 15 构建结果

| 项目 | 当前值 |
|---|---|
| 功能提交 | `018cf3c356f0f262deb8051f47fc436ad2d141aa` |
| GitHub Actions | #107，成功 |
| IPA 路径 | `C:\Users\Administrator\Desktop\Nomi-1.4-build15\Jinri-unsigned.ipa` |
| IPA 大小 | 11,622,460 bytes |
| SHA256 | `3D2A9BC1038A974233A3D87AB530E2600C7EDF2CD13F0833FBD3517CA97FF60D` |

## Build 16 · 角色尺寸

新 Nomi 的全身体积比旧方脑袋角色更大，Build 15 中的显示尺寸显得过满。Build 16 统一缩小约 27%：

- 首页与对话主角色：`120pt → 88pt`。
- 首页角色外框：`126×174pt → 96×132pt`。
- 首页主卡高度：`184pt → 158pt`。
- 语音页角色：`154pt → 112pt`。
- 物理盒子角色：容器边长的 `36% → 27%`。
- 小号组件角色：`56pt → 42pt`。
- 中号组件角色：`68pt → 52pt`。
- 锁屏角色：`96pt → 72pt`。

拖动、点击、表情切换、呼吸、眨眼和越界回弹逻辑不变。

## 设计替换

App 中的方脑袋角色已替换为 `robot_expressions` 中的圆形头部 Nomi。保留白色机身、黑色面屏、蓝色眼睛和钛合金高光，同时移除旧角色在业务页面中的绘制。

替换范围：

- 首页、对话和悬浮角色。
- 语音助手全屏页。
- 物理盒子。
- 主屏小/中号组件。
- 锁屏 Live Activity 和灵动岛展开态。
- App 图标继续使用大笑表情的全身体验图。

## 动画资源

接入 13 个原生 Lottie 状态：

`idle / happy / laughing / thinking / surprised / excited / angry / sad / crying / scared / confused / sleepy / love`

每个 JSON：

- 画布 512×512。
- 24fps。
- 透明背景。
- 图片资源嵌入 JSON，无外部网络请求。

现有 Nomi 表情映射：

| 现有表情 | 新动画 |
|---|---|
| 平静 | idle |
| 开心 | happy |
| 大笑 | laughing |
| 好奇 / 思考 | thinking |
| 生气 | angry |
| 低落 / 叹气 | sad |
| 难过 | crying |
| 打盹 | sleepy |
| 吓一跳 | surprised |
| 无聊 | confused |
| 兴奋 / 跑步 | excited |

## 播放和性能

- App 使用 Airbnb Lottie iOS 4.5.x 原生播放。
- idle 循环，单次情绪动画播放一次。
- 页面离屏、切换主入口或 App 进入后台时暂停。
- 一次只保留一个当前播放器。
- 开启“减少动态效果”时改用透明静态海报。
- 静态 Lottie 资源不可用时自动回退到海报。

## WidgetKit 和 Live Activity

WidgetKit 不适合播放 Lottie，因此以下场景使用透明静态角色：

- 小号和中号主屏组件。
- 锁屏组件中的角色。
- Live Activity 的角色。
- 灵动岛展开态。

动画状态会映射到 idle、happy、thinking、excited、sleepy、sad 六张海报。

## 交互约束

- 点击 Nomi 仍只触发表情与肢体反馈，不跳转聊天。
- 拖动和越界回弹保持不变。
- 角色显示区域、输入栏与底部导航不重叠。
- `followFace` 现在通过角色整体轻微转向表达关注，因为新素材眼睛已经烘焙在动画画面中，不能单独位移像素。

## 资源来源

- Lottie：`D:\AI_work\AI_codex\robot_expressions\animations\lottie`
- 海报：`D:\AI_work\AI_codex\robot_expressions\animations\posters`
- App 资源：`ios/App/Resources/NomiAnimations`
- Widget 海报：`ios/App/WidgetExt/NomiWidget*.png`

## 验收清单

- [ ] 首页、对话和语音页全部显示圆形头部 Nomi。
- [ ] idle 动画包含呼吸和眨眼。
- [ ] 点击、高兴、思考、生气、难过等表情能正确切换。
- [ ] Nomi 可以拖动，越界回弹正常。
- [ ] 离开首页后动画暂停，返回后恢复。
- [ ] 开启减少动态效果后显示静态 Nomi。
- [ ] 主屏小组件显示新 Nomi，而不是方脑袋。
- [ ] 锁屏 Live Activity 和灵动岛显示新 Nomi。
- [ ] 音乐仍不占用灵动岛。
- [ ] App 图标仍为大笑的圆形头部 Nomi。

## 验证状态

- 13 个 Lottie JSON 已解析：全部为 512×512、24fps、3 个内嵌图片资源。
- 13 张 App 海报和 6 张 Widget 海报均为 512×512 RGBA。
- GitHub Actions #107 的 Lottie 依赖解析、逻辑回归、XcodeGen、Release 编译和 IPA 打包全部成功。
- IPA 内确认包含 13 个 Lottie JSON、13 张 App 海报和 6 张 Widget 海报。
- 主 App 和 Widget 版本均为 `1.4 (15)`。
- Build 16 已通过 GitHub Actions #108，主 App 和 Widget 版本均为 `1.4 (16)`。
- Build 17 已通过 GitHub Actions #109，并生成 Lottie 尺寸修复版 IPA。
- 真机验收尚未执行。
