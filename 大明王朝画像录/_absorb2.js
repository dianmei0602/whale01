const fs=require('fs');
const DIR=__dirname;
const IMG=DIR+'/images';
let out={};
try{out=JSON.parse(fs.readFileSync(DIR+'/_images.json','utf8'));}catch(e){}
const kind={};
try{kind=JSON.parse(fs.readFileSync(DIR+'/_imgkind.json','utf8'))}catch(e){}
const bkTime=fs.statSync(DIR+'/_dl_baike.json').mtimeMs;   // 百科下载时刻基准
// 先剔除已核定误配
Object.entries(kind).forEach(([id,v])=>{ if(v.action==='drop') delete out[id]; });
const files=fs.readdirSync(IMG);
const merged=JSON.parse(fs.readFileSync(DIR+'/_merged.json','utf8')).with;
const norm=s=>s.replace(/\.[a-z0-9]+$/i,'').replace(/[^a-zA-Z0-9]/g,'').toLowerCase();
function lev(a,b){
  const m=a.length,n=b.length;if(!m)return n;if(!n)return m;
  let prev=Array.from({length:n+1},(_,j)=>j),cur=new Array(n+1);
  for(let i=1;i<=m;i++){cur[0]=i;
    for(let j=1;j<=n;j++){
      cur[j]=Math.min(prev[j]+1,cur[j-1]+1,prev[j-1]+(a[i-1]===b[j-1]?0:1));
    }
    [prev,cur]=[cur,prev];}
  return prev[n];
}
const used=new Set(Object.values(out).map(v=>v.file.replace('images/','')));
const picks=[];
files.forEach(f=>{
  if(f.startsWith('_'))return;
  if(used.has(f))return;
  const base=norm(f);
  if(base.length<4)return;
  let best=null,bd=9;
  merged.forEach(p=>{
    const nb=norm(p.id), ns=norm(p.id.replace(/^extra/,''));
    const d=Math.min(lev(base,nb),lev(base,ns));
    if(d<bd){bd=d;best=p.id}
  });
  if(best&&bd<=2)picks.push({f,id:best,d:bd});
});
console.log('模糊匹配到',picks.length,'张');
let add=0,skip=0;
picks.forEach(c=>{
  const k=kind[c.id];
  if(k&&k.action==='drop'){skip++;return}   // 已核定误配，一律不予收录
  const b=fs.readFileSync(IMG+'/'+c.f);
  if(!(b.length>3000&&((b[0]===0xFF&&b[1]===0xD8)||(b[0]===0x89&&b[1]===0x50))))return;
  const fn=c.id+'.jpg';
  try{if(c.f!==fn)fs.copyFileSync(IMG+'/'+c.f,IMG+'/'+fn)}catch(e){return}
  const kk=kind[c.id];
  out[c.id]={file:'images/'+fn,
    from:'公开图源采集（馆藏机构数字资源 / 公开图录）',
    pageUrl:'',note:'已下载并验证'+(kk&&kk.note?'；'+kk.note:''),kind:(kk&&kk.kind)||''};
  add++;
});
fs.writeFileSync(DIR+'/_images.json',JSON.stringify(out,null,1),'utf8');
// 最终剔除：已核定误配的条目不得留在索引中
Object.entries(kind).forEach(([id,v])=>{ if(v.action==='drop') delete out[id]; });
fs.writeFileSync(DIR+'/_images.json',JSON.stringify(out,null,1),'utf8');
console.log('新增',add,'| 跳过(drop旧图)',skip,'| 索引条目',Object.keys(out).length);
const no=merged.filter(p=>!out[p.id]).map(p=>p.name);
console.log('仍无图',no.length,'人:',no.join('、'));
