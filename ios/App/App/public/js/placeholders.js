/* ============================================================
   placeholders.js — 404 页（M3 起地图 / 名将 / 统计均已实装，
   本文件仅保留未找到路由的降级页面）
   ============================================================ */

import { navigate } from './router.js';

export function renderNotFound(root) {
  root.innerHTML = `<div class="placeholder-page">
    <header class="page-head">
      <div class="head-title">未寻此页<span class="head-sub">404</span></div>
    </header>
    <div class="placeholder">
      <div class="empty-state" style="padding-top:64px">
        <div class="empty-art"></div>
        <h3>此卷无此页</h3>
        <p>链接可能已失效，回到卷首重新顺着时间轴读下去。</p>
        <div class="empty-actions"><button class="btn btn--gold" type="button" data-action="home">回到卷首</button></div>
      </div>
    </div>
  </div>`;
  root.querySelector('[data-action="home"]')?.addEventListener('click', () => navigate('/'));
}
