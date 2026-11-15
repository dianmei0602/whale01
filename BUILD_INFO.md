# 山河战纪 · iOS 构建分支

- 应用名：山河战纪（com.shanhezhanji.app）
- 版本：2.2.0 (22)
- 内容：120 场战役 / 40 名将 / 20 势力 / 34 关系 / 20 场推演 / 官方标准地图 GS(2022)4307
- 本分支仅用于在 macOS GitHub Actions 上构建**未签名 IPA**，供真机侧载验证；主开发代码在私有仓库。

## 使用

1. 推送本分支（或手动 workflow_dispatch）触发 `build-ipa`。
2. 在 Actions 运行页下载 artifact `ShanheZhanyi-unsigned-ipa`。
3. 解压得到 `ShanheZhanyi-unsigned.ipa`，用 Sideloadly / AltStore / SideStore 以 Apple ID 重签安装到 iPhone（iOS 15+）。
   - 免费 Apple ID：7 天有效，到期重签；需在 iPhone 设置 → 通用 → VPN与设备管理 中信任开发者。
   - 若已有付费开发者账号，可自行用对应证书重签。

## 说明

- 未签名 IPA 不含 provisioning profile，不能直接双击安装；必须侧载重签。
- 应用全离线，无网络请求；WebView 资源已随包（ios/App/App/public）。
