/* ============================================================
   more.js — 更多 / 设置：字号三档、减弱动效、数据来源、关于
   ============================================================ */

import { esc, icon, toast } from './ui.js';
import { getSettings, updateSetting, resetSettings, loadRecent, loadFavorites } from './store.js';
import { initMenuStagger } from './motion.js';
import { showOnboarding } from './onboarding.js';

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
  const favCount = loadFavorites().length;
  const replayCount = (ctx.data.replays || []).length;
  const bioList = [...new Set((ctx.data.generalByName?.values?.() || []))];
  const bioTotal = bioList.length;
  const bioFeatured = bioList.filter((g) => g && g.featured !== false).length;
  const peopleText = bioTotal ? `${bioTotal} 位人物` : '64 位人物';
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
        <p>一部装在口袋里、可以顺着时间轴一路读下去的中国战史。以时间为目录，串起 12 期、120 场战役的因果与人物；3.0 增补战役档案、双方势力对照、势力范围示意、家族谱与联姻；3.1 新增卷首；3.2 关系可视化（图谱双图层 / 时代总览 / 图例与读图）；3.3 阅读闭环（进度 / 收藏 / 分享）与新手引导。全量离线，无广告、无账号、无内购。</p>
        <div class="about-meta">
          <span>版本 <b>3.3 体验补全版</b></span>
          <span>内容 <b>${ctx.data.total} 场 · ${ctx.data.eras.length} 期 · ${peopleText}</b></span>
          <span>谱系 <b>20 势力 · 34 关系 · 14 家族</b></span>
          <span>入谱 <b>${bioFeatured || 40} 位 · 关系图谱</b></span>
          <span>更新 <b>2026-11</b></span>
        </div>
      </div>

      <button class="setting-row" type="button" data-action="onboarding" style="margin-top:12px;width:100%;text-align:left">
        <div class="sr-main">
          <div class="sr-label">重新查看新手引导</div>
          <div class="sr-desc">3 步看完时间轴 / 地图 / 关系与时代总览</div>
        </div>
        <span class="ph-soon">3 步</span>
      </button>

      <a class="setting-row" href="privacy.html" style="margin-top:8px">
        <div class="sr-main">
          <div class="sr-label">隐私政策</div>
          <div class="sr-desc">本机存储说明 · 无账号 · 无网络上传</div>
        </div>
        <span class="ph-soon">查看</span>
      </a>

      <a class="setting-row" href="#/favorites" style="margin-top:8px">
        <div class="sr-main">
          <div class="sr-label">收藏夹</div>
          <div class="sr-desc">收藏的战役与阅读进度 · 本机保存</div>
        </div>
        <span class="ph-soon">${favCount} 场</span>
      </a>

      <a class="setting-row" href="#/replays" style="margin-top:8px">
        <div class="sr-main">
          <div class="sr-label">推演库</div>
          <div class="sr-desc">重点战役动画推演 · 时期 / 类型筛选</div>
        </div>
        <span class="ph-soon">${replayCount} 场</span>
      </a>

      <a class="setting-row" href="#/legend" style="margin-top:12px">
        <div class="sr-main">
          <div class="sr-label">图例与读图</div>
          <div class="sr-desc">时间轴 / 地图 / 关系图谱 / 甘特时间带 / 家族谱 · 5 节图例</div>
        </div>
        <span class="ph-soon">5 节</span>
      </a>

      <a class="setting-row" href="#/atlas" style="margin-top:8px">
        <div class="sr-main">
          <div class="sr-label">时代总览</div>
          <div class="sr-desc">甘特总览 · 12 期索引 · 全站关系入口</div>
        </div>
        <span class="ph-soon">3.2</span>
      </a>

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
          <li>3.2 关系可视化：名将/国家双图层图谱、名将放射模式、时代总览、图例与读图、势力甘特战役事件层。</li>
          <li>3.3 阅读体验：详情阅读进度、收藏与已读、分享（Web Share / 复制链接）、人物小传按有无省略、首启 3 步新手引导。</li>
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
        <br>3.3 体验补全版 · 仅供内部演示<br>从涿鹿到加勒万，山河未已
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

  root.querySelector('[data-action="onboarding"]')?.addEventListener('click', () => showOnboarding({ force: true }));

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
