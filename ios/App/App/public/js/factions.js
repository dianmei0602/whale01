/* ============================================================
   factions.js — 2.0 势力：时间带甘特图 + 20 家族卡片 + 详情
   数据：www/data/factions.json（缺失时优雅降级为空态）
   ============================================================ */

import { esc, icon, fmtYear, emptyStateHTML } from './ui.js';
import { navigate } from './router.js';
import { initBandLight, initAccordion, revealStagger } from './motion.js';

let state = null;

const CN_NUM = ['', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];

/* ---------------- 时间带 ---------------- */
function bandSVG(factions, selectedId) {
  const rows = [...factions].sort((a, b) => a.startYear - b.startYear || a.endYear - b.endYear);
  const minYear = Math.min(...rows.map((f) => f.startYear), -2100);
  const maxYear = Math.max(...rows.map((f) => f.endYear), 1950);
  const padL = 120;
  const padR = 24;
  const rowH = 46;
  const top = 40;
  const W = 1000;
  const H = top + rows.length * rowH + 34;
  const x = (year) => padL + ((year - minYear) / (maxYear - minYear)) * (W - padL - padR);
  const plotW = W - padL - padR;

  // 年代刻度：控制在 6–9 个，避免手机宽度下标签重叠
  const totalSpan = maxYear - minYear;
  const step = [500, 1000, 250, 200, 100].find((s) => (plotW * s) / totalSpan >= 90) || 500;
  const ticks = [];
  for (let y = Math.ceil(minYear / step) * step; y <= maxYear; y += step) {
    const px = x(y);
    ticks.push(
      `<line x1="${px.toFixed(1)}" y1="${top - 8}" x2="${px.toFixed(1)}" y2="${H - 28}" class="fac-tick-line"/>` +
        `<text x="${px.toFixed(1)}" y="${H - 10}" class="fac-tick-label" text-anchor="middle">${
          y < 0 ? '前' + Math.abs(y) : y
        }</text>`
    );
  }

  const bars = rows
    .map((f, i) => {
      const y = top + i * rowH;
      const x0 = x(f.startYear);
      const x1 = Math.max(x0 + 4, x(f.endYear));
      const selected = f.id === selectedId;
      const labelNearRight = x1 > W - 160;
      const labelX = labelNearRight ? x0 - 8 : x1 + 8;
      const labelAnchor = labelNearRight ? 'end' : 'start';
      return `<g class="fac-bar-row${selected ? ' is-selected' : ''}" data-faction="${esc(f.id)}" tabindex="0" role="button" aria-label="${esc(
        f.name
      )}，${esc(f.rangeText || '')}">
        <rect x="0" y="${y}" width="${W}" height="${rowH}" class="fac-row-hit"/>
        <text x="12" y="${y + rowH / 2 + 6}" class="fac-row-name">${esc(f.name)}</text>
        <rect x="${x0.toFixed(1)}" y="${y + 12}" width="${(x1 - x0).toFixed(1)}" height="22" rx="4" fill="${esc(
        f.color
      )}" class="fac-bar" opacity="${selected ? 1 : 0.82}"/>
        ${selected ? `<rect x="${x0.toFixed(1)}" y="${y + 12}" width="${(x1 - x0).toFixed(
            1
          )}" height="22" rx="4" class="fac-bar-ring"/>` : ''}
        <text x="${labelX.toFixed(1)}" y="${y + rowH / 2 + 5}" text-anchor="${labelAnchor}" class="fac-row-year">${esc(
        f.shortYearText || ''
      )}</text>
      </g>`;
    })
    .join('');

  return `<svg class="fac-band-svg" viewBox="0 0 ${W} ${H}" role="img" aria-label="20 个家族势力的起止时间带">
    <g class="fac-ticks">${ticks.join('')}</g>
    ${bars}
  </svg>`;
}

/* ---------------- 卡片 ---------------- */
function factionCardHTML(f, data, selectedId) {
  const battles = (f.keyBattles || [])
    .map((id) => data.byId.get(id))
    .filter(Boolean)
    .map(
      (b) =>
        `<a class="fac-chip fac-chip-battle" href="#/battle/${encodeURIComponent(b.id)}">${esc(b.name)}<i>${esc(
          fmtYear(b.startYear)
        )}</i></a>`
    )
    .join('');
  const generals = (f.keyGenerals || [])
    .slice(0, 5)
    .map((name) => `<a class="fac-chip fac-chip-general" href="#/generals">${esc(name)}</a>`)
    .join('');
  return `<article class="fac-card${f.id === selectedId ? ' is-selected' : ''}" data-faction-card="${esc(f.id)}" style="--fac-color:${esc(
    f.color
  )}">
    <a class="fac-card-main" href="#/factions/${encodeURIComponent(f.id)}">
      <span class="fac-seal" aria-hidden="true">${esc((f.name || '').slice(0, 1))}</span>
      <span class="fac-card-body">
        <span class="fac-name-row">
          <strong class="fac-name">${esc(f.name)}</strong>
          <span class="fac-fullname">${esc(f.fullName || '')}</span>
        </span>
        <span class="fac-meta">${esc(f.rangeText || `${fmtYear(f.startYear)} — ${fmtYear(f.endYear)}`)}${f.capital ? ` · 都 ${esc(f.capital)}` : ''}${f.founder ? ` · ${esc(f.founder)}` : ''}</span>
        <span class="fac-family">${esc(f.family || '')}</span>
        <span class="fac-tagline">${esc(f.tagline || '')}</span>
      </span>
      <span class="fac-arrow" aria-hidden="true">›</span>
    </a>
    ${battles || generals ? `<div class="fac-chips">${battles}${generals}</div>` : ''}
  </article>`;
}

/* ---------------- 列表页 ---------------- */
function listHTML(ctx, selectedId) {
  const factions = ctx.data.factions || [];
  return `<div class="factions-page">
    <header class="page-head">
      <div class="head-title">势力<span class="head-sub">${factions.length} 个家族政权 · 时间带</span></div>
      <div class="head-actions">
        <button class="icon-btn" type="button" data-action="search" aria-label="搜索战役">${icon('search')}</button>
      </div>
    </header>

    <div class="fac-body">
      <section class="fac-band-panel" aria-labelledby="facBandTitle">
        <div class="fac-section-head">
          <h2 class="fac-section-title" id="facBandTitle">势力时间带</h2>
          <span class="fac-section-note">约前 2070 — 1912</span>
        </div>
        <div class="fac-band-wrap no-scrollbar" id="facBand">${bandSVG(
          factions.map((f) => ({
            ...f,
            shortYearText: `${fmtYear(f.startYear)}—${fmtYear(f.endYear)}`,
          })),
          selectedId
        )}</div>
        <p class="fac-band-hint">点击色条选中势力；再点卡片查看兴衰。色条长度即国祚长短。</p>
      </section>

      <div class="fac-list-head">
        <span>全部家族</span>
        <span>按起止时间</span>
      </div>
      <div class="fac-cards" id="facCards">${factions.map((f) => factionCardHTML(f, ctx.data, selectedId)).join('')}</div>
    </div>
  </div>`;
}

/* ---------------- 详情页 ---------------- */
function detailHTML(ctx, faction) {
  const data = ctx.data;
  const eras = (faction.eraIds || [])
    .map((id) => data.eraById.get(id))
    .filter(Boolean)
    .map((e) => `<span class="gen-era" style="--era:${esc(e.themeColor)}">${esc(e.short || e.name)}</span>`)
    .join('');
  const battles = (faction.keyBattles || [])
    .map((id) => data.byId.get(id))
    .filter(Boolean)
    .map(
      (b) => `<a class="fac-key-battle" href="#/battle/${encodeURIComponent(b.id)}">
        <span class="fkb-year">${esc(fmtYear(b.startYear))}</span>
        <span class="fkb-name">${esc(b.name)}</span>
        <span class="fkb-result">${esc(b.result.text || '')}</span>
      </a>`
    )
    .join('');
  const generals = (faction.keyGenerals || [])
    .map((name) => `<a class="fac-key-general" href="#/generals">${esc(name)}</a>`)
    .join('');

  const section = (numText, title, body, open = true) => {
    if (!body) return '';
    const idx = accIndex++;
    const id = `facc-${idx}`;
    return `<section class="d-sec fac-acc" data-acc-card>
          <h2 class="d-sec-head"><span class="d-sec-num">${numText}</span><span class="d-sec-title">${esc(
            title
          )}</span><span class="d-sec-rule"></span><button class="fac-acc-btn" type="button" data-acc-toggle aria-expanded="${
            open ? 'true' : 'false'
          }" aria-controls="${id}" data-acc-label="收起|展开">${open ? '收起' : '展开'}</button></h2>
          <div class="m-acc${open ? ' is-open' : ''}" id="${id}"><div class="m-acc-inner"><p class="d-p">${esc(body)}</p></div></div>
        </section>`;
  };
  let accIndex = 0;

  return `<div class="faction-detail" style="--fac-color:${esc(faction.color)}">
    <header class="detail-bar">
      <button class="icon-btn" type="button" data-action="back" aria-label="返回势力列表">${icon('back')}</button>
      <div class="detail-bar-title"><span class="db-era">势力</span><span class="db-idx">${esc(faction.name)}</span></div>
      <button class="icon-btn" type="button" data-action="search" aria-label="搜索战役">${icon('search')}</button>
    </header>

    <section class="fac-hero">
      <div class="fac-hero-glow" aria-hidden="true"></div>
      <div class="fac-hero-inner">
        <div class="fac-hero-meta">
          <span class="fac-era-badge">${esc(faction.family || '家族势力')}</span>
          ${eras}
        </div>
        <h1 class="fac-hero-title"><span class="fac-hero-seal" aria-hidden="true">${esc(
          (faction.name || '').slice(0, 1)
        )}</span>${esc(faction.name)}</h1>
        <p class="fac-hero-full">${esc(faction.fullName || '')}</p>
        <p class="fac-hero-tagline">${esc(faction.tagline || '')}</p>
        <dl class="fac-hero-facts">
          <div><dt>起止</dt><dd>${esc(faction.rangeText || `${fmtYear(faction.startYear)} — ${fmtYear(faction.endYear)}`)}</dd></div>
          <div><dt>都城</dt><dd>${esc(faction.capital || '—')}</dd></div>
          <div><dt>开国</dt><dd>${esc(faction.founder || '—')}</dd></div>
          <div><dt>极盛</dt><dd>${esc(faction.peakRuler || '—')}</dd></div>
        </dl>
      </div>
    </section>

    <div class="detail-body fac-detail-body">
      ${section('壹', '兴', faction.rise)}
      ${section('贰', '衰', faction.fall)}
      ${section('叁', '制度', faction.system, false)}
      ${section('肆', '疆域', faction.territory, false)}
      ${section('伍', '遗产', faction.legacy, false)}

      ${
        battles
          ? `<section class="d-sec"><h2 class="d-sec-head"><span class="d-sec-num">陆</span><span class="d-sec-title">关键战役</span><span class="d-sec-rule"></span></h2><div class="fac-key-battles">${battles}</div></section>`
          : ''
      }
      ${
        generals
          ? `<section class="d-sec"><h2 class="d-sec-head"><span class="d-sec-num">柒</span><span class="d-sec-title">代表人物</span><span class="d-sec-rule"></span></h2><div class="fac-key-generals">${generals}</div></section>`
          : ''
      }

      <p class="fac-detail-foot">势力统计以《山河战纪》2.0 数据为准 · 起止年代取通行纪年</p>
    </div>
  </div>`;
}

/* ---------------- 入口 ---------------- */
function bindList(root, ctx) {
  const band = root.querySelector('#facBand');
  band?.addEventListener('click', (e) => {
    const row = e.target.closest('[data-faction]');
    if (!row) return;
    selectFaction(root, ctx, row.dataset.faction);
  });
  band?.addEventListener('keydown', (e) => {
    if (e.key !== 'Enter' && e.key !== ' ') return;
    const row = e.target.closest('[data-faction]');
    if (!row) return;
    e.preventDefault();
    selectFaction(root, ctx, row.dataset.faction);
  });
  root.querySelector('[data-action="search"]')?.addEventListener('click', () => navigate('/search'));
}

function selectFaction(root, ctx, id) {
  if (!state) return;
  state.selected = id;
  const faction = ctx.data.factionsById.get(id);
  if (!faction) return;
  const bandWrap = root.querySelector('#facBand');
  const wrapRows = bandWrap?.querySelectorAll('.fac-bar-row');
  wrapRows?.forEach((row) => row.classList.toggle('is-selected', row.dataset.faction === id));
  root.querySelectorAll('[data-faction-card]').forEach((card) => {
    card.classList.toggle('is-selected', card.dataset.factionCard === id);
  });
  const card = root.querySelector(`[data-faction-card="${CSS.escape(id)}"]`);
  if (card) card.scrollIntoView({ behavior: 'smooth', block: 'center' });
}

export function renderFactions(root, ctx, route) {
  disposeFactions();
  const factions = ctx.data?.factions || [];
  const id = route?.params?.id;

  if (!factions.length) {
    root.innerHTML = `<div class="factions-page">
      <header class="page-head">
        <div class="head-title">势力<span class="head-sub">2.0 数据准备中</span></div>
      </header>
      <div class="page-body">${emptyStateHTML({
        title: '势力谱系尚未载入',
        desc: 'factions.json 暂不可用或内容为空。请稍后重试；已加载的 120 场战役与名将仍可正常阅读。',
        actions:
          '<button class="btn btn--gold" type="button" data-action="retry">重新载入</button><button class="btn" type="button" data-action="home">回到时间轴</button>',
      })}</div>
    </div>`;
    root.querySelector('[data-action="retry"]')?.addEventListener('click', () => window.location.reload());
    root.querySelector('[data-action="home"]')?.addEventListener('click', () => navigate('/'));
    return;
  }

  if (id) {
    const faction = ctx.data.factionsById.get(id);
    if (!faction) {
      root.innerHTML = `<div class="factions-page">
        <header class="page-head">
          <div class="head-title">势力<span class="head-sub">未找到</span></div>
        </header>
        <div class="page-body">${emptyStateHTML({
          title: '未见此势力',
          desc: `未找到「${id}」对应的家族势力，可能链接有误。`,
          actions: '<button class="btn btn--gold" type="button" data-action="back-list">返回势力列表</button>',
        })}</div>
      </div>`;
      root.querySelector('[data-action="back-list"]')?.addEventListener('click', () => navigate('/factions'));
      return;
    }
    state = { root, ctx, selected: id };
    root.innerHTML = detailHTML(ctx, faction);
    initAccordion(root);
    root.querySelector('[data-action="back"]')?.addEventListener('click', () => navigate('/factions'));
    root.querySelector('[data-action="search"]')?.addEventListener('click', () => navigate('/search'));
    return;
  }

  state = { root, ctx, selected: '' };
  root.innerHTML = listHTML(ctx, '');
  bindList(root, ctx);
  initBandLight(root);
  revealStagger(root, '.fac-card', { stagger: 40, threshold: 0.04 });
}

export function disposeFactions() {
  state = null;
}
