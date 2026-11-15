/* 一次性迁移：DEEP 数据已进入 content-bundle，移除 HTML 内重复的大段常量。 */
const fs = require('fs');
const path = require('path');

const target = path.join(path.dirname(__dirname), '大明王朝iOS', 'index.html');
const source = fs.readFileSync(target, 'utf8');
const withoutDeep = source
  .split(/\r?\n/)
  .filter(line => !line.startsWith('const DEEP = '))
  .join('\n');
if (withoutDeep === source) {
  console.log('No inline DEEP declaration found.');
} else {
  fs.writeFileSync(target, withoutDeep, 'utf8');
  console.log(JSON.stringify({ output: target, removedBytes: Buffer.byteLength(source) - Buffer.byteLength(withoutDeep) }, null, 2));
}
