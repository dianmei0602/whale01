/* 把 DataV 中国省级 GeoJSON 转为离线 SVG 路径。
   底图仅用于现代地名定位，不代表明代疆域；运行时无需联网。 */
const fs = require('fs');
const path = require('path');

const base = __dirname;
const geoPath = path.join(base, 'content', 'china.geo.json');
const outputPath = path.join(path.dirname(base), '大明王朝iOS', 'china-map.js');
const data = JSON.parse(fs.readFileSync(geoPath, 'utf8'));

const WIDTH = 420;
const HEIGHT = 430;
const MIN_LAT = 15;
const MARGIN = 12;
const points = [];
function walk(coords) {
  if (Array.isArray(coords) && typeof coords[0] === 'number') {
    if (coords[0] >= 73 && coords[0] <= 136 && coords[1] >= MIN_LAT && coords[1] <= 54) points.push(coords);
  } else if (Array.isArray(coords)) {
    coords.forEach(walk);
  }
}
for (const feature of data.features) walk(feature.geometry.coordinates);

const mercator = lat => Math.log(Math.tan(Math.PI / 4 + lat * Math.PI / 360));
const minLon = Math.min(...points.map(point => point[0]));
const maxLon = Math.max(...points.map(point => point[0]));
const minY = mercator(MIN_LAT);
const maxY = mercator(54);
const minLonRad = minLon * Math.PI / 180;
const maxLonRad = maxLon * Math.PI / 180;
const scale = Math.min(
  (WIDTH - MARGIN * 2) / (maxLonRad - minLonRad),
  (HEIGHT - MARGIN * 2) / (maxY - minY)
);
const contentWidth = (maxLonRad - minLonRad) * scale;
const contentHeight = (maxY - minY) * scale;
const offsetX = (WIDTH - contentWidth) / 2;
const offsetY = (HEIGHT - contentHeight) / 2;
const project = ([lon, lat]) => [
  offsetX + (lon * Math.PI / 180 - minLonRad) * scale,
  offsetY + (maxY - mercator(lat)) * scale
];

function ringToPath(ring) {
  const visible = ring.filter(point => point[1] >= MIN_LAT);
  if (visible.length < 3) return '';
  const seen = new Set();
  const coords = [];
  for (const point of visible) {
    const [x, y] = project(point).map(value => Math.round(value * 10) / 10);
    const key = `${x},${y}`;
    if (!seen.has(key)) {
      seen.add(key);
      coords.push([x, y]);
    }
  }
  if (coords.length < 3) return '';
  return coords.map(([x, y], index) => `${index ? 'L' : 'M'}${x} ${y}`).join('') + 'Z';
}

const provinces = data.features.map(feature => {
  const geometry = feature.geometry;
  const polygons = geometry.type === 'Polygon' ? [geometry.coordinates] : geometry.coordinates;
  const paths = polygons.map(polygon => polygon.map(ringToPath).filter(Boolean).join('')).filter(Boolean);
  return { name: feature.properties.name, path: paths.join(' ') };
}).filter(province => province.path);

const payload = {
  width: WIDTH,
  height: HEIGHT,
  source: 'DataV 行政区划 GeoJSON',
  projection: { minLon, maxLon, minMerc: minY, maxMerc: maxY, scale, offsetX, offsetY },
  provinces
};
fs.writeFileSync(
  outputPath,
  `/* 自动生成；底图来源：DataV 行政区划 GeoJSON；仅作现代地理定位 */\nwindow.DAM_CHINA_MAP=${JSON.stringify(payload)};\n`,
  'utf8'
);
console.log(JSON.stringify({
  output: outputPath,
  bytes: fs.statSync(outputPath).size,
  provinces: provinces.length,
  sourcePoints: points.length
}, null, 2));
