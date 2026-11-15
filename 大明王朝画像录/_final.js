const fs=require('fs');
const DIR=__dirname;
const IMG=DIR+'/images';
let out={};
try{ out=JSON.parse(fs.readFileSync(DIR+'/_images.json','utf8')); }catch(e){ console.log('读取 _images.json 失败:',e.message); }
let kind={};
try{ kind=JSON.parse(fs.readFileSync(DIR+'/_imgkind.json','utf8')); }catch(e){ console.log('读取 _imgkind.json 失败:',e.message); }
const merged=JSON.parse(fs.readFileSync(DIR+'/_merged.json','utf8')).with;

// 1. 剔除已核定误配
let dropped=0;
Object.keys(out).forEach(id=>{ if(kind[id]&&kind[id].action==='drop'){ delete out[id]; dropped++; } });

// 2. 校验文件存在且为有效图像；顺带补 kind
let bad=[];
Object.entries(out).forEach(([id,v])=>{
  const p=DIR+'/'+v.file;
  if(!fs.existsSync(p)){ bad.push(id+'(缺文件)'); delete out[id]; return; }
  const b=fs.readFileSync(p);
  const ok=b.length>3000&&((b[0]===0xFF&&b[1]===0xD8)||(b[0]===0x89&&b[1]===0x50));
  if(!ok){ bad.push(id+'(非图像)'); delete out[id]; return; }
  if(kind[id]&&kind[id].kind&&!v.kind) v.kind=kind[id].kind;
});
fs.writeFileSync(DIR+'/_images.json',JSON.stringify(out,null,1),'utf8');

const no=merged.filter(p=>!out[p.id]);
console.log('索引条目',Object.keys(out).length,'| 剔除误配',dropped,'| 校验剔除',bad.length);
if(bad.length)console.log('  ',bad.join(' '));
console.log('无图',no.length,'人:',no.map(p=>p.name).join('、'));
const kinds={};
Object.values(out).forEach(v=>{ if(v.kind) kinds[v.kind]=(kinds[v.kind]||0)+1; });
console.log('类型标注',JSON.stringify(kinds));
