/* ============================================================
   search.js — 全屏搜索浮层：名称/别名/人物/古今地名/典故/tag/提要
   ============================================================ */

import { esc, icon, fmtYear, highlight, debounce } from './ui.js';
import { searchBattles, hotTags } from './data.js';
import { loadRecent } from './store.js';
import { navigateBack } from './router.js';
import { revealStagger } from './motion.js';

let screen = null;
let cleanupFns = [];

function closeSearch() {
  navigateBack();
}

function hotChipsHTML(tags, query = '') {
  return `<div class="hot-chips">${tags
    .map(
      (t) =>
        `<button class="hot-chip" type="button" data-hot="${esc(t.tag)}">${esc(t.tag)}${
          t.count ? `<span class="hot-num">${t.count}</span>` : ''
        }</button>`
    )
    .join('')}</div>`;
}

function recentHTML(ctx) {
  const ids = loadRecent();
  const battles = ids.map((id) => ctx.data.byId.get(id)).filter(Boolean);
  if (!battles.length) return '';
  return `<section class="search-group">
    <div class="search-group-title">最近浏览<span class="sg-rule"></span><span class="sg-count">${battles.length}</span></div>
    <div class="recent-list">${battles
      .map(
        (b) => `<a class="recent-item" href="#/battle/${encodeURIComponent(b.id)}">
          <span class="ri-year">${esc(fmtYear(b.startYear))}</span>
          <span>${esc(b.name)}</span>
          <span class="ri-arrow" aria-hidden="true">›</span>
        </a>`
      )
      .join('')}</div>
  </section>`;
}

function initialHTML(ctx) {
  const tags = hotTags(ctx.data, 8);
  return `<div class="search-hint">
      <div class="sh-kicker">热门检索</div>
      ${hotChipsHTML(tags)}
    </div>
    ${recentHTML(ctx)}
    <p class="search-note">可检索：战役名 · 别名 · 人物 · 古地名 · 今地名 · 典故 · 标签 · 提要 · 年份</p>`;
}

function battleItemHTML(item, q) {
  const b = item.battle;
  const era = b.era;
  const sides = b.sides.map((s) => s.name).join(' 对 ');
  return `<a class="s-item" href="#/battle/${encodeURIComponent(b.id)}">
    <div class="s-item-top">
      <span class="s-year">${esc(fmtYear(b.startYear))}</span>
      <span class="s-name">${highlight(b.name, q)}</span>
      <span class="s-era">${esc(era?.short || era?.name || '')}</span>
    </div>
    <div class="s-meta">${esc(sides)}${b.result.text ? ' · ' + esc(b.result.text) : ''}</div>
    <div class="s-hit">命中 · ${item.hits.map((h) => esc(h)).join(' · ')}</div>
  </a>`;
}

function anecdoteItemHTML(item, q) {
  const b = item.battle;
  return `<a class="s-item" href="#/battle/${encodeURIComponent(b.id)}">
    <div class="s-item-top">
      <span class="s-year">${esc(fmtYear(b.startYear))}</span>
      <span class="s-anec-title">${highlight(item.title || '典故', q)}</span>
      <span class="s-era">${esc(b.name)}</span>
    </div>
    <div class="s-anec-text">${highlight(item.text, q)}</div>
  </a>`;
}

function personItemHTML(person, q) {
  const seed = String(person.name || '名').slice(0, 1);
  return `<div class="s-person">
    <div class="s-person-head">
      <span class="s-person-seal" aria-hidden="true">${esc(seed)}</span>
      <span class="s-person-name">${highlight(person.name, q)}</span>
      <span class="s-person-count">关联 ${person.battles.length} 场</span>
    </div>
    <div class="s-person-battles">
      ${person.battles
        .map(
          (b) => `<a href="#/battle/${encodeURIComponent(b.id)}">${esc(b.name)} · ${esc(fmtYear(b.startYear))}</a>`
        )
        .join('')}
    </div>
    <p class="s-anec-text" style="margin-top:8px">名将小传与完整战绩将在 M3 名将页上线。</p>
  </div>`;
}

function resultsHTML(ctx, q) {
  const result = searchBattles(ctx.data, q);
  const hasAny = result && (result.battles.length || result.anecdotes.length || result.people.length);
  if (!hasAny) {
    return `<div class="search-empty">
      <div class="se-mark">未寻</div>
      <h3>没有找到「${esc(q)}」</h3>
      <p>试试战役名、人物、古地名或典故；也可用「前260」这样的年份检索。</p>
      ${hotChipsHTML(hotTags(ctx.data, 5))}
    </div>`;
  }

  const groups = [];

  if (result.battles.length) {
    groups.push(`<section class="search-group">
      <div class="search-group-title">战役<span class="sg-rule"></span><span class="sg-count">${result.battles.length}</span></div>
      ${result.battles.slice(0, 24).map((item) => battleItemHTML(item, q)).join('')}
    </section>`);
  }
  if (result.people.length) {
    groups.push(`<section class="search-group">
      <div class="search-group-title">名将<span class="sg-rule"></span><span class="sg-count">${result.people.length}</span></div>
      ${result.people.map((p) => personItemHTML(p, q)).join('')}
    </section>`);
  }
  if (result.anecdotes.length) {
    groups.push(`<section class="search-group">
      <div class="search-group-title">典故<span class="sg-rule"></span><span class="sg-count">${result.anecdotes.length}</span></div>
      ${result.anecdotes.map((item) => anecdoteItemHTML(item, q)).join('')}
    </section>`);
  }
  return groups.join('');
}

export function renderSearch(ctx, route) {
  disposeSearch();
  const initialQuery = String(route?.query?.q || '');
  const personMode = route?.query?.note === 'person';

  screen = document.createElement('div');
  screen.id = 'search-screen';
  screen.className = 'search-screen';
  screen.innerHTML = `
    <div class="search-head" role="search">
      <button class="icon-btn" type="button" data-action="close" aria-label="返回">${icon('back')}</button>
      <div class="search-field">
        ${icon('search')}
        <input id="searchInput" type="search" inputmode="search" enterkeyhint="search"
          placeholder="搜战役、人物、地名、典故" autocomplete="off" autocapitalize="off" spellcheck="false" aria-label="搜索战役、人物、地名、典故">
        <button class="search-clear" type="button" data-action="clear" aria-label="清空搜索">${icon('close')}</button>
      </div>
    </div>
    <p class="sr-only" id="searchStatus" aria-live="polite"></p>
    <div class="search-body" id="searchBody"></div>`;

  document.body.appendChild(screen);
  document.body.classList.add('search-open');

  const input = screen.querySelector('#searchInput');
  const body = screen.querySelector('#searchBody');
  const clearBtn = screen.querySelector('.search-clear');
  const status = screen.querySelector('#searchStatus');

  const render = (q) => {
    if (!q) {
      body.innerHTML = initialHTML(ctx);
      revealStagger(body, '.hot-chip, .recent-item, .search-hint', { stagger: 30, wave: 10 });
      if (status) status.textContent = '搜索首屏已就绪';
      return;
    }
    const note = personMode
      ? `<p class="search-note search-fallback-note"><b>该人物未收录小传</b>，已为你检索「${esc(q)}」的相关战役与典故。</p>`
      : '';
    body.innerHTML = note + resultsHTML(ctx, q);
    body.scrollTop = 0;
    revealStagger(body, '.s-item, .s-person, .search-group-title', { stagger: 35, wave: 10 });
    if (status) {
      const groups = body.querySelectorAll('.search-group').length;
      const hits = body.querySelectorAll('.s-item, .s-person').length;
      status.textContent = hits ? `找到 ${hits} 条结果，${groups} 个分组` : `没有找到「${q}」`;
    }
  };

  const updateClear = () => {
    clearBtn.classList.toggle('is-visible', input.value.trim().length > 0);
  };

  const run = debounce(() => render(input.value.trim()), 80);

  input.addEventListener('input', () => {
    updateClear();
    run();
  });

  input.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeSearch();
  });

  clearBtn.addEventListener('click', () => {
    input.value = '';
    updateClear();
    render('');
    input.focus({ preventScroll: true });
  });

  screen.querySelector('[data-action="close"]').addEventListener('click', closeSearch);

  body.addEventListener('click', (e) => {
    const hot = e.target.closest('[data-hot]');
    if (hot) {
      input.value = hot.dataset.hot;
      updateClear();
      render(input.value.trim());
      input.focus({ preventScroll: true });
    }
  });

  render(initialQuery);
  if (initialQuery) {
    input.value = initialQuery;
    status.textContent = personMode ? `该人物未收录小传，已搜索「${initialQuery}」` : `搜索「${initialQuery}」`;
  }
  updateClear();
  setTimeout(() => {
    try {
      input.focus({ preventScroll: true });
    } catch (err) {
      /* ignore */
    }
  }, 60);

  cleanupFns.push(() => {
    /* 事件随节点移除而回收 */
  });
}

export function disposeSearch() {
  if (screen) {
    screen.remove();
    screen = null;
  }
  document.body.classList.remove('search-open');
  cleanupFns.forEach((fn) => fn());
  cleanupFns = [];
}
