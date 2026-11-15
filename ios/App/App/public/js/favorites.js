/* ============================================================
   favorites.js — 3.3 P1 收藏夹（#/favorites）
   ============================================================ */

import { esc, icon, verdictSeal, emptyStateHTML, toast } from './ui.js';
import { navigate, navigateBack } from './router.js';
import { loadFavorites, toggleFavorite, getProgress, isRead } from './store.js';

const CSS_HREF = 'css/favorites.css';
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

function favCardHTML(battle, ctx) {
  const era = battle.era || ctx.data.eraById.get(battle.eraId);
  const pct = getProgress(battle.id);
  const read = isRead(battle.id);
  const label = read ? '已读' : pct > 0 ? `读至 ${pct}%` : '未开始';
  const width = read ? 100 : pct;
  return `<article class="fav-card${read ? ' is-read' : ''}" data-fav-id="${esc(battle.id)}">
    <a class="fav-main" href="#/battle/${encodeURIComponent(battle.id)}">
      <span class="fav-year">${esc(battle.yearText || '')}</span>
      <span class="fav-body">
        <span class="fav-title">${esc(battle.name)}</span>
        <span class="fav-meta">${esc(era?.short || era?.name || '')} · ${esc(
    battle.sides.map((s) => s.name).join(' 对 ')
  )}</span>
        <span class="fav-progress" aria-label="阅读进度 ${width}%">
          <i style="width:${width}%"></i>
        </span>
      </span>
      <span class="fav-result">${verdictSeal(battle)}</span>
      <span class="fav-state">${esc(label)}</span>
    </a>
    <button class="fav-remove" type="button" data-fav-remove="${esc(battle.id)}" aria-label="取消收藏 ${esc(
    battle.name
  )}">${icon('book')}<span>取消收藏</span></button>
  </article>`;
}

function pageHTML(ctx, list) {
  const cards = list.map((b) => favCardHTML(b, ctx)).join('');
  return `<div class="favorites-page">
    <header class="page-head">
      <button class="icon-btn" type="button" data-action="back" aria-label="返回更多">${icon('back')}</button>
      <div class="head-title">收藏夹<span class="head-sub">${list.length} 场收藏 · 本机保存</span></div>
      <div class="head-actions">
        <button class="icon-btn" type="button" data-action="search" aria-label="搜索">${icon('search')}</button>
      </div>
    </header>
    <div class="page-body">
      ${
        cards
          ? `<div class="fav-list">${cards}</div>
             <p class="fav-foot">收藏保存在本机（localStorage），不上传、不同步。取消收藏不影响阅读进度记录。</p>`
          : `<div class="fav-empty">${emptyStateHTML({
              title: '还没有收藏的战役',
              desc: '在战役详情页点右上角书签即可收藏；收藏与阅读进度都只保存在本机，刷新后仍在。',
              actions:
                '<a class="btn btn--gold" href="#/">去时间轴</a><a class="btn" href="#/map">去地图</a>',
            })}</div>`
      }
    </div>
  </div>`;
}

export function renderFavorites(root, ctx) {
  ensureCss();
  const render = () => {
    const list = loadFavorites()
      .map((id) => ctx.data.byId.get(id))
      .filter(Boolean);
    root.innerHTML = pageHTML(ctx, list);
    root.querySelector('[data-action="back"]')?.addEventListener('click', () => navigate('/more'));
    root.querySelector('[data-action="search"]')?.addEventListener('click', () => navigate('/search'));
    root.querySelectorAll('[data-fav-remove]').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        const id = btn.dataset.favRemove;
        const removed = toggleFavorite(id);
        if (removed === false) toast('已取消收藏');
        render();
      });
    });
  };
  render();
}

export function disposeFavorites() {}
