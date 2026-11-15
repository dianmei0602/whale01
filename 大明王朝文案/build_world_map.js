/* 把 Natural Earth 1:110m 国家边界转为离线 SVG 路径。
   底图仅用于现代地理定位，不代表明代疆域；运行时无需联网。 */
const fs = require('fs');
const path = require('path');

const base = __dirname;
const outputPath = path.join(path.dirname(base), '大明王朝iOS', 'world-map.js');
const sourceUrl = 'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_admin_0_countries.geojson';
const WIDTH = 960;
const HEIGHT = 720;
const MIN_LON = -180;
const MAX_LON = 180;
const MIN_LAT = -55;
const MAX_LAT = 80;
const MARGIN = 12;

const mercator = lat => Math.log(Math.tan(Math.PI / 4 + lat * Math.PI / 360));
const minMerc = mercator(MIN_LAT);
const maxMerc = mercator(MAX_LAT);
const scale = Math.min(
  (WIDTH - MARGIN * 2) / (2 * Math.PI),
  (HEIGHT - MARGIN * 2) / (maxMerc - minMerc)
);
const contentWidth = 2 * Math.PI * scale;
const contentHeight = (maxMerc - minMerc) * scale;
const offsetX = (WIDTH - contentWidth) / 2;
const offsetY = (HEIGHT - contentHeight) / 2;

function project([lon, lat]) {
  return [
    offsetX + (lon * Math.PI / 180 + Math.PI) * scale,
    offsetY + (maxMerc - mercator(lat)) * scale
  ];
}

function ringToPaths(ring) {
  const paths = [];
  let current = [];
  let previousLon = null;
  const flush = () => {
    if (current.length >= 3) {
      paths.push(current.map(([x, y], index) => `${index ? 'L' : 'M'}${x} ${y}`).join('') + 'Z');
    }
    current = [];
  };
  for (const point of ring) {
    const [lon, lat] = point;
    if (
      lon < MIN_LON ||
      lon > MAX_LON ||
      lat < MIN_LAT ||
      lat > MAX_LAT ||
      (previousLon !== null && Math.abs(lon - previousLon) > 180)
    ) {
      flush();
      previousLon = null;
    }
    if (lon < MIN_LON || lon > MAX_LON || lat < MIN_LAT || lat > MAX_LAT) continue;
    const [x, y] = project(point).map(value => Math.round(value * 10) / 10);
    current.push([x, y]);
    previousLon = lon;
  }
  flush();
  return paths;
}

async function main() {
  const response = await fetch(sourceUrl);
  if (!response.ok) throw new Error(`Natural Earth download failed: ${response.status}`);
  const data = await response.json();
  const countries = data.features
    .filter(feature => feature.properties.ADMIN !== 'Antarctica')
    .map(feature => {
      const geometry = feature.geometry;
      const polygons = geometry.type === 'Polygon' ? [geometry.coordinates] : geometry.coordinates;
      const paths = polygons
        .flatMap(polygon => polygon.flatMap(ringToPaths))
        .filter(Boolean);
      return {
        name: feature.properties.ADMIN || feature.properties.NAME || '',
        path: paths.join(' ')
      };
    })
    .filter(country => country.path);

  const payload = {
    width: WIDTH,
    height: HEIGHT,
    source: 'Natural Earth 1:110m Admin 0 Countries',
    sourceUrl,
    projection: {
      minLon: MIN_LON,
      maxLon: MAX_LON,
      minMerc,
      maxMerc,
      scale,
      offsetX,
      offsetY
    },
    countries
  };

  fs.writeFileSync(
    outputPath,
    `/* 自动生成；底图来源：Natural Earth Public Domain；现代国家仅作地理定位 */\nwindow.DAM_WORLD_MAP=${JSON.stringify(payload)};\n`,
    'utf8'
  );
  console.log(JSON.stringify({
    output: outputPath,
    bytes: fs.statSync(outputPath).size,
    countries: countries.length,
    sourceUrl
  }, null, 2));
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
