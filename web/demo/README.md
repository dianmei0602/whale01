# 华章 iPhone HTML 演示

这是原生 iPhone App 交互与视觉方向的可运行原型。它不调用后端，也不需要安装第三方依赖。

## 运行

在仓库根目录启动本地静态服务器：

```powershell
python -m http.server 8765 --bind 127.0.0.1
```

打开：

```text
http://127.0.0.1:8765/web/demo/index.html
```

直接双击 `index.html` 会因浏览器限制 ES module 加载而无法启动。

## 可操作内容

- 长河：切换六个时代、移动年代尺、查看同时存在的政权和附近事件
- 卷目：按时代展开或折叠政权目录
- 并立：用年代步进或滑块比较政权存续区间
- 索引：检索政权、人物、都城、事件和摘要
- 详情：查看政权事实、事件解释、阅读提示与文献出处
- 夜读：在右上角切换浅色和深色阅读模式

## URL 参数

便于截图和验收，可以指定初始状态：

```text
?year=910#/river
?year=1127&theme=night#/atlas
#/dynasty/tang
#/event/jingkang
```

可用参数：

- `year`：任意历史年份，负数表示公元前
- `era`：`pre-qin`、`qin-han`、`wei-jin-nanbei`、`sui-tang`、`five-dynasties-song`、`yuan-ming-qing`
- `theme`：`light` 或 `night`

## 数据

`data.js` 由正式 App 的 `chronicles.v1.json` 生成：

```powershell
node tools/build_web_demo.mjs
node tools/build_web_demo.mjs --check
```

不要直接修改 `data.js`。史料更新应修改原生 App 的 JSON，然后重新生成演示数据。
