/* ============================================================
   filter.js — 底部筛选弹层：时期多选 + 类型多选 + 实时命中数
   ============================================================ */

import { esc, icon, toast } from './ui.js';
import { filters, TYPES } from './store.js';
import { filterBattles } from './data.js';
import { initDrawerSpring } from './motion.js';

let openSheet = null;

function closeFilterSheet({ immediate = false } = {}) {
  const el = openSheet;
  if (!el) return;
  openSheet = null;
  const { scrim, sheet, previousFocus } = el;
  scrim.classList.remove('is-open');
  sheet.classList.remove('is-open');
  if (el.dragCleanup) el.dragCleanup();
  const remove = () => {
    scrim.remove();
    sheet.remove();
  };
  if (immediate) remove();
  else setTimeout(remove, 300);
  document.removeEventListener('keydown', el.onKey);
  try {
    if (previousFocus && typeof previousFocus.focus === 'function') previousFocus.focus({ preventScroll: true });
  } catch (err) {
    /* 忽略 */
  }
}

export function openFilterSheet(ctx) {
  if (openSheet) {
    closeFilterSheet({ immediate: true });
  }

  const eraList = ctx.data.eras;
  const draft = { eras: new Set(filters.eras), types: new Set(filters.types) };

  const scrim = document.createElement('div');
  scrim.className = 'scrim';
  scrim.setAttribute('aria-hidden', 'true');

  const sheet = document.createElement('div');
  sheet.className = 'bottom-sheet';
  sheet.setAttribute('role', 'dialog');
  sheet.setAttribute('aria-modal', 'true');
  sheet.setAttribute('aria-label', '筛选战役');
  sheet.innerHTML = `
    <div class="sheet-head">
      <h2 class="sheet-title">筛选</h2>
      <button class="icon-btn" type="button" data-close aria-label="关闭筛选">${icon('close')}</button>
    </div>
    <div class="sheet-body">
      <section class="filter-section">
        <div class="filter-title">时期 <span class="ft-sub">${eraList.length} 期 · 可多选</span></div>
        <div class="chip-grid">
          ${eraList
            .map(
              (era) => `<button class="f-chip" type="button" data-kind="era" data-value="${esc(era.id)}" aria-pressed="${
                draft.eras.has(era.id) ? 'true' : 'false'
              }">
                <span class="fc-idx">${String(era.index).padStart(2, '0')}</span>
                <span class="fc-name">${esc(era.short || era.name)}</span>
              </button>`
            )
            .join('')}
        </div>
      </section>
      <section class="filter-section">
        <div class="filter-title">类型 <span class="ft-sub">可多选</span></div>
        <div class="chip-grid cols-2">
          ${TYPES.map(
            (type) => `<button class="f-chip" type="button" data-kind="type" data-value="${esc(type)}" aria-pressed="${
              draft.types.has(type) ? 'true' : 'false'
            }">
              <span class="fc-name">${esc(type)}</span>
            </button>`
          ).join('')}
        </div>
      </section>
      <div class="filter-count" aria-live="polite">
        <b id="filterCount">0</b> 场战役命中
        <span class="fc-hint">不选即全部</span>
      </div>
    </div>
    <div class="sheet-foot">
      <button class="btn" type="button" data-action="reset">重置</button>
      <button class="btn btn--primary" type="button" data-action="apply">查看 0 场</button>
    </div>`;

  document.body.append(scrim, sheet);
  openSheet = { scrim, sheet, previousFocus: document.activeElement };
  // 打开后把焦点移入弹层（关闭时归还）
  try {
    sheet.querySelector('[data-close]').focus({ preventScroll: true });
  } catch (err) {
    /* 忽略 */
  }

  const countEl = sheet.querySelector('#filterCount');
  const applyBtn = sheet.querySelector('[data-action="apply"]');
  const hintEl = sheet.querySelector('.fc-hint');

  const current = () => ({ eras: [...draft.eras], types: [...draft.types] });

  const refresh = () => {
    const list = filterBattles(ctx.data.battles, current());
    countEl.textContent = String(list.length);
    applyBtn.textContent = `查看 ${list.length} 场`;
    applyBtn.disabled = false;
    const active = draft.eras.size + draft.types.size > 0;
    hintEl.textContent = active ? '再次点击可取消' : '不选即全部';
  };

  sheet.querySelector('.sheet-body').addEventListener('click', (e) => {
    const chip = e.target.closest('.f-chip');
    if (!chip) return;
    const value = chip.dataset.value;
    if (chip.dataset.kind === 'era') {
      if (draft.eras.has(value)) draft.eras.delete(value);
      else draft.eras.add(value);
    } else if (draft.types.has(value)) {
      draft.types.delete(value);
    } else {
      draft.types.add(value);
    }
    chip.setAttribute('aria-pressed', chip.getAttribute('aria-pressed') === 'true' ? 'false' : 'true');
    refresh();
  });

  sheet.querySelector('[data-action="reset"]').addEventListener('click', () => {
    draft.eras.clear();
    draft.types.clear();
    sheet.querySelectorAll('.f-chip').forEach((chip) => chip.setAttribute('aria-pressed', 'false'));
    refresh();
  });

  sheet.querySelector('[data-action="apply"]').addEventListener('click', () => {
    const next = current();
    filters.eras = next.eras;
    filters.types = next.types;
    const list = filterBattles(ctx.data.battles, filters);
    closeFilterSheet();
    ctx.rerenderHome({ toTop: true });
    toast(filters.eras.length || filters.types.length ? `已筛选 · 命中 ${list.length} 场` : '已显示全部战役');
  });

  const onKey = (e) => {
    if (e.key === 'Escape') closeFilterSheet();
  };
  openSheet.onKey = onKey;
  document.addEventListener('keydown', onKey);

  scrim.addEventListener('click', () => closeFilterSheet());
  sheet.querySelector('[data-close]').addEventListener('click', () => closeFilterSheet());

  refresh();
  requestAnimationFrame(() => {
    scrim.classList.add('is-open');
    sheet.classList.add('is-open');
    if (openSheet) openSheet.dragCleanup = initDrawerSpring(sheet, { onClose: () => closeFilterSheet(), handle: sheet.querySelector('.sheet-head') });
  });
}

export function disposeFilterSheet() {
  closeFilterSheet({ immediate: true });
}
