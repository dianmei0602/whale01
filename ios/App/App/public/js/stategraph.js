/* ============================================================
   stategraph.js — 3.2 国家关系思维导图（双图层图谱的「国家关系」层）
   接口（固定，勿改名）：
     export function renderStateGraph(host, ctx, opts = {})
     export function disposeStateGraph()
   数据：ctx.data.factions（20 势力，自动取色）+ ctx.data.stateExtraNodes（外部势力）
         + ctx.data.stateRelations（关系边）；缺失时 fetch 兜底，仍无 → 空态。
   布局：按时代分环的稳定放射布局（最内圈=最早时期，每代占一段扇区），
         势力=圆点、外部势力=菱点，节点内 2–3 字简称常显，选中/高倍缩放显全名。
   零依赖、无外链；减弱动效下无动画；390/375/430 无横溢。
   ============================================================ */

import { esc, icon, fmtYear, emptyStateHTML, toast } from './ui.js';
import { initDrawerSpring, skeletonHTML } from './motion.js';

const CSS_HREF = 'css/stategraph.css';

/* ---------------- 样式：模块加载即注入（index.html 未加 link 也可用） ---------------- */
let stylesPromise = null;
function ensureStyles() {
  try {
    const links = document.querySelectorAll('link[rel="stylesheet"]');
    for (const link of links) {
      const href = link.getAttribute('href') || '';
      if (href.includes('stategraph.css')) return Promise.resolve();
    }
    if (stylesPromise) return stylesPromise;
    stylesPromise = new Promise((resolve) => {
      const el = document.createElement('link');
      el.rel = 'stylesheet';
      el.href = CSS_HREF;
      el.dataset.stategraphCss = '1';
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

/* ---------------- 常量 ---------------- */
const W = 420;
const H = 430;
const CX = W / 2;
const CY = H / 2;
const R_HUB = 84;
const R_INNER = 126;
const R_OUTER = 172;
const NODE_BASE_R = 15;
const LABEL_FS = 12;

const TYPES = ['战争', '并吞', '和亲', '会盟', '朝贡', '联盟'];
const TYPE_STYLE = {
  战争: { color: '#C94B3A', dash: '', dashType: 'solid', width: 1.7, arrow: false, label: '战争' },
  并吞: { color: '#C94B3A', dash: '', dashType: 'solid', width: 3.0, arrow: true, label: '并吞' },
  和亲: { color: '#E0C060', dash: '1.6 4', dashType: 'dotted', width: 1.7, arrow: false, label: '和亲' },
  会盟: { color: '#8C9B7E', dash: '7 5', dashType: 'dashed', width: 1.9, arrow: false, label: '会盟' },
  朝贡: { color: '#9C907B', dash: '4 6', dashType: 'dashed', width: 1.6, arrow: false, label: '朝贡' },
  联盟: { color: '#74A36F', dash: '', dashType: 'solid', width: 1.9, arrow: false, label: '联盟' },
};
const TYPE_FALLBACK = TYPE_STYLE['战争'];

const KIND_COLOR = {
  部族: '#8C6F1C',
  王朝: '#C9A227',
  割据政权: '#B8783A',
  联军: '#6F7B66',
  外国军队: '#9C907B',
  近代军队: '#A9A08C',
  其他: '#9C907B',
};

/* 时代分环：按 startYear 归入时期（与 eras.json 的 12 期分段兼容） */
const EPOCHS = [
  { id: 'pre-qin', name: '先秦', startYear: -2600, endYear: -221 },
  { id: 'qin-han', name: '秦汉魏晋', startYear: -220, endYear: 580 },
  { id: 'sui-tang', name: '隋唐', startYear: 581, endYear: 907 },
  { id: 'song-liao', name: '宋辽金夏', startYear: 908, endYear: 1270 },
  { id: 'yuan-qing', name: '元明清', startYear: 1271, endYear: 1840 },
  { id: 'modern', name: '近现代', startYear: 1841, endYear: 2100 },
];

const DEG = Math.PI / 180;

/* ---------------- 小工具 ---------------- */
const str = (v) => (v == null ? '' : String(v));
const arr = (v) => (Array.isArray(v) ? v : v == null || v === '' ? [] : [v]);
const num = (v, fallback) => (Number.isFinite(Number(v)) ? Number(v) : fallback);
const clamp = (v, min, max) => (v < min ? min : v > max ? max : v);
const polar = (angle, radius) => ({ x: CX + Math.cos(angle) * radius, y: CY + Math.sin(angle) * radius });
const reducedMotion = () => {
  try {
    const html = document.documentElement.dataset.motion;
    const body = document.body && document.body.dataset.motion;
    if (html === 'reduce' || body === 'reduce') return true;
  } catch (err) {
    /* ignore */
  }
  return !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
};

function yearRange(startYear, endYear) {
  const s = Number.isFinite(Number(startYear)) ? Number(startYear) : null;
  const e = Number.isFinite(Number(endYear)) ? Number(endYear) : s;
  if (s == null && e == null) return '';
  if (s != null && e != null && s !== e) return `${fmtYear(s)}—${fmtYear(e)}`;
  return fmtYear(s != null ? s : e);
}

/** 节点内单字印记：势力取末字（汉/魏/宋/晋），附加政权取首字（匈/吐/准），长名特判 */
const SYMBOL_OVERRIDE = { 中华民国: '民', 中华人民共和国: '共', 苏联: '苏' };
function symbolFor(name, isFaction) {
  const text = str(name).trim();
  if (!text) return '·';
  if (SYMBOL_OVERRIDE[text]) return SYMBOL_OVERRIDE[text];
  if (text.length === 1) return text;
  if (isFaction) return text.slice(-1);
  return text.slice(0, 1);
}

function epochIndexForYear(year) {
  const y = Number.isFinite(Number(year)) ? Number(year) : 0;
  for (let i = 0; i < EPOCHS.length; i += 1) {
    const epoch = EPOCHS[i];
    if (y >= epoch.startYear && y <= epoch.endYear) return i;
  }
  return y < EPOCHS[0].startYear ? 0 : EPOCHS.length - 1;
}

function hasOverlap(aStart, aEnd, bStart, bEnd) {
  const a1 = Number.isFinite(Number(aStart)) ? Number(aStart) : -1e9;
  const a2 = Number.isFinite(Number(aEnd)) ? Number(aEnd) : a1;
  const b1 = Number.isFinite(Number(bStart)) ? Number(bStart) : -1e9;
  const b2 = Number.isFinite(Number(bEnd)) ? Number(bEnd) : b1;
  return a2 >= b1 && a1 <= b2;
}

/* ============================================================
   数据：规范化 / 读取
   ============================================================ */

function normalizeFaction(raw, index) {
  if (!raw || typeof raw !== 'object') return null;
  const id = str(raw.id).trim();
  const name = str(raw.name).trim();
  if (!id || !name) return null;
  const startYear = num(raw.startYear, 0);
  const endYear = num(raw.endYear, startYear);
  return {
    id,
    name,
    symbol: symbolFor(name, true),
    color: /^#[0-9a-fA-F]{6}$/.test(str(raw.color)) ? str(raw.color) : '#C9A227',
    kind: '势力',
    isFaction: true,
    startYear,
    endYear,
    eraIds: arr(raw.eraIds).map(str).filter(Boolean),
    family: str(raw.family),
    fullName: str(raw.fullName),
    rangeText: str(raw.rangeText) || yearRange(startYear, endYear),
    note: str(raw.tagline),
  };
}

function normalizeExtraNode(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const id = str(raw.id).trim();
  const name = str(raw.name).trim();
  if (!id || !name) return null;
  const kind = str(raw.kind) || '部族';
  const startYear = num(raw.startYear, 0);
  const endYear = num(raw.endYear, startYear);
  return {
    id,
    name,
    symbol: symbolFor(name, false),
    color: /^#[0-9a-fA-F]{6}$/.test(str(raw.color)) ? str(raw.color) : KIND_COLOR[kind] || '#9C907B',
    kind,
    isFaction: false,
    startYear,
    endYear,
    eraIds: [],
    family: '',
    fullName: '',
    rangeText: str(raw.rangeText) || yearRange(startYear, endYear),
    note: str(raw.note),
  };
}

function normalizeRelation(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const from = str(raw.from).trim();
  const to = str(raw.to).trim();
  if (!from || !to || from === to) return null;
  const type = TYPES.includes(str(raw.type)) ? str(raw.type) : '战争';
  const startYear = num(raw.startYear, null);
  const endYear = num(raw.endYear, startYear);
  return {
    id: str(raw.id) || `${from}-${to}-${type}`,
    from,
    to,
    type,
    startYear,
    endYear,
    battles: arr(raw.battles).map(str).filter(Boolean),
    note: str(raw.note),
    sources: arr(raw.sources).map(str).filter(Boolean),
  };
}

function normalizeList(raw) {
  if (!raw) return [];
  if (Array.isArray(raw)) return raw;
  if (typeof raw === 'object') {
    if (Array.isArray(raw.relations)) return raw.relations;
    if (Array.isArray(raw.list)) return raw.list;
    if (Array.isArray(raw.items)) return raw.items;
  }
  return [];
}

let stateFileCache = null;
let factionsFileCache = null;

async function fetchJSON(file) {
  const res = await fetch(`data/${file}`, { cache: 'no-cache' });
  if (!res.ok) throw new Error(`${file} HTTP ${res.status}`);
  const text = (await res.text()).replace(/^\uFEFF/, '');
  return JSON.parse(text);
}

async function loadStateFile() {
  if (stateFileCache) return stateFileCache;
  try {
    const raw = await fetchJSON('state-relations.json');
    const relations = arr(raw && raw.relations).map(normalizeRelation).filter(Boolean);
    const extraNodes = arr(raw && raw.extraNodes).map(normalizeExtraNode).filter(Boolean);
    stateFileCache = { relations, extraNodes };
  } catch (err) {
    console.info('[山河战纪] state-relations.json 暂不可用：', err && err.message ? err.message : err);
    stateFileCache = { relations: [], extraNodes: [] };
  }
  return stateFileCache;
}

async function loadFactions(ctx) {
  const fromCtx = arr(ctx && ctx.data && ctx.data.factions);
  if (fromCtx.length) return fromCtx.map(normalizeFaction).filter(Boolean);
  if (factionsFileCache) return factionsFileCache;
  try {
    const raw = await fetchJSON('factions.json');
    factionsFileCache = arr(raw).map(normalizeFaction).filter(Boolean);
  } catch (err) {
    factionsFileCache = [];
  }
  return factionsFileCache;
}

async function loadGraphData(ctx) {
  const data = (ctx && ctx.data) || {};
  const factions = await loadFactions(ctx);
  let relations = arr(data.stateRelations).map(normalizeRelation).filter(Boolean);
  let extraRaw = arr(data.stateExtraNodes);
  if (!extraRaw.length) {
    // data.js 对 state 数据是原样传递的；这里仅在确实为空时尝试原始文件补全
    const file = await loadStateFile();
    if (!relations.length) relations = file.relations;
    if (!extraRaw.length) extraRaw = file.extraNodes;
  }
  const extras = extraRaw.map(normalizeExtraNode).filter(Boolean);
  const eras = arr(data.eras).filter((era) => era && era.id);
  return { factions, extras, relations, eras, data };
}

/* ---------------- 组装节点 / 边 ---------------- */
function buildGraph(data) {
  const nodes = [];
  const nodeMap = new Map();
  const addNode = (node) => {
    if (!node || nodeMap.has(node.id)) return;
    nodeMap.set(node.id, node);
    nodes.push(node);
  };
  data.factions.forEach(addNode);
  data.extras.forEach(addNode);

  const relations = [];
  data.relations.forEach((relation) => {
    let from = nodeMap.get(relation.from);
    let to = nodeMap.get(relation.to);
    // 端点缺失时补占位节点，保证关系不丢
    if (!from) {
      from = {
        id: relation.from,
        name: relation.from,
        symbol: symbolFor(relation.from, false),
        color: '#9C907B',
        kind: '其他',
        isFaction: false,
        startYear: relation.startYear || 0,
        endYear: relation.endYear || relation.startYear || 0,
        eraIds: [],
        family: '',
        fullName: '',
        rangeText: yearRange(relation.startYear, relation.endYear),
        note: '',
        synthetic: true,
      };
      addNode(from);
    }
    if (!to) {
      to = {
        id: relation.to,
        name: relation.to,
        symbol: symbolFor(relation.to, false),
        color: '#9C907B',
        kind: '其他',
        isFaction: false,
        startYear: relation.startYear || 0,
        endYear: relation.endYear || relation.startYear || 0,
        eraIds: [],
        family: '',
        fullName: '',
        rangeText: yearRange(relation.startYear, relation.endYear),
        note: '',
        synthetic: true,
      };
      addNode(to);
    }
    relations.push({ ...relation, fromNode: from, toNode: to });
  });

  // 同对、同类型的关系合并成一条边（线宽按关系数）
  const edgeMap = new Map();
  relations.forEach((relation) => {
    const pair = [relation.from, relation.to].sort().join('|');
    const key = `${pair}|${relation.type}`;
    let edge = edgeMap.get(key);
    if (!edge) {
      edge = {
        key,
        pair,
        type: relation.type,
        from: relation.from,
        to: relation.to,
        fromNode: relation.fromNode,
        toNode: relation.toNode,
        relations: [],
      };
      edgeMap.set(key, edge);
    }
    edge.relations.push(relation);
  });
  const edges = [...edgeMap.values()];
  const pairIndex = new Map();
  const pairTotal = new Map();
  edges.forEach((edge) => pairTotal.set(edge.pair, (pairTotal.get(edge.pair) || 0) + 1));
  const parallelSeq = new Map();
  edges.forEach((edge) => {
    const index = parallelSeq.get(edge.pair) || 0;
    parallelSeq.set(edge.pair, index + 1);
    const total = pairTotal.get(edge.pair) || 1;
    edge.parallelIndex = index;
    edge.parallelTotal = total;
    // 弯曲度用于分离同一对节点之间的多条关系线
    edge.bow = 0.24 + (index - (total - 1) / 2) * 0.1;
    edge.width = Math.min(4.6, (TYPE_STYLE[edge.type] || TYPE_FALLBACK).width + (edge.relations.length - 1) * 0.55);
    edge.degree = edge.relations.length;
  });

  // 度量
  nodes.forEach((node) => {
    node.degree = 0;
  });
  edges.forEach((edge) => {
    edge.fromNode.degree += edge.relations.length;
    edge.toNode.degree += edge.relations.length;
  });
  nodes.forEach((node) => {
    node.radius = NODE_BASE_R + Math.min(4, (node.degree || 0) * 0.45);
  });

  layoutNodes(nodes);

  const relationsByNode = new Map();
  nodes.forEach((node) => relationsByNode.set(node.id, []));
  relations.forEach((relation) => {
    relationsByNode.get(relation.from)?.push(relation);
    relationsByNode.get(relation.to)?.push(relation);
  });
  const edgesByNode = new Map();
  nodes.forEach((node) => edgesByNode.set(node.id, []));
  edges.forEach((edge) => {
    edgesByNode.get(edge.from)?.push(edge);
    edgesByNode.get(edge.to)?.push(edge);
  });

  return { nodes, nodeMap, relations, edges, relationsByNode, edgesByNode, epochs: layoutEpochs };
}

/* ============================================================
   布局：按时代分扇区、内/外双环放射排列（稳定、确定性）
   ============================================================ */
let layoutEpochs = [];

function layoutNodes(nodes) {
  const groups = EPOCHS.map((epoch, index) => ({ index, epoch, nodes: [] }));
  nodes.forEach((node) => {
    const idx = epochIndexForYear(node.startYear);
    node.epochIndex = idx;
    groups[idx].nodes.push(node);
  });
  const active = groups.filter((group) => group.nodes.length);

  if (!active.length) {
    layoutEpochs = [];
    return;
  }

  // 扇区宽度：按时段节点数按比例分配，最少 40°
  const total = active.reduce((sum, group) => sum + group.nodes.length, 0);
  let widths = active.map((group) => Math.max(40 * DEG, (Math.PI * 2 * group.nodes.length) / total));
  const sum = widths.reduce((a, b) => a + b, 0);
  if (sum > Math.PI * 2) {
    widths = widths.map((width) => (width * (Math.PI * 2)) / sum);
  } else if (sum < Math.PI * 2) {
    // 富余角度按节点数比例补给，避免小扇区拥挤
    const extra = Math.PI * 2 - sum;
    const denom = total || 1;
    widths = widths.map((width, i) => width + (extra * active[i].nodes.length) / denom);
  }

  const MIN_GAP = 17 * DEG;
  let cursor = -Math.PI / 2;
  layoutEpochs = active.map((group, groupIndex) => {
    const width = widths[groupIndex];
    const centerAngle = cursor + width / 2;
    cursor += width;
    group.centerAngle = centerAngle;
    group.startAngle = centerAngle - width / 2;
    group.width = width;
    group.hub = polar(centerAngle, R_HUB);

    const list = group.nodes
      .slice()
      .sort((a, b) => a.startYear - b.startYear || a.name.localeCompare(b.name, 'zh'));
    const pad = Math.min(width * 0.12, 5 * DEG);
    const span = Math.max(width - pad * 2, 4 * DEG);
    // 按 17° 最小角距决定每行容量与行数（最多两环），再均匀分到各行
    const maxPerRow = clamp(Math.floor(span / MIN_GAP) + 1, 1, 8);
    const rowCount = clamp(Math.ceil(list.length / maxPerRow), 1, 2);
    const base = Math.floor(list.length / rowCount);
    const extraCount = list.length % rowCount;
    let cursorIndex = 0;
    for (let row = 0; row < rowCount; row += 1) {
      const count = base + (row < extraCount ? 1 : 0);
      const rowNodes = list.slice(cursorIndex, cursorIndex + count);
      cursorIndex += count;
      const radius = R_INNER + row * (R_OUTER - R_INNER);
      rowNodes.forEach((node, i) => {
        const step = rowNodes.length > 1 ? span / (rowNodes.length - 1) : 0;
        const angle = centerAngle + (i - (rowNodes.length - 1) / 2) * step;
        const point = polar(angle, radius);
        node.x = point.x;
        node.y = point.y;
        node.angle = angle;
        node.distance = radius;
      });
    }
    group.nodes = list;
    return { ...group, hub: group.hub };
  });

  relaxNodes(nodes);
  nodes.forEach((node) => computeNodeLabel(node, nodes));
}

/** 轻量松弛：消除节点圆点重叠并避开中心「天下」印章（确定性，最多 60 轮） */
function relaxNodes(nodes) {
  const marginX = 26;
  const marginY = 28;
  const centerClear = 54;
  for (let iter = 0; iter < 60; iter += 1) {
    let moved = false;
    for (let i = 0; i < nodes.length; i += 1) {
      for (let j = i + 1; j < nodes.length; j += 1) {
        const a = nodes[i];
        const b = nodes[j];
        let dx = b.x - a.x;
        let dy = b.y - a.y;
        let dist = Math.hypot(dx, dy);
        const minDist = a.radius + b.radius + 10;
        if (dist >= minDist) continue;
        if (dist < 0.01) {
          dx = i % 2 ? 1 : -1;
          dy = 1;
          dist = Math.hypot(dx, dy);
        }
        const push = (minDist - dist) / 2 + 0.4;
        const ux = dx / dist;
        const uy = dy / dist;
        a.x -= ux * push;
        a.y -= uy * push;
        b.x += ux * push;
        b.y += uy * push;
        moved = true;
      }
    }
    nodes.forEach((node) => {
      const dx = node.x - CX;
      const dy = node.y - CY;
      const dist = Math.hypot(dx, dy) || 1;
      const need = node.radius + centerClear;
      if (dist < need) {
        node.x = CX + (dx / dist) * need;
        node.y = CY + (dy / dist) * need;
        moved = true;
      }
      const oldX = node.x;
      const oldY = node.y;
      node.x = clamp(node.x, marginX, W - marginX);
      node.y = clamp(node.y, marginY, H - marginY);
      if (oldX !== node.x || oldY !== node.y) moved = true;
    });
    if (!moved) break;
  }
}

/* ============================================================
   SVG 构建
   ============================================================ */
function edgePath(edge) {
  const a = edge.fromNode;
  const b = edge.toNode;
  const mx = (a.x + b.x) / 2;
  const my = (a.y + b.y) / 2;
  // 控制点向圆心收拢，形成「思维导图」式的内弧
  const cx = mx + (CX - mx) * edge.bow;
  const cy = my + (CY - my) * edge.bow;
  return `M${a.x.toFixed(1)} ${a.y.toFixed(1)} Q${cx.toFixed(1)} ${cy.toFixed(1)} ${b.x.toFixed(1)} ${b.y.toFixed(1)}`;
}

function nodeLabelOffset(node) {
  const dx = node.x - CX;
  const dy = node.y - CY;
  const len = Math.hypot(dx, dy) || 1;
  return { ux: dx / len, uy: dy / len, len };
}

function labelRectFor(node, candidate) {
  const width = String(node.name).length * LABEL_FS;
  let left = candidate.x;
  if (candidate.anchor === 'end') left -= width;
  else if (candidate.anchor === 'middle') left -= width / 2;
  return { left, right: left + width, top: candidate.y - LABEL_FS, bottom: candidate.y + 4 };
}

/** 为每个节点挑全名标签位置：外/内/下/上四候选，优先不出画布且不压其它节点 */
function computeNodeLabel(node, nodes) {
  const offset = nodeLabelOffset(node);
  const dist = node.radius + 8;
  const outsideAnchor = offset.ux > 0.25 ? 'start' : offset.ux < -0.25 ? 'end' : 'middle';
  const insideAnchor = offset.ux > 0.25 ? 'end' : offset.ux < -0.25 ? 'start' : 'middle';
  const candidates = [
    { x: node.x + offset.ux * dist, y: node.y + offset.uy * dist + 4, anchor: outsideAnchor },
    { x: node.x - offset.ux * dist, y: node.y - offset.uy * dist + 4, anchor: insideAnchor },
    { x: node.x, y: node.y + node.radius + 17, anchor: 'middle' },
    { x: node.x, y: node.y - node.radius - 9, anchor: 'middle' },
  ];
  const others = (nodes || []).filter((other) => other !== node);
  let best = null;
  let bestScore = Infinity;
  candidates.forEach((candidate, index) => {
    const rect = labelRectFor(node, candidate);
    if (rect.left < 3 || rect.right > W - 3 || rect.top < 3 || rect.bottom > H - 3) return;
    let overlaps = 0;
    others.forEach((other) => {
      const box = {
        left: other.x - other.radius - 2,
        right: other.x + other.radius + 2,
        top: other.y - other.radius - 2,
        bottom: other.y + other.radius + 2,
      };
      if (rectOverlap(rect, box, 1)) overlaps += 1;
    });
    const centerBox = { left: CX - 33, right: CX + 33, top: CY - 33, bottom: CY + 33 };
    if (rectOverlap(rect, centerBox, 1)) overlaps += 2;
    const score = overlaps * 10 + index * 0.01;
    if (score < bestScore) {
      bestScore = score;
      best = candidate;
    }
  });
  node.label = best || candidates[0];
}

function nodeMarkup(node) {
  const label = node.label || { x: node.x, y: node.y + node.radius + 17, anchor: 'middle' };
  // 标签坐标在布局里按画布绝对坐标计算，节点 <g> 已 translate，故此处转成局部坐标
  const labelX = (label.x - node.x).toFixed(1);
  const labelY = (label.y - node.y).toFixed(1);
  const shape = node.isFaction
    ? `<circle class="sg-node-dot" r="${node.radius}" fill="${node.color}"/>`
    : `<polygon class="sg-node-dot sg-node-dot--extra" points="0,${-node.radius - 2} ${node.radius + 2},0 0,${node.radius + 2} ${-node.radius - 2},0" fill="${node.color}"/>`;
  const symFont = node.symbol.length > 1 ? ' is-long' : '';
  return `<g class="sg-node${node.isFaction ? '' : ' sg-node--extra'}${node.synthetic ? ' is-synthetic' : ''}" data-node="${esc(
    node.id
  )}" tabindex="0" role="button" aria-label="${esc(`${node.name}，${node.kind}，${node.degree} 条关系`)}" transform="translate(${node.x.toFixed(
    1
  )} ${node.y.toFixed(1)})">
    <circle class="sg-node-halo" r="${(node.radius + 7).toFixed(1)}" fill="${node.color}"/>
    <circle class="sg-node-ring" r="${(node.radius + 5).toFixed(1)}"/>
    ${shape}
    <text class="sg-node-sym${symFont}" y="4">${esc(node.symbol)}</text>
    <text class="sg-node-full" x="${labelX}" y="${labelY}" text-anchor="${label.anchor}">${esc(node.name)}</text>
  </g>`;
}

function graphSVG(graph) {
  const rings = [R_HUB, R_INNER, R_OUTER]
    .map((radius) => `<circle class="sg-ring" cx="${CX}" cy="${CY}" r="${radius}"/>`)
    .join('');

  const spokes = layoutEpochs
    .map((group) => `<line class="sg-spoke" x1="${CX}" y1="${CY}" x2="${group.hub.x.toFixed(1)}" y2="${group.hub.y.toFixed(1)}"/>`)
    .join('');

  // 时代扇区分界（自中心向外，帮助读图）
  const dividers = layoutEpochs
    .map((group) => {
      const inner = polar(group.startAngle, 40);
      const outer = polar(group.startAngle, R_OUTER + 10);
      return `<line class="sg-divider" x1="${inner.x.toFixed(1)}" y1="${inner.y.toFixed(1)}" x2="${outer.x.toFixed(1)}" y2="${outer.y.toFixed(1)}"/>`;
    })
    .join('');

  const epochHubs = layoutEpochs
    .map((group) => {
      const label = polar(group.centerAngle, R_HUB - 18);
      return `<g class="sg-epoch" data-epoch="${esc(group.epoch.id)}">
        <circle class="sg-epoch-dot" cx="${group.hub.x.toFixed(1)}" cy="${group.hub.y.toFixed(1)}" r="5"/>
        <text class="sg-epoch-label" x="${label.x.toFixed(1)}" y="${(label.y + 4).toFixed(1)}" text-anchor="middle">${esc(
          group.epoch.name
        )}</text>
      </g>`;
    })
    .join('');

  const branches = layoutEpochs
    .map((group) =>
      group.nodes
        .map(
          (node) =>
            `<line class="sg-branch" x1="${group.hub.x.toFixed(1)}" y1="${group.hub.y.toFixed(1)}" x2="${node.x.toFixed(
              1
            )}" y2="${node.y.toFixed(1)}"/>`
        )
        .join('')
    )
    .join('');

  const edgeMarkup = graph.edges
    .map((edge) => {
      const style = TYPE_STYLE[edge.type] || TYPE_FALLBACK;
      const d = edgePath(edge);
      const dash = style.dash ? ` stroke-dasharray="${style.dash}"` : '';
      const marker = style.arrow ? ' marker-end="url(#sg-arrow)"' : '';
      const title = `${edge.fromNode.name} — ${edge.toNode.name}（${edge.type}，${edge.relations.length} 条）`;
      return `<g class="sg-edge-group" data-edge-group="${esc(edge.key)}">
        <path class="sg-edge-hit" data-edge="${esc(edge.key)}" d="${d}" fill="none"/>
        <path class="sg-edge sg-edge--${esc(edge.type)}" data-edge="${esc(edge.key)}" d="${d}" fill="none" stroke="${
        style.color
      }" stroke-width="${edge.width.toFixed(2)}"${dash}${marker}><title>${esc(title)}</title></path>
      </g>`;
    })
    .join('');

  const nodesMarkup = graph.nodes.map(nodeMarkup).join('');

  return `<svg class="sg-svg" viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMid meet" role="img" aria-label="国家关系思维导图">
    <defs>
      <marker id="sg-arrow" viewBox="0 0 10 10" refX="8.6" refY="5" markerWidth="7.2" markerHeight="7.2" orient="auto-start-reverse">
        <path d="M0 1.4 10 5 0 8.6 2.6 5Z" fill="#C94B3A"/>
      </marker>
      <radialGradient id="sg-center-glow" cx="0.5" cy="0.5" r="0.5">
        <stop offset="0" stop-color="#C9A227" stop-opacity="0.22"/>
        <stop offset="0.7" stop-color="#C9A227" stop-opacity="0.05"/>
        <stop offset="1" stop-color="#C9A227" stop-opacity="0"/>
      </radialGradient>
    </defs>
    <circle class="sg-center-glow" cx="${CX}" cy="${CY}" r="130" fill="url(#sg-center-glow)"/>
    <g class="sg-rings">${rings}</g>
    <g class="sg-dividers">${dividers}</g>
    <g class="sg-spokes">${spokes}</g>
    <g class="sg-branches">${branches}</g>
    <g class="sg-edges">${edgeMarkup}</g>
    <g class="sg-nodes">${nodesMarkup}</g>
    <g class="sg-epochs">${epochHubs}</g>
    <g class="sg-center" aria-hidden="true">
      <circle class="sg-center-disc" cx="${CX}" cy="${CY}" r="27"/>
      <circle class="sg-center-inner" cx="${CX}" cy="${CY}" r="21"/>
      <text class="sg-center-text" x="${CX}" y="${CY + 5}" text-anchor="middle">天下</text>
    </g>
  </svg>`;
}

/* ============================================================
   页面骨架
   ============================================================ */
function filterChips(defs) {
  const chips = defs
    .filter((item) => item.id !== 'all')
    .map(
      (item) =>
        `<button class="sg-chip" type="button" data-filter="${esc(item.id)}" aria-pressed="false" title="${esc(
          item.label
        )}"><i>${String(item.index || '').padStart(2, '0')}</i><span>${esc(item.label)}</span></button>`
    )
    .join('');
  return `<button class="sg-chip is-active" type="button" data-filter="all" aria-pressed="true"><i>全</i><span>全部</span></button>${chips}`;
}

function legendHTML(graph) {
  const typeItems = TYPES.map((type) => {
    const style = TYPE_STYLE[type];
    return `<span class="sg-legend-item"><i class="sg-legend-line" style="--c:${style.color};--w:${style.width}px;--dash:${
      style.dashType
    }${style.arrow ? ';--arrow:1' : ''}"></i>${esc(style.label)}</span>`;
  }).join('');
  const factionCount = graph.nodes.filter((node) => node.isFaction).length;
  const extraCount = graph.nodes.filter((node) => !node.isFaction).length;
  return `<section class="sg-legend" aria-label="图例">
    <div class="sg-legend-block">
      <span class="sg-legend-title">关系</span>
      <div class="sg-legend-items">${typeItems}</div>
    </div>
    <div class="sg-legend-block">
      <span class="sg-legend-title">节点</span>
      <div class="sg-legend-items">
        <span class="sg-legend-item"><i class="sg-legend-dot"></i>势力 ${factionCount}</span>
        <span class="sg-legend-item"><i class="sg-legend-diamond"></i>附加政权 ${extraCount}</span>
        <span class="sg-legend-item sg-legend-muted">线宽 ← 关系条数</span>
      </div>
    </div>
    <p class="sg-legend-summary">${factionCount} 势力 + ${extraCount} 附加政权 · ${graph.relations.length} 条关系 · 按时代分环</p>
  </section>`;
}

function rootHTML(graph, filterDefs) {
  return `<div class="sg-root" data-sg-root>
    <div class="sg-toolbar">
      <div class="sg-filter no-scrollbar" role="group" aria-label="按时期筛选">${filterChips(filterDefs)}</div>
      <div class="sg-tools">
        <span class="sg-zoom" aria-live="polite">1.00×</span>
        <button class="sg-tool" type="button" data-sg-action="names" aria-pressed="false" aria-label="显示全部节点名称" title="显示全部节点名称">名称</button>
        <button class="sg-tool" type="button" data-sg-action="zoom-in" aria-label="放大">＋</button>
        <button class="sg-tool" type="button" data-sg-action="zoom-out" aria-label="缩小">－</button>
        <button class="sg-tool" type="button" data-sg-action="reset" aria-label="复位视图">↺</button>
      </div>
    </div>
    <div class="sg-stage" id="sgStage" tabindex="0" aria-label="国家关系图画布：拖动平移，滚轮或双指缩放，Tab 选择节点后回车查看详情">
      <div class="sg-canvas" id="sgCanvas">${graphSVG(graph)}</div>
      <p class="sg-stage-hint">拖动平移 · 滚轮/双指缩放 · 点节点看详情 · 点连线看说明</p>
    </div>
    ${legendHTML(graph)}
    <p class="sg-foot">节点按时代分环排布（${layoutEpochs.map((group) => group.epoch.name).join(' · ')}）；关系据 state-relations.json。初始缩放只显示关键节点，放大到 1.2× 以上显示全部名称；布局为阅读性示意，可拖动与缩放。</p>
  </div>`;
}

function emptyHTML() {
  return `<div class="sg-root sg-root--empty">
    ${emptyStateHTML({
      title: '国家关系数据准备中',
      desc: 'state-relations.json 暂不可用或内容为空。名将关系图层、时间轴与势力页仍可正常浏览。',
    })}
  </div>`;
}

function loadingHTML() {
  return `<div class="sg-root sg-root--loading">
    <div class="sg-loading">${skeletonHTML(3)}<p class="sg-loading-text">正在整理国家关系…</p></div>
  </div>`;
}

/* ============================================================
   实例状态
   ============================================================ */
let live = null;
let renderSeq = 0;

function ensurePanel() {
  let panel = document.getElementById('sgPanel');
  let scrim = document.getElementById('sgScrim');
  if (panel) panel.remove();
  if (scrim) scrim.remove();
  scrim = document.createElement('div');
  scrim.id = 'sgScrim';
  scrim.className = 'sg-scrim';
  scrim.hidden = true;
  panel = document.createElement('div');
  panel.id = 'sgPanel';
  panel.className = 'sg-panel';
  panel.hidden = true;
  panel.setAttribute('role', 'dialog');
  panel.setAttribute('aria-modal', 'false');
  panel.setAttribute('aria-label', '国家关系详情');
  panel.tabIndex = -1;
  document.body.appendChild(scrim);
  document.body.appendChild(panel);
  return { panel, scrim };
}

/* ---------------- 视图变换 ---------------- */
function stageSize(state) {
  return { w: state.stage.clientWidth, h: state.stage.clientHeight };
}

function applyTransform(state) {
  const t = state.transform;
  state.canvas.style.transform = `translate3d(${t.x.toFixed(2)}px, ${t.y.toFixed(2)}px, 0) scale(${t.k.toFixed(4)})`;
  if (state.zoomEl) state.zoomEl.textContent = `${t.k.toFixed(2)}×`;
  scheduleLabelUpdate(state);
}

function fitView(state) {
  const { w, h } = stageSize(state);
  if (!w || !h) return;
  const k = Math.min(w / W, h / H) * 0.97;
  state.transform = { k, x: (w - W * k) / 2, y: (h - H * k) / 2 };
  state.fitted = true;
  clampTransform(state);
  applyTransform(state);
}

function clampTransform(state) {
  const { w, h } = stageSize(state);
  const t = state.transform;
  const cw = W * t.k;
  const ch = H * t.k;
  const pad = 24;
  t.x = cw <= w ? (w - cw) / 2 : Math.min(pad, Math.max(w - cw - pad, t.x));
  t.y = ch <= h ? (h - ch) / 2 : Math.min(pad, Math.max(h - ch - pad, t.y));
}

function zoomAt(state, fx, fy, factor) {
  const t = state.transform;
  const k = clamp(t.k * factor, 0.45, 3.2);
  if (Math.abs(k - t.k) < 0.0001) return;
  const ax = (fx - t.x) / t.k;
  const ay = (fy - t.y) / t.k;
  t.k = k;
  t.x = fx - ax * k;
  t.y = fy - ay * k;
  clampTransform(state);
  applyTransform(state);
}

/* ---------------- 选中 / 高亮 / 标签 / 筛选 ---------------- */
function relatedNodeIds(state, nodeId) {
  const ids = new Set();
  if (!nodeId) return ids;
  (state.edgesByNode.get(nodeId) || []).forEach((edge) => {
    ids.add(edge.fromNode.id);
    ids.add(edge.toNode.id);
  });
  ids.delete(nodeId);
  return ids;
}

function applySelection(state) {
  const selectedId = state.selectedId;
  const related = relatedNodeIds(state, selectedId);
  const incidentEdges = selectedId ? new Set((state.edgesByNode.get(selectedId) || []).map((edge) => edge.key)) : null;
  state.svg.querySelectorAll('.sg-node').forEach((el) => {
    const id = el.dataset.node;
    const isSelected = !!selectedId && id === selectedId;
    const isRelated = !!selectedId && related.has(id);
    el.classList.toggle('is-selected', isSelected);
    el.classList.toggle('is-related', isRelated);
    el.classList.toggle('is-faded', !!selectedId && !isSelected && !isRelated);
  });
  state.svg.querySelectorAll('.sg-edge-group').forEach((group) => {
    const key = group.dataset.edgeGroup;
    const on = !!selectedId && incidentEdges.has(key);
    group.classList.toggle('is-on', on);
    group.classList.toggle('is-faded', !!selectedId && !on);
  });
  updateFullLabels(state);
}

const rectOverlap = (a, b, pad = 2) =>
  a.left - pad < b.right && a.right + pad > b.left && a.top - pad < b.bottom && a.bottom + pad > b.top;

function fullLabelRect(node, text) {
  const label = node.label || { x: node.x, y: node.y + node.radius + 17, anchor: 'middle' };
  const width = String(text == null ? node.name : text).length * LABEL_FS;
  let left = label.x;
  if (label.anchor === 'end') left -= width;
  else if (label.anchor === 'middle') left -= width / 2;
  return { left, right: left + width, top: label.y - LABEL_FS, bottom: label.y + 4 };
}

function updateFullLabels(state) {
  if (!state || !state.svg) return;
  const k = state.transform.k;
  const selectedId = state.selectedId;
  const related = relatedNodeIds(state, selectedId);
  // 低缩放（约 0.8×）只显示一级关键节点；放大后才逐步全显，避免标签叠字
  const showAll = state.showAllNames || k >= 1.18;
  const ranked = state.nodes
    .map((node) => ({
      node,
      priority:
        (node.id === selectedId ? 1e9 : 0) +
        (related.has(node.id) ? 1e8 : 0) +
        (node.isFaction ? 200 : 0) +
        node.degree * 100,
    }))
    .sort((a, b) => b.priority - a.priority);
  let limit;
  if (showAll) limit = ranked.length;
  else if (selectedId) limit = Math.max(14, related.size + 1);
  else if (k >= 1.0) limit = 18;
  else limit = 10;
  const candidates = ranked.slice(0, Math.min(limit, ranked.length));
  const allMode = showAll;

  const placed = state.nodes.map((node) => ({
    left: node.x - node.radius,
    right: node.x + node.radius,
    top: node.y - node.radius,
    bottom: node.y + node.radius,
  }));
  const visible = new Set();
  if (allMode) {
    // 放大到 1.2× 以上或手动开启「名称」：全部显示（允许少量叠字，便于逐点读取）
    state.nodes.forEach((node) => visible.add(node.id));
  } else {
    candidates.forEach(({ node }) => {
      const rect = fullLabelRect(node, node.name);
      if (placed.some((other) => rectOverlap(rect, other))) return;
      placed.push(rect);
      visible.add(node.id);
    });
  }
  state.svg.querySelectorAll('.sg-node').forEach((el) => {
    el.classList.toggle('is-labeled', visible.has(el.dataset.node));
  });
}

function scheduleLabelUpdate(state) {
  if (!state) return;
  if (state.labelRaf) cancelAnimationFrame(state.labelRaf);
  state.labelRaf = requestAnimationFrame(() => {
    if (!state) return;
    state.labelRaf = 0;
    updateFullLabels(state);
  });
}

function applyEraFilter(state, filterId) {
  state.filterId = filterId;
  const chip = state.filterDefs.find((item) => item.id === filterId);
  const isAll = !chip || filterId === 'all';
  const visibleEdges = new Set();
  state.edges.forEach((edge) => {
    const visible =
      isAll ||
      edge.relations.some((relation) => hasOverlap(relation.startYear, relation.endYear, chip.startYear, chip.endYear));
    if (visible) visibleEdges.add(edge.key);
    const group = state.svg.querySelector(`[data-edge-group="${CSS.escape(edge.key)}"]`);
    if (group) group.classList.toggle('is-dim', !visible);
  });
  const activeNodes = new Set();
  state.edges.forEach((edge) => {
    if (!visibleEdges.has(edge.key)) return;
    activeNodes.add(edge.fromNode.id);
    activeNodes.add(edge.toNode.id);
  });
  state.svg.querySelectorAll('.sg-node').forEach((el) => {
    const node = state.nodeMap.get(el.dataset.node);
    const spanVisible =
      node &&
      (isAll || hasOverlap(node.startYear, node.endYear, chip.startYear, chip.endYear) || activeNodes.has(node.id));
    el.classList.toggle('is-dim', !!node && !isAll && !spanVisible);
  });
  state.root.querySelectorAll('[data-filter]').forEach((btn) => {
    const on = btn.dataset.filter === filterId;
    btn.classList.toggle('is-active', on);
    btn.setAttribute('aria-pressed', on ? 'true' : 'false');
  });
  updateFullLabels(state);
}

/* ---------------- 详情面板 ---------------- */
function typeChip(type) {
  const style = TYPE_STYLE[type] || TYPE_FALLBACK;
  return `<span class="sg-type-chip" style="--c:${style.color}">${esc(type)}</span>`;
}

function nodeMeta(state, node) {
  if (node.isFaction) {
    return [node.fullName, node.family ? `家族 · ${node.family}` : '', node.rangeText].filter(Boolean).join('　');
  }
  return [node.kind, node.rangeText].filter(Boolean).join('　');
}

function panelHTML(state, node) {
  const relations = (state.relationsByNode.get(node.id) || [])
    .slice()
    .sort((a, b) => (a.startYear || 0) - (b.startYear || 0));
  const battleIds = [];
  relations.forEach((relation) => relation.battles.forEach((id) => {
    if (!battleIds.includes(id)) battleIds.push(id);
  }));
  const battles = battleIds
    .slice(0, 8)
    .map((id) => {
      const battle = state.data.byId && typeof state.data.byId.get === 'function' ? state.data.byId.get(id) : null;
      const name = battle ? battle.name : id;
      const year = battle && battle.yearText ? `<i>${esc(battle.yearText)}</i>` : '';
      return `<a class="sg-battle" href="#/battle/${encodeURIComponent(id)}">${esc(name)}${year}</a>`;
    })
    .join('');
  const relationRows = relations
    .map((relation) => {
      const other = relation.from === node.id ? relation.toNode : relation.fromNode;
      const years = yearRange(relation.startYear, relation.endYear);
      return `<li class="sg-rel-row">
        ${typeChip(relation.type)}
        <button class="sg-rel-other" type="button" data-goto-node="${esc(other.id)}">${esc(other.name)}</button>
        ${years ? `<span class="sg-rel-year">${esc(years)}</span>` : ''}
        <p class="sg-rel-note">${esc(relation.note || '暂无说明')}</p>
      </li>`;
    })
    .join('');
  const sources = [];
  relations.forEach((relation) => relation.sources.forEach((source) => {
    if (!sources.includes(source)) sources.push(source);
  }));
  const sourceText = sources.slice(0, 5).join(' · ');
  return `<button class="sg-panel-close" type="button" data-panel-close aria-label="关闭详情">${icon('close')}</button>
    <div class="sg-panel-head">
      <span class="sg-panel-seal" aria-hidden="true">${esc(node.symbol || str(node.name).slice(0, 1))}</span>
      <div class="sg-panel-main">
        <h2 class="sg-panel-name">${esc(node.name)}</h2>
        <p class="sg-panel-kind">${esc(node.isFaction ? '势力' : node.kind)}${node.synthetic ? ' · 占位节点' : ''}</p>
        <p class="sg-panel-meta">${esc(nodeMeta(state, node))}</p>
      </div>
    </div>
    ${
      node.note
        ? `<p class="sg-panel-note">${esc(node.note)}</p>`
        : ''
    }
    <div class="sg-panel-stats">
      <span>关系 <b>${relations.length}</b> 条</span>
      <span>关联战役 <b>${battleIds.length}</b> 场</span>
      <span>关系方 <b>${new Set(relations.map((relation) => (relation.from === node.id ? relation.to : relation.from))).size}</b></span>
    </div>
    <div class="sg-panel-section">
      <h3 class="sg-panel-sub">相关关系</h3>
      <ul class="sg-rel-list">${relationRows || '<li class="sg-rel-empty">暂无关系记载</li>'}</ul>
    </div>
    ${battles ? `<div class="sg-panel-section"><h3 class="sg-panel-sub">关联战役</h3><div class="sg-battles">${battles}</div></div>` : ''}
    ${sourceText ? `<p class="sg-panel-sources">据 ${esc(sourceText)}</p>` : ''}`;
}

function openPanel(state, nodeId) {
  const node = state.nodeMap.get(nodeId);
  if (!node) return;
  const panel = state.panel;
  state.selectedId = nodeId;
  panel.innerHTML = panelHTML(state, node);
  panel.hidden = false;
  if (state.scrim) state.scrim.hidden = false;
  requestAnimationFrame(() => {
    if (!live || live !== state) return;
    panel.classList.add('is-open');
    if (state.scrim) state.scrim.classList.add('is-open');
  });
  state.panelReturnFocus = document.activeElement;
  const closeBtn = panel.querySelector('[data-panel-close]');
  try {
    (closeBtn || panel).focus({ preventScroll: true });
  } catch (err) {
    /* ignore */
  }
  if (state.panelDragCleanup) {
    try {
      state.panelDragCleanup();
    } catch (err) {
      /* ignore */
    }
  }
  state.panelDragCleanup = initDrawerSpring(panel, { onClose: () => closePanel(state), handle: panel.querySelector('.sg-panel-head') });
  applySelection(state);
}

function closePanel(state) {
  if (!state || !state.panel) return;
  state.selectedId = null;
  if (state.panelDragCleanup) {
    try {
      state.panelDragCleanup();
    } catch (err) {
      /* ignore */
    }
    state.panelDragCleanup = null;
  }
  const panel = state.panel;
  panel.classList.remove('is-open');
  if (state.scrim) {
    state.scrim.classList.remove('is-open');
    state.scrim.hidden = true;
  }
  if (reducedMotion()) panel.hidden = true;
  else {
    state.timers.push(
      window.setTimeout(() => {
        if (panel && !panel.classList.contains('is-open')) panel.hidden = true;
      }, 220)
    );
  }
  try {
    if (state.panelReturnFocus && state.panelReturnFocus.focus) state.panelReturnFocus.focus({ preventScroll: true });
  } catch (err) {
    /* ignore */
  }
  applySelection(state);
}

/* ---------------- 边说明 toast ---------------- */
function showEdgeNote(state, edgeKey) {
  const edge = state.edgeMap.get(edgeKey);
  if (!edge) return;
  const relations = edge.relations;
  const years = relations
    .map((relation) => yearRange(relation.startYear, relation.endYear))
    .filter(Boolean)
    .join('；');
  const notes = relations.map((relation) => relation.note).filter(Boolean).join(' ');
  const text = `${edge.fromNode.name} — ${edge.toNode.name}｜${edge.type}${years ? `｜${years}` : ''}${
    notes ? `｜${notes}` : ''
  }`;
  toast(text, 3600);
  if (state.toastHighlightEdge) {
    const previous = state.svg.querySelector('.sg-edge-group.is-flash');
    if (previous) previous.classList.remove('is-flash');
  }
  const group = state.svg.querySelector(`[data-edge-group="${CSS.escape(edge.key)}"]`);
  if (group) {
    group.classList.add('is-flash');
    state.toastHighlightEdge = group;
    state.timers.push(
      window.setTimeout(() => {
        group.classList.remove('is-flash');
        if (state.toastHighlightEdge === group) state.toastHighlightEdge = null;
      }, 1600)
    );
  }
}

/* ---------------- 绑定交互 ---------------- */
function bind(state) {
  const stage = state.stage;
  const pointers = new Map();
  let drag = null;
  let pinch = null;
  let moved = 0;
  let downEdge = null;
  let downNode = null;

  const local = (event) => {
    const rect = stage.getBoundingClientRect();
    return { x: event.clientX - rect.left, y: event.clientY - rect.top };
  };

  const onPointerDown = (event) => {
    if (event.target.closest('.sg-tool')) return;
    stage.setPointerCapture(event.pointerId);
    pointers.set(event.pointerId, { x: event.clientX, y: event.clientY });
    moved = 0;
    downEdge = null;
    downNode = null;
    if (pointers.size === 1) {
      drag = { x: event.clientX, y: event.clientY, tx: state.transform.x, ty: state.transform.y };
      const nodeEl = event.target.closest('[data-node]');
      const edgeEl = event.target.closest('[data-edge]');
      if (nodeEl) downNode = nodeEl.dataset.node;
      else if (edgeEl) downEdge = edgeEl.dataset.edge;
    }
    if (pointers.size === 2) {
      drag = null;
      const pts = [...pointers.values()];
      pinch = {
        dist: Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y) || 1,
        mid: local(event),
        k: state.transform.k,
        x: state.transform.x,
        y: state.transform.y,
      };
      downNode = null;
      downEdge = null;
    }
    stage.classList.add('is-dragging');
    event.preventDefault();
  };

  const onPointerMove = (event) => {
    if (!pointers.has(event.pointerId)) return;
    pointers.set(event.pointerId, { x: event.clientX, y: event.clientY });
    if (pointers.size >= 2 && pinch) {
      const pts = [...pointers.values()];
      const dist = Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y) || 1;
      const mid = local(event);
      const k = clamp(pinch.k * (dist / pinch.dist), 0.45, 3.2);
      const ax = (pinch.mid.x - pinch.x) / pinch.k;
      const ay = (pinch.mid.y - pinch.y) / pinch.k;
      state.transform = { k, x: mid.x - ax * k, y: mid.y - ay * k };
      clampTransform(state);
      applyTransform(state);
      moved = 99;
      return;
    }
    if (!drag) return;
    moved = Math.max(moved, Math.abs(event.clientX - drag.x) + Math.abs(event.clientY - drag.y));
    state.transform.x = drag.tx + (event.clientX - drag.x);
    state.transform.y = drag.ty + (event.clientY - drag.y);
    clampTransform(state);
    applyTransform(state);
  };

  const onPointerUp = (event) => {
    pointers.delete(event.pointerId);
    if (pointers.size < 2) pinch = null;
    if (pointers.size === 0) {
      stage.classList.remove('is-dragging');
      if (moved < 5) {
        if (downNode) {
          openPanel(state, downNode);
        } else if (downEdge) {
          showEdgeNote(state, downEdge);
        }
      }
      drag = null;
      downNode = null;
      downEdge = null;
      scheduleLabelUpdate(state);
    }
  };

  const onWheel = (event) => {
    event.preventDefault();
    const point = local(event);
    zoomAt(state, point.x, point.y, Math.exp(-event.deltaY * 0.0016));
  };

  const onKeyDown = (event) => {
    if (event.key !== 'Enter' && event.key !== ' ') return;
    const nodeEl = event.target.closest && event.target.closest('[data-node]');
    if (!nodeEl) return;
    event.preventDefault();
    openPanel(state, nodeEl.dataset.node);
  };

  const onClick = (event) => {
    const actionBtn = event.target.closest('[data-sg-action]');
    if (actionBtn) {
      const action = actionBtn.dataset.sgAction;
      const { w, h } = stageSize(state);
      if (action === 'zoom-in') zoomAt(state, w / 2, h / 2, 1.35);
      else if (action === 'zoom-out') zoomAt(state, w / 2, h / 2, 1 / 1.35);
      else if (action === 'reset') {
        fitView(state);
        if (state.nameToggle) {
          state.showAllNames = false;
          state.nameToggle.setAttribute('aria-pressed', 'false');
          state.nameToggle.classList.remove('is-on');
          updateFullLabels(state);
        }
      } else if (action === 'names') {
        state.showAllNames = !state.showAllNames;
        actionBtn.setAttribute('aria-pressed', state.showAllNames ? 'true' : 'false');
        actionBtn.classList.toggle('is-on', state.showAllNames);
        updateFullLabels(state);
      }
      return;
    }
    const chip = event.target.closest('[data-filter]');
    if (chip) applyEraFilter(state, chip.dataset.filter);
  };

  const onPanelClick = (event) => {
    if (event.target.closest('[data-panel-close]')) {
      closePanel(state);
      return;
    }
    const goto = event.target.closest('[data-goto-node]');
    if (goto) openPanel(state, goto.dataset.gotoNode);
  };

  const onScrimClick = () => closePanel(state);

  const onDocKey = (event) => {
    if (event.key === 'Escape' && state.selectedId) closePanel(state);
  };

  const onResize = () => {
    if (!state) return;
    clampTransform(state);
    applyTransform(state);
  };

  // 宿主从隐藏切到可见（宽高 0 → 非 0）时补一次 fit，避免组件在隐藏容器里初始化
  let lastW = stage.clientWidth;
  let lastH = stage.clientHeight;
  let resizeObserver = null;
  if (typeof ResizeObserver !== 'undefined') {
    resizeObserver = new ResizeObserver(() => {
      if (!state) return;
      const w = stage.clientWidth;
      const h = stage.clientHeight;
      if (!w || !h) return;
      if (!state.fitted || lastW === 0 || lastH === 0) fitView(state);
      else {
        clampTransform(state);
        applyTransform(state);
      }
      lastW = w;
      lastH = h;
    });
    resizeObserver.observe(stage);
    state.resizeObserver = resizeObserver;
  }

  stage.addEventListener('pointerdown', onPointerDown);
  stage.addEventListener('pointermove', onPointerMove);
  stage.addEventListener('pointerup', onPointerUp);
  stage.addEventListener('pointercancel', onPointerUp);
  stage.addEventListener('wheel', onWheel, { passive: false });
  stage.addEventListener('keydown', onKeyDown);
  state.root.addEventListener('click', onClick);
  state.panel.addEventListener('click', onPanelClick);
  if (state.scrim) state.scrim.addEventListener('click', onScrimClick);
  document.addEventListener('keydown', onDocKey);
  window.addEventListener('resize', onResize);
  state.listeners.push(
    [stage, 'pointerdown', onPointerDown],
    [stage, 'pointermove', onPointerMove],
    [stage, 'pointerup', onPointerUp],
    [stage, 'pointercancel', onPointerUp],
    [stage, 'wheel', onWheel, { passive: false }],
    [stage, 'keydown', onKeyDown],
    [state.root, 'click', onClick],
    [state.panel, 'click', onPanelClick],
    [state.scrim, 'click', onScrimClick],
    [document, 'keydown', onDocKey],
    [window, 'resize', onResize]
  );
}

/* ============================================================
   数据加载后的挂载
   ============================================================ */
function mount(host, ctx, opts, data) {
  const graph = buildGraph(data);
  if (!graph.nodes.length || !graph.edges.length) {
    host.innerHTML = emptyHTML();
    return;
  }
  const panelRefs = ensurePanel();
  const filterDefs = buildFilterDefs(data.eras, data.relations);
  const root = document.createElement('div');
  root.innerHTML = rootHTML(graph, filterDefs);
  const shell = root.firstElementChild;
  host.innerHTML = '';
  host.appendChild(shell);

  const state = {
    host,
    root: shell,
    ctx,
    opts: opts || {},
    data: data.data || {},
    graph,
    nodes: graph.nodes,
    edges: graph.edges,
    nodeMap: graph.nodeMap,
    relationsByNode: graph.relationsByNode,
    edgesByNode: graph.edgesByNode,
    edgeMap: new Map(graph.edges.map((edge) => [edge.key, edge])),
    stage: shell.querySelector('#sgStage'),
    canvas: shell.querySelector('#sgCanvas'),
    svg: shell.querySelector('.sg-svg'),
    zoomEl: shell.querySelector('.sg-zoom'),
    nameToggle: shell.querySelector('[data-sg-action="names"]'),
    panel: panelRefs.panel,
    scrim: panelRefs.scrim,
    panelDragCleanup: null,
    selectedId: null,
    filterId: 'all',
    filterDefs,
    transform: { x: 0, y: 0, k: 1 },
    showAllNames: false,
    labelRaf: 0,
    timers: [],
    listeners: [],
    resizeObserver: null,
    fitted: false,
  };
  live = state;

  bind(state);
  fitView(state);
  applySelection(state);
  if (opts && opts.initialEra) applyEraFilter(state, str(opts.initialEra));
}

function buildFilterDefs(eras, relations) {
  if (eras.length >= 2) {
    const used = eras.filter((era) =>
      relations.some((relation) => hasOverlap(relation.startYear, relation.endYear, era.startYear, era.endYear))
    );
    if (used.length) {
      return [
        { id: 'all', label: '全部', startYear: null, endYear: null },
        ...used.map((era) => ({
          id: str(era.id),
          label: str(era.short || era.name),
          index: num(era.index, 0),
          startYear: num(era.startYear, null),
          endYear: num(era.endYear, null),
        })),
      ];
    }
  }
  return [
    { id: 'all', label: '全部', startYear: null, endYear: null },
    ...EPOCHS.map((epoch, index) => ({
      id: epoch.id,
      label: epoch.name,
      index: index + 1,
      startYear: epoch.startYear,
      endYear: epoch.endYear,
    })),
  ];
}

/* ============================================================
   对外接口
   ============================================================ */
export function renderStateGraph(host, ctx, opts = {}) {
  disposeStateGraph();
  if (!host) return;
  const token = ++renderSeq;
  host.innerHTML = loadingHTML();
  Promise.all([loadGraphData(ctx), stylesReady])
    .then(([data]) => {
      if (token !== renderSeq || !host.isConnected) return;
      if (!data.relations.length) {
        host.innerHTML = emptyHTML();
        return;
      }
      mount(host, ctx, opts, data);
    })
    .catch((err) => {
      if (token !== renderSeq) return;
      console.error('[山河战纪] 国家关系图渲染失败', err);
      host.innerHTML = emptyHTML();
    });
}

export function disposeStateGraph() {
  renderSeq += 1;
  const state = live;
  live = null;
  if (state) {
    if (state.labelRaf) cancelAnimationFrame(state.labelRaf);
    if (state.timers && state.timers.length) state.timers.forEach((id) => clearTimeout(id));
    if (state.listeners && state.listeners.length) {
      state.listeners.forEach(([target, type, handler, options]) => {
        try {
          target.removeEventListener(type, handler, options);
        } catch (err) {
          /* ignore */
        }
      });
      state.listeners = [];
    }
    if (state.panelDragCleanup) {
      try {
        state.panelDragCleanup();
      } catch (err) {
        /* ignore */
      }
      state.panelDragCleanup = null;
    }
    if (state.resizeObserver) {
      try {
        state.resizeObserver.disconnect();
      } catch (err) {
        /* ignore */
      }
      state.resizeObserver = null;
    }
    if (state.panel) {
      try {
        state.panel.remove();
      } catch (err) {
        /* ignore */
      }
    }
    if (state.scrim) {
      try {
        state.scrim.remove();
      } catch (err) {
        /* ignore */
      }
    }
    state.panel = null;
    state.scrim = null;
    state.svg = null;
    state.canvas = null;
    state.root = null;
    state.host = null;
  }
}
