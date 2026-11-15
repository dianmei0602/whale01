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
   资产：assets/standard-map.jpg（6000×3887，由官方 300dpi 原图 10599×6867 等比缩放，1.76MB）
   标定（3.0 重标定）：图面 ◎ 符号模板匹配 + 严格 RANSAC，得到 10 个互洽控制点，
        拟合二次多项式 (lng,lat)->像素：样本内残差 0.89km、留一验证 2.78km。
        说明：本地图幅符号密集（每个县级驻地都是同款 ◎），模板匹配易混入邻镇符号，
        故只保留经严格一致性检验的 10 个控制点（详见 www/assets/map-source.md §4）。
   精度口径：**展示级精度，不作量测**。控制点 10 个（长春/杭州/武汉/广州/南宁/昆明/兰州/
        银川/台北/重庆），样本内 0.89km、留一 2.78km、最大 1.81km；边角（喀什/漠河/
        三亚/抚远等）为外推，误差估计 ≤5km。人工补点工具见 .tmp/calibrate.html（3.1 可选）。
   说明：2.1 起改用「有邻国」图幅，朝鲜半岛/越南/蒙古/哈萨克斯坦方向的
        境外战场点可落入对应邻国境内；旧的「无邻国」图保留为
        assets/standard-map-nonborder.jpg 备查。
   兜底：底图加载失败时回退 china-geo.js 的示意轮廓。 */
const STD = {
  src: 'assets/standard-map.jpg',
  width: 6000,
  height: 3887,
  lon0: 105.0,
  lat0: 35.0,
  slon: 30.0,
  slat: 20.0,
  // u=(lng-105)/30, v=(lat-35)/20；基函数 [1, u, v, u², uv, v²]
  cx: [2924.1691, 2390.4014, 125.4595, -1.6202, -654.1567, 47.6054],
  cy: [2044.5089, 83.4247, -2016.0923, -324.8105, 14.3514, -10.0471],
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

    <g class="map-territories" id="mapTerritories"></g>
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
    <div class="map-filter-row map-layer-row no-scrollbar" id="mapLayerRow" aria-label="图层">
      <button class="m-chip m-chip--layer" type="button" data-layer="territories">势力范围</button>
      <span class="map-layer-note" id="mapLayerNote" hidden></span>
    </div>
  </div>`;
}

function pageHTML(ctx, mode) {
  return `<div class="map-page">
    <header class="page-head">
      <div class="head-title">战役地图<span class="head-sub">${ctx.data.total} 场 · ${
      mode === 'vector' ? '示意轮廓（底图回退）' : '标准地图'
    }</span></div>
      <div class="head-actions">
        <a class="icon-btn icon-btn--text" href="#/legend#map" aria-label="打开地图图例">图例</a>
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
          <i class="lg lg-ring" aria-hidden="true"></i>决战
          <i class="lg lg-out" aria-hidden="true"></i>境外
          <i class="lg lg-cluster" aria-hidden="true"></i>聚合
          <span class="lg-terr-wrap" id="lgTerr" hidden><i class="lg lg-terr" aria-hidden="true"></i>势力范围</span>
        </span>
      </div>

      <div class="map-focus" id="mapFocus" hidden></div>
      <p class="map-scale" id="mapScale">比例尺 1:740万 · 审图号 GS(2022)4307号 · 自然资源部监制<br>点位为展示级精度，不作量测（控制点 10 个，样本内残差 0.89km）</p>

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

/* ---------------- 势力范围图层（3.0） ---------------- */
const TERR = {
  provinces: null, // GeoJSON
  factions: null, // [{id,name,color,eraIds}]
  territories: null, // [{factionId, provinces[]}]
  loading: null,
};

const PROV_ALIAS = {
  内蒙古自治区: '内蒙古', 广西壮族自治区: '广西', 西藏自治区: '西藏',
  宁夏回族自治区: '宁夏', 新疆维吾尔自治区: '新疆', 香港特别行政区: '香港',
  澳门特别行政区: '澳门', 台湾省: '台湾',
};

function normProv(name) {
  const n = String(name || '').trim();
  if (PROV_ALIAS[n]) return PROV_ALIAS[n];
  return n.replace(/(省|市|自治区|特别行政区)$/g, '');
}

async function loadTerritoryData() {
  if (TERR.provinces && TERR.factions && TERR.territories) return TERR;
  if (TERR.loading) return TERR.loading;
  TERR.loading = (async () => {
    const [pv, fa, te] = await Promise.all([
      fetch('data/china-provinces.json', { cache: 'no-store' }).then((r) => {
        if (!r.ok) throw new Error(`provinces HTTP ${r.status}`);
        return r.json();
      }),
      fetch('data/factions.json', { cache: 'no-store' }).then((r) => (r.ok ? r.json() : [])),
      fetch('data/territories.json', { cache: 'no-store' }).then((r) => {
        if (!r.ok) throw new Error(`territories HTTP ${r.status}`);
        return r.json();
      }),
    ]);
    TERR.provinces = pv;
    TERR.factions = Array.isArray(fa) ? fa : fa.factions || [];
    TERR.territories = Array.isArray(te) ? te : te.factions || [];
    return TERR;
  })();
  return TERR.loading;
}

function provPathD(geom) {
  const polys = geom.type === 'Polygon' ? [geom.coordinates] : geom.coordinates;
  const parts = [];
  for (const poly of polys) {
    for (const ring of poly) {
      let started = false;
      for (const [lng, lat] of ring) {
        const [x, y] = stdProject(lng, lat);
        parts.push(`${started ? 'L' : 'M'}${x.toFixed(1)},${y.toFixed(1)}`);
        started = true;
      }
      parts.push('Z');
    }
  }
  return parts.join('');
}

function renderTerritories() {
  if (!state) return;
  const g = state.root.querySelector('#mapTerritories');
  if (!g) return;
  if (!state.terrOn || !TERR.provinces) {
    g.innerHTML = '';
    return;
  }
  const era = state.era;
  const factionById = new Map(TERR.factions.map((f) => [f.id, f]));
  const focusId = state.factionFocus || '';
  if (focusId) {
    const provSet = new Set(factionProvinces(focusId));
    const f = factionById.get(focusId) || { color: '#C9A227', name: focusId };
    const color = f.color || '#C9A227';
    const feats = (TERR.provinces.features || []).filter((feat) =>
      provSet.has(normProv(feat.properties && feat.properties.name))
    );
    g.innerHTML = feats
      .map(
        (feat) =>
          `<path class="terr-prov is-focus" data-prov="${esc(
            normProv(feat.properties && feat.properties.name)
          )}" d="${provPathD(feat.geometry)}" fill="${color}" fill-opacity="0.34" stroke="${color}" stroke-opacity="0.72" stroke-width="7" stroke-linejoin="round"/>`
      )
      .join('');
    const note = state.root.querySelector('#mapLayerNote');
    if (note) {
      note.hidden = false;
      note.textContent = `势力版图：${f.name || focusId} · ${feats.length} 省（示意，非精确疆域）`;
    }
    return;
  }
  const active = TERR.territories.filter((t) => {
    if (era === 'all') return true;
    const f = factionById.get(t.factionId);
    return f && Array.isArray(f.eraIds) && f.eraIds.includes(era);
  });
  if (!active.length) {
    g.innerHTML = '';
    return;
  }
  const owner = new Map(); // 省 -> faction
  for (const t of active) {
    for (const p of t.provinces || []) {
      const key = normProv(p);
      if (!owner.has(key)) owner.set(key, factionById.get(t.factionId) || { color: '#C9A227', name: t.factionId });
    }
  }
  const alpha = era === 'all' ? 0.14 : 0.22;
  const strokes = era === 'all' ? 0.28 : 0.5;
  const paths = [];
  for (const feat of TERR.provinces.features || []) {
    const key = normProv(feat.properties && feat.properties.name);
    const f = owner.get(key);
    if (!f) continue;
    const color = f.color || '#C9A227';
    paths.push(
      `<path class="terr-prov" data-prov="${esc(key)}" d="${provPathD(feat.geometry)}" fill="${color}" fill-opacity="${alpha}" stroke="${color}" stroke-opacity="${strokes}" stroke-width="5" stroke-linejoin="round"/>`
    );
  }
  g.innerHTML = paths.join('');
  const note = state.root.querySelector('#mapLayerNote');
  if (note) {
    const used = new Set([...owner.values()].map((f) => f.name || f.id));
    note.textContent =
      `势力范围：已绘制 ${paths.length} 省 · ${used.size} 个势力` +
      (era === 'all' ? '（全部时期叠加，示意）' : '');
  }
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
  renderTerritories();
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
const PRECISION_TEXT = { 确: '精确位置（确）', 约: '约略位置（约）', 传说: '传说地点（传说）' };
const PRECISION_NOTE = '展示级精度，不作量测';
function precisionText(v) {
  return PRECISION_TEXT[v] || '位置精度未标注';
}

/* ---------------- 定位（#/map?battle=<id>） ---------------- */
function battleQuery() {
  const raw = String((window.location && window.location.hash) || '');
  const m = /[?&]battle=([^&#]+)/.exec(raw);
  if (!m) return '';
  try {
    return decodeURIComponent(m[1]);
  } catch (err) {
    return m[1];
  }
}

/* ---------------- 势力版图定位（#/map?faction=<id>） ---------------- */
function factionQuery() {
  const raw = String((window.location && window.location.hash) || '');
  const m = /[?&]faction=([^&#]+)/.exec(raw);
  if (!m) return '';
  try {
    return decodeURIComponent(m[1]);
  } catch (err) {
    return m[1];
  }
}

function factionName(id) {
  const f = (TERR.factions || []).find((x) => x.id === id);
  return f ? f.name : id;
}

function factionProvinces(id) {
  const t = (TERR.territories || []).find((x) => x.factionId === id);
  return t ? (t.provinces || []).map(normProv) : [];
}

function setTerritoryChip(on) {
  if (!state) return;
  const chip = state.root.querySelector('[data-layer="territories"]');
  if (chip) {
    chip.classList.toggle('is-active', on);
    chip.setAttribute('aria-pressed', on ? 'true' : 'false');
  }
  const lg = state.root.querySelector('#lgTerr');
  if (lg) lg.hidden = !on;
}

function showFocusChip(inner, faction = false) {
  if (!state) return;
  const chip = state.root.querySelector('#mapFocus');
  if (!chip) return;
  chip.hidden = false;
  chip.classList.toggle('map-focus--faction', !!faction);
  chip.innerHTML = `${inner}<button class="mf-clear" type="button" data-focus-clear aria-label="清除定位">${icon(
    'close'
  )}</button>`;
  chip.querySelector('[data-focus-clear]').addEventListener('click', () => clearFocus(true));
}

function factionBBox(provSet) {
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (const feat of (TERR.provinces && TERR.provinces.features) || []) {
    const key = normProv(feat.properties && feat.properties.name);
    if (!provSet.has(key)) continue;
    const polys = feat.geometry.type === 'Polygon' ? [feat.geometry.coordinates] : feat.geometry.coordinates;
    for (const poly of polys) {
      for (const ring of poly) {
        for (const pair of ring) {
          const p = stdProject(pair[0], pair[1]);
          if (p[0] < minX) minX = p[0];
          if (p[0] > maxX) maxX = p[0];
          if (p[1] < minY) minY = p[1];
          if (p[1] > maxY) maxY = p[1];
        }
      }
    }
  }
  return Number.isFinite(minX) ? { minX, minY, maxX, maxY } : null;
}

function focusOnFaction(id) {
  if (!state || !id) return false;
  const name = factionName(id);
  const provs = factionProvinces(id);
  const note = state.root.querySelector('#mapLayerNote');
  if (!provs.length) {
    // 空态：不开启图层，给出提示与可清除的定位条
    state.factionFocus = '';
    setTerritoryChip(false);
    renderTerritories();
    showFocusChip(
      `<span class="mf-k mf-k--faction">势力</span><b class="mf-name">${esc(name)}</b><span class="mf-era">暂无版图数据</span>`,
      true
    );
    if (note) {
      note.hidden = false;
      note.textContent = `势力范围：未找到「${name}」的版图数据（territories.json）`;
    }
    return false;
  }
  state.factionFocus = id;
  state.terrOn = true;
  state.focusTarget = '';
  setTerritoryChip(true);
  renderTerritories();
  const box = factionBBox(new Set(provs));
  if (box) {
    const w = state.frame.clientWidth;
    const h = state.frame.clientHeight;
    const bs = w / mapW();
    const cx = (box.minX + box.maxX) / 2;
    const cy = (box.minY + box.maxY) / 2;
    const spanX = Math.max(1, box.maxX - box.minX);
    const spanY = Math.max(1, box.maxY - box.minY);
    const fit = Math.min(w / (spanX * bs), h / (spanY * bs)) * 0.82;
    state.scale = clampScale(Math.min(3.6, Math.max(1.25, fit)));
    state.tx = w / 2 - cx * bs * state.scale;
    state.ty = h / 2 - cy * bs * state.scale;
    clampView();
    applyView();
    renderPoints(true);
  }
  showFocusChip(
    `<span class="mf-k mf-k--faction">势力</span><b class="mf-name">${esc(name)}</b><span class="mf-era">版图示意 · ${provs.length} 省</span>`,
    true
  );
  const status = state.root.querySelector('#mapStatus');
  if (status) status.textContent = `已定位势力：${name}`;
  return true;
}

function hideFocusChip() {
  const chip = state && state.root.querySelector('#mapFocus');
  if (chip) {
    chip.hidden = true;
    chip.innerHTML = '';
  }
}

function focusOnBattle(id) {
  if (!state) return false;
  const b = state.ctx.data.byId.get(id);
  if (!b) return false;
  const [x, y] = proj(b.location.lng, b.location.lat);
  const w = state.frame.clientWidth;
  const h = state.frame.clientHeight;
  const bs = w / mapW();
  state.scale = clampScale(3.2);
  state.focusTarget = id;
  state.tx = w / 2 - x * bs * state.scale;
  state.ty = h / 2 - y * bs * state.scale;
  clampView();
  applyView();
  renderPoints(true);
  showPopup(id);
  const chip = state.root.querySelector('#mapFocus');
  if (chip) {
    chip.hidden = false;
    chip.innerHTML = `<span class="mf-k">定位</span><b class="mf-name">${esc(b.name)}</b><span class="mf-era">${esc(
      b.era ? b.era.name : ''
    )}</span><button class="mf-clear" type="button" data-focus-clear aria-label="清除定位">${icon('close')}</button>`;
    chip.querySelector('[data-focus-clear]').addEventListener('click', () => clearFocus(true));
  }
  const status = state.root.querySelector('#mapStatus');
  if (status) status.textContent = `已定位：${b.name}`;
  return true;
}

function clearFocus(resetView = false) {
  hideFocusChip();
  hidePopup();
  if (state) {
    state.focusTarget = null;
    state.factionFocus = '';
    if (state.terrOn) {
      state.terrOn = false;
      setTerritoryChip(false);
      renderTerritories();
      const note = state.root.querySelector('#mapLayerNote');
      if (note) {
        note.hidden = true;
        note.textContent = '';
      }
    }
  }
  if (state && /[?&](battle|faction)=/.test(String(window.location.hash || ''))) {
    try {
      window.history.replaceState(null, '', '#/map');
    } catch (err) {
      /* 忽略，仅清理视觉状态 */
    }
  }
  if (resetView) resetView();
}
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
    <p class="mp-precision"><span class="mp-precision-k">位置</span>${esc(precisionText(b.location.precision))}<span class="mp-precision-note">${PRECISION_NOTE}</span></p>
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
    if (e.isTrusted && state.focusTarget) state.focusTarget = null;
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
    // 定位模式：忽略 app.js locateOnMap 触发的合成点击，避免连跳聚合缩放覆盖定位视图
    if (!e.isTrusted && state.focusTarget) return;
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
    hideFocusChip();
    hidePopup();
    if (state.factionFocus) {
      state.factionFocus = '';
      state.terrOn = false;
      setTerritoryChip(false);
    }
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
    hideFocusChip();
    hidePopup();
    if (state.factionFocus) {
      state.factionFocus = '';
      state.terrOn = false;
      setTerritoryChip(false);
    }
    clearTimeout(state.animTimer);
    renderPoints(true);
    announceMapChange();
  });

  state.popup.addEventListener('click', (e) => {
    if (e.target.closest('[data-popup-close]')) hidePopup();
  });

  root.querySelector('#mapLayerRow').addEventListener('click', async (e) => {
    const chip = e.target.closest('[data-layer]');
    if (!chip) return;
    const on = !chip.classList.contains('is-active');
    chip.classList.toggle('is-active', on);
    chip.setAttribute('aria-pressed', on ? 'true' : 'false');
    const note = root.querySelector('#mapLayerNote');
    const lg = root.querySelector('#lgTerr');
    if (lg) lg.hidden = !on;
    if (!on) {
      state.terrOn = false;
      // 手动关闭图层时一并解除势力版图聚焦，避免定位条与图层状态不一致
      if (state.factionFocus) {
        state.factionFocus = '';
        hideFocusChip();
        if (/[?&]faction=/.test(String(window.location.hash || ''))) {
          try {
            window.history.replaceState(null, '', '#/map');
          } catch (err) {
            /* 忽略 */
          }
        }
      }
      renderTerritories();
      if (note) {
        note.hidden = true;
        note.textContent = '';
      }
      return;
    }
    if (note) {
      note.hidden = false;
      note.textContent = '势力范围：读取数据中…';
    }
    state.terrOn = true;
    try {
      await loadTerritoryData();
      renderTerritories();
    } catch (err) {
      if (note) note.textContent = '势力范围：数据加载失败（territories.json / china-provinces.json）';
    }
    return;
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
    terrOn: false,
    factionFocus: '',
    focusTarget: '',
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

  // #/map?battle=<id>：定位并弹出摘要卡
  const target = battleQuery();
  if (target && ctx.data.byId.get(target)) {
    // app.js 的 locateOnMap 会合成点击点位/聚合点；置 focusTarget 后由本模块接管，
    // 并在 click 处理器里忽略这些合成点击（见 bindMapInteraction）。
    state.focusTarget = target;
    requestAnimationFrame(() => {
      if (state && ctx.data.byId.get(target)) focusOnBattle(target);
    });
  }

  // #/map?faction=<id>：自动开启势力范围图层并高亮定位（?battle= 优先）
  const facTarget = factionQuery();
  if (facTarget && !target) {
    (async () => {
      try {
        await loadTerritoryData();
        if (state) focusOnFaction(facTarget);
      } catch (err) {
        if (state) {
          const note = state.root.querySelector('#mapLayerNote');
          if (note) {
            note.hidden = false;
            note.textContent = '势力范围：数据加载失败（territories.json / china-provinces.json）';
          }
        }
      }
    })();
  }

  // 标准地图加载失败 -> 回退示意轮廓（并在提示区说明）
  const probe = new Image();
  probe.onerror = () => {
    if (!state || state.mode !== 'std') return;
    state.mode = 'vector';
    state.canvas.innerHTML = mapSVG('vector');
    state.terrOn = false;
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
  // 释放高清底图解码引用，离开地图页后让 WKWebView 更早回收内存
  try {
    const img = state?.canvas?.querySelector('image');
    if (img) img.setAttribute('href', '');
  } catch (err) {
    /* ignore */
  }
  state = null;
}

