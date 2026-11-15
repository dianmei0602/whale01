/* ============================================================
   more.js — 更多 / 设置：字号三档、减弱动效、数据来源、关于
   ============================================================ */

import { esc, icon, toast } from './ui.js';
import { getSettings, updateSetting, resetSettings, loadRecent } from './store.js';
import { initMenuStagger } from './motion.js';

function segmented(font) {
  return `<div class="segmented" role="group" aria-label="正文字号">
    ${[
      ['sm', '小'],
      ['std', '标准'],
      ['lg', '大'],
    ]
      .map(
        ([value, label]) =>
          `<button class="seg-btn" type="button" data-font="${value}" aria-pressed="${
            font === value ? 'true' : 'false'
          }">${label}</button>`
      )
      .join('')}
  </div>`;
}

function renderHTML(ctx, settings) {
  const recent = loadRecent().length;
  return `<div class="more-page">
    <header class="page-head">
      <div class="head-title">更多<span class="head-sub">设置 · 数据 · 关于</span></div>
      <div class="head-actions">
        <button class="icon-btn" type="button" data-action="search" aria-label="搜索">${icon('search')}</button>
      </div>
    </header>

    <div class="page-body">
      <div class="about-card">
        <h3>山河战纪</h3>
        <p class="about-sub">从涿鹿到加勒万 · 中国战史时间轴</p>
        <p>一部装在口袋里、可以顺着时间轴一路读下去的中国战史。以时间为目录，串起 12 期、120 场战役的因果与人物；3.0 增补战役档案、双方势力对照、势力范围示意、家族谱与联姻。全量离线，无广告、无账号、无内购。</p>
        <div class="about-meta">
          <span>版本 <b>3.0 考据版</b></span>
          <span>内容 <b>120 场 · 12 期 · 40 名将</b></span>
          <span>谱系 <b>20 势力 · 34 关系 · 14 家族</b></span>
          <span>更新 <b>2026-11</b></span>
        </div>
      </div>

      <section class="settings-group" style="margin-top:22px">
        <h2 class="settings-group-title">阅读设置</h2>
        <div class="setting-row">
          <div class="sr-main">
            <div class="sr-label">正文字号</div>
            <div class="sr-desc">三档可调 · 立即生效并记住</div>
          </div>
          ${segmented(settings.font)}
        </div>
        <div class="setting-row">
          <div class="sr-main">
            <div class="sr-label">减弱动效</div>
            <div class="sr-desc">关闭位移与缩放动画，只保留淡入</div>
          </div>
          <button class="switch" type="button" data-action="motion" aria-label="减弱动效" aria-pressed="${
            settings.motion === 'reduce' ? 'true' : 'false'
          }"></button>
        </div>
        <div class="sample-text" aria-hidden="true">
          <span class="st-label">字号预览</span>
          夫战，勇气也。一鼓作气，再而衰，三而竭。彼竭我盈，故克之。
        </div>
      </section>

      <section class="settings-group">
        <h2 class="settings-group-title">数据与来源</h2>
        <div class="setting-row">
          <div class="sr-main">
            <div class="sr-label">史料来源</div>
            <div class="sr-desc">《史记》《资治通鉴》《中国历代战争史》等 · 每场战役文末标注出处</div>
          </div>
        </div>
        <div class="setting-row">
          <div class="sr-main">
            <div class="sr-label">底图与审图号</div>
            <div class="sr-desc">自然资源部标准地图服务 · GS(2022)4307 号 · 全量离线可用</div>
          </div>
          <span class="ph-soon">标准地图</span>
        </div>
        <div class="setting-row">
          <div class="sr-main">
            <div class="sr-label">最近浏览</div>
            <div class="sr-desc">本机记录 ${recent} 条，不上传、不同步</div>
          </div>
          <button class="btn btn--ghost" type="button" data-action="clear-recent">清除</button>
        </div>
      </section>

      <section class="settings-group">
        <h2 class="settings-group-title">关于</h2>
        <ul class="source-list">
          <li>3.0 考据：战役档案（时长/目的/地形/兵种/伤亡口径）、双方势力对照（面积/人口/兵力为估算区间）、势力范围示意（今省界拼合）、家族谱与联姻。</li>
          <li>视觉：水墨古卷 · 墨金；纹理、山脉、印章均为本地程序化生成；标准地图审图号 GS(2022)4307。</li>
          <li>隐私：全部数据与设置保存在本机，无网络请求、无统计埋点。</li>
          <li>后续：持续校核战役档案与家族谱系，扩充考据来源标注。</li>
        </ul>
        <div class="setting-row" style="margin-top:12px">
          <div class="sr-main">
            <div class="sr-label">恢复默认设置</div>
            <div class="sr-desc">字号标准 · 完整动效</div>
          </div>
          <button class="btn" type="button" data-action="reset-settings">恢复</button>
        </div>
      </section>

      <footer class="detail-foot">
        <span class="foot-seal">山河战纪</span>
        <br>3.0 考据版 · 仅供内部演示<br>从涿鹿到加勒万，山河未已
      </footer>
    </div>
  </div>`;
}

export function renderMore(root, ctx) {
  const settings = getSettings();
  root.innerHTML = renderHTML(ctx, settings);
  initMenuStagger(root);

  root.querySelector('[data-action="search"]')?.addEventListener('click', () => {
    window.location.hash = '#/search';
  });

  root.querySelectorAll('.seg-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      const font = btn.dataset.font;
      updateSetting('font', font);
      root.querySelectorAll('.seg-btn').forEach((b) => b.setAttribute('aria-pressed', b === btn ? 'true' : 'false'));
      const page = root.querySelector('.more-page');
      if (page) {
        page.classList.add('is-font-flip');
        setTimeout(() => page.classList.remove('is-font-flip'), 220);
      }
      toast(font === 'sm' ? '字号已调小' : font === 'lg' ? '字号已放大' : '字号已恢复标准');
    });
  });

  const motionBtn = root.querySelector('[data-action="motion"]');
  motionBtn?.addEventListener('click', () => {
    const next = getSettings().motion === 'reduce' ? 'full' : 'reduce';
    updateSetting('motion', next);
    motionBtn.setAttribute('aria-pressed', next === 'reduce' ? 'true' : 'false');
    toast(next === 'reduce' ? '已减弱动效' : '已恢复完整动效');
  });

  root.querySelector('[data-action="clear-recent"]')?.addEventListener('click', () => {
    try {
      localStorage.removeItem('shj.recent.v1');
    } catch (err) {
      /* ignore */
    }
    toast('已清除最近浏览记录');
    renderMore(root, ctx);
  });

  root.querySelector('[data-action="reset-settings"]')?.addEventListener('click', () => {
    resetSettings();
    toast('已恢复默认设置');
    renderMore(root, ctx);
  });
}
