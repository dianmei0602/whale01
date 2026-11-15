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
  const [pathname, search = ''] = withSlash.split('?');
  const query = {};
  try {
    new URLSearchParams(search).forEach((value, key) => {
      query[key] = value;
    });
  } catch (err) {
    /* 忽略非法 query */
  }
  const seg = pathname.split('/').filter(Boolean);
  if (!seg.length) return { name: 'timeline', params: {}, query, path: '/' };
  if (seg[0] === 'battle' && seg[1]) {
    return { name: 'detail', params: { id: decodeURIComponent(seg[1]) }, query, path: pathname };
  }
  if (seg[0] === 'factions') {
    return {
      name: 'factions',
      params: seg[1] ? { id: decodeURIComponent(seg[1]) } : {},
      query,
      path: pathname,
    };
  }
  if (seg[0] === 'clan' && seg[1]) {
    return { name: 'clan', params: { id: decodeURIComponent(seg[1]) }, query, path: pathname };
  }
  if (seg[0] === 'replay' && seg[1]) {
    return { name: 'replay', params: { id: decodeURIComponent(seg[1]) }, query, path: pathname };
  }
  if (['map', 'generals', 'stats', 'more', 'search', 'graph'].includes(seg[0])) {
    return { name: seg[0], params: {}, query, path: pathname };
  }
  return { name: 'notfound', params: { path: pathname }, query, path: pathname };
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
  const fromStack = Boolean(target);
  if (!target) target = '/';
  backTarget = target;
  const targetHash = hashFor(target);
  if (window.location.hash === targetHash) {
    backTarget = null;
    dispatch();
    return;
  }

  // 正常前进流程：上一页就是浏览器历史的上一条 → 用 history.back() 回退，
  // 避免向历史栈再压一条「返回后的页面」（否则系统返回/侧滑会再回到刚退出的页面）。
  if (fromStack && prevRoute && prevRoute.path === target) {
    const before = window.location.hash;
    history.back();
    window.setTimeout(() => {
      if (window.location.hash === before) {
        // 没有可回退的历史条目（如直接深链进入）：用 replace 不留重复记录
        backTarget = target;
        window.location.replace(targetHash);
      }
    }, 180);
    return;
  }

  // 深链首屏：没有可回退的上一页，用 replace 回卷首，不污染历史
  if (!fromStack) {
    window.location.replace(targetHash);
    return;
  }

  window.location.hash = targetHash;
}

/** 重新渲染当前路由，不新增历史记录（用于可选数据晚到的补渲染） */
export function refreshRoute() {
  dispatch();
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
    clan: '家族谱',
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
