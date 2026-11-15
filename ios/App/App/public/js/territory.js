/* ============================================================
   territory.js — 势力范围示意图（矢量，非标准地图）
   数据：data/china-provinces.json（按今省界拼合）+ data/territories.json
   用法：
     import { territorySVG } from './territory.js';
     el.innerHTML = territorySVG({
       provinces, entries,            // provinces: FeatureCollection; entries: territories 数组
       highlights: ['qin'],           // 高亮 factionId
       colorFor: (id) => '#B23A2E',
       point: [109.9, 35.5],          // 可选，战场点
       width: 320, height: 240,
       label: '势力范围示意',
     });
   ============================================================ */

const BOUNDS = { lngMin: 73, lngMax: 135.5, latMin: 17.5, latMax: 54.5 };

function mercY(lat) {
  const rad = (lat * Math.PI) / 180;
  return Math.log(Math.tan(Math.PI / 4 + rad / 2));
}

const Y0 = mercY(BOUNDS.latMin);
const Y1 = mercY(BOUNDS.latMax);

function makeProject(width, height, pad) {
  const w = width - pad * 2;
  const h = height - pad * 2;
  const kx = w / (BOUNDS.lngMax - BOUNDS.lngMin);
  const ky = h / (Y1 - Y0);
  return (lng, lat) => [pad + (lng - BOUNDS.lngMin) * kx, pad + (Y1 - mercY(lat)) * ky];
}

function ringPath(ring, project) {
  return (
    ring
      .map(([lng, lat], i) => {
        const [x, y] = project(lng, lat);
        return `${i ? 'L' : 'M'}${x.toFixed(1)},${y.toFixed(1)}`;
      })
      .join('') + 'Z'
  );
}

function geometryPath(geom, project) {
  if (!geom) return '';
  if (geom.type === 'Polygon') {
    return geom.coordinates.map((r) => ringPath(r, project)).join('');
  }
  if (geom.type === 'MultiPolygon') {
    return geom.coordinates.map((poly) => poly.map((r) => ringPath(r, project)).join('')).join('');
  }
  return '';
}

/**
 * @param {object} opts
 * @param {object} opts.provinces  china-provinces.json（FeatureCollection）
 * @param {Array}  opts.entries     territories.json 的 factions 数组
 * @param {Array}  [opts.highlights] 高亮的 factionId 列表
 * @param {function} [opts.colorFor] factionId -> 颜色
 * @param {Array}  [opts.point]     战场 [lng, lat]
 * @param {string} [opts.pointLabel] 战场点标签
 * @param {number} [opts.width]
 * @param {number} [opts.height]
 * @param {string} [opts.label]     图例标题
 * @param {boolean}[opts.showAllNames] 是否标出高亮省名
 * @returns {string} SVG 字符串
 */
export function territorySVG(opts) {
  const {
    provinces,
    entries = [],
    highlights = [],
    colorFor = () => '#B23A2E',
    point = null,
    pointLabel = '',
    width = 320,
    height = 236,
    label = '势力范围示意',
    showAllNames = false,
  } = opts || {};
  const project = makeProject(width, height, 8);
  const hl = new Set(highlights.filter(Boolean));
  const byProvince = new Map();
  entries.forEach((e) => {
    (e.provinces || []).forEach((p) => {
      if (!byProvince.has(p)) byProvince.set(p, []);
      byProvince.get(p).push(e.factionId);
    });
  });

  const parts = [];
  parts.push(
    `<svg class="territory-svg" viewBox="0 0 ${width} ${height}" role="img" aria-label="${esc(
      label
    )}">`
  );
  parts.push(
    `<rect x="0" y="0" width="${width}" height="${height}" fill="rgba(233,223,200,0.03)"/>`
  );

  for (const f of provinces?.features || []) {
    const name = f.properties?.name;
    const d = geometryPath(f.geometry, project);
    if (!d) continue;
    const owners = byProvince.get(name) || [];
    const highlighted = owners.filter((id) => hl.has(id));
    const fill = highlighted.length ? colorFor(highlighted[0]) : 'rgba(233,223,200,0.055)';
    const opacity = highlighted.length ? 0.42 : 1;
    parts.push(
      `<path d="${d}" fill="${fill}" fill-opacity="${opacity}" stroke="rgba(233,223,200,0.16)" stroke-width="0.5"/>`
    );
  }

  if (point && Number.isFinite(point[0]) && Number.isFinite(point[1])) {
    const [px, py] = project(point[0], point[1]);
    parts.push(
      `<g class="territory-point"><circle cx="${px.toFixed(1)}" cy="${py.toFixed(
        1
      )}" r="7" fill="rgba(178,58,46,0.25)"/><circle cx="${px.toFixed(1)}" cy="${py.toFixed(
        1
      )}" r="3.2" fill="#B23A2E" stroke="#E9DFC8" stroke-width="1"/></g>`
    );
    if (pointLabel) {
      parts.push(
        `<text x="${px.toFixed(1)}" y="${(py - 10).toFixed(1)}" text-anchor="middle" font-size="9" fill="#E9DFC8" opacity="0.85">${esc(
          pointLabel
        )}</text>`
      );
    }
  }

  parts.push(
    `<text x="6" y="${height - 6}" font-size="8" fill="rgba(233,223,200,0.45)">${esc(label)}</text>`
  );
  parts.push('</svg>');
  return parts.join('');
}

function esc(s) {
  return String(s == null ? '' : s).replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])
  );
}

export default territorySVG;
