/* ============================================================
   store.js — 本地设置 / 筛选状态 / 最近浏览（localStorage 持久化）
   ============================================================ */

const SETTINGS_KEY = 'shj.settings.v1';
const RECENT_KEY = 'shj.recent.v1';

export const TYPES = ['统一战争', '抵御外侮', '农民起义', '王朝内战', '边疆经略', '事变'];

const DEFAULTS = { font: 'std', motion: 'full' };
let settings = { ...DEFAULTS };

function systemPrefersReducedMotion() {
  try {
    return window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  } catch (err) {
    return false;
  }
}

export function loadSettings() {
  settings = { ...DEFAULTS };
  // 首次进入且系统开启「减弱动效」时，默认跟随系统
  if (systemPrefersReducedMotion()) settings.motion = 'reduce';
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      if (['sm', 'std', 'lg'].includes(parsed.font)) settings.font = parsed.font;
      if (['full', 'reduce'].includes(parsed.motion)) settings.motion = parsed.motion;
    }
  } catch (err) {
    /* 隐私模式 / file:// 下 localStorage 可能不可用，静默降级 */
  }
  applySettings();
  return settings;
}

export function getSettings() {
  return settings;
}

export function updateSetting(key, value) {
  settings = { ...settings, [key]: value };
  try {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  } catch (err) {
    /* 静默降级 */
  }
  applySettings();
}

export function resetSettings() {
  settings = { ...DEFAULTS };
  try {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  } catch (err) {
    /* 静默降级 */
  }
  applySettings();
}

export function applySettings() {
  const html = document.documentElement;
  html.dataset.font = settings.font;
  html.dataset.motion = settings.motion;
}

/* ---------------- 筛选状态 ---------------- */
export const filters = {
  eras: [],
  types: [],
};

export function hasFilters() {
  return filters.eras.length > 0 || filters.types.length > 0;
}

export function clearFilters() {
  filters.eras = [];
  filters.types = [];
}

export function filterCountText() {
  const parts = [];
  if (filters.eras.length) parts.push(`${filters.eras.length} 个时期`);
  if (filters.types.length) parts.push(`${filters.types.length} 个类型`);
  return parts.join(' · ');
}

/* ---------------- 最近浏览 ---------------- */
export function loadRecent() {
  try {
    const raw = localStorage.getItem(RECENT_KEY);
    const list = raw ? JSON.parse(raw) : [];
    return Array.isArray(list) ? list.filter((x) => typeof x === 'string').slice(0, 8) : [];
  } catch (err) {
    return [];
  }
}

export function pushRecent(id) {
  if (!id) return;
  const list = loadRecent().filter((x) => x !== id);
  list.unshift(id);
  try {
    localStorage.setItem(RECENT_KEY, JSON.stringify(list.slice(0, 8)));
  } catch (err) {
    /* 静默降级 */
  }
}
