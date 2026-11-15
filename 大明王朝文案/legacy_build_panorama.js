/* 旧版全景构建器。保留供迁移比对，不再重新拼装独立数据。
   运行：node build_panorama.js
   输出：../大明王朝·全景大纲.md、../大明王朝全景/index.html（替换数据标记块） */
const fs = require('fs');
const path = require('path');

const base = __dirname;
const root = path.dirname(base);
const cdir = path.join(base, 'content');
const bdir = path.join(cdir, 'batch');
const read = f => JSON.parse(fs.readFileSync(f, 'utf8'));

const roster = read(path.join(cdir, 'roster.json'));
const chapters = read(path.join(cdir, 'chapters.json')).chapters;
const deepBios = [
  ...read(path.join(cdir, 'bios_generals.json')).people,
  ...read(path.join(cdir, 'bios_others.json')).people
];
const deepMap = new Map(deepBios.map(b => [b.id, b]));
const supplementPath = path.join(cdir, 'bios_supplement.json');
const supplementBios = fs.existsSync(supplementPath) ? read(supplementPath).people : [];
const supplementMap = new Map(supplementBios.map(b => [b.id, b]));

/* ---------- 一、收集批次数据 ---------- */
const files = fs.readdirSync(bdir).filter(f => f.endsWith('.json')).sort();
let events = [], extra = new Map();
for (const f of files) {
  const j = read(path.join(bdir, f));
  if (Array.isArray(j.events)) events.push(...j.events.map(e => ({ ...e, _src: f })));
  if (Array.isArray(j.people)) for (const p of j.people) extra.set(p.id, { ...p, _src: f });
}

/* ---------- 二、校验 ---------- */
const problems = [];
const idSet = new Set(roster.people.map(p => p.id));
const seenE = new Set();
for (const e of events) {
  if (!e.id || seenE.has(e.id)) problems.push('事件 id 重复或缺失：' + e.id);
  seenE.add(e.id);
  if (!roster.cats.includes(e.cat)) problems.push('事件类别非法：' + e.id + ' ' + e.cat);
  if (!Number.isInteger(e.year) || e.year < 1351 || e.year > 1662) problems.push('事件年份越界：' + e.id);
  if (!Array.isArray(e.people)) e.people = [];
  for (const pid of e.people) if (!idSet.has(pid)) problems.push('事件 ' + e.id + ' 引用未登记人物：' + pid);
  for (const t of e.threads || []) if (!roster.threads.includes(t)) problems.push('事件 ' + e.id + ' 线索非法：' + t);
  if (!e.text) problems.push('事件 ' + e.id + ' 缺正文');
}
for (const [pid, p] of extra) {
  if (!idSet.has(pid)) problems.push('档案 id 未登记：' + pid);
  for (const r of p.related || []) if (!idSet.has(r)) problems.push('档案 ' + pid + ' 关系引用非法：' + r);
}
const missingArchive = roster.people.filter(p => !p.existing && !extra.has(p.id)).map(p => p.id);
if (missingArchive.length) problems.push('缺档案人物：' + missingArchive.join('、'));

/* ---------- 三、合成人物（roster 为骨架，批次档案覆写，31 人复用深度自传） ---------- */
const people = roster.people.map(r => {
  const x = extra.get(r.id) || {};
  const d = deepMap.get(r.id) || null;
  const extraStory = supplementMap.get(r.id) || null;
  const bioFromStages = d ? d.stages.map(s => s.text).join('').slice(0, 360) : '';
  const o = {
    id: r.id,
    name: r.name,
    side: r.side,
    span: r.span,
    brief: r.brief,
    existing: !!r.existing,
    years: x.years || (d ? d.stages[0].year + '—' + r.span[1] : r.span[0] + '—' + r.span[1]),
    alias: x.alias || '',
    role: x.role || r.brief,
    arc: x.arc || (d ? d.arc : r.brief),
    bio: x.bio || bioFromStages || r.brief,
    deeds: x.deeds || (d ? d.timeline : []),
    end: x.end || r.brief,
    note: x.note || (d ? d.legacy : ''),
    threads: x.threads || [],
    related: x.related || []
  };
  if (d) {
    o.memoir = d.memoir;
    o.stages = d.stages;
    o.legacy = d.legacy;
    o.threadLabel = d.thread || '';
  } else if (extraStory?.stages?.length) {
    o.stages = extraStory.stages;
  }
  return o;
});
const peopleMap = new Map(people.map(p => [p.id, p]));

/* 事件与人物互建索引 */
events.sort((a, b) => a.year - b.year || a.id.localeCompare(b.id));
for (const e of events) { e._src = undefined; delete e._src; }
const eventsOfPerson = new Map();
for (const e of events) for (const pid of e.people) {
  if (!eventsOfPerson.has(pid)) eventsOfPerson.set(pid, []);
  eventsOfPerson.get(pid).push(e.id);
}
for (const p of people) p.eventIds = eventsOfPerson.get(p.id) || [];

/* 深度自传的原有 schema 不含关系字段；按共同参与事件补足可核验的人物关系。 */
for (const p of people) {
  if ((p.related || []).length) continue;
  const linked = new Map();
  for (const eid of p.eventIds) {
    const event = events.find(item => item.id === eid);
    for (const pid of event?.people || []) {
      if (pid === p.id || !peopleMap.has(pid)) continue;
      linked.set(pid, (linked.get(pid) || 0) + 1);
    }
  }
  p.related = [...linked.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, 8)
    .map(([pid]) => pid);
}
const relatedFallback = {
  muying: ['zhu_yuanzhang', 'ma_huanghou', 'lanyu'],
  zhouyanru: ['zhu_youjian', 'wentiren', 'yang_sichang'],
  shenshixing: ['zhu_yijun', 'zhangjuzheng', 'wang_xijue', 'gaogong']
};
for (const p of people) {
  if ((p.related || []).length) continue;
  p.related = (relatedFallback[p.id] || []).filter(pid => peopleMap.has(pid));
}

/* ---------- 四、汇编《大明王朝·全景大纲》 ---------- */
const L = [];
L.push('# 《大明王朝》全景大纲');
L.push('');
L.push('> 版本 v3.0　｜　《明朝那些事儿》式分卷叙事 ＋ 全事件年表 ＋ 全人物索引');
L.push('> ');
L.push('> 配套：《大明王朝App企划案 v1.0》《大明王朝·深度文案集 v2.0》、iOS 交互原型、全景时序可视化页。');
L.push('> ');
L.push('> **读法**：卷章是叙事主线，附录一是事件年表，附录二是人物索引。三者同一套 ID——任何一个人的遭遇都能在年表里找到年份，任何一件事都能在索引里找到当事人。');
L.push('');
L.push('## 导读');
L.push('');
L.push('明代二百七十六年不是一份帝王编年表，而是同一批危机反复出现的过程：北边打进来怎么办、钱从哪里来、皇帝与文官集团谁说了算。本书把 1351 年朱元璋投军到 1662 年永历遇害之间的三百一十一年摊开，按「危机 — 应对 — 代价」推进。每一次应对都解决了眼前的问题，同时把成本推给下一段：废丞相换来内阁与宦官，军屯崩坏换来募饷与加派，边患暂缓换来党争与清算。');
L.push('');
L.push('三条压力线贯穿全书：**边患线**（北元→瓦剌→俺答与倭寇→后金）、**财政线**（军屯→宝钞→白银→加派）、**党争线**（废相→内阁→司礼监→厂卫→东林）。' + events.length + ' 个事件、' + people.length + ' 位人物、' + chapters.length + ' 章，构成一张可以正着读、也可以横着查的网。');
L.push('');
L.push('> **边界说明**：事件年份、官职、战役、结局依《明史》《明实录》及主流研究核对；人物档案中的「自述」属第一人称文学重构，不是史料引文；「身后」「点评」「结构性判断」属叙事设计与史识分析，不是史论定谳；争议处（徐达赐蒸鹅、建文下落、景泰帝死因、袁崇焕通敌、李自成结局等）以「史载／存疑／一说」标注。');
L.push('');
L.push('---');
L.push('');

let lastVolume = '';
for (const c of chapters) {
  if (c.volume !== lastVolume) {
    L.push('## ' + c.volume + '（' + c.years + ' 起）');
    L.push('');
    lastVolume = c.volume;
  }
  L.push('### 第 ' + c.no + ' 章　' + c.title + '（' + c.years + '）');
  L.push('');
  L.push(c.intro);
  L.push('');
  L.push('**关键事件**　' + (c.events || []).join('　·　'));
  L.push('');
  L.push('**出场人物**　' + (c.people || []).map(id => peopleMap.get(id) ? peopleMap.get(id).name : id).join('　·　'));
  L.push('');
  L.push('**主导压力线**　' + (c.thread || '—'));
  L.push('');
  L.push('> 连向下一章：' + (c.hook || ''));
  L.push('');
}
L.push('---');
L.push('');
L.push('## 附录一 · 事件年表');
L.push('');
L.push('> 按年份排序，方括号内为事件类别。共 ' + events.length + ' 条；完整正文、关联人物与三线标签见「全景时序」可视化页。');
L.push('');
for (const e of events) {
  L.push('- **' + (e.date || e.year) + '　' + e.title + '**　［' + e.cat + '］' + (e.place ? '　' + e.place : '') + (e.cost ? '　｜　代价：' + e.cost : ''));
}
L.push('');
L.push('---');
L.push('');
L.push('## 附录二 · 人物索引');
L.push('');
L.push('> 按阵营分组，共 ' + people.length + ' 人。括号内为生命线区间；生卒不详者用其见于史册的活动区间。');
L.push('');
for (const side of roster.sides) {
  const group = people.filter(p => p.side === side);
  if (!group.length) continue;
  L.push('### ' + side + '（' + group.length + ' 人）');
  L.push('');
  for (const p of group) {
    L.push('- **' + p.name + '** (' + p.span[0] + '—' + p.span[1] + ')　' + p.role + '　｜　' + p.arc + '　｜　结局：' + p.end + '　｜　关联事件 ' + p.eventIds.length + ' 条');
  }
  L.push('');
}
L.push('---');
L.push('');
L.push('## 附：内容使用建议');
L.push('');
L.push('- **卷章**可直接拆为 App 的剧情章节，每章的「关键事件」即页内节点，「出场人物」即浮层人物卡。');
L.push('- **事件年表**是全景时序页的数据源：同一年份多类别并列，点击可展开三视角（当事人／对手／财政）。');
L.push('- **人物索引**与生命线联动：选中一人，其参与的全部事件在年表上高亮，其余淡出。');
L.push('- **争议标注**：涉及存疑的条目在 App 内需以「史载／存疑」标签区分，不要把文学重构当史料引文。');
L.push('');

const md = L.join('\n');
const mdPath = path.join(root, '大明王朝·全景大纲.md');
fs.writeFileSync(mdPath, md, 'utf8');

/* ---------- 五、注入可视化页面 ---------- */
const payload = {
  meta: {
    from: 1351, to: 1662,
    sides: roster.sides, cats: roster.cats, threads: roster.threads,
    counts: { events: events.length, people: people.length, chapters: chapters.length, bios: deepBios.length }
  },
  events, people, chapters
};
const htmlPath = path.join(root, '大明王朝全景', 'index.html');
let html = fs.readFileSync(htmlPath, 'utf8');
const START = '/*PANORAMA_DATA_START*/', END = '/*PANORAMA_DATA_END*/';
const a = html.indexOf(START), b = html.indexOf(END);
if (a < 0 || b < 0 || b < a) throw new Error('index.html 缺少 PANORAMA_DATA 标记块或顺序异常');
const block = START + '\nconst DATA = ' + JSON.stringify(payload) + ';\n' + END;
html = html.slice(0, a) + block + html.slice(b + END.length);
fs.writeFileSync(htmlPath, html, 'utf8');

/* ---------- 六、报告 ---------- */
console.log('批次文件：', files.length);
console.log('事件：', events.length, '｜ 人物：', people.length, '｜ 章节：', chapters.length, '｜ 深度自传复用：', deepBios.length);
const catCount = {}; for (const e of events) catCount[e.cat] = (catCount[e.cat] || 0) + 1;
console.log('事件类别：', JSON.stringify(catCount, null, 0));
const sideCount = {}; for (const p of people) sideCount[p.side] = (sideCount[p.side] || 0) + 1;
console.log('人物阵营：', JSON.stringify(sideCount, null, 0));
console.log('校验问题：', problems.length);
if (problems.length) { problems.slice(0, 20).forEach(x => console.log('  ! ' + x)); }
console.log('文档：', mdPath, md.length, '字');
console.log('注入：', htmlPath, 'DATA 字节', Buffer.byteLength(JSON.stringify(payload)));
if (problems.length) process.exitCode = 1;
