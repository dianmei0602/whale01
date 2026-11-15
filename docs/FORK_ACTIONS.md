# 公开 fork 构建

私有仓库 `dianmei0602/ChineseChronicles` 保存开发源码。若私有仓库 Actions 因账单额度被阻断，可以把同一提交推到已存在的公开 fork：

```text
dianmei0602/whale01
```

只使用专用分支：

```text
chinese-chronicles-ci
```

公开 fork 的默认分支注册了两个通用工作流：

- `Chinese Chronicles Interaction Tests`
- `Chinese Chronicles Sideload`

它们通过 `source_ref` 输入明确 checkout 构建分支，并使用 checkout 后的真实
`HEAD` 生成构建身份，不把 fork 主分支的提交误写成 App 源码提交。

## 同步源码

```powershell
git push actions HEAD:chinese-chronicles-ci
```

`actions` remote 指向：

```text
https://github.com/dianmei0602/whale01.git
```

## 手动运行

在公开 fork 的 Actions 页面选择：

1. `Chinese Chronicles Interaction Tests`
2. `Chinese Chronicles Sideload`

每次运行时把 `source_ref` 填为：

```text
chinese-chronicles-ci
```

## 发布校验

公开 fork 的 workflow 定义来自 fork 主分支，而 IPA 源码来自专用构建分支。下载时必须分别核对：

```powershell
.\tools\publish_ipa.ps1 `
  -Repo dianmei0602/whale01 `
  -ArtifactBase ChineseChronicles-Sideload `
  -WorkflowName "Chinese Chronicles Sideload" `
  -RunId <run-id> `
  -ExpectedSourceSHA <app-source-sha> `
  -AllowForkedWorkflow
```

`-AllowForkedWorkflow` 只放宽“workflow 提交必须等于源码提交”，不会放宽产物校验。下载后仍会检查：

- 产物 `manifest.gitSHA` 是否等于 `ExpectedSourceSHA`
- IPA 文件 SHA256 是否等于 manifest
- 版本、Build、内容清单与资源哈希
- 是否嵌入长期密钥

私有仓库和公开 fork 都不应提交 `ipa-private.pem`。公开的 `.github/ipa-public.pem` 只用于加密产物，不能解密。
