ROUND 1
Seen in one second: 一部中国历史产品有四种完全不同的阅读入口。
Idea (one sentence): 将“多个政权在同一时间段内并存”从资料细节提升为首屏结构。
Live thing: 在年代线上定位 1127 年，同时看见北宋终结、南宋开始与金、西夏的并存。
Layout words by section: hero=statement / schemes=four-column gallery / recommendation=split conclusion.
Scores: design 8.4 · usability 8.2 · creativity 8.7 · content 8.8 → overall 8.4.
Caps applied: 产品界面片段是真实的 DOM 界面，不是灰色占位图；四个方案均使用同一份真实编年史资料。
Top three problems:
1. 桌面首屏只能看到手机预览的上半部分，四套方案的差异需要滚动后才能完整判断。修复：压缩页头纵向占用，但保留大标题作为四个方案的总命题。
2. “长河”和“天下”都以横向轨道呈现时间；两者需要更明确的职责区分。修复：将“长河”定位为阅读入口，把“天下”定位为对照工具，并在导航与首屏文案中直接说明。
3. “册页”与“夜读”的文字氛围较强，手机上会形成长阅读，但事件页的“返回年代”路径不够明确。修复：在进入具体设计的下一轮加入固定的年代上下文条。

ROUND 2
Seen in one second: 同一份历史资料可以按时间、卷册、关系或叙事组织。
Idea (one sentence): “并存”成为产品的主视觉，而不是详情页里的解释。
Live thing: 用同一条年代线与标记切换阅读对象。
Layout words by section: hero=two-column statement / schemes=four-up comparison / recommendation=split conclusion.
Scores: design 8.5 · usability 8.3 · creativity 8.8 · content 8.8 → overall 8.5.
Caps applied: none.
Top three problems:
1. 设计比较板高于一个手机屏幕；这符合比较页用途，但第一屏不会显示四部手机的全部内容。
2. 四个界面片段都使用底部三项导航；正式实现时只应让一个主动作突出，其他导航保持低对比。
3. 中文显示依赖系统宋体与苹方，与自动推荐字体不一致；这是明确的产品取舍。正式 SwiftUI 实现应使用系统中文宋体作为标题字体、苹方作为界面字体，避免引入网络字体。

## 结论

“长河”最适合成为主界面。它直接回答了编年史产品最独特的问题：哪些政权在同一时间存在。现有数据和 SwiftUI 时间轴实现都能支撑这个方向。

“册页”适合详情页，“天下”适合作为并立政权专题，“夜读”适合作为深色主题。四者不是互斥方案，推荐采用“一主三辅”的组合。
