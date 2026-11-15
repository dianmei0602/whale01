/* ============================================================
   replay.js — 2.0 战役动画推演播放器
   接口（固定，勿改名）：
     export function renderReplay(root, ctx, battleId)
     export function disposeReplay()
   数据：优先 ctx.data.replays（数组 / Map / 以 battleId 为键的对象）
         缺失时 fetch('data/replays.json') 兜底；仍无 → 空态。
   约定：docs/05-2.0-data-spec.md §3；SVG viewBox 0 0 100 100 示意画布。
   无第三方库、无外链；减弱动效读 html/body[data-motion]；页面隐藏自动暂停。
   ============================================================ */

import { esc, icon, emptyStateHTML } from './ui.js';
import { navigate } from './router.js';

const SVG_NS = 'http://www.w3.org/2000/svg';
const CSS_HREF = 'css/replay.css';
const NUM = ['壹', '贰', '叁', '肆', '伍', '陆', '柒', '捌', '玖', '拾'];
const SPEEDS = [0.5, 1, 1.5, 2];

const SIDES = new Set(['A', 'B', 'N']);
const KINDS = new Set(['infantry', 'cavalry', 'navy', 'camp', 'city', 'fort']);
const ARROW_KINDS = new Set(['advance', 'attack', 'retreat', 'fire', 'feint']);
const TERRAINS = new Set(['plain', 'river', 'mountain', 'city', 'sea']);

const TERRAIN_NAME = { plain: '平原', river: '江河', mountain: '山地', city: '城邑', sea: '海域' };
const DEFAULT_LABEL = { A: '甲军', B: '乙军', N: '中立军' };

const SVG_PLAY =
  '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8.4 5.2 18.4 12 8.4 18.8Z" fill="currentColor" stroke="none"/></svg>';
const SVG_PAUSE =
  '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 5.5v13M15 5.5v13" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/></svg>';

/* ---------------- 样式：模块加载即注入（index.html 未加 link 也可用） ---------------- */
let stylesPromise = null;
function ensureStyles() {
  try {
    const links = document.querySelectorAll('link[rel="stylesheet"]');
    for (const link of links) {
      const href = link.getAttribute('href') || '';
      if (href.includes('replay.css')) return Promise.resolve();
    }
    if (stylesPromise) return stylesPromise;
    stylesPromise = new Promise((resolve) => {
      const el = document.createElement('link');
      el.rel = 'stylesheet';
      el.href = CSS_HREF;
      el.dataset.replayCss = '1';
      el.addEventListener('load', () => resolve());
      el.addEventListener('error', () => resolve());
      document.head.appendChild(el);
    });
    return stylesPromise;
  } catch (err) {
    return Promise.resolve();
  }
}
const stylesReady = ensureStyles();

/* ---------------- 小工具 ---------------- */
const clamp = (v, min, max) => (v < min ? min : v > max ? max : v);
const f = (n) => (Math.round(Number(n) * 100) / 100).toString();
const str = (v) => (v == null ? '' : String(v));
const clip = (s, n) => (s.length > n ? s.slice(0, n - 1) + '…' : s);

function hashSeed(input) {
  let h = 2166136261;
  const s = String(input);
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function rng(seed) {
  let a = seed >>> 0;
  return function next() {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const easeOutCubic = (t) => 1 - Math.pow(1 - t, 3);

function normPos(value) {
  if (value == null) return null;
  let x;
  let y;
  if (Array.isArray(value)) {
    x = Number(value[0]);
    y = Number(value[1]);
  } else if (typeof value === 'object') {
    x = Number(value.x != null ? value.x : value[0]);
    y = Number(value.y != null ? value.y : value[1]);
  } else {
    return null;
  }
  if (!Number.isFinite(x) || !Number.isFinite(y)) return null;
  return [clamp(x, 0, 100), clamp(y, 0, 100)];
}

function normFocus(value) {
  if (!Array.isArray(value) || value.length < 2) return null;
  const x = Number(value[0]);
  const y = Number(value[1]);
  let r = Number(value[2]);
  if (!Number.isFinite(x) || !Number.isFinite(y)) return null;
  if (!Number.isFinite(r) || r <= 0) r = 20;
  return [clamp(x, 0, 100), clamp(y, 0, 100), clamp(r, 6, 45)];
}

function readReduce() {
  try {
    const html = document.documentElement;
    const body = document.body;
    const attr = (html && html.dataset ? html.dataset.motion : '') || (body && body.dataset ? body.dataset.motion : '');
    if (attr === 'reduce') return true;
    if (attr === 'full') return false;
    return !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
  } catch (err) {
    return false;
  }
}

/* ============================================================
   数据层：规范化 / 读取
   ============================================================ */

function normalizeUnit(raw, idx, seen) {
  if (!raw || typeof raw !== 'object') return null;
  const pos = normPos(raw.pos) || normPos(raw.position) || normPos(raw.at) || [50, 50];
  let id = str(raw.id) || str(raw.uid) || str(raw.key);
  if (!id) id = `${str(raw.side) || 'n'}-${idx + 1}`;
  if (seen) {
    if (seen.has(id)) {
      let k = 2;
      while (seen.has(`${id}-${k}`)) k += 1;
      id = `${id}-${k}`;
    }
    seen.add(id);
  }
  const sideRaw = str(raw.side).toUpperCase();
  const side = SIDES.has(sideRaw) ? sideRaw : 'N';
  const kind = KINDS.has(str(raw.kind)) ? str(raw.kind) : 'infantry';
  const label = str(raw.label) || str(raw.name) || DEFAULT_LABEL[side];
  return { id, label, side, kind, pos };
}

function normalizeArrow(raw, unitMap) {
  if (!raw || typeof raw !== 'object') return null;
  let from = normPos(raw.from) || normPos(raw.start);
  let to = normPos(raw.to) || normPos(raw.end);
  if (!from && typeof raw.from === 'string' && unitMap.has(raw.from)) from = unitMap.get(raw.from).pos;
  if (!to && typeof raw.to === 'string' && unitMap.has(raw.to)) to = unitMap.get(raw.to).pos;
  if (!from || !to) return null;
  const kind = ARROW_KINDS.has(str(raw.kind)) ? str(raw.kind) : 'advance';
  return { from, to, kind, label: str(raw.label) };
}

function normalizeStage(raw, idx) {
  if (!raw || typeof raw !== 'object') return null;
  const seen = new Set();
  const units = (Array.isArray(raw.units) ? raw.units : []).map((u, i) => normalizeUnit(u, i, seen)).filter(Boolean);
  const unitMap = new Map(units.map((u) => [u.id, u]));
  const arrows = (Array.isArray(raw.arrows) ? raw.arrows : []).map((a) => normalizeArrow(a, unitMap)).filter(Boolean);
  const durationRaw = Number(raw.duration);
  const duration = Number.isFinite(durationRaw) && durationRaw > 0 ? clamp(durationRaw, 2, 30) : 5;
  return {
    title: str(raw.title) || `第 ${idx + 1} 阶段`,
    narration: str(raw.narration) || str(raw.text) || str(raw.desc) || '',
    duration,
    units,
    arrows,
    focus: normFocus(raw.focus),
  };
}

function normalizeReplay(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const battleId = str(raw.battleId || raw.battleID || (raw.battle && raw.battle.id) || raw.id).trim();
  const stages = (Array.isArray(raw.stages) ? raw.stages : []).map(normalizeStage).filter(Boolean);
  if (!battleId || !stages.length) return null;
  const terrainRaw = str(raw.terrain);
  return {
    battleId,
    terrain: TERRAINS.has(terrainRaw) ? terrainRaw : 'plain',
    title: str(raw.title) || battleId,
    subtitle: str(raw.subtitle) || str(raw.sub) || '',
    summary: str(raw.summary) || '',
    stages,
  };
}

function normalizeList(raw) {
  if (!raw) return null;
  let items = null;
  if (Array.isArray(raw)) {
    items = raw;
  } else if (typeof Map !== 'undefined' && raw instanceof Map) {
    items = [...raw.values()];
  } else if (typeof raw === 'object') {
    if (Array.isArray(raw.replays)) items = raw.replays;
    else if (Array.isArray(raw.list)) items = raw.list;
    else if (Array.isArray(raw.items)) items = raw.items;
    else items = Object.values(raw);
  }
  if (!items) return null;
  const list = items.map(normalizeReplay).filter(Boolean);
  return list.length ? list : null;
}

function pickReplaysFromCtx(ctx) {
  const data = ctx && ctx.data;
  if (!data || typeof data !== 'object') return null;
  const candidates = [data.replays, data.replayList, data.replaysById, data.replayById];
  for (const candidate of candidates) {
    const list = normalizeList(candidate);
    if (list) return list;
  }
  return null;
}

async function loadReplays(ctx) {
  const fromCtx = pickReplaysFromCtx(ctx);
  if (fromCtx) return fromCtx;
  try {
    const res = await fetch('data/replays.json', { cache: 'no-cache' });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const text = (await res.text()).replace(/^\uFEFF/, '');
    const list = normalizeList(JSON.parse(text));
    if (list) return list;
    console.info('[山河战纪] replays.json 为空或格式不符');
  } catch (err) {
    console.info('[山河战纪] replays.json 暂不可用：', err && err.message ? err.message : err);
  }
  return [];
}

function battleMeta(ctx, id) {
  try {
    const byId = ctx && ctx.data && ctx.data.byId;
    const battle = byId && typeof byId.get === 'function' ? byId.get(id) : null;
    if (battle) {
      return {
        name: str(battle.name),
        yearText: str(battle.yearText),
        era: battle.era ? str(battle.era.name) : '',
      };
    }
  } catch (err) {
    /* ignore */
  }
  return { name: '', yearText: '', era: '' };
}

function stripReplaySuffix(title) {
  return str(title)
    .replace(/\s*[·・|｜]\s*推演.*$/u, '')
    .replace(/\s*推演$/u, '')
    .trim();
}

/* ============================================================
   SVG：defs / 地形
   ============================================================ */

function svgDefs(uid) {
  const marker = (name, color) =>
    `<marker id="${uid}-${name}" viewBox="0 0 6 6" refX="5.2" refY="3" markerUnits="userSpaceOnUse" markerWidth="3.2" markerHeight="3.2" orient="auto-start-reverse"><path d="M0 0 L6 3 L0 6 L1.5 3 Z" fill="${color}"/></marker>`;
  return `<defs>
    <linearGradient id="${uid}-sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#1D1811"/>
      <stop offset="0.52" stop-color="#15120E"/>
      <stop offset="1" stop-color="#0B0908"/>
    </linearGradient>
    <radialGradient id="${uid}-glow" cx="0.5" cy="0.24" r="0.82">
      <stop offset="0" stop-color="#C9A227" stop-opacity="0.17"/>
      <stop offset="0.62" stop-color="#C9A227" stop-opacity="0.04"/>
      <stop offset="1" stop-color="#C9A227" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="${uid}-vign" cx="0.5" cy="0.5" r="0.74">
      <stop offset="0.56" stop-color="#000000" stop-opacity="0"/>
      <stop offset="1" stop-color="#000000" stop-opacity="0.44"/>
    </radialGradient>
    <radialGradient id="${uid}-disc" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#E0C060" stop-opacity="0.5"/>
      <stop offset="0.55" stop-color="#E0C060" stop-opacity="0.16"/>
      <stop offset="1" stop-color="#E0C060" stop-opacity="0"/>
    </radialGradient>
    <pattern id="${uid}-grid" width="10" height="10" patternUnits="userSpaceOnUse">
      <path d="M10 0H0V10" fill="none" stroke="#C9A227" stroke-opacity="0.05" stroke-width="0.22"/>
    </pattern>
    <filter id="${uid}-glowf" x="-40%" y="-40%" width="180%" height="180%">
      <feGaussianBlur stdDeviation="0.9"/>
    </filter>
    ${marker('gold', '#E0C060')}
    ${marker('cinnabar', '#D2584A')}
    ${marker('mute', '#C7BCA6')}
    ${marker('fire', '#E08A46')}
    ${marker('bronze', '#A9B79E')}
  </defs>`;
}

/** 山脊线 + 闭合填充（程序化，墨色剪影） */
function ridge(rnd, baseY, amp, steps = 11) {
  const pts = [];
  for (let i = 0; i <= steps; i += 1) {
    const x = -2 + (104 * i) / steps;
    const envelope = 0.45 + 0.55 * Math.sin((Math.PI * i) / steps);
    const y = baseY - (0.3 + rnd() * 0.7) * amp * envelope;
    pts.push([x, y]);
  }
  let line = `M${f(pts[0][0])} ${f(pts[0][1])}`;
  for (let i = 1; i < pts.length; i += 1) line += ` L${f(pts[i][0])} ${f(pts[i][1])}`;
  return { line, fill: `${line} L102 102 L-2 102 Z` };
}

/** 一条波浪线（用于水纹 / 雾带） */
function waveLine(baseY, amp, cycles, phase, steps = 44) {
  const pts = [];
  for (let i = 0; i <= steps; i += 1) {
    const x = (100 * i) / steps;
    const y = baseY + Math.sin(phase + (i / steps) * Math.PI * 2 * cycles) * amp;
    pts.push([x, y]);
  }
  return `M${f(pts[0][0])} ${f(pts[0][1])}` + pts.slice(1).map(([x, y]) => ` L${f(x)} ${f(y)}`).join('');
}

function wavePoints(baseY, amp, cycles, phase, steps = 44) {
  const pts = [];
  for (let i = 0; i <= steps; i += 1) {
    const x = (100 * i) / steps;
    const y = baseY + Math.sin(phase + (i / steps) * Math.PI * 2 * cycles) * amp;
    pts.push([x, y]);
  }
  return pts;
}

function bandPath(top, bottom) {
  let topLine = `M${f(top[0][0])} ${f(top[0][1])}`;
  for (let i = 1; i < top.length; i += 1) topLine += ` L${f(top[i][0])} ${f(top[i][1])}`;
  let botLine = `M${f(bottom[0][0])} ${f(bottom[0][1])}`;
  for (let i = 1; i < bottom.length; i += 1) botLine += ` L${f(bottom[i][0])} ${f(bottom[i][1])}`;
  let fill = topLine;
  for (let i = bottom.length - 1; i >= 0; i -= 1) fill += ` L${f(bottom[i][0])} ${f(bottom[i][1])}`;
  fill += ' Z';
  return { fill, topLine, botLine };
}

function grass(rnd, x0, x1, y0, y1, count, opacity) {
  let s = '';
  for (let i = 0; i < count; i += 1) {
    const x = x0 + rnd() * (x1 - x0);
    const y = y0 + rnd() * (y1 - y0);
    const dx = (rnd() - 0.5) * 2;
    const dy = -0.9 - rnd() * 1.5;
    s += `<path d="M${f(x)} ${f(y)} l${f(dx)} ${f(dy)}" fill="none" stroke="#E9DFC8" stroke-opacity="${opacity}" stroke-width="0.18" stroke-linecap="round"/>`;
  }
  return s;
}

function plainTerrain(rnd) {
  const far = ridge(rnd, 58, 13, 11);
  const near = ridge(rnd, 67, 9, 9);
  let s = `<path d="${far.fill}" fill="#E9DFC8" fill-opacity="0.04"/>
    <path d="${far.line}" fill="none" stroke="#C9A227" stroke-opacity="0.15" stroke-width="0.28"/>
    <path d="${near.fill}" fill="#0C0A08" fill-opacity="0.5"/>
    <path d="${near.line}" fill="none" stroke="#C9A227" stroke-opacity="0.1" stroke-width="0.24"/>
    <path d="M0 74H100" stroke="#C9A227" stroke-opacity="0.14" stroke-width="0.3"/>`;
  s += grass(rnd, 0, 100, 76, 98, 26, 0.1);
  return s;
}

function riverTerrain(rnd) {
  const back = ridge(rnd, 43, 9, 9);
  const band = bandPath(wavePoints(52, 2.6, 1.4, 0.7), wavePoints(78, 2.6, 1.15, 2.4));
  let s = `<path d="${back.fill}" fill="#E9DFC8" fill-opacity="0.035"/>
    <path d="${band.fill}" fill="#14211F" fill-opacity="0.9"/>
    <path d="${band.topLine}" fill="none" stroke="#C9A227" stroke-opacity="0.3" stroke-width="0.32"/>
    <path d="${band.botLine}" fill="none" stroke="#C9A227" stroke-opacity="0.26" stroke-width="0.32"/>`;
  for (let i = 0; i < 6; i += 1) {
    const y = 57 + i * 4;
    s += `<path d="${waveLine(y, 0.7 + rnd() * 0.6, 2.4, rnd() * 6)}" fill="none" stroke="#C9A227" stroke-opacity="${(
      0.09 + rnd() * 0.11
    ).toFixed(2)}" stroke-width="0.2" stroke-dasharray="2 2.6"/>`;
  }
  s += grass(rnd, 0, 100, 82, 98, 14, 0.07);
  s += grass(rnd, 0, 100, 40, 48, 10, 0.05);
  return s;
}

function mountainTerrain(rnd) {
  const layers = [
    { y: 51, a: 16, fill: 0.03, line: 0.1, steps: 9 },
    { y: 60, a: 14, fill: 0.05, line: 0.13, steps: 10 },
    { y: 70, a: 12, fill: 0.08, line: 0.17, steps: 11 },
    { y: 82, a: 9, fill: 0.11, line: 0.2, steps: 12 },
  ];
  let s = '';
  layers.forEach((layer, i) => {
    const r = ridge(rnd, layer.y, layer.a, layer.steps + i);
    s += `<path d="${r.fill}" fill="#E9DFC8" fill-opacity="${layer.fill}"/>`;
    s += `<path d="${r.line}" fill="none" stroke="#C9A227" stroke-opacity="${layer.line}" stroke-width="0.26"/>`;
  });
  // 谷间雾带
  s += `<path d="${waveLine(66, 1.5, 1.8, 1.1)}" fill="none" stroke="#E9DFC8" stroke-opacity="0.05" stroke-width="1.6"/>`;
  s += `<path d="${waveLine(74, 1.2, 2.2, 3.4)}" fill="none" stroke="#E9DFC8" stroke-opacity="0.04" stroke-width="1.2"/>`;
  return s;
}

function cityTerrain(rnd) {
  const back = ridge(rnd, 55, 9, 9);
  const y0 = 69;
  const y1 = 82;
  const x0 = 15;
  const x1 = 85;
  const merlonW = 3.2;
  const merlonGap = 2.2;
  const merlonH = 2.6;

  let wall = `M${f(x0)} ${f(y1)} L${f(x0)} ${f(y0)}`;
  let x = x0;
  while (x < x1 - merlonW - 0.5) {
    wall += ` L${f(x)} ${f(y0 - merlonH)} L${f(x + merlonW)} ${f(y0 - merlonH)} L${f(x + merlonW)} ${f(y0)}`;
    x += merlonW;
    if (x >= x1 - merlonGap - 1) break;
    wall += ` L${f(x)} ${f(y0)}`;
    x += merlonGap;
    wall += ` L${f(x)} ${f(y0)}`;
  }
  wall += ` L${f(x1)} ${f(y0)} L${f(x1)} ${f(y1)} Z`;

  let s = `<path d="${back.fill}" fill="#E9DFC8" fill-opacity="0.04"/>
    <path d="${back.line}" fill="none" stroke="#C9A227" stroke-opacity="0.12" stroke-width="0.24"/>
    <path d="${wall}" fill="#17130F" stroke="#C9A227" stroke-opacity="0.34" stroke-width="0.3" stroke-linejoin="round"/>
    <path d="M44 ${f(y1)}V76.6a6 6 0 0 1 12 0V${f(y1)}Z" fill="#090807" stroke="#C9A227" stroke-opacity="0.3" stroke-width="0.3"/>`;

  const tower = (tx) =>
    `<path d="M${f(tx)} ${f(y0)}V65" stroke="#C9A227" stroke-opacity="0.35" stroke-width="0.3"/>
     <path d="M${f(tx - 2.4)} 65H${f(tx + 2.4)}V${f(y0)}H${f(tx - 2.4)}Z" fill="#1B1712" stroke="#C9A227" stroke-opacity="0.3" stroke-width="0.28"/>
     <path d="M${f(tx - 3.3)} 65 ${f(tx)} 60.4 ${f(tx + 3.3)} 65Z" fill="#8C6F1C" fill-opacity="0.3" stroke="#E0C060" stroke-opacity="0.28" stroke-width="0.24"/>`;
  s += tower(17) + tower(83);

  [[30, y0], [38, 68], [58, 68.5], [66, y0]].forEach(([hx, hy], i) => {
    s += `<path d="M${f(hx - 2.6)} ${f(hy)} ${f(hx)} ${f(hy - 3.2)} ${f(hx + 2.6)} ${f(hy)}Z" fill="#E9DFC8" fill-opacity="${(
      0.05 + i * 0.008
    ).toFixed(3)}" stroke="#C9A227" stroke-opacity="0.16" stroke-width="0.2"/>`;
  });
  s += `<path d="M0 ${f(y1)}H100" stroke="#C9A227" stroke-opacity="0.14" stroke-width="0.3"/>`;
  s += grass(rnd, 0, 100, 84, 98, 12, 0.06);
  return s;
}

function seaTerrain(rnd, uid) {
  const island = ridge(rnd, 42, 7, 7);
  let s = `<path d="${island.fill}" fill="#E9DFC8" fill-opacity="0.05"/>
    <path d="${island.line}" fill="none" stroke="#C9A227" stroke-opacity="0.12" stroke-width="0.24"/>
    <circle cx="76" cy="21" r="9" fill="url(#${uid}-disc)"/>
    <circle cx="76" cy="21" r="3.1" fill="#E0C060" fill-opacity="0.18"/>
    <path d="M0 44H100" stroke="#C9A227" stroke-opacity="0.2" stroke-width="0.3"/>`;
  for (let i = 0; i < 9; i += 1) {
    const y = 47 + i * 5.6;
    const amp = 0.6 + i * 0.16;
    s += `<path d="${waveLine(y, amp, 2.2 + (i % 3) * 0.4, rnd() * 6)}" fill="none" stroke="#9FB39B" stroke-opacity="${(
      0.06 + 0.05 * (i % 4)
    ).toFixed(2)}" stroke-width="${(0.2 + i * 0.02).toFixed(2)}"/>`;
  }
  for (let i = 0; i < 15; i += 1) {
    const x = rnd() * 100;
    const y = 48 + rnd() * 48;
    s += `<path d="M${f(x)} ${f(y)}h${f(1.2 + rnd() * 2.2)}" fill="none" stroke="#E0C060" stroke-opacity="0.1" stroke-width="0.18" stroke-linecap="round"/>`;
  }
  return s;
}

function terrainLayer(terrain, seed, uid) {
  const rnd = rng(hashSeed(seed + ':terrain'));
  const parts = [`<rect width="100" height="100" fill="url(#${uid}-sky)"/>`, `<rect width="100" height="100" fill="url(#${uid}-glow)"/>`];
  if (terrain === 'river') parts.push(riverTerrain(rnd));
  else if (terrain === 'mountain') parts.push(mountainTerrain(rnd));
  else if (terrain === 'city') parts.push(cityTerrain(rnd));
  else if (terrain === 'sea') parts.push(seaTerrain(rnd, uid));
  else parts.push(plainTerrain(rnd));
  parts.push(`<rect width="100" height="100" fill="url(#${uid}-grid)"/>`);
  parts.push(`<rect width="100" height="100" fill="url(#${uid}-vign)"/>`);
  return parts.join('');
}

/* ============================================================
   SVG：单位 / 箭头
   ============================================================ */

const GLYPHS = {
  infantry:
    '<path class="rp-gbody" d="M0 -3.1 2.7 -1.7V1.1L0 3.5-2.7 1.1V-1.7Z"/><path class="rp-gline" d="M0 -4.6V-2.6"/>',
  cavalry:
    '<path class="rp-gline" d="M-3.1 2.3H2.2M-2.5 2.3V-1.1M1.5 2.3V-.7"/><path class="rp-gbody" d="M-3.2 -.6H1.4L3.5 -2.5 2.7 -.1 1.5 .5H-3.2Z"/>',
  navy:
    '<path class="rp-gbody" d="M-4.1 1.1Q0 4.3 4.1 1.1L3.1 .1H-3.1Z"/><path class="rp-gline" d="M0 .1V-4M0 -3.8 3.2 -1.4 0 -.6"/>',
  camp: '<path class="rp-gbody" d="M-3.9 3 0 -3.9 3.9 3Z"/><path class="rp-gline" d="M0 -3.9V3M-3.9 3H3.9"/>',
  city:
    '<path class="rp-gbody" d="M-3.9 3V-1H-2.7V-2.3H-1.3V-1H1.3V-2.3H2.7V-1H3.9V3Z"/><path class="rp-gline" d="M-1.1 3V1a1.1 1.1 0 0 1 2.2 0V3"/>',
  fort: '<path class="rp-gbody" d="M0 -3.9 3.5 -2V2L0 3.9-3.5 2V-2Z"/><circle class="rp-gline" cx="0" cy="0" r="1.15"/>',
};

function unitMarkup(unit, index) {
  const sideClass = unit.side.toLowerCase();
  const delay = index * 0.35;
  return `<g class="rp-unit rp-unit--${sideClass} is-enter" data-uid="${esc(unit.id)}" transform="translate(${f(
    unit.pos[0]
  )} ${f(unit.pos[1])})" style="--rp-delay:${delay}s">
    <circle class="rp-halo" r="3.9"/>
    <circle class="rp-disc" r="2.9"/>
    <g class="rp-glyph" transform="scale(0.7)">${GLYPHS[unit.kind] || GLYPHS.infantry}</g>
    <path class="rp-flag" d="M2.2 -2 4.4 -2.8V-.9L2.2 -.1Z"/>
    <text class="rp-label"></text>
  </g>`;
}

const ARROW_STYLE = {
  advance: { color: '#E0C060', width: 0.62, dash: '', flow: false, head: 'gold', bow: 0.16 },
  attack: { color: '#D2584A', width: 0.8, dash: '2 1.4', flow: true, head: 'cinnabar', bow: 0.14 },
  retreat: { color: '#C7BCA6', width: 0.5, dash: '2.6 1.5', flow: false, head: 'mute', bow: 0.2 },
  fire: { color: '#E08A46', width: 0.72, dash: '1.5 1.1', flow: true, head: 'fire', bow: 0.12, glow: true },
  feint: { color: '#A9B79E', width: 0.46, dash: '0.45 1.5', flow: false, head: 'bronze', bow: 0.3 },
};

/** 箭头几何：二次贝塞尔 + 标注点（避开单位与已放的箭头标注，减少压字） */
function arrowGeometry(arrow, units, placedRects) {
  const style = ARROW_STYLE[arrow.kind] || ARROW_STYLE.advance;
  const [x1, y1] = arrow.from;
  const [x2, y2] = arrow.to;
  const dx = x2 - x1;
  const dy = y2 - y1;
  const len = Math.hypot(dx, dy) || 1;
  const nx = -dy / len;
  const ny = dx / len;
  const cx = (x1 + x2) / 2 + nx * len * style.bow;
  const cy = (y1 + y2) / 2 + ny * len * style.bow;
  let text = arrow.label ? clip(arrow.label, 12) : '';
  let rect = null;
  let lx = cx;
  let ly = cy;
  if (text) {
    const width = estimateTextWidth(text, 2.35);
    const unitPts = Array.isArray(units) ? units.map((unit) => unit.pos) : [];
    const unitBoxes = unitPts.map(([ux, uy]) => ({ left: ux - 3.2, right: ux + 3.2, top: uy - 3.2, bottom: uy + 3.2 }));
    let best = null;
    let bestScore = -Infinity;
    let bestUnitOverlap = Infinity;
    let bestClearance = 0;
    const samples = [[0.28, 1], [0.28, -1], [0.42, 1], [0.42, -1], [0.56, 1], [0.56, -1], [0.7, 1], [0.34, 1], [0.34, -1], [0.8, 1], [0.8, -1]];
    samples.forEach(([t, side]) => {
      const bx = (1 - t) * (1 - t) * x1 + 2 * (1 - t) * t * cx + t * t * x2;
      const by = (1 - t) * (1 - t) * y1 + 2 * (1 - t) * t * cy + t * t * y2;
      const dxdt = 2 * (1 - t) * (cx - x1) + 2 * t * (x2 - cx);
      const dydt = 2 * (1 - t) * (cy - y1) + 2 * t * (y2 - cy);
      const dl = Math.hypot(dxdt, dydt) || 1;
      const px = -dydt / dl;
      const py = dxdt / dl;
      let pxx = bx + px * 3.1 * side;
      let pyy = by + py * 3.1 * side;
      pxx = clamp(pxx, 3 + width / 2, 97 - width / 2);
      pyy = clamp(pyy, 5, 95);
      const box = { left: pxx - width / 2, right: pxx + width / 2, top: pyy - 2.7, bottom: pyy + 1.3 };
      let nearestUnit = 8;
      unitPts.forEach(([ux, uy]) => {
        nearestUnit = Math.min(nearestUnit, Math.hypot(ux - pxx, uy - pyy));
      });
      let unitOverlap = 0;
      unitBoxes.forEach((unitBox) => {
        if (boxesOverlap(box, unitBox)) unitOverlap += 1;
      });
      let labelOverlap = 0;
      (placedRects || []).forEach((placed) => {
        if (boxesOverlap(box, placed)) labelOverlap += 1;
      });
      const score = -unitOverlap * 10 - labelOverlap * 8 + Math.min(nearestUnit, 7) * 0.5;
      if (score > bestScore) {
        bestScore = score;
        bestUnitOverlap = unitOverlap;
        bestClearance = nearestUnit;
        best = [pxx, pyy];
      }
    });
    // 队形拥挤到放不下时宁可不放标注，避免压住兵种图形与其它文字
    if (best && bestUnitOverlap === 0 && bestClearance >= 4) {
      lx = best[0];
      ly = best[1];
      rect = { left: lx - width / 2 - 0.6, right: lx + width / 2 + 0.6, top: ly - 2.7, bottom: ly + 1.3 };
    } else {
      text = '';
    }
  }
  return { style, x1, y1, cx, cy, x2, y2, lx, ly, text, rect };
}

function arrowMarkup(geom, uid, index, reduce) {
  const { style, x1, y1, cx, cy, x2, y2, lx, ly, text } = geom;
  const delay = reduce ? '0ms' : `${Math.min(index, 8) * 80}ms`;
  const dash = style.dash ? ` stroke-dasharray="${style.dash}"` : '';
  const filter = style.glow ? ` filter="url(#${uid}-glowf)"` : '';
  const label = text
    ? `<text class="rp-arrow-label" x="${f(lx)}" y="${f(ly)}" text-anchor="middle" fill="${style.color}">${esc(text)}</text>`
    : '';
  return `<g class="rp-arrow" style="animation-delay:${delay}">
    <path class="rp-arrow-line${style.flow ? ' is-flow' : ''}" d="M${f(x1)} ${f(y1)} Q${f(cx)} ${f(cy)} ${f(x2)} ${f(
    y2
  )}" stroke="${style.color}" stroke-width="${style.width}"${dash}${filter} marker-end="url(#${uid}-${style.head})"/>
    ${label}
  </g>`;
}

/* ============================================================
   页面模板
   ============================================================ */

function titleOf(replay, meta) {
  return meta.name || stripReplaySuffix(replay.title) || replay.battleId;
}

function subtitleOf(replay, meta) {
  if (replay.subtitle) return replay.subtitle;
  const bits = [meta.yearText, meta.era].filter(Boolean);
  return bits.join(' · ');
}

function progressHTML(stages) {
  return stages
    .map(
      (stage, i) =>
        `<button class="rp-seg" type="button" data-i="${i}" style="flex-grow:${Math.max(
          2,
          stage.duration
        )}" aria-label="第 ${i + 1} 阶段 · ${esc(stage.title)}"><span class="rp-seg-fill"></span></button>`
    )
    .join('');
}

function chipsHTML(stages) {
  return stages
    .map(
      (stage, i) =>
        `<li><button class="rp-chip" type="button" data-i="${i}" aria-label="跳到第 ${i + 1} 阶段"><span class="rp-chip-n">${String(
          i + 1
        ).padStart(2, '0')}</span><span class="rp-chip-t">${esc(stage.title)}</span></button></li>`
    )
    .join('');
}

function speedHTML() {
  return SPEEDS.map(
    (speed) =>
      `<button class="rp-speed-btn" type="button" data-speed="${speed}" aria-pressed="${speed === 1}" aria-label="速度 ${speed} 倍">${speed}×</button>`
  ).join('');
}

function legendHTML() {
  return `<span class="rp-leg rp-leg--a"><i></i>朱砂</span><span class="rp-leg rp-leg--b"><i></i>青铜</span><span class="rp-leg rp-leg--n"><i></i>中立</span>`;
}

function playerHTML(replay, meta, uid) {
  const stages = replay.stages;
  return `<section class="replay-page" role="region" aria-label="战役动画推演" data-replay="${esc(
    replay.battleId
  )}" data-rp-stage="0" data-rp-playing="0" data-rp-finished="0">
    <header class="rp-bar">
      <button class="icon-btn" type="button" data-rp="back" aria-label="返回战役详情">${icon('back')}</button>
      <div class="rp-bar-title">
        <span class="rp-bar-name">${esc(titleOf(replay, meta))}</span>
        <span class="rp-bar-sub">${esc(subtitleOf(replay, meta))}</span>
      </div>
      <span class="rp-bar-year">${esc(meta.yearText)}</span>
    </header>

    <main class="rp-board">
      <div class="rp-canvas-wrap">
        <div class="rp-canvas">
          <svg class="rp-svg" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid meet" aria-hidden="true" focusable="false">
            ${svgDefs(uid)}
            <g class="rp-cam" transform="translate(0 0) scale(1)">
              <g class="rp-terrain-layer">${terrainLayer(replay.terrain, replay.battleId, uid)}</g>
              <g class="rp-arrow-layer"></g>
              <g class="rp-unit-layer"></g>
            </g>
          </svg>
          <span class="rp-scan" aria-hidden="true"></span>
          <div class="rp-hud" aria-hidden="true">
            <span class="rp-hud-stage"><span class="rp-hud-idx">壹</span><span class="rp-hud-total">/ ${NUM[
              Math.max(0, Math.min(stages.length - 1, NUM.length - 1))
            ]}</span></span>
            <span class="rp-hud-terrain">${esc(TERRAIN_NAME[replay.terrain] || '')}</span>
          </div>
          <div class="rp-legend" aria-hidden="true">${legendHTML()}</div>
          <span class="corner-orn" aria-hidden="true"></span>
        </div>
      </div>

      <div class="rp-caption" aria-live="polite">
        <div class="rp-cap-inner">
          <div class="rp-cap-top">
            <span class="rp-cap-idx">壹</span>
            <h2 class="rp-cap-title"></h2>
            <span class="rp-cap-dur"></span>
          </div>
          <p class="rp-cap-text"></p>
        </div>
      </div>
    </main>

    <div class="rp-console">
      <div class="rp-progress" role="group" aria-label="阶段进度">${progressHTML(stages)}</div>
      <div class="rp-transport">
        <div class="rp-tbtns">
          <button class="rp-tbtn" type="button" data-rp="prev" aria-label="上一阶段">${icon('back')}</button>
          <button class="rp-play" type="button" data-rp="play" aria-label="播放">${SVG_PLAY}</button>
          <button class="rp-tbtn" type="button" data-rp="next" aria-label="下一阶段">${icon('forward')}</button>
          <button class="rp-tbtn" type="button" data-rp="restart" aria-label="重播">${icon('refresh')}</button>
        </div>
        <div class="rp-speed" role="group" aria-label="播放速度">${speedHTML()}</div>
      </div>
      <ol class="rp-stages no-scrollbar" aria-label="阶段列表">${chipsHTML(stages)}</ol>
    </div>
  </section>`;
}

function statePageHTML(inner, title) {
  return `<section class="replay-page replay-page--state" role="region" aria-label="战役动画推演">
    <header class="rp-bar">
      <button class="icon-btn" type="button" data-rp="back" aria-label="返回">${icon('back')}</button>
      <div class="rp-bar-title"><span class="rp-bar-name">${esc(title || '战役推演')}</span></div>
    </header>
    <div class="rp-state">${inner}</div>
  </section>`;
}

function loadingHTML() {
  return statePageHTML('<span class="rp-spin" aria-hidden="true"></span><p>推演装载中…</p>', '战役推演');
}

function emptyHTML(ctx, id) {
  const meta = battleMeta(ctx, id);
  const known = !!meta.name;
  const title = known ? `${meta.name} · 推演` : '战役推演';
  const desc = known
    ? `「${meta.name}」的动画推演尚未编成。可先阅读战役详情，或回到时间轴继续展卷。`
    : `未找到「${id || '该战役'}」的推演脚本。可能是链接有误，或这一场尚未编入推演卷。`;
  const action = `<button class="btn btn--gold" type="button" data-rp="back">${known ? '返回战役详情' : '返回时间轴'}</button>`;
  return statePageHTML(emptyStateHTML({ title: '此役推演未成卷', desc, actions: action }), title);
}

/* ============================================================
   播放器实例
   ============================================================ */

let live = null;
let renderSeq = 0;

function goBackById(ctx, id) {
  if (id) {
    navigate(`/battle/${encodeURIComponent(id)}`);
    return;
  }
  navigate('/');
}

function wireStatePage(root, ctx, id) {
  const back = root.querySelector('[data-rp="back"]');
  if (back) {
    back.addEventListener('click', () => goBackById(ctx, id));
  }
}

function mount(root, ctx, replay, requestedId, token) {
  const uid = `rp${hashSeed(replay.battleId) % 100000}`;
  const meta = battleMeta(ctx, replay.battleId);
  const state = {
    token,
    root,
    ctx,
    replay,
    requestedId,
    uid,
    meta,
    stages: replay.stages,
    index: 0,
    stageTime: 0,
    speed: 1,
    playing: false,
    finished: false,
    raf: 0,
    lastTs: null,
    tweens: [],
    timers: [],
    units: new Map(),
    cam: { s: 1, tx: 0, ty: 0 },
    reduce: readReduce(),
    listeners: [],
    observer: null,
    page: null,
    els: {},
  };
  live = state;

  try {
    document.body.dataset.chrome = 'none';
  } catch (err) {
    /* ignore */
  }

  root.innerHTML = playerHTML(replay, meta, uid);
  state.page = root.querySelector('.replay-page');
  if (!state.page) return;

  const q = (sel) => state.page.querySelector(sel);
  const qa = (sel) => [...state.page.querySelectorAll(sel)];
  state.els = {
    page: state.page,
    svg: q('.rp-svg'),
    cam: q('.rp-cam'),
    unitLayer: q('.rp-unit-layer'),
    arrowLayer: q('.rp-arrow-layer'),
    hudIdx: q('.rp-hud-idx'),
    hudTotal: q('.rp-hud-total'),
    cap: q('.rp-caption'),
    capIdx: q('.rp-cap-idx'),
    capTitle: q('.rp-cap-title'),
    capText: q('.rp-cap-text'),
    capDur: q('.rp-cap-dur'),
    segs: qa('.rp-seg'),
    segFills: qa('.rp-seg-fill'),
    chips: qa('.rp-chip'),
    stageList: q('.rp-stages'),
    playBtn: q('.rp-play'),
    prevBtn: q('[data-rp="prev"]'),
    nextBtn: q('[data-rp="next"]'),
    speedBtns: qa('.rp-speed-btn'),
  };

  bind(state);
  applyStage(state, 0, { animate: false });
  updatePlayBtn(state);

  // 自动播放（减弱动效时改为静态首帧，交给用户手动推进）
  if (!state.reduce) {
    state.timers.push(
      window.setTimeout(() => {
        if (live === state && !state.playing && !state.finished && state.index === 0 && state.stageTime === 0) {
          playState(state);
        }
      }, 420)
    );
  }
}

function bind(state) {
  const onClick = (event) => {
    if (live !== state) return;
    if (!state.page || !state.page.isConnected) {
      disposeReplay();
      return;
    }
    const btn = event.target && event.target.closest ? event.target.closest('button') : null;
    if (!btn || !state.page.contains(btn)) return;
    const action = btn.dataset.rp;
    if (action === 'back') {
      goBackById(state.ctx, state.replay.battleId || state.requestedId);
      return;
    }
    if (action === 'play') {
      togglePlay(state);
      return;
    }
    if (action === 'prev') {
      jumpTo(state, state.index - 1);
      return;
    }
    if (action === 'next') {
      jumpTo(state, state.index + 1);
      return;
    }
    if (action === 'restart') {
      restartPlayback(state);
      return;
    }
    if (btn.dataset.speed != null) {
      setSpeed(state, Number(btn.dataset.speed));
      return;
    }
    if (btn.dataset.i != null) {
      const i = Number(btn.dataset.i);
      if (Number.isFinite(i)) jumpTo(state, i);
    }
  };
  state.root.addEventListener('click', onClick);
  state.listeners.push([state.root, 'click', onClick]);

  const onKey = (event) => {
    if (live !== state || event.defaultPrevented) return;
    if (!state.page || !state.page.isConnected) {
      disposeReplay();
      return;
    }
    const target = event.target;
    if (target && target.closest && target.closest('input, textarea, select, [contenteditable="true"]')) return;
    if (event.key === ' ' || event.code === 'Space') {
      if (target && target.closest && target.closest('button, a')) return;
      event.preventDefault();
      togglePlay(state);
      return;
    }
    if (event.key === 'ArrowRight') {
      event.preventDefault();
      jumpTo(state, state.index + 1);
    } else if (event.key === 'ArrowLeft') {
      event.preventDefault();
      jumpTo(state, state.index - 1);
    }
  };
  document.addEventListener('keydown', onKey);
  state.listeners.push([document, 'keydown', onKey]);

  const onVisibility = () => {
    if (live !== state) return;
    if (!state.page || !state.page.isConnected) {
      disposeReplay();
      return;
    }
    if (document.hidden && state.playing) pauseState(state);
  };
  document.addEventListener('visibilitychange', onVisibility);
  state.listeners.push([document, 'visibilitychange', onVisibility]);

  try {
    const observer = new MutationObserver(() => {
      if (live !== state) return;
      const next = readReduce();
      if (next === state.reduce) return;
      state.reduce = next;
      if (next) {
        // 立即吸附到终点，取消位移
        state.tweens.forEach((tween) => {
          if (tween.kind === 'unit') {
            tween.rec.x = tween.x1;
            tween.rec.y = tween.y1;
            setTranslate(tween.el, tween.x1, tween.y1);
          } else {
            state.cam = { s: tween.s1, tx: tween.tx1, ty: tween.ty1 };
            applyCamTransform(state);
          }
        });
        state.tweens = [];
      }
    });
    observer.observe(document.documentElement, { attributes: true, attributeFilter: ['data-motion'] });
    if (document.body) observer.observe(document.body, { attributes: true, attributeFilter: ['data-motion'] });
    state.observer = observer;
  } catch (err) {
    /* ignore */
  }
}

/* ---------------- 阶段渲染 ---------------- */

function applyStage(state, index, opts = {}) {
  const animate = opts.animate !== false;
  const total = state.stages.length;
  const i = clamp(index, 0, total - 1);
  const stage = state.stages[i];

  state.index = i;
  state.stageTime = 0;
  state.finished = false;

  updateHud(state, stage, total);
  updateCaption(state, stage, i);
  updateProgress(state, 0);
  updateChips(state, i);
  const arrowRects = renderArrows(state, stage, i);
  const viewStage = { ...stage, units: declutterUnits(stage.units) };
  renderUnits(state, viewStage, animate, arrowRects);
  applyCamera(state, viewStage, animate);
  updateTransport(state);

  if (state.page) {
    state.page.dataset.rpStage = String(i);
    state.page.dataset.rpFinished = '0';
  }
}

function updateHud(state, stage, total) {
  const { hudIdx, hudTotal } = state.els;
  if (hudIdx) hudIdx.textContent = NUM[state.index] || String(state.index + 1);
  if (hudTotal) hudTotal.textContent = `/ ${NUM[Math.max(0, Math.min(total - 1, NUM.length - 1))]}`;
}

function updateCaption(state, stage, index) {
  const { cap, capIdx, capTitle, capText, capDur } = state.els;
  if (capIdx) capIdx.textContent = NUM[index] || String(index + 1);
  if (capTitle) capTitle.textContent = stage.title;
  if (capText) capText.textContent = stage.narration || '（本阶段暂无旁白）';
  if (capDur) capDur.textContent = `${stage.duration}″`;
  if (cap) {
    cap.classList.remove('is-in');
    // 强制重排以重放淡入
    void cap.offsetWidth;
    cap.classList.add('is-in');
  }
}

function updateProgress(state, ratio) {
  const { segs, segFills } = state.els;
  if (!segs || !segs.length) return;
  const p = clamp(ratio, 0, 1);
  segs.forEach((seg, i) => {
    const fill = segFills[i];
    let width = 0;
    if (state.finished) width = 100;
    else if (i < state.index) width = 100;
    else if (i === state.index) width = p * 100;
    if (fill) fill.style.width = `${width.toFixed(1)}%`;
    seg.classList.toggle('is-done', state.finished || i < state.index);
    seg.classList.toggle('is-active', !state.finished && i === state.index);
  });
}

function updateChips(state, index) {
  state.els.chips.forEach((chip, i) => {
    if (i === index) chip.setAttribute('aria-current', 'true');
    else chip.removeAttribute('aria-current');
  });
  const list = state.els.stageList;
  const chip = state.els.chips[index];
  if (!list || !chip) return;
  try {
    const listRect = list.getBoundingClientRect();
    const chipRect = chip.getBoundingClientRect();
    if (chipRect.left < listRect.left) {
      list.scrollLeft -= listRect.left - chipRect.left + 12;
    } else if (chipRect.right > listRect.right) {
      list.scrollLeft += chipRect.right - listRect.right + 12;
    }
  } catch (err) {
    /* ignore */
  }
}

function updateTransport(state) {
  if (state.els.prevBtn) state.els.prevBtn.disabled = state.index <= 0;
  if (state.els.nextBtn) state.els.nextBtn.disabled = state.index >= state.stages.length - 1;
}

/* ---------------- 单位 ---------------- */

const LABEL_FS = 2.45;

/** 同阶段内单位过近（数据里营寨与主力常几乎同位）时做轻微排布散开，仅影响显示坐标 */
function declutterUnits(units) {
  if (!Array.isArray(units) || units.length < 2) return units;
  const pts = units.map((unit) => ({ x: unit.pos[0], y: unit.pos[1] }));
  const MIN = 6.2;
  for (let iter = 0; iter < 10; iter += 1) {
    let moved = false;
    for (let i = 0; i < pts.length; i += 1) {
      for (let j = i + 1; j < pts.length; j += 1) {
        let dx = pts[j].x - pts[i].x;
        let dy = pts[j].y - pts[i].y;
        let dist = Math.hypot(dx, dy);
        if (dist >= MIN) continue;
        if (dist < 0.01) {
          dx = i % 2 ? 1 : -1;
          dy = 1;
          dist = Math.hypot(dx, dy);
        }
        const push = (MIN - dist) / 2;
        const ux = dx / dist;
        const uy = dy / dist;
        pts[i].x -= ux * push;
        pts[i].y -= uy * push;
        pts[j].x += ux * push;
        pts[j].y += uy * push;
        moved = true;
      }
    }
    if (!moved) break;
  }
  return units.map((unit, i) => {
    const x = clamp(pts[i].x, 4, 96);
    const y = clamp(pts[i].y, 4, 96);
    if (Math.abs(x - unit.pos[0]) < 0.05 && Math.abs(y - unit.pos[1]) < 0.05) return unit;
    return { ...unit, pos: [x, y] };
  });
}

function estimateTextWidth(text, fs) {
  let width = 0;
  for (const ch of String(text)) {
    width += /[\u2E80-\u9FFF\uF900-\uFAFF\uFF00-\uFFEF]/.test(ch) ? fs * 1.03 : fs * 0.58;
  }
  return width;
}

/** 地图标签去掉括注（如「楚右军（陈蔡）」→「楚右军」），过长截断 */
function mapLabel(label) {
  const raw = String(label || '').trim();
  const clean = raw.replace(/（[^）]*）|\([^)]*\)/g, '').trim() || raw;
  return clip(clean, 6);
}

function labelBox(x, y, anchor, text) {
  const width = estimateTextWidth(text, LABEL_FS);
  const left = anchor === 'middle' ? x - width / 2 : anchor === 'end' ? x - width : x;
  return { left, right: left + width, top: y - LABEL_FS * 0.95, bottom: y + LABEL_FS * 0.3 };
}

const boxesOverlap = (a, b) =>
  !(a.right < b.left - 0.3 || a.left > b.right + 0.3 || a.bottom < b.top - 0.3 || a.top > b.bottom + 0.3);

/**
 * 给单位标签选位置：下方 / 下方左右 / 上方 / 上方左右 / 左右依次尝试，
 * 按「与单位圆盘、箭头标注、已放标签的重叠数」评分择优，密集队形下也能尽量错开。
 */
function placeUnitLabel(textEl, x, y, text, obstacles) {
  const width = estimateTextWidth(text, LABEL_FS);
  const candidates = [
    { x, y: y + 5.9, anchor: 'middle' },
    { x: x + width / 2 + 2.4, y: y + 5.9, anchor: 'middle' },
    { x: x - width / 2 - 2.4, y: y + 5.9, anchor: 'middle' },
    { x, y: y - 4.9, anchor: 'middle' },
    { x: x + width / 2 + 2.4, y: y - 4.9, anchor: 'middle' },
    { x: x - width / 2 - 2.4, y: y - 4.9, anchor: 'middle' },
    { x: x + 3.9, y: y + 1.1, anchor: 'start' },
    { x: x - 3.9, y: y + 1.1, anchor: 'end' },
  ];
  let chosen = null;
  let bestScore = Infinity;
  candidates.forEach((candidate, index) => {
    const box = labelBox(candidate.x, candidate.y, candidate.anchor, text);
    let dx = 0;
    if (box.left < 1) dx = 1 - box.left;
    else if (box.right > 99) dx = 99 - box.right;
    const shifted = { ...box, left: box.left + dx, right: box.right + dx };
    let hits = 0;
    obstacles.forEach((obstacle) => {
      if (boxesOverlap(shifted, obstacle)) hits += 1;
    });
    // 重叠越少越好；同分时优先靠前（下方）候选
    const score = hits * 10 + index * 0.01;
    if (score < bestScore) {
      bestScore = score;
      chosen = { ...candidate, x: candidate.x + dx, box: shifted };
    }
  });
  // 标签是单位 <g>（已 translate 到单位位置）的子元素，故写局部坐标
  textEl.setAttribute('x', f(chosen.x - x));
  textEl.setAttribute('y', f(chosen.y - y));
  textEl.setAttribute('text-anchor', chosen.anchor);
  obstacles.push(chosen.box);
}

function renderUnits(state, stage, animate, arrowRects) {
  const layer = state.els.unitLayer;
  if (!layer) return;
  const next = new Map();

  stage.units.forEach((unit, index) => {
    const key = unit.id;
    let rec = state.units.get(key);
    if (!rec) {
      const el = svgElementFromMarkup(unitMarkup(unit, index));
      if (!el) return;
      rec = { el, x: unit.pos[0], y: unit.pos[1], labelEl: el.querySelector('.rp-label') };
      layer.appendChild(el);
      state.units.set(key, rec);
      moveUnit(state, rec, unit.pos[0], unit.pos[1], false);
    } else {
      moveUnit(state, rec, unit.pos[0], unit.pos[1], animate);
    }
    next.set(key, rec);
  });

  // 本阶段退场的单位：淡出后移除
  state.units.forEach((rec, key) => {
    if (next.has(key)) return;
    state.units.delete(key);
    rec.el.classList.add('is-out');
    state.timers.push(
      window.setTimeout(() => {
        if (rec.el && rec.el.parentNode) rec.el.parentNode.removeChild(rec.el);
      }, 360)
    );
  });

  // 标签避让：圆盘与箭头标注作为障碍
  const obstacles = [];
  (arrowRects || []).forEach((rect) => obstacles.push(rect));
  stage.units.forEach((unit) => {
    obstacles.push({ left: unit.pos[0] - 3.1, right: unit.pos[0] + 3.1, top: unit.pos[1] - 3.1, bottom: unit.pos[1] + 3.1 });
  });
  stage.units.forEach((unit) => {
    const rec = state.units.get(unit.id);
    if (!rec || !rec.labelEl) return;
    const text = mapLabel(unit.label);
    rec.labelEl.textContent = text;
    placeUnitLabel(rec.labelEl, unit.pos[0], unit.pos[1], text, obstacles);
  });
}

function svgElementFromMarkup(markup) {
  try {
    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.innerHTML = markup;
    return svg.firstElementChild;
  } catch (err) {
    return null;
  }
}

function setTranslate(el, x, y) {
  el.setAttribute('transform', `translate(${f(x)} ${f(y)})`);
}

function moveUnit(state, rec, x, y, animate) {
  rec.tx = x;
  rec.ty = y;
  if (!animate || state.reduce) {
    state.tweens = state.tweens.filter((tween) => tween.rec !== rec);
    rec.x = x;
    rec.y = y;
    setTranslate(rec.el, x, y);
    return;
  }
  state.tweens = state.tweens.filter((tween) => tween.rec !== rec);
  state.tweens.push({
    kind: 'unit',
    rec,
    el: rec.el,
    x0: rec.x,
    y0: rec.y,
    x1: x,
    y1: y,
    t0: performance.now(),
    dur: 640,
  });
  ensureLoop(state);
}

/* ---------------- 箭头 ---------------- */

function renderArrows(state, stage, index) {
  const layer = state.els.arrowLayer;
  if (!layer) return [];
  const placed = [];
  const geoms = stage.arrows.map((arrow) => {
    const geom = arrowGeometry(arrow, stage.units, placed);
    if (geom.rect) placed.push(geom.rect);
    return geom;
  });
  layer.innerHTML = geoms.map((geom, i) => arrowMarkup(geom, state.uid, i, state.reduce)).join('');
  return geoms.map((geom) => geom.rect).filter(Boolean);
}

/* ---------------- 镜头 ---------------- */

/**
 * 镜头轻缩放：以 focus 为中心，但先用本阶段「单位 + 箭头端点」的包围盒
 * 反推最大可放大倍数，保证任何一方都不会被裁出画布（f 可选、可降级）。
 */
function cameraTarget(stage) {
  const focus = stage && stage.focus;
  const pts = [];
  if (stage) {
    (stage.units || []).forEach((unit) => pts.push(unit.pos));
    (stage.arrows || []).forEach((arrow) => {
      pts.push(arrow.from);
      pts.push(arrow.to);
    });
  }
  let bbox = null;
  if (pts.length) {
    let minX = 100;
    let maxX = 0;
    let minY = 100;
    let maxY = 0;
    pts.forEach(([x, y]) => {
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    });
    bbox = { minX, maxX, minY, maxY };
  }
  if (!focus) return { s: 1, tx: 0, ty: 0 };

  const [fx, fy, fr] = focus;
  let s = clamp(50 / Math.max(fr, 10), 1, 1.55);
  if (bbox) {
    // 留 8% 边距 + 标签空间，反推能容纳包围盒的最大缩放
    const need = Math.max(bbox.maxX - bbox.minX, bbox.maxY - bbox.minY) * 1.16 + 12;
    s = Math.min(s, 100 / Math.max(need, 24));
  }
  s = clamp(s, 1, 1.55);
  if (s <= 1.001) return { s: 1, tx: 0, ty: 0 };

  const half = 50 / s;
  let cx = clamp(fx, half, 100 - half);
  let cy = clamp(fy, half, 100 - half);
  // focus 若把包围盒推到视野外，则退回包围盒中心
  if (bbox) {
    const pad = 3;
    const fits = cx - half + pad <= bbox.minX && cx + half - pad >= bbox.maxX && cy - half + pad <= bbox.minY && cy + half - pad >= bbox.maxY;
    if (!fits) {
      cx = clamp((bbox.minX + bbox.maxX) / 2, half, 100 - half);
      cy = clamp((bbox.minY + bbox.maxY) / 2, half, 100 - half);
    }
  }
  return { s, tx: 50 - s * cx, ty: 50 - s * cy };
}

function applyCamTransform(state) {
  if (!state.els.cam) return;
  const { s, tx, ty } = state.cam;
  state.els.cam.setAttribute('transform', `translate(${f(tx)} ${f(ty)}) scale(${f(s)})`);
}

function applyCamera(state, stage, animate) {
  const target = cameraTarget(stage);
  state.tweens = state.tweens.filter((tween) => tween.kind !== 'cam');
  if (!animate || state.reduce) {
    state.cam = target;
    applyCamTransform(state);
    return;
  }
  state.tweens.push({
    kind: 'cam',
    s0: state.cam.s,
    tx0: state.cam.tx,
    ty0: state.cam.ty,
    s1: target.s,
    tx1: target.tx,
    ty1: target.ty,
    t0: performance.now(),
    dur: 700,
  });
  ensureLoop(state);
}

/* ---------------- 播放控制 ---------------- */

function updatePlayBtn(state) {
  const btn = state.els.playBtn;
  if (!btn) return;
  btn.classList.toggle('is-playing', state.playing);
  btn.setAttribute('aria-label', state.playing ? '暂停' : state.finished ? '重播' : '播放');
  btn.innerHTML = state.playing ? SVG_PAUSE : SVG_PLAY;
  if (state.page) {
    state.page.dataset.rpPlaying = state.playing ? '1' : '0';
    state.page.dataset.rpFinished = state.finished ? '1' : '0';
  }
}

function ensureLoop(state) {
  if (live !== state || state.raf) return;
  if (!state.playing && !state.tweens.length) return;
  state.lastTs = null;
  state.raf = requestAnimationFrame((ts) => frameTick(state, ts));
}

function frameTick(state, ts) {
  state.raf = 0;
  if (live !== state) return;
  const page = state.els.page;
  if (!page || !page.isConnected) {
    disposeReplay();
    return;
  }
  const now = ts || (window.performance && performance.now ? performance.now() : Date.now());
  const dt = state.lastTs == null ? 0 : Math.min(now - state.lastTs, 140);
  state.lastTs = now;

  tickTweens(state, now);

  if (state.playing) {
    const stage = state.stages[state.index];
    const duration = stage.duration * 1000;
    state.stageTime += dt * state.speed;
    if (state.stageTime >= duration) {
      if (state.index < state.stages.length - 1) {
        applyStage(state, state.index + 1, { animate: true });
        state.lastTs = null;
      } else {
        state.stageTime = duration;
        finish(state);
      }
    }
    const current = state.stages[state.index];
    updateProgress(state, current.duration > 0 ? state.stageTime / (current.duration * 1000) : 1);
  }

  if (state.playing || state.tweens.length) {
    state.raf = requestAnimationFrame((nextTs) => frameTick(state, nextTs));
  } else {
    state.lastTs = null;
  }
}

function tickTweens(state, now) {
  if (!state.tweens.length) return;
  const keep = [];
  for (const tween of state.tweens) {
    const progress = state.reduce ? 1 : clamp((now - tween.t0) / tween.dur, 0, 1);
    const eased = easeOutCubic(progress);
    if (tween.kind === 'unit') {
      const x = tween.x0 + (tween.x1 - tween.x0) * eased;
      const y = tween.y0 + (tween.y1 - tween.y0) * eased;
      tween.rec.x = x;
      tween.rec.y = y;
      setTranslate(tween.el, x, y);
    } else {
      state.cam = {
        s: tween.s0 + (tween.s1 - tween.s0) * eased,
        tx: tween.tx0 + (tween.tx1 - tween.tx0) * eased,
        ty: tween.ty0 + (tween.ty1 - tween.ty0) * eased,
      };
      applyCamTransform(state);
    }
    if (progress < 1) keep.push(tween);
  }
  state.tweens = keep;
}

function playState(state) {
  if (live !== state) return;
  if (state.finished) {
    state.finished = false;
    applyStage(state, 0, { animate: false });
  }
  state.playing = true;
  state.lastTs = null;
  updatePlayBtn(state);
  ensureLoop(state);
}

function pauseState(state) {
  state.playing = false;
  state.lastTs = null;
  updatePlayBtn(state);
  ensureLoop(state);
}

function togglePlay(state) {
  if (state.playing) pauseState(state);
  else playState(state);
}

function jumpTo(state, index) {
  if (live !== state) return;
  const target = clamp(index, 0, state.stages.length - 1);
  if (!Number.isFinite(target)) return;
  const wasPlaying = state.playing;
  state.playing = false;
  state.finished = false;
  applyStage(state, target, { animate: true });
  if (wasPlaying) {
    state.playing = true;
    state.lastTs = null;
  }
  updatePlayBtn(state);
  ensureLoop(state);
}

function restartPlayback(state) {
  const wasPlaying = state.playing;
  state.playing = false;
  state.finished = false;
  applyStage(state, 0, { animate: true });
  if (wasPlaying) {
    state.playing = true;
    state.lastTs = null;
  }
  updatePlayBtn(state);
  ensureLoop(state);
}

function finish(state) {
  state.playing = false;
  state.finished = true;
  state.lastTs = null;
  updatePlayBtn(state);
  updateProgress(state, 1);
}

function setSpeed(state, value) {
  if (!SPEEDS.includes(value)) return;
  state.speed = value;
  state.lastTs = null;
  state.els.speedBtns.forEach((btn) => {
    const active = Number(btn.dataset.speed) === value;
    btn.setAttribute('aria-pressed', active ? 'true' : 'false');
  });
}

/* ============================================================
   对外接口
   ============================================================ */

export function renderReplay(root, ctx, battleId) {
  disposeReplay();
  if (!root) return;
  const token = ++renderSeq;
  const id = str(battleId).trim();

  root.innerHTML = loadingHTML();
  wireStatePage(root, ctx, id);

  // 数据与样式都就绪后再挂载，避免首帧无样式闪烁
  Promise.all([loadReplays(ctx), stylesReady])
    .then(([list]) => {
      if (token !== renderSeq || !root.isConnected) return;
      const replay = list.find((item) => item.battleId === id) || null;
      if (!replay) {
        root.innerHTML = emptyHTML(ctx, id);
        wireStatePage(root, ctx, id);
        return;
      }
      mount(root, ctx, replay, id, token);
    })
    .catch((err) => {
      if (token !== renderSeq) return;
      console.error('[山河战纪] 推演渲染失败', err);
      root.innerHTML = emptyHTML(ctx, id);
      wireStatePage(root, ctx, id);
    });
}

export function disposeReplay() {
  renderSeq += 1;
  const state = live;
  live = null;
  if (!state) return;
  if (state.raf) {
    cancelAnimationFrame(state.raf);
    state.raf = 0;
  }
  if (state.timers && state.timers.length) {
    state.timers.forEach((id) => clearTimeout(id));
    state.timers = [];
  }
  if (state.listeners && state.listeners.length) {
    state.listeners.forEach(([target, type, handler]) => {
      try {
        target.removeEventListener(type, handler);
      } catch (err) {
        /* ignore */
      }
    });
    state.listeners = [];
  }
  if (state.observer) {
    try {
      state.observer.disconnect();
    } catch (err) {
      /* ignore */
    }
    state.observer = null;
  }
  if (state.tweens) state.tweens.length = 0;
  if (state.units) state.units.clear();
  state.page = null;
  state.els = {};
  state.root = null;
}
