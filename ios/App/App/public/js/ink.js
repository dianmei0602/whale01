/* ============================================================
   ink.js — 程序化水墨山形 / 印章纹理 的 SVG 生成器（无外链）
   ============================================================ */

function hashSeed(str) {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function mulberry32(a) {
  return function () {
    a |= 0;
    a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function ridge(rnd, W, H, baseY, amp, steps) {
  const pts = [];
  for (let i = 0; i <= steps; i++) {
    const x = (i * W) / steps;
    const t = i / steps;
    const env = Math.sin(Math.PI * Math.min(1, 0.08 + t * 0.92));
    const jag = 0.28 + rnd() * 0.72;
    const y = baseY - amp * jag * (0.35 + env * 0.65);
    pts.push([x, y]);
  }
  let d = `M0 ${H} L0 ${pts[0][1].toFixed(1)}`;
  for (const [x, y] of pts) d += ` L${x.toFixed(1)} ${y.toFixed(1)}`;
  d += ` L${W} ${H} Z`;
  return d;
}

/**
 * 生成水墨山形 Hero。
 * @param {string} seed 决定山形与日月的种子（如战役 id）
 * @param {object} opts { height, accent, disc: 'moon'|'sun', dark }
 */
export function inkMountain(seed, opts = {}) {
  const { height = 420, accent = '#E0C060', disc = 'moon', transparent = false } = opts;
  const uid = 'ink' + (hashSeed(String(seed)) % 100000);
  const rnd = mulberry32(hashSeed(String(seed) + ':v1'));
  const W = 390;
  const H = height;

  const sunX = 250 + rnd() * 90;
  const sunY = 58 + rnd() * 54;
  const sunR = 22 + rnd() * 12;
  const discColor = disc === 'sun' ? '#C94B3A' : '#E0C060';

  const far = ridge(rnd, W, H, H * 0.6, H * 0.3, 13);
  const mid = ridge(rnd, W, H, H * 0.76, H * 0.26, 11);
  const near = ridge(rnd, W, H, H * 0.94, H * 0.3, 9);

  return `<svg class="ink-svg" viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMax slice" aria-hidden="true" focusable="false">
  <defs>
    <linearGradient id="${uid}sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#211B14"/>
      <stop offset="0.55" stop-color="#15120E"/>
      <stop offset="1" stop-color="#0C0A08"/>
    </linearGradient>
    <radialGradient id="${uid}disc" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="${discColor}" stop-opacity="0.92"/>
      <stop offset="0.55" stop-color="${discColor}" stop-opacity="0.4"/>
      <stop offset="1" stop-color="${discColor}" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="${uid}far" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#E9DFC8" stop-opacity="0.17"/>
      <stop offset="0.55" stop-color="#E9DFC8" stop-opacity="0.05"/>
      <stop offset="1" stop-color="#0E0C0A" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="${uid}mid" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#E9DFC8" stop-opacity="0.11"/>
      <stop offset="1" stop-color="#0E0C0A" stop-opacity="0.2"/>
    </linearGradient>
    <linearGradient id="${uid}rim" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="${accent}" stop-opacity="0"/>
      <stop offset="0.5" stop-color="${accent}" stop-opacity="0.5"/>
      <stop offset="1" stop-color="${accent}" stop-opacity="0"/>
    </linearGradient>
    <filter id="${uid}rough" x="-8%" y="-8%" width="116%" height="116%">
      <feTurbulence type="fractalNoise" baseFrequency="0.018" numOctaves="3" seed="${hashSeed(seed) % 97}" result="t"/>
      <feDisplacementMap in="SourceGraphic" in2="t" scale="8" xChannelSelector="R" yChannelSelector="G"/>
    </filter>
    <filter id="${uid}blur" x="-30%" y="-60%" width="160%" height="220%">
      <feGaussianBlur stdDeviation="13"/>
    </filter>
    <filter id="${uid}grain" x="0" y="0" width="100%" height="100%">
      <feTurbulence type="fractalNoise" baseFrequency="0.75" numOctaves="3" stitchTiles="stitch"/>
      <feColorMatrix type="saturate" values="0"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.075"/></feComponentTransfer>
    </filter>
  </defs>

  <rect width="${W}" height="${H}" fill="url(#${uid}sky)"${transparent ? ' opacity="0"' : ''}/>
  <circle cx="${sunX.toFixed(0)}" cy="${sunY.toFixed(0)}" r="${(sunR * 3.6).toFixed(0)}" fill="url(#${uid}disc)" opacity="0.45"/>
  <circle cx="${sunX.toFixed(0)}" cy="${sunY.toFixed(0)}" r="${sunR.toFixed(0)}" fill="${discColor}" opacity="0.5"/>
  <circle cx="${sunX.toFixed(0)}" cy="${sunY.toFixed(0)}" r="${(sunR * 0.86).toFixed(0)}" fill="#F6E7B8" opacity="0.36"/>
  <circle cx="${sunX.toFixed(0)}" cy="${sunY.toFixed(0)}" r="${(sunR * 0.5).toFixed(0)}" fill="#FBF0CE" opacity="0.3"/>

  <g filter="url(#${uid}rough)">
    <path d="${far}" fill="url(#${uid}far)"/>
    <path d="${mid}" fill="url(#${uid}mid)"/>
    <path d="${mid}" fill="none" stroke="url(#${uid}rim)" stroke-width="1" opacity="0.55"/>
    <path d="${near}" fill="#070605" opacity="0.94"/>
    <path d="${near}" fill="none" stroke="url(#${uid}rim)" stroke-width="0.8" opacity="0.5"/>
  </g>

  <ellipse cx="${(W * 0.3).toFixed(0)}" cy="${(H * 0.68).toFixed(0)}" rx="${(W * 0.45).toFixed(0)}" ry="${(H * 0.045).toFixed(0)}" fill="#E9DFC8" opacity="0.06" filter="url(#${uid}blur)"/>
  <ellipse cx="${(W * 0.72).toFixed(0)}" cy="${(H * 0.82).toFixed(0)}" rx="${(W * 0.4).toFixed(0)}" ry="${(H * 0.035).toFixed(0)}" fill="#E9DFC8" opacity="0.05" filter="url(#${uid}blur)"/>
  ${transparent ? '' : `<rect width="${W}" height="${H}" filter="url(#${uid}grain)" opacity="0.6"/>`}
</svg>`;
}

/** 空态小山水 */
export function inkEmpty() {
  return inkMountain('empty-state', { height: 150, accent: '#C9A227', disc: 'sun', transparent: true });
}
