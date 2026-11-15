/* 从 360 百科人物条目匹配姓名精确一致的历史画像。
   只下载条目正文图片，记录来源页和待复核状态；找不到时保留档案形象。 */
const fs = require('fs');
const path = require('path');

const base = __dirname;
const root = path.dirname(base);
const contentDir = path.join(base, 'content');
const assetDir = path.join(root, '大明王朝iOS', 'assets', 'portraits');
const manifestPath = path.join(contentDir, 'published', 'portraits.json');
const roster = JSON.parse(fs.readFileSync(path.join(contentDir, 'roster.json'), 'utf8')).people;
const userProvided = new Map([
  ['zhu_yuanzhang', {
    file: 'zhu_yuanzhang.png',
    label: '朱元璋 · 明代太祖像',
    sourcePage: null,
    credit: '用户提供图像',
    license: '用户提供，正式发布前复核'
  }]
]);
/* 本轮只批准朱元璋真实画像进入产品；其他人物待逐图核对后再开放。 */
const approvedHistoricalPortraits = new Set(['zhu_yuanzhang']);
fs.mkdirSync(assetDir, { recursive: true });

const headers = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/135 Safari/537.36',
  'Referer': 'https://baike.so.com/'
};
const decode = value => value
  .replace(/&amp;/g, '&')
  .replace(/&quot;/g, '"')
  .replace(/&#39;/g, "'")
  .replace(/&lt;/g, '<')
  .replace(/&gt;/g, '>');
const attr = (tag, name) => {
  const match = tag.match(new RegExp(`${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s>]+))`, 'i'));
  return decode(match?.[1] || match?.[2] || match?.[3] || '');
};
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

async function findPortrait(name) {
  const searchUrl = `https://www.so.com/s?q=${encodeURIComponent(`${name} 明朝 360百科`)}`;
  const searchResponse = await fetch(searchUrl, { headers });
  if (!searchResponse.ok) return null;
  const searchHtml = await searchResponse.text();
  const resultBlocks = [...searchHtml.matchAll(/<li class="res-list"[\s\S]*?<\/li>/gi)]
    .map(match => match[0])
    .filter(block => block.includes(name) && block.includes('https://baike.so.com/doc/'));
  for (const block of resultBlocks) {
    const pageMatch = block.match(/https:\/\/baike\.so\.com\/doc\/\d+-\d+\.html/);
    const image = [...block.matchAll(/<img\b[^>]*>/gi)].map(match => match[0])
      .find(tag => attr(tag, 'data-isrc'));
    if (!pageMatch || !image) continue;
    let src = attr(image, 'data-isrc');
    if (src.startsWith('//')) src = `https:${src}`;
    if (!/^https?:\/\//.test(src)) continue;
    return { sourcePage: pageMatch[0], src, searchUrl };
  }
  return null;
}

async function download(candidate, personId) {
  const response = await fetch(candidate.src, { headers });
  if (!response.ok) return null;
  const type = response.headers.get('content-type') || '';
  if (!type.startsWith('image/')) return null;
  const extension = type.includes('png') ? 'png' : type.includes('webp') ? 'webp' : 'jpg';
  const data = Buffer.from(await response.arrayBuffer());
  if (data.length < 3500) return null;
  const file = `${personId}.${extension}`;
  fs.writeFileSync(path.join(assetDir, file), data);
  return { file, type, bytes: data.length };
}

async function main() {
  const portraits = [];
  for (let index = 0; index < roster.length; index += 1) {
    const person = roster[index];
    const provided = userProvided.get(person.id);
    if (provided && fs.existsSync(path.join(assetDir, provided.file))) {
      portraits.push({
        personId: person.id,
        status: 'historical',
        src: `assets/portraits/${provided.file}`,
        label: provided.label,
        note: '真实历史画像；来源与授权待正式发布前复核。',
        sourcePage: provided.sourcePage,
        sourceTitle: person.name,
        license: provided.license,
        credit: provided.credit,
        match: 'user-provided',
        reviewStatus: 'license-review-required'
      });
      continue;
    }
    if (!approvedHistoricalPortraits.has(person.id)) {
      portraits.push({
        personId: person.id,
        status: 'fallback',
        src: null,
        label: '暂无可靠传世画像',
        note: '以姓名、身份与时代纹样构成的档案形象，不冒充历史肖像。',
        sourcePage: null,
        sourceTitle: null,
        license: null,
        credit: null,
        match: 'none',
        reviewStatus: 'fallback'
      });
      continue;
    }
    let record = null;
    try {
      const candidate = await findPortrait(person.name);
      if (candidate) {
        const file = await download(candidate, person.id);
        if (file) record = {
          personId: person.id,
          status: 'historical',
          src: `assets/portraits/${file.file}`,
          label: `${person.name} · 百科历史画像`,
          note: '按姓名精确匹配的百科条目图像；正式发布前需逐图核对来源和授权。',
          sourcePage: candidate.sourcePage,
          sourceTitle: person.name,
          license: '百科图像，授权待复核',
          credit: '360百科',
          match: 'exact-name-alt',
          reviewStatus: 'source-page-matched-license-pending'
        };
      }
    } catch (error) {
      console.warn(`${person.name}: ${error.message}`);
    }
    portraits.push(record || {
      personId: person.id,
      status: 'fallback',
      src: null,
      label: '暂无可靠传世画像',
      note: '以姓名、身份与时代纹样构成的档案形象，不冒充历史肖像。',
      sourcePage: null,
      sourceTitle: null,
      license: null,
      credit: null,
      match: 'none',
      reviewStatus: 'fallback'
    });
    if (index % 10 === 0) {
      fs.writeFileSync(manifestPath, JSON.stringify({ portraits }, null, 2), 'utf8');
      console.log(`${index + 1}/${roster.length} · historical=${portraits.filter(item => item.status === 'historical').length}`);
    }
    await sleep(180);
  }
  fs.writeFileSync(manifestPath, JSON.stringify({ portraits }, null, 2), 'utf8');
  console.log(JSON.stringify({
    manifest: manifestPath,
    assets: assetDir,
    historical: portraits.filter(item => item.status === 'historical').length,
    fallback: portraits.filter(item => item.status === 'fallback').length
  }, null, 2));
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
