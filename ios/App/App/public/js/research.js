/* ============================================================
   research.js — 3.0 考据版共用渲染：势力档案查找 / 区间文本 /
   位置精度 / 版图卡（复用 territory.js 的 SVG）
   ============================================================ */

import { esc } from './ui.js';
import { territorySVG } from './territory.js';

export function findPower(ctx, sideName) {
  const name = String(sideName || '').trim();
  if (!name || !ctx?.data?.powersByName) return null;
  const map = ctx.data.powersByName;
  if (map.has(name)) return map.get(name);
  const short = name.replace(/[军部]$/u, '');
  if (short && map.has(short)) return map.get(short);
  for (const [key, power] of map) {
    if (key.includes(name) || name.includes(key)) return power;
  }
  return null;
}

export function rangeText(range, unit = '') {
  if (!Array.isArray(range) || !range.length) return '史无确载';
  const [a, b] = range.length >= 2 ? range : [range[0], range[0]];
  if (a === b || !Number.isFinite(Number(b))) return `约 ${a}${unit}`;
  return `约 ${a}–${b}${unit}`;
}

export function precisionText(raw) {
  const value = String(raw || '').trim();
  if (/确/.test(value)) return { label: '确有其地', tone: 'ok', desc: '古地名与今地对应较明确' };
  if (/约/.test(value)) return { label: '约指', tone: 'mid', desc: '古今对应为通行推定' };
  if (/传说|传/.test(value)) return { label: '传说', tone: 'low', desc: '传说时代，地望存疑' };
  if (/境外/.test(value)) return { label: '境外示意', tone: 'low', desc: '境外地点，示意标注' };
  if (!value || value === '待考') return { label: '待考', tone: 'low', desc: '史无确载' };
  return { label: value, tone: 'mid', desc: '' };
}

function colorForFaction(ctx, id) {
  return ctx?.data?.factionsById?.get(id)?.color || '#C9A227';
}

export function territoryFor(ctx, provinceSource = null) {
  const provinces = ctx?.data?.provinces;
  const entries = ctx?.data?.territories || [];
  if (!provinces || !entries.length) return null;
  return { provinces, entries };
}

/** 势力详情：版图卡 */
export function factionTerritoryCard(ctx, faction) {
  const territory = ctx?.data?.territoriesByFaction?.get(faction?.id);
  const base = territoryFor(ctx);
  if (!faction) return '';
  if (!territory || !base) {
    return `<section class="terr-card is-empty" aria-label="势力范围">
      <div class="terr-head"><span>势力范围 · ${esc(faction.name)}</span><span class="terr-tag">示意</span></div>
      <p class="terr-empty">版图示意数据尚未收录（territories.json / china-provinces.json 未就绪）。</p>
    </section>`;
  }
  const svg = territorySVG({
    provinces: base.provinces,
    entries: base.entries,
    highlights: [faction.id],
    colorFor: (id) => colorForFaction(ctx, id),
    width: 340,
    height: 220,
    label: '势力范围示意',
  });
  return `<section class="terr-card" aria-label="${esc(faction.name)}势力范围">
    <div class="terr-head"><span>势力范围 · ${esc(faction.name)}</span><span class="terr-tag">示意</span></div>
    <div class="terr-map">${svg}</div>
    <p class="terr-note">${esc(territory.note || '按今省界拼合的示意范围，不表示精确历史边界。')}</p>
    <div class="terr-legend"><i style="--c:${esc(faction.color)}"></i>势力范围（示意）<span>省界仅作定位参考</span></div>
  </section>`;
}

/** 详情：某一阵营的势力范围小图 */
export function battleTerritoryHTML(ctx, battle, side) {
  const power = findPower(ctx, side.name);
  const factionId = power?.factionId;
  const faction = factionId ? ctx?.data?.factionsById?.get(factionId) : null;
  const territory = factionId ? ctx?.data?.territoriesByFaction?.get(factionId) : null;
  const base = territoryFor(ctx);
  if (!territory || !base || !factionId) {
    return `<div class="bterr is-empty">
      <span class="bterr-name">${esc(side.name)}</span>
      <p>该方${power?.kind && /联军|起义军|外国|近代|军阀|革命/.test(power.kind) ? '非固定政权' : '无对应版图数据'}，无版图示意。</p>
    </div>`;
  }
  const lng = Number(battle?.location?.lng);
  const lat = Number(battle?.location?.lat);
  const point = Number.isFinite(lng) && Number.isFinite(lat) ? [lng, lat] : null;
  const svg = territorySVG({
    provinces: base.provinces,
    entries: base.entries,
    highlights: [factionId],
    colorFor: () => faction.color || '#C9A227',
    point,
    pointLabel: battle?.location?.ancient || '',
    width: 320,
    height: 210,
    label: '势力范围示意',
  });
  return `<div class="bterr">
    <div class="bterr-head"><span class="bterr-name">${esc(side.name)}</span><span class="bterr-sub">${esc(
      faction.fullName || faction.name
    )} · 示意范围</span></div>
    <div class="terr-map">${svg}</div>
    <p class="bterr-note">${esc(territory.note || '按今省界拼合的示意范围')}</p>
    <a class="bterr-link" href="#/map?battle=${encodeURIComponent(battle.id)}">在地图中定位战场 →</a>
  </div>`;
}
