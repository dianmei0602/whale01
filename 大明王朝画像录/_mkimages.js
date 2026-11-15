const fs=require('fs');
const DIR=__dirname;
const IMG=DIR+'/images';
if(!fs.existsSync(IMG))fs.mkdirSync(IMG);
let kind={};
try{kind=JSON.parse(fs.readFileSync(DIR+'/_imgkind.json','utf8'))}catch(e){}

// 1. 百科来源
const out={};
let n=0;
try{
  const bk=JSON.parse(fs.readFileSync(DIR+'/_dl_baike.json','utf8')).ok||[];
  bk.forEach(d=>{
    const k=kind[d.id];
    if(k&&k.action==='drop')return;
    out[d.id]={file:d.file,from:'百度百科「'+(d.title||d.name)+'」词条配图',pageUrl:d.pageUrl||'',
      note:'按词条名检索并下载原图，服务端统一转制为 JPEG（长边 800px）',kind:k&&k.kind||''};
    n++;
  });
}catch(e){console.log('百科结果缺失')}

// 2. 机构来源优先（Agent 采集），统一文件名 id.jpg
const agents=[];
for(const f of ['_img_agentA.json','_img_agentB.json','_img_agentC.json','_img_extra.json']){
  try{const arr=JSON.parse(fs.readFileSync(DIR+'/'+f)); if(Array.isArray(arr))agents.push(...arr)}catch(e){}
}
let an=0;
agents.forEach(a=>{
  if(!a)return;
  const rel=(a.image||a.file||'');
  if(!rel)return;
  const k=kind[a.id];
  if(k&&k.action==='drop')return;
  const src=rel.replace(/^images\//,'');
  const srcPath=DIR+'/images/'+src;
  if(!fs.existsSync(srcPath))return;
  const fn=a.id.replace(/[^a-zA-Z0-9_-]/g,'_')+'.jpg';
  const dstPath=IMG+'/'+fn;
  try{ if(srcPath!==dstPath) fs.copyFileSync(srcPath,dstPath); }catch(e){ return; }
  const isExtra=!!a.via;
  out[a.id]={file:'images/'+fn,
    from:isExtra?(a.from||'补充采集'):((a.hold||'馆藏机构')+'　'+(a.source||'')),
    pageUrl:a.pageUrl||a.url||'',
    note:a.note||'已下载并验证',kind:k&&k.kind||''};
  an++;
});

fs.writeFileSync(DIR+'/_images.json',JSON.stringify(out,null,1),'utf8');
console.log('_images.json 条目',Object.keys(out).length,'（百科',n,'机构优先覆盖',an,'）');
const withKind=Object.values(out).filter(v=>v.kind).length;
console.log('其中带类型标注',withKind,'张');
const miss=Object.entries(out).filter(([k,v])=>!fs.existsSync(DIR+'/'+v.file)).map(([k])=>k);
if(miss.length)console.log('文件缺失:',miss.join(' '));
const dropped=Object.entries(kind).filter(([,v])=>v.action==='drop').map(([k])=>k);
console.log('已撤除图像:',dropped.length,'人');
