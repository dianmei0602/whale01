/* ============================================================
   ui.js — 通用工具：转义 / 图标 / 印章 / 年份 / 高亮 / Toast
   ============================================================ */

import { inkEmpty } from './ink.js';

export const esc = (value) =>
  String(value == null ? '' : value).replace(/[&<>"']/g, (ch) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  }[ch]));

/* ---------------- 线性图标（手写 SVG path，无图标库） ---------------- */
const ICONS = {
  search: '<circle cx="10.5" cy="10.5" r="6.5"/><path d="m15.5 15.5 4.5 4.5"/>',
  filter: '<path d="M4 7h10M18 7h2M4 17h2M10 17h10"/><circle cx="16" cy="7" r="2"/><circle cx="8" cy="17" r="2"/>',
  back: '<path d="M14.5 5 8 12l6.5 7"/>',
  forward: '<path d="M9.5 5 16 12l-6.5 7"/>',
  close: '<path d="m6 6 12 12M18 6 6 18"/>',
  down: '<path d="M12 4v14m0 0 5-5m-5 5-5-5"/>',
  chevron: '<path d="m6 9 6 6 6-6"/>',
  pin: '<path d="M12 21s6.5-6.1 6.5-11a6.5 6.5 0 1 0-13 0C5.5 14.9 12 21 12 21Z"/><circle cx="12" cy="10" r="2.3"/>',
  book: '<path d="M4 5.5c2.5-1 5.2-1 8 0v14c-2.8-1-5.5-1-8 0z"/><path d="M20 5.5c-2.5-1-5.2-1-8 0v14c2.8-1 5.5-1 8 0z"/>',
  compass: '<circle cx="12" cy="12" r="8"/><path d="m14.8 9.2-1.6 4-4 1.6 1.6-4z"/>',
  check: '<path d="m5 12.5 4.5 4.5L19 7"/>',
  refresh: '<path d="M20 11a8 8 0 1 0-2.3 6.3"/><path d="M20 4.5V11h-6.5"/>',
  arrow: '<path d="M5 12h13m0 0-5-5m5 5-5 5"/>',
  scroll: '<path d="M7 4h10v16H7z"/><path d="M9.5 4v16M14.5 4v16M7 9h10"/>',
  user: '<circle cx="12" cy="8" r="3.5"/><path d="M5 20c.8-3.6 3.6-5.5 7-5.5s6.2 1.9 7 5.5"/>',
  layers: '<path d="m12 4 8 4.5-8 4.5-8-4.5z"/><path d="m4 13 8 4.5 8-4.5"/>',
  gauge: '<path d="M4 17a8 8 0 1 1 16 0"/><path d="m12 13 4-4"/><circle cx="12" cy="17" r="1.4" fill="currentColor" stroke="none"/>',
  mountain: '<path d="M3 19 9 8l4 6 3-4 5 9z"/><path d="M3 19h18"/>',
  share: '<path d="M12 15V4m0 0-4 4m4-4 4 4"/><path d="M5 13v6h14v-6"/>',
};

export function icon(name, cls = '') {
  const body = ICONS[name] || '';
  const filled = name === 'compass' ? '' : '';
  return `<svg class="${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">${body}${filled}</svg>`;
}

/* ---------------- 印章 ---------------- */
export function seal(text, { size = 'sm', vertical = true, cls = '' } = {}) {
  return `<span class="seal seal--${size}${vertical ? ' seal--v' : ''}${cls ? ' ' + cls : ''}">${esc(text)}</span>`;
}

/* ---------------- 结果 / 阵营 ---------------- */
export function shortSide(name) {
  let s = String(name || '')
    .replace(/[（(][^）)]*[）)]/g, '')
    .replace(/\s+/g, '');
  if (s.includes('志愿军')) return '志愿';
  s = s.replace(/(联军|军队|大军|兵团|方面军|集团军|军|部)$/u, '');
  return s.slice(0, 2) || String(name || '').slice(0, 2);
}

export function resultSealText(battle) {
  const winner = battle?.result?.winner;
  if (winner === 'A' || winner === 'B') {
    const side = battle.sides?.[winner === 'A' ? 0 : 1];
    return shortSide(side?.name) + '胜';
  }
  if (winner === 'draw') return '平局';
  if (winner === 'truce') return '言和';
  return '未决';
}

/** 卡片用小印章：上方阵营短名，下方「胜」字（竖排文字在 40px 内会换行，故用两行排版） */
export function verdictSeal(battle) {
  const winner = battle?.result?.winner;
  if (winner === 'A' || winner === 'B') {
    const side = battle.sides?.[winner === 'A' ? 0 : 1];
    return `<span class="seal seal--sm card-seal seal--verdict">
      <span class="sv-side">${esc(shortSide(side?.name))}</span>
      <span class="sv-verdict">胜</span>
    </span>`;
  }
  const word = winner === 'draw' ? '平' : winner === 'truce' ? '和' : '未';
  return `<span class="seal seal--sm card-seal seal--verdict is-single"><span class="sv-verdict">${word}</span></span>`;
}


export function resultText(battle) {
  return battle?.result?.text || '';
}

/* ---------------- 年份 ---------------- */
export function fmtYear(y) {
  if (typeof y !== 'number' || Number.isNaN(y)) return '';
  return y < 0 ? `前${Math.abs(y)}` : String(y);
}

export function fmtYearFull(y) {
  if (typeof y !== 'number' || Number.isNaN(y)) return '';
  return y < 0 ? `公元前${Math.abs(y)}年` : `公元${y}年`;
}

/** 卡片大号年份标记 */
export function yearMarkup(battle) {
  const s = battle.startYear;
  const e = battle.endYear ?? s;
  if (s < 0 && e < 0 && e !== s) {
    return `<span class="y-pre">前</span><span class="y-range">${Math.abs(s)}<span class="y-dash">—</span>${Math.abs(e)}</span>`;
  }
  if (s < 0) return `<span class="y-pre">前</span><span class="y-num">${Math.abs(s)}</span>`;
  if (e !== s) {
    return `<span class="y-range">${s}<span class="y-dash">—</span>${String(e).slice(-2)}</span>`;
  }
  return `<span class="y-num">${s}</span>`;
}

export function eraStartText(era) {
  const raw = String(era.rangeText || '').split('—')[0].trim();
  return raw || fmtYearFull(era.startYear);
}

export function fmtTroops(n) {
  if (!n && n !== 0) return '';
  if (n >= 10000) {
    const w = n / 10000;
    return `${Number.isInteger(w) ? w : w.toFixed(1)}万`;
  }
  return String(n);
}

/* ---------------- 搜索高亮 ---------------- */
export function highlight(text, query) {
  const s = String(text == null ? '' : text);
  const q = String(query || '').trim();
  if (!q) return esc(s);
  const safe = q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const re = new RegExp(`(${safe})`, 'gi');
  return s
    .split(re)
    .map((part, i) => (i % 2 ? `<mark>${esc(part)}</mark>` : esc(part)))
    .join('');
}

/* ---------------- Toast ---------------- */
let toastTimer = 0;
export function toast(message, duration = 2200) {
  const el = document.getElementById('toast');
  if (!el) return;
  el.textContent = message;
  el.style.setProperty('--toast-dur', `${duration}ms`);
  el.classList.remove('is-visible');
  void el.offsetWidth;
  el.classList.add('is-visible');
  clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => el.classList.remove('is-visible'), duration);
}

/* ---------------- 其他 ---------------- */
export function debounce(fn, wait = 120) {
  let t = 0;
  const wrapped = (...args) => {
    clearTimeout(t);
    t = window.setTimeout(() => fn(...args), wait);
  };
  wrapped.cancel = () => clearTimeout(t);
  return wrapped;
}

export function emptyStateHTML({ title = '暂无内容', desc = '', actions = '' } = {}) {
  return `<div class="empty-state">
    <div class="empty-art">${inkEmpty()}</div>
    <h3>${esc(title)}</h3>
    <p>${esc(desc)}</p>
    ${actions ? `<div class="empty-actions">${actions}</div>` : ''}
  </div>`;
}
