/* ============================================================
   legend.js — 3.2 P1 #/legend 图例与读图
   5 节：时间轴 / 地图 / 关系图谱 / 甘特（势力时间带）/ 家族谱
   静态读图说明，锚点 #timeline #map #graph #gantt #family
   ============================================================ */

import { esc, icon } from './ui.js';
import { navigate, navigateBack } from './router.js';

const CSS_HREF = 'css/legend.css';
let cssLoaded = false;

function ensureCss() {
  if (cssLoaded || document.querySelector(`link[href="${CSS_HREF}"]`)) {
    cssLoaded = true;
    return;
  }
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = CSS_HREF;
  document.head.appendChild(link);
  cssLoaded = true;
}

const REL_TYPES = [
  ['父子', '#C94B3A', ''],
  ['兄弟', '#E0C060', ''],
  ['舅甥', '#C08A4A', ''],
  ['师徒', '#7E8F72', ''],
  ['君臣', '#C9A227', '6 4'],
  ['同僚', '#9C907B', ''],
  ['盟友', '#6F7B66', ''],
  ['对手', '#C94B3A', '5 5'],
  ['举荐', '#A9A08C', '2 4'],
  ['姻亲', '#D98C7C', '2 3'],
  ['世交', '#B8783A', '8 4 2 4'],
];

function svgWrap(label, inner, h = 120) {
  return `<svg class="lg-svg" viewBox="0 0 320 ${h}" role="img" aria-label="${esc(label)}">${inner}</svg>`;
}

function timelineDemo() {
  return svgWrap(
    '时间轴图例示意',
    `<line x1="24" y1="22" x2="296" y2="22" stroke="rgba(201,162,39,.3)" stroke-width="1"/>
     <circle cx="54" cy="22" r="4" fill="#0E0C0A" stroke="#C9A227" stroke-width="1.2"/>
     <circle cx="122" cy="22" r="4" fill="#B23A2E" stroke="#E08A78" stroke-width="1.2"/>
     <rect x="118" y="26" width="8" height="8" transform="rotate(45 122 30)" fill="rgba(201,162,39,.3)" stroke="#E0C060" stroke-width="1"/>
     <rect x="190" y="12" width="20" height="20" rx="2" fill="rgba(178,58,46,.3)" stroke="rgba(178,58,46,.8)"/>
     <text x="200" y="26" text-anchor="middle" font-size="10" fill="#E9DFC8">胜</text>
     <rect x="236" y="14" width="42" height="16" rx="2" fill="none" stroke="rgba(233,223,200,.3)"/>
     <text x="257" y="26" text-anchor="middle" font-size="9" fill="#9C907B">类型</text>
     <text x="54" y="52" text-anchor="middle" font-size="10" fill="#9C907B">战役节点</text>
     <text x="122" y="52" text-anchor="middle" font-size="10" fill="#9C907B">戈形 · 决战</text>
     <text x="200" y="52" text-anchor="middle" font-size="10" fill="#9C907B">结果印章</text>
     <text x="257" y="52" text-anchor="middle" font-size="10" fill="#9C907B">类型标签</text>
     <line x1="24" y1="72" x2="296" y2="72" stroke="rgba(233,223,200,.1)"/>
     <text x="24" y="90" font-size="10" fill="rgba(233,223,200,.65)">滚动时期高亮：吸顶时期条随滚动切换当前期</text>`
  );
}

function mapDemo() {
  return svgWrap(
    '地图图例示意',
    `<rect x="22" y="12" width="276" height="86" rx="4" fill="rgba(20,17,13,.7)" stroke="rgba(201,162,39,.18)"/>
     <circle cx="62" cy="42" r="5" fill="rgba(178,58,46,.28)"/><circle cx="62" cy="42" r="3" fill="#B23A2E"/>
     <circle cx="122" cy="42" r="7" fill="none" stroke="#E0C060" stroke-width="1.6"/><circle cx="122" cy="42" r="3.5" fill="#B23A2E"/>
     <circle cx="182" cy="42" r="3.5" fill="#0E0C0A" stroke="#9C907B" stroke-width="1" stroke-dasharray="2 2"/>
     <circle cx="226" cy="42" r="9" fill="rgba(178,58,46,.22)" stroke="#C94B3A"/><text x="226" y="45" text-anchor="middle" font-size="8" fill="#E9DFC8">6</text>
     <rect x="250" y="34" width="22" height="14" fill="rgba(111,123,102,.4)" stroke="rgba(111,123,102,.6)"/>
     <text x="62" y="65" text-anchor="middle" font-size="9" fill="#9C907B">战役点</text>
     <text x="122" y="65" text-anchor="middle" font-size="9" fill="#9C907B">决战环</text>
     <text x="182" y="65" text-anchor="middle" font-size="9" fill="#9C907B">境外示意</text>
     <text x="226" y="65" text-anchor="middle" font-size="9" fill="#9C907B">聚合</text>
     <text x="272" y="65" text-anchor="middle" font-size="8" fill="#9C907B">势力范围</text>
     <text x="24" y="84" font-size="9" fill="rgba(233,223,200,.55)">比例尺 1:740 万 · 审图号 GS(2022)4307 号 · 位置精度 确/约/传说</text>`
  );
}

function graphDemo() {
  const cols = REL_TYPES.map(([name, color, dash], i) => {
    const x = 26 + (i % 2) * 150;
    const y = 20 + Math.floor(i / 2) * 17;
    return `<line x1="${x}" y1="${y}" x2="${x + 36}" y2="${y}" stroke="${color}" stroke-width="2" ${
      dash ? `stroke-dasharray="${dash}"` : ''
    }/><text x="${x + 44}" y="${y + 3}" font-size="9" fill="rgba(233,223,200,.72)">${name}</text>`;
  }).join('');
  return svgWrap(
    '关系图谱图例示意',
    `<rect x="18" y="8" width="284" height="104" rx="4" fill="rgba(20,17,13,.7)" stroke="rgba(201,162,39,.18)"/>${cols}
     <text x="26" y="108" font-size="9" fill="rgba(233,223,200,.55)">线宽表示关系强度 1–3；选中节点后关联边/对端提亮，其余降透明。</text>`
  );
}

function ganttDemo() {
  return svgWrap(
    '甘特图图例示意',
    `<line x1="112" y1="14" x2="112" y2="96" stroke="rgba(201,162,39,.18)" stroke-dasharray="2 6"/>
     <text x="112" y="10" text-anchor="middle" font-size="8" fill="#9C907B">时期线</text>
     <rect x="34" y="22" width="80" height="12" rx="3" fill="#8C6B4A"/>
     <rect x="120" y="22" width="64" height="12" rx="3" fill="#B23A2E"/>
     <rect x="120" y="48" width="150" height="12" rx="3" fill="#C9A227"/>
     <circle cx="142" cy="28" r="3" fill="#B23A2E"/>
     <circle cx="196" cy="54" r="3" fill="#B23A2E"/>
     <circle cx="196" cy="54" r="5.2" fill="none" stroke="#E0C060" stroke-width="1.4"/>
     <text x="34" y="52" font-size="8" fill="#9C907B">色条 = 国祚</text>
     <text x="34" y="66" font-size="8" fill="#9C907B">圆点 = 战役</text>
     <text x="34" y="80" font-size="8" fill="#9C907B">金环 = 战略决战</text>
     <text x="188" y="90" font-size="8" fill="rgba(233,223,200,.6)">点色条选势力；点圆点进战役详情</text>`
  );
}

function familyDemo() {
  return svgWrap(
    '家族谱图例示意',
    `<line x1="40" y1="30" x2="40" y2="90" stroke="rgba(201,162,39,.35)"/>
     <rect x="22" y="12" width="36" height="20" rx="2" fill="rgba(201,162,39,.1)" stroke="rgba(201,162,39,.4)"/>
     <text x="40" y="26" text-anchor="middle" font-size="9" fill="#E9DFC8">第一代</text>
     <rect x="22" y="46" width="36" height="20" rx="2" fill="rgba(201,162,39,.1)" stroke="rgba(201,162,39,.4)"/>
     <text x="40" y="60" text-anchor="middle" font-size="9" fill="#E9DFC8">第二代</text>
     <line x1="76" y1="56" x2="106" y2="56" stroke="rgba(233,223,200,.3)" stroke-dasharray="2 3"/>
     <text x="112" y="60" font-size="9" fill="#9C907B">承自（父子）</text>
     <line x1="40" y1="66" x2="40" y2="90" stroke="rgba(233,223,200,.2)" stroke-dasharray="2 3"/>
     <text x="128" y="90" font-size="9" fill="#9C907B">姻 · 联姻</text>
     <rect x="118" y="76" width="18" height="18" rx="2" fill="rgba(178,58,46,.18)" stroke="rgba(178,58,46,.5)"/>
     <text x="127" y="89" text-anchor="middle" font-size="9" fill="#E08A78">姻</text>`
  );
}

const SECTIONS = [
  {
    id: 'timeline',
    no: '壹',
    title: '时间轴',
    demo: timelineDemo,
    points: [
      '普通战役节点：朱砂细点；战略决战叠加戈形标记。',
      '卡片右上是结果印章（胜/败/平/和/未决），下方是类型标签。',
      '右侧时期条随滚动吸顶并高亮当前期；点击时期 chip 可跳转。',
    ],
  },
  {
    id: 'map',
    no: '贰',
    title: '地图',
    demo: mapDemo,
    points: [
      '战役点、战略决战环、境外示意点；低缩放时聚合为数字气泡。',
      '势力范围以省界色块示意，比例尺与审图号见地图页脚。',
      '位置精度分「确 / 约 / 传说」，摘要卡与详情页一致标注。',
    ],
  },
  {
    id: 'graph',
    no: '叁',
    title: '关系图谱',
    demo: graphDemo,
    points: [
      '11 类关系用颜色与线型区分：实线/虚线/点线，线宽表示强度。',
      '选中节点后，关联边与对端提亮，其余降透明；时代筛选可聚焦某一期。',
      '缩放 ≥1.2× 显示全部标签；节点可拖动，小传面板可跳战役。',
    ],
  },
  {
    id: 'gantt',
    no: '肆',
    title: '甘特（势力时间带）',
    demo: ganttDemo,
    points: [
      '横条表示国祚起止，颜色为势力色；竖向虚线为年代刻度（时期线）。',
      '圆点为该势力关联战役：普通朱砂点、战略决战为金色环。',
      '点击色条选中势力并定位卡片；点击战役节点直接进入战役详情。',
    ],
  },
  {
    id: 'family',
    no: '伍',
    title: '家族谱',
    demo: familyDemo,
    points: [
      '按世代自上而下排列；成员卡可进入关联名将小传。',
      '「承自」表示父子/继承关系；「姻」表示联姻记录（含年份与说明）。',
      '家族谱入口：势力详情「进入家族谱」或名将小传「所属家族」。',
    ],
  },
];

function pageHTML(route) {
  const anchor = route?.anchor || '';
  return `<div class="legend-page">
    <header class="page-head">
      <button class="icon-btn" type="button" data-action="back" aria-label="返回">${icon('back')}</button>
      <div class="head-title">图例与读图<span class="head-sub">5 节 · 墨金图例</span></div>
      <div class="head-actions">
        <button class="icon-btn" type="button" data-action="search" aria-label="搜索">${icon('search')}</button>
      </div>
    </header>

    <nav class="lg-nav no-scrollbar" aria-label="图例章节">
      ${SECTIONS.map(
        (s) =>
          `<a class="lg-nav-chip${anchor === s.id ? ' is-active' : ''}" href="#/legend#${s.id}">${
            s.id === 'gantt' ? '甘特' : s.title
          }</a>`
      ).join('')}
    </nav>

    <div class="legend-body">
      ${SECTIONS.map(
        (s) => `<section class="lg-sec" id="legend-${s.id}" data-anchor="${s.id}" aria-labelledby="lgTitle-${s.id}">
          <div class="lg-demo">${s.demo()}</div>
          <div class="lg-copy">
            <h2 class="lg-title" id="lgTitle-${s.id}"><span class="lg-no">${s.no}</span>${s.title}</h2>
            <ul class="lg-points">${s.points.map((p) => `<li>${esc(p)}</li>`).join('')}</ul>
          </div>
        </section>`
      ).join('')}

      <div class="lg-foot">
        <p>图例仅解释读图方式；数据口径与来源见各页面页脚。所有图形均为本地 SVG 绘制，无外链。</p>
        <a class="btn btn--ghost" href="#/map">去地图看图例应用</a>
      </div>
    </div>
  </div>`;
}

export function renderLegend(root, ctx, route) {
  ensureCss();
  root.innerHTML = pageHTML(route);
  root.querySelector('[data-action="back"]')?.addEventListener('click', () => navigateBack());
  root.querySelector('[data-action="search"]')?.addEventListener('click', () => navigate('/search'));
  const anchor = route?.anchor;
  if (anchor) {
    requestAnimationFrame(() => {
      const sec = document.getElementById(`legend-${anchor}`);
      if (sec) sec.scrollIntoView({ block: 'start', behavior: 'auto' });
    });
  }
}

export function disposeLegend() {}
