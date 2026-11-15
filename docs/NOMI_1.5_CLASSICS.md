# Nomi 1.5 · 365 日古籍原文

日期：2026-11-15  
目标版本：`1.5 (19)`  
状态：Build 19 已构建并通过 IPA 校验，等待 iPhone 16 Pro 真机验收

## 构建结果

| 项目 | 当前值 |
|---|---|
| 功能提交 | `6cb866fd472d4178478fedddc4ce0d0690c6c94e` |
| GitHub Actions | #112，成功 |
| IPA 路径 | `C:\Users\Administrator\Desktop\Nomi-1.5-build19-final\artifact\Jinri-unsigned.ipa` |
| IPA 大小 | 11,792,968 bytes |
| SHA256 | `F3446EC8EC8588501C998E4E06E810B18F24266EAE67727A9EAC0AA9826C6E75` |

主 App、Widget、版本号、权限说明、Live Activity 和 `classical_quotes.json` 均已进入 IPA。

## 数据

- 365 条完整原文
- 13 部典籍
- 去除标点后严格为 15–30 个汉字
- 原文无重复
- App 离线读取，不依赖模型生成或运行时抓取

| 典籍 | 条数 |
|---|---:|
| 论语 | 28 |
| 孟子 | 45 |
| 老子 | 28 |
| 荀子 | 45 |
| 庄子 | 36 |
| 礼记 | 57 |
| 大学章句集注 | 11 |
| 中庸 | 24 |
| 菜根谭 | 24 |
| 朱子家训 | 8 |
| 颜氏家训 | 18 |
| 韩非子 | 36 |
| 世说新语 | 5 |

## 来源

- 原文库：`NiuTrans/Classical-Modern`
- 许可证：MIT
- 固定提交：`4e746ea9fa99c3c0d7051c45397330bef7b0962d`
- 每条保留书名、篇章、朝代、语料库路径和固定提交链接

其中：

- 65 条为此前人工挑选的 `curated-source-match`
- 300 条为完整句段筛选后的 `automated-source-match`
- 全部逐条检查汉字数量和固定版本原文包含关系
- 标点做可读性规范化，汉字序列保持与固定底本一致

## SwiftUI 接入

- 首页原大角色卡替换为“今日一句”古籍卡。
- 保留页眉 Nomi 头肩角色、设置入口和原有三主入口。
- 同一天固定一句。
- 最近 30 句不重复。
- “换一句”写入当日选择。
- 点击“古籍库”进入完整 365 句列表。
- 古籍库可按 13 部书筛选，点击任意原文将其设为今日一句。
- 每日选择使用新版 `v2` 历史键，不复用旧网络鼓励文案历史。

## 数据文件

- App 资源：`ios/App/Resources/classical_quotes.json`
- 校验脚本：`ios/tools/validate_classical_quotes.py`
- CI：在 Swift 编译前执行数据校验

## 本地验证

- 125 个 Swift 文件语法解析通过
- 185 项纯逻辑回归通过
- 365 条数据长度、去重、13 部书和来源字段校验通过
- Git whitespace 检查通过

## 真机待验证

- iPhone 16 Pro 上首页古籍卡和古籍库的字体、滚动、左边缘返回
- 大字号下卡片的按钮和引文布局
