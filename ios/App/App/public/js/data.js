/* ============================================================
   data.js — 数据加载（www/data/*.json）、索引、搜索、筛选
   契约见 docs/03-data-spec.md；数据缺失时优雅降级为空态
   ============================================================ */

const BASE = 'data/';

async function getJSON(file, timeoutMs = 12000) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(BASE + file, { cache: 'no-cache', signal: ctrl.signal });
    if (!res.ok) throw new Error(`${file} HTTP ${res.status}`);
    const text = (await res.text()).replace(/^\uFEFF/, '');
    return JSON.parse(text);
  } finally {
    clearTimeout(timer);
  }
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
    // 3.0 考据字段（数据未补齐时为空，UI 降级「史无确载」）
    duration: str(b.duration),
    objective: str(b.objective),
    terrainType: str(b.terrainType),
    arms: arr(b.arms).map(str).filter(Boolean),
    casualties: arr(b.casualties)
      .map((c) => ({ side: c?.side === 'B' ? 'B' : 'A', text: str(c?.text), note: str(c?.note) }))
      .filter((c) => c.text || c.note),
    troopsSource: arr(b.troopsSource).map(str).filter(Boolean),
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
    powers: [],
    powersByName: new Map(),
    territories: [],
    territoriesByFaction: new Map(),
    clans: [],
    clansById: new Map(),
    clansByFaction: new Map(),
    clansByGeneral: new Map(),
    generalByName: new Map(),
    generalById: new Map(),
    provinces: null,
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
    powers: [],
    powersByName: new Map(),
    territories: [],
    territoriesByFaction: new Map(),
    clans: [],
    clansById: new Map(),
    clansByFaction: new Map(),
    clansByGeneral: new Map(),
    generalByName: new Map(),
    generalById: new Map(),
    provinces: null,
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

function normalizePower(raw) {
  const p = raw && typeof raw === 'object' ? raw : {};
  const range = (v) => {
    const list = arr(v).map((x) => Number(x)).filter((x) => Number.isFinite(x));
    if (list.length >= 2) return [list[0], list[1]];
    if (list.length === 1) return [list[0], list[0]];
    return null;
  };
  return {
    ...p,
    id: str(p.id),
    name: str(p.name),
    aliases: arr(p.aliases).map(str).filter(Boolean),
    kind: str(p.kind) || '其他',
    factionId: str(p.factionId),
    period: str(p.period),
    territory: str(p.territory),
    areaWanKm2: range(p.areaWanKm2),
    populationWan: range(p.populationWan),
    armyWan: range(p.armyWan),
    note: str(p.note),
    sources: arr(p.sources).map(str).filter(Boolean),
  };
}

function normalizeClan(raw) {
  const c = raw && typeof raw === 'object' ? raw : {};
  const generations = arr(c.generations).map((g, gi) => ({
    gen: Number.isFinite(Number(g?.gen)) ? Number(g.gen) : gi + 1,
    members: arr(g?.members).map((m) => ({
      name: str(m?.name),
      role: str(m?.role),
      generalId: str(m?.generalId),
      parent: str(m?.parent),
      note: str(m?.note),
    })),
  }));
  return {
    ...c,
    id: str(c.id),
    name: str(c.name),
    factionId: str(c.factionId),
    note: str(c.note),
    generations,
    marriages: arr(c.marriages).map((m) => ({
      from: str(m?.from),
      to: str(m?.to),
      member: str(m?.member),
      year: Number.isFinite(Number(m?.year)) ? Number(m.year) : null,
      note: str(m?.note),
      factionIds: arr(m?.factionIds).map(str).filter(Boolean),
    })),
  };
}

function normalizeTerritory(raw) {
  const t = raw && typeof raw === 'object' ? raw : {};
  return {
    ...t,
    factionId: str(t.factionId),
    provinces: arr(t.provinces).map(str).filter(Boolean),
    note: str(t.note),
  };
}

async function loadOptional2_0() {
  const [factionsRes, relationsRes, replaysRes, powersRes, territoriesRes, clansRes, provincesRes, generalsRes] =
    await Promise.allSettled([
      getJSON('factions.json'),
      getJSON('relations.json'),
      getJSON('replays.json'),
      getJSON('powers.json'),
      getJSON('territories.json'),
      getJSON('clans.json'),
      getJSON('china-provinces.json'),
      getJSON('generals.json'),
    ]);
  const missing = [];
  const take = (res, file, normalize) => {
    if (res.status !== 'fulfilled' || res.value == null) {
      missing.push(file);
      return [];
    }
    const raw = res.value;
    const list = Array.isArray(raw) ? raw : Array.isArray(raw?.factions) ? raw.factions : Array.isArray(raw?.clans) ? raw.clans : [];
    return list.map(normalize).filter((x) => x && (x.id || x.factionId || x.name));
  };
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

  const powers = take(powersRes, 'powers.json', normalizePower).filter((p) => p.name);
  const territories = take(territoriesRes, 'territories.json', normalizeTerritory).filter((t) => t.factionId);
  const clans = take(clansRes, 'clans.json', normalizeClan).filter((c) => c.id || c.name);
  const generalsRaw =
    generalsRes.status === 'fulfilled' && Array.isArray(generalsRes.value) ? generalsRes.value : [];

  const powersByName = new Map();
  for (const p of powers) {
    powersByName.set(p.name, p);
    for (const alias of p.aliases) powersByName.set(alias, p);
  }
  const territoriesByFaction = new Map(territories.map((t) => [t.factionId, t]));
  const clansById = new Map(clans.map((c) => [c.id, c]));
  const clansByFaction = new Map();
  for (const c of clans) {
    if (c.factionId && !clansByFaction.has(c.factionId)) clansByFaction.set(c.factionId, c);
  }
  const generalByName = new Map();
  const generalById = new Map();
  for (const g of generalsRaw) {
    if (!g?.id) continue;
    generalById.set(str(g.id), g);
    generalByName.set(str(g.name), g);
    for (const alias of arr(g.alias)) generalByName.set(str(alias), g);
  }
  const clansByGeneral = new Map();
  for (const c of clans) {
    for (const gen of c.generations) {
      for (const m of gen.members) {
        const gid = m.generalId || generalByName.get(m.name)?.id || '';
        if (gid) clansByGeneral.set(gid, c);
      }
    }
  }
  if (missing.length) console.info(`[山河战纪] 部分数据暂不可用：${missing.join(', ')}`);
  return {
    factions,
    factionsById: new Map(factions.map((f) => [f.id, f])),
    relations,
    replays,
    replaysByBattle: new Map(replays.map((r) => [r.battleId, r])),
    powers,
    powersByName,
    territories,
    territoriesByFaction,
    clans,
    clansById,
    clansByFaction,
    clansByGeneral,
    generalByName,
    generalById,
    provinces:
      provincesRes.status === 'fulfilled' && provincesRes.value && Array.isArray(provincesRes.value.features)
        ? provincesRes.value
        : null,
    missing,
  };
}


async function loadOptional3_0() {
  const [powersRes, territoriesRes, clansRes, provincesRes, stateRes] = await Promise.allSettled([
    getJSON('powers.json'),
    getJSON('territories.json'),
    getJSON('clans.json'),
    getJSON('china-provinces.json'),
    getJSON('state-relations.json'),
  ]);
  const missing = [];
  const powersRaw = powersRes.status === 'fulfilled' ? powersRes.value : (missing.push('powers.json'), []);
  const powers = (Array.isArray(powersRaw) ? powersRaw : arr(powersRaw?.powers))
    .filter((p) => p && (p.name || p.id))
    .map((p) => ({ ...p, name: str(p.name), kind: str(p.kind) || '其他' }));
  const powersByName = new Map();
  powers.forEach((p) => {
    if (!p.name) return;
    powersByName.set(p.name, p);
    arr(p.aliases).forEach((a) => a && powersByName.set(a, p));
  });
  const territoriesRaw = territoriesRes.status === 'fulfilled' ? territoriesRes.value : (missing.push('territories.json'), {});
  const territories = Array.isArray(territoriesRaw) ? territoriesRaw : arr(territoriesRaw?.factions);
  const territoriesByFaction = new Map(territories.filter((t) => t.factionId).map((t) => [t.factionId, t]));
  const clansRaw = clansRes.status === 'fulfilled' ? clansRes.value : (missing.push('clans.json'), []);
  const clans = (Array.isArray(clansRaw) ? clansRaw : arr(clansRaw?.clans)).filter((c) => c && c.id);
  const clansById = new Map(clans.map((c) => [c.id, c]));
  const provinces = provincesRes.status === 'fulfilled' ? provincesRes.value : null;
  const stateRaw = stateRes.status === 'fulfilled' ? stateRes.value : (missing.push('state-relations.json'), {});
  const stateRelations = Array.isArray(stateRaw) ? stateRaw : arr(stateRaw?.relations);
  const stateExtraNodes = Array.isArray(stateRaw) ? [] : arr(stateRaw?.extraNodes);
  if (missing.length) console.info(`[山河战纪] 3.0 数据暂不可用：${missing.join(', ')}`);
  return {
    powers, powersByName, territories, territoriesByFaction, clans, clansById, provinces,
    stateRelations, stateExtraNodes, missing,
  };
}

/**
 * 加载全部数据；顺序：真实 fetch → 开发 fixture（仅当显式开启）→ 空态。
 * 永远 resolve，不抛错（保证不白屏）。
 */
export async function loadData() {
  // 2.0 可选数据与主数据并行拉取，避免串行叠加首屏等待
  const extraPromise = loadOptional2_0();
  const extra3Promise = loadOptional3_0();
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
        data.powers = extra.powers;
        data.powersByName = extra.powersByName;
        data.territories = extra.territories;
        data.territoriesByFaction = extra.territoriesByFaction;
        data.clans = extra.clans;
        data.clansById = extra.clansById;
        data.clansByFaction = extra.clansByFaction;
        data.clansByGeneral = extra.clansByGeneral;
        data.generalByName = extra.generalByName;
        data.generalById = extra.generalById;
        data.provinces = extra.provinces;
        data.missing2 = extra.missing;
        return data;
      })
      .catch(() => data);

    // 3.0 考据数据（势力档案/版图/家族谱），在 ready2 之后补渲染
    data.ready3 = Promise.all([data.ready2, extra3Promise])
      .then(([, extra]) => {
        data.powers = extra.powers;
        data.powersByName = extra.powersByName;
        data.territories = extra.territories;
        data.territoriesByFaction = extra.territoriesByFaction;
        data.clans = extra.clans;
        data.clansById = extra.clansById;
        data.provinces = extra.provinces;
        data.stateRelations = extra.stateRelations;
        data.stateExtraNodes = extra.stateExtraNodes;
        data.missing3 = extra.missing;
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
