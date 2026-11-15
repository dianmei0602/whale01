/* ============================================================
   app.js — 应用启动：数据加载 → 路由注册 → 视图渲染
   ============================================================ */

import { loadData } from './data.js';
import { initPWA, initUpdateBar } from './pwa.js';
import { loadSettings } from './store.js';
import { initRouter, navigate, refreshRoute, setHomeScroll } from './router.js';
import { renderTimeline, disposeTimeline } from './timeline.js';
import { renderDetail, disposeDetail } from './detail.js';
import { renderSearch, disposeSearch } from './search.js';
import { renderMap, disposeMap } from './map.js';
import { renderGenerals, disposeGenerals } from './generals.js';
import { renderFactions, disposeFactions } from './factions.js';
import { renderGraph, disposeGraph } from './graph.js';
import { renderReplay, disposeReplay } from './replay.js';
import { renderClan, disposeClan } from './clan.js';
import { renderStats, disposeStats } from './stats.js';
import { renderLegend, disposeLegend } from './legend.js';
import { renderAtlas, disposeAtlas } from './atlas.js';
import { renderFavorites, disposeFavorites } from './favorites.js';
import { renderReplays, disposeReplays } from './replays.js';
import { renderNotFound } from './placeholders.js';
import { renderMore } from './more.js';
import { maybeShowOnboarding } from './onboarding.js';
import { disposeFilterSheet } from './filter.js';
import { toast } from './ui.js';
import {
  skeletonHTML,
  initRipple,
  initTabBounce,
  initSwitchBounce,
  initFlipCards,
} from './motion.js';

const view = document.getElementById('view');
const ctx = { data: null, rerenderHome: () => {}, rerenderMore: () => {} };

function setChrome(mode) {
  document.body.dataset.chrome = mode;
}

function setTab(name) {
  document.querySelectorAll('.tab').forEach((tab) => {
    tab.classList.toggle('is-active', tab.dataset.tab === name);
  });
}

function disposePages() {
  disposeMap();
  disposeGenerals();
  disposeFactions();
  disposeGraph();
  disposeReplay();
  disposeClan();
  disposeStats();
  disposeDetail();
  disposeLegend();
  disposeAtlas();
  disposeFavorites();
  disposeReplays();
}

ctx.rerenderHome = ({ toTop = false } = {}) => {
  if (document.body.dataset.route !== 'timeline') return;
  disposeTimeline();
  renderTimeline(view, ctx);
  if (toTop) {
    setHomeScroll(0);
    window.scrollTo(0, 0);
  }
};

ctx.rerenderMore = () => {
  if (document.body.dataset.route === 'more') renderMore(view, ctx);
};

async function boot() {
  loadSettings();

  // 数据加载较慢时才显示骨架屏（启动「展卷」Loading 已在最上层；避免首屏多余 DOM）
  const skeletonTimer = setTimeout(() => {
    if (!ctx.data && view.children.length === 0) view.innerHTML = skeletonHTML(5);
  }, 450);

  try {
    ctx.data = await loadData();
  } catch (err) {
    console.error('[山河战纪] 数据加载异常', err);
    ctx.data = {
      ok: false,
      eras: [],
      eraById: new Map(),
      battles: [],
      byId: new Map(),
      neighbors: new Map(),
      sections: [],
      yearSpan: 0,
      total: 0,
      source: 'none',
      error: '数据加载异常',
    };
  }

  const locateOnMap = (battleId) => {
    if (!battleId) return;
    const attempt = (depth) => {
      const point = view.querySelector(`#mapPoints [data-battle="${CSS.escape(battleId)}"]`);
      if (point) {
        point.dispatchEvent(new MouseEvent('click', { bubbles: true }));
        const battle = ctx.data.byId.get(battleId);
        const status = view.querySelector('#mapStatus');
        if (status && battle) status.textContent = `定位：${battle.name}`;
        return;
      }
      if (depth >= 2) return;
      const cluster = [...view.querySelectorAll('#mapPoints [data-cluster]')].find((el) =>
        String(el.dataset.cluster || '').split(',').includes(battleId)
      );
      if (cluster) {
        cluster.dispatchEvent(new MouseEvent('click', { bubbles: true }));
        setTimeout(() => attempt(depth + 1), 480);
      }
    };
    setTimeout(() => attempt(0), 160);
  };

  const deferReady3 = (routeName, fn) => {
    if (!ctx.data.ready3 || ctx.data.missing3 !== undefined) return false;
    view.innerHTML = skeletonHTML(4);
    ctx.data.ready3
      .then(() => {
        if (document.body.dataset.route === routeName) fn();
      })
      .catch(() => {
        if (document.body.dataset.route === routeName) fn();
      });
    return true;
  };

  const routes = {
    timeline(route) {
      clearTimeout(skeletonTimer);
      disposeSearch();
      disposeFilterSheet();
      disposePages();
      setChrome('full');
      setTab('timeline');
      renderTimeline(view, ctx, route);
    },

    detail(route) {
      disposeSearch();
      disposeFilterSheet();
      disposeTimeline();
      disposePages();
      setChrome('none');
      setTab('');
      const doRender = () => renderDetail(view, ctx, route);
      if (ctx.data.ready3 && ctx.data.missing3 === undefined) {
        view.innerHTML = skeletonHTML(3);
        ctx.data.ready3.then(() => {
          if (document.body.dataset.route === 'detail') doRender();
        }).catch(doRender);
        return;
      }
      doRender();
    },

    search(route) {
      disposeFilterSheet();
      disposeTimeline();
      disposePages();
      setChrome('none');
      setTab('timeline');
      // 搜索浮层为不透明全屏页，无需在背后渲染时间轴（120 场时可省一次全量渲染）
      renderSearch(ctx, route);
    },

    map(route) {
      disposeSearch();
      disposeFilterSheet();
      disposeTimeline();
      disposePages();
      setChrome('full');
      setTab('map');
      renderMap(view, ctx, route);
      if (route?.query?.battle) locateOnMap(route.query.battle);
    },

    factions(route) {
      disposeSearch();
      disposeFilterSheet();
      disposeTimeline();
      disposePages();
      setChrome('full');
      setTab('factions');
      renderFactions(view, ctx, route);
    },

    graph(route) {
      disposeSearch();
      disposeFilterSheet();
      disposeTimeline();
      disposePages();
      setChrome('full');
      setTab('generals');
      renderGraph(view, ctx, route);
    },

    legend(route) {
      disposeSearch();
      disposeFilterSheet();
      disposeTimeline();
      disposePages();
      setChrome('full');
      setTab('more');
      renderLegend(view, ctx, route);
    },

    atlas(route) {
      disposeSearch();
      disposeFilterSheet();
      disposeTimeline();
      disposePages();
      setChrome('full');
      setTab('more');
      if (!deferReady3('atlas', () => renderAtlas(view, ctx, route))) renderAtlas(view, ctx, route);
    },

    favorites() {
      disposeSearch();
      disposeFilterSheet();
      disposeTimeline();
      disposePages();
      setChrome('full');
      setTab('more');
      renderFavorites(view, ctx);
    },

    replays() {
      disposeSearch();
      disposeFilterSheet();
      disposeTimeline();
      disposePages();
      setChrome('full');
      setTab('more');
      renderReplays(view, ctx);
    },

    clan(route) {
      disposeSearch();
      disposeFilterSheet();
      disposeTimeline();
      disposePages();
      setChrome('full');
      setTab('factions');
      renderClan(view, ctx, route?.params?.id);
    },

    replay(route) {
      disposeSearch();
      disposeFilterSheet();
      disposeTimeline();
      disposePages();
      setChrome('none');
      setTab('');
      renderReplay(view, ctx, route?.params?.id);
    },

    generals(route) {
      disposeSearch();
      disposeFilterSheet();
      disposeTimeline();
      disposePages();
      setChrome('full');
      setTab('generals');
      renderGenerals(view, ctx, route);
    },

    stats() {
      disposeSearch();
      disposeFilterSheet();
      disposeTimeline();
      disposePages();
      setChrome('full');
      setTab('stats');
      renderStats(view, ctx);
    },

    more() {
      disposeSearch();
      disposeFilterSheet();
      disposeTimeline();
      disposePages();
      setChrome('full');
      setTab('more');
      renderMore(view, ctx);
    },

    notfound() {
      disposeSearch();
      disposeFilterSheet();
      disposeTimeline();
      disposePages();
      setChrome('full');
      setTab('');
      renderNotFound(view);
    },

    error(route, err) {
      setChrome('full');
      view.innerHTML = `<div class="page-body" style="padding-top:80px">
        <div class="empty-state">
          <div class="empty-art"></div>
          <h3>页面渲染出错</h3>
          <p>${err ? String(err.message || err) : '未知错误'}。请返回卷首重试。</p>
          <div class="empty-actions"><button class="btn btn--gold" type="button" data-action="home">回到卷首</button></div>
        </div>
      </div>`;
      view.querySelector('[data-action="home"]')?.addEventListener('click', () => navigate('/'));
    },
  };

  // ---------- 路由渲染后的统一收尾：Tab 语义 / 展卷 Loading / 焦点管理 ----------
  const TAB_FOR_ROUTE = {
    timeline: 'timeline',
    search: 'timeline',
    map: 'map',
    factions: 'factions',
    clan: 'factions',
    generals: 'generals',
    graph: 'generals',
    legend: 'more',
    atlas: 'more',
    favorites: 'more',
    replays: 'more',
    stats: 'stats',
    more: 'more',
    detail: '',
    replay: '',
    notfound: '',
  };
  const bootEl = document.getElementById('boot');
  let bootHidden = false;
  const removeBoot = () => {
    if (bootHidden || !bootEl) return;
    bootHidden = true;
    bootEl.classList.add('is-done');
    setTimeout(() => bootEl.remove(), 450);
  };
  // 最长 2s 兜底：即使数据异常也不让「展卷」常驻
  setTimeout(removeBoot, 2000);

  document.addEventListener('route:rendered', (event) => {
    const route = event.detail.route;
    const prev = event.detail.prev;

    // 路由切换的读屏播报（视觉上不可见）
    const live = document.getElementById('route-live');
    if (live) live.textContent = (document.title || '').replace('山河战纪 · ', '') + ' 页面';

    // ---------- 路由 push / pop 方向转场（incoming） ----------
    const push =
      route.name === 'detail' ||
      route.name === 'replay' ||
      route.name === 'clan' ||
      (route.name === 'factions' && route.params?.id);
    const leavingPush =
      prev &&
      (prev.name === 'detail' || prev.name === 'replay' || prev.name === 'clan' || (prev.name === 'factions' && prev.params?.id));
    view.classList.remove('route-push', 'route-pop', 'route-fade');
    view.classList.add(push ? 'route-push' : leavingPush ? 'route-pop' : 'route-fade');

    const activeTab = TAB_FOR_ROUTE[route.name] || '';
    document.querySelectorAll('.tab').forEach((tab) => {
      if (tab.dataset.tab === activeTab) tab.setAttribute('aria-current', 'page');
      else tab.removeAttribute('aria-current');
    });

    // 数据就绪且首个 view 内容已落地后再移除「展卷」；避免连续 hash 切换时残留在中间态
    if (!bootHidden) {
      requestAnimationFrame(() => {
        if (view.childElementCount > 0 || view.textContent.trim()) removeBoot();
        else setTimeout(removeBoot, 80);
      });
    }

    // 3.3 首启引导：只在真正的 #/ 首屏、数据已渲染后出现一次
    if (route.name === 'timeline') {
      setTimeout(() => maybeShowOnboarding(), 300);
    }

    // 路由切换后把焦点交给主内容；搜索页保留输入框焦点
    if (route.name !== 'search') {
      try {
        view.focus({ preventScroll: true });
      } catch (err) {
        /* 忽略 */
      }
    }
  });

  initPWA();
  initUpdateBar();
  initRipple();
  initTabBounce();
  initSwitchBounce();
  initFlipCards();

  // 全局兜底：未捕获异常 / Promise 拒绝不让页面静默失败
  let lastErrorAt = 0;
  const reportError = (label, err) => {
    console.error(`[山河战纪] ${label}`, err);
    const now = Date.now();
    if (now - lastErrorAt < 4000) return;
    lastErrorAt = now;
    try {
      toast('页面出现异常，可返回卷首重试');
    } catch (e) {
      /* ignore */
    }
  };
  window.addEventListener('error', (e) => reportError('未捕获错误', e.error || e.message));
  window.addEventListener('unhandledrejection', (e) => reportError('未处理的 Promise', e.reason));
  initRouter(routes);

  // 2.0 可选数据晚到：补渲染图谱页 / 推演库
  if (ctx.data.ready2) {
    ctx.data.ready2.then(() => {
      if (['graph', 'replays', 'more'].includes(document.body.dataset.route)) refreshRoute();
    });
  }
  // 3.0 考据数据晚到：补渲染详情/势力/家族/名将/图谱/总览
  if (ctx.data.ready3) {
    ctx.data.ready3.then(() => {
      const route = document.body.dataset.route;
      if (['detail', 'factions', 'clan', 'generals', 'graph', 'atlas'].includes(route)) refreshRoute();
    });
  }

  if (ctx.data.source === 'fixture') {
    // 开发期提示（真实 www/data/ 就绪后自动消失）
    setTimeout(() => toast('开发模式：正在使用内存样例数据'), 700);
  } else if (ctx.data.source === 'none') {
    setTimeout(() => toast('数据文件未就绪，已降级为空态'), 500);
  }
}

boot();
