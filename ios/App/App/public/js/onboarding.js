/* ============================================================
   onboarding.js — 3.3 首启新手引导（3 步，仅时间轴首启一次）
   localStorage: shj.onboarded.v3
   ============================================================ */

import { esc } from './ui.js';

const KEY = 'shj.onboarded.v3';

const STEPS = [
  {
    kicker: '壹 / 叁',
    title: '顺着时间轴，读一部战史',
    desc: '卷首以 12 期为目录，120 场战役沿竖向时间轴铺开。点开任意卡片进入详情；右侧时期条会随滚动高亮。',
    art: `<svg viewBox="0 0 320 150" role="img" aria-label="时间轴示意">
      <line x1="64" y1="16" x2="64" y2="136" stroke="rgba(201,162,39,.35)" stroke-width="1.4"/>
      <circle cx="64" cy="34" r="4" fill="#0E0C0A" stroke="#C9A227"/>
      <circle cx="64" cy="72" r="5" fill="#B23A2E" stroke="#E0C060"/>
      <circle cx="64" cy="112" r="4" fill="#0E0C0A" stroke="#C9A227"/>
      <rect x="84" y="22" width="214" height="26" rx="3" fill="rgba(233,223,200,.04)" stroke="rgba(233,223,200,.12)"/>
      <rect x="84" y="58" width="214" height="30" rx="3" fill="rgba(178,58,46,.08)" stroke="rgba(178,58,46,.28)"/>
      <rect x="84" y="100" width="214" height="26" rx="3" fill="rgba(233,223,200,.04)" stroke="rgba(233,223,200,.12)"/>
      <text x="94" y="40" font-size="10" fill="#E9DFC8">逐鹿之战 · 前 2600</text>
      <text x="94" y="78" font-size="10" fill="#E9DFC8">赤壁之战 · 208</text>
      <text x="94" y="117" font-size="10" fill="#9C907B">上甘岭战役 · 1952</text>
      <rect x="266" y="66" width="20" height="20" rx="2" fill="rgba(178,58,46,.3)" stroke="#B23A2E"/>
      <text x="276" y="80" text-anchor="middle" font-size="9" fill="#E9DFC8">胜</text>
    </svg>`,
  },
  {
    kicker: '贰 / 叁',
    title: '地图与势力范围',
    desc: '地图把 120 场战役放回山河：点战役看摘要，点“势力范围”叠层看政权疆域。用 ? 打开地图图例。',
    art: `<svg viewBox="0 0 320 150" role="img" aria-label="地图示意">
      <rect x="18" y="12" width="284" height="126" rx="4" fill="rgba(21,18,14,.8)" stroke="rgba(201,162,39,.18)"/>
      <path d="M58 82c18-26 42-34 70-22s46 2 66-12 46-16 66 4 22 48-2 62-52 18-86 8-62-4-84 8-44-18-30-48z" fill="rgba(111,123,102,.16)" stroke="rgba(111,123,102,.3)"/>
      <circle cx="126" cy="78" r="5" fill="#B23A2E" stroke="#E0C060"/>
      <circle cx="214" cy="62" r="4" fill="#B23A2E"/>
      <circle cx="180" cy="104" r="3.5" fill="#B23A2E"/>
      <circle cx="72" cy="58" r="3.5" fill="#9C907B" stroke-dasharray="2 2"/>
      <text x="132" y="76" font-size="9" fill="#E9DFC8">赤壁</text>
      <rect x="238" y="20" width="46" height="20" rx="2" fill="rgba(201,162,39,.12)" stroke="rgba(201,162,39,.3)"/>
      <text x="261" y="34" text-anchor="middle" font-size="8" fill="#E0C060">势力范围</text>
      <text x="28" y="130" font-size="8" fill="#9C907B">标准地图 GS(2022)4307 · 位置精度 确/约/传说</text>
    </svg>`,
  },
  {
    kicker: '叁 / 叁',
    title: '关系图谱与时代总览',
    desc: '名将关系看人物网络，国家关系看战争/和亲/会盟；时代总览一屏看尽 12 期、120 场与 20 个势力。',
    art: `<svg viewBox="0 0 320 150" role="img" aria-label="关系与总览示意">
      <circle cx="92" cy="74" r="26" fill="none" stroke="rgba(201,162,39,.25)"/>
      <circle cx="92" cy="74" r="9" fill="rgba(201,162,39,.16)" stroke="#C9A227"/>
      <circle cx="36" cy="42" r="5" fill="#B23A2E"/><line x1="40" y1="47" x2="84" y2="68" stroke="#C94B3A"/>
      <circle cx="44" cy="110" r="5" fill="#6F7B66"/><line x1="49" y1="106" x2="84" y2="80" stroke="#74A36F"/>
      <circle cx="144" cy="40" r="5" fill="#E0C060"/><line x1="139" y1="44" x2="101" y2="68" stroke="#E0C060" stroke-dasharray="2 3"/>
      <circle cx="144" cy="106" r="5" fill="#9C907B"/><line x1="139" y1="102" x2="101" y2="80" stroke="#9C907B" stroke-dasharray="4 4"/>
      <line x1="196" y1="42" x2="302" y2="42" stroke="rgba(201,162,39,.18)"/>
      <rect x="196" y="56" width="42" height="8" rx="2" fill="#8C6B4A"/>
      <rect x="205" y="72" width="58" height="8" rx="2" fill="#B23A2E"/>
      <rect x="196" y="88" width="80" height="8" rx="2" fill="#C9A227"/>
      <rect x="205" y="104" width="64" height="8" rx="2" fill="#6F7B66"/>
      <text x="196" y="132" font-size="8" fill="#9C907B">12 期 · 120 场 · 20 势力 · 关系</text>
    </svg>`,
  },
];

let active = null;
let prevFocus = null;
let stepIndex = 0;
let closeTimer = 0;

function hasOnboarded() {
  try {
    return localStorage.getItem(KEY) === '1';
  } catch (err) {
    return true;
  }
}

function persist() {
  try {
    localStorage.setItem(KEY, '1');
  } catch (err) {
    /* 静默降级 */
  }
}

function dotsHTML() {
  return STEPS.map(
    (_, i) =>
      `<button class="ob-dot${i === stepIndex ? ' is-active' : ''}" type="button" data-ob-step="${i}" aria-label="第 ${i + 1} 步"${
        i === stepIndex ? ' aria-current="step"' : ''
      }></button>`
  ).join('');
}

function cardHTML() {
  const step = STEPS[stepIndex];
  const isLast = stepIndex === STEPS.length - 1;
  return `<div class="ob-card" role="document">
    <div class="ob-head">
      <span class="ob-brand">山河战纪 · 3.3</span>
      <button class="ob-skip" type="button" data-ob-skip>跳过</button>
    </div>
    <div class="ob-art">${step.art}</div>
    <p class="ob-kicker">${esc(step.kicker)}</p>
    <h2 class="ob-title" id="obTitle">${esc(step.title)}</h2>
    <p class="ob-desc">${esc(step.desc)}</p>
    <div class="ob-dots" role="group" aria-label="引导步骤">${dotsHTML()}</div>
    <button class="btn btn--gold ob-next" type="button" data-ob-next>${isLast ? '开始阅读' : '下一步'}</button>
  </div>`;
}

function paint() {
  if (!active) return;
  const card = active.querySelector('.ob-card');
  if (card) card.outerHTML = cardHTML();
  bind();
}

function bind() {
  if (!active) return;
  active.querySelector('[data-ob-skip]')?.addEventListener('click', close);
  active.querySelector('[data-ob-next]')?.addEventListener('click', () => {
    if (stepIndex >= STEPS.length - 1) close();
    else {
      stepIndex += 1;
      paint();
    }
  });
  active.querySelectorAll('[data-ob-step]').forEach((dot) => {
    dot.addEventListener('click', () => {
      stepIndex = Number(dot.dataset.obStep) || 0;
      paint();
    });
  });
  active.querySelector('[data-ob-next]')?.focus({ preventScroll: true });
}

function onKeydown(e) {
  if (!active) return;
  if (e.key === 'Escape') {
    e.preventDefault();
    close();
  }
}

export function showOnboarding({ force = false } = {}) {
  if (active) return;
  if (!force && hasOnboarded()) return;
  persist();
  stepIndex = 0;
  prevFocus = document.activeElement;
  active = document.createElement('div');
  active.className = 'onboard';
  active.setAttribute('role', 'dialog');
  active.setAttribute('aria-modal', 'true');
  active.setAttribute('aria-labelledby', 'obTitle');
  active.innerHTML = `<div class="ob-backdrop"></div>${cardHTML()}`;
  document.body.appendChild(active);
  document.documentElement.classList.add('onboard-lock');
  document.addEventListener('keydown', onKeydown);
  bind();
  requestAnimationFrame(() => active?.classList.add('is-open'));
  // 避免浮层在 route 转场期间被误点；关闭时统一清理
}

export function maybeShowOnboarding() {
  if (hasOnboarded() || active) return false;
  // 只在真正的时间轴首屏显示，深链（详情/锚点/query）不拦截
  const hash = location.hash || '#/';
  if (hash !== '#/' && hash !== '#' && hash !== '') return false;
  if (!document.querySelector('.timeline-page')) return false;
  clearTimeout(closeTimer);
  closeTimer = setTimeout(() => showOnboarding(), 420);
  return true;
}

export function closeOnboarding() {
  if (active) close();
}

function close() {
  if (!active) return;
  persist();
  clearTimeout(closeTimer);
  document.removeEventListener('keydown', onKeydown);
  document.documentElement.classList.remove('onboard-lock');
  const el = active;
  active = null;
  el.classList.remove('is-open');
  const remove = () => el.remove();
  const reduce = document.documentElement.dataset.motion === 'reduce' || !el.animate;
  if (reduce) remove();
  else setTimeout(remove, 220);
  try {
    prevFocus?.focus?.({ preventScroll: true });
  } catch (err) {
    /* 忽略 */
  }
}

export function isOnboardingActive() {
  return !!active;
}
