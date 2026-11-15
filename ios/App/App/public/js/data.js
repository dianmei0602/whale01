/* ============================================================
   data.js — 数据加载（www/data/*.json）、索引、搜索、筛选
   契约见 docs/03-data-spec.md；数据缺失时优雅降级为空态
   ============================================================ */

const BASE = 'data/';

async function getJSON(file) {
  const res = await fetch(BASE + file, { cache: 'no-cache' });
  if (!res.ok) throw new Error(`${file} HTTP ${res.status}`);
  const text = (await res.text()).replace(/^\uFEFF/, '');
  return JSON.parse(text);
}

const arr = (v) => (Array.isArray(v) ? v : v == null || v === '' ? [] : [v]);
const str = (v) => (v == null ? '' : String(v));

function normalizeBattle(raw, era) {
  const b = raw && typeof raw === 'object' ? raw : {};
  const sides = Array.isArray(b.sides) ? b.sides : [];
  const startYear = Number.isFinite(Number(b.startYear)) ? Number(b.startYear) : 0;
  const endYear = Number.isFinite(Number(b.endYear)) ? Number(b.endYear) : startYear;
  return {
    ...b,
    id: str(b.id),
    name: str(b.name) || '无名之战',
    alias: arr(b.alias).map(str).filter(Boolean),
    eraId: str(b.eraId) || (era ? era.id : ''),
    era: era || null,
    yearText: str(b.yearText),
    startYear,
    endYear,
    type: arr(b.type).map(str).filter(Boolean),
    scale: str(b.scale) || '战役',
    location: {
      ancient: '',
      modern: '',
      lng: null,
      lat: null,
      precision: '',
      ...(b.location && typeof b.location === 'object' ? b.location : {}),
    },
    sides: sides.map((s, i) => ({
      name: str(s?.name) || `阵营${i + 1}`,
      commanders: arr(s?.commanders).map(str).filter(Boolean),
      troopsText: str(s?.troopsText),
      troopsNum: Number.isFinite(Number(s?.troopsNum)) ? Number(s.troopsNum) : null,
      color: s?.color === 'B' ? 'B' : 'A',
    })),
    result: {
      winner: ['A', 'B', 'draw', 'truce', 'none'].includes(b.result?.winner) ? b.result.winner : 'none',
      text: str(b.result?.text),
    },
    summary: str(b.summary),
    background: str(b.background),
    course: arr(b.course)
      .map((c) => ({ title: str(c?.title), text: str(c?.text) }))
      .filter((c) => c.text || c.title),
    outcome: str(b.outcome),
    significance: str(b.significance),
    anecdotes: arr(b.anecdotes)
      .map((a) => ({ title: str(a?.title), text: str(a?.text) }))
      .filter((a) => a.text || a.title),
    people: arr(b.people).map(str).filter(Boolean),
    sources: arr(b.sources).map(str).filter(Boolean),
    notes: arr(b.notes).map(str).filter(Boolean),
    related: arr(b.related).map(str).filter(Boolean),
    tags: arr(b.tags).map(str).filter(Boolean),
  };
}

function normalizeEra(raw, i) {
  const e = raw && typeof raw === 'object' ? raw : {};
  return {
    ...e,
    id: str(e.id) || `era-${String(i + 1).padStart(2, '0')}`,
    index: Number.isFinite(Number(e.index)) ? Number(e.index) : i + 1,
    name: str(e.name),
    short: str(e.short) || str(e.name).slice(0, 3),
    startYear: Number.isFinite(Number(e.startYear)) ? Number(e.startYear) : 0,
    endYear: Number.isFinite(Number(e.endYear)) ? Number(e.endYear) : 0,
    rangeText: str(e.rangeText),
    themeColor: /^#[0-9a-fA-F]{6}$/.test(str(e.themeColor)) ? str(e.themeColor) : '#C9A227',
    tagline: str(e.tagline),
  };
}

function buildIndex(erasRaw, battlesRaw) {
  const eras = erasRaw.map(normalizeEra).sort((a, b) => a.index - b.index);
  const eraById = new Map(eras.map((e) => [e.id, e]));
  const battles = battlesRaw
    .map((b) => normalizeBattle(b, eraById.get(str(b?.eraId)) || null))
    .filter((b) => b.id && b.name)
    .sort((a, b) => a.startYear - b.startYear || a.endYear - b.endYear || a.name.localeCompare(b.name, 'zh'));

  const byId = new Map(battles.map((b) => [b.id, b]));
  const neighbors = new Map();
  battles.forEach((b, i) => {
    neighbors.set(b.id, {
      prev: i > 0 ? battles[i - 1] : null,
      next: i < battles.length - 1 ? battles[i + 1] : null,
      index: i + 1,
    });
  });

  const sections = eras.map((era) => ({
    era,
    battles: battles.filter((b) => b.eraId === era.id),
  }));

  const yearSpan = battles.length
    ? Math.max(...battles.map((b) => b.endYear)) - Math.min(...battles.map((b) => b.startYear))
    : 0;

  return {
    ok: battles.length > 0,
    eras,
    eraById,
    battles,
    byId,
    neighbors,
    sections,
    yearSpan,
    total: battles.length,
    factions: [],
    factionsById: new Map(),
    relations: [],
    replays: [],
    replaysByBattle: new Map(),
  };
}

function emptyData(error = '') {
  return {
    ok: false,
    eras: [],
    eraById: new Map(),
    battles: [],
    byId: new Map(),
    neighbors: new Map(),
    sections: [],
    yearSpan: 0,
    total: 0,
    factions: [],
    factionsById: new Map(),
    relations: [],
    replays: [],
    replaysByBattle: new Map(),
    error,
    source: 'none',
  };
}

/* ---------------- 2.0 可选数据：势力 / 名将关系 / 战役推演 ---------------- */
const num = (v, fallback = 0) => (Number.isFinite(Number(v)) ? Number(v) : fallback);

function normalizeFaction(raw) {
  const f = raw && typeof raw === 'object' ? raw : {};
  return {
    ...f,
    id: str(f.id),
    name: str(f.name),
    fullName: str(f.fullName) || str(f.name),
    family: str(f.family),
    eraIds: arr(f.eraIds).map(str).filter(Boolean),
    startYear: num(f.startYear),
    endYear: num(f.endYear),
    capital: str(f.capital),
    founder: str(f.founder),
    peakRuler: str(f.peakRuler),
    color: /^#[0-9a-fA-F]{6}$/.test(str(f.color)) ? str(f.color) : '#C9A227',
    tagline: str(f.tagline),
    rise: str(f.rise),
    fall: str(f.fall),
    system: str(f.system),
    territory: str(f.territory),
    keyBattles: arr(f.keyBattles).map(str).filter(Boolean),
    keyGenerals: arr(f.keyGenerals).map(str).filter(Boolean),
    legacy: str(f.legacy),
  };
}

function normalizeRelation(raw) {
  const r = raw && typeof raw === 'object' ? raw : {};
  return {
    ...r,
    id: str(r.id) || `${str(r.source)}--${str(r.target)}`,
    source: str(r.source),
    target: str(r.target),
    type: str(r.type) || '同僚',
    note: str(r.note),
    eraIds: arr(r.eraIds).map(str).filter(Boolean),
    strength: Math.min(3, Math.max(1, num(r.strength, 2))),
  };
}

function normalizeReplay(raw) {
  const r = raw && typeof raw === 'object' ? raw : {};
  return {
    ...r,
    battleId: str(r.battleId),
    title: str(r.title),
    subtitle: str(r.subtitle),
    terrain: str(r.terrain) || 'plain',
    summary: str(r.summary),
    stages: arr(r.stages).map((s) => ({
      ...s,
      title: str(s?.title),
      narration: str(s?.narration),
      duration: num(s?.duration, 6),
      units: arr(s?.units).map((u) => ({
        ...u,
        id: str(u?.id),
        label: str(u?.label),
        side: ['A', 'B', 'N'].includes(u?.side) ? u.side : 'N',
        pos: Array.isArray(u?.pos) ? [num(u.pos[0], 50), num(u.pos[1], 50)] : [50, 50],
        kind: str(u?.kind) || 'infantry',
      })),
      arrows: arr(s?.arrows).map((a) => ({
        ...a,
        from: Array.isArray(a?.from) ? [num(a.from[0], 50), num(a.from[1], 50)] : [50, 50],
        to: Array.isArray(a?.to) ? [num(a.to[0], 50), num(a.to[1], 50)] : [50, 50],
        kind: str(a?.kind) || 'advance',
        label: str(a?.label),
      })),
    })),
  };
}

async function loadOptional2_0() {
  const [factionsRes, relationsRes, replaysRes] = await Promise.allSettled([
    getJSON('factions.json'),
    getJSON('relations.json'),
    getJSON('replays.json'),
  ]);
  const missing = [];
  const factions =
    factionsRes.status === 'fulfilled' && Array.isArray(factionsRes.value)
      ? factionsRes.value.map(normalizeFaction).filter((f) => f.id && f.name)
      : (missing.push('factions.json'), []);
  const relations =
    relationsRes.status === 'fulfilled' && Array.isArray(relationsRes.value)
      ? relationsRes.value.map(normalizeRelation).filter((r) => r.source && r.target)
      : (missing.push('relations.json'), []);
  const replays =
    replaysRes.status === 'fulfilled' && Array.isArray(replaysRes.value)
      ? replaysRes.value.map(normalizeReplay).filter((r) => r.battleId)
      : (missing.push('replays.json'), []);
  if (missing.length) console.info(`[山河战纪] 2.0 数据暂不可用：${missing.join(', ')}`);
  return {
    factions,
    factionsById: new Map(factions.map((f) => [f.id, f])),
    relations,
    replays,
    replaysByBattle: new Map(replays.map((r) => [r.battleId, r])),
    missing,
  };
}


/**
 * 加载全部数据；顺序：真实 fetch → 开发 fixture（仅当显式开启）→ 空态。
 * 永远 resolve，不抛错（保证不白屏）。
 */
export async function loadData() {
  // 2.0 可选数据与主数据并行拉取，避免串行叠加首屏等待
  const extraPromise = loadOptional2_0();
  try {
    const erasJson = await getJSON('eras.json');
    const erasRaw = Array.isArray(erasJson) ? erasJson : arr(erasJson?.eras);
    if (!erasRaw.length) throw new Error('eras.json 为空');

    const files = erasRaw.map((e, i) => {
      const idx = Number.isFinite(Number(e?.index)) ? Number(e.index) : i + 1;
      return `${String(e?.id || `era-${String(idx).padStart(2, '0')}`)}.json`;
    });

    const settled = await Promise.allSettled(files.map((f) => getJSON(f)));
    const battlesRaw = [];
    const missing = [];
    settled.forEach((r, i) => {
      if (r.status === 'fulfilled' && Array.isArray(r.value)) {
        const era = erasRaw[i];
        r.value.forEach((b) => {
          if (b && typeof b === 'object' && !b.eraId && era?.id) b.eraId = era.id;
        });
        battlesRaw.push(...r.value);
      } else {
        missing.push(files[i]);
      }
    });
    if (missing.length) {
      // 单期数据缺失不阻塞整体：仅记录，界面照常渲染已有内容
      console.info(`[山河战纪] 以下数据文件暂不可用：${missing.join(', ')}`);
    }
    const data = buildIndex(erasRaw, battlesRaw);
    data.source = 'fetch';
    if (missing.length) data.missing = missing;

    // 2.0 数据为可选增强：并行加载，但先返回主数据以尽早渲染时间轴；
    // 势力/图谱等页面在 ready2 完成后由 app.js 自动补渲染。
    data.ready2 = extraPromise
      .then((extra) => {
        data.factions = extra.factions;
        data.factionsById = extra.factionsById;
        data.relations = extra.relations;
        data.replays = extra.replays;
        data.replaysByBattle = extra.replaysByBattle;
        data.missing2 = extra.missing;
        return data;
      })
      .catch(() => data);

    return data;
  } catch (err) {
    console.info('[山河战纪] 数据目录不可用，尝试开发期内存数据。', err?.message || err);
  }

  if (typeof window !== 'undefined' && window.__USE_DEV_FIXTURE__) {
    try {
      const mod = await import('./dev-fixture.js');
      const data = buildIndex(mod.eras || [], mod.battles || []);
      data.source = 'fixture';
      return data;
    } catch (err) {
      console.warn('[山河战纪] 开发期内存数据加载失败。', err?.message || err);
    }
  }

  return emptyData('数据文件缺失或不可读');
}

/* ---------------- 筛选 ---------------- */
export function filterBattles(battles, filter) {
  const eras = filter?.eras || [];
  const types = filter?.types || [];
  if (!eras.length && !types.length) return battles;
  return battles.filter((b) => {
    if (eras.length && !eras.includes(b.eraId)) return false;
    if (types.length && !b.type.some((t) => types.includes(t))) return false;
    return true;
  });
}

/* ---------------- 搜索 ---------------- */
const norm = (s) => String(s == null ? '' : s).toLowerCase().replace(/\s+/g, '');

export function searchBattles(data, rawQuery) {
  const q = norm(rawQuery);
  if (!q) return null;

  const battleHits = [];
  const anecdoteHits = [];
  const peopleMap = new Map();

  for (const b of data.battles) {
    const hits = [];
    let score = 0;
    const check = (value, label, weight) => {
      if (!value) return;
      const text = norm(value);
      if (!text) return;
      if (text.includes(q)) {
        if (!hits.includes(label)) hits.push(label);
        if (weight > score) score = weight;
      }
    };

    check(b.name, '战役名', 120);
    b.alias.forEach((a) => check(a, '别名', 110));
    b.people.forEach((p) => check(p, '人物', 95));
    check(b.location.ancient, '古地名', 85);
    check(b.location.modern, '今地名', 85);
    b.tags.forEach((t) => check(t, '标签', 75));
    check(b.summary, '提要', 62);
    check(b.yearText, '年代', 58);
    b.course.forEach((c) => {
      check(c.title, '经过', 46);
      check(c.text, '经过', 30);
    });
    b.anecdotes.forEach((a) => {
      check(a.title, '典故', 78);
      check(a.text, '典故', 38);
      if (norm(a.title).includes(q) || norm(a.text).includes(q)) {
        anecdoteHits.push({ battle: b, title: a.title, text: a.text });
      }
    });
    b.sides.forEach((s) => {
      check(s.name, '阵营', 70);
      s.commanders.forEach((c) => check(c, '人物', 95));
    });

    // 年份数字（"前260" / "260" / "208"）
    if (/\d/.test(q)) {
      for (const year of [b.startYear, b.endYear]) {
        const abs = String(Math.abs(year));
        if (abs && (abs.includes(q) || q.includes(abs))) {
          if (!hits.includes('年代')) hits.push('年代');
          score = Math.max(score, 66);
        }
      }
    }

    if (hits.length) battleHits.push({ battle: b, score, hits });

    for (const p of b.people) {
      if (norm(p).includes(q) || q.includes(norm(p))) {
        if (!peopleMap.has(p)) peopleMap.set(p, { name: p, battles: [] });
        peopleMap.get(p).battles.push(b);
      }
    }
  }

  battleHits.sort((a, b) => b.score - a.score || a.battle.startYear - b.battle.startYear);

  return {
    battles: battleHits,
    anecdotes: anecdoteHits.slice(0, 10),
    people: [...peopleMap.values()].slice(0, 8),
  };
}

/* ---------------- 热门词 ---------------- */
export function hotTags(data, limit = 8) {
  const map = new Map();
  for (const b of data.battles) {
    for (const t of [...b.tags, ...b.type]) {
      if (!t) continue;
      map.set(t, (map.get(t) || 0) + 1);
    }
  }
  return [...map.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0], 'zh'))
    .slice(0, limit)
    .map(([tag, count]) => ({ tag, count }));
}
