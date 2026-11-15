/* 唯一内容构建入口：读取 content 源文件，生成 Web 原型可消费的内容包。 */
const fs = require('fs');
const path = require('path');

const base = __dirname;
const root = path.dirname(base);
const cdir = path.join(base, 'content');
const outDir = path.join(root, '大明王朝iOS');
const read = file => JSON.parse(fs.readFileSync(path.join(cdir, file), 'utf8'));

const roster = read('roster.json');
const chapters = read('chapters.json').chapters;
const editorial = read('history.json');
const sources = read('sources.json').sources;
const places = read('places.json').places;
const memorials = read('memorials.json').memorials;
const works = read('works.json').works;
const portraitPath = path.join(cdir, 'published', 'portraits.json');
let portraits = fs.existsSync(portraitPath) ? read('published/portraits.json').portraits : [];
if (!fs.existsSync(portraitPath)) {
  portraits = roster.people.map(person => ({
    personId: person.id,
    status: 'fallback',
    src: null,
    label: '暂无可靠传世画像',
    note: '以姓名、身份与时代纹样构成的档案形象，不冒充历史肖像。',
    sourcePage: null,
    license: null,
    credit: null,
    match: 'none',
    reviewStatus: 'fallback'
  }));
  fs.writeFileSync(portraitPath, JSON.stringify({ portraits }, null, 2), 'utf8');
}
const portraitMap = new Map(portraits.map(item => [item.personId, item]));

const batchDir = path.join(cdir, 'batch');
const batchFiles = fs.readdirSync(batchDir).filter(file => file.endsWith('.json')).sort();
const events = [];
const profiles = new Map();
for (const file of batchFiles) {
  const data = JSON.parse(fs.readFileSync(path.join(batchDir, file), 'utf8'));
  if (Array.isArray(data.events)) events.push(...data.events);
  for (const person of data.people || []) profiles.set(person.id, person);
}
const publishedDir = path.join(cdir, 'published');
for (const file of fs.readdirSync(publishedDir).filter(name => name.endsWith('.json') && name !== 'portraits.json').sort()) {
  const data = JSON.parse(fs.readFileSync(path.join(publishedDir, file), 'utf8'));
  if (Array.isArray(data.events)) events.push(...data.events);
  for (const person of data.people || []) profiles.set(person.id, person);
}

const deepPeople = [
  ...read('bios_generals.json').people,
  ...read('bios_others.json').people
];
const deepMap = new Map(deepPeople.map(person => [person.id, person]));
const supplement = read('bios_supplement.json').people;
const supplementMap = new Map(supplement.map(person => [person.id, person]));
const rosterMap = new Map(roster.people.map(person => [person.id, person]));
const sourceIds = new Set(sources.map(source => source.id));
const relationOverrides = new Map([
  ['huweiyong|zhu_yuanzhang', ['主从', '政敌']],
  ['lanyu|zhu_yuanzhang', ['主从', '政敌']],
  ['lishanchang|zhu_yuanzhang', ['主从', '政敌']],
  ['xuda|zhu_yuanzhang', ['主从']],
  ['qijiguang|zhangjuzheng', ['主从']],
  ['gaogong|zhangjuzheng', ['政敌']],
  ['xujie|yansong', ['政敌']],
  ['gaogong|xujie', ['政敌']],
  ['shi_heng|yuqian', ['政敌']],
  ['xu_youzhen|yuqian', ['政敌']],
  ['zhu_qizhen|yuqian', ['主从', '政敌']],
  ['mao_wenlong|yuanchonghuan', ['政敌']],
  ['sunchengzong|yuanchonghuan', ['同僚']],
  ['weizhongxian|yang_lian', ['政敌']],
  ['zhu_youjian|yuanchonghuan', ['主从', '政敌']],
  ['zhu_youxiao|weizhongxian', ['主从']],
  ['feng_bao|zhangjuzheng', ['同僚']],
  ['li_taihou|zhangjuzheng', ['同僚']]
]);
const familyPairs = new Set([
  'ma_huanghou|zhu_yuanzhang','zhu_biao|zhu_yuanzhang','zhu_yunwen|zhu_yuanzhang',
  'zhu_di|zhu_yuanzhang','zhu_gaochi|zhu_di','zhu_gaoxu|zhu_di','zhu_gaosui|zhu_di',
  'zhu_gaochi|zhu_zhanji','zhu_gaoxu|zhu_zhanji','zhu_qiyu|zhu_qizhen',
  'zhu_jianshen|zhu_qizhen','changping|zhu_youjian','tian_guifei|zhu_youjian',
  'zhu_youjian|zhou_huanghou_cz'
]);

const problems = [];
const warnings = [];
const seenEvents = new Set();
function issue(message) { problems.push(message); }
function warn(message) { warnings.push(message); }
function parseTime(event) {
  const raw = String(event.date || '').trim();
  const parts = raw.split('.').filter(Boolean);
  const year = Number(event.year || parts[0] || 0);
  const month = parts.length > 1 && Number.isFinite(Number(parts[1])) ? Number(parts[1]) : null;
  const precision = month ? 'month' : 'year';
  return {
    year,
    month,
    precision,
    sortValue: year * 100 + (month || 0),
    display: raw || `${year}年`,
    uncertainty: raw ? 'statedWorkingDate' : 'yearOnly'
  };
}
function sourceRefsFor(item, fallback) {
  const refs = Array.isArray(item.sourceRefs) && item.sourceRefs.length ? item.sourceRefs : fallback;
  for (const ref of refs) if (!sourceIds.has(ref)) issue(`未知来源 ${ref}：${item.id || item.title || item.name}`);
  return refs.map(sourceId => ({
    sourceId,
    locator: null,
    status: 'work-level',
    note: '卷次、篇目和页码待史料校订补录。'
  }));
}
function placeRefsFor(event) {
  const haystack = `${event.place || ''} ${event.title || ''}`;
  const refs = places
    .filter(place => (place.keywords || []).some(keyword => haystack.includes(keyword)))
    .map(place => ({ placeId: place.id, match: 'keyword', confidence: 'inferred' }));
  return refs;
}

events.sort((a, b) => parseTime(a).sortValue - parseTime(b).sortValue || a.id.localeCompare(b.id));
const normalizedEvents = events.map(event => {
  if (!event.id || seenEvents.has(event.id)) issue(`事件 ID 重复或缺失：${event.id}`);
  seenEvents.add(event.id);
  if (!Number.isInteger(event.year)) issue(`事件年份无效：${event.id}`);
  for (const personId of event.people || []) if (!rosterMap.has(personId)) issue(`事件 ${event.id} 引用未知人物 ${personId}`);
  const time = parseTime(event);
  const placeRefs = placeRefsFor(event);
  if (!placeRefs.length) warn(`事件无结构化地点：${event.id} ${event.title}`);
  const uncertaintyFlags = [];
  if (/存疑|一说|史载不一|尚待考/.test(event.text || '')) uncertaintyFlags.push('contested-detail');
  return {
    ...event,
    time,
    placeRefs,
    relationStatus: 'inferred-by-keyword',
    uncertaintyFlags,
    sourceRefs: sourceRefsFor(event, ['mingshi', 'mingshilu'])
  };
});

const eventsOfPerson = new Map();
for (const event of normalizedEvents) {
  for (const personId of event.people || []) {
    if (!eventsOfPerson.has(personId)) eventsOfPerson.set(personId, []);
    eventsOfPerson.get(personId).push(event.id);
  }
}

const people = roster.people.map(member => {
  const profile = profiles.get(member.id) || {};
  const deep = deepMap.get(member.id);
  const extraStory = supplementMap.get(member.id);
  const eventIds = eventsOfPerson.get(member.id) || [];
  let related = profile.related || [];
  if (!related.length) {
    const counts = new Map();
    for (const eventId of eventIds) {
      const event = normalizedEvents.find(item => item.id === eventId);
      for (const personId of event?.people || []) {
        if (personId !== member.id && rosterMap.has(personId)) counts.set(personId, (counts.get(personId) || 0) + 1);
      }
    }
    related = [...counts.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])).slice(0, 8).map(([id]) => id);
  }
  const fallbackRelated = {
    muying: ['zhu_yuanzhang', 'ma_huanghou', 'lanyu'],
    zhouyanru: ['zhu_youjian', 'wentiren', 'yang_sichang'],
    shenshixing: ['zhu_yijun', 'zhangjuzheng', 'wang_xijue', 'gaogong']
  };
  if (!related.length) related = fallbackRelated[member.id] || [];
  const stages = deep?.stages || extraStory?.stages || [];
  const tier = deep?.memoir ? 'core' : stages.length >= 5 ? 'extended' : 'standard';
  const portrait = portraitMap.get(member.id) || {
    personId: member.id,
    status: 'fallback',
    src: null,
    label: '暂无可靠传世画像',
    note: '以姓名、身份与时代纹样构成的档案形象，不冒充历史肖像。'
  };
  if (!eventIds.length) issue(`人物没有关联事件：${member.name}`);
  return {
    id: member.id,
    name: member.name,
    alias: profile.alias || '',
    side: member.side,
    years: profile.years || `${member.span[0]}—${member.span[1]}`,
    span: member.span,
    role: profile.role || member.brief,
    arc: profile.arc || deep?.arc || member.brief,
    bio: profile.bio || deep?.stages?.map(stage => stage.text).join('') || member.brief,
    deeds: profile.deeds || deep?.timeline || [],
    end: profile.end || member.brief,
    note: profile.note || deep?.legacy || '',
    threads: profile.threads || [],
    related,
    eventIds,
    stages,
    memoir: deep?.memoir || '',
    editorialType: deep?.memoir ? 'literaryReconstruction' : 'referenceProfile',
    contentTier: tier,
    sourceRefs: sourceRefsFor(profile, ['mingshi']),
    portrait,
    quality: {
      bioChars: (profile.bio || deep?.stages?.map(stage => stage.text).join('') || member.brief || '').length,
      deedCount: (profile.deeds || deep?.timeline || []).length,
      stageCount: stages.length,
      eventCount: eventIds.length
    }
  };
});
const peopleMap = new Map(people.map(person => [person.id, person]));

function relationTypes(a, b, sharedEvents) {
  const pair = [a.id, b.id].sort().join('|');
  const types = [...(relationOverrides.get(pair) || [])];
  if (familyPairs.has(pair)) types.push('家族');
  else if (a.name[0] === b.name[0] && ['帝王','宗室','后妃外戚'].includes(a.side) && ['帝王','宗室','后妃外戚'].includes(b.side)) types.push('家族');
  if ((a.side === '帝王' || b.side === '帝王') && !types.includes('家族')) types.push('主从');
  if (!relationOverrides.has(pair) && !types.includes('家族') && sharedEvents.some(event => event.cat === '人事') && a.side === b.side) types.push('同僚');
  if (!types.length && a.side === b.side) types.push('同僚');
  if (!types.length) types.push('同场');
  return [...new Set(types)];
}

const relationMap = new Map();
for (const person of people) {
  person.relations = person.related.map(id => peopleMap.get(id)).filter(Boolean).map(other => {
    const sharedEvents = normalizedEvents.filter(event => (event.people || []).includes(person.id) && (event.people || []).includes(other.id));
    const relation = {
      id: [person.id, other.id].sort().join('--'),
      from: person.id,
      to: other.id,
      types: relationTypes(person, other, sharedEvents),
      evidenceEventIds: sharedEvents.slice(0, 6).map(event => event.id),
      evidence: sharedEvents.slice(0, 3).map(event => `${event.year} ${event.title}`),
      basis: relationOverrides.has([person.id, other.id].sort().join('|')) || familyPairs.has([person.id, other.id].sort().join('|')) ? 'curated-rule' : 'shared-events',
      reviewStatus: 'inferred'
    };
    relationMap.set(relation.id, relation);
    return relation;
  });
}

const normalizeNarrativeText = value => String(value || '').replace(/[^\u4e00-\u9fff0-9]/g, '');
function narrativeBigrams(value) {
  const text = normalizeNarrativeText(value);
  const grams = new Set();
  for (let index = 0; index < text.length - 1; index += 1) grams.add(text.slice(index, index + 2));
  return grams;
}
function primaryChapterFor(event) {
  const candidates = chapters.filter(chapter => event.year >= chapter.from && event.year <= chapter.to);
  if (candidates.length === 1) return candidates[0];
  const title = normalizeNarrativeText(event.title);
  const eventGrams = narrativeBigrams(`${event.title} ${event.place} ${event.text}`);
  const boundaryRules = {
    1424: event.title.includes('榆木川') ? 6 : 7,
    1449: /土木|亲征|也先.*入|大同宣府/.test(event.title) ? 8 : 9,
    1457: /夺门|于谦|景泰/.test(event.title) ? 9 : 10,
    1582: /张居正/.test(event.title) ? 15 : 16
  };
  const preferred = boundaryRules[event.year];
  if (preferred && candidates.some(chapter => chapter.no === preferred)) {
    return candidates.find(chapter => chapter.no === preferred);
  }
  return candidates
    .map(chapter => {
      const context = normalizeNarrativeText(`${chapter.title} ${(chapter.events || []).join('')} ${chapter.intro} ${chapter.hook}`);
      let overlap = 0;
      for (const gram of eventGrams) if (context.includes(gram)) overlap += 1;
      const exact = title && context.includes(title) ? 60 : 0;
      const distance = Math.abs(event.year - (chapter.from + chapter.to) / 2);
      return { chapter, score: exact + overlap * 2 - distance * 0.001 };
    })
    .sort((a, b) => b.score - a.score || b.chapter.no - a.chapter.no)[0].chapter;
}
const eventChapter = new Map(normalizedEvents.map(event => [event.id, primaryChapterFor(event).no]));
for (const event of normalizedEvents) event.primaryChapterId = eventChapter.get(event.id);
const normalizedChapters = chapters.map(chapter => ({
  ...chapter,
  eventIds: normalizedEvents.filter(event => event.primaryChapterId === chapter.no).map(event => event.id),
  membershipBasis: 'single-primary-chapter',
  sourceRefs: [{ sourceId: 'mingshi', locator: null, status: 'work-level' }]
}));
for (const chapter of normalizedChapters) if (!chapter.eventIds.length) issue(`章节没有事件：${chapter.no}`);
const chapterAssignments = normalizedChapters.flatMap(chapter => chapter.eventIds);
if (new Set(chapterAssignments).size !== chapterAssignments.length) issue('章节事件存在重复归属');
if (chapterAssignments.length !== normalizedEvents.length) issue('存在未分配主章节或重复分配的事件');

const output = {
  meta: {
    schemaVersion: '4.0.0',
    contentVersion: '2026.11-p0',
    generatedAt: new Date().toISOString(),
    people: people.length,
    events: normalizedEvents.length,
    chapters: normalizedChapters.length,
    sources: sources.length,
    places: places.length,
    memorials: memorials.length,
    works: works.length,
    relations: relationMap.size,
    missingEventPeople: people.filter(person => !person.eventIds.length).length,
    portraitFallbacks: people.filter(person => person.portrait.status === 'fallback').length,
    validation: { errors: problems.length, warnings: warnings.length }
  },
  people,
  events: normalizedEvents,
  chapters: normalizedChapters,
  relations: [...relationMap.values()],
  places,
  sources,
  memorials,
  works,
  editorial
};

const jsTarget = path.join(outDir, 'content-bundle.js');
const jsonTarget = path.join(outDir, 'content-bundle.json');
fs.writeFileSync(jsTarget, `/* 自动生成；唯一构建入口 build_content_bundle.js */\nwindow.DAM_CONTENT=${JSON.stringify(output)};\n`, 'utf8');
fs.writeFileSync(jsonTarget, JSON.stringify(output, null, 2), 'utf8');
const reviewQueue = {
  schemaVersion: output.meta.schemaVersion,
  contentVersion: output.meta.contentVersion,
  missingStructuredPlaces: normalizedEvents.filter(event => !event.placeRefs.length).map(event => ({
    eventId: event.id,
    title: event.title,
    place: event.place,
    reason: 'national-or-unmapped-scope'
  })),
  sourceLocatorsPending: [
    ...people.flatMap(person => person.sourceRefs.filter(ref => !ref.locator).map(ref => ({ entity: 'person', id: person.id, sourceId: ref.sourceId }))),
    ...normalizedEvents.flatMap(event => event.sourceRefs.filter(ref => !ref.locator).map(ref => ({ entity: 'event', id: event.id, sourceId: ref.sourceId })))
  ],
  portraitFallbacks: people.filter(person => person.portrait.status === 'fallback').map(person => person.id)
};
fs.writeFileSync(path.join(outDir, 'content-review-queue.json'), JSON.stringify(reviewQueue, null, 2), 'utf8');

console.log(JSON.stringify({
  outputs: [jsTarget, jsonTarget, path.join(outDir, 'content-review-queue.json')],
  people: people.length,
  events: normalizedEvents.length,
  chapters: normalizedChapters.length,
  relations: relationMap.size,
  missingEventPeople: output.meta.missingEventPeople,
  portraitFallbacks: output.meta.portraitFallbacks,
  datePrecision: normalizedEvents.reduce((acc, event) => {
    acc[event.time.precision] = (acc[event.time.precision] || 0) + 1;
    return acc;
  }, {}),
  errors: problems,
  warnings: warnings.slice(0, 30)
}, null, 2));
if (problems.length) process.exitCode = 1;
