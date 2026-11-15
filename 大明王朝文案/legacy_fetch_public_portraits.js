/* 旧版维基画像抓取尝试。当前改用受控的 fetch_baike_portraits.js，只批准朱元璋画像。
   未匹配或许可不明的人物保留为明确的“无可靠传世画像”档案形象。 */
const fs = require('fs');
const path = require('path');

const base = __dirname;
const root = path.dirname(base);
const contentDir = path.join(base, 'content');
const assetDir = path.join(root, '大明王朝iOS', 'assets', 'portraits');
const manifestPath = path.join(contentDir, 'published', 'portraits.json');
const roster = JSON.parse(fs.readFileSync(path.join(contentDir, 'roster.json'), 'utf8')).people;

fs.mkdirSync(assetDir, { recursive: true });

const apiUrl = 'https://zh.wikipedia.org/w/api.php';
const headers = { 'User-Agent': 'DamingAtlasPrototype/1.0 (local editorial prototype)' };
const allowedLicense = /(public domain|pd[- ]|cc0|cc by|cc-by|gfdl|公有领域|知识共享)/i;
const chunks = (items, size) => Array.from({ length: Math.ceil(items.length / size) }, (_, index) => items.slice(index * size, index * size + size));

async function get(params) {
  const url = new URL(apiUrl);
  for (const [key, value] of Object.entries({ format: 'json', formatversion: '2', ...params })) url.searchParams.set(key, value);
  const response = await fetch(url, { headers });
  if (!response.ok) throw new Error(`Wikipedia API ${response.status}: ${url}`);
  return response.json();
}

async function build() {
  const records = new Map();
  const titleToId = new Map(roster.map(person => [person.name, person.id]));
  for (const names of chunks(roster.map(person => person.name), 40)) {
    const data = await get({
      action: 'query',
      prop: 'pageimages',
      piprop: 'thumbnail|name',
      pithumbsize: '640',
      redirects: '1',
      titles: names.join('|')
    });
    const alias = new Map();
    for (const item of data.query?.normalized || []) alias.set(item.to, item.from);
    for (const item of data.query?.redirects || []) alias.set(item.to, alias.get(item.from) || item.from);
    for (const page of data.query?.pages || []) {
      const sourceTitle = alias.get(page.title) || page.title;
      const personId = titleToId.get(sourceTitle);
      if (!personId || !page.thumbnail?.source || !page.pageimage) continue;
      records.set(personId, {
        pageTitle: page.title,
        pageimage: page.pageimage,
        sourcePage: `https://zh.wikipedia.org/wiki/${encodeURIComponent(page.title.replaceAll(' ', '_'))}`,
        thumbnail: page.thumbnail.source
      });
    }
  }

  const files = [...new Set([...records.values()].map(record => `File:${record.pageimage}`))];
  const metadata = new Map();
  for (const titles of chunks(files, 40)) {
    const data = await get({
      action: 'query',
      prop: 'imageinfo',
      iiprop: 'url|extmetadata',
      iiurlwidth: '640',
      titles: titles.join('|')
    });
    for (const page of data.query?.pages || []) metadata.set(page.title, page.imageinfo?.[0]);
  }

  const portraits = [];
  for (const person of roster) {
    const record = records.get(person.id);
    const info = record ? metadata.get(`File:${record.pageimage}`) : null;
    const license = info?.extmetadata?.LicenseShortName?.value || '';
    const artist = (info?.extmetadata?.Artist?.value || '').replace(/<[^>]+>/g, '').trim();
    const credit = (info?.extmetadata?.Credit?.value || '').replace(/<[^>]+>/g, '').trim();
    if (record && info && allowedLicense.test(license)) {
      const response = await fetch(info.thumburl || info.url || record.thumbnail, { headers });
      if (response.ok) {
        const type = response.headers.get('content-type') || '';
        const extension = type.includes('png') ? 'png' : type.includes('webp') ? 'webp' : 'jpg';
        const file = `${person.id}.${extension}`;
        fs.writeFileSync(path.join(assetDir, file), Buffer.from(await response.arrayBuffer()));
        portraits.push({
          personId: person.id,
          status: 'historical',
          src: `assets/portraits/${file}`,
          label: `${person.name} · 传世画像`,
          note: '按中文维基百科同名人物条目页首图匹配，正式发布前仍需逐图复核。',
          sourcePage: record.sourcePage,
          sourceTitle: record.pageTitle,
          license,
          credit: artist || credit || 'Wikimedia Commons contributor',
          match: 'exact-page-title',
          reviewStatus: 'source-page-matched'
        });
        continue;
      }
    }
    portraits.push({
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
    });
  }
  fs.writeFileSync(manifestPath, JSON.stringify({ portraits }, null, 2), 'utf8');
  console.log(JSON.stringify({
    manifest: manifestPath,
    assets: assetDir,
    historical: portraits.filter(item => item.status === 'historical').length,
    fallback: portraits.filter(item => item.status === 'fallback').length
  }, null, 2));
}

build().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
