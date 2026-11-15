/* ============================================================
   stats.js — M3 统计：各期战役数 / 类型分布 / 每百年密度 / 胜负
   全部基于 www/data/ 实时计算，SVG + CSS 零依赖
   ============================================================ */

import { esc, icon, emptyStateHTML } from './ui.js';
import { TYPES } from './store.js';
import { navigate } from './router.js';
import { initOdometer, initChartGrowth } from './motion.js';

const TYPE_COLORS = ['#D98C7C', '#E0C060', '#7E8F72', '#B23A2E', '#A9A08C', '#C08A4A'];

function computeStats(data) {
  const battles = data.battles;

  const eraCounts = data.sections.map(({ era, battles: list }) => ({
    era,
    count: list.length,
    span: Math.max(1, era.endYear - era.startYear),
  }));

  const typeCounts = TYPES.map((type, i) => ({
    type,
    color: TYPE_COLORS[i],
    count: battles.filter((b) => b.type.includes(type)).length,
  })).filter((t) => t.count > 0);

  const winner = { A: 0, B: 0, draw: 0, truce: 0, none: 0 };
  battles.forEach((b) => {
    winner[b.result.winner] = (winner[b.result.winner] || 0) + 1;
  });

  const minYear = Math.min(...battles.map((b) => b.startYear));
  const maxYear = Math.max(...battles.map((b) => b.startYear));
  const binStart = Math.floor(minYear / 100) * 100;
  const binEnd = Math.ceil(maxYear / 100) * 100;
  const bins = [];
  for (let y = binStart; y <= binEnd; y += 100) bins.push({ year: y, count: 0 });
  battles.forEach((b) => {
    const idx = Math.min(bins.length - 1, Math.max(0, Math.floor((b.startYear - binStart) / 100)));
    bins[idx].count += 1;
  });

  const withTroops = battles.filter((b) => b.sides.length === 2 && b.sides.every((s) => s.troopsNum > 0));
  const upsets = withTroops.filter((b) => {
    if (b.result.winner !== 'A' && b.result.winner !== 'B') return false;
    const win = b.sides[b.result.winner === 'A' ? 0 : 1];
    const lose = b.sides[b.result.winner === 'A' ? 1 : 0];
    return win.troopsNum < lose.troopsNum;
  });

  const deciding = battles.filter((b) => b.scale === '战略决战').length;
  const yearSpan = Math.max(...battles.map((b) => b.endYear)) - minYear;
  const peakBin = bins.reduce((a, b) => (b.count > a.count ? b : a), bins[0]);

  return {
    eraCounts,
    typeCounts,
    winner,
    bins,
    peakBin,
    withTroops: withTroops.length,
    upsets: upsets.length,
    upsetRate: withTroops.length ? Math.round((upsets.length / withTroops.length) * 100) : 0,
    deciding,
    total: battles.length,
    eraCount: data.eras.length,
    yearSpan,
  };
}

/* ---------------- 图表 ---------------- */
function eraBarsHTML(stats) {
  const max = Math.max(...stats.eraCounts.map((e) => e.count), 1);
  return `<div class="st-bars" role="img" aria-label="各时期战役数量柱状图，共 ${stats.total} 场">${stats.eraCounts
    .map(
      ({ era, count }) => `<div class="st-bar-item" title="${esc(era.name)} ${count} 场">
        <span class="st-bar-count">${count}</span>
        <span class="st-bar-track"><i class="st-bar" style="height:${Math.max(6, Math.round((count / max) * 100))}%;--era:${esc(
        era.themeColor
      )}"></i></span>
        <span class="st-bar-label">${esc(era.short || era.name)}</span>
      </div>`
    )
    .join('')}</div>`;
}

function donutHTML(stats) {
  const total = stats.typeCounts.reduce((s, t) => s + t.count, 0) || 1;
  const R = 52;
  const C = 2 * Math.PI * R;
  let offset = 0;
  const segments = stats.typeCounts
    .map((t) => {
      const len = (t.count / total) * C;
      const seg = `<circle class="st-donut-seg" cx="80" cy="80" r="${R}" fill="none" stroke="${t.color}" stroke-width="15"
        stroke-dasharray="${(len - 2.4).toFixed(2)} ${(C - len + 2.4).toFixed(2)}"
        stroke-dashoffset="${(-offset).toFixed(2)}" transform="rotate(-90 80 80)"/>`;
      offset += len;
      return seg;
    })
    .join('');
  return `<div class="st-donut-wrap">
    <svg class="st-donut" viewBox="0 0 160 160" role="img" aria-label="战役类型分布">
      <circle cx="80" cy="80" r="${R}" fill="none" stroke="rgba(233,223,200,0.06)" stroke-width="15"/>
      ${segments}
      <text x="80" y="76" text-anchor="middle" class="st-donut-num">${stats.total}</text>
      <text x="80" y="94" text-anchor="middle" class="st-donut-label">场战役</text>
    </svg>
    <ul class="st-legend">${stats.typeCounts
      .map(
        (t) => `<li><i style="background:${t.color}"></i><span>${esc(t.type)}</span><b>${t.count}</b><em>${Math.round(
          (t.count / total) * 100
        )}%</em></li>`
      )
      .join('')}</ul>
  </div>`;
}

function densityHTML(stats) {
  const W = 340;
  const H = 150;
  const ml = 26;
  const mr = 10;
  const mt = 12;
  const mb = 26;
  const n = stats.bins.length;
  const max = Math.max(...stats.bins.map((b) => b.count), 1);
  const plotW = W - ml - mr;
  const plotH = H - mt - mb;
  const x = (i) => ml + (n === 1 ? plotW / 2 : (i / (n - 1)) * plotW);
  const y = (count) => mt + plotH - (count / max) * plotH;
  const points = stats.bins.map((b, i) => `${x(i).toFixed(1)},${y(b.count).toFixed(1)}`);
  const line = points.join(' ');
  const area = `M${x(0).toFixed(1)} ${(mt + plotH).toFixed(1)} L${line.replace(/ /g, ' L')} L${x(n - 1).toFixed(
    1
  )} ${(mt + plotH).toFixed(1)} Z`;
  const ticks = [-2000, -1000, 0, 1000, 2000].filter((yv) => yv >= stats.bins[0].year && yv <= stats.bins[n - 1].year);

  return `<div class="st-chart-wrap">
    <svg class="st-chart" viewBox="0 0 ${W} ${H}" role="img" aria-label="每百年战役数量折线图">
      <defs>
        <linearGradient id="stDensityFill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="#C94B3A" stop-opacity="0.34"/>
          <stop offset="1" stop-color="#C94B3A" stop-opacity="0"/>
        </linearGradient>
      </defs>
      <g class="st-grid">
        <line x1="${ml}" y1="${mt}" x2="${ml}" y2="${mt + plotH}"/>
        <line x1="${ml}" y1="${mt + plotH}" x2="${W - mr}" y2="${mt + plotH}"/>
        ${[0.5, 1]
          .map((f) => `<line x1="${ml}" y1="${y(max * f).toFixed(1)}" x2="${W - mr}" y2="${y(max * f).toFixed(1)}" stroke-dasharray="2 4"/>`)
          .join('')}
      </g>
      <path d="${area}" class="st-area" fill="url(#stDensityFill)"/>
      <polyline points="${line}" class="st-line"/>
      ${stats.bins
        .map((b, i) =>
          b.count > 0
            ? `<circle cx="${x(i).toFixed(1)}" cy="${y(b.count).toFixed(1)}" r="2.1" class="st-dot"/>`
            : ''
        )
        .join('')}
      <g class="st-axis">
        ${ticks
          .map((yv) => {
            const idx = Math.round((yv - stats.bins[0].year) / 100);
            if (idx <= 0 || idx >= n - 1) return '';
            return `<text x="${x(idx).toFixed(1)}" y="${H - 8}" text-anchor="middle">${yv < 0 ? '前' + Math.abs(yv) : yv}</text>`;
          })
          .join('')}
        <text x="${ml - 6}" y="${y(max).toFixed(1) + 3}" text-anchor="end">${max}</text>
        <text x="${ml - 6}" y="${(mt + plotH).toFixed(1)}" text-anchor="end">0</text>
      </g>
    </svg>
    <p class="st-chart-caption">范围：约前 2600 — 2026 年；峰值：${
      stats.peakBin.year < 0 ? '公元前' + Math.abs(stats.peakBin.year) : stats.peakBin.year
    } 年代起的一百年内 ${stats.peakBin.count} 场</p>
  </div>`;
}

function outcomeHTML(stats) {
  const w = stats.winner;
  const total = stats.total || 1;
  const parts = [
    { key: 'A', label: 'A 方胜', color: '#C94B3A', count: w.A },
    { key: 'B', label: 'B 方胜', color: '#C9A227', count: w.B },
    { key: 'draw', label: '平局', color: '#6F7B66', count: w.draw },
    { key: 'truce', label: '言和', color: '#9C907B', count: w.truce },
    { key: 'none', label: '未决', color: '#4A4237', count: w.none },
  ].filter((p) => p.count > 0);

  return `<div class="st-outcome">
    <div class="st-stack" role="img" aria-label="胜负分布">
      ${parts
        .map(
          (p) =>
            `<span class="st-stack-seg" style="width:${((p.count / total) * 100).toFixed(2)}%;background:${p.color}" title="${p.label} ${p.count} 场"></span>`
        )
        .join('')}
    </div>
    <ul class="st-outcome-legend">${parts
      .map(
        (p) =>
          `<li><i style="background:${p.color}"></i>${esc(p.label)}<b>${p.count}</b><em>${Math.round(
            (p.count / total) * 100
          )}%</em></li>`
      )
      .join('')}</ul>
    <div class="st-highlights">
      <div class="st-highlight">
        <b>${stats.upsets}</b><span>场以少胜多</span>
        <em>占可统计场次 ${stats.upsetRate}%（共 ${stats.withTroops} 场双方兵力数字可考）</em>
      </div>
      <div class="st-highlight">
        <b>${stats.deciding}</b><span>场战略决战</span>
        <em>占全部 ${Math.round((stats.deciding / stats.total) * 100)}%</em>
      </div>
    </div>
    <p class="st-outcome-note">胜负口径：以数据中 result.winner 为准；以少胜多以双方 troopsNum 均可考、且胜方兵力少于败方的场次统计。</p>
  </div>`;
}

function pageHTML(ctx, stats) {
  const spanText = (Math.round(stats.yearSpan / 100) * 100).toLocaleString('zh-CN');
  return `<div class="stats-page">
    <header class="page-head">
      <div class="head-title">统计<span class="head-sub">${stats.total} 场 · 实时计算</span></div>
      <div class="head-actions">
        <button class="icon-btn" type="button" data-action="search" aria-label="搜索">${icon('search')}</button>
      </div>
    </header>
    <div class="st-body">
      <section class="st-overview">
        <div class="st-ov-item"><b>${stats.total}</b><i>场战役</i></div>
        <div class="st-ov-item"><b>${stats.eraCount}</b><i>个时期</i></div>
        <div class="st-ov-item"><b>${spanText}</b><i>年跨度</i></div>
        <div class="st-ov-item"><b>${stats.upsetRate}%</b><i>以少胜多率</i></div>
      </section>

      <section class="st-panel">
        <h2 class="st-title">各期战役数<span>按时间由远及近</span></h2>
        ${eraBarsHTML(stats)}
      </section>

      <section class="st-panel">
        <h2 class="st-title">战役类型分布<span>一场可属多类</span></h2>
        ${donutHTML(stats)}
      </section>

      <section class="st-panel">
        <h2 class="st-title">每百年战事密度<span>约 ${spanText} 年 · ${stats.bins.length} 个百年区间</span></h2>
        ${densityHTML(stats)}
      </section>

      <section class="st-panel">
        <h2 class="st-title">胜负与以少胜多<span>结果口径来自数据标注</span></h2>
        ${outcomeHTML(stats)}
      </section>

      <p class="st-foot">统计口径与《山河战纪》数据契约一致；传说场次（如涿鹿）与争议兵力数字不作为精确统计依据，详见各战役「史料与争议」。</p>
    </div>
  </div>`;
}

export function renderStats(root, ctx) {
  if (!ctx.data || !ctx.data.ok || !ctx.data.battles.length) {
    root.innerHTML = `<div class="stats-page">
      <header class="page-head">
        <div class="head-title">统计<span class="head-sub">数据准备中</span></div>
      </header>
      <div class="page-body">${emptyStateHTML({
        title: '暂无数字可纪',
        desc: '战役数据尚未就绪，统计图表无法计算。请稍后重试，或先回到时间轴阅读。',
        actions: '<button class="btn btn--gold" type="button" data-action="retry">重新载入</button><button class="btn" type="button" data-action="home">回到时间轴</button>',
      })}</div>
    </div>`;
    root.querySelector('[data-action="retry"]')?.addEventListener('click', () => window.location.reload());
    root.querySelector('[data-action="home"]')?.addEventListener('click', () => navigate('/'));
    return;
  }
  const stats = computeStats(ctx.data);
  root.innerHTML = pageHTML(ctx, stats);
  root.querySelector('[data-action="search"]').addEventListener('click', () => navigate('/search'));

  // ---------- 2.2 动效：数字 odometer / 图表生长 ----------
  initOdometer(root, '.st-ov-item b');
  initOdometer(root, '.st-donut-num');
  initChartGrowth(root);
}

export function disposeStats() {}
