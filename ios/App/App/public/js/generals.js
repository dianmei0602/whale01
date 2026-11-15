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

function bioStats(bios) {
  const list = Array.isArray(bios) ? bios : [];
  const featured = list.filter((g) => g && g.featured !== false).length;
  return { total: list.length, featured, extra: list.length - featured };
}

function bioBadgeHTML(g) {
  return g?.featured === false
    ? '<span class="bio-badge" title="独立小传人物，暂不进入关系图谱">重点人物</span>'
    : '';
}

function bioCountsText(stats) {
  if (!stats.total) return '';
  return `${stats.featured} 位入谱 · ${stats.total} 位立传`;
}

function filteredBios(bios, featuredOnly = false, eraId = 'all', query = '') {
  const needle = String(query || '').trim();
  return (bios || []).filter((g) => {
    if (featuredOnly && g.featured === false) return false;
    if (eraId !== 'all' && !(g.eraIds || []).includes(eraId)) return false;
    if (!needle) return true;
    return [g.name, ...(g.alias || []), g.title].some((value) => String(value || '').includes(needle));
  });
}

function biosHTML(ctx, bios, featuredOnly = false, eraId = 'all', query = '', limit = 8) {
  if (!bios.length) {
    return `<p class="gen-bio-loading">名将小传暂未载入（data/generals.json 不可用）；仍可切换到「全部将帅」浏览自动聚合名册。</p>`;
  }
  const filtered = filteredBios(bios, featuredOnly, eraId, query);
  if (!filtered.length) {
    return `<div class="gen-bio-empty">
      <p>当前范围没有匹配的人物小传。</p>
      <button class="btn" type="button" data-action="reset-gen-filter">清除筛选</button>
    </div>`;
  }
  const shown = filtered.slice(0, Math.max(1, Number(limit) || 8));
  const remaining = filtered.length - shown.length;
  return `<div class="gen-bio-list">${shown
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
      const clan = ctx.data.clansByGeneral?.get(g.id);
      const family = clan
        ? `<a class="bio-family" href="#/clan/${encodeURIComponent(clan.id)}"><span>所属家族</span>${esc(clan.name)}<i aria-hidden="true">›</i></a>`
        : '';
      return `<article class="gen-bio-card${g.featured === false ? ' is-extra' : ''}" data-bio-card data-general-id="${esc(
        g.id || ''
      )}">
        <header class="bio-head">
          <span class="gen-seal bio-seal" aria-hidden="true">${esc(String(g.name || '').slice(0, 1))}</span>
          <div class="bio-head-main">
            <h3 class="bio-name">${esc(g.name || '')}${aliases.length ? `<span class="bio-alias">${esc(aliases.join(' / '))}</span>` : ''}${bioBadgeHTML(g)}</h3>
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
        ${family}
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
    .join('')}</div>${
    remaining > 0
      ? `<button class="gen-more btn" type="button" data-action="load-more-bio">再显示 ${Math.min(
          8,
          remaining
        )} 位 · 剩余 ${remaining} 位</button>`
      : ''
  }`;
}

/* ---------------- 入谱 / 立传 / 全部将帅 ---------------- */
function viewTabsHTML() {
  const stats = bioStats(state?.bios);
  return `<div class="gen-view-tabs segmented" role="tablist" aria-label="名将浏览范围">
    <button class="seg-btn" type="button" role="tab" data-gen-view="featured" aria-selected="${state?.view === 'featured'}" aria-controls="genResults">入谱 <span data-gen-count="featured">${stats.featured || '—'}</span></button>
    <button class="seg-btn" type="button" role="tab" data-gen-view="bio" aria-selected="${state?.view === 'bio'}" aria-controls="genResults">立传 <span data-gen-count="bio">${stats.total || '—'}</span></button>
    <button class="seg-btn" type="button" role="tab" data-gen-view="roster" aria-selected="${state?.view === 'roster'}" aria-controls="genResults">全部将帅 <span data-gen-count="roster">${buildGenerals(state.ctx.data).length || '—'}</span></button>
  </div>`;
}

function resultTitleText() {
  if (state?.view === 'roster') return '全部将帅';
  if (state?.view === 'bio') return '人物立传';
  return '入谱名将';
}

function resultSummaryText() {
  if (state?.view === 'roster') return '按战役主将聚合 · 可搜索与排序';
  if (state?.view === 'bio') return '全部独立小传 · 可按时期筛选';
  return '关系图谱核心人物 · 可查看独立小传';
}

function catalogSectionHTML(ctx, generals) {
  const stats = bioStats(state.bios);
  const eras = ctx.data.eras || [];
  const placeholder = state.view === 'roster' ? '搜索全部将帅' : '搜索立传人物';
  const initial = state.bios === null && state.view !== 'roster'
    ? '<p class="gen-bio-loading">正在载入名将小传…</p>'
    : state.view === 'roster'
      ? listHTML(generals)
      : biosHTML(ctx, state.bios || [], state.view === 'featured', state.era, state.query, state.bioLimit);
  return `<section class="gen-catalog" aria-labelledby="genCatalogTitle">
    <div class="gen-section-head gen-catalog-head">
      <h2 class="gen-section-title" id="genCatalogTitle">将星名册<span data-gen-total>${stats.total || '—'} 位立传</span></h2>
      <span class="gen-section-note" data-gen-summary>${esc(resultSummaryText())}</span>
    </div>
    ${viewTabsHTML()}
    <div class="gen-bio-tools">
      <div class="gen-bio-filter-row">
        <label class="gen-search gen-bio-search">
          ${icon('search')}
          <input id="genSearch" type="search" inputmode="search" autocomplete="off" spellcheck="false" placeholder="${esc(placeholder)}" aria-label="${esc(placeholder)}" value="${esc(state?.query || '')}">
        </label>
        <label class="gen-era-filter">
          <span class="sr-only">按时期筛选名将</span>
          <select id="genEra" aria-label="按时期筛选名将">
            <option value="all">全部时期</option>
            ${eras.map((era) => `<option value="${esc(era.id)}"${state?.era === era.id ? ' selected' : ''}>${esc(era.short || era.name)}</option>`).join('')}
          </select>
        </label>
      </div>
      <div class="segmented gen-sort" role="group" aria-label="全部将帅排序方式"${state.view === 'roster' ? '' : ' hidden'}>
        ${SORTS.map(
          ([value, label]) =>
            `<button class="seg-btn" type="button" data-sort="${value}" aria-pressed="${
              state.sort === value ? 'true' : 'false'
            }">${label}</button>`
        ).join('')}
      </div>
    </div>
    <div class="gen-result-head" aria-live="polite">
      <h3 class="gen-result-title" data-gen-result-title>${esc(resultTitleText())}</h3>
      <span class="gen-result-meta" data-gen-result-meta>${state.bios === null ? '正在载入…' : '准备就绪'}</span>
    </div>
    <div id="genResults">${initial}</div>
  </section>`;
}

function introHTML(data, generals, relationCount, bios) {
  const stats = bioStats(bios);
  const eraCount = new Set(generals.flatMap((g) => g.eraList.map((e) => e.id))).size;
  const commanding = generals.filter((g) => g.count > 1).length;
  return `<section class="gen-intro">
    <div class="gen-intro-head">
      <h1>将星入册</h1>
      <span class="gen-intro-sub" data-bio-intro-sub>${
        stats.total ? `${stats.total} 位立传 · ${generals.length} 位将帅在册` : `名将小传载入中 · ${generals.length} 位在册`
      }</span>
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
        <span data-bio-graph-cta>${stats.featured || '—'} 位名将 · ${relationCount} 条关系 · 点击看小传</span>
      </span>
      <span class="gen-graph-cta-arrow" aria-hidden="true">›</span>
    </a>
    <p class="gen-intro-note" data-bio-note>${
      stats.total
        ? `小传 ${stats.total} 人（${stats.featured} 位入谱、${stats.extra} 位重点人物），按数据供稿撰写；全部 ${generals.length} 位将帅由 sides[].commanders 自动聚合。同一场战役中作为主将或主要将领出现即计入指挥场次；胜率按其所在一方的胜负计算，平局/未决不计胜。`
        : `全部 ${generals.length} 位将帅由 sides[].commanders 自动聚合。同一场战役中作为主将或主要将领出现即计入指挥场次；胜率按其所在一方的胜负计算，平局/未决不计胜。`
    }</p>
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
  const filtered = generals.filter((g) => {
    if (state.query && !g.name.includes(state.query)) return false;
    if (state.era !== 'all' && !g.eraList.some((era) => era.id === state.era)) return false;
    return true;
  });
  const sorted = sortGenerals(filtered, state.sort);
  const shown = sorted.slice(0, state.limit);
  const remain = sorted.length - shown.length;

  if (!filtered.length) {
    return `<div class="gen-empty">
      <p>没有找到符合当前搜索与时期条件的将领。</p>
      <button class="btn" type="button" data-action="reset-gen-filter">清除筛选</button>
    </div>`;
  }

  return `<div class="gen-list-head" aria-live="polite">
      <span>共 <b>${sorted.length}</b> 位将领</span>
      <span class="gen-list-sort">按${SORTS.find((s) => s[0] === state.sort)[1]}排序</span>
    </div>
    <div class="gen-list">${shown.map(cardHTML).join('')}</div>
    ${
      remain > 0
        ? `<button class="gen-more btn" type="button" data-action="load-more">再显示 ${Math.min(
            state.rosterPageSize,
            remain
          )} 位 · 剩余 ${remain} 位</button>`
        : ''
    }`;
}

function pageHTML(ctx) {
  const generals = buildGenerals(ctx.data);
  const relationCount = (ctx.data.relations || []).length;
  const stats = bioStats(state.bios);
  return `<div class="generals-page">
    <header class="page-head">
      <div class="head-title">名将<span class="head-sub" data-bio-header>${
        stats.total ? `${stats.featured} 位入谱 · ${stats.total} 位立传` : `名将小传载入中 · ${generals.length} 位关联将帅`
      }</span></div>
      <div class="head-actions">
        <a class="icon-btn" href="#/graph" aria-label="关系图谱">${icon('layers')}</a>
        <button class="icon-btn" type="button" data-action="search" aria-label="搜索战役">${icon('search')}</button>
      </div>
    </header>
    <div class="gen-body">
      ${introHTML(ctx.data, generals, relationCount, state.bios)}
      ${catalogSectionHTML(ctx, generals)}
      <p class="gen-foot">入谱人物可进入关系图谱；立传人物拥有独立小传；全部将帅由战役主将字段自动聚合，同名人物按通行姓名合并。</p>
    </div>
  </div>`;
}

/* ---------------- 交互 ---------------- */
function rosterFiltered(generals) {
  return generals.filter((g) => {
    if (state.query && !g.name.includes(state.query)) return false;
    if (state.era !== 'all' && !g.eraList.some((era) => era.id === state.era)) return false;
    return true;
  });
}

function updateCatalogChrome(root) {
  if (!state || !root) return;
  const stats = bioStats(state.bios);
  const generals = buildGenerals(state.ctx.data);
  const counts = {
    featured: stats.featured,
    bio: stats.total,
    roster: generals.length,
  };
  root.querySelectorAll('[data-gen-count]').forEach((el) => {
    const value = counts[el.dataset.genCount];
    el.textContent = state.bios === null && el.dataset.genCount !== 'roster' ? '…' : String(value || 0);
  });
  const total = root.querySelector('[data-gen-total]');
  if (total) total.textContent = state.bios === null ? '立传载入中' : `${stats.total} 位立传`;
  const title = root.querySelector('[data-gen-result-title]');
  if (title) title.textContent = resultTitleText();
  const summary = root.querySelector('[data-gen-summary]');
  if (summary) summary.textContent = resultSummaryText();
  const resultMeta = root.querySelector('[data-gen-result-meta]');
  if (resultMeta) {
    let count = 0;
    if (state.view === 'roster') count = rosterFiltered(generals).length;
    else if (state.bios !== null) {
      count = filteredBios(state.bios, state.view === 'featured', state.era, state.query).length;
    }
    resultMeta.textContent =
      state.bios === null && state.view !== 'roster' ? '正在载入…' : `${count} 位${state.query || state.era !== 'all' ? '匹配' : ''}人物`;
  }
  root.querySelectorAll('[data-gen-view]').forEach((btn) => {
    const active = btn.dataset.genView === state.view;
    btn.setAttribute('aria-selected', active ? 'true' : 'false');
  });
}

function refreshResults() {
  if (!state) return;
  const { root } = state;
  const host = root.querySelector('#genResults');
  if (!host) return;
  if (state.view === 'roster') {
    host.innerHTML = listHTML(buildGenerals(state.ctx.data));
  } else if (state.bios === null) {
    host.innerHTML = '<p class="gen-bio-loading">正在载入名将小传…</p>';
  } else {
    host.innerHTML = biosHTML(
      state.ctx,
      state.bios,
      state.view === 'featured',
      state.era,
      state.query,
      state.bioLimit
    );
  }
  updateCatalogChrome(root);
  revealStagger(host, '.gen-bio-card, .gen-card', { stagger: 35, threshold: 0.04 });
}

function switchView(view) {
  if (!state || !['featured', 'bio', 'roster'].includes(view)) return;
  state.view = view;
  state.limit = state.rosterPageSize;
  state.bioLimit = state.bioPageSize;
  state.expanded.clear();
  const input = state.root.querySelector('#genSearch');
  const placeholder = view === 'roster' ? '搜索全部将帅' : '搜索立传人物';
  if (input) {
    input.placeholder = placeholder;
    input.setAttribute('aria-label', placeholder);
  }
  const sort = state.root.querySelector('.gen-sort');
  if (sort) sort.hidden = view !== 'roster';
  refreshResults();
}

function resetGenFilters() {
  if (!state) return;
  state.query = '';
  state.era = 'all';
  state.limit = state.rosterPageSize;
  state.bioLimit = state.bioPageSize;
  const input = state.root.querySelector('#genSearch');
  if (input) input.value = '';
  const era = state.root.querySelector('#genEra');
  if (era) era.value = 'all';
  refreshResults();
}

function bindEvents() {
  const { root } = state;
  root.querySelector('[data-action="search"]').addEventListener('click', () => navigate('/search'));

  root.addEventListener('click', (e) => {
    const viewBtn = e.target.closest('[data-gen-view]');
    if (viewBtn) {
      switchView(viewBtn.dataset.genView);
      return;
    }

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

    const expandBtn = e.target.closest('[data-expand]');
    if (expandBtn) {
      const name = expandBtn.dataset.expand;
      if (state.expanded.has(name)) state.expanded.delete(name);
      else state.expanded.add(name);
      refreshResults();
      return;
    }

    if (e.target.closest('[data-action="load-more"]')) {
      state.limit += state.rosterPageSize;
      refreshResults();
      return;
    }
    if (e.target.closest('[data-action="load-more-bio"]')) {
      state.bioLimit += state.bioPageSize;
      refreshResults();
      return;
    }
    if (e.target.closest('[data-action="reset-gen-filter"]')) {
      resetGenFilters();
      return;
    }
    const sortBtn = e.target.closest('[data-sort]');
    if (sortBtn) {
      state.sort = sortBtn.dataset.sort;
      root.querySelectorAll('.gen-sort [data-sort]').forEach((btn) => {
        btn.setAttribute('aria-pressed', btn === sortBtn ? 'true' : 'false');
      });
      refreshResults();
    }
  });

  const input = root.querySelector('#genSearch');
  const onInput = debounce(() => {
    state.query = input.value.trim();
    state.limit = state.rosterPageSize;
    state.bioLimit = state.bioPageSize;
    refreshResults();
  }, 100);
  input.addEventListener('input', onInput);
  input.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    input.value = '';
    state.query = '';
    refreshResults();
  });

  const era = root.querySelector('#genEra');
  era?.addEventListener('change', () => {
    state.era = era.value;
    state.limit = state.rosterPageSize;
    state.bioLimit = state.bioPageSize;
    refreshResults();
  });
}

function updateBioCounts(root, bios) {
  if (!root) return;
  const stats = bioStats(bios);
  const generals = buildGenerals(state.ctx.data);
  const relationCount = (state.ctx.data.relations || []).length;
  const header = root.querySelector('[data-bio-header]');
  if (header) header.textContent = `${stats.featured} 位入谱 · ${stats.total} 位立传`;
  const introSub = root.querySelector('[data-bio-intro-sub]');
  if (introSub) introSub.textContent = `${stats.total} 位立传 · ${generals.length} 位将帅在册`;
  const graphCta = root.querySelector('[data-bio-graph-cta]');
  if (graphCta) graphCta.textContent = `${stats.featured} 位名将 · ${relationCount} 条关系 · 点击看小传`;
  const note = root.querySelector('[data-bio-note]');
  if (note) {
    note.textContent = `小传 ${stats.total} 人（${stats.featured} 位入谱、${stats.extra} 位重点人物），按数据供稿撰写；全部 ${generals.length} 位将帅由 sides[].commanders 自动聚合。同一场战役中作为主将或主要将领出现即计入指挥场次；胜率按其所在一方的胜负计算，平局/未决不计胜。`;
  }
  updateCatalogChrome(root);
}

function focusGeneral(root, gid) {
  if (!gid) return;
  const reduce = document.documentElement.dataset.motion === 'reduce';
  let card = null;
  try {
    card = root.querySelector(`[data-general-id="${CSS.escape(gid)}"]`);
  } catch (err) {
    card = null;
  }
  if (!card) return;
  card.classList.add('is-open');
  const acc = card.querySelector('.bio-acc');
  acc?.classList.add('is-open');
  const btn = card.querySelector('[data-bio-toggle]');
  if (btn) {
    btn.setAttribute('aria-expanded', 'true');
    btn.textContent = '收起小传';
  }
  requestAnimationFrame(() => {
    try {
      card.scrollIntoView({ behavior: reduce ? 'auto' : 'smooth', block: 'center' });
    } catch (err) {
      card.scrollIntoView();
    }
  });
}

export function renderGenerals(root, ctx, route) {
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
    view: 'featured',
    query: '',
    sort: 'count',
    era: 'all',
    bioLimit: 8,
    bioPageSize: 8,
    limit: 24,
    rosterPageSize: 24,
    expanded: new Set(),
    bios: null,
    targetGeneralId: route?.query?.g || '',
  };
  root.innerHTML = pageHTML(ctx);
  bindEvents();

  // 小传数据按需异步载入；失败时保留「全部将帅」可用
  loadBios().then((bios) => {
    if (!state || state.root !== root) return;
    state.bios = bios;
    if (state.targetGeneralId) {
      const target = bios.find((g) => g.id === state.targetGeneralId);
      if (target) {
        state.view = target.featured === false ? 'bio' : 'featured';
        const targetIndex = filteredBios(bios, state.view === 'featured').findIndex(
          (g) => g.id === state.targetGeneralId
        );
        state.bioLimit = Math.max(state.bioPageSize, targetIndex + 1);
      }
    }
    refreshResults();
    updateBioCounts(root, bios);
    if (state.targetGeneralId) focusGeneral(root.querySelector('#genResults'), state.targetGeneralId);
  });
}

export function disposeGenerals() {
  state = null;
}
