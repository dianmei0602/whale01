/* 旧版深读文档构建器。保留供迁移比对；不再向 index.html 注入 DEEP。
   运行：node build.js
   输入：content/*.json
   输出：../大明王朝·深度文案集.md、../大明王朝iOS/index.html（替换标记块） */
const fs = require('fs');
const path = require('path');

const base = __dirname;
const root = path.dirname(base);
const read = f => JSON.parse(fs.readFileSync(path.join(base, 'content', f), 'utf8'));

const history = read('history.json');
const generals = read('bios_generals.json').people;
const others = read('bios_others.json').people;
const allBios = [...generals, ...others];
const bios = Object.fromEntries(allBios.map(p => [p.id, p]));

/* ---------- 一、汇编 Markdown 文档 ---------- */
const L = [];
L.push('# 《大明王朝》深度文案集');
L.push('');
L.push('> 版本 v2.0　｜　配套《大明王朝App企划案 v1.0》与 iOS 交互原型');
L.push('> ');
L.push('> **边界说明**：事件年份、官职、战役、结局依《明史》《明实录》及主流研究核对；「自述」为第一人称文学重构，用于呈现人物对自身处境的理解，不是史料引文；「成长历程」「身后」「结构性规律」属叙事设计与史识分析，不是史论定谳。');
L.push('> ');
L.push('> **读法**：卷上讲三条线如何互相加压，卷中讲五幕各自的转折与代价，卷下是三十一个人各自的一生。三卷互文——任何一个人的遭遇，都能在卷上找到制度性的解释。');
L.push('');
L.push('---');
L.push('');
L.push('## 卷上 · 历史脉络');
L.push('');
L.push('### 总论');
L.push('');
L.push(history.intro);
L.push('');
L.push('### 三条线的演化');
L.push('');
for (const t of history.threads) {
  L.push(`#### ${t.name}`);
  L.push('');
  L.push(t.logic);
  L.push('');
  L.push('**分期**');
  L.push('');
  for (const s of t.stages) L.push(`- **${s.era}　${s.label}**　${s.text}`);
  L.push('');
  L.push(`**跨线传导**　${t.cross}`);
  L.push('');
}
L.push('### 五项制度：它们原本要解决什么，后来长成了什么');
L.push('');
for (const [i, ins] of history.institutions.entries()) {
  L.push(`#### ${i + 1}. ${ins.name}`);
  L.push('');
  L.push(ins.text);
  L.push('');
}
L.push('### 结构性规律');
L.push('');
history.laws.forEach((x, i) => L.push(`${i + 1}. ${x}`));
L.push('');
L.push('---');
L.push('');
L.push('## 卷中 · 五幕深描');
L.push('');
for (const a of history.acts) {
  L.push(`### 第${['一', '二', '三', '四', '五'][a.no - 1]}幕　${a.title}（${a.years}）`);
  L.push('');
  L.push('**开场**');
  L.push('');
  L.push(a.opening);
  L.push('');
  L.push('**叙事节拍**');
  L.push('');
  for (const b of a.beats) L.push(`- **${b.year}　${b.title}**　${b.text}`);
  L.push('');
  L.push('**转折**');
  L.push('');
  L.push(a.turning);
  L.push('');
  L.push('**代价**');
  L.push('');
  L.push(a.cost);
  L.push('');
  L.push(`> 连向下一幕：${a.hook}`);
  L.push('');
}
L.push('---');
L.push('');
L.push('## 卷下 · 人物自传');
L.push('');

function writeBios(title, intro, list) {
  L.push(`### ${title}`);
  L.push('');
  L.push(intro);
  L.push('');
  for (const p of list) {
    L.push(`#### ${p.name}　｜　${p.arc}`);
    L.push('');
    L.push(`*三线定位：${p.thread}*`);
    L.push('');
    L.push('**自述（文学重构）**');
    L.push('');
    L.push(`> ${p.memoir}`);
    L.push('');
    L.push('**成长历程**');
    L.push('');
    for (const s of p.stages) L.push(`**${s.year}　${s.title}**　${s.text}`, '');
    L.push('**生平年表**');
    L.push('');
    for (const [y, e] of p.timeline) L.push(`- ${y}　${e}`);
    L.push('');
    L.push(`**身后**　${p.legacy}`);
    L.push('');
  }
}
writeBios('一、名将录（十二人）', '十二份战功与结局。合起来读，是一部「武将如何被自己人消耗」的制度史。', generals);
writeBios('二、奸臣 · 权阉录（九人）', '九份权力与依赖。他们不是孤立的坏人，而是皇权在不同处境下伸出去的手。', others.slice(0, 9));
writeBios('三、能臣录（十人）', '十份改革与反噬。知道问题在哪、也知道动了谁的利益，更知道自己走后会怎样。', others.slice(9));
L.push('---');
L.push('');
L.push('## 附：文案使用建议');
L.push('');
L.push('- **剧情页**：卷中的「开场 / 叙事节拍 / 转折 / 代价」可直接拆成幕内章节，节拍即页。');
L.push('- **人物页**：「自述」置于档案首屏作情绪入口，「成长历程」按年份做纵向时间条，「生平年表」做可点跳转节点。');
L.push('- **时间轴**：卷上「跨线传导」是交错节点三视角章节的文案底稿。');
L.push('- **史料标注**：涉及争议处（如徐达赐蒸鹅、袁崇焕通敌案、严世蕃通倭罪名）在 App 内需以「史载 / 存疑」标签区分。');
L.push('');

const md = L.join('\n');
const mdPath = path.join(root, '大明王朝·深度文案集.md');
fs.writeFileSync(mdPath, md, 'utf8');

/* ---------- 二、注入 iOS 原型 ---------- */
const htmlPath = path.join(root, '大明王朝iOS', 'index.html');
let html = fs.readFileSync(htmlPath, 'utf8');
const START = '/*DEEP_DATA_START*/';
const END = '/*DEEP_DATA_END*/';
if (!html.includes(START) || !html.includes(END)) {
  throw new Error('index.html 缺少 DEEP_DATA 标记块，请先添加');
}
const payload = { history, bios };
const block = `${START}\nconst DEEP = ${JSON.stringify(payload)};\n${END}`;
const a = html.indexOf(START), b = html.indexOf(END);
if (a < 0 || b < 0 || b < a) throw new Error('DEEP_DATA 标记块顺序异常');
html = html.slice(0, a) + block + html.slice(b + END.length);
fs.writeFileSync(htmlPath, html, 'utf8');

console.log('文档：', mdPath, '字数', md.length);
console.log('注入：', htmlPath, 'DEEP 字节', Buffer.byteLength(JSON.stringify(payload)));
console.log('人物数', allBios.length, '｜ 幕数', history.acts.length, '｜ 三线', history.threads.length, '｜ 制度', history.institutions.length, '｜ 规律', history.laws.length);
