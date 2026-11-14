# 编年史资料指南

## 原则

编年史 App 的可信度来自资料结构和出处，而不是回答是否流畅。模型、检索和界面都必须读取同一份经过审核的数据。

当前数据位于：

`ios/ChineseChronicles/Resources/chronicles.v1.json`

修改后运行：

```powershell
node tools/validate_chronicles.mjs
```

## 主要字段

### HistoricalDate

```json
{
  "year": -221,
  "month": null,
  "day": null,
  "display": "前 221 年",
  "precision": "year"
}
```

- `year`：负数表示公元前，不能使用公元 0 年。
- `precision`：`exact`、`year`、`approximate`、`disputed`。
- `display`：用户实际看到的文字；不要把约数显示成精确年份。

### Dynasty / 时期

`role` 的取值：

- `mainline`：主线王朝。
- `divided`：分裂时期或由多个政权构成的阶段。
- `parallel`：与其他政权长期并立。
- `disputed`：传统纪年或考古对应存在明显争议。

时间轴会按起止年自动分配轨道，不要求人工把王朝排成一条队列。

### Event

每条事件必须有 `dynastyId` 和至少一个 `sourceIds`。如果资料对年份或解释有分歧，写入 `caveat`，界面会在详情页展示“阅读提示”。

### Source

来源分为：

- `primary`：传统文献。
- `reference`：研究参考或断代框架。

`citation` 应指向能复核的书名、篇名、卷次或报告名称；不要只写“网络资料”。

## 资料来源状态

当前先使用传统史书书目作为内容依据，并对先秦若干年代注明《夏商周断代工程 1996—2000 年阶段成果报告》。这不等于本版已经完成逐句校勘，也不能把书目名称冒充具体卷次证据。

下一批资料应按以下顺序补齐：

1. 从《史记》《汉书》《后汉书》等原典中增加可定位到篇章的事件。
2. 将涉及年代争议的条目同时登记至少两种观点。
3. 增加地图与人物前，先建立稳定 ID，避免只靠姓名和年份关联。
4. 对新增内容做一轮人工复核，再更新 `contentVersion`。

## 审核状态

建议后续给条目增加：

```json
{
  "reviewStatus": "reviewed",
  "reviewedBy": "editorial-seed",
  "reviewedAt": "2026-11-15"
}
```

但只有实际复核后才能写入，不能因为字段存在就自动声称已经校勘。

