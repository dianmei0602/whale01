const fs=require('fs');
const DIR=__dirname;
const ROOT=DIR+'/../大明王朝文案/content';

const roster=JSON.parse(fs.readFileSync(ROOT+'/roster.json','utf8'));
const nameToId={}, idToPerson={};
roster.people.forEach(p=>{nameToId[p.name]=p.id;idToPerson[p.id]=p});

// 1. agent 五组数据
const files=['_data_p1.json','_data_p2.json','_data_p3.json','_data_p4.json','_data_existing.json'];
let agentWith=[],agentWithout=[];
for(const f of files){const j=JSON.parse(fs.readFileSync(DIR+'/'+f,'utf8'));agentWith.push(...j.with);agentWithout.push(...j.without)}

// 2. 手写详尽数据（独立源，避免与展示层耦合）
const hand=JSON.parse(fs.readFileSync(DIR+'/_data_hand.json','utf8'));

// 3. 别名映射：手写名 -> roster id
const alias={
 '朱元璋':'zhu_yuanzhang','朱棣':'zhu_di','朱高炽':'zhu_gaochi','朱瞻基':'zhu_zhanji',
 '朱祁镇':'zhu_qizhen','朱见深':'zhu_jianshen','朱祐樘':'zhu_youtang','朱厚照':'zhu_houzhao',
 '朱厚熜':'zhu_houcong','朱载坖':'zhu_zaihou','朱翊钧':'zhu_yijun','朱常洛':'zhu_changluo',
 '朱由校':'zhu_youxiao','王守仁':'wangyangming','马皇后':'ma_huanghou','徐皇后':'xu_huanghou',
 '张太后':'zhang_taihou','李太后':'li_taihou','王阳明':'wangyangming','徐渭':'xu_wei',
 '史可法':'shi_kefa','郑成功':'zhengchenggong','戚继光':'qijiguang','于谦':'yuqian',
 '张居正':'zhangjuzheng','海瑞':'hairui','袁崇焕':'yuanchonghuan','李自成':'li_zicheng',
 '张献忠':'zhang_xianzhong','魏忠贤':'weizhongxian','建文帝':'zhu_yunwen','景泰帝':'zhu_qiyu',
 '崇祯帝':'zhu_youjian','王时敏':null,'张卿子':null,'葛一龙':null,'顾梦游':null,'赵士锷':null,
 '董其昌':null,'沛然':null,'李醉鸥':null,'徐明伯':null,'赵赓':null,'胡尔慥':null,'侯侗曾':null,
 '黄道周':null,'吴北海':null,'俞安期':null,'潘琴台':null,'严用晦':null,'柳敬亭':null,
 '黄尊素':null,'利玛窦':null,'徐光启':null,'刘伯渊':null,'刘宪宠':null,'李日华':null,
 '汪庆百':null,'何斌':null,'徐应登':null,'童学颜':null,'罗应斗':null,'葛寅亮':null,
 '王以宁':null,'陶崇道':null,'朱元璋异相像':null,'兴献王':null,'徐达':'xuda','常遇春':'changyuchun'
};

// 4b. 附图：本地图像索引（由采集脚本生成）
let imgIndex={};
try{ imgIndex=JSON.parse(fs.readFileSync(DIR+'/_images.json','utf8')); }catch(e){ console.log('warning: _images.json 未找到'); }

// 5. 合并：agent 为基底（保证 roster id 与 208 覆盖），手写详尽版按 roster id 覆盖
const finalMap=new Map();
agentWith.forEach(p=>finalMap.set(p.id,{...p,inRoster:true}));
let override=0,extra=0;
hand.forEach(p=>{
  const rid=alias[p.name]!==undefined?alias[p.name]:nameToId[p.name];
  if(rid&&finalMap.has(rid)){
    finalMap.set(rid,{...p,id:rid,inRoster:true});override++;
  }else if(rid&&!finalMap.has(rid)){
    finalMap.set(rid,{...p,id:rid,inRoster:true});extra++;
  }else if(rid===null){
    const eid='extra_'+p.id;
    finalMap.set(eid,{...p,id:eid,inRoster:false});extra++;
  }else{
    // 手写版中名字与 roster 不匹配且非别名白名单的，视为重复条目丢弃（如后妃庙号 vs 原名）
    // 白名单：真正 roster 外的人物（曾鲸写真对象、利玛窦等）
    const keepExtra=new Set(['xuweii','taizu_yixiang','matic','xuguangqi','taizu','chengzu','xingxianwang',
      'wangshimin','zhangqingzi','geyilong','gumengyou','zhaoshie','dongqichang','peiran','lizuiao',
      'xumingbo','zhaogeng','huercao','houtongzeng','huangdaozhou','wubeihai','yuanqiqi','panqintai',
      'yanyonghui','liujingting','huangzunsu','liuzhi','lixianchong','lirihua','wangqingbai','hebin',
      'xuyingdeng','tongxueyan','luoyingdou','geyinliang','wangyining','taochongdao']);
    if(keepExtra.has(p.id)){finalMap.set(p.id,{...p,inRoster:false});extra++;}
    else{/* dropped: hand-written duplicate under temple name */}
  }
});

const finalWith=[...finalMap.values()];
const rosterIds=new Set(roster.people.map(p=>p.id));
const covered=new Set(finalWith.filter(p=>p.inRoster).map(p=>p.id));
const withInRoster=roster.people.filter(p=>covered.has(p.id));
const withoutInRoster=agentWithout.filter(p=>!covered.has(p.id));

// 校验
const dup=finalWith.map(p=>p.id).filter((x,i,a)=>a.indexOf(x)!==i);
console.log('agent with',agentWith.length,'| hand',hand.length,'| override',override,'| extra',extra);
console.log('final with',finalWith.length,'| inRoster',withInRoster.length,'| extra',finalWith.length-withInRoster.length);
console.log('without',withoutInRoster.length,'| with+without',withInRoster.length+withoutInRoster.length,'(should be 208)');
console.log('duplicate ids',dup.length,dup);
const grades={};finalWith.forEach(p=>grades[p.grade]=(grades[p.grade]||0)+1);
console.log('grades',JSON.stringify(grades));
const missing=roster.people.filter(p=>!covered.has(p.id)&&!withoutInRoster.find(x=>x.id===p.id));
console.log('roster uncovered',missing.length,missing.map(p=>p.id).join(' '));

// 按 grade + id 排序
const order={A:0,B:1,C:2};
finalWith.sort((a,b)=>(order[a.grade]-order[b.grade])||a.name.localeCompare(b.name,'zh'));
withoutInRoster.sort((a,b)=>a.id.localeCompare(b.id));

const merged={with:finalWith,without:withoutInRoster};
// 附加图像信息
let imgCount=0;
finalWith.forEach(p=>{ const im=imgIndex[p.id]; if(im&&im.file){ p.image=im.file; p.imgFrom=im.from||''; p.imgPage=im.pageUrl||''; p.imgNote=im.note||''; p.imgKind=im.kind||''; imgCount++; } });
console.log('附图条目',imgCount);
fs.writeFileSync(DIR+'/_merged.json',JSON.stringify(merged,null,1),'utf8');
console.log('written _merged.json');

// 幂等注入展示层
let html=fs.readFileSync(DIR+'/index.html','utf8');
const a=html.indexOf('/*DATA_START*/'), b=html.indexOf('/*DATA_END*/');
if(a<0||b<0)throw new Error('DATA markers not found in index.html');
const json=JSON.stringify(merged).replace(/</g,'\\u003c');
const block='/*DATA_START*/\nconst MERGED='+json+';\nconst DATA=MERGED.with;\nconst WITHOUT=MERGED.without;\n/*DATA_END*/';
html=html.slice(0,a)+block+html.slice(b+'/*DATA_END*/'.length);
fs.writeFileSync(DIR+'/index.html',html,'utf8');
console.log('injected into index.html');
