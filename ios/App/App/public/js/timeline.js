/* ============================================================
   timeline.js — 时间轴首页：12 期导航 / 朱砂轴 / 卡片流 / IO 入场
   ============================================================ */

import {
  esc,
  icon,
  seal,
  verdictSeal,
  yearMarkup,
  eraStartText,
  fmtYear,
  emptyStateHTML,
} from './ui.js';
import { filterBattles } from './data.js';
import { filters, hasFilters, clearFilters, filterCountText, loadRecent } from './store.js';
import { navigate } from './router.js';
import { openFilterSheet } from './filter.js';
import { initLargeTitle, playCardFlipBack } from './motion.js';

let cleanup = null;
let activeEraId = '';
let suppressHighlightUntil = 0;

export function disposeTimeline() {
  if (typeof cleanup === 'function') cleanup();
  cleanup = null;
}

function pad2(n) {
  return String(n).padStart(2, '0');
}

/* ---------------- 头部 ---------------- */
function headerHTML(ctx, visibleIds) {
  const { data } = ctx;
  const eras = data.eras;
  const eraChips = eras
    .map((era) => {
      const empty = hasFilters() && !data.sections.find((s) => s.era.id === era.id)?.battles.some((b) => visibleIds.has(b.id));
      return `<button class="era-chip${empty ? ' is-empty' : ''}" type="button" data-era="${esc(era.id)}" ${
        empty ? 'aria-disabled="true"' : ''
      }>
        <span class="era-chip-idx">${pad2(era.index)}</span>
        <span class="era-chip-name">${esc(era.short || era.name)}</span>
      </button>`;
    })
    .join('');

  return `<header class="tl-head">
    <div class="brand">
      <div class="brand-main">
        <h1 class="brand-title"><a class="brand-link" href="#/" data-action="cover-top" aria-label="回到卷首">山河战纪<span class="brand-seal" aria-hidden="true">纪</span></a></h1>
        <p class="brand-sub">从涿鹿到加勒万 · 中国战史时间轴</p>
      </div>
      <div class="brand-actions">
        <button class="icon-btn" type="button" data-action="search" aria-label="搜索战役">${icon('search')}</button>
        <button class="icon-btn filter-btn${hasFilters() ? ' has-filter' : ''}" type="button" data-action="filter" aria-label="筛选战役">
          ${icon('filter')}<span class="filter-dot" aria-hidden="true"></span>
        </button>
      </div>
    </div>
    <nav class="era-nav no-scrollbar" id="eraNav" aria-label="时期导航">${eraChips}</nav>
    <div class="tl-ticker">
      <span class="ticker-era"><i class="ticker-dot" id="tickerDot"></i>当前 · <b id="tickerName">—</b></span>
      <span class="ticker-range" id="tickerRange">—</span>
    </div>
  </header>`;
}

/* ---------------- 卷首 ---------------- */
function dayIndex(n) {
  const now = new Date();
  const start = Date.UTC(2020, 0, 1);
  const days = Math.floor((Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()) - start) / 86400000);
  return ((days % n) + n) % n;
}

function coverSide(name) {
  return String(name || '')
    .replace('中国人民解放军', '解放军')
    .replace('中国人民志愿军', '志愿军')
    .replace('国民党军', '国军')
    .replace('日本军队', '日军')
    .replace('联合国军', '联军');
}

function coverHTML(ctx) {
  const { data } = ctx;
  const battles = data.battles || [];
  if (!battles.length) return '';
  const today = battles[dayIndex(battles.length)];
  const recent = loadRecent()
    .map((id) => data.byId.get(id))
    .find(Boolean);
  const cont = recent || battles[0];
  const todayEra = data.eraById.get(today.eraId);
  const contEra = data.eraById.get(cont.eraId);
  return `<section class="tl-cover" aria-label="卷首">
    <div class="cover-top">
      <span class="cover-kicker">卷首 · 开卷</span>
      <p class="cover-line">四千六百年山河，一条长卷；从今日一役，或上次读到的战役继续。</p>
    </div>
    <div class="cover-grid">
      <a class="cover-card cover-today" href="#/battle/${encodeURIComponent(today.id)}">
        <span class="cover-tag"><i class="cover-dot" aria-hidden="true"></i>今日一役</span>
        <span class="cover-year">${esc(today.yearText)}</span>
        <strong class="cover-name">${esc(today.name)}</strong>
        <span class="cover-meta">${esc(todayEra?.short || todayEra?.name || '')} · ${esc(
    today.sides.map((s) => coverSide(s.name)).join(' 对 ')
  )}</span>
        <span class="cover-go">开卷 →</span>
      </a>
      <a class="cover-card cover-continue" href="#/battle/${encodeURIComponent(cont.id)}">
        <span class="cover-tag">${recent ? '继续阅读' : '从这里开始'}</span>
        <span class="cover-year">${esc(cont.yearText)}</span>
        <strong class="cover-name">${esc(cont.name)}</strong>
        <span class="cover-meta">${recent ? '上次读到' : '第一篇'} · ${esc(contEra?.short || contEra?.name || '')}</span>
        <span class="cover-go">${recent ? '续读 →' : '开读 →'}</span>
      </a>
    </div>
    <nav class="cover-entries" aria-label="快捷入口">
      <a class="cover-entry" href="#/map">${icon('pin')}<span>战役地图</span></a>
      <a class="cover-entry" href="#/factions">${icon('layers')}<span>势力版图</span></a>
      <a class="cover-entry" href="#/clan">${icon('user')}<span>家族谱</span></a>
      <a class="cover-entry" href="#/graph">${icon('compass')}<span>关系图谱</span></a>
    </nav>
  </section>`;
}

function introHTML(data) {
  const span = data.yearSpan > 0 ? `约 ${(Math.round(data.yearSpan / 100) * 100).toLocaleString('zh-CN')} 年` : '';
  return `<div class="tl-intro">
    <span class="intro-rule" aria-hidden="true"></span>
    <div class="intro-copy">
      <p class="intro-counts"><b>${data.eras.length}</b> 期 · <b>${data.total}</b> 场 ${span ? `· ${span}` : ''}</p>
      <p class="intro-hint">下滑阅读 · 轻点卡片看详情
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v14m0 0 5-5m-5 5-5-5"/></svg>
      </p>
    </div>
  </div>`;
}

function filterBarHTML(visibleCount) {
  if (!hasFilters()) return '';
  return `<div class="filter-bar">
    已筛选 · ${esc(filterCountText())} · 命中 <span class="fb-count">${visibleCount}</span> 场
    <button class="fb-clear" type="button" data-action="clear-filter">清除</button>
  </div>`;
}

/* ---------------- 卡片 ---------------- */
function sidesHTML(battle) {
  const winner = battle.result.winner;
  return battle.sides
    .map((side, i) => {
      const key = i === 0 ? 'A' : 'B';
      let cls = '';
      if (winner === key) cls = ' is-win';
      else if (winner === 'A' || winner === 'B') cls = ' is-lose';
      return `<span class="side${cls}">${esc(side.name)}</span>`;
    })
    .join('<span class="vs">对</span>');
}

function cardHTML(battle, i) {
  const deciding = battle.scale === '战略决战';
  const tags = battle.type
    .slice(0, 2)
    .map((t) => `<span class="tag${t === '抵御外侮' ? ' tag--cinnabar' : ''}">${esc(t)}</span>`)
    .join('');
  return `<a class="tl-card${deciding ? ' is-deciding' : ''}" href="#/battle/${encodeURIComponent(battle.id)}" data-battle="${esc(
    battle.id
  )}">
    <span class="tl-node" aria-hidden="true"></span>
    <span class="card-corner" aria-hidden="true"></span>
    <div class="card-top">
      <div class="card-year">${yearMarkup(battle)}</div>
      ${verdictSeal(battle)}
    </div>
    <div class="card-name-row">
      <h3 class="card-name">${esc(battle.name)}</h3>
      ${deciding ? '<span class="deciding-badge">战略决战</span>' : ''}
    </div>
    <div class="card-sides">${sidesHTML(battle)}</div>
    <p class="card-summary">${esc(battle.summary)}</p>
    <div class="card-foot">
      ${tags}
      <span class="card-index">${pad2(i + 1)}</span>
    </div>
  </a>`;
}

function eraSectionHTML(era, battles, hidden) {
  const range = era.rangeText || `${fmtYear(era.startYear)} — ${fmtYear(era.endYear)}`;
  return `<section class="era-section" id="${esc(era.id)}" data-era="${esc(era.id)}" style="--era:${esc(
    era.themeColor
  )}"${hidden ? ' hidden' : ''}>
    <div class="era-mark" aria-hidden="true">
      <span class="era-mark-year">${esc(eraStartText(era))}</span>
      <span class="era-mark-rule"></span>
    </div>
    <header class="era-head">
      <p class="era-kicker"><span class="era-dot"></span>第 ${pad2(era.index)} 期</p>
      <h2 class="era-name">${esc(era.name)}</h2>
      <p class="era-range">${esc(range)} · ${battles.length} 场</p>
      <p class="era-tagline">${esc(era.tagline)}</p>
    </header>
    <div class="era-battles">
      ${battles.map((b, i) => cardHTML(b, i)).join('')}
    </div>
  </section>`;
}

function timelineLegendHTML() {
  return `<div class="tl-legend" aria-label="时间轴图例">
    <span class="tll-item"><i class="tll-node"></i>战役节点</span>
    <span class="tll-item"><i class="tll-node is-deciding"></i>规模决战（戈形）</span>
    <span class="tll-item"><i class="tll-seal">胜</i>结果印章</span>
    <span class="tll-item"><i class="tll-tag">类型</i>标签</span>
  </div>`;
}

function timelineHTML(ctx, visibleIds) {
  const { data } = ctx;
  const sections = data.sections.map(({ era, battles }) => {
    const shown = battles.filter((b) => visibleIds.has(b.id));
    return eraSectionHTML(era, shown, shown.length === 0);
  });

  return `<div class="timeline" id="timeline">${sections.join('')}
    <footer class="timeline-end">
      ${seal('卷终', { size: 'sm', cls: 'end-seal', vertical: false })}
      <p>山河未已 · 十二期一百二十场已全<br>考据与版图持续修订</p>
      <button class="btn btn--ghost" type="button" data-action="back-top">${icon('arrow')} 回到卷首</button>
    </footer>
  </div>`;
}

function emptyDataHTML(ctx) {
  const isFixture = ctx.data.source === 'fixture';
  return `<div class="timeline-page">
    <header class="tl-head">
      <div class="brand">
        <div class="brand-main">
          <h1 class="brand-title">山河战纪<span class="brand-seal" aria-hidden="true">纪</span></h1>
          <p class="brand-sub">从涿鹿到加勒万 · 中国战史时间轴</p>
        </div>
      </div>
    </header>
    ${emptyStateHTML({
      title: '兵器未至，长卷待启',
      desc: isFixture
        ? '正在使用开发期内存样例数据，真实数据接入后将自动切换。'
        : '数据文件尚未就绪（www/data/）。请确认 eras.json 与 era-01…12.json 已生成后重试。',
      actions: '<button class="btn btn--gold" type="button" data-action="retry">重新载入</button>',
    })}
  </div>`;
}

/* ---------------- 事件 & 观察者 ---------------- */
function bindEvents(root, ctx) {
  root.querySelector('.brand-actions')?.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-action]');
    if (!btn) return;
    if (btn.dataset.action === 'search') navigate('/search');
    if (btn.dataset.action === 'filter') openFilterSheet(ctx);
  });

  root.querySelector('.era-nav')?.addEventListener('click', (e) => {
    const chip = e.target.closest('.era-chip');
    if (!chip || chip.classList.contains('is-empty')) return;
    const eraId = chip.dataset.era;
    const section = root.querySelector(`.era-section[data-era="${eraId}"]`);
    if (!section) return;
    suppressHighlightUntil = performance.now() + 900;
    setActiveEra(root, ctx, eraId, { scrollNav: true });
    section.scrollIntoView({ behavior: prefersReduced() ? 'auto' : 'smooth', block: 'start' });
  });

  root.querySelector('.filter-bar')?.addEventListener('click', (e) => {
    if (e.target.closest('[data-action="clear-filter"]')) {
      clearFilters();
      ctx.rerenderHome({ toTop: true });
    }
  });

  root.querySelector('[data-action="back-top"]')?.addEventListener('click', () => {
    window.scrollTo({ top: 0, behavior: prefersReduced() ? 'auto' : 'smooth' });
  });

  root.querySelector('[data-action="cover-top"]')?.addEventListener('click', (e) => {
    e.preventDefault();
    window.scrollTo({ top: 0, behavior: prefersReduced() ? 'auto' : 'smooth' });
  });

  root.querySelector('[data-action="retry"]')?.addEventListener('click', () => window.location.reload());

  const emptyClear = root.querySelector('[data-action="clear-filter-empty"]');
  emptyClear?.addEventListener('click', () => {
    clearFilters();
    ctx.rerenderHome({ toTop: true });
  });
}

function prefersReduced() {
  return document.documentElement.dataset.motion === 'reduce';
}

function setActiveEra(root, ctx, eraId, { scrollNav = true } = {}) {
  if (!eraId || activeEraId === eraId) {
    if (eraId) updateTicker(root, ctx, eraId);
    return;
  }
  activeEraId = eraId;
  root.querySelectorAll('.era-chip').forEach((chip) => {
    chip.classList.toggle('is-active', chip.dataset.era === eraId);
  });
  updateTicker(root, ctx, eraId);
  if (scrollNav) {
    const nav = root.querySelector('.era-nav');
    const chip = root.querySelector(`.era-chip[data-era="${eraId}"]`);
    if (nav && chip) {
      const left = chip.offsetLeft - nav.clientWidth / 2 + chip.offsetWidth / 2;
      nav.scrollTo({ left: Math.max(0, left), behavior: prefersReduced() ? 'auto' : 'smooth' });
    }
  }
}

function updateTicker(root, ctx, eraId) {
  const era = ctx.data.eraById.get(eraId);
  if (!era) return;
  const nameEl = root.querySelector('#tickerName');
  const rangeEl = root.querySelector('#tickerRange');
  const dotEl = root.querySelector('#tickerDot');
  if (nameEl) nameEl.textContent = era.name;
  if (rangeEl) rangeEl.textContent = era.rangeText || `${fmtYear(era.startYear)} — ${fmtYear(era.endYear)}`;
  if (dotEl) dotEl.style.setProperty('--era', era.themeColor);
}

function setupObservers(root, ctx) {
  const cleanups = [];

  // 卡片入场：IntersectionObserver（不监听 scroll）
  const timelineEl = root.querySelector('.timeline');
  const cards = [...root.querySelectorAll('.tl-card')];
  if (timelineEl && cards.length) {
    timelineEl.classList.add('reveal-armed');
    // stagger 参数：同一期内按 i 错开，配合 motion.css 的 blurUp
    cards.forEach((card) => {
      card.classList.add('m-reveal');
      const group = card.closest('.era-battles');
      const idx = group ? [...group.querySelectorAll('.tl-card')].indexOf(card) : 0;
      card.style.setProperty('--m-delay', `${Math.min(6, idx) * 45}ms`);
    });
    if ('IntersectionObserver' in window) {
      const revealIO = new IntersectionObserver(
        (entries, observer) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              entry.target.classList.add('is-in');
              observer.unobserve(entry.target);
            }
          });
        },
        { threshold: 0.16, rootMargin: '0px 0px -6% 0px' }
      );
      cards.forEach((card) => revealIO.observe(card));
      cleanups.push(() => revealIO.disconnect());

      // 首屏安全兜底：确保首屏卡片立即显示（无滚动监听）
      requestAnimationFrame(() => {
        cards.forEach((card) => {
          if (card.classList.contains('is-in')) return;
          const rect = card.getBoundingClientRect();
          if (rect.top < window.innerHeight * 0.95 && rect.bottom > 0) {
            card.classList.add('is-in');
            revealIO.unobserve(card);
          }
        });
      });
    } else {
      cards.forEach((card) => card.classList.add('is-in'));
    }
  }

  // 时期高亮：观察 section，滚动时同步 12 期导航
  if ('IntersectionObserver' in window) {
    const eraIO = new IntersectionObserver(
      (entries) => {
        if (performance.now() < suppressHighlightUntil) return;
        let best = null;
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            if (!best || entry.boundingClientRect.top < best.boundingClientRect.top) best = entry;
          }
        });
        if (best) setActiveEra(root, ctx, best.target.dataset.era);
      },
      { rootMargin: '-128px 0px -56% 0px', threshold: 0 }
    );
    root.querySelectorAll('.era-section:not([hidden])').forEach((section) => eraIO.observe(section));
    cleanups.push(() => eraIO.disconnect());
  }

  // 初始高亮：优先恢复滚动位置附近，其次第一期
  const firstEra = ctx.data.eras[0];
  if (firstEra) {
    setActiveEra(root, ctx, firstEra.id, { scrollNav: false });
    requestAnimationFrame(() => {
      const sections = [...root.querySelectorAll('.era-section:not([hidden])')];
      const marker = 170;
      const current = sections.find((s) => {
        const rect = s.getBoundingClientRect();
        return rect.top <= marker && rect.bottom > marker;
      });
      if (current) setActiveEra(root, ctx, current.dataset.era, { scrollNav: true });
    });
  }

  cleanup = () => cleanups.forEach((fn) => fn());
  cleanups.push(initLargeTitle(root));
}

/* ---------------- 主渲染 ---------------- */
export function renderTimeline(root, ctx, route) {
  disposeTimeline();
  activeEraId = '';

  const { data } = ctx;
  if (!data || !data.ok || !data.eras.length) {
    root.innerHTML = emptyDataHTML({ data: data || { source: 'none' } });
    bindEvents(root, ctx);
    return;
  }

  const visible = filterBattles(data.battles, filters);
  const visibleIds = new Set(visible.map((b) => b.id));

  let body;
  if (visible.length === 0) {
    body = `<div class="tl-empty">${emptyStateHTML({
      title: '这个条件下暂无战役',
      desc: '试试放宽类型，或清除时期筛选，重新顺着时间轴读下去。',
      actions: '<button class="btn btn--gold" type="button" data-action="clear-filter-empty">清除筛选</button>',
    })}</div>`;
  } else {
    body = timelineHTML(ctx, visibleIds);
  }

  root.innerHTML = `<div class="timeline-page">
    ${headerHTML(ctx, visibleIds)}
    ${coverHTML(ctx)}
    ${introHTML(data)}
    ${timelineLegendHTML()}
    ${filterBarHTML(visible.length)}
    ${body}
  </div>`;

  bindEvents(root, ctx);
  setupObservers(root, ctx);
  playCardFlipBack(root);
  if (route?.anchor) {
    requestAnimationFrame(() => {
      const sec = root.querySelector(`.era-section[data-era="${CSS.escape(route.anchor)}"]`) || document.getElementById(route.anchor);
      if (sec) sec.scrollIntoView({ behavior: prefersReduced() ? 'auto' : 'smooth', block: 'start' });
    });
  }
}
