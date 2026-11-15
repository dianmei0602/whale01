/* ============================================================
   pwa.js — Service Worker 注册与版本更新提示
   ============================================================ */

let hadController = false;

function showUpdateBar() {
  const bar = document.getElementById('update-bar');
  if (!bar || !bar.hidden) return;
  bar.hidden = false;
}

export function initPWA() {
  if (!('serviceWorker' in navigator)) return;
  hadController = Boolean(navigator.serviceWorker.controller);
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    // 首次安装也会触发 controllerchange，只有「已有旧版本被替换」时才提示
    if (hadController) showUpdateBar();
  });
  window.addEventListener('load', async () => {
    try {
      const reg = await navigator.serviceWorker.register('sw.js');
      const watch = (worker) => {
        if (!worker) return;
        worker.addEventListener('statechange', () => {
          if (worker.state === 'installed' && navigator.serviceWorker.controller) showUpdateBar();
        });
      };
      watch(reg.installing);
      reg.addEventListener('updatefound', () => watch(reg.installing));
      if (reg.waiting && navigator.serviceWorker.controller) showUpdateBar();
    } catch (err) {
      console.info('[山河战纪] Service Worker 注册失败：', err && err.message ? err.message : err);
    }
  });
}

export function initUpdateBar() {
  const btn = document.getElementById('update-reload');
  if (!btn) return;
  btn.addEventListener('click', () => {
    btn.disabled = true;
    window.location.reload();
  });
}
