/* ============================================================
   clan.js — 3.0 家族谱：世代谱 / 父子缩进 / 联姻 / 图例 / 空态
   接口（固定，勿改名）：
     export function renderClan(root, ctx, clanId)
     export function disposeClan()
   数据：优先 ctx.data.clans / clansById，缺失时 fetch('data/clans.json') 兜底。
   路由 #/clan/<id> 由 app.js 接线；本模块自注入 clan.css。
   零依赖、无外链；减弱动效下无动画。
   ============================================================ */

import { esc, icon, emptyStateHTML } from './ui.js';
import { navigate, navigateBack, getPrevRoute } from './router.js';
import { revealStagger, skeletonHTML } from './motion.js';

const CSS_HREF = 'css/clan.css';
const CN_NUM = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];

/* ---------------- 样式：模块加载即注入（index.html 未加 link 也可用） ---------------- */
let stylesPromise = null;
function ensureStyles() {
  try {
    const links = document.querySelectorAll('link[rel="stylesheet"]');
    for (const link of links) {
      const href = link.getAttribute('href') || '';
      if (href.includes('clan.css')) return Promise.resolve();
    }
    if (stylesPromise) return stylesPromise;
    stylesPromise = new Promise((resolve) => {
      const el = document.createElement('link');
      el.rel = 'stylesheet';
      el.href = CSS_HREF;
      el.dataset.clanCss = '1';
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
const str = (v) => (v == null ? '' : String(v));
const arr = (v) => (Array.isArray(v) ? v : v == null || v === '' ? [] : [v]);
const clamp = (v, min, max) => (v < min ? min : v > max ? max : v);

function normalizeClanId(value) {
  if (value && typeof value === 'object') {
    const params = value.params || {};
    return str(params.id != null ? params.id : value.clanId != null ? value.clanId : value.id).trim();
  }
  return str(value).trim();
}

function cnNum(n) {
  const num = Number(n);
  if (!Number.isFinite(num)) return str(n);
  const i = Math.round(num);
  if (i >= 0 && i <= 10) return CN_NUM[i];
  return String(num);
}

function fmtYearText(raw) {
  const text = str(raw).trim();
  if (!text) return '';
  const num = Number(text);
  if (!Number.isFinite(num)) return text;
  if (num < 0) return `前 ${Math.abs(num)} 年`;
  return `${num} 年`;
}

const generalHref = (id) => `#/generals?g=${encodeURIComponent(str(id))}`;
const battleHref = (id) => `#/battle/${encodeURIComponent(str(id))}`;
const factionHref = (id) => `#/factions/${encodeURIComponent(str(id))}`;

/* ============================================================
   数据层：规范化 / 读取
   ============================================================ */

function normalizeMember(raw) {
  if (raw == null) return null;
  if (typeof raw === 'string') {
    const name = raw.trim();
    return name ? { name, role: '', generalId: '', note: '', parent: '', battleIds: [] } : null;
  }
  if (typeof raw !== 'object') return null;
  const name = str(raw.name).trim();
  if (!name) return null;
  const battleIds = arr(raw.battleIds != null ? raw.battleIds : raw.battles != null ? raw.battles : raw.keyBattles)
    .map((id) => str(id).trim())
    .filter(Boolean);
  return {
    name,
    role: str(raw.role != null ? raw.role : raw.title).trim(),
    generalId: str(raw.generalId).trim(),
    note: str(raw.note != null ? raw.note : raw.desc).trim(),
    parent: str(raw.parent).trim(),
    battleIds,
  };
}

function normalizeGeneration(raw, index) {
  if (!raw || typeof raw !== 'object') return null;
  const members = arr(raw.members).map(normalizeMember).filter(Boolean);
  const genNum = Number(raw.gen);
  return {
    gen: Number.isFinite(genNum) ? genNum : index + 1,
    title: str(raw.title).trim(),
    members,
  };
}

function normalizeMarriage(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const from = str(raw.from).trim();
  const to = str(raw.to).trim();
  if (!from && !to) return null;
  return {
    from,
    to,
    member: str(raw.member != null ? raw.member : raw.person).trim(),
    yearText: str(raw.year).trim(),
    note: str(raw.note).trim(),
    factionIds: arr(raw.factionIds).map((id) => str(id).trim()).filter(Boolean),
  };
}

function normalizeClan(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const id = str(raw.id).trim();
  const name = str(raw.name).trim();
  if (!id || !name) return null;
  const generations = arr(raw.generations)
    .map(normalizeGeneration)
    .filter(Boolean)
    .filter((g) => g.members.length)
    .sort((a, b) => a.gen - b.gen);
  const marriages = arr(raw.marriages).map(normalizeMarriage).filter(Boolean);
  return {
    id,
    name,
    factionId: str(raw.factionId).trim(),
    note: str(raw.note != null ? raw.note : raw.desc).trim(),
    generations,
    marriages,
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
    if (Array.isArray(raw.clans)) items = raw.clans;
    else if (Array.isArray(raw.list)) items = raw.list;
    else if (Array.isArray(raw.items)) items = raw.items;
    else items = Object.values(raw);
  }
  if (!items) return null;
  const list = items.map(normalizeClan).filter(Boolean);
  return list.length ? list : null;
}

function pickClansFromCtx(ctx) {
  const data = ctx && ctx.data;
  if (!data || typeof data !== 'object') return null;
  const candidates = [data.clans, data.clanList, data.clansById];
  for (const candidate of candidates) {
    const list = normalizeList(candidate);
    if (list && list.length) return list;
  }
  return null;
}

let fetchCache = null;

/** 原始 clans.json：字段最全（成员 battleIds 等）。空结果不缓存为“已尝试”，下次可重试。 */
async function loadRawClans() {
  if (fetchCache && fetchCache.length) return fetchCache;
  try {
    const res = await fetch('data/clans.json', { cache: 'no-cache' });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const text = (await res.text()).replace(/^\uFEFF/, '');
    const list = normalizeList(JSON.parse(text));
    fetchCache = list || [];
    if (!fetchCache.length) console.info('[山河战纪] clans.json 为空或格式不符');
    return fetchCache;
  } catch (err) {
    console.info('[山河战纪] clans.json 暂不可用：', err && err.message ? err.message : err);
    return [];
  }
}

function hasBattleIds(clans) {
  return clans.some((clan) =>
    clan.generations.some((gen) => gen.members.some((member) => member.battleIds && member.battleIds.length))
  );
}

/**
 * 数据来源：data.js 的 ctx.data.clans 可能裁掉成员 battleIds（历代版本不同），
 * 此时以原始 clans.json 为准补全；原始数据不可用时退回 ctx。
 */
async function loadClans(ctx) {
  const fromCtx = pickClansFromCtx(ctx);
  if (fromCtx && hasBattleIds(fromCtx)) return fromCtx;
  const raw = await loadRawClans();
  if (raw.length) return raw;
  return fromCtx || [];
}

/* ---------------- 上下文关联（势力 / 战役名） ---------------- */
function factionOf(ctx, id) {
  try {
    const map = ctx && ctx.data && ctx.data.factionsById;
    const faction = map && typeof map.get === 'function' ? map.get(id) : null;
    return faction || null;
  } catch (err) {
    return null;
  }
}

function factionName(ctx, id) {
  const faction = factionOf(ctx, id);
  return faction ? str(faction.name) : '';
}

function battleOf(ctx, id) {
  try {
    const map = ctx && ctx.data && ctx.data.byId;
    const battle = map && typeof map.get === 'function' ? map.get(id) : null;
    return battle || null;
  } catch (err) {
    return null;
  }
}

/* ============================================================
   世代 / 父子关系
   ============================================================ */

function countMembers(clan) {
  return clan.generations.reduce((sum, gen) => sum + gen.members.length, 0);
}

function countGenerals(clan) {
  return clan.generations.reduce((sum, gen) => sum + gen.members.filter((m) => m.generalId).length, 0);
}

/** 依据 member.parent（父名）计算缩进层级，最多 3 层，防环 */
function buildDepthMap(generations) {
  const byName = new Map();
  generations.forEach((gen) => {
    gen.members.forEach((member) => {
      if (member.name && !byName.has(member.name)) byName.set(member.name, member);
    });
  });
  const depth = new Map();
  const resolve = (name, seen) => {
    if (depth.has(name)) return depth.get(name);
    const member = byName.get(name);
    if (!member || !member.parent || seen.has(name)) {
      depth.set(name, 0);
      return 0;
    }
    seen.add(name);
    const parentDepth = byName.has(member.parent) ? resolve(member.parent, seen) : 0;
    const value = clamp(parentDepth + 1, 0, 3);
    depth.set(name, value);
    return value;
  };
  generations.forEach((gen) => gen.members.forEach((member) => resolve(member.name, new Set())));
  return depth;
}

/* ============================================================
   页面模板
   ============================================================ */

function headHTML({ title, sub = '', factionId = '' }) {
  return `<header class="page-head">
    <button class="icon-btn" type="button" data-action="back" aria-label="返回">${icon('back')}</button>
    <div class="head-title">${esc(title)}${
    sub ? `<span class="head-sub">${esc(sub)}</span>` : ''
  }</div>
    <div class="head-actions">${
      factionId
        ? `<a class="icon-btn" href="${factionHref(factionId)}" aria-label="前往所属势力">${icon('compass')}</a>`
        : ''
    }</div>
  </header>`;
}

function heroHTML(ctx, clan) {
  const facName = factionName(ctx, clan.factionId);
  const facts = [
    { k: '世代', v: `${clan.generations.length} 代` },
    { k: '成员', v: `${countMembers(clan)} 人` },
    { k: '入册名将', v: `${countGenerals(clan)} 人` },
    { k: '联姻', v: `${clan.marriages.length} 桩` },
  ];
  return `<section class="cl-hero" aria-labelledby="clTitle">
    <div class="cl-hero-glow" aria-hidden="true"></div>
    <span class="cl-hero-seal" aria-hidden="true">${esc(str(clan.name).slice(0, 1) || '家')}</span>
    <div class="cl-hero-inner">
      <div class="cl-hero-meta">
        <span class="cl-hero-badge">家族谱</span>
        ${
          clan.factionId
            ? `<a class="cl-faction-link" href="${factionHref(clan.factionId)}">${esc(
                facName || clan.factionId
              )}<span aria-hidden="true"> ›</span></a>`
            : ''
        }
      </div>
      <h1 class="cl-hero-title" id="clTitle">${esc(clan.name)}</h1>
      ${clan.note ? `<p class="cl-hero-note">${esc(clan.note)}</p>` : ''}
      <dl class="cl-facts">${facts
        .map((fact) => `<div class="cl-fact"><dt>${esc(fact.k)}</dt><dd>${esc(fact.v)}</dd></div>`)
        .join('')}</dl>
    </div>
  </section>`;
}

function battleChipHTML(ctx, id) {
  const battle = battleOf(ctx, id);
  const name = battle ? str(battle.name) : str(id);
  const year = battle && battle.yearText ? str(battle.yearText) : '';
  return `<a class="cl-chip cl-chip--battle" href="${battleHref(id)}"${
    year ? ` title="${esc(year)}"` : ''
  }>${esc(name)}</a>`;
}

function memberHTML(ctx, member, depthMap) {
  const depth = clamp(depthMap.get(member.name) || 0, 0, 3);
  const battles = member.battleIds.map((id) => battleChipHTML(ctx, id)).join('');
  const generalLink = member.generalId
    ? `<a class="cl-link-btn" href="${generalHref(member.generalId)}">名将小传<span aria-hidden="true"> ›</span></a>`
    : '';
  const foot = generalLink || battles ? `<div class="cl-member-foot">${generalLink}<div class="cl-chips">${battles}</div></div>` : '';
  return `<li class="cl-member${depth ? ' is-child' : ''}" style="--cl-depth:${depth}">
    <div class="cl-member-card">
      <div class="cl-member-head">
        <span class="cl-member-name">${esc(member.name)}</span>
        ${member.role ? `<span class="cl-member-role">${esc(member.role)}</span>` : ''}
        ${member.generalId ? '<span class="cl-member-flag">名将</span>' : ''}
      </div>
      ${
        member.parent
          ? `<p class="cl-member-parent"><span class="cl-tree-glyph" aria-hidden="true">↳</span>承自 ${esc(member.parent)}</p>`
          : ''
      }
      ${member.note ? `<p class="cl-member-note">${esc(member.note)}</p>` : ''}
      ${foot}
    </div>
  </li>`;
}

function generationHTML(ctx, gen, depthMap) {
  return `<section class="cl-gen" data-gen="${esc(gen.gen)}">
    <header class="cl-gen-head">
      <span class="cl-gen-badge">第${cnNum(gen.gen)}代</span>
      ${gen.title ? `<span class="cl-gen-title">${esc(gen.title)}</span>` : ''}
      <span class="cl-gen-rule" aria-hidden="true"></span>
      <span class="cl-gen-count">${gen.members.length} 人</span>
    </header>
    <ol class="cl-members">${gen.members.map((member) => memberHTML(ctx, member, depthMap)).join('')}</ol>
  </section>`;
}

function sectionHeadHTML(num, title, note, id) {
  return `<div class="cl-sec-head">
    <h2 class="cl-sec-title"${id ? ` id="${id}"` : ''}><span class="cl-sec-num">${esc(num)}</span>${esc(title)}</h2>
    <span class="cl-sec-rule" aria-hidden="true"></span>
    ${note ? `<span class="cl-sec-note">${esc(note)}</span>` : ''}
  </div>`;
}

function generationsHTML(ctx, clan) {
  const depthMap = buildDepthMap(clan.generations);
  const body = clan.generations.length
    ? `<div class="cl-tree">${clan.generations
        .map((gen) => generationHTML(ctx, gen, depthMap))
        .join('')}</div>`
    : '<p class="cl-empty-line">该家族世代谱待补。</p>';
  return `<section class="cl-section" aria-labelledby="clGenTitle">
    ${sectionHeadHTML('壹', '世代谱', clan.generations.length ? '自上而下 · 世代递进' : '', 'clGenTitle')}
    ${body}
  </section>`;
}

function marriageHTML(ctx, marriage) {
  const year = fmtYearText(marriage.yearText);
  const factions = marriage.factionIds
    .map((id) => {
      const name = factionName(ctx, id) || id;
      return `<a class="cl-chip cl-chip--faction" href="${factionHref(id)}">${esc(name)}</a>`;
    })
    .join('');
  return `<li class="cl-marriage">
    <div class="cl-marriage-route">
      <span class="cl-marriage-side">${esc(marriage.from || '—')}</span>
      <span class="cl-marriage-knot" aria-label="联姻">姻</span>
      <span class="cl-marriage-side">${esc(marriage.to || '—')}</span>
    </div>
    <div class="cl-marriage-meta">
      ${marriage.member ? `<span class="cl-marriage-member">${esc(marriage.member)}</span>` : ''}
      ${year ? `<span class="cl-marriage-year">${esc(year)}</span>` : ''}
      ${factions ? `<span class="cl-marriage-facs">${factions}</span>` : ''}
    </div>
    ${marriage.note ? `<p class="cl-marriage-note">${esc(marriage.note)}</p>` : ''}
  </li>`;
}

function marriagesHTML(ctx, clan) {
  const body = clan.marriages.length
    ? `<ul class="cl-marriages">${clan.marriages.map((marriage) => marriageHTML(ctx, marriage)).join('')}</ul>`
    : '<p class="cl-empty-line">该家族暂无联姻记载。</p>';
  return `<section class="cl-section" aria-labelledby="clMarTitle">
    ${sectionHeadHTML(
      '贰',
      '联姻',
      clan.marriages.length ? `${clan.marriages.length} 桩 · 势力间婚盟` : '',
      'clMarTitle'
    )}
    ${body}
  </section>`;
}

function legendHTML() {
  return `<section class="cl-legend" aria-label="图例">
    <h2 class="cl-legend-title">图例</h2>
    <ul class="cl-legend-list">
      <li><span class="cl-lg cl-lg--gen">第N代</span>自上而下世代递进</li>
      <li><span class="cl-lg cl-lg--line" aria-hidden="true"></span>缩进与「承自」表示父子</li>
      <li><span class="cl-lg cl-lg--knot">姻</span>联姻记录</li>
      <li><span class="cl-lg cl-lg--general">名将</span>可进名将小传</li>
      <li><span class="cl-lg cl-lg--battle">战役</span>可进战役详情</li>
    </ul>
  </section>`;
}

function footerHTML() {
  return `<footer class="cl-foot">
    <p>世代与联姻据通行史籍整理 · 谱系为示意，非完整族谱</p>
    <p class="cl-foot-seal">山河战纪 · 家族谱</p>
  </footer>`;
}

function clanHTML(ctx, clan) {
  return `<div class="clan-page" data-clan="${esc(clan.id)}" data-faction="${esc(clan.factionId)}">
    ${headHTML({ title: '家族谱', sub: clan.name, factionId: clan.factionId })}
    ${heroHTML(ctx, clan)}
    <div class="cl-body">
      ${generationsHTML(ctx, clan)}
      ${marriagesHTML(ctx, clan)}
      ${legendHTML()}
      ${footerHTML()}
    </div>
  </div>`;
}

function overviewHTML(ctx, clans) {
  const cards = clans
    .map((clan) => {
      const facName = factionName(ctx, clan.factionId);
      return `<li><a class="cl-index-card" href="#/clan/${encodeURIComponent(clan.id)}">
        <span class="cl-index-seal" aria-hidden="true">${esc(str(clan.name).slice(0, 1) || '家')}</span>
        <span class="cl-index-body">
          <span class="cl-index-name">${esc(clan.name)}</span>
          ${facName ? `<span class="cl-index-fac">${esc(facName)}</span>` : ''}
          ${clan.note ? `<span class="cl-index-note-line">${esc(clan.note)}</span>` : ''}
          <span class="cl-index-stats">${clan.generations.length} 代 · ${countMembers(clan)} 人 · ${
        clan.marriages.length
      } 桩联姻</span>
        </span>
        <span class="cl-index-arrow" aria-hidden="true">›</span>
      </a></li>`;
    })
    .join('');
  return `<div class="clan-page clan-page--index">
    ${headHTML({ title: '家族谱', sub: `${clans.length} 个家族 · 世代与联姻` })}
    <div class="cl-body">
      <p class="cl-index-intro">自先秦至清，择要收录家族谱系与势力联姻；点开家族可看世代成员、名将小传与代表战役。</p>
      <ul class="cl-index-list">${cards}</ul>
      ${legendHTML()}
    </div>
  </div>`;
}

function loadingHTML() {
  return `<div class="clan-page clan-page--state">
    ${headHTML({ title: '家族谱' })}
    <div class="cl-body">
      <div class="cl-loading">
        ${skeletonHTML(3)}
        <p class="cl-loading-text">家族谱装载中…</p>
      </div>
    </div>
  </div>`;
}

function emptyDataHTML() {
  return `<div class="clan-page clan-page--state">
    ${headHTML({ title: '家族谱' })}
    <div class="cl-body">
      ${emptyStateHTML({
        title: '家族谱尚未载入',
        desc: 'clans.json 暂不可用或内容为空。120 场战役、名将册与势力页仍可正常阅读。',
        actions:
          '<button class="btn btn--gold" type="button" data-action="retry">重新载入</button><button class="btn" type="button" data-action="factions">返回势力</button>',
      })}
    </div>
  </div>`;
}

function notFoundHTML(id) {
  return `<div class="clan-page clan-page--state">
    ${headHTML({ title: '家族谱', sub: '未找到' })}
    <div class="cl-body">
      ${emptyStateHTML({
        title: '未见此家族',
        desc: `未找到「${id || '该家族'}」对应的家族谱，可能链接有误，或该家族尚未收录。`,
        actions: '<button class="btn btn--gold" type="button" data-action="factions">返回势力</button>',
      })}
    </div>
  </div>`;
}

/* ============================================================
   实例与生命周期
   ============================================================ */

let live = null;
let renderToken = 0;

function goBack(root) {
  const factionId = root && root.querySelector ? root.querySelector('.clan-page')?.dataset.faction || '' : '';
  // 注意：3.0 数据晚到时 app.js 会就地把当前路由再渲染一次，此时 getPrevRoute()
  // 会等于当前路由本身（prev.path === 当前 path），不能当作"上一页"。
  const currentPath = (window.location.hash || '').replace(/^#/, '') || '/';
  const prev = getPrevRoute();
  if (prev && prev.path && prev.path !== currentPath) {
    navigateBack();
    return;
  }
  navigate(factionId ? `/factions/${encodeURIComponent(factionId)}` : '/factions');
}

function bindChrome(root) {
  root.querySelectorAll('[data-action="back"]').forEach((btn) => {
    btn.addEventListener('click', () => goBack(root));
  });
  root.querySelector('[data-action="retry"]')?.addEventListener('click', () => window.location.reload());
  root.querySelector('[data-action="factions"]')?.addEventListener('click', () => navigate('/factions'));
  root.querySelector('[data-action="home"]')?.addEventListener('click', () => navigate('/'));
}

function mount(root, ctx, clan) {
  live = { root, ctx, clan, cleanup: null };
  root.innerHTML = clanHTML(ctx, clan);
  bindChrome(root);
  try {
    const cleanup = revealStagger(root, '.cl-member-card, .cl-marriage, .cl-index-card', {
      stagger: 34,
      wave: 6,
      threshold: 0.04,
    });
    if (typeof cleanup === 'function') live.cleanup = cleanup;
  } catch (err) {
    /* 动效失败不影响页面 */
  }
}

export function renderClan(root, ctx, clanId) {
  disposeClan();
  if (!root) return;
  const token = ++renderToken;
  const id = normalizeClanId(clanId);

  root.innerHTML = loadingHTML();
  bindChrome(root);

  Promise.all([loadClans(ctx), stylesReady])
    .then(([list]) => {
      if (token !== renderToken || !root.isConnected) return;
      if (!list || !list.length) {
        root.innerHTML = emptyDataHTML();
        bindChrome(root);
        return;
      }
      if (!id) {
        root.innerHTML = overviewHTML(ctx, list);
        bindChrome(root);
        return;
      }
      const clan = list.find((item) => item.id === id) || null;
      if (!clan) {
        root.innerHTML = notFoundHTML(id);
        bindChrome(root);
        return;
      }
      mount(root, ctx, clan);
    })
    .catch((err) => {
      if (token !== renderToken) return;
      console.error('[山河战纪] 家族谱渲染失败', err);
      root.innerHTML = emptyDataHTML();
      bindChrome(root);
    });
}

export function disposeClan() {
  renderToken += 1;
  const state = live;
  live = null;
  if (!state) return;
  if (typeof state.cleanup === 'function') {
    try {
      state.cleanup();
    } catch (err) {
      /* ignore */
    }
  }
  state.root = null;
  state.clan = null;
}
