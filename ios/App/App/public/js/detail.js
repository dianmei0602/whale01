/* ============================================================
   detail.js — 战役详情：水墨 Hero / 信息条 / 六段正文 / 上下场
   ============================================================ */

import {
  esc,
  icon,
  seal,
  resultSealText,
  fmtTroops,
  emptyStateHTML,
} from './ui.js';
import { inkMountain } from './ink.js';
import { pushRecent } from './store.js';
import { navigate, navigateBack } from './router.js';
import { initParallax, revealStagger, initSwipeDetail, playCardFlipIn, rememberDetailFlip } from './motion.js';
import { findPower, rangeText, precisionText, battleTerritoryHTML } from './research.js';

const SECTION_NUMS = ['壹', '贰', '叁', '肆', '伍', '陆', '柒'];

let detailCleanup = () => {};

function heroTitleHTML(name) {
  const chars = [...String(name || '')];
  return chars
    .map(
      (ch, i) =>
        `<span class="m-ch"><span class="m-ch-i" style="--i:${i}">${esc(ch)}</span></span>`
    )
    .join('');
}

function heroDisc(seed) {
  let h = 0;
  for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) >>> 0;
  return h % 3 === 0 ? 'sun' : 'moon';
}

function sectionHead(num, title) {
  return `<h2 class="d-sec-head"><span class="d-sec-num">${num}</span><span class="d-sec-title">${esc(
    title
  )}</span><span class="d-sec-rule"></span></h2>`;
}

function paragraphs(text, cls = 'd-p') {
  const chunks = String(text || '')
    .split(/\n+/)
    .map((s) => s.trim())
    .filter(Boolean);
  if (!chunks.length) return `<p class="${cls}">这一段史料暂缺，M2 将补齐。</p>`;
  return chunks.map((p) => `<p class="${cls}">${esc(p)}</p>`).join('');
}

function infoStrip(battle) {
  const era = battle.era;
  const sides = battle.sides.map((s) => s.name).join(' 对 ');
  const troops = battle.sides
    .map((s) => `${s.name} ${s.troopsText || fmtTroops(s.troopsNum) || '兵力不详'}`)
    .join('；');
  const items = [
    { k: '时间', v: battle.yearText || '' },
    { k: '古战场', v: battle.location.ancient || '待考' },
    { k: '今地', v: battle.location.modern || '待考' },
    { k: '双方', v: sides },
    { k: '兵力', v: troops },
    { k: '规模', v: battle.scale || '' },
    { k: '结果', v: battle.result.text || resultSealText(battle) },
  ];
  return `<div class="info-strip no-scrollbar">${items
    .map(
      (item) =>
        `<div class="info-item"><span class="info-k">${esc(item.k)}</span><span class="info-v">${esc(item.v)}</span></div>`
    )
    .join('')}</div>`;
}

function forceHTML(battle) {
  const max = Math.max(...battle.sides.map((s) => (s.troopsNum && s.troopsNum > 0 ? s.troopsNum : 0)), 1);
  const winner = battle.result.winner;
  return `<div class="force">
    ${battle.sides
      .map((side, i) => {
        const color = i === 0 ? 'A' : 'B';
        const hasNum = side.troopsNum && side.troopsNum > 0;
        const width = hasNum ? Math.max(6, Math.round((side.troopsNum / max) * 100)) : 0;
        const isWin = winner === color;
        const isDecided = winner === 'A' || winner === 'B';
        const troopLabel = side.troopsText || (hasNum ? `约${fmtTroops(side.troopsNum)}` : '暂无可靠数字');
        return `<div class="force-side force-${color.toLowerCase()}${isWin ? ' is-win' : ''}">
          <div class="force-top">
            <span class="force-name">${esc(side.name)}${
              isWin ? '<span class="force-flag">胜</span>' : isDecided ? '<span class="force-flag" style="color:var(--mute);border-color:var(--line-soft)">败</span>' : ''
            }</span>
            <span class="force-troops">${esc(troopLabel)}</span>
          </div>
          <div class="force-track${hasNum ? '' : ' is-unknown'}" role="img" aria-label="${esc(side.name)}兵力比例">
            ${hasNum ? `<span class="force-bar" style="width:${width}%"></span>` : ''}
          </div>
          <div class="force-cmd">主将 · ${side.commanders.length ? side.commanders.map((c) => esc(c)).join('、') : '不详'}</div>
        </div>`;
      })
      .join('')}
    <p class="force-note">兵力数字取自史料主流说法，括号内「号称」多为战时夸大；诸说异同见文末「史料与争议」。</p>
  </div>`;
}

function courseHTML(battle) {
  if (!battle.course.length) return `<p class="d-p">战役过程记述暂缺，M2 将补齐。</p>`;
  return `<ol class="course">
    ${battle.course
      .map(
        (step, i) => `<li class="course-step" data-idx="${String(i + 1).padStart(2, '0')}">
          ${step.title ? `<h3>${esc(step.title)}</h3>` : ''}
          <p>${esc(step.text)}</p>
        </li>`
      )
      .join('')}
  </ol>`;
}

function anecdotesHTML(battle, ctx) {
  const list = battle.anecdotes.length
    ? battle.anecdotes
        .map(
          (a) => `<article class="anecdote">
            ${a.title ? `<h3>${esc(a.title)}</h3>` : ''}
            <p>${esc(a.text)}</p>
          </article>`
        )
        .join('')
    : '<p class="d-p">典故暂缺，M2 将补充。</p>';
  const people = battle.people.length
    ? `<div class="people">${battle.people
        .map((p) => {
          const general = ctx?.data?.generalByName?.get(p);
          const href = general ? `#/generals?g=${encodeURIComponent(general.id)}` : `#/search?q=${encodeURIComponent(p)}&note=person`;
          const klass = general ? 'person is-general' : 'person';
          return `<a class="${klass}" href="${href}"${
            general ? '' : ' data-person-search="1" title="该人物未收录小传，点击搜索"'
          }>${esc(p)}${general ? '<i class="person-dot" aria-hidden="true"></i>' : ''}</a>`;
        })
        .join('')}</div>`
    : '';
  return `${list}${people}`;
}

function sourcesHTML(battle) {
  const sources = battle.sources.length
    ? `<ul class="sources">${battle.sources.map((s) => `<li>${esc(s)}</li>`).join('')}</ul>`
    : '<p class="d-p">出处暂缺，M2 将补齐。</p>';
  const notes = battle.notes.length
    ? `<div class="notes-box">
        <h3>存疑与传说</h3>
        ${battle.notes.map((n) => `<p>${esc(n)}</p>`).join('')}
      </div>`
    : '';
  return `${sources}${notes}`;
}

function minimapHTML(battle) {
  const loc = battle.location;
  const precision = precisionText(loc.precision);
  const coords =
    loc.lng != null && loc.lat != null
      ? `东经 ${Number(loc.lng).toFixed(2)}° · 北纬 ${Number(loc.lat).toFixed(2)}°`
      : '坐标待考';
  return `<a class="mini-map" href="#/map?battle=${encodeURIComponent(battle.id)}" aria-label="在地图中定位 ${esc(battle.name)}">
    <span class="mm-dot" aria-hidden="true"></span>
    <span class="mm-badge">地图 · 战场定位</span>
    <span class="mm-text">
      <span class="mm-title">战场位置 · ${esc(battle.location.ancient || '待考')}</span>
      <span class="mm-sub">${esc(coords)} · ${esc(precision.label)}</span>
    </span>
  </a>`;
}

function pnHTML(battle, ctx) {
  const nav = ctx.data.neighbors.get(battle.id) || {};
  const item = (target, kind) => {
    if (!target) {
      return `<div class="pn-item ${kind} is-empty">
        <span class="pn-label">${kind === 'prev' ? '上一场' : '下一场'}</span>
        <span class="pn-name">已是卷${kind === 'prev' ? '首' : '末'}</span>
      </div>`;
    }
    return `<a class="pn-item ${kind}" href="#/battle/${encodeURIComponent(target.id)}">
      <span class="pn-arrow" aria-hidden="true">${kind === 'prev' ? '‹' : '›'}</span>
      <span class="pn-label">${kind === 'prev' ? '上一场' : '下一场'}</span>
      <span class="pn-name">${esc(target.name)}</span>
      <span class="pn-year">${esc(target.yearText || '')}</span>
    </a>`;
  };
  return `<nav class="pn" aria-label="相邻战役">${item(nav.prev, 'prev')}${item(nav.next, 'next')}</nav>`;
}

function detailLegendHTML(battle) {
  const precision = precisionText(battle.location.precision);
  return `<div class="detail-legend" aria-label="图例">
    <span class="dl-item"><i class="dl-dot dl-a"></i>${esc(battle.sides[0]?.name || 'A 方')}</span>
    <span class="dl-item"><i class="dl-dot dl-b"></i>${esc(battle.sides[1]?.name || 'B 方')}</span>
    <span class="dl-item"><i class="dl-bar"></i>兵力条（相对比例）</span>
    <span class="dl-item"><i class="dl-seal"></i>结果印章</span>
    <span class="dl-item dl-precision is-${precision.tone}">位置精度 · ${esc(precision.label)}</span>
  </div>`;
}

function archiveHTML(battle) {
  const precision = precisionText(battle.location.precision);
  const casualties = battle.casualties || [];
  const sideName = (key) => battle.sides[key === 'B' ? 1 : 0]?.name || (key === 'B' ? 'B 方' : 'A 方');
  const hasAny =
    battle.duration || battle.objective || battle.terrainType || battle.arms.length || casualties.length || battle.troopsSource.length;
  if (!hasAny) {
    return `<section class="d-sec research-sec is-empty">
      <h2 class="d-sec-head"><span class="d-sec-num">档</span><span class="d-sec-title">战役档案</span><span class="d-sec-rule"></span><span class="research-badge">考据</span></h2>
      <p class="d-p research-empty">该场档案（时长 / 目的 / 地形 / 兵种 / 伤亡）尚在考据整理中。</p>
    </section>`;
  }
  const item = (label, value, cls = '') => `<div class="archive-item ${cls}"><span class="ai-k">${label}</span><span class="ai-v">${value}</span></div>`;
  const casualtyHTML = casualties.length
    ? `<div class="archive-item archive-wide"><span class="ai-k">伤亡</span><span class="ai-v">${casualties
        .map(
          (c) =>
            `<span class="casualty casualty-${c.side.toLowerCase()}"><b>${esc(sideName(c.side))}</b>${esc(c.text || '史无确载')}${
              c.note ? `<i>${esc(c.note)}</i>` : ''
            }</span>`
        )
        .join('')}</span></div>`
    : item('伤亡', '史无确载', 'archive-wide');
  return `<section class="d-sec research-sec">
    <h2 class="d-sec-head"><span class="d-sec-num">档</span><span class="d-sec-title">战役档案</span><span class="d-sec-rule"></span><span class="research-badge">考据</span></h2>
    <div class="archive-grid">
      ${item('持续时间', esc(battle.duration || '史无确载'))}
      ${item('地形', esc(battle.terrainType || '史无确载'))}
      ${item('位置精度', `<span class="precision-tag is-${precision.tone}">${esc(precision.label)}</span>${precision.desc ? `<i>${esc(precision.desc)}</i>` : ''}`)}
      ${item('双方兵种', battle.arms.length ? battle.arms.map((a) => `<span class="arm-chip">${esc(a)}</span>`).join('') : '史无确载')}
      ${battle.objective ? item('战略目的', esc(battle.objective), 'archive-wide') : item('战略目的', '史无确载', 'archive-wide')}
      ${casualtyHTML}
      ${battle.troopsSource.length ? item('兵力来源', battle.troopsSource.map((s) => esc(s)).join('、'), 'archive-wide') : ''}
    </div>
    <p class="research-foot">档案口径以通行史料与今人研究为据；无可靠数字处标注「史无确载」，不补写精确值。</p>
  </section>`;
}

function powerCardHTML(battle, ctx, side) {
  const power = findPower(ctx, side.name);
  const unknown = '史无确载';
  const rows = power
    ? [
        ['性质', power.kind],
        ['控制区域', power.territory || unknown],
        ['面积（估算）', rangeText(power.areaWanKm2, ' 万 km²')],
        ['人口（估算）', rangeText(power.populationWan, ' 万人')],
        ['可动员兵力（估算）', rangeText(power.armyWan, ' 万人')],
      ]
    : [
        ['性质', unknown],
        ['控制区域', unknown],
        ['面积（估算）', unknown],
        ['人口（估算）', unknown],
        ['可动员兵力（估算）', unknown],
      ];
  return `<article class="power-card power-${side.color.toLowerCase()}">
    <header class="power-head">
      <span class="power-name">${esc(side.name)}</span>
      ${power ? `<span class="power-kind">${esc(power.kind)}</span>` : '<span class="power-kind is-unknown">未收录</span>'}
    </header>
    <p class="power-troops"><span>本场投入</span>${esc(side.troopsText || unknown)}</p>
    <dl class="power-rows">${rows
      .map(([k, v]) => `<div><dt>${k}</dt><dd>${esc(v)}</dd></div>`)
      .join('')}</dl>
    ${power?.note ? `<p class="power-note">${esc(power.note)}${power.sources?.length ? `<span>来源：${power.sources.map((s) => esc(s)).join('、')}</span>` : ''}</p>` : ''}
  </article>`;
}

function powersHTML(battle, ctx) {
  if (!battle.sides.length) return '';
  return `<section class="d-sec research-sec powers-sec">
    <h2 class="d-sec-head"><span class="d-sec-num">势</span><span class="d-sec-title">双方势力对照</span><span class="d-sec-rule"></span><span class="research-badge">估算 · 有据</span></h2>
    <div class="power-compare">${battle.sides.map((side) => powerCardHTML(battle, ctx, side)).join('')}</div>
    <p class="research-foot">面积 / 人口 / 可动员兵力为今人研究估算区间，仅作量级参考；非单场投入兵力。无可靠记录处标注「史无确载」。</p>
  </section>`;
}

function territorySectionHTML(battle, ctx) {
  return `<section class="d-sec research-sec territory-sec">
    <h2 class="d-sec-head"><span class="d-sec-num">域</span><span class="d-sec-title">势力范围</span><span class="d-sec-rule"></span><span class="research-badge">示意</span></h2>
    <div class="bterr-grid">${battle.sides.map((side) => battleTerritoryHTML(ctx, battle, side)).join('')}</div>
    <p class="research-foot">按今省界拼合的示意范围，参考《中国历史地图集》与通行叙述，不表示精确历史边界。</p>
  </section>`;
}

function detailHTML(battle, ctx) {
  const era = battle.era || { index: '—', name: '未分期', themeColor: '#C9A227' };
  const nav = ctx.data.neighbors.get(battle.id) || {};
  const total = ctx.data.total;
  const disc = heroDisc(battle.id);

  return `<article class="detail-page" data-era="${esc(battle.eraId)}">
    <header class="detail-bar">
      <button class="icon-btn" type="button" data-action="back" aria-label="返回">${icon('back')}</button>
      <div class="detail-bar-title">
        <span class="db-era">${esc(era.name)}</span>
        <span class="db-idx">${String(era.index).padStart(2, '0')} / ${String(total).padStart(2, '0')}</span>
      </div>
      <button class="icon-btn" type="button" data-action="search" aria-label="搜索">${icon('search')}</button>
    </header>

    <section class="detail-hero">
      <div class="hero-art">${inkMountain(battle.id, { height: 430, accent: era.themeColor, disc })}</div>
      <div class="hero-shade" aria-hidden="true"></div>
      <div class="hero-content">
        <div class="hero-meta">
          <span class="hero-era">第 ${String(era.index).padStart(2, '0')} 期 · ${esc(era.name)}</span>
          <span class="hero-year">${esc(battle.yearText || '')}</span>
        </div>
        <h1 class="hero-title">${heroTitleHTML(battle.name)}</h1>
        ${battle.alias.length ? `<p class="hero-alias">别名 · ${battle.alias.map((a) => esc(a)).join('、')}</p>` : ''}
        <p class="hero-loc">${esc(battle.location.ancient || '战场待考')}${
          battle.location.modern ? `<br>今 · ${esc(battle.location.modern)}` : ''
        }</p>
        <div class="hero-result">
          ${seal(resultSealText(battle), { size: 'lg', cls: 'hero-seal m-shimmer' })}
          <div class="hero-result-text">
            <span class="hr-label">战果</span>
            <p>${esc(battle.result.text || '结果待考')}</p>
          </div>
        </div>
      </div>
    </section>

    <div class="detail-body">
      ${infoStrip(battle)}
      ${detailLegendHTML(battle)}

      ${
        ctx.data.replaysByBattle && ctx.data.replaysByBattle.get(battle.id)
          ? `<a class="btn btn--gold replay-cta" href="#/replay/${encodeURIComponent(battle.id)}" style="width:100%;margin:0 0 18px;min-height:48px;letter-spacing:.16em">
              ▶ 动画推演 · ${esc(ctx.data.replaysByBattle.get(battle.id).subtitle || '战役推演')}
            </a>`
          : ''
      }

      <blockquote class="lead">
        <span class="lead-label">一句话提要</span>
        <p>${esc(battle.summary || '提要待补。')}</p>
      </blockquote>

      ${archiveHTML(battle)}
      ${powersHTML(battle, ctx)}
      ${territorySectionHTML(battle, ctx)}

      <section class="d-sec">
        ${sectionHead(SECTION_NUMS[0], '背景')}
        ${paragraphs(battle.background)}
      </section>

      <section class="d-sec">
        ${sectionHead(SECTION_NUMS[1], '兵力与部署')}
        ${forceHTML(battle)}
      </section>

      <section class="d-sec">
        ${sectionHead(SECTION_NUMS[2], '战役经过')}
        ${courseHTML(battle)}
      </section>

      <section class="d-sec">
        ${sectionHead(SECTION_NUMS[3], '结果与影响')}
        <h3 class="d-sub">结果</h3>
        ${paragraphs(battle.outcome)}
        <h3 class="d-sub">影响</h3>
        ${paragraphs(battle.significance)}
      </section>

      <section class="d-sec">
        ${sectionHead(SECTION_NUMS[4], '典故与人物')}
        ${anecdotesHTML(battle, ctx)}
      </section>

      <section class="d-sec">
        ${sectionHead(SECTION_NUMS[5], '史料与争议')}
        ${sourcesHTML(battle)}
      </section>

      ${minimapHTML(battle)}

      ${pnHTML(battle, ctx)}

      <footer class="detail-foot">
        <span class="foot-seal">山河战纪</span>
        <br>第 ${String(nav.index || 0).padStart(2, '0')} / ${String(total).padStart(2, '0')} 场 · ${esc(
    era.name
  )}<br>史实以通行纪年为准 · 数据核校中
      </footer>
    </div>
  </article>`;
}

export function disposeDetail() {
  detailCleanup();
  detailCleanup = () => {};
}

export function renderDetail(root, ctx, route) {
  disposeDetail();
  detailCleanup = () => {};
  const id = route?.params?.id;
  const battle = ctx.data.byId.get(id);

  if (!battle) {
    root.innerHTML = `<div class="detail-page">
      <header class="detail-bar">
        <button class="icon-btn" type="button" data-action="back" aria-label="返回">${icon('back')}</button>
        <div class="detail-bar-title"><span class="db-era">未找到该战役</span></div>
      </header>
      ${emptyStateHTML({
        title: '这一页尚未写入长卷',
        desc: `未找到战役「${id || ''}」。可能是链接有误，或该战役将在 M2 内容扩充中加入。`,
        actions: '<button class="btn btn--gold" type="button" data-action="home">回到时间轴</button>',
      })}
    </div>`;
    root.querySelector('[data-action="back"]')?.addEventListener('click', () => navigateBack());
    root.querySelector('[data-action="home"]')?.addEventListener('click', () => navigate('/'));
    return;
  }

  pushRecent(battle.id);
  root.innerHTML = detailHTML(battle, ctx);

  root.querySelector('[data-action="back"]')?.addEventListener('click', () => {
    rememberDetailFlip(root.querySelector('.hero-title'), battle.id);
    navigateBack();
  });
  root.querySelector('[data-action="search"]')?.addEventListener('click', () => navigate('/search'));

  // ---------- 2.2 动效：Hero 视差 / 标题逐字 / 印章 spring / 分段 reveal / 左右滑 ----------
  const nav = ctx.data.neighbors.get(battle.id) || {};
  const cleanups = [
    initParallax(root, '.hero-art', { max: 18, speed: 0.14 }),
    revealStagger(root, '.d-sec', { stagger: 55, threshold: 0.08 }),
    initSwipeDetail(root, {
      prev: nav.prev || null,
      next: nav.next || null,
      onNavigate: (target) => navigate(`/battle/${encodeURIComponent(target.id)}`),
    }),
  ];
  playCardFlipIn(root.querySelector('.hero-title'));
  detailCleanup = () => cleanups.forEach((fn) => fn && fn());
}
