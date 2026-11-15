/* 将唯一内容包同步给 iOS 工程资源目录。 */
const fs = require('fs');
const path = require('path');

const root = path.dirname(__dirname);
const source = path.join(root, '大明王朝iOS', 'content-bundle.json');
const targetDir = path.join(root, 'DamingAtlasNative', 'DamingAtlas', 'Resources');
const target = path.join(targetDir, 'content-bundle.json');
const portraitSource = path.join(root, '大明王朝iOS', 'assets');
const portraitTarget = path.join(targetDir, 'assets');
fs.mkdirSync(targetDir, { recursive: true });
fs.copyFileSync(source, target);
fs.cpSync(portraitSource, portraitTarget, { recursive: true, force: true });
console.log(JSON.stringify({ source, target, assets: portraitTarget, bytes: fs.statSync(target).size }, null, 2));
