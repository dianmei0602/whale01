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
  const peopleText = bioTotal ? `${bioTotal} 位人物` : '—';
  const factionCount = (ctx.data.factions || []).length;
  const relationCount = (ctx.data.relations || []).length;
  const clanCount = (ctx.data.clans || []).length;
  const totalBattles = ctx.data.total || 0;
  const eraCount = (ctx.data.eras || []).length;
  const dash = (value) => (Number.isFinite(Number(value)) ? Number(value) : '—');
  return `<div class="more-page">
    <header class="page-head">
      <div class="head-title"><h1 class="page-h1" id="moreTitle">更多</h1><span class="head-sub">我的阅读 · 探索 · 设置与关于</span></div>
      <div class="head-actions">
        <button class="icon-btn" type="button" data-action="search" aria-label="搜索">${icon('search')}</button>
      </div>
    </header>

    <div class="page-body">
      <section class="settings-group more-primary" aria-labelledby="myReadingTitle">
        <h2 class="settings-group-title" id="myReadingTitle">我的阅读</h2>
        <a class="setting-row" href="#/favorites">
          <div class="sr-main">
            <div class="sr-label">收藏与进度</div>
            <div class="sr-desc">收藏的战役、已读状态与上次阅读位置</div>
          </div>
          <span class="ph-soon">${favCount} 场</span>
        </a>
        <a class="setting-row" href="#/replays">
          <div class="sr-main">
            <div class="sr-label">动画推演</div>
            <div class="sr-desc">重点战役分阶段推演 · 按时期与类型筛选</div>
          </div>
          <span class="ph-soon">${replayCount} 场</span>
        </a>
      </section>

      <section class="settings-group" aria-labelledby="exploreTitle">
        <h2 class="settings-group-title" id="exploreTitle">探索</h2>
        <a class="setting-row" href="#/stats">
          <div class="sr-main">
            <div class="sr-label">统计</div>
            <div class="sr-desc">时期数量、类型分布、时间密度与胜负口径</div>
          </div>
          <span class="ph-soon">4 类图表</span>
        </a>
        <a class="setting-row" href="#/atlas">
          <div class="sr-main">
            <div class="sr-label">时代总览</div>
            <div class="sr-desc">一屏查看时期、战役与势力国祚</div>
          </div>
          <span class="ph-soon">总览</span>
        </a>
        <a class="setting-row" href="#/legend">
          <div class="sr-main">
            <div class="sr-label">图例与读图</div>
            <div class="sr-desc">时间轴、地图、关系图谱、甘特与家族谱</div>
          </div>
          <span class="ph-soon">5 节</span>
        </a>
      </section>

      <section class="settings-group settings-about" aria-labelledby="settingsAboutTitle">
        <h2 class="settings-group-title" id="settingsAboutTitle">设置与关于</h2>

        <div class="settings-subgroup" aria-labelledby="readingSettingsTitle">
          <h3 class="settings-subtitle" id="readingSettingsTitle">阅读设置</h3>
          <div class="setting-row">
            <div class="sr-main">
              <div class="sr-label">正文字号</div>
              <div class="sr-desc">三档可调，立即生效并记住</div>
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
        </div>

        <div class="settings-subgroup" aria-labelledby="dataSettingsTitle">
          <h3 class="settings-subtitle" id="dataSettingsTitle">数据与来源</h3>
          <div class="setting-row">
            <div class="sr-main">
              <div class="sr-label">史料来源</div>
              <div class="sr-desc">《史记》《资治通鉴》《中国历代战争史》等；每场战役文末标注出处</div>
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
        </div>

        <div class="settings-subgroup" aria-labelledby="helpSettingsTitle">
          <h3 class="settings-subtitle" id="helpSettingsTitle">帮助与关于</h3>
          <button class="setting-row" type="button" data-action="onboarding">
            <div class="sr-main">
              <div class="sr-label">重新查看新手引导</div>
              <div class="sr-desc">时间轴、地图与关系入口的简短说明</div>
            </div>
            <span class="ph-soon">3 步</span>
          </button>
          <a class="setting-row" href="privacy.html">
            <div class="sr-main">
              <div class="sr-label">隐私政策</div>
              <div class="sr-desc">本机存储说明 · 无账号 · 无网络上传</div>
            </div>
            <span class="ph-soon">查看</span>
          </a>
          <div class="setting-row about-reset">
            <div class="sr-main">
              <div class="sr-label">恢复默认设置</div>
              <div class="sr-desc">字号标准 · 完整动效</div>
            </div>
            <button class="btn" type="button" data-action="reset-settings">恢复</button>
          </div>
        </div>

        <section class="about-card" aria-labelledby="aboutTitle">
          <div class="about-heading">
            <h3 id="aboutTitle">山河战纪</h3>
            <span class="about-version">3.3.0</span>
          </div>
          <p class="about-sub">从涿鹿到加勒万 · 中国战史时间轴</p>
          <p>一部可以顺着时间轴一路读下去的中国战史。全量离线，无广告、无账号、无内购。</p>
          <div class="about-meta">
            <span>内容 <b>${dash(totalBattles)} 场 · ${dash(eraCount)} 期 · ${peopleText}</b></span>
            <span>关系图谱 <b>${dash(factionCount)} 势力 · ${dash(relationCount)} 关系 · ${dash(clanCount)} 家族</b></span>
            <span>入谱 <b>${bioTotal ? `${dash(bioFeatured)} 位 · 关系图谱` : '—'}</b></span>
            <span>推演 <b>${dash(replayCount)} 场 · 本机收藏 ${favCount} 场</b></span>
          </div>
          <details class="about-more">
            <summary>版本与资料说明</summary>
            <p>3.3 阅读闭环包含进度、收藏与分享；3.2 增加关系可视化与时代总览；3.0 补齐战役档案、势力版图与家族谱。持续校核史料口径。</p>
            <p>视觉使用本地生成的水墨纹理、山脉与印章；标准地图审图号 GS(2022)4307。</p>
          </details>
        </section>
      </section>

      <footer class="detail-foot">
        <span class="foot-seal">山河战纪</span>
        <br>3.3.0 · 仅供内部演示<br>从涿鹿到加勒万，山河未已
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
