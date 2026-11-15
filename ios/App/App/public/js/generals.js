/* ============================================================
   generals.js — 名将：
   ① 名将录 · 40 人（M3.5 小传，expandable）
   ② 全部将帅 · 664（从 sides[].commanders 聚合，搜索/排序/分页）
   ============================================================ */

import { esc, icon, fmtYear, debounce, emptyStateHTML } from './ui.js';
import { navigate } from './router.js';
import { revealStagger } from './motion.js';

let state = null;
let cachedGenerals = null;
let cachedDataKey = '';
let biosPromise = null;

const SORTS = [
  ['count', '战役数'],
  ['rate', '胜率'],
  ['era', '时期'],
];

/* ---------------- 全量将帅聚合 ---------------- */
function buildGenerals(data) {
  const key = `${data.total}:${data.battles.map((b) => b.id).join(',')}`;
  if (cachedGenerals && cachedDataKey === key) return cachedGenerals;

  const map = new Map();
  for (const b of data.battles) {
    b.sides.forEach((side, i) => {
      const color = i === 0 ? 'A' : 'B';
      for (const rawName of side.commanders) {
        const name = String(rawName).trim();
        if (!name) continue;
        let g = map.get(name);
        if (!g) {
          g = { name, battles: [], eras: new Map(), sides: new Map(), wins: 0, deciding: 0, firstYear: Infinity };
          map.set(name, g);
        }
        if (g.battles.some((x) => x.id === b.id)) continue;
        g.battles.push(b);
        g.eras.set(b.eraId, b.era);
        g.sides.set(side.name, (g.sides.get(side.name) || 0) + 1);
        if (b.result.winner === color) g.wins += 1;
        if (b.scale === '战略决战') g.deciding += 1;
        if (b.startYear < g.firstYear) g.firstYear = b.startYear;
      }
    });
  }

  cachedGenerals = [...map.values()].map((g) => {
    const count = g.battles.length;
    const sideTop = [...g.sides.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] || '';
    const eraList = [...g.eras.values()].sort((a, b) => a.index - b.index);
    g.battles.sort((a, b) => a.startYear - b.startYear || a.name.localeCompare(b.name, 'zh'));
    return {
      ...g,
      count,
      rate: count ? Math.round((g.wins / count) * 100) : 0,
      sideTop,
      eraList,
      firstYear: g.firstYear === Infinity ? 0 : g.firstYear,
    };
  });
  cachedDataKey = key;
  return cachedGenerals;
}

function sortGenerals(list, sort) {
  const arr = [...list];
  if (sort === 'rate') {
    arr.sort((a, b) => b.rate - a.rate || b.count - a.count || a.name.localeCompare(b.name, 'zh'));
  } else if (sort === 'era') {
    arr.sort((a, b) => a.firstYear - b.firstYear || b.count - a.count || a.name.localeCompare(b.name, 'zh'));
  } else {
    arr.sort((a, b) => b.count - a.count || b.wins - a.wins || a.name.localeCompare(b.name, 'zh'));
  }
  return arr;
}

/* ---------------- 小传数据 ---------------- */
function loadBios() {
  if (!biosPromise) {
    biosPromise = fetch('data/generals.json', { cache: 'no-cache' })
      .then((res) => (res.ok ? res.json() : null))
      .then((list) => (Array.isArray(list) ? list : []))
      .catch(() => []);
  }
  return biosPromise;
}

function biosHTML(ctx, bios) {
  if (!bios.length) {
    return `<p class="gen-bio-loading">名将小传暂未载入（data/generals.json 不可用），下方「全部将帅」仍可浏览。</p>`;
  }
  return `<div class="gen-bio-list">${bios
    .map((g, i) => {
      const battles = (g.battles || [])
        .map((id) => ctx.data.byId.get(id))
        .filter(Boolean)
        .slice(0, 6);
      const eras = (g.eraIds || [])
        .map((id) => ctx.data.eraById.get(id))
        .filter(Boolean)
        .map((era) => `<span class="gen-era" style="--era:${esc(era.themeColor)}">${esc(era.short || era.name)}</span>`)
        .join('');
      const tags = (g.tags || [])
        .slice(0, 3)
        .map((t) => `<span class="bio-tag">${esc(t)}</span>`)
        .join('');
      const bioText = String(g.bio || '').trim();
      const pid = `bio-${i}`;
      const aliases = (g.alias || []).filter((a) => a && a !== g.title);
      const titleText = g.title && g.title !== g.name ? String(g.title) : '';
      const lifeText = g.life ? (/^生卒/.test(String(g.life)) ? String(g.life) : `生卒 · ${g.life}`) : '';
      const metaText = [lifeText, g.camp ? `阵营 · ${g.camp}` : ''].filter(Boolean).join('　');
      return `<article class="gen-bio-card" data-bio-card>
        <header class="bio-head">
          <span class="gen-seal bio-seal" aria-hidden="true">${esc(String(g.name || '').slice(0, 1))}</span>
          <div class="bio-head-main">
            <h3 class="bio-name">${esc(g.name || '')}${aliases.length ? `<span class="bio-alias">${esc(aliases.join(' / '))}</span>` : ''}</h3>
            ${titleText ? `<p class="bio-title">${esc(titleText)}</p>` : ''}
            <p class="bio-meta">${esc(metaText)}</p>
          </div>
          <span class="bio-era-row">${eras}</span>
        </header>
        <p class="bio-text">${esc(bioText)}</p>
        <div class="bio-acc m-acc" id="${pid}">
          <div class="m-acc-inner"><p class="bio-full">${esc(bioText)}</p></div>
        </div>
        <div class="bio-foot">
          <button class="bio-toggle" type="button" data-bio-toggle aria-expanded="false" aria-controls="${pid}">展开小传</button>
          <span class="bio-tags">${tags}</span>
        </div>
        ${
          battles.length
            ? `<div class="bio-battles">
                <span class="bio-battles-label">相关战役（亲历或同局）</span>
                <span class="bio-battles-note">部分名将因收录范围以同局关联补齐，详见小传。</span>
                ${battles
                  .map(
                    (b) =>
                      `<a class="bio-battle" href="#/battle/${encodeURIComponent(b.id)}">${esc(b.name)}<i>${esc(
                        fmtYear(b.startYear)
                      )}</i></a>`
                  )
                  .join('')}
              </div>`
            : ''
        }
      </article>`;
    })
    .join('')}</div>`;
}

/* ---------------- 小传区 / 全量区 ---------------- */
function featuredSectionHTML(ctx, bios) {
  return `<section class="gen-featured" aria-labelledby="genFeaturedTitle">
    <div class="gen-section-head">
      <h2 class="gen-section-title" id="genFeaturedTitle">名将录<span>40 人 · 小传</span></h2>
      <span class="gen-section-note">M3.5 内容</span>
    </div>
    <div id="genFeatured">${
      bios
        ? biosHTML(ctx, bios)
        : '<p class="gen-bio-loading">正在载入 40 位名将小传…</p>'
    }</div>
  </section>`;
}

function introHTML(data, generals, relationCount) {
  const eraCount = new Set(generals.flatMap((g) => g.eraList.map((e) => e.id))).size;
  const commanding = generals.filter((g) => g.count > 1).length;
  return `<section class="gen-intro">
    <div class="gen-intro-head">
      <h1>将星入册</h1>
      <span class="gen-intro-sub">40 位立传 · ${generals.length} 位将帅在册</span>
    </div>
    <div class="gen-stats-row">
      <span class="gen-stat"><b>${generals.length}</b><i>位将帅</i></span>
      <span class="gen-stat"><b>${commanding}</b><i>指挥 2 场以上</i></span>
      <span class="gen-stat"><b>${eraCount}</b><i>期覆盖</i></span>
      <span class="gen-stat"><b>${data.total}</b><i>关联战役</i></span>
    </div>
    <a class="gen-graph-cta m-glow" href="#/graph">
      <span class="gen-graph-cta-icon" aria-hidden="true">${icon('layers')}</span>
      <span class="gen-graph-cta-main">
        <strong>关系图谱</strong>
        <span>40 位名将 · ${relationCount} 条关系 · 点击看小传</span>
      </span>
      <span class="gen-graph-cta-arrow" aria-hidden="true">›</span>
    </a>
    <p class="gen-intro-note">小传 40 人按数据供稿撰写；全部 ${generals.length} 位将帅由 sides[].commanders 自动聚合。同一场战役中作为主将或主要将领出现即计入指挥场次；胜率按其所在一方的胜负计算，平局/未决不计胜。</p>
  </section>`;
}

function cardHTML(g) {
  const expanded = state.expanded.has(g.name);
  const eras = g.eraList
    .slice(0, 2)
    .map((e) => `<span class="gen-era" style="--era:${esc(e.themeColor)}">${esc(e.short || e.name)}</span>`)
    .join('');
  return `<article class="gen-card${expanded ? ' is-open' : ''}" data-general="${esc(g.name)}">
    <button class="gen-head" type="button" data-expand="${esc(g.name)}" aria-expanded="${expanded}">
      <span class="gen-seal" aria-hidden="true">${esc(g.name.slice(0, 1))}</span>
      <span class="gen-main">
        <span class="gen-name">${esc(g.name)}</span>
        <span class="gen-sub">${esc(g.sideTop || '阵营不详')} · 指挥 <b>${g.count}</b> 场 · <b>${g.wins}</b> 胜</span>
      </span>
      <span class="gen-right">
        <span class="gen-rate"><b>${g.rate}%</b><i>胜率</i></span>
        <span class="gen-chevron" aria-hidden="true">${icon('chevron')}</span>
      </span>
    </button>
    <div class="gen-era-row">${eras}</div>
    ${
      expanded
        ? `<div class="gen-battles">${g.battles
            .map(
              (b) => `<a class="gen-battle" href="#/battle/${encodeURIComponent(b.id)}">
                <span class="gb-year">${esc(fmtYear(b.startYear))}</span>
                <span class="gb-name">${esc(b.name)}</span>
                <span class="gb-result">${esc(b.result.text || '')}</span>
              </a>`
            )
            .join('')}</div>`
        : ''
    }
  </article>`;
}

function listHTML(generals) {
  const filtered = generals.filter((g) => !state.query || g.name.includes(state.query));
  const sorted = sortGenerals(filtered, state.sort);
  const shown = sorted.slice(0, state.limit);
  const remain = sorted.length - shown.length;

  if (!filtered.length) {
    return `<div class="gen-empty">
      <p>没有找到「${esc(state.query)}」相关的将领。</p>
      <button class="btn" type="button" data-action="clear-query">清除搜索</button>
    </div>`;
  }

  return `<div class="gen-list-head" aria-live="polite">
      <span>共 <b>${sorted.length}</b> 位将领</span>
      <span class="gen-list-sort">按${SORTS.find((s) => s[0] === state.sort)[1]}排序</span>
    </div>
    <div class="gen-list">${shown.map(cardHTML).join('')}</div>
    ${
      remain > 0
        ? `<button class="gen-more btn" type="button" data-action="load-more">再显示 ${Math.min(30, remain)} 位 · 剩余 ${remain}</button>`
        : ''
    }`;
}

function allSectionHTML(generals) {
  return `<section class="gen-all" aria-labelledby="genAllTitle">
    <div class="gen-section-head gen-all-head">
      <h2 class="gen-section-title" id="genAllTitle">全部将帅<span>${generals.length} 人 · 自动聚合</span></h2>
      <button class="gen-all-toggle" type="button" data-all-toggle aria-expanded="false" aria-controls="genAllBody">展开名册</button>
    </div>
    <div class="gen-all-body" id="genAllBody" hidden>
      <div class="gen-toolbar">
        <label class="gen-search">
          ${icon('search')}
          <input id="genSearch" type="search" inputmode="search" autocomplete="off" spellcheck="false" placeholder="搜索将帅姓名" aria-label="搜索将帅姓名">
        </label>
        <div class="segmented" role="group" aria-label="排序方式">
          ${SORTS.map(
            ([value, label]) =>
              `<button class="seg-btn" type="button" data-sort="${value}" aria-pressed="${
                state.sort === value ? 'true' : 'false'
              }">${label}</button>`
          ).join('')}
        </div>
      </div>
      <div id="genList"></div>
    </div>
  </section>`;
}

function pageHTML(ctx) {
  const generals = buildGenerals(ctx.data);
  const relationCount = (ctx.data.relations || []).length;
  return `<div class="generals-page">
    <header class="page-head">
      <div class="head-title">名将<span class="head-sub">40 位立传 · ${generals.length} 位在册</span></div>
      <div class="head-actions">
        <a class="icon-btn" href="#/graph" aria-label="关系图谱">${icon('layers')}</a>
        <button class="icon-btn" type="button" data-action="search" aria-label="搜索战役">${icon('search')}</button>
      </div>
    </header>
    <div class="gen-body">
      ${introHTML(ctx.data, generals, relationCount)}
      ${featuredSectionHTML(ctx, state.bios)}
      ${allSectionHTML(generals)}
      <p class="gen-foot">名将小传为 M3.5 数据；全部名册由 sides[].commanders 自动聚合，同名人物按通行姓名合并，暂未区分字号与重名。</p>
    </div>
  </div>`;
}

/* ---------------- 交互 ---------------- */
function rerenderList() {
  if (!state) return;
  const generals = buildGenerals(state.ctx.data);
  const wrap = state.root.querySelector('#genList');
  if (wrap) wrap.innerHTML = listHTML(generals);
}

function openAllIfNeeded() {
  if (!state || state.allOpen) return;
  const body = state.root.querySelector('#genAllBody');
  const toggle = state.root.querySelector('[data-all-toggle]');
  if (!body) return;
  state.allOpen = true;
  body.hidden = false;
  if (toggle) {
    toggle.setAttribute('aria-expanded', 'true');
    toggle.textContent = '收起名册';
  }
  rerenderList();
}

function bindEvents() {
  const { root } = state;

  root.querySelector('[data-action="search"]').addEventListener('click', () => navigate('/search'));

  root.addEventListener('click', (e) => {
    // 全部将帅 折叠
    if (e.target.closest('[data-all-toggle]')) {
      const body = root.querySelector('#genAllBody');
      const toggle = root.querySelector('[data-all-toggle]');
      state.allOpen = !state.allOpen;
      if (body) body.hidden = !state.allOpen;
      if (toggle) {
        toggle.setAttribute('aria-expanded', state.allOpen ? 'true' : 'false');
        toggle.textContent = state.allOpen ? '收起名册' : '展开名册';
      }
      if (state.allOpen) rerenderList();
      return;
    }

    // 小传展开 / 收起
    const bioToggle = e.target.closest('[data-bio-toggle]');
    if (bioToggle) {
      const card = bioToggle.closest('[data-bio-card]');
      const expanded = bioToggle.getAttribute('aria-expanded') === 'true';
      bioToggle.setAttribute('aria-expanded', expanded ? 'false' : 'true');
      bioToggle.textContent = expanded ? '展开小传' : '收起小传';
      if (card) {
        card.classList.toggle('is-open', !expanded);
        card.querySelector('.bio-acc')?.classList.toggle('is-open', !expanded);
      }
      return;
    }

    // 全量名册：展开某位将领
    const expandBtn = e.target.closest('[data-expand]');
    if (expandBtn) {
      const name = expandBtn.dataset.expand;
      if (state.expanded.has(name)) state.expanded.delete(name);
      else state.expanded.add(name);
      rerenderList();
      return;
    }

    const more = e.target.closest('[data-action="load-more"]');
    if (more) {
      state.limit += 30;
      rerenderList();
      return;
    }
    if (e.target.closest('[data-action="clear-query"]')) {
      const input = root.querySelector('#genSearch');
      if (input) input.value = '';
      state.query = '';
      rerenderList();
    }
  });

  // 搜索（事件委托绑定，元素在折叠区里也存在）
  const input = root.querySelector('#genSearch');
  const onInput = debounce(() => {
    state.query = input.value.trim();
    state.limit = 30;
    rerenderList();
  }, 100);
  input.addEventListener('input', onInput);
  input.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      input.value = '';
      state.query = '';
      rerenderList();
    }
  });

  root.querySelector('.gen-toolbar .segmented').addEventListener('click', (e) => {
    const btn = e.target.closest('[data-sort]');
    if (!btn) return;
    state.sort = btn.dataset.sort;
    root.querySelectorAll('.gen-toolbar .seg-btn').forEach((b) => b.setAttribute('aria-pressed', b === btn ? 'true' : 'false'));
    rerenderList();
  });
}

export function renderGenerals(root, ctx) {
  if (!ctx.data || !ctx.data.ok || !ctx.data.battles.length) {
    root.innerHTML = `<div class="generals-page">
      <header class="page-head">
        <div class="head-title">名将<span class="head-sub">数据准备中</span></div>
      </header>
      <div class="page-body">${emptyStateHTML({
        title: '将星尚未入册',
        desc: '战役数据尚未就绪，无法聚合将领名录。请稍后重试，或先回到时间轴阅读。',
        actions: '<button class="btn btn--gold" type="button" data-action="retry">重新载入</button><button class="btn" type="button" data-action="home">回到时间轴</button>',
      })}</div>
    </div>`;
    root.querySelector('[data-action="retry"]')?.addEventListener('click', () => window.location.reload());
    root.querySelector('[data-action="home"]')?.addEventListener('click', () => navigate('/'));
    return;
  }

  state = {
    root,
    ctx,
    query: '',
    sort: 'count',
    limit: 30,
    expanded: new Set(),
    allOpen: false,
    bios: null,
  };
  root.innerHTML = pageHTML(ctx);
  bindEvents();

  // 小传数据按需异步载入；失败时保留「全部将帅」可用
  loadBios().then((bios) => {
    if (!state || state.root !== root) return;
    state.bios = bios;
    const host = root.querySelector('#genFeatured');
    if (host) {
      host.innerHTML = biosHTML(ctx, bios);
      revealStagger(host, '.gen-bio-card', { stagger: 45, threshold: 0.04 });
    }
  });
}

export function disposeGenerals() {
  state = null;
}
