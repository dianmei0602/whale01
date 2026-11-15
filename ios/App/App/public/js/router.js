/* ============================================================
   router.js — hash 路由：#/ #/battle/<id> #/map #/generals
               #/stats #/search #/more；刷新任一路由可直达
   维护一个简单的页面栈，供「返回」「关闭搜索」使用。
   ============================================================ */

let viewMap = null;
let lastRoute = null;
let prevRoute = null;
let homeScroll = 0;
let started = false;

const stack = [];
let backTarget = null;

export function parseHash(hash) {
  const raw = String(hash == null ? window.location.hash : hash).replace(/^#/, '');
  const withSlash = raw.startsWith('/') ? raw : '/' + raw;
  const [pathname] = withSlash.split('?');
  const seg = pathname.split('/').filter(Boolean);
  if (!seg.length) return { name: 'timeline', params: {}, path: '/' };
  if (seg[0] === 'battle' && seg[1]) {
    return { name: 'detail', params: { id: decodeURIComponent(seg[1]) }, path: pathname };
  }
  if (seg[0] === 'factions') {
    return {
      name: 'factions',
      params: seg[1] ? { id: decodeURIComponent(seg[1]) } : {},
      path: pathname,
    };
  }
  if (seg[0] === 'replay' && seg[1]) {
    return { name: 'replay', params: { id: decodeURIComponent(seg[1]) }, path: pathname };
  }
  if (['map', 'generals', 'stats', 'more', 'search', 'graph'].includes(seg[0])) {
    return { name: seg[0], params: {}, path: pathname };
  }
  return { name: 'notfound', params: { path: pathname }, path: pathname };
}

function hashFor(path) {
  return '#' + (String(path || '/').startsWith('/') ? path : '/' + path);
}

export function navigate(path) {
  const target = hashFor(path);
  if (window.location.hash === target) dispatch();
  else window.location.hash = target;
}

/** 返回上一页（来自页面栈），无栈时回时间轴 */
export function navigateBack() {
  let target = null;
  while (stack.length) {
    const candidate = stack.pop();
    if (candidate && candidate !== lastRoute?.path) {
      target = candidate;
      break;
    }
  }
  if (!target) target = '/';
  backTarget = target;
  const targetHash = hashFor(target);
  if (window.location.hash === targetHash) {
    backTarget = null;
    dispatch();
  } else {
    window.location.hash = targetHash;
  }
}

export function getPrevRoute() {
  return prevRoute;
}

export function setHomeScroll(value) {
  homeScroll = Number.isFinite(Number(value)) ? Number(value) : 0;
}

function clearOverlays() {
  document.body.classList.remove('search-open');
  document.querySelectorAll('.bottom-sheet, .scrim, #search-screen').forEach((el) => el.remove());
}

function applyScroll(route) {
  if (route.name === 'timeline') {
    if (homeScroll > 0) {
      const y = homeScroll;
      window.scrollTo(0, y);
      requestAnimationFrame(() => window.scrollTo(0, y));
    }
  } else {
    window.scrollTo(0, 0);
  }
}

function dispatch() {
  if (!viewMap) return;
  const next = parseHash();
  const from = lastRoute;

  if (from && from.name === 'timeline' && next.name !== 'timeline') {
    homeScroll = window.scrollY || 0;
  }

  // 维护页面栈：普通前进推入上一页；返回时不再推入
  if (from && from.path !== next.path) {
    if (backTarget && next.path === backTarget) {
      backTarget = null;
    } else {
      stack.push(from.path);
      if (stack.length > 40) stack.shift();
    }
  }

  clearOverlays();

  const handler = viewMap[next.name] || viewMap.notfound;
  try {
    handler(next);
  } catch (err) {
    console.error('[山河战纪] 页面渲染失败', err);
    viewMap.error?.(next, err);
  }

  document.body.dataset.route = next.name;
  document.title = titleFor(next);

  applyScroll(next);

  prevRoute = from;
  lastRoute = next;
  document.dispatchEvent(new CustomEvent('route:rendered', { detail: { route: next, prev: from } }));
}

function titleFor(route) {
  const map = {
    timeline: '时间轴',
    map: '战役地图',
    factions: '势力',
    generals: '名将',
    graph: '关系图谱',
    stats: '统计',
    more: '更多',
    search: '搜索',
    detail: '战役详情',
    replay: '动画推演',
    notfound: '页面未找到',
  };
  return `山河战纪 · ${map[route.name] || ''}`;
}

export function initRouter(map) {
  viewMap = map;
  if (!started) {
    started = true;
    window.addEventListener('hashchange', dispatch);
  }
  dispatch();
}
