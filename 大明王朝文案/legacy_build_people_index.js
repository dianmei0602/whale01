/* 旧版独立人物索引构建器。保留供迁移比对，不再作为应用数据入口。 */
const fs = require('fs');
const path = require('path');

const base = __dirname;
const root = path.dirname(base);
const cdir = path.join(base, 'content');
const read = file => JSON.parse(fs.readFileSync(path.join(cdir, file), 'utf8'));

const roster = read('roster.json');
const chapters = read('chapters.json').chapters;
const batchFiles = fs.readdirSync(path.join(cdir, 'batch')).filter(file => file.endsWith('.json'));
const events = [];
const profiles = new Map();

for (const file of batchFiles.sort()) {
  const data = JSON.parse(fs.readFileSync(path.join(cdir, 'batch', file), 'utf8'));
  if (data.events) events.push(...data.events);
  for (const person of data.people || []) profiles.set(person.id, person);
}

const deepPeople = [
  ...read('bios_generals.json').people,
  ...read('bios_others.json').people
];
const deepMap = new Map(deepPeople.map(person => [person.id, person]));
const supplement = read('bios_supplement.json').people;
const supplementMap = new Map(supplement.map(person => [person.id, person]));

events.sort((a, b) => a.year - b.year || a.id.localeCompare(b.id));
const eventsOfPerson = new Map();
for (const event of events) {
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
    const memberSet = new Set(roster.people.map(person => person.id));
    for (const eventId of eventIds) {
      const event = events.find(item => item.id === eventId);
      for (const personId of event?.people || []) {
        if (personId !== member.id && memberSet.has(personId)) {
          counts.set(personId, (counts.get(personId) || 0) + 1);
        }
      }
    }
    related = [...counts.entries()]
      .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
      .slice(0, 8)
      .map(([personId]) => personId);
  }

  const fallbackRelated = {
    muying: ['zhu_yuanzhang', 'ma_huanghou', 'lanyu'],
    zhouyanru: ['zhu_youjian', 'wentiren', 'yang_sichang'],
    shenshixing: ['zhu_yijun', 'zhangjuzheng', 'wang_xijue', 'gaogong']
  };
  if (!related.length) related = fallbackRelated[member.id] || [];

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
    stages: deep?.stages || extraStory?.stages || [],
    memoir: deep?.memoir || ''
  };
});
const peopleMap = new Map(people.map(person => [person.id, person]));
const familyPairs = new Set([
  'ma_huanghou|zhu_yuanzhang',
  'zhu_biao|zhu_yuanzhang',
  'zhu_yunwen|zhu_yuanzhang',
  'zhu_di|zhu_yuanzhang',
  'zhu_gaochi|zhu_di',
  'zhu_gaoxu|zhu_di',
  'zhu_gaosui|zhu_di',
  'zhu_gaochi|zhu_zhanji',
  'zhu_gaoxu|zhu_zhanji',
  'zhu_qiyu|zhu_qizhen',
  'zhu_jianshen|zhu_qizhen',
  'changping|zhu_youjian',
  'tian_guifei|zhu_youjian',
  'zhu_youjian|zhou_huanghou_cz'
]);
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
function relationTypes(a,b,sharedEvents){
  const pair=[a.id,b.id].sort().join('|');
  const types=[...(relationOverrides.get(pair)||[])];
  if(familyPairs.has(pair))types.push('家族');
  else if(a.name[0]===b.name[0]&&['帝王','宗室','后妃外戚'].includes(a.side)&&['帝王','宗室','后妃外戚'].includes(b.side))types.push('家族');
  if((a.side==='帝王'||b.side==='帝王')&&!types.includes('家族'))types.push('主从');
  if(!relationOverrides.has(pair)&&!types.includes('家族')&&sharedEvents.some(event=>event.cat==='人事')&&a.side===b.side)types.push('同僚');
  if(!types.length&&a.side===b.side)types.push('同僚');
  if(!types.length)types.push('同场');
  return [...new Set(types)];
}
for(const person of people){
  person.relations=person.related.map(id=>peopleMap.get(id)).filter(Boolean).map(other=>{
    const sharedEvents=events.filter(event=>
      (event.people||[]).includes(person.id)&&(event.people||[]).includes(other.id)
    );
    return {
      id:other.id,
      name:other.name,
      role:other.role,
      types:relationTypes(person,other,sharedEvents),
      evidence:sharedEvents.slice(0,3).map(event=>`${event.year} ${event.title}`)
    };
  });
}

const output = {
  meta: {
    people: people.length,
    events: events.length,
    from: Math.min(...people.map(person => person.span[0])),
    to: Math.max(...people.map(person => person.span[1]))
  },
  people,
  events,
  chapters
};

const target = path.join(root, '大明王朝iOS', 'people-full.js');
fs.writeFileSync(
  target,
  `/* 自动生成；请修改 content 数据后运行 build_people_index.js */\nwindow.DAM_PEOPLE=${JSON.stringify(output)};\n`,
  'utf8'
);

console.log(JSON.stringify({
  output: target,
  bytes: fs.statSync(target).size,
  people: people.length,
  events: events.length,
  chapters: chapters.length,
  peopleWithStages: people.filter(person => person.stages.length).length,
  peopleWithEvents: people.filter(person => person.eventIds.length).length
}, null, 2));
