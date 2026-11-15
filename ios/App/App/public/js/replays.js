/* ============================================================
   replays.js — 3.3 P1 推演库（#/replays）
   ============================================================ */

import { esc, icon, emptyStateHTML } from './ui.js';
import { navigate, navigateBack } from './router.js';

const CSS_HREF = 'css/replays.css';
let cssLoaded = false;
let filterEra = 'all';
let filterType = 'all';

const TERRAIN_LABEL = {
  plain: '平原',
  mountain: '山地',
  water: '水域',
  city: '城邑',
  desert: '荒漠',
  forest: '山林',
  pass: '关隘',
  coastal: '沿海',
  river: '河川',
};

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

function terrainText(t) {
  return TERRAIN_LABEL[t] || t || '地形未载';
}

function replayType(battle) {
  return battle?.type?.[0] || '未分类';
}

function cardHTML(replay, ctx) {
  const battle = ctx.data.byId.get(replay.battleId);
  const era = battle?.era || ctx.data.eraById.get(battle?.eraId);
  const stages = replay.stages?.length || 0;
  const duration = (replay.stages || []).reduce((sum, s) => sum + (Number(s.duration) || 0), 0);
  return `<a class="rep-card" href="#/replay/${encodeURIComponent(replay.battleId)}" data-replay="${esc(
    replay.battleId
  )}">
    <span class="rep-top">
      <span class="rep-era">${esc(era?.short || era?.name || '')}</span>
      <span class="rep-type">${esc(replayType(battle))}</span>
    </span>
    <strong class="rep-title">${esc(replay.title || battle?.name || '战役推演')}</strong>
    <span class="rep-sub">${esc(replay.subtitle || battle?.summary || '')}</span>
    <span class="rep-meta">
      <span>${esc(terrainText(replay.terrain))}</span>
      <span>${stages} 阶段</span>
      <span>约 ${duration}s</span>
      <span class="rep-go">进入推演 →</span>
    </span>
  </a>`;
}

function pageHTML(ctx) {
  const eras = ctx.data.eras || [];
  const replays = ctx.data.replays || [];
  const types = [...new Set(replays.map((r) => replayType(ctx.data.byId.get(r.battleId))))].filter(Boolean);
  const eraChips = [`<button class="rep-chip${filterEra === 'all' ? ' is-active' : ''}" type="button" data-rep-era="all">全部时期</button>`]
    .concat(
      eras.map(
        (era) =>
          `<button class="rep-chip${filterEra === era.id ? ' is-active' : ''}" type="button" data-rep-era="${esc(
            era.id
          )}">${esc(era.short || era.name)}</button>`
      )
    )
    .join('');
  const typeChips = [`<button class="rep-chip${filterType === 'all' ? ' is-active' : ''}" type="button" data-rep-type="all">全部类型</button>`]
    .concat(
      types.map(
        (type) =>
          `<button class="rep-chip${filterType === type ? ' is-active' : ''}" type="button" data-rep-type="${esc(
            type
          )}">${esc(type)}</button>`
      )
    )
    .join('');
  return `<div class="replays-page">
    <header class="page-head">
      <button class="icon-btn" type="button" data-action="back" aria-label="返回更多">${icon('back')}</button>
      <div class="head-title">推演库<span class="head-sub">${replays.length} 场动画推演 · 重点战役</span></div>
      <div class="head-actions">
        <a class="icon-btn icon-btn--text" href="#/atlas" aria-label="打开时代总览">时代总览</a>
        <button class="icon-btn" type="button" data-action="search" aria-label="搜索">${icon('search')}</button>
      </div>
    </header>
    <div class="page-body">
      <div class="rep-filter-group">
        <div class="rep-filter-row no-scrollbar" aria-label="按时期筛选">${eraChips}</div>
        <div class="rep-filter-row no-scrollbar" aria-label="按类型筛选">${typeChips}</div>
      </div>
      <div class="rep-list" id="repList"></div>
      <p class="rep-foot">推演覆盖重点战役与知名人物；动画为阅读辅助示意，战术细节以史料为准。</p>
    </div>
  </div>`;
}

export function renderReplays(root, ctx) {
  ensureCss();
  const all = ctx.data.replays || [];
  root.innerHTML = pageHTML(ctx);
  root.querySelector('[data-action="back"]')?.addEventListener('click', () => navigateBack('/more'));
  root.querySelector('[data-action="search"]')?.addEventListener('click', () => navigate('/search'));
  const listEl = root.querySelector('#repList');

  const paintList = () => {
    const list = all.filter((r) => {
      const battle = ctx.data.byId.get(r.battleId);
      if (filterEra !== 'all' && battle?.eraId !== filterEra) return false;
      if (filterType !== 'all' && replayType(battle) !== filterType) return false;
      return true;
    });
    listEl.innerHTML = list.length
      ? list.map((r) => cardHTML(r, ctx)).join('')
      : `<div class="rep-empty">${emptyStateHTML({
          title: '这个筛选下没有推演',
          desc: '换一个时期或类型看看；推演库只覆盖重点战役，未覆盖的战役仍可阅读详情。',
          actions:
            '<button class="btn btn--gold" type="button" data-rep-reset>查看全部</button><a class="btn" href="#/">去时间轴</a>',
        })}</div>`;
    listEl.querySelector('[data-rep-reset]')?.addEventListener('click', () => {
      filterEra = 'all';
      filterType = 'all';
      root.querySelectorAll('[data-rep-era]').forEach((b) => b.classList.toggle('is-active', b.dataset.repEra === 'all'));
      root.querySelectorAll('[data-rep-type]').forEach((b) => b.classList.toggle('is-active', b.dataset.repType === 'all'));
      paintList();
    });
  };

  root.querySelectorAll('[data-rep-era]').forEach((btn) => {
    btn.addEventListener('click', () => {
      filterEra = btn.dataset.repEra;
      root.querySelectorAll('[data-rep-era]').forEach((b) => b.classList.toggle('is-active', b === btn));
      paintList();
    });
  });
  root.querySelectorAll('[data-rep-type]').forEach((btn) => {
    btn.addEventListener('click', () => {
      filterType = btn.dataset.repType;
      root.querySelectorAll('[data-rep-type]').forEach((b) => b.classList.toggle('is-active', b === btn));
      paintList();
    });
  });
  paintList();
}

export function disposeReplays() {}
