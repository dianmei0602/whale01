/* ============================================================
   motion.js — 2.2 动效系统工具（零依赖，全部 rAF / IO / WAAPI）
   revealStagger / large title / odometer / ripple / accordion /
   swipe / drawer spring / parallax / FLIP / tab & switch bounce /
   skeleton / chart draw / band light
   所有函数在减弱动效（html/body data-motion=reduce 或系统设置）下降级。
   ============================================================ */

const REDUCE_QUERY = '(prefers-reduced-motion: reduce)';

export function prefersReducedMotion() {
  try {
    return window.matchMedia && window.matchMedia(REDUCE_QUERY).matches;
  } catch (err) {
    return false;
  }
}

/** 当前是否允许动效（设置面板 or 系统） */
export function motionOK() {
  const html = document.documentElement;
  const body = document.body;
  if (body?.dataset.motion === 'reduce' || html?.dataset.motion === 'reduce') return false;
  return !prefersReducedMotion();
}

export function rafThrottle(fn) {
  let raf = 0;
  return (...args) => {
    if (raf) return;
    raf = requestAnimationFrame(() => {
      raf = 0;
      fn(...args);
    });
  };
}

/* ---------------- 骨架屏 ---------------- */
export function skeletonHTML(count = 4) {
  return `<div class="m-skeleton-list" aria-hidden="true">
    ${Array.from({ length: count }, (_, i) =>
      `<div class="m-skeleton-row"><span class="m-sk m-sk--dot"></span><span class="m-sk m-sk--line" style="--w:${70 + ((i * 7) % 25)}%"></span></div>`
    ).join('')}
  </div>`;
}

/* ---------------- 进入视口 stagger / blurUp ---------------- */
export function revealStagger(container, selector, opts = {}) {
  const { stagger = 50, wave = 8, threshold = 0.1, groupBy = '', once = true } = opts;
  if (!container) return () => {};
  const els = [...container.querySelectorAll(selector)];
  if (!els.length) return () => {};

  const groups = new Map();
  els.forEach((el) => {
    el.classList.add('m-reveal');
    const group = groupBy ? el.closest(groupBy) : null;
    const key = group || container;
    const idx = groups.get(key) || 0;
    el.style.setProperty('--m-delay', `${(idx % wave) * stagger}ms`);
    groups.set(key, idx + 1);
  });

  if (!motionOK()) {
    els.forEach((el) => el.classList.add('is-in'));
    return () => {};
  }

  let io = null;
  const show = (el) => {
    el.classList.add('is-in');
    io?.unobserve(el);
  };
  if ('IntersectionObserver' in window) {
    io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) show(entry.target);
        });
      },
      { threshold, rootMargin: '0px 0px -4% 0px' }
    );
    els.forEach((el) => io.observe(el));
  } else {
    els.forEach(show);
  }
  return () => io?.disconnect();
}

/* ---------------- 大标题滚动折叠 ---------------- */
export function initLargeTitle(root) {
  const head = root?.querySelector('.tl-head');
  if (!head) return () => {};
  const update = () => head.classList.toggle('is-collapsed', window.scrollY > 72);
  const onScroll = rafThrottle(update);
  window.addEventListener('scroll', onScroll, { passive: true });
  update();
  return () => window.removeEventListener('scroll', onScroll);
}

/* ---------------- 数字翻滚 ---------------- */
export function odometer(el, duration = 800) {
  if (!el || el.dataset.odoDone) return;
  const raw = String(el.textContent || '').trim();
  const match = raw.match(/^(-?\d+(?:\.\d+)?)(.*)$/);
  if (!match) return;
  el.dataset.odoDone = '1';
  if (!motionOK()) return;
  const target = parseFloat(match[1]);
  const suffix = match[2] || '';
  const decimals = (match[1].split('.')[1] || '').length;
  const start = performance.now();
  const tick = (now) => {
    const p = Math.min(1, (now - start) / duration);
    const eased = 1 - Math.pow(1 - p, 3);
    el.textContent = (target * eased).toFixed(decimals) + suffix;
    if (p < 1) requestAnimationFrame(tick);
    else el.textContent = raw;
  };
  requestAnimationFrame(tick);
}

export function initOdometer(root, selector = '[data-odometer], .st-ov-item b') {
  if (!root) return;
  root.querySelectorAll(selector).forEach((el) => odometer(el));
}

/* ---------------- 点击波纹 ---------------- */
const RIPPLE_SELECTOR =
  '.btn, .icon-btn, .tab, .tl-card, .fac-card, .gen-graph-cta, .graph-ctl, .seg-btn, .f-chip, .g-chip, .bio-toggle, .pn-item, .s-item, .hot-chip, .person, .switch, [data-rp]';

export function ripple(event) {
  if (!motionOK()) return;
  const host = event.target?.closest?.(RIPPLE_SELECTOR);
  if (!host || host.disabled) return;
  const span = document.createElement('span');
  span.className = 'm-ripple';
  span.style.left = `${event.clientX - 60}px`;
  span.style.top = `${event.clientY - 60}px`;
  document.body.appendChild(span);
  span.addEventListener('animationend', () => span.remove(), { once: true });
  setTimeout(() => span.remove(), 700);
}

export function initRipple() {
  let last = 0;
  const onDown = (e) => {
    if (e.pointerType === 'mouse' && e.button !== 0) return;
    const now = performance.now();
    if (now - last < 80) return;
    last = now;
    ripple(e);
  };
  document.addEventListener('pointerdown', onDown, { passive: true });
  return () => document.removeEventListener('pointerdown', onDown);
}

/* ---------------- Tab 弹簧 ---------------- */
export function initTabBounce() {
  const onClick = (e) => {
    const tab = e.target?.closest?.('.tab');
    if (!tab || !motionOK()) return;
    tab.classList.remove('is-bounce');
    // 强制回流以重启动画
    void tab.offsetWidth;
    tab.classList.add('is-bounce');
    tab.addEventListener('animationend', () => tab.classList.remove('is-bounce'), { once: true });
  };
  document.addEventListener('click', onClick);
  return () => document.removeEventListener('click', onClick);
}

/* ---------------- 开关双弹跳 ---------------- */
export function initSwitchBounce() {
  const onClick = (e) => {
    const sw = e.target?.closest?.('.switch');
    if (!sw || !motionOK()) return;
    sw.classList.remove('is-pop');
    void sw.offsetWidth;
    sw.classList.add('is-pop');
    sw.addEventListener('animationend', () => sw.classList.remove('is-pop'), { once: true });
  };
  document.addEventListener('click', onClick);
  return () => document.removeEventListener('click', onClick);
}

/* ---------------- 手风琴 ---------------- */
export function initAccordion(root, selector = '[data-acc-toggle]') {
  if (!root) return () => {};
  const onClick = (e) => {
    const btn = e.target.closest(selector);
    if (!btn) return;
    const target =
      document.getElementById(btn.getAttribute('aria-controls') || '') ||
      btn.closest('[data-acc-card]')?.querySelector('.m-acc') ||
      btn.parentElement?.querySelector('.m-acc');
    if (!target) return;
    if (btn.tagName === 'BUTTON') e.preventDefault();
    const open = btn.getAttribute('aria-expanded') === 'true';
    btn.setAttribute('aria-expanded', open ? 'false' : 'true');
    target.classList.toggle('is-open', !open);
    if (btn.dataset.accLabel) {
      const labels = btn.dataset.accLabel.split('|');
      btn.textContent = open ? labels[0] : labels[1] || labels[0];
    }
  };
  root.addEventListener('click', onClick);
  return () => root.removeEventListener('click', onClick);
}

/* ---------------- 详情左右滑 ---------------- */
export function initSwipeDetail(root, { prev = null, next = null, onNavigate } = {}) {
  if (!root) return () => {};
  let sx = 0;
  let sy = 0;
  let dx = 0;
  let dy = 0;
  let tracking = false;
  const page = root.querySelector('.detail-page');
  const getT = (e) => (e.touches && e.touches[0]) || (e.changedTouches && e.changedTouches[0]) || null;
  const setDx = (value) => {
    if (page) page.style.setProperty('--swipe-x', `${value}px`);
  };
  const onStart = (e) => {
    const t = getT(e);
    if (!t || (e.touches && e.touches.length > 1)) return;
    sx = t.clientX;
    sy = t.clientY;
    dx = 0;
    dy = 0;
    tracking = true;
    if (motionOK()) page?.classList.add('is-swiping');
  };
  const onMove = (e) => {
    if (!tracking) return;
    const t = getT(e);
    if (!t) return;
    dx = t.clientX - sx;
    dy = t.clientY - sy;
    if (Math.abs(dy) > Math.abs(dx) && Math.abs(dy) > 14) {
      tracking = false;
      page?.classList.remove('is-swiping');
      setDx(0);
      return;
    }
    if (Math.abs(dx) > 8 && Math.abs(dx) > Math.abs(dy) * 1.2 && motionOK()) setDx(dx * 0.28);
  };
  const onEnd = () => {
    if (!tracking) return;
    tracking = false;
    page?.classList.remove('is-swiping');
    setDx(0);
    if (Math.abs(dx) < 60 || Math.abs(dx) <= Math.abs(dy) * 1.2) return;
    const target = dx > 0 ? prev : next;
    if (target) onNavigate?.(target);
  };
  root.addEventListener('touchstart', onStart, { passive: true });
  root.addEventListener('touchmove', onMove, { passive: true });
  root.addEventListener('touchend', onEnd, { passive: true });
  root.addEventListener('touchcancel', onEnd, { passive: true });
  return () => {
    root.removeEventListener('touchstart', onStart);
    root.removeEventListener('touchmove', onMove);
    root.removeEventListener('touchend', onEnd);
    root.removeEventListener('touchcancel', onEnd);
  };
}

/* ---------------- 弹簧抽屉 ---------------- */
export function initDrawerSpring(el, { onClose, handle } = {}) {
  if (!el || !motionOK() || !onClose) return () => {};
  const grip = handle || el.querySelector('.sheet-head') || el;
  let startY = 0;
  let lastY = 0;
  let lastT = 0;
  let dy = 0;
  let dragging = false;
  let velocity = 0;

  const onDown = (e) => {
    if (e.target.closest('button, a, input, .f-chip, .g-chip, .graph-ctl')) return;
    dragging = true;
    startY = e.clientY;
    lastY = e.clientY;
    lastT = performance.now();
    dy = 0;
    velocity = 0;
    el.classList.add('is-dragging');
    el.style.transition = 'none';
    grip.setPointerCapture?.(e.pointerId);
  };
  const onMove = (e) => {
    if (!dragging) return;
    dy = Math.max(0, e.clientY - startY);
    const now = performance.now();
    velocity = (e.clientY - lastY) / Math.max(1, now - lastT);
    lastY = e.clientY;
    lastT = now;
    el.style.transform = `translate3d(0, ${dy}px, 0)`;
  };
  const onUp = () => {
    if (!dragging) return;
    dragging = false;
    el.classList.remove('is-dragging');
    const height = el.getBoundingClientRect().height || 1;
    if (dy > height * 0.45 || velocity > 0.5) {
      el.style.transition = 'transform 260ms var(--ease-spring)';
      el.style.transform = `translate3d(0, ${height + 24}px, 0)`;
      setTimeout(() => {
        el.style.transform = '';
        el.style.transition = '';
        onClose();
      }, 250);
    } else {
      el.style.transition = 'transform 320ms var(--ease-spring)';
      el.style.transform = '';
      setTimeout(() => {
        el.style.transition = '';
      }, 340);
    }
  };
  grip.addEventListener('pointerdown', onDown);
  grip.addEventListener('pointermove', onMove);
  grip.addEventListener('pointerup', onUp);
  grip.addEventListener('pointercancel', onUp);
  return () => {
    grip.removeEventListener('pointerdown', onDown);
    grip.removeEventListener('pointermove', onMove);
    grip.removeEventListener('pointerup', onUp);
    grip.removeEventListener('pointercancel', onUp);
  };
}

/* ---------------- Hero 视差 ---------------- */
export function initParallax(root, selector, { max = 18, speed = 0.14 } = {}) {
  const els = [...(root?.querySelectorAll(selector) || [])];
  if (!els.length) return () => {};
  if (!motionOK()) {
    els.forEach((el) => (el.style.transform = ''));
    return () => {};
  }
  const update = () => {
    const y = Math.max(-max, Math.min(max, window.scrollY * speed));
    els.forEach((el) => (el.style.transform = `translate3d(0, ${y.toFixed(2)}px, 0)`));
  };
  const onScroll = rafThrottle(update);
  window.addEventListener('scroll', onScroll, { passive: true });
  update();
  return () => window.removeEventListener('scroll', onScroll);
}

/* ---------------- 卡片 → 详情 FLIP ---------------- */
let flipPending = null;

export function rememberCardFlip(card) {
  if (!card || !motionOK()) {
    flipPending = null;
    return;
  }
  const rect = card.getBoundingClientRect();
  const name = card.querySelector('.card-name')?.textContent?.trim() || '';
  const year = card.querySelector('.card-year')?.textContent?.trim() || '';
  flipPending = { rect, name, year, at: performance.now() };
}

export function initFlipCards() {
  const onClick = (e) => {
    const card = e.target?.closest?.('.tl-card');
    if (card) rememberCardFlip(card);
  };
  document.addEventListener('click', onClick, true);
  return () => document.removeEventListener('click', onClick, true);
}

export function playCardFlipIn(target) {
  if (!flipPending || !target) {
    flipPending = null;
    return;
  }
  const pending = flipPending;
  flipPending = null;
  if (!motionOK() || performance.now() - pending.at > 1800) return;
  const to = target.getBoundingClientRect();
  const from = pending.rect;
  if (!from.width || !to.width) return;
  const ghost = document.createElement('div');
  ghost.className = 'm-flip-ghost';
  ghost.textContent = pending.name || '';
  ghost.style.left = `${from.left}px`;
  ghost.style.top = `${from.top}px`;
  ghost.style.width = `${from.width}px`;
  ghost.style.height = `${from.height}px`;
  ghost.style.fontSize = `${Math.min(30, Math.max(16, from.height * 0.1))}px`;
  document.body.appendChild(ghost);
  const dx = to.left + to.width / 2 - (from.left + from.width / 2);
  const dy = to.top + to.height / 2 - (from.top + from.height / 2);
  const scaleX = Math.max(0.2, to.width / from.width);
  const scaleY = Math.max(0.2, to.height / from.height);
  try {
    const anim = ghost.animate(
      [
        { transform: 'translate3d(0,0,0) scale(1,1)', opacity: 0.95, filter: 'blur(0px)' },
        { transform: `translate3d(${dx * 0.55}px, ${dy * 0.55}px, 0) scale(${1 + (scaleX - 1) * 0.5}, ${1 + (scaleY - 1) * 0.5})`, opacity: 0.9, filter: 'blur(1px)', offset: 0.55 },
        { transform: `translate3d(${dx}px, ${dy}px, 0) scale(${scaleX}, ${scaleY})`, opacity: 0, filter: 'blur(3px)' },
      ],
      { duration: 440, easing: 'cubic-bezier(.22,.61,.36,1)', fill: 'both' }
    );
    anim.addEventListener('finish', () => ghost.remove());
    setTimeout(() => ghost.remove(), 700);
  } catch (err) {
    ghost.remove();
  }
}

/* ---------------- 详情 → 卡片 FLIP 返回 ---------------- */
let flipBackPending = null;

export function rememberDetailFlip(heroEl, battleId) {
  if (!heroEl || !battleId || !motionOK()) return;
  flipBackPending = { rect: heroEl.getBoundingClientRect(), battleId, at: performance.now() };
}

export function playCardFlipBack(root) {
  if (!flipBackPending || !motionOK()) {
    flipBackPending = null;
    return;
  }
  const pending = flipBackPending;
  flipBackPending = null;
  if (performance.now() - pending.at > 2000) return;
  const card = root?.querySelector(`.tl-card[data-battle="${CSS.escape(pending.battleId)}"]`);
  if (!card) return;
  const to = card.getBoundingClientRect();
  const from = pending.rect;
  if (!from.width || !to.width) return;
  const ghost = document.createElement('div');
  ghost.className = 'm-flip-ghost';
  ghost.textContent = card.querySelector('.card-name')?.textContent?.trim() || '';
  ghost.style.left = `${from.left}px`;
  ghost.style.top = `${from.top}px`;
  ghost.style.width = `${from.width}px`;
  ghost.style.height = `${from.height}px`;
  ghost.style.fontSize = `${Math.min(34, Math.max(18, from.height * 0.11))}px`;
  document.body.appendChild(ghost);
  const dx = to.left + to.width / 2 - (from.left + from.width / 2);
  const dy = to.top + to.height / 2 - (from.top + from.height / 2);
  const sx = Math.max(0.2, to.width / from.width);
  const sy = Math.max(0.2, to.height / from.height);
  try {
    const anim = ghost.animate(
      [
        { transform: 'translate3d(0,0,0) scale(1,1)', opacity: 0.95, filter: 'blur(0px)' },
        { transform: `translate3d(${dx}px, ${dy}px, 0) scale(${sx}, ${sy})`, opacity: 0, filter: 'blur(3px)' },
      ],
      { duration: 420, easing: 'cubic-bezier(.22,.61,.36,1)', fill: 'both' }
    );
    anim.addEventListener('finish', () => ghost.remove());
    setTimeout(() => ghost.remove(), 700);
  } catch (err) {
    ghost.remove();
  }
}

/* ---------------- 更多菜单 stagger ---------------- */
export function initMenuStagger(root) {
  return revealStagger(root, '.about-card, .settings-group, .source-list', { stagger: 55, wave: 6 });
}

/* ---------------- 图表生长 / 环形描边 ---------------- */
export function initChartGrowth(root) {
  if (!root || !motionOK()) return;
  root.querySelectorAll('.st-donut-seg').forEach((seg, i) => {
    try {
      const off = parseFloat(seg.getAttribute('stroke-dashoffset')) || 0;
      const arr = String(seg.getAttribute('stroke-dasharray') || '').split(/[ ,]+/);
      const len = parseFloat(arr[0]) || 0;
      if (!len) return;
      seg.animate(
        [{ strokeDashoffset: `${off - len}` }, { strokeDashoffset: `${off}` }],
        { duration: 800, delay: i * 40, easing: 'cubic-bezier(.16,1,.3,1)', fill: 'both' }
      );
    } catch (err) {
      /* 忽略 */
    }
  });
  root.querySelectorAll('.st-line, .st-area').forEach((path) => {
    try {
      const len = path.getTotalLength?.() || 0;
      if (!len) return;
      path.style.strokeDasharray = `${len}`;
      path.animate([{ strokeDashoffset: len }, { strokeDashoffset: 0 }], {
        duration: 800,
        easing: 'cubic-bezier(.16,1,.3,1)',
        fill: 'both',
      });
    } catch (err) {
      /* 忽略 */
    }
  });
}

/* ---------------- 势力时间带点亮 ---------------- */
export function initBandLight(root) {
  const svg = root?.querySelector('.fac-band-svg');
  if (!svg) return;
  if (!motionOK()) return;
  const rows = [...svg.querySelectorAll('.fac-bar-row')];
  svg.classList.add('m-band-playing');
  rows.forEach((row, i) => {
    row.style.setProperty('--m-delay', `${i * 26}ms`);
    row.querySelector('.fac-bar')?.style.setProperty('--m-delay', `${i * 26}ms`);
  });
}
