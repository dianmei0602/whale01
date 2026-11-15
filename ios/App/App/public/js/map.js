/* ============================================================
   map.js — M3 战役地图：
   内置示意中国轮廓（Natural Earth 简化） + 120 场线性投影落位
   + 时期/类型筛选 + 缩放拖动 + 低缩放聚合 + 摘要卡直达详情
   ============================================================ */

import { esc, icon, fmtYear, emptyStateHTML } from './ui.js';
import { TYPES } from './store.js';
import { navigate } from './router.js';
import * as geo from './china-geo.js';

const CLUSTER_SCREEN_PX = 34; // 聚合格子（屏幕像素）
const MIN_SCALE = 1;
const MAX_SCALE = 5;

/* ---------------- 标准地图底图（自然资源部标准地图服务） ----------------
   图幅：中国地图 1:740万 对开 · 横版 · 有邻国 · 线划一
   审图号：GS(2022)4307号 · 自然资源部监制
   资产：assets/standard-map.jpg（3200×2073，由官方 300dpi 原图 10599×6867 等比缩放）
   标定：以图面 34 个省会/特别行政区符号为控制点，RANSAC 剔除误配后
        用 22 个内点最小二乘拟合 二次多项式 (lng,lat)->像素，
        内点残差 3.69km、留一验证 5.68km（详见 www/assets/map-source.md）。
   说明：2.1 起改用「有邻国」图幅，朝鲜半岛/越南/蒙古/哈萨克斯坦方向的
        境外战场点可落入对应邻国境内；旧的「无邻国」图保留为
        assets/standard-map-nonborder.jpg 备查。
   兜底：底图加载失败时回退 china-geo.js 的示意轮廓。 */
const STD = {
  src: 'assets/standard-map.jpg',
  width: 3200,
  height: 2073,
  lon0: 105.0,
  lat0: 35.0,
  slon: 30.0,
  slat: 20.0,
  // u=(lng-105)/30, v=(lat-35)/20；基函数 [1, u, v, u², uv, v²]
  cx: [1560.673508, 1278.426529, 66.242249, -4.160836, -352.341108, 18.558034],
  cy: [1089.072808, 45.986769, -1073.996724, -176.936858, 2.982154, -1.120347],
};

function stdProject(lng, lat) {
  const u = (lng - STD.lon0) / STD.slon;
  const v = (lat - STD.lat0) / STD.slat;
  const b = [1, u, v, u * u, u * v, v * v];
  let x = 0;
  let y = 0;
  for (let i = 0; i < 6; i += 1) {
    x += b[i] * STD.cx[i];
    y += b[i] * STD.cy[i];
  }
  return [x, y];
}

/* 中国轮廓（由 china-geo 的投影坐标反解为经纬度，仅用于判定“境外”） */
const CHINA_RINGS_LL = geo.RINGS.map((ring) =>
  ring.map(([x, y]) => [x / geo.MAP.kx + geo.MAP.lngMin, geo.MAP.latMax - y / geo.MAP.ky])
);

function inChinaLL(lng, lat) {
  let inside = false;
  for (const ring of CHINA_RINGS_LL) {
    for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      const [xi, yi] = ring[i];
      const [xj, yj] = ring[j];
      if (yi > lat !== yj > lat && lng < ((xj - xi) * (lat - yi)) / (yj - yi) + xi) inside = !inside;
    }
  }
  return inside;
}

let state = null;

function isVectorMode() {
  return !!state && state.mode === 'vector';
}

function mapW() {
  return isVectorMode() ? geo.MAP.width : STD.width;
}

function mapH() {
  return isVectorMode() ? geo.MAP.height : STD.height;
}

function proj(lng, lat) {
  return isVectorMode() ? geo.project(lng, lat) : stdProject(lng, lat);
}

/* ---------------- 数据 ---------------- */
function filteredBattles(data) {
  return data.battles.filter((b) => {
    if (state.era !== 'all' && b.eraId !== state.era) return false;
    if (state.types.size && !b.type.some((t) => state.types.has(t))) return false;
    return true;
  });
}

/* ---------------- 视图渲染 ---------------- */
function mapSVG(mode) {
  const vector = mode === 'vector';
  const MW = vector ? geo.MAP.width : STD.width;
  const MH = vector ? geo.MAP.height : STD.height;
  const grid = [];
  if (vector) {
    for (let lng = 80; lng <= 130; lng += 10) {
      const [x] = geo.project(lng, 0);
      grid.push(`<line x1="${x.toFixed(1)}" y1="0" x2="${x.toFixed(1)}" y2="${MH}" class="map-grid-line"/>`);
      grid.push(`<text x="${(x + 5).toFixed(1)}" y="${MH - 14}" class="map-grid-label">${lng}°E</text>`);
    }
    for (let lat = 20; lat <= 50; lat += 10) {
      const [, y] = geo.project(0, lat);
      grid.push(`<line x1="0" y1="${y.toFixed(1)}" x2="${MW}" y2="${y.toFixed(1)}" class="map-grid-line"/>`);
      grid.push(`<text x="10" y="${(y + (lat === 50 ? 20 : -6)).toFixed(1)}" class="map-grid-label">${lat}°N</text>`);
    }
  }

  return `<svg class="map-svg" viewBox="0 0 ${MW.toFixed(1)} ${MH.toFixed(1)}" preserveAspectRatio="xMidYMid meet" role="img" aria-label="中国战役地图">
    <defs>
      <radialGradient id="mapSea" cx="0.5" cy="0.42" r="0.75">
        <stop offset="0" stop-color="#16130F"/>
        <stop offset="0.7" stop-color="#100E0B"/>
        <stop offset="1" stop-color="#0B0908"/>
      </radialGradient>
      <linearGradient id="mapLand" x1="0" y1="0" x2="0.4" y2="1">
        <stop offset="0" stop-color="#E9DFC8" stop-opacity="0.16"/>
        <stop offset="0.55" stop-color="#E9DFC8" stop-opacity="0.09"/>
        <stop offset="1" stop-color="#C9A227" stop-opacity="0.1"/>
      </linearGradient>
      <linearGradient id="mapRim" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#E0C060" stop-opacity="0.85"/>
        <stop offset="0.5" stop-color="#C9A227" stop-opacity="0.45"/>
        <stop offset="1" stop-color="#B23A2E" stop-opacity="0.4"/>
      </linearGradient>
      <filter id="mapGlow" x="-20%" y="-20%" width="140%" height="140%">
        <feGaussianBlur stdDeviation="6" result="b"/>
        <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
      </filter>
    </defs>

    <rect width="100%" height="100%" fill="url(#mapSea)"/>
    ${vector ? '' : `<image href="${STD.src}" x="0" y="0" width="${STD.width}" height="${STD.height}" preserveAspectRatio="none"/>`}
    <g class="map-grid">${grid.join('')}</g>

    ${vector ? `<g class="map-land-wrap" filter="url(#mapGlow)">
      <path class="map-land" d="${geo.OUTLINE_PATH}" fill="url(#mapLand)" stroke="url(#mapRim)" stroke-width="2.2"/>
      <path class="map-islands" d="${geo.ISLANDS_PATH}" fill="url(#mapLand)" stroke="url(#mapRim)" stroke-width="1.8"/>
    </g>

    <g class="map-nanhai" transform="translate(824, 560)">
      <rect x="0" y="0" width="150" height="150" rx="8" class="map-inset-rect"/>
      <text x="12" y="24" class="map-inset-title">南海诸岛</text>
      <text x="12" y="42" class="map-inset-sub">示意</text>
      <g class="map-inset-dots">
        <circle cx="46" cy="82" r="2.6"/><circle cx="70" cy="58" r="2.2"/>
        <circle cx="88" cy="96" r="2.4"/><circle cx="112" cy="70" r="2"/>
        <circle cx="66" cy="118" r="2.2"/><circle cx="104" cy="124" r="2"/>
      </g>
      <path d="M28 136c16-22 38-32 72-30" class="map-inset-dash"/>
    </g>` : ''}

    <g class="map-points" id="mapPoints"></g>
  </svg>`;
}

function filtersHTML(ctx) {
  const eraChips = [`<button class="m-chip is-active" type="button" data-era="all">全部</button>`]
    .concat(
      ctx.data.eras.map(
        (era) =>
          `<button class="m-chip" type="button" data-era="${esc(era.id)}"><span class="m-chip-idx">${String(
            era.index
          ).padStart(2, '0')}</span>${esc(era.short || era.name)}</button>`
      )
    )
    .join('');
  const typeChips = [`<button class="m-chip is-active" type="button" data-type="all">全部类型</button>`]
    .concat(TYPES.map((t) => `<button class="m-chip" type="button" data-type="${esc(t)}">${esc(t)}</button>`))
    .join('');
  return `<div class="map-filters">
    <div class="map-filter-row no-scrollbar" id="mapEraRow" aria-label="按时期筛选">${eraChips}</div>
    <div class="map-filter-row no-scrollbar" id="mapTypeRow" aria-label="按类型筛选">${typeChips}</div>
  </div>`;
}

function pageHTML(ctx, mode) {
  return `<div class="map-page">
    <header class="page-head">
      <div class="head-title">战役地图<span class="head-sub">${ctx.data.total} 场 · ${
      mode === 'vector' ? '示意轮廓（底图回退）' : '标准地图'
    }</span></div>
      <div class="head-actions">
        <button class="icon-btn" type="button" data-action="search" aria-label="搜索战役">${icon('search')}</button>
      </div>
    </header>

    <div class="map-body">
      <p class="sr-only" id="mapStatus" aria-live="polite"></p>
      ${filtersHTML(ctx)}

      <div class="map-meta">
        <span class="map-count" aria-live="polite"><b id="mapCount">0</b> 场落位</span>
        <span class="map-legend">
          <i class="lg lg-dot" aria-hidden="true"></i>战役
          <i class="lg lg-ring" aria-hidden="true"></i>战略决战
          <i class="lg lg-out" aria-hidden="true"></i>境外示意
        </span>
      </div>

      <div class="map-frame" id="mapFrame">
        <div class="map-canvas" id="mapCanvas">${mapSVG(mode)}</div>
        <div class="map-controls">
          <button class="map-ctl" type="button" data-map-action="zoom-in" aria-label="放大地图">+</button>
          <button class="map-ctl" type="button" data-map-action="zoom-out" aria-label="缩小地图">−</button>
          <button class="map-ctl" type="button" data-map-action="reset" aria-label="复位地图">↺</button>
        </div>
        <span class="map-zoom" id="mapZoom" aria-hidden="true">1.0×</span>
      </div>

      <p class="map-hint" id="mapHint"><b>底图</b>：自然资源部标准地图服务 · 审图号 <b>GS(2022)4307号</b>（中国地图 1:740万 对开 · 有邻国 · 线划一）<br>点位按经纬度落位 · 双指/滚轮缩放 · 拖动浏览 · 低缩放时数字气泡为聚合点，点按可放大</p>

      <section class="map-list-wrap">
        <div class="map-list-head">
          <span class="mlh-title" aria-live="polite">本筛选点位 <b id="mapListCount">0</b> 场</span>
          <button class="mlh-toggle" type="button" data-map-action="toggle-list" id="mapListToggle" aria-expanded="false">展开全部</button>
        </div>
        <div class="map-list" id="mapList"></div>
      </section>
    </div>
  </div>`;
}

/* ---------------- 点位 / 聚合 ---------------- */
function layoutPoints(battles) {
  const frame = state.frame;
  const baseScale = frame.clientWidth / mapW();
  const u = 1 / Math.max(1e-6, baseScale * state.scale); // 1 屏幕像素对应的地图单位
  const cell = CLUSTER_SCREEN_PX * u;

  const points = battles.map((b) => {
    const [x, y] = proj(b.location.lng, b.location.lat);
    return { b, x, y, outside: !inChinaLL(b.location.lng, b.location.lat), deciding: b.scale === '战略决战' };
  });

  const buckets = new Map();
  for (const p of points) {
    const key = `${Math.floor(p.x / cell)},${Math.floor(p.y / cell)}`;
    if (!buckets.has(key)) buckets.set(key, []);
    buckets.get(key).push(p);
  }

  const groups = [];
  for (const list of buckets.values()) {
    if (list.length === 1) {
      groups.push({ ...list[0], count: 1 });
    } else {
      const cx = list.reduce((s, p) => s + p.x, 0) / list.length;
      const cy = list.reduce((s, p) => s + p.y, 0) / list.length;
      groups.push({ x: cx, y: cy, count: list.length, items: list, outside: list.every((p) => p.outside) });
    }
  }

  const parts = groups.map((g) => {
    if (g.count > 1) {
      const r = 12 * u;
      return `<g class="mp-cluster" data-cluster="${g.items.map((p) => esc(p.b.id)).join(',')}" role="button" tabindex="0" aria-label="${g.count} 场战役聚合，点击放大">
        <circle class="mp-hit" cx="${g.x.toFixed(1)}" cy="${g.y.toFixed(1)}" r="${(25 * u).toFixed(2)}"/>
        <circle class="mp-cluster-glow" cx="${g.x.toFixed(1)}" cy="${g.y.toFixed(1)}" r="${(r * 1.5).toFixed(2)}"/>
        <circle class="mp-cluster-bg" cx="${g.x.toFixed(1)}" cy="${g.y.toFixed(1)}" r="${r.toFixed(2)}"/>
        <text x="${g.x.toFixed(1)}" y="${(g.y + 0.5 * u).toFixed(1)}" font-size="${(10 * u).toFixed(2)}" text-anchor="middle" dominant-baseline="middle">${g.count}</text>
      </g>`;
    }
    const r = (g.deciding ? 5.6 : 4.1) * u;
    const ringR = 8.2 * u;
    return `<g class="mp${g.deciding ? ' mp-deciding' : ''}${g.outside ? ' mp-outside' : ''}" data-battle="${esc(g.b.id)}" role="button" tabindex="0" aria-label="${esc(g.b.name)}">
      <circle class="mp-hit" cx="${g.x.toFixed(1)}" cy="${g.y.toFixed(1)}" r="${(23 * u).toFixed(2)}"/>
      ${g.deciding ? `<circle class="mp-ring" cx="${g.x.toFixed(1)}" cy="${g.y.toFixed(1)}" r="${ringR.toFixed(2)}" stroke-width="${(1.3 * u).toFixed(2)}"/>` : ''}
      <circle class="mp-halo" cx="${g.x.toFixed(1)}" cy="${g.y.toFixed(1)}" r="${(r * 2.1).toFixed(2)}"/>
      <circle class="mp-dot" cx="${g.x.toFixed(1)}" cy="${g.y.toFixed(1)}" r="${r.toFixed(2)}"/>
    </g>`;
  });

  return { html: parts.join(''), count: points.length };
}

function renderPoints(animate = false) {
  if (!state) return;
  const layer = state.root.querySelector('#mapPoints');
  if (!layer) return;
  const list = filteredBattles(state.ctx.data);
  const { html } = layoutPoints(list);
  layer.innerHTML = html;
  layer.classList.toggle('points-anim', !!animate);
  const countEl = state.root.querySelector('#mapCount');
  const listCountEl = state.root.querySelector('#mapListCount');
  if (countEl) countEl.textContent = String(list.length);
  if (listCountEl) listCountEl.textContent = String(list.length);
  renderList(list);
}

/* ---------------- 列表 ---------------- */
function renderList(list) {
  if (!state) return;
  const wrap = state.root.querySelector('#mapList');
  const toggle = state.root.querySelector('#mapListToggle');
  if (!wrap) return;
  const limit = state.listExpanded ? list.length : Math.min(8, list.length);
  wrap.innerHTML = list
    .slice(0, limit)
    .map(
      (b) => `<a class="map-row" href="#/battle/${encodeURIComponent(b.id)}">
        <span class="mr-year">${esc(fmtYear(b.startYear))}</span>
        <span class="mr-main">
          <span class="mr-name">${esc(b.name)}${b.scale === '战略决战' ? '<i class="mr-deciding">决战</i>' : ''}</span>
          <span class="mr-sub">${esc(b.location.modern || b.location.ancient)}</span>
        </span>
        <span class="mr-era" style="--era:${esc(b.era?.themeColor || '#C9A227')}">${esc(b.era?.short || '')}</span>
      </a>`
    )
    .join('');
  if (toggle) {
    if (list.length <= 8) {
      toggle.hidden = true;
    } else {
      toggle.hidden = false;
      toggle.textContent = state.listExpanded ? '收起' : `展开全部 ${list.length} 场`;
    }
  }
}

/* ---------------- 摘要卡 ---------------- */
function showPopup(battleId) {
  const b = state.ctx.data.byId.get(battleId);
  if (!b) return;
  const popup = state.popup;
  const outside = !inChinaLL(b.location.lng, b.location.lat);
  popup.innerHTML = `<button class="map-popup-close" type="button" data-popup-close aria-label="关闭">${icon('close')}</button>
    <div class="mp-head">
      <span class="mp-year">${esc(fmtYear(b.startYear))}</span>
      <span class="mp-name">${esc(b.name)}</span>
      <span class="mp-era">${esc(b.era?.name || '')}</span>
    </div>
    <p class="mp-sides">${b.sides.map((s) => esc(s.name)).join(' <span class="mp-vs">对</span> ')}</p>
    <p class="mp-result">${esc(b.result.text || '')}</p>
    <div class="mp-foot">
      <span class="mp-loc">${esc(b.location.ancient || '')} · ${esc(b.location.modern || '')}${
    outside ? '<i class="mp-outside-tag">境外示意</i>' : ''
  }</span>
      <a class="btn btn--primary" href="#/battle/${encodeURIComponent(b.id)}">查看战史</a>
    </div>`;
  popup.hidden = false;
  requestAnimationFrame(() => popup.classList.add('is-open'));
  state.selected = battleId;
  // 高亮选中点位
  state.root.querySelectorAll('.map-points .mp.is-selected').forEach((el) => el.classList.remove('is-selected'));
  state.root.querySelector(`.map-points [data-battle="${CSS.escape(battleId)}"]`)?.classList.add('is-selected');
}

function hidePopup() {
  const popup = state?.popup;
  if (!popup) return;
  popup.classList.remove('is-open');
  state.selected = null;
  state.root.querySelectorAll('.map-points .mp.is-selected').forEach((el) => el.classList.remove('is-selected'));
  setTimeout(() => {
    if (popup && !popup.classList.contains('is-open')) popup.hidden = true;
  }, 220);
}

/* ---------------- 缩放 / 拖动 ---------------- */
function baseScale() {
  return state.frame.clientWidth / mapW();
}

function clampScale(s) {
  return Math.min(MAX_SCALE, Math.max(MIN_SCALE, s));
}

function clampView() {
  const w = state.frame.clientWidth;
  const h = state.frame.clientHeight;
  const cw = w * state.scale;
  const ch = h * state.scale;
  state.tx = cw <= w + 0.5 ? (w - cw) / 2 : Math.min(0, Math.max(w - cw, state.tx));
  state.ty = ch <= h + 0.5 ? (h - ch) / 2 : Math.min(0, Math.max(h - ch, state.ty));
}

function applyView() {
  if (!state) return;
  state.canvas.style.transform = `translate3d(${state.tx.toFixed(2)}px, ${state.ty.toFixed(2)}px, 0) scale(${state.scale})`;
  const zoomEl = state.root.querySelector('#mapZoom');
  if (zoomEl) zoomEl.textContent = `${state.scale.toFixed(1)}×`;
}

function schedulePoints() {
  if (!state || state.pending) return;
  state.pending = requestAnimationFrame(() => {
    if (!state) return;
    state.pending = 0;
    renderPoints(false);
    // 缩放停止后再播放一次聚合/点位展开动画，避免拖动过程中持续重排
    clearTimeout(state.animTimer);
    state.animTimer = setTimeout(() => {
      if (state) renderPoints(true);
    }, 420);
  });
}

function zoomAt(fx, fy, factor, { render = true } = {}) {
  const old = state.scale;
  const s = clampScale(old * factor);
  if (s === old) return;
  const ax = (fx - state.tx) / old;
  const ay = (fy - state.ty) / old;
  state.scale = s;
  state.tx = fx - ax * s;
  state.ty = fy - ay * s;
  clampView();
  applyView();
  if (render) schedulePoints();
}

function resetView() {
  state.scale = 1;
  state.tx = 0;
  state.ty = 0;
  applyView();
  schedulePoints();
}

function zoomToCluster(x, y) {
  // 让聚合中心移动到视野中心，并放大
  const targetScale = clampScale(Math.max(state.scale * 1.9, 2.2));
  const w = state.frame.clientWidth;
  const h = state.frame.clientHeight;
  const bs = baseScale();
  state.scale = targetScale;
  state.tx = w / 2 - x * bs * targetScale;
  state.ty = h / 2 - y * bs * targetScale;
  clampView();
  applyView();
  schedulePoints();
}

function bindMapInteraction() {
  const frame = state.frame;
  const pointers = new Map();
  let dragStart = null;
  let pinchStart = null;
  let moved = 0;

  const localPoint = (e) => {
    const r = frame.getBoundingClientRect();
    return { x: e.clientX - r.left, y: e.clientY - r.top };
  };

  frame.addEventListener('pointerdown', (e) => {
    if (e.target.closest('.map-controls')) return;
    frame.setPointerCapture(e.pointerId);
    pointers.set(e.pointerId, { sx: e.clientX, sy: e.clientY });
    if (pointers.size === 1) {
      dragStart = { x: e.clientX, y: e.clientY, tx: state.tx, ty: state.ty };
      moved = 0;
    } else if (pointers.size === 2) {
      const pts = [...pointers.values()];
      pinchStart = {
        dist: Math.hypot(pts[0].sx - pts[1].sx, pts[0].sy - pts[1].sy),
        mid: localPoint(e),
        scale: state.scale,
        tx: state.tx,
        ty: state.ty,
      };
      dragStart = null;
    }
    e.preventDefault();
  });

  frame.addEventListener('pointermove', (e) => {
    if (!pointers.has(e.pointerId)) return;
    pointers.set(e.pointerId, { sx: e.clientX, sy: e.clientY });

    if (pointers.size >= 2 && pinchStart) {
      const pts = [...pointers.values()];
      const dist = Math.hypot(pts[0].sx - pts[1].sx, pts[0].sy - pts[1].sy) || 1;
      const mid = localPoint(e);
      const targetScale = clampScale(pinchStart.scale * (dist / Math.max(1, pinchStart.dist)));
      const ax = (pinchStart.mid.x - pinchStart.tx) / pinchStart.scale;
      const ay = (pinchStart.mid.y - pinchStart.ty) / pinchStart.scale;
      state.scale = targetScale;
      state.tx = mid.x - ax * targetScale;
      state.ty = mid.y - ay * targetScale;
      clampView();
      applyView();
      schedulePoints();
      moved = 99;
      return;
    }

    if (dragStart) {
      const dx = e.clientX - dragStart.x;
      const dy = e.clientY - dragStart.y;
      moved = Math.max(moved, Math.abs(dx) + Math.abs(dy));
      state.tx = dragStart.tx + dx;
      state.ty = dragStart.ty + dy;
      clampView();
      applyView();
    }
  });

  const endPointer = (e) => {
    pointers.delete(e.pointerId);
    if (pointers.size < 2) pinchStart = null;
    if (pointers.size === 0) dragStart = null;
    if (pointers.size === 1) {
      const p = [...pointers.values()][0];
      dragStart = { x: p.sx, y: p.sy, tx: state.tx, ty: state.ty };
    }
  };
  frame.addEventListener('pointerup', endPointer);
  frame.addEventListener('pointercancel', endPointer);

  frame.addEventListener(
    'wheel',
    (e) => {
      e.preventDefault();
      const p = localPoint(e);
      zoomAt(p.x, p.y, Math.exp(-e.deltaY * 0.0016));
    },
    { passive: false }
  );

  frame.addEventListener('click', (e) => {
    if (moved > 6) return;
    const cluster = e.target.closest('[data-cluster]');
    if (cluster) {
      const ids = cluster.dataset.cluster.split(',');
      const b = state.ctx.data.byId.get(ids[0]);
      if (!b) return;
      const [x, y] = proj(b.location.lng, b.location.lat);
      hidePopup();
      zoomToCluster(x, y);
      return;
    }
    const point = e.target.closest('[data-battle]');
    if (point) {
      showPopup(point.dataset.battle);
      return;
    }
    hidePopup();
  });

  frame.addEventListener('dblclick', (e) => {
    const p = localPoint(e);
    zoomAt(p.x, p.y, 1.7);
  });

  state.root.querySelector('.map-controls').addEventListener('click', (e) => {
    const btn = e.target.closest('[data-map-action]');
    if (!btn) return;
    const cx = frame.clientWidth / 2;
    const cy = frame.clientHeight / 2;
    if (btn.dataset.mapAction === 'zoom-in') zoomAt(cx, cy, 1.5);
    if (btn.dataset.mapAction === 'zoom-out') zoomAt(cx, cy, 1 / 1.5);
    if (btn.dataset.mapAction === 'reset') resetView();
  });
}

/* ---------------- 筛选交互 ---------------- */
function bindFilters() {
  const { root, ctx } = state;

  root.querySelector('#mapEraRow').addEventListener('click', (e) => {
    const chip = e.target.closest('[data-era]');
    if (!chip) return;
    state.era = chip.dataset.era;
    root.querySelectorAll('#mapEraRow .m-chip').forEach((c) => c.classList.toggle('is-active', c === chip));
    hidePopup();
    clearTimeout(state.animTimer);
    renderPoints(true);
    announceMapChange();
  });

  root.querySelector('#mapTypeRow').addEventListener('click', (e) => {
    const chip = e.target.closest('[data-type]');
    if (!chip) return;
    const value = chip.dataset.type;
    if (value === 'all') {
      state.types.clear();
    } else if (state.types.size === 0) {
      state.types.add(value);
    } else if (state.types.has(value)) {
      state.types.delete(value);
    } else {
      state.types.add(value);
    }
    root.querySelectorAll('#mapTypeRow .m-chip').forEach((c) => {
      if (c.dataset.type === 'all') c.classList.toggle('is-active', state.types.size === 0);
      else c.classList.toggle('is-active', state.types.has(c.dataset.type));
    });
    hidePopup();
    clearTimeout(state.animTimer);
    renderPoints(true);
    announceMapChange();
  });

  state.popup.addEventListener('click', (e) => {
    if (e.target.closest('[data-popup-close]')) hidePopup();
  });

  root.querySelector('#mapListToggle').addEventListener('click', (e) => {
    state.listExpanded = !state.listExpanded;
    e.currentTarget.setAttribute('aria-expanded', state.listExpanded ? 'true' : 'false');
    renderList(filteredBattles(state.ctx.data));
  });

  root.querySelector('[data-action="search"]').addEventListener('click', () => navigate('/search'));

  // 键盘访问点位 / 聚合气泡（挂在 frame 上，底图回退重建后仍有效）
  state.frame.addEventListener('keydown', (e) => {
    if (e.key !== 'Enter' && e.key !== ' ') return;
    const cluster = e.target.closest('[data-cluster]');
    if (cluster) {
      e.preventDefault();
      const first = state.ctx.data.byId.get(cluster.dataset.cluster.split(',')[0]);
      if (first) {
        const [x, y] = proj(first.location.lng, first.location.lat);
        zoomToCluster(x, y);
      }
      return;
    }
    const g = e.target.closest('[data-battle]');
    if (g) {
      e.preventDefault();
      showPopup(g.dataset.battle);
    }
  });

  bindMapInteraction();
  window.addEventListener('resize', onResize);
}

function announceMapChange() {
  if (!state) return;
  const status = state.root.querySelector('#mapStatus');
  if (status) status.textContent = `已筛选 ${filteredBattles(state.ctx.data).length} 场落位`;
}

function onResize() {
  if (!state) return;
  clampView();
  applyView();
  schedulePoints();
}

/* ---------------- 入口 ---------------- */
export function renderMap(root, ctx) {
  disposeMap();

  if (!ctx.data || !ctx.data.ok || !ctx.data.battles.length) {
    root.innerHTML = `<div class="map-page">
      <header class="page-head">
        <div class="head-title">战役地图<span class="head-sub">数据准备中</span></div>
      </header>
      <div class="page-body">${emptyStateHTML({
        title: '地图暂时无点位',
        desc: '战役数据尚未就绪，或数据文件不可读。请稍后重试，或先回到时间轴阅读。',
        actions: '<button class="btn btn--gold" type="button" data-action="retry">重新载入</button><button class="btn" type="button" data-action="home">回到时间轴</button>',
      })}</div>
    </div>`;
    root.querySelector('[data-action="retry"]')?.addEventListener('click', () => window.location.reload());
    root.querySelector('[data-action="home"]')?.addEventListener('click', () => navigate('/'));
    return;
  }

  const mode = 'std';
  root.innerHTML = pageHTML(ctx, mode);

  // 摘要卡挂在 body 上：避免被 .view > * 的动画 transform 影响 fixed 定位
  const popup = document.createElement('div');
  popup.id = 'mapPopup';
  popup.className = 'map-popup';
  popup.hidden = true;
  document.body.appendChild(popup);

  const frame = root.querySelector('#mapFrame');
  state = {
    root,
    ctx,
    mode,
    frame,
    canvas: root.querySelector('#mapCanvas'),
    popup,
    era: 'all',
    types: new Set(),
    scale: 1,
    tx: 0,
    ty: 0,
    selected: null,
    listExpanded: false,
    pending: 0,
    animTimer: 0,
  };
  // 初始视图：标准地图整幅含图例与南海附图，首屏适度放大聚焦国土
  if (mode === 'std') {
    const focus = stdProject(104.5, 35.0);
    const bs = frame.clientWidth / STD.width;
    state.scale = 1.9;
    state.tx = frame.clientWidth / 2 - focus[0] * bs * state.scale;
    state.ty = frame.clientHeight / 2 - focus[1] * bs * state.scale;
    clampView();
  }
  applyView();
  bindFilters();
  renderPoints(true);

  // 标准地图加载失败 -> 回退示意轮廓（并在提示区说明）
  const probe = new Image();
  probe.onerror = () => {
    if (!state || state.mode !== 'std') return;
    state.mode = 'vector';
    state.canvas.innerHTML = mapSVG('vector');
    state.scale = 1;
    state.tx = 0;
    state.ty = 0;
    applyView();
    renderPoints(true);
    const hint = state.root.querySelector('#mapHint');
    if (hint) {
      hint.innerHTML =
        '<b>已回退示意轮廓</b> · 标准地图底图（assets/standard-map.jpg）加载失败，点位落位仍按经纬度绘制<br>' +
        '双指缩放 / 滚轮缩放 · 拖动浏览 · 低缩放时数字气泡为聚合点，点按可放大';
    }
    const headSub = state.root.querySelector('.head-sub');
    if (headSub) headSub.textContent = `${ctx.data.total} 场 · 示意轮廓（底图回退）`;
  };
  probe.src = STD.src;
}

export function disposeMap() {
  window.removeEventListener('resize', onResize);
  if (state) {
    clearTimeout(state.animTimer);
    if (state.pending) cancelAnimationFrame(state.pending);
  }
  document.getElementById('mapPopup')?.remove();
  state = null;
}

