/* ============================================================
   atlas.js — 3.2 P3 #/atlas 时代总览
   甘特总览（12 期色带 / 120 战役节点 / 20 势力条）+ 12 期索引 + 关系入口
   ============================================================ */

import { esc, icon, fmtYear } from './ui.js';
import { navigate, navigateBack } from './router.js';

const CSS_HREF = 'css/atlas.css';
let cssLoaded = false;

function ensureCss() {
  if (cssLoaded || document.querySelector(`link[href="${CSS_HREF}"]`)) {
    cssLoaded = true;
    return;
  }
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = CSS_HREF;
  document.head.appendChild(link);
  cssLoaded = true;
}

function ganttSVG(ctx) {
  const data = ctx.data;
  const factions = [...(data.factions || [])].sort((a, b) => a.startYear - b.startYear);
  const battles = data.battles || [];
  const minYear = Math.min(...(data.eras || []).map((e) => e.startYear), -2100);
  const maxYear = Math.max(...(data.eras || []).map((e) => e.endYear), 1950);
  const W = 780;
  const PAD_L = 100;
  const PAD_R = 16;
  const x = (year) => PAD_L + ((year - minYear) / (maxYear - minYear)) * (W - PAD_L - PAD_R);
  const eraTop = 30;
  const eraH = 44;
  const battleTop = 116;
  const facTop = 164;
  const rowH = 38;
  const H = facTop + factions.length * rowH + 34;
  const step = 500;
  const ticks = [];
  for (let y = Math.ceil(minYear / step) * step; y <= maxYear; y += step) {
    const px = x(y);
    ticks.push(
      `<line class="at-tick" x1="${px.toFixed(1)}" y1="${eraTop - 6}" x2="${px.toFixed(1)}" y2="${H - 16}"/>` +
        `<text class="at-tick-label" x="${px.toFixed(1)}" y="${H - 4}" text-anchor="middle">${
          y < 0 ? '前' + Math.abs(y) : y
        }</text>`
    );
  }
  const eras = (data.eras || [])
    .map((era, i) => {
      const x0 = x(era.startYear);
      const x1 = Math.max(x0 + 4, x(era.endYear));
      const labelY = eraTop + [12, 25, 38][i % 3];
      return `<a class="at-era" href="#/#${esc(era.id)}" data-atlas-go="#/#${esc(era.id)}" title="${esc(era.name)}">
        <rect x="${x0.toFixed(1)}" y="${eraTop}" width="${(x1 - x0).toFixed(1)}" height="${eraH}" rx="2" fill="${esc(
        era.themeColor
      )}" opacity="0.2"/>
        <rect x="${x0.toFixed(1)}" y="${eraTop}" width="${(x1 - x0).toFixed(1)}" height="${eraH}" rx="2" fill="none" stroke="${esc(
        era.themeColor
      )}" stroke-opacity="0.5"/>
        <text x="${((x0 + x1) / 2).toFixed(1)}" y="${labelY}" text-anchor="middle" class="at-era-label">${esc(
        era.short || era.name
      )}</text>
      </a>`;
    })
    .join('');
  const battleDots = battles
    .map((b, i) => {
      const bx = x(b.startYear);
      const by = battleTop + (i % 3) * 12;
      const deciding = b.scale === '战略决战';
      return `<a class="at-battle" href="#/battle/${encodeURIComponent(b.id)}" data-atlas-go="#/battle/${encodeURIComponent(
        b.id
      )}" aria-label="${esc(b.name)}">
        <title>${esc(b.name)} · ${esc(fmtYear(b.startYear))}</title>
        ${deciding ? `<circle cx="${bx.toFixed(1)}" cy="${by}" r="5" fill="none" stroke="#E0C060" stroke-width="1.3"/>` : ''}
        <circle class="at-battle-dot" cx="${bx.toFixed(1)}" cy="${by}" r="${deciding ? 2.4 : 3}" fill="${esc(
        b.era?.themeColor || '#B23A2E'
      )}"/>
      </a>`;
    })
    .join('');
  const rows = factions
    .map((f, i) => {
      const y = facTop + i * rowH;
      const x0 = x(f.startYear);
      const x1 = Math.max(x0 + 4, x(f.endYear));
      const nearRight = x1 > W - 120;
      const yearX = nearRight ? x0 - 7 : x1 + 7;
      const yearAnchor = nearRight ? 'end' : 'start';
      return `<a class="at-faction" href="#/factions/${encodeURIComponent(f.id)}" data-atlas-go="#/factions/${encodeURIComponent(
        f.id
      )}" aria-label="${esc(f.name)}">
        <text class="at-fname" x="8" y="${y + 22}">${esc(f.name)}</text>
        <rect x="${x0.toFixed(1)}" y="${y + 9}" width="${(x1 - x0).toFixed(1)}" height="16" rx="3" fill="${esc(
        f.color
      )}" opacity="0.82"/>
        <text class="at-fyear" x="${yearX.toFixed(1)}" y="${y + 22}" text-anchor="${yearAnchor}">${esc(
        `${fmtYear(f.startYear)}—${fmtYear(f.endYear)}`
      )}</text>
      </a>`;
    })
    .join('');
  return `<svg class="atlas-svg" viewBox="0 0 ${W} ${H}" role="img" aria-label="12 期、120 场战役与 20 个势力的甘特总览">
    <g class="at-grid">${ticks.join('')}</g>
    <text class="at-band-label" x="8" y="${eraTop + 15}">12 期</text>
    <g class="at-eras">${eras}</g>
    <text class="at-band-label" x="8" y="${battleTop + 16}">战役</text>
    <g class="at-battles">${battleDots}</g>
    <text class="at-band-label" x="8" y="${facTop + 16}">势力</text>
    <g class="at-factions">${rows}</g>
  </svg>`;
}

function pageHTML(ctx) {
  const data = ctx.data;
  const eras = data.eras || [];
  const relations = [
    ['战役地图', '120 场落位与定位', '#/map', 'map'],
    ['势力谱系', '20 势力 · 版图与国力', '#/factions', 'fac'],
    ['名将关系', '40 位 · 34 条关系', '#/graph', 'graph'],
    ['国家关系', '20 势力 + 14 外部势力', '#/graph?layer=state', 'state'],
    ['家族谱', '14 家族 · 世代与联姻', '#/clan/ying-qin', 'clan'],
    ['推演库', `${(ctx.data.replays || []).length} 场重点战役动画推演`, '#/replays', 'replay'],
    ['图例与读图', '5 节图例 · 怎么读', '#/legend', 'legend'],
  ];
  return `<div class="atlas-page">
    <header class="page-head">
      <button class="icon-btn" type="button" data-action="back" aria-label="返回">${icon('back')}</button>
      <div class="head-title">时代总览<span class="head-sub">时间 · 空间 · 关系</span></div>
      <div class="head-actions">
        <button class="icon-btn" type="button" data-action="search" aria-label="搜索">${icon('search')}</button>
      </div>
    </header>

    <div class="atlas-body">
      <section class="atlas-hero">
        <p class="at-kicker">山河战纪 · 3.2</p>
        <h1>一眼看尽 4,600 年</h1>
        <p>从涿鹿到加勒万：上方是 12 期色带、120 场战役与 20 个势力的甘特总览；下方可进入时间轴、地图、势力、关系图谱与家族谱。</p>
        <div class="at-hero-meta"><span>${data.total} 场</span><span>${eras.length} 期</span><span>${(data.factions || []).length} 势力</span><span>${(data.battles || []).length} 节点</span></div>
      </section>

      <section class="atlas-panel" aria-labelledby="atGanttTitle">
        <div class="atlas-panel-head"><h2 id="atGanttTitle">甘特总览</h2><span>全时段一屏总览 <button class="at-zoom-btn" type="button" data-atlas-zoom>放大</button></span></div>
        <div class="atlas-scroll no-scrollbar">${ganttSVG(ctx)}</div>
        <div class="atlas-legend"><span><i class="al-era"></i>12 期色带</span><span><i class="al-dot"></i>战役（金色环=决战）</span><span><i class="al-bar"></i>势力国祚</span><span>点击可进入详情</span></div>
      </section>

      <section class="atlas-panel" aria-labelledby="atEraTitle">
        <div class="atlas-panel-head"><h2 id="atEraTitle">12 期索引</h2><span>点击回到时间轴对应时期</span></div>
        <div class="at-era-chips">${eras
          .map(
            (era) =>
              `<a class="at-era-chip" href="#/#${esc(era.id)}" style="--era:${esc(era.themeColor)}"><b>${String(
                era.index
              ).padStart(2, '0')}</b><span>${esc(era.short || era.name)}</span></a>`
          )
          .join('')}</div>
      </section>

      <section class="atlas-panel" aria-labelledby="atRelTitle">
        <div class="atlas-panel-head"><h2 id="atRelTitle">关系入口</h2><span>跨视图继续阅读</span></div>
        <div class="at-rel-grid">${relations
          .map(
            ([title, desc, href, kind]) =>
              `<a class="at-rel-card at-rel-${kind}" href="${href}"><span class="at-rel-icon" aria-hidden="true">${esc(
                title.slice(0, 1)
              )}</span><span class="at-rel-main"><b>${esc(title)}</b><i>${esc(desc)}</i></span><span class="at-rel-arrow" aria-hidden="true">›</span></a>`
          )
          .join('')}</div>
      </section>
    </div>
  </div>`;
}

export function renderAtlas(root, ctx, route) {
  ensureCss();
  root.innerHTML = pageHTML(ctx);
  root.querySelector('[data-action="back"]')?.addEventListener('click', () => navigateBack());
  root.querySelector('[data-action="search"]')?.addEventListener('click', () => navigate('/search'));
  root.querySelector('.atlas-body')?.addEventListener('click', (e) => {
    const el = e.target.closest?.('[data-atlas-go]');
    if (!el) return;
    e.preventDefault();
    const target = (el.getAttribute('data-atlas-go') || '').replace(/^#/, '');
    if (target) navigate(target);
  });
  const zoomBtn = root.querySelector('[data-atlas-zoom]');
  const scroll = root.querySelector('.atlas-scroll');
  zoomBtn?.addEventListener('click', () => {
    if (!scroll) return;
    const zoomed = scroll.classList.toggle('is-zoomed');
    zoomBtn.textContent = zoomed ? '适应全宽' : '放大';
    if (zoomed) {
      requestAnimationFrame(() => {
        scroll.scrollLeft = Math.max(0, scroll.scrollWidth * 0.12);
      });
    } else {
      scroll.scrollLeft = 0;
    }
  });
}

export function disposeAtlas() {}
