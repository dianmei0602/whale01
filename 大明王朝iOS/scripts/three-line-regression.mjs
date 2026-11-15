import { createServer } from 'node:http';
import { createReadStream, mkdirSync, statSync, writeFileSync } from 'node:fs';
import { dirname, extname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(scriptDir, '..', '..');
const outputDir = join(projectRoot, '大明王朝iOS', 'output', 'playwright', 'iphone16pro');
const cdpModule = pathToFileURL('C:/Users/Administrator/.codex/skills/design-taste-frontend/scripts/lib/cdp.mjs').href;
const { Browser, sleep } = await import(cdpModule);
mkdirSync(outputDir, { recursive: true });

const mime = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2'
};

const server = createServer((request, response) => {
  try {
    const pathName = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    let file = resolve(projectRoot, `.${pathName}`);
    if (file !== projectRoot && !file.startsWith(projectRoot)) throw new Error('outside root');
    if (statSync(file).isDirectory()) file = join(file, 'index.html');
    response.writeHead(200, {
      'content-type': mime[extname(file).toLowerCase()] || 'application/octet-stream',
      'content-length': statSync(file).size,
      'cache-control': 'no-store'
    });
    createReadStream(file).pipe(response);
  } catch {
    response.writeHead(404);
    response.end('not found');
  }
});

await new Promise((done) => server.listen(0, '127.0.0.1', done));
const baseUrl = `http://127.0.0.1:${server.address().port}`;
const browser = await Browser.launch();
const page = await browser.newPage({ width: 402, height: 874, dsf: 2, mobile: true });
const consoleErrors = [];
page.browser.on(page.sessionId, 'Runtime.consoleAPICalled', (event) => {
  if (event.type === 'error') consoleErrors.push(event.args.map((arg) => arg.value || arg.description || '').join(' '));
});

const checks = [];
const check = (name, pass, details) => checks.push({ name, pass: Boolean(pass), details });

try {
  await page.goto(`${baseUrl}/%E5%A4%A7%E6%98%8E%E7%8E%8B%E6%9C%9DiOS/index.html`, { settleMs: 1900 });

  const initial = await page.eval(() => {
    hideLaunch();
    switchTab('timeline', { top: true });
    showRouteMode('pressure');
    return {
      year: document.getElementById('yearBig').textContent,
      focusTitle: document.getElementById('yearFocusTitle').textContent,
      activeAct: document.querySelector('#syncActStrip .on b')?.textContent,
      routeNavHidden: document.getElementById('routeActMap').hidden
    };
  });
  await sleep(200);
  await page.screenshot({ path: join(outputDir, 'three-line-tab-top-mobile-v3.png'), format: 'png' });
  await page.eval(() => document.querySelector('.year-card').scrollIntoView({ block: 'start' }));
  await sleep(150);
  await page.screenshot({ path: join(outputDir, 'three-line-1368-mobile-v3.png'), format: 'png' });
  check('timeline opens with a readable narrative year', initial.year === '1368' && initial.focusTitle.length > 4, initial);
  check('timeline opens on the first act', initial.activeAct === '一幕', initial.activeAct);
  check('pressure mode has one act navigator', initial.routeNavHidden, initial.routeNavHidden);

  const timeline = await page.eval(() => {
    hideLaunch();
    switchTab('timeline', { top: true });
    document.querySelector('[data-rmode="pressure"]').click();
    document.querySelector('[data-sync-act="2"]').click();
    const range = document.getElementById('yearRange');
    range.value = '1449';
    range.dispatchEvent(new Event('input', { bubbles: true }));
    document.querySelector('.year-card').scrollIntoView({ block: 'start' });
    return {
      width: innerWidth,
      height: innerHeight,
      acts: document.querySelectorAll('#syncActStrip [data-sync-act]').length,
      activeAct: document.querySelector('#syncActStrip .on b')?.textContent,
      svgActLabels: [...document.querySelectorAll('#miniAxis text')]
        .map((node) => node.textContent)
        .filter((text) => text.includes('幕')),
      year: document.getElementById('yearBig').textContent,
      events: document.querySelectorAll('#syncFocus [data-sync-event]').length,
      expectedEvents: window.DAM_CONTENT.events.filter((event) => event.year === 1449).length,
      pageOverflow: document.documentElement.scrollWidth - innerWidth,
      viewOverflow: document.getElementById('viewTimeline').scrollWidth - document.getElementById('viewTimeline').clientWidth
    };
  });
  await sleep(250);
  await page.screenshot({ path: join(outputDir, 'three-line-1449-mobile-v2.png'), format: 'png' });
  check('five act key', timeline.acts === 5, timeline.acts);
  check('current act follows year', timeline.activeAct === '三幕', timeline.activeAct);
  check('no act labels inside plot', timeline.svgActLabels.length === 0, timeline.svgActLabels);
  check('slider selects 1449', timeline.year === '1449', timeline.year);
  check('all synchronized events for the year are visible', timeline.events === timeline.expectedEvents, timeline);
  check('timeline has no page overflow', timeline.pageOverflow <= 0, timeline.pageOverflow);
  check('timeline has no view overflow', timeline.viewOverflow <= 0, timeline.viewOverflow);

  const trend = await page.eval(() => {
    document.querySelector('.decade-panel').scrollIntoView({ block: 'start' });
    const labels = [...document.querySelectorAll('#miniAxis text')].map((node) => node.textContent);
    const pressureNames = [...document.querySelectorAll('.pressure-name')].map((node) => node.textContent.trim());
    const pressureDetails = [...document.querySelectorAll('.pressure-card > p')].map((node) => node.textContent.trim());
    return {
      focusTitle: document.getElementById('yearFocusTitle').textContent,
      focusSummary: document.getElementById('yearFocusSummary').textContent,
      pressureNames,
      pressureDetails,
      yLabels: ['0', '50', '100'].every((label) => labels.includes(label)),
      yearLabels: ['1444', '1446', '1449', '1452', '1454'].every((label) => labels.includes(label)),
      series: document.querySelectorAll('#miniAxis polyline').length,
      chartLabel: document.getElementById('miniAxis').getAttribute('aria-label'),
      note: document.getElementById('pressureIndexNote')?.textContent || '',
      range: document.getElementById('decadeRange').textContent,
      previousDisabled: document.getElementById('prevTurningPoint').disabled,
      previousLabel: document.getElementById('prevTurningPoint').textContent,
      nextLabel: document.getElementById('nextTurningPoint').textContent,
      touchTargets: [...document.querySelectorAll('.sync-act-chip,.slider-quick button,.year-focus-action,.dynasty-detail summary')]
        .map((element) => element.getBoundingClientRect().height)
    };
  });
  await sleep(200);
  await page.screenshot({ path: join(outputDir, 'three-line-trend-1449-mobile-v3.png'), format: 'png' });
  check('year focus names the major event', trend.focusTitle.includes('土木堡'), trend.focusTitle);
  check('year focus explains why the year matters', trend.focusSummary.length >= 20, trend.focusSummary);
  check('pressure rows use full readable names', trend.pressureNames.join('|') === '边患线|党争线|财政线', trend.pressureNames);
  check('pressure rows explain each line', trend.pressureDetails.every((text) => text.length >= 8), trend.pressureDetails);
  check('decade chart has a readable y scale', trend.yLabels, trend);
  check('decade chart has readable year ticks', trend.yearLabels, trend);
  check('decade chart has exactly three series', trend.series === 3, trend.series);
  check('decade chart explains its current values to assistive tech', trend.chartLabel.includes('边患96') && trend.chartLabel.includes('党争84') && trend.chartLabel.includes('财政72'), trend.chartLabel);
  check('decade view names its ten-year window', trend.range === '1444—1454', trend.range);
  check('pressure index is disclosed as editorial', trend.note.includes('不是明代') && trend.note.includes('原始统计'), trend.note);
  check('event-year navigation is available in both directions', !trend.previousDisabled && trend.previousLabel.includes('1448') && trend.nextLabel.includes('1450'), trend);
  check('new timeline controls meet touch size', trend.touchTargets.every((height) => height >= 44), trend.touchTargets);

  const navigation = await page.eval(() => {
    document.getElementById('prevTurningPoint').click();
    const previousYear = document.getElementById('yearBig').textContent;
    document.getElementById('nextTurningPoint').click();
    const returnedYear = document.getElementById('yearBig').textContent;
    return { previousYear, returnedYear };
  });
  check('previous event control changes the year', navigation.previousYear === '1448', navigation);
  check('next event control returns to 1449', navigation.returnedYear === '1449', navigation);

  const overviewState = await page.eval(() => {
    const details = document.querySelector('.dynasty-detail');
    details.open = true;
    details.scrollIntoView({ block: 'start' });
    return {
      open: details.open,
      series: document.querySelectorAll('#overviewAxis polyline').length,
      labels: [...document.querySelectorAll('#overviewAxis text')].map((node) => node.textContent)
    };
  });
  await sleep(200);
  await page.screenshot({ path: join(outputDir, 'three-line-overview-1449-mobile-v3.png'), format: 'png' });
  check('full-dynasty chart is available on demand', overviewState.open && overviewState.series === 3, overviewState);
  check('full-dynasty chart keeps readable scale and decades', ['1368', '1450', '1550', '1662', '0', '100'].every((label) => overviewState.labels.includes(label)), overviewState.labels);

  const matrix = await page.eval(() => {
    const panel = document.querySelector('.chapter-matrix-panel');
    panel.scrollIntoView({ block: 'start' });
    const first = document.querySelector('.chapter-matrix-year');
    const firstCell = document.querySelector('.chapter-matrix-cell');
    return {
      columns: document.querySelectorAll('.chapter-matrix-year').length,
      firstHeading: first.textContent.replace(/\s+/g, ''),
      firstTitle: first.title,
      cell: { width: firstCell.getBoundingClientRect().width, height: firstCell.getBoundingClientRect().height },
      scrollerOverflow: document.getElementById('chapterMatrix').scrollWidth > document.getElementById('chapterMatrix').clientWidth,
      pageOverflow: document.documentElement.scrollWidth - innerWidth
    };
  });
  await sleep(200);
  await page.screenshot({ path: join(outputDir, 'chapter-matrix-mobile-v2.png'), format: 'png' });
  check('20 chapter columns', matrix.columns === 20, matrix.columns);
  check('chapter heading is explicit', matrix.firstHeading.includes('第1章') && matrix.firstHeading.includes('1351'), matrix.firstHeading);
  check('matrix has full heading tooltip', matrix.firstTitle.includes('第1章'), matrix.firstTitle);
  check('matrix touch target', matrix.cell.width >= 44 && matrix.cell.height >= 44, matrix.cell);
  check('matrix scrolls inside its frame', matrix.scrollerOverflow, matrix.scrollerOverflow);
  check('matrix has no page overflow', matrix.pageOverflow <= 0, matrix.pageOverflow);

  const causalIntegrity = await page.eval(() => {
    const value = (event) => {
      const exact = Number(event.time?.sortValue);
      return Number.isFinite(exact) ? exact : (Number(event.year) || 0) * 100 + (Number(event.time?.month) || 0);
    };
    const failures = [];
    let totalLinks = 0;
    let empty = 0;
    for (const event of window.DAM_CONTENT.events) {
      const holder = document.createElement('div');
      holder.innerHTML = eventCausalFlow(event);
      const links = [...holder.querySelectorAll('.causal-column:first-child [data-full-event]')];
      if (!links.length) empty += 1;
      for (const link of links) {
        totalLinks += 1;
        const previous = window.DAM_CONTENT.events.find((item) => item.id === link.dataset.fullEvent);
        const shared = previous?.threads?.filter((thread) => event.threads?.includes(thread)) || [];
        if (!previous || value(previous) >= value(event) || !shared.length) {
          failures.push({ current: event.id, previous: link.dataset.fullEvent, currentTime: value(event), previousTime: previous ? value(previous) : null });
        }
      }
    }
    return { events: window.DAM_CONTENT.events.length, totalLinks, empty, failures: failures.slice(0, 20), failureCount: failures.length };
  });
  check('all prior-event links are strictly earlier', causalIntegrity.failureCount === 0, causalIntegrity);
  check('all prior-event links share a pressure line', causalIntegrity.failureCount === 0, causalIntegrity);

  await page.goto(`${baseUrl}/%E5%A4%A7%E6%98%8E%E7%8E%8B%E6%9C%9DiOS/index.html?view=event&id=e1449_gonggong`, { settleMs: 1900 });
  const causal = await page.eval(() => {
    hideLaunch();
    const flow = document.querySelector('#detailView .causal-flow');
    flow.scrollIntoView({ block: 'start' });
    const columns = [...flow.querySelectorAll('.causal-column')];
    const previous = [...columns[0].querySelectorAll('[data-full-event]')].map((button) => button.dataset.fullEvent);
    const first = columns[0].getBoundingClientRect();
    const second = columns[1].getBoundingClientRect();
    return {
      sections: columns.length,
      previous,
      labels: columns.map((column) => column.querySelector(':scope > span')?.textContent),
      firstTime: columns[0].querySelector('time')?.textContent,
      stacked: Math.abs(first.left - second.left) < 1 && second.top >= first.bottom,
      touchTargets: [...flow.querySelectorAll('.causal-link')].map((button) => button.getBoundingClientRect().height),
      bodyFont: getComputedStyle(columns[0].querySelector('p, em') || columns[0]).fontSize,
      pageOverflow: document.documentElement.scrollWidth - innerWidth,
      detailOverflow: document.getElementById('detailScroll').scrollWidth - document.getElementById('detailScroll').clientWidth
    };
  });
  await sleep(250);
  await page.screenshot({ path: join(outputDir, 'event-causal-mobile-v2.png'), format: 'png' });
  check('causal view has three stages', causal.sections === 3, causal.sections);
  check('causal stages stack on the phone', causal.stacked, causal);
  check('causal touch targets are at least 44px', causal.touchTargets.every((height) => height >= 44), causal.touchTargets);
  check('causal text is readable', parseFloat(causal.bodyFont) >= 12, causal.bodyFont);
  check('causal has no page overflow', causal.pageOverflow <= 0, causal.pageOverflow);
  check('causal has no detail overflow', causal.detailOverflow <= 0, causal.detailOverflow);
  check('sample event shows only earlier evidence', !causal.previous.includes('e1449_dingce') && !causal.previous.includes('e1449_beijing'), causal.previous);

  await page.setViewport({ width: 700, height: 874, dsf: 1, mobile: false });
  await sleep(200);
  const causalWide = await page.eval(() => {
    const flow = document.querySelector('#detailView .causal-flow');
    flow.scrollIntoView({ block: 'start' });
    const columns = [...flow.querySelectorAll('.causal-column')].map((column) => {
      const rect = column.getBoundingClientRect();
      return { left: rect.left, top: rect.top, width: rect.width };
    });
    return {
      columns,
      horizontal: columns.length === 3 && columns.every((column) => Math.abs(column.top - columns[0].top) < 1),
      pageOverflow: document.documentElement.scrollWidth - innerWidth
    };
  });
  await sleep(200);
  await page.screenshot({ path: join(outputDir, 'event-causal-wide-3col-v2.png'), format: 'png' });
  check('causal keeps three columns on wider screens', causalWide.horizontal, causalWide);
  check('wide causal has no page overflow', causalWide.pageOverflow <= 0, causalWide.pageOverflow);
  check('no javascript errors', consoleErrors.length === 0 && page.consoleErrors.length === 0, { consoleErrors, exceptions: page.consoleErrors });

  const report = {
    generatedAt: new Date().toISOString(),
    viewport: { width: 402, height: 874, device: 'iPhone 16 Pro logical viewport' },
    pass: checks.every((item) => item.pass),
    checks,
    causalIntegrity,
    screenshots: [
      join(outputDir, 'three-line-tab-top-mobile-v3.png'),
      join(outputDir, 'three-line-1368-mobile-v3.png'),
      join(outputDir, 'three-line-1449-mobile-v2.png'),
      join(outputDir, 'three-line-trend-1449-mobile-v3.png'),
      join(outputDir, 'three-line-overview-1449-mobile-v3.png'),
      join(outputDir, 'chapter-matrix-mobile-v2.png'),
      join(outputDir, 'event-causal-mobile-v2.png'),
      join(outputDir, 'event-causal-wide-3col-v2.png')
    ]
  };
  writeFileSync(join(outputDir, 'three-line-regression.json'), `${JSON.stringify(report, null, 2)}\n`);
  console.log(JSON.stringify(report, null, 2));
  if (!report.pass) process.exitCode = 1;
} finally {
  await page.close();
  await browser.close();
  server.closeAllConnections();
  await new Promise((done) => server.close(done));
}
