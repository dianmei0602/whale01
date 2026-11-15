const fs=require('fs');
const DIR=__dirname;
const UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/126.0 Safari/537.36';
const H={'Content-Type':'application/json;charset=utf-8','Referer':'https://minghuaji.dpm.org.cn/','User-Agent':UA};
const TASKS=[
 {id:'yang_pu',name:'杨溥',kw:['杨溥','杨文定','杨文定公像','杨文定公']},
 {id:'guo_zixing',name:'郭子兴',kw:['郭子兴','郭子兴像','濠州郭子兴']},
 {id:'qi_tai',name:'齐泰',kw:['齐泰','齐泰像','齐德之']},
 {id:'wan_guifei',name:'万贵妃',kw:['万贵妃','万氏','明孝宗皇后']},
 {id:'changping',name:'长平公主',kw:['长平公主','坤道公主','长平公主像']},
 {id:'extra_taizu_yixiang',name:'朱元璋异相像',kw:['明太祖画像','明太祖正形像','朱元璋画像','明太祖行乐图']}
];
async function baike(kw){
  const u='https://baike.baidu.com/api/openapi/BaikeLemmaCardApi?scope=103&format=json&appid=379020&bk_key='+encodeURIComponent(kw)+'&bk_length=600';
  try{const r=await fetch(u,{headers:{'User-Agent':UA}});const j=await r.json();return j.image?{image:j.image,title:j.title,url:j.url}:null}catch(e){return null}
}
async function dpm(kw){
  try{
    const r=await fetch('https://minghuaji.dpm.org.cn/search/queryList',{method:'POST',headers:H,body:JSON.stringify({k:kw})});
    const j=await r.json();const pl=j.result&&j.result.paintingList;
    if(!pl||!pl.records||!pl.records.length)return null;
    const rec=pl.records[0];
    return {image:rec.imagePath,title:rec.name,url:'https://minghuaji.dpm.org.cn/paint/detail?id='+rec.id,from:'dpm'};
  }catch(e){return null}
}
(async()=>{
  const out=[];
  for(const t of TASKS){
    let hit=null;
    for(const k of t.kw){
      const b=await baike(k);
      if(b){hit={...b,via:'baike:'+k,referer:'https://baike.baidu.com/'};break}
      const d=await dpm(k);
      if(d){hit={...d,via:'dpm:'+k,referer:'https://minghuaji.dpm.org.cn/'};break}
    }
    if(hit){
      const url=hit.image.split('?')[0]+(hit.via.startsWith('baike')?'?x-bce-process=image/resize,w_800/format,f_jpg':'');
      try{
        const r=await fetch(url,{headers:{'User-Agent':UA,'Referer':hit.referer}});
        const buf=Buffer.from(await r.arrayBuffer());
        const ok=buf.length>2000&&((buf[0]===0xFF&&buf[1]===0xD8)||(buf[0]===0x89&&buf[1]===0x50));
        if(ok){
          const fn=t.id+'.jpg';
          fs.writeFileSync(DIR+'/images/'+fn,buf);
          out.push({id:t.id,name:t.name,file:'images/'+fn,from:hit.via.startsWith('baike')?('百度百科「'+hit.title+'」词条配图'):('故宫名画记　'+hit.title),pageUrl:hit.url,note:'下载并验证成功',via:hit.via,bytes:buf.length});
        } else out.push({id:t.id,name:t.name,file:null,reason:'下载内容非图片 '+buf.length});
      }catch(e){out.push({id:t.id,name:t.name,file:null,reason:e.message})}
    } else out.push({id:t.id,name:t.name,file:null,reason:'未检索到候选'});
    console.log(t.name,'->',out[out.length-1].file||out[out.length-1].reason);
  }
  fs.writeFileSync(DIR+'/_img_extra.json',JSON.stringify(out,null,1),'utf8');
})();
