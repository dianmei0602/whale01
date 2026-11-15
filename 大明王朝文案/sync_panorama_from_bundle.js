/* 用唯一内容包刷新全景页，避免全景页重新拼装一份人物与事件数据。 */
const fs = require('fs');
const path = require('path');

const root = path.dirname(__dirname);
const bundlePath = path.join(root, '大明王朝iOS', 'content-bundle.json');
const htmlPath = path.join(root, '大明王朝全景', 'index.html');
const bundle = JSON.parse(fs.readFileSync(bundlePath, 'utf8'));
const payload = {
  meta: {
    from: 1351,
    to: 1662,
    sides: [...new Set(bundle.people.map(person => person.side))],
    cats: [...new Set(bundle.events.map(event => event.cat))],
    threads: ['边患线', '财政线', '党争线'],
    counts: {
      events: bundle.events.length,
      people: bundle.people.length,
      chapters: bundle.chapters.length,
      bios: bundle.people.filter(person => person.contentTier === 'core').length
    }
  },
  events: bundle.events,
  people: bundle.people,
  chapters: bundle.chapters,
  relations: bundle.relations,
  places: bundle.places,
  sources: bundle.sources,
  works: bundle.works
};

let html = fs.readFileSync(htmlPath, 'utf8');
const start = '/*PANORAMA_DATA_START*/';
const end = '/*PANORAMA_DATA_END*/';
const from = html.indexOf(start);
const to = html.indexOf(end);
if (from < 0 || to < from) throw new Error('全景页缺少 PANORAMA_DATA 标记块');
html = html.slice(0, from) + start + '\nconst DATA = ' + JSON.stringify(payload) + ';\n' + end + html.slice(to + end.length);
fs.writeFileSync(htmlPath, html, 'utf8');
console.log(JSON.stringify({
  output: htmlPath,
  people: payload.people.length,
  events: payload.events.length,
  chapters: payload.chapters.length,
  bytes: fs.statSync(htmlPath).size
}, null, 2));
