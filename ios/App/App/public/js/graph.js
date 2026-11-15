/* ============================================================
   graph.js — 2.0 名将关系图谱
   40 位名将节点 + relations.json 关系线；按时代分层的确定性布局
   支持节点拖动 / 画布缩放平移 / 点击看小传 / 时代筛选 / 关系图例
   ============================================================ */

import { esc, icon, fmtYear, emptyStateHTML } from './ui.js';
import { navigate, navigateBack } from './router.js';
import { initDrawerSpring } from './motion.js';

const W = 780;
const H = 760;
const PAD_X = 62;
const TOP = 104;
const BOTTOM = 56;
const ZOOM_ALL_LABELS = 1.2;
const LABEL_CHAR_W = 16;
const LABEL_H = 16;
const LAYOUT_MS = 200;

const reducedMotion = () =>
  (typeof document !== 'undefined' && document.documentElement.dataset.motion === 'reduce') ||
  (typeof window !== 'undefined' && window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);

const TYPE_STYLES = {
  父子: { color: '#C94B3A', dash: '', width: 2.6 },
  兄弟: { color: '#E0C060', dash: '', width: 2.2 },
  舅甥: { color: '#C08A4A', dash: '', width: 2.0 },
  师徒: { color: '#7E8F72', dash: '', width: 2.2 },
  君臣: { color: '#C9A227', dash: '6 4', width: 2.2 },
  同僚: { color: '#9C907B', dash: '', width: 1.6 },
  盟友: { color: '#6F7B66', dash: '', width: 2.0 },
  对手: { color: '#C94B3A', dash: '5 5', width: 2.4 },
  举荐: { color: '#A9A08C', dash: '2 4', width: 1.8 },
  姻亲: { color: '#D98C7C', dash: '2 3', width: 1.6 },
  世交: { color: '#B8783A', dash: '8 4 2 4', width: 1.8 },
};
const TYPE_ORDER = Object.keys(TYPE_STYLES);

let state = null;
let generalsPromise = null;

function loadGenerals() {
  if (!generalsPromise) {
    generalsPromise = fetch('data/generals.json', { cache: 'no-cache' })
      .then((res) => (res.ok ? res.json() : null))
      .then((list) => (Array.isArray(list) ? list : []))
      .catch(() => []);
  }
  return generalsPromise;
}

function eraIndexOf(eraIds) {
  const first = (eraIds || [])[0] || '';
  const n = parseInt(String(first).replace('era-', ''), 10);
  return Number.isFinite(n) ? n : 1;
}

/* ---------------- 布局 ---------------- */
function buildNodes(ctx, generals, featuredIds = null) {
  const byId = new Map();
  for (const g of generals) {
    if (!g || !g.id || g.featured === false) continue;
    byId.set(g.id, {
      id: g.id,
      name: g.name || g.id,
      eraIdx: eraIndexOf(g.eraIds),
      era: ctx.data.eraById.get((g.eraIds || [])[0]),
      camp: g.camp || '',
      title: g.title || '',
      life: g.life || '',
      bio: g.bio || '',
      battles: g.battles || [],
      eras: g.eraIds || [],
      synthetic: false,
    });
  }
  // relations 中可能出现 generals 之外的 id：只补 featured 节点，避免新增人物进图
  for (const r of ctx.data.relations) {
    for (const id of [r.source, r.target]) {
      if (featuredIds && !featuredIds.has(id)) continue;
      if (!byId.has(id)) {
        byId.set(id, {
          id,
          name: id,
          eraIdx: eraIndexOf(r.eraIds),
          era: ctx.data.eraById.get((r.eraIds || [])[0]),
          camp: '',
          title: '',
          life: '',
          bio: '',
          battles: [],
          eras: r.eraIds || [],
          synthetic: true,
        });
      }
    }
  }
  return [...byId.values()];
}

function layoutNodes(nodes, eras) {
  const groups = new Map();
  for (const n of nodes) {
    if (!groups.has(n.eraIdx)) groups.set(n.eraIdx, []);
    groups.get(n.eraIdx).push(n);
  }
  const maxEra = Math.max(12, ...groups.keys());
  for (const [idx, list] of groups) {
    list.sort((a, b) => a.name.localeCompare(b.name, 'zh'));
    const x = PAD_X + ((idx - 1) / (maxEra - 1)) * (W - PAD_X * 2);
    const usable = H - TOP - BOTTOM;
    const step = Math.min(76, usable / Math.max(1, list.length));
    list.forEach((n, i) => {
      const y = H / 2 + (i - (list.length - 1) / 2) * step;
      // 舒展：当前分层大间距；紧凑：向中心收拢、层内更紧，优先成簇
      n.expanded = { x, y, labelDy: 34 + ((i + idx) % 2) * 17 };
      n.compact = {
        x: W / 2 + (x - W / 2) * 0.64,
        y: H / 2 + (y - H / 2) * 0.8,
        labelDy: 32 + ((i + idx) % 2) * 14,
      };
    });
  }
  return groups;
}

function applyLayoutPositions(mode) {
  for (const n of state.nodes) {
    const p = n[mode] || n.expanded;
    n.x = p.x;
    n.y = p.y;
    n.labelDy = p.labelDy;
    n.homeX = p.x;
    n.homeY = p.y;
  }
}

/* ---------------- 放射 / 网络视图 ---------------- */
function setViewMode(mode) {
  if (!state) return;
  state.mode = mode === 'radial' ? 'radial' : 'network';
  state.root.querySelectorAll('[data-g-mode]').forEach((btn) => {
    const on = btn.dataset.gMode === state.mode;
    btn.classList.toggle('is-active', on);
    btn.setAttribute('aria-pressed', on ? 'true' : 'false');
  });
  const hint = state.root.querySelector('#gRadialHint');
  if (state.mode === 'radial') {
    if (state.selected) applyRadialLayout();
    else {
      if (hint) hint.hidden = false;
      clearRadialVisibility();
      applyLayoutPositions(state.layoutMode);
      updatePositions();
      updateLabels();
    }
  } else {
    if (hint) hint.hidden = true;
    clearRadialVisibility();
    applyLayoutPositions(state.layoutMode);
    updatePositions();
    updateLabels();
  }
}

function clearRadialVisibility() {
  if (!state?.svg) return;
  state.svg.querySelectorAll('.g-node.is-radial-out, .g-link.is-radial-out').forEach((el) => el.classList.remove('is-radial-out'));
}

function applyRadialLayout() {
  if (!state || state.mode !== 'radial' || !state.svg) return;
  const selected = state.selected;
  const hint = state.root.querySelector('#gRadialHint');
  if (!selected) {
    if (hint) hint.hidden = false;
    return;
  }
  if (hint) hint.hidden = true;
  const related = state.links.filter((l) => l.sourceNode.id === selected.id || l.targetNode.id === selected.id);
  const neighborMap = new Map();
  for (const link of related) {
    const other = link.sourceNode.id === selected.id ? link.targetNode : link.sourceNode;
    if (!neighborMap.has(other.id)) neighborMap.set(other.id, { node: other, type: link.type });
  }
  const groups = new Map();
  for (const item of neighborMap.values()) {
    if (!groups.has(item.type)) groups.set(item.type, []);
    groups.get(item.type).push(item.node);
  }
  const types = [...groups.keys()].sort((a, b) => TYPE_ORDER.indexOf(a) - TYPE_ORDER.indexOf(b));
  selected.x = W / 2;
  selected.y = H / 2;
  selected.labelDy = 38;
  types.forEach((type, ti) => {
    const base = (ti / Math.max(1, types.length)) * Math.PI * 2 - Math.PI / 2;
    const list = groups.get(type);
    list.forEach((node, ni) => {
      const spread = list.length > 1 ? Math.min(0.92, 0.28 + 0.18 * (list.length - 1)) : 0;
      const angle = base + (list.length > 1 ? (ni / (list.length - 1) - 0.5) * spread : 0);
      const radius = list.length > 1 && ni % 2 === 1 ? 196 : 236;
      node.x = W / 2 + Math.cos(angle) * radius;
      node.y = H / 2 + Math.sin(angle) * radius;
      node.labelDy = 34 + (ni % 2) * 16;
    });
  });
  state.svg.querySelectorAll('.g-node').forEach((el) => {
    const id = el.dataset.node;
    el.classList.toggle('is-radial-out', id !== selected.id && !neighborMap.has(id));
  });
  state.svg.querySelectorAll('.g-link').forEach((el) => {
    const on = el.dataset.source === selected.id || el.dataset.target === selected.id;
    el.classList.toggle('is-radial-out', !on);
  });
  updatePositions();
  updateLabels();
}


/* ---------------- SVG ---------------- */
function nodeColor(node) {
  return node.era?.themeColor || '#C9A227';
}

function graphSVG(ctx, nodes, links, eraGroups) {
  const eras = ctx.data.eras;
  const eraLabels = eras
    .map((era, i) => {
      const x = PAD_X + (i / Math.max(1, eras.length - 1)) * (W - PAD_X * 2);
      const rowY = i % 2 === 0 ? TOP - 32 : TOP - 60;
      return `<g class="g-era-label">
        <line x1="${x.toFixed(1)}" y1="${TOP - 8}" x2="${x.toFixed(1)}" y2="${H - BOTTOM + 10}" class="g-era-line"/>
        <text x="${x.toFixed(1)}" y="${rowY}" text-anchor="middle" class="g-era-name">${esc(era.short || era.name)}</text>
        <text x="${x.toFixed(1)}" y="${rowY + 17}" text-anchor="middle" class="g-era-idx">${String(era.index).padStart(2, '0')}</text>
      </g>`;
    })
    .join('');

  const linkEls = links
    .map((l) => {
      const st = TYPE_STYLES[l.type] || TYPE_STYLES['同僚'];
      return `<line class="g-link" data-link="${esc(l.id)}" data-source="${esc(l.source)}" data-target="${esc(
        l.target
      )}" x1="${l.sourceNode.x.toFixed(1)}" y1="${l.sourceNode.y.toFixed(1)}" x2="${l.targetNode.x.toFixed(
        1
      )}" y2="${l.targetNode.y.toFixed(1)}" stroke="${st.color}" stroke-width="${(
        st.width *
        Math.max(1, l.strength / 2) *
        1.5
      ).toFixed(2)}" ${st.dash ? `stroke-dasharray="${st.dash}"` : ''} stroke-opacity="0.55"/>`;
    })
    .join('');

  const nodeEls = nodes
    .map(
      (n) => `<g class="g-node${n.synthetic ? ' is-synthetic' : ''}" data-node="${esc(n.id)}" tabindex="0" role="button" aria-label="${esc(
        n.name
      )}">
        <circle class="g-node-hit" cx="${n.x.toFixed(1)}" cy="${n.y.toFixed(1)}" r="40"/>
        <circle class="g-node-selring" cx="${n.x.toFixed(1)}" cy="${n.y.toFixed(1)}" r="27"/>
        <circle class="g-node-halo" cx="${n.x.toFixed(1)}" cy="${n.y.toFixed(1)}" r="35" fill="${nodeColor(n)}"/>
        <circle class="g-node-dot" cx="${n.x.toFixed(1)}" cy="${n.y.toFixed(1)}" r="18" fill="${nodeColor(n)}"/>
        <text class="g-node-name" x="${n.x.toFixed(1)}" y="${(n.y + (n.labelDy || 34)).toFixed(1)}" text-anchor="middle">${esc(n.name)}</text>
      </g>`
    )
    .join('');

  return `<svg class="graph-svg" viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMid meet" role="img" aria-label="名将关系图谱">
    <g class="g-era-labels">${eraLabels}</g>
    <g class="g-links">${linkEls}</g>
    <g class="g-nodes">${nodeEls}</g>
  </svg>`;
}

/* ---------------- 页面 ---------------- */
function graphPageHTML(ctx) {
  const eras = ctx.data.eras;
  const eraChips = [`<button class="g-chip is-active" type="button" data-era="all">全部</button>`]
    .concat(
      eras.map(
        (era) =>
          `<button class="g-chip" type="button" data-era="${esc(era.id)}">${String(era.index).padStart(2, '0')}<span>${esc(
            era.short || era.name
          )}</span></button>`
      )
    )
    .join('');
  const legend = TYPE_ORDER.map((type) => {
    const st = TYPE_STYLES[type];
    return `<span class="g-legend-item"><i class="g-legend-line" style="--c:${st.color};--dash:${
      st.dash || 'solid'
    }"></i>${type}</span>`;
  }).join('');

  return `<div class="graph-page">
    <header class="page-head">
      <button class="icon-btn" type="button" data-action="back" aria-label="返回上一页">${icon('back')}</button>
      <div class="head-title">关系图谱<span class="head-sub">40 位名将 · ${ctx.data.relations.length} 条关系</span></div>
      <div class="head-actions">
        <a class="icon-btn icon-btn--text" href="#/legend#graph" aria-label="打开关系图谱图例">图例</a>
        <button class="icon-btn" type="button" data-action="search" aria-label="搜索战役">${icon('search')}</button>
      </div>
    </header>

    <div class="graph-body">
      <div class="graph-switch-row">
        <div class="g-layer-seg" role="group" aria-label="图谱图层">
          <a class="g-layer-btn is-active" href="#/graph" aria-current="page">名将关系</a>
          <a class="g-layer-btn" href="#/graph?layer=state">国家关系</a>
        </div>
        <div class="g-view-seg" role="group" aria-label="名将视图">
          <button class="g-view-btn is-active" type="button" data-g-mode="network" aria-pressed="true">网络</button>
          <button class="g-view-btn" type="button" data-g-mode="radial" aria-pressed="false">放射</button>
        </div>
      </div>

      <div class="g-filter-row no-scrollbar" aria-label="按时期筛选">${eraChips}</div>

      <div class="graph-toolbar">
        <span class="graph-zoom" id="graphZoom">—</span>
        <div class="g-layout-seg" role="group" aria-label="布局密度">
          <button class="g-seg" type="button" data-layout="compact" aria-pressed="false">紧凑</button>
          <button class="g-seg is-active" type="button" data-layout="expanded" aria-pressed="true">舒展</button>
        </div>
        <button class="g-label-toggle" type="button" data-label-toggle aria-pressed="false" aria-label="显示全部标签" title="显示全部标签（缩放 < 1.2× 时）">标签</button>
        <div class="graph-controls">
          <button class="graph-ctl" type="button" data-graph-action="zoom-in" aria-label="放大">+</button>
          <button class="graph-ctl" type="button" data-graph-action="zoom-out" aria-label="缩小">−</button>
          <button class="graph-ctl" type="button" data-graph-action="reset" aria-label="复位视图">↺</button>
        </div>
      </div>

      <div class="graph-stage" id="graphStage">
        <div class="graph-canvas" id="graphCanvas">
          <div class="graph-loading" id="graphLoading">正在整理将星关系…</div>
        </div>
        <div class="g-radial-hint" id="gRadialHint" hidden>
          <b>放射模式</b>
          <span>点选一位名将作为中心</span>
          <small>一级按关系类型分叉，二级为对端人物</small>
        </div>
        <p class="graph-hint">缩放 ≥1.2× 显示全部标签 · 拖动节点 · 双指缩放 / 平移</p>
      </div>

      <div class="g-legend-wrap">
        <div class="g-legend-head"><span>关系类型</span><span>线宽 ← 关系强度</span></div>
        <div class="g-legend no-scrollbar">${legend}</div>
      </div>

      <p class="graph-foot">关系依据 generals.json 与 relations.json；节点按所属时期分层，位置为阅读性示意布局，拖动可自行整理。</p>
    </div>
  </div>`;
}

/* ---------------- 面板 ---------------- */
function panelHTML(ctx, node) {
  const data = ctx.data;
  const battles = (node.battles || [])
    .map((id) => data.byId.get(id))
    .filter(Boolean)
    .slice(0, 6)
    .map(
      (b) =>
        `<a class="gp-battle" href="#/battle/${encodeURIComponent(b.id)}">${esc(b.name)}<i>${esc(
          fmtYear(b.startYear)
        )}</i></a>`
    )
    .join('');
  const eraNames = (node.eras || [])
    .map((id) => data.eraById.get(id))
    .filter(Boolean)
    .map((e) => e.short || e.name)
    .join(' / ');
  const lifeText = node.life ? (/^生卒/.test(String(node.life)) ? String(node.life) : `生卒 · ${node.life}`) : '';
  const meta = [lifeText, node.camp ? `阵营 · ${node.camp}` : '', eraNames ? `时期 · ${eraNames}` : '']
    .filter(Boolean)
    .join('　');
  const clan = ctx.data?.clansByGeneral?.get(node.id);
  return `<button class="graph-panel-close" type="button" data-panel-close aria-label="关闭小传">${icon('close')}</button>
    <div class="gp-head">
      <span class="gp-seal" aria-hidden="true">${esc((node.name || '').slice(0, 1))}</span>
      <div class="gp-head-main">
        <h2 class="gp-name">${esc(node.name)}</h2>
        <p class="gp-title">${esc(node.title || node.camp || '')}</p>
        <p class="gp-meta">${esc(meta)}</p>
      </div>
    </div>
    <p class="gp-bio">${esc(node.bio || '该名将小传暂未收录。')}</p>
    ${
      clan
        ? `<a class="gp-family" href="#/clan/${encodeURIComponent(clan.id)}"><span>所属家族</span>${esc(clan.name)}<i aria-hidden="true">›</i></a>`
        : ''
    }
    ${
      battles
        ? `<div class="gp-battles"><span class="gp-battles-label">相关战役</span>${battles}</div>`
        : ''
    }`;
}

function showPanel(node) {
  if (!state) return;
  state.selected = node;
  const panel = state.panel;
  panel.tabIndex = -1;
  panel.innerHTML = panelHTML(state.ctx, node);
  panel.hidden = false;
  requestAnimationFrame(() => panel.classList.add('is-open'));
  state.panelReturnFocus = document.activeElement;
  try {
    panel.focus({ preventScroll: true });
  } catch (err) {
    /* 忽略 */
  }
  highlightSelection();
  if (state.mode === 'radial') applyRadialLayout();
  if (state.panelDragCleanup) state.panelDragCleanup();
  state.panelDragCleanup = initDrawerSpring(panel, { onClose: () => hidePanel(), handle: panel.querySelector('.gp-head') });
}

function hidePanel() {
  if (!state) return;
  state.selected = null;
  if (state.panelDragCleanup) {
    state.panelDragCleanup();
    state.panelDragCleanup = null;
  }
  const panel = state.panel;
  if (!panel) return;
  panel.classList.remove('is-open');
  setTimeout(() => {
    if (panel && !panel.classList.contains('is-open')) panel.hidden = true;
  }, 200);
  try {
    if (state.panelReturnFocus) state.panelReturnFocus.focus({ preventScroll: true });
  } catch (err) {
    /* 忽略 */
  }
  highlightSelection();
  if (state.mode === 'radial') {
    const hint = state.root.querySelector('#gRadialHint');
    if (hint) hint.hidden = false;
    clearRadialVisibility();
    applyLayoutPositions(state.layoutMode);
    updatePositions();
    updateLabels();
  }
}

/* ---------------- 视图变换 ---------------- */
function stageSize() {
  const stage = state.stage;
  return { w: stage.clientWidth, h: stage.clientHeight };
}

function applyTransform() {
  if (!state) return;
  const t = state.transform;
  state.canvas.style.transform = `translate3d(${t.x.toFixed(2)}px, ${t.y.toFixed(2)}px, 0) scale(${t.k.toFixed(4)})`;
  const z = state.root.querySelector('#graphZoom');
  if (z) z.textContent = `${t.k.toFixed(2)}×`;
  scheduleLabelUpdate();
}

function fitView() {
  const { w, h } = stageSize();
  const k = Math.min(w / W, h / H) * 0.98;
  state.transform = { k, x: (w - W * k) / 2, y: (h - H * k) / 2 };
  applyTransform();
}

function zoomAt(fx, fy, factor) {
  const t = state.transform;
  const k = Math.min(3.2, Math.max(0.25, t.k * factor));
  if (k === t.k) return;
  const ax = (fx - t.x) / t.k;
  const ay = (fy - t.y) / t.k;
  t.k = k;
  t.x = fx - ax * k;
  t.y = fy - ay * k;
  clampTransform();
  applyTransform();
}

function clampTransform() {
  const { w, h } = stageSize();
  const t = state.transform;
  const cw = W * t.k;
  const ch = H * t.k;
  t.x = cw <= w ? (w - cw) / 2 : Math.min(0, Math.max(w - cw, t.x));
  t.y = ch <= h ? (h - ch) / 2 : Math.min(0, Math.max(h - ch, t.y));
}

/* ---------------- 选中 / 筛选 / 标签 ---------------- */
function applySelectionStyles() {
  if (!state) return;
  const selected = state.selected;
  const related = new Set();
  if (selected) {
    for (const link of state.links) {
      if (link.sourceNode.id === selected.id) related.add(link.targetNode.id);
      if (link.targetNode.id === selected.id) related.add(link.sourceNode.id);
    }
  }
  state.svg.querySelectorAll('.g-node').forEach((el) => {
    const id = el.dataset.node;
    const isSel = !!selected && id === selected.id;
    el.classList.toggle('is-selected', isSel);
    el.classList.toggle('is-related', !!selected && related.has(id));
    el.classList.toggle('is-faded', !!selected && !isSel && !related.has(id));
  });
  state.svg.querySelectorAll('.g-link').forEach((el) => {
    const on = !!selected && (el.dataset.source === selected.id || el.dataset.target === selected.id);
    el.classList.toggle('is-on', on);
    el.classList.toggle('is-faded', !!selected && !on);
  });
}

function highlightSelection() {
  if (!state) return;
  applySelectionStyles();
  updateLabels();
}

const rectOverlap = (a, b, pad = 3) =>
  a.x - pad < b.x + b.w && a.x + a.w + pad > b.x && a.y - pad < b.y + b.h && a.y + a.h + pad > b.y;

function labelRect(node, text) {
  const w = String(text).length * LABEL_CHAR_W + 4;
  return { x: node.x - w / 2, y: node.y + (node.labelDy || 34) - 12, w, h: LABEL_H };
}

function updateLabels() {
  if (!state || !state.svg || !state.nodes.length) return;
  const allMode =
    state.showAllLabels ||
    state.transform.k >= ZOOM_ALL_LABELS ||
    (state.mode === 'radial' && !!state.selected);
  const filter = state.filterEra !== 'all' ? state.ctx.data.eraById.get(state.filterEra) : null;
  const selected = state.selected;
  const decide = new Map();

  if (allMode) {
    for (const n of state.nodes) decide.set(n.id, 'full');
  } else {
    const candidates = [];
    for (const n of state.nodes) {
      if (n === selected) {
        candidates.push({ n, score: 1e9 });
      } else if (filter) {
        // 有时代筛选时只显示该期命中节点的标签，避免筛选后仍被全局关键节点干扰
        if ((n.eras || []).includes(filter.id)) candidates.push({ n, score: 1e8 + (n.degree || 0) * 100 });
      } else if ((n.degree || 0) >= 2) {
        candidates.push({ n, score: (n.degree || 0) * 100 + (n.strengthSum || 0) });
      }
    }
    candidates.sort((a, b) => b.score - a.score || a.n.name.localeCompare(b.n.name, 'zh'));
    const placed = [];
    for (const { n } of candidates) {
      let rect = labelRect(n, n.name);
      if (!placed.some((p) => rectOverlap(rect, p))) {
        decide.set(n.id, 'full');
        placed.push(rect);
        continue;
      }
      // 重叠时优先缩为单字（仍按度数/选中顺序占位），再不行才隐藏
      const short = n.name.slice(0, 1);
      rect = labelRect(n, short);
      if (!placed.some((p) => rectOverlap(rect, p))) {
        decide.set(n.id, 'short');
        placed.push(rect);
      } else {
        decide.set(n.id, 'hidden');
      }
    }
  }

  state.svg.querySelectorAll('.g-node').forEach((el) => {
    const node = state.nodes.find((n) => n.id === el.dataset.node);
    if (!node) return;
    const mode = decide.get(node.id) || 'hidden';
    const text = el.querySelector('.g-node-name');
    if (text) text.textContent = mode === 'short' ? node.name.slice(0, 1) : node.name;
    el.classList.toggle('is-label-hidden', mode === 'hidden');
    el.classList.toggle('is-label-short', mode === 'short');
  });

  const toggle = state.root.querySelector('[data-label-toggle]');
  if (toggle) {
    toggle.classList.toggle('is-on', !!state.showAllLabels);
    toggle.setAttribute('aria-pressed', state.showAllLabels ? 'true' : 'false');
  }
}

function scheduleLabelUpdate() {
  if (!state) return;
  if (state.labelRaf) cancelAnimationFrame(state.labelRaf);
  state.labelRaf = requestAnimationFrame(() => {
    if (!state) return;
    state.labelRaf = 0;
    updateLabels();
  });
}

function applyEraFilter() {
  if (!state) return;
  const id = state.filterEra;
  const era = id === 'all' ? null : state.ctx.data.eraById.get(id);
  state.svg.querySelectorAll('.g-node').forEach((el) => {
    const node = state.nodes.find((n) => n.id === el.dataset.node);
    const match = !era || (node && (node.eras || []).includes(era.id));
    el.classList.toggle('is-dim', !!era && !match);
  });
  state.svg.querySelectorAll('.g-link').forEach((el) => {
    const s = state.nodes.find((n) => n.id === el.dataset.source);
    const t = state.nodes.find((n) => n.id === el.dataset.target);
    const match = !era || (s && (s.eras || []).includes(era.id)) || (t && (t.eras || []).includes(era.id));
    el.classList.toggle('is-dim', !!era && !match);
  });
  state.root.querySelectorAll('.g-chip').forEach((c) => {
    c.classList.toggle('is-active', c.dataset.era === id);
  });
  updateLabels();
}

/* ---------------- 紧凑 / 舒展布局过渡 ---------------- */
function setLayoutMode(mode) {
  if (!state || state.layoutMode === mode) return;
  state.layoutMode = mode;
  state.root.querySelectorAll('[data-layout]').forEach((btn) => {
    const on = btn.dataset.layout === mode;
    btn.classList.toggle('is-active', on);
    btn.setAttribute('aria-pressed', on ? 'true' : 'false');
  });
  animateLayout(mode);
}

function animateLayout(mode) {
  if (!state) return;
  if (state.layoutRaf) cancelAnimationFrame(state.layoutRaf);
  const start = new Map(state.nodes.map((n) => [n.id, { x: n.x, y: n.y, labelDy: n.labelDy }]));
  const targets = new Map(state.nodes.map((n) => [n.id, n[mode] || n.expanded]));
  for (const n of state.nodes) {
    n.homeX = (n[mode] || n.expanded).x;
    n.homeY = (n[mode] || n.expanded).y;
  }
  const finish = () => {
    for (const n of state.nodes) {
      const t = targets.get(n.id);
      n.x = t.x;
      n.y = t.y;
      n.labelDy = t.labelDy;
    }
    updatePositions();
    updateLabels();
  };
  if (reducedMotion()) {
    finish();
    return;
  }
  const t0 = performance.now();
  const tick = (now) => {
    if (!state) return;
    const p = Math.min(1, (now - t0) / LAYOUT_MS);
    const e = 1 - Math.pow(1 - p, 3);
    for (const n of state.nodes) {
      const s = start.get(n.id);
      const t = targets.get(n.id);
      n.x = s.x + (t.x - s.x) * e;
      n.y = s.y + (t.y - s.y) * e;
      n.labelDy = s.labelDy + (t.labelDy - s.labelDy) * e;
    }
    updatePositions();
    if (p < 1) state.layoutRaf = requestAnimationFrame(tick);
    else {
      state.layoutRaf = 0;
      updateLabels();
    }
  };
  state.layoutRaf = requestAnimationFrame(tick);
}

/* ---------------- 交互 ---------------- */
function bindGraph() {
  const stage = state.stage;
  const pointers = new Map();
  let drag = null;
  let moved = 0;
  let dragNode = null;

  const local = (e) => {
    const r = stage.getBoundingClientRect();
    return { x: e.clientX - r.left, y: e.clientY - r.top };
  };
  const toCanvas = (p) => ({ x: (p.x - state.transform.x) / state.transform.k, y: (p.y - state.transform.y) / state.transform.k });

  stage.addEventListener('pointerdown', (e) => {
    if (e.target.closest('.graph-controls')) return;
    if (state.layoutRaf) {
      cancelAnimationFrame(state.layoutRaf);
      state.layoutRaf = 0;
    }
    stage.setPointerCapture(e.pointerId);
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    moved = 0;
    const nodeEl = e.target.closest('[data-node]');
    if (nodeEl && pointers.size === 1) {
      const node = state.nodes.find((n) => n.id === nodeEl.dataset.node);
      if (node) dragNode = { node, start: local(e), x: node.x, y: node.y };
    } else if (!nodeEl && pointers.size === 1) {
      drag = { x: e.clientX, y: e.clientY, tx: state.transform.x, ty: state.transform.y };
    }
    if (pointers.size === 2) {
      drag = null;
      const pts = [...pointers.values()];
      state.pinch = {
        dist: Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y) || 1,
        mid: local(e),
        k: state.transform.k,
        x: state.transform.x,
        y: state.transform.y,
      };
      dragNode = null;
    }
    e.preventDefault();
  });

  stage.addEventListener('pointermove', (e) => {
    if (!pointers.has(e.pointerId)) return;
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });

    if (pointers.size >= 2 && state.pinch) {
      const pts = [...pointers.values()];
      const dist = Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y) || 1;
      const mid = local(e);
      const p = state.pinch;
      const k = Math.min(3.2, Math.max(0.25, p.k * (dist / p.dist)));
      const ax = (p.mid.x - p.x) / p.k;
      const ay = (p.mid.y - p.y) / p.k;
      state.transform = { k, x: mid.x - ax * k, y: mid.y - ay * k };
      clampTransform();
      applyTransform();
      moved = 99;
      return;
    }

    if (dragNode) {
      const p = local(e);
      const dx = (p.x - dragNode.start.x) / state.transform.k;
      const dy = (p.y - dragNode.start.y) / state.transform.k;
      moved = Math.max(moved, Math.abs(dx) + Math.abs(dy));
      dragNode.node.x = Math.max(20, Math.min(W - 20, dragNode.x + dx));
      dragNode.node.y = Math.max(30, Math.min(H - 20, dragNode.y + dy));
      updatePositions();
      return;
    }

    if (drag) {
      moved = Math.max(moved, Math.abs(e.clientX - drag.x) + Math.abs(e.clientY - drag.y));
      state.transform.x = drag.tx + (e.clientX - drag.x);
      state.transform.y = drag.ty + (e.clientY - drag.y);
      clampTransform();
      applyTransform();
    }
  });

  const endPointer = (e) => {
    pointers.delete(e.pointerId);
    if (pointers.size < 2) state.pinch = null;
    if (pointers.size === 0) {
      if (dragNode && moved < 4) {
        const node = dragNode.node;
        hidePanel();
        showPanel(node);
      }
      dragNode = null;
      drag = null;
      scheduleLabelUpdate();
    }
  };
  stage.addEventListener('pointerup', endPointer);
  stage.addEventListener('pointercancel', endPointer);

  stage.addEventListener(
    'wheel',
    (e) => {
      e.preventDefault();
      const p = local(e);
      zoomAt(p.x, p.y, Math.exp(-e.deltaY * 0.0016));
    },
    { passive: false }
  );

  stage.addEventListener('keydown', (e) => {
    if (e.key !== 'Enter' && e.key !== ' ') return;
    const nodeEl = e.target.closest('[data-node]');
    if (!nodeEl) return;
    e.preventDefault();
    const node = state.nodes.find((n) => n.id === nodeEl.dataset.node);
    if (node) showPanel(node);
  });

  state.root.querySelector('.graph-controls').addEventListener('click', (e) => {
    const btn = e.target.closest('[data-graph-action]');
    if (!btn) return;
    const { w, h } = stageSize();
    if (btn.dataset.graphAction === 'zoom-in') zoomAt(w / 2, h / 2, 1.4);
    if (btn.dataset.graphAction === 'zoom-out') zoomAt(w / 2, h / 2, 1 / 1.4);
    if (btn.dataset.graphAction === 'reset') {
      fitView();
      if (state.mode === 'radial' && state.selected) applyRadialLayout();
      else animateLayout(state.layoutMode);
    }
  });

  state.root.querySelector('.g-view-seg')?.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-g-mode]');
    if (btn) setViewMode(btn.dataset.gMode);
  });

  state.root.querySelector('.g-layout-seg').addEventListener('click', (e) => {
    const btn = e.target.closest('[data-layout]');
    if (btn) setLayoutMode(btn.dataset.layout);
  });

  state.root.querySelector('[data-label-toggle]').addEventListener('click', () => {
    if (!state) return;
    state.showAllLabels = !state.showAllLabels;
    updateLabels();
  });

  state.root.querySelector('.g-filter-row').addEventListener('click', (e) => {
    const chip = e.target.closest('[data-era]');
    if (!chip) return;
    state.filterEra = chip.dataset.era;
    applyEraFilter();
  });

  state.panel.addEventListener('click', (e) => {
    if (e.target.closest('[data-panel-close]')) hidePanel();
  });

  document.addEventListener('keydown', onKey);
  state.onKey = onKey;
  window.addEventListener('resize', onResize);
}

function onKey(e) {
  if (e.key === 'Escape' && state?.selected) hidePanel();
}

function onResize() {
  if (!state) return;
  clampTransform();
  applyTransform();
}

function updatePositions() {
  if (!state) return;
  for (const node of state.nodes) {
    const g = state.svg.querySelector(`.g-node[data-node="${CSS.escape(node.id)}"]`);
    if (!g) continue;
    const halo = g.querySelector('.g-node-halo');
    const dot = g.querySelector('.g-node-dot');
    const label = g.querySelector('.g-node-name');
    halo?.setAttribute('cx', node.x.toFixed(1));
    halo?.setAttribute('cy', node.y.toFixed(1));
    dot?.setAttribute('cx', node.x.toFixed(1));
    dot?.setAttribute('cy', node.y.toFixed(1));
    const ring = g.querySelector('.g-node-selring');
    ring?.setAttribute('cx', node.x.toFixed(1));
    ring?.setAttribute('cy', node.y.toFixed(1));
    const hit = g.querySelector('.g-node-hit');
    hit?.setAttribute('cx', node.x.toFixed(1));
    hit?.setAttribute('cy', node.y.toFixed(1));
    label?.setAttribute('x', node.x.toFixed(1));
    label?.setAttribute('y', (node.y + (node.labelDy || 34)).toFixed(1));
  }
  for (const link of state.links) {
    const el = state.svg.querySelector(`.g-link[data-link="${CSS.escape(link.id)}"]`);
    if (!el) continue;
    el.setAttribute('x1', link.sourceNode.x.toFixed(1));
    el.setAttribute('y1', link.sourceNode.y.toFixed(1));
    el.setAttribute('x2', link.targetNode.x.toFixed(1));
    el.setAttribute('y2', link.targetNode.y.toFixed(1));
  }
}

/* ---------------- 拖入数据 ---------------- */
function renderGraphBody(root, ctx, generals) {
  if (!state || state.root !== root) return;
  const featured = generals.filter((g) => g && g.id && g.featured !== false);
  const featuredIds = new Set(featured.map((g) => g.id));
  state.nodes = buildNodes(ctx, featured, featuredIds);
  state.eraGroups = layoutNodes(state.nodes, ctx.data.eras);
  state.layoutMode = 'expanded';
  applyLayoutPositions('expanded');

  const nodeMap = new Map(state.nodes.map((n) => [n.id, n]));
  for (const n of state.nodes) {
    n.degree = 0;
    n.strengthSum = 0;
  }
  state.links = ctx.data.relations
    .map((r) => {
      const s = nodeMap.get(r.source);
      const t = nodeMap.get(r.target);
      if (!s || !t || s.id === t.id) return null;
      s.degree += 1;
      t.degree += 1;
      s.strengthSum += r.strength || 1;
      t.strengthSum += r.strength || 1;
      return { ...r, sourceNode: s, targetNode: t };
    })
    .filter(Boolean);

  const canvas = root.querySelector('#graphCanvas');
  canvas.innerHTML = graphSVG(ctx, state.nodes, state.links, state.eraGroups);
  state.svg = canvas.querySelector('svg');
  fitView();
  bindGraph();
  applyEraFilter();
  updateLabels();
  if (state.mode === 'radial') setViewMode('radial');
}

/* ---------------- 国家关系图层 ---------------- */
let stateGraphPromise = null;
function loadStateGraph() {
  if (!stateGraphPromise) stateGraphPromise = import('./stategraph.js');
  return stateGraphPromise;
}

function statePageHTML(ctx) {
  const extraCount = (ctx.data?.stateExtraNodes || []).length;
  return `<div class="graph-page g-state-page">
    <header class="page-head">
      <button class="icon-btn" type="button" data-action="back" aria-label="返回上一页">${icon('back')}</button>
      <div class="head-title">关系图谱<span class="head-sub">国家关系 · 20 势力${extraCount ? ` + ${extraCount} 附加政权` : ' + 附加政权'}</span></div>
      <div class="head-actions">
        <a class="icon-btn icon-btn--text" href="#/legend#graph" aria-label="打开国家关系图例">图例</a>
        <button class="icon-btn" type="button" data-action="search" aria-label="搜索战役">${icon('search')}</button>
      </div>
    </header>
    <div class="graph-body">
      <div class="graph-switch-row">
        <div class="g-layer-seg" role="group" aria-label="图谱图层">
          <a class="g-layer-btn" href="#/graph">名将关系</a>
          <a class="g-layer-btn is-active" href="#/graph?layer=state" aria-current="page">国家关系</a>
        </div>
      </div>
      <div class="g-state-host" id="stateGraphHost"><div class="graph-loading">正在整理国家关系…</div></div>
    </div>
  </div>`;
}

function renderStateLayer(root, ctx) {
  root.innerHTML = statePageHTML(ctx);
  state = {
    root,
    ctx,
    layer: 'state',
    module: null,
    stage: null,
    panel: null,
  };
  root.querySelector('[data-action="back"]')?.addEventListener('click', () => navigateBack('/generals'));
  root.querySelector('[data-action="search"]')?.addEventListener('click', () => navigate('/search'));
  const host = root.querySelector('#stateGraphHost');
  loadStateGraph()
    .then((mod) => {
      if (!state || state.layer !== 'state' || state.root !== root) return;
      state.module = mod;
      mod.renderStateGraph(host, ctx, { layer: 'state' });
    })
    .catch((err) => {
      console.error('[山河战纪] 国家关系组件加载失败', err);
      if (host) {
        host.innerHTML = `<div class="page-body">${emptyStateHTML({
          title: '国家关系数据准备中',
          desc: 'stategraph 组件或 state-relations.json 暂不可用；名将关系层仍可正常使用。',
          actions: '<a class="btn btn--gold" href="#/graph">返回名将关系</a>',
        })}</div>`;
      }
    });
}

/* ---------------- 入口 ---------------- */
export function renderGraph(root, ctx, route) {
  disposeGraph();
  const layer = route?.query?.layer === 'state' ? 'state' : 'generals';
  if (layer === 'state') {
    renderStateLayer(root, ctx);
    return;
  }
  const relations = ctx.data?.relations || [];
  if (!relations.length) {
    root.innerHTML = `<div class="graph-page">
      <header class="page-head">
        <button class="icon-btn" type="button" data-action="back" aria-label="返回名将页">${icon('back')}</button>
        <div class="head-title">关系图谱<span class="head-sub">2.0 数据准备中</span></div>
      </header>
      <div class="page-body">${emptyStateHTML({
        title: '关系图谱尚未载入',
        desc: 'relations.json 暂不可用或内容为空。名将小传与全部名将仍可正常浏览。',
        actions:
          '<button class="btn btn--gold" type="button" data-action="retry">重新载入</button><button class="btn" type="button" data-action="generals">去名将页</button>',
      })}</div>
    </div>`;
    root.querySelector('[data-action="retry"]')?.addEventListener('click', () => window.location.reload());
    root.querySelector('[data-action="generals"]')?.addEventListener('click', () => navigate('/generals'));
    root.querySelector('[data-action="back"]')?.addEventListener('click', () => navigateBack('/generals'));
    return;
  }

  state = {
    root,
    ctx,
    layer: 'generals',
    mode: route?.query?.layer === 'radial' ? 'radial' : 'network',
    nodes: [],
    links: [],
    svg: null,
    filterEra: 'all',
    selected: null,
    transform: { x: 0, y: 0, k: 1 },
    pinch: null,
    panel: null,
    stage: null,
    canvas: null,
    onKey: null,
    layoutMode: 'expanded',
    showAllLabels: false,
    labelRaf: 0,
    layoutRaf: 0,
  };
  root.innerHTML = graphPageHTML(ctx);
  state.stage = root.querySelector('#graphStage');
  state.canvas = root.querySelector('#graphCanvas');
  // 小传面板挂 body，避免 .view > * 动画 transform 影响 fixed 定位
  const panel = document.createElement('div');
  panel.id = 'graphPanel';
  panel.className = 'graph-panel';
  panel.hidden = true;
  document.body.appendChild(panel);
  state.panel = panel;
  state.root.querySelector('[data-action="back"]')?.addEventListener('click', () => navigateBack('/generals'));
  state.root.querySelector('[data-action="search"]')?.addEventListener('click', () => navigate('/search'));
  fitView();

  loadGenerals().then((generals) => renderGraphBody(root, ctx, generals));
}

export function disposeGraph() {
  if (state?.layer === 'state') {
    try {
      state.module?.disposeStateGraph?.();
    } catch (err) {
      /* 忽略 */
    }
    state = null;
    document.getElementById('graphPanel')?.remove();
    return;
  }
  if (state) {
    if (state.labelRaf) cancelAnimationFrame(state.labelRaf);
    if (state.layoutRaf) cancelAnimationFrame(state.layoutRaf);
    document.removeEventListener('keydown', state.onKey);
    window.removeEventListener('resize', onResize);
    if (state.panelDragCleanup) state.panelDragCleanup();
    state.panel?.remove();
  }
  document.getElementById('graphPanel')?.remove();
  state = null;
}
