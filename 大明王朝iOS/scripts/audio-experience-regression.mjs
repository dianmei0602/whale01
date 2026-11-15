import { createHmac } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createAppServer, buildTtsUrl, resolveTtsEndpoint } from '../server.mjs';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const root = resolve(scriptDir, '..');
const outputDir = join(root, 'output', 'playwright', 'audio');
mkdirSync(outputDir, { recursive: true });

const cdpModule = pathToFileURL('C:/Users/Administrator/.codex/skills/design-taste-frontend/scripts/lib/cdp.mjs').href;
const { Browser, sleep } = await import(cdpModule);
const checks = [];
const check = (name, pass, details) => checks.push({ name, pass: Boolean(pass), details });

const testDate = new Date('2026-11-15T13:00:00Z');
const signedUrl = new URL(buildTtsUrl({ apiKey: 'test-key', apiSecret: 'test-secret' }, testDate));
const expectedSignature = createHmac('sha256', 'test-secret')
  .update(`host: tts-api.xfyun.cn\ndate: ${testDate.toUTCString()}\nGET /v2/tts HTTP/1.1`)
  .digest('base64');
check('iFlytek signature URL uses the official host', signedUrl.hostname === 'tts-api.xfyun.cn' && signedUrl.pathname === '/v2/tts', signedUrl.origin + signedUrl.pathname);
check('iFlytek signature date is RFC1123 GMT', signedUrl.searchParams.get('date') === testDate.toUTCString(), signedUrl.searchParams.get('date'));

const signedAuthText = Buffer.from(signedUrl.searchParams.get('authorization'), 'base64').toString('utf8');
check('iFlytek authorization carries the HMAC signature', signedAuthText.includes(`signature="${expectedSignature}"`), signedAuthText);

const privateVoiceFallback = resolveTtsEndpoint({
  endpoint: 'wss://private.example/v1/private/test',
  voice: 'x4_yezi'
});
check(
  'x4_yezi avoids private voice families and keeps the requested voice',
  privateVoiceFallback.endpoint === 'wss://tts-api.xfyun.cn/v2/tts'
    && privateVoiceFallback.requestedEndpointKind === 'private-super-human'
    && privateVoiceFallback.fallbackReason === 'voice-not-supported-by-private-endpoint',
  privateVoiceFallback
);

const fallbackServer = createAppServer({
  configProvider: () => ({ appId: '', apiKey: '', apiSecret: '', endpoint: '', voice: '', speed: 45, volume: 65, pitch: 48 })
});
const liveServer = createAppServer();
await Promise.all([
  new Promise((done) => fallbackServer.listen(0, '127.0.0.1', done)),
  new Promise((done) => liveServer.listen(0, '127.0.0.1', done))
]);
const base = `http://127.0.0.1:${fallbackServer.address().port}`;
const liveBase = `http://127.0.0.1:${liveServer.address().port}`;

const statusResponse = await fetch(`${base}/api/tts/status`);
const status = await statusResponse.json();
check('TTS status endpoint is available', statusResponse.ok && status.provider === 'iFlytek WebAPI', status);

const fallbackTtsResponse = await fetch(`${base}/api/tts`, {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ text: '大明王朝' })
});
const fallbackTtsError = await fallbackTtsResponse.json();
check('unconfigured iFlytek fails honestly', fallbackTtsResponse.status === 503 && fallbackTtsError.error === 'TTS_NOT_CONFIGURED', { status: fallbackTtsResponse.status, ttsError: fallbackTtsError });

const liveStatusResponse = await fetch(`${liveBase}/api/tts/status`);
const liveStatus = await liveStatusResponse.json();
check('configured iFlytek account is detected from local env', liveStatusResponse.ok && liveStatus.configured === true, liveStatus);
check('iFlytek uses the requested Xiaolu voice', liveStatus.voice === 'x4_yezi', liveStatus);
check('iFlytek speed is tuned for continuous reading', liveStatus.speed === 55, liveStatus);

let liveTtsBytes = 0;
if (liveStatus.configured) {
  const liveTtsResponse = await fetch(`${liveBase}/api/tts`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ text: '大明王朝，山河入卷。' })
  });
  const audio = Buffer.from(await liveTtsResponse.arrayBuffer());
  liveTtsBytes = audio.length;
  check('real iFlytek synthesis returns MP3 audio', liveTtsResponse.ok && /audio\/mpeg/.test(liveTtsResponse.headers.get('content-type') || '') && liveTtsBytes > 1000, {
    status: liveTtsResponse.status,
    type: liveTtsResponse.headers.get('content-type'),
    bytes: liveTtsBytes
  });
  if (liveTtsResponse.ok) writeFileSync(join(outputDir, 'xfyun-live-sample.mp3'), audio);
}

const browser = await Browser.launch();
const page = await browser.newPage({ width: 402, height: 874, dsf: 2, mobile: true });
const consoleErrors = [];
page.browser.on(page.sessionId, 'Runtime.consoleAPICalled', (event) => {
  if (event.type === 'error') consoleErrors.push(event.args.map((arg) => arg.value || arg.description || '').join(' '));
});

await page.send('Page.addScriptToEvaluateOnNewDocument', {
  source: `
    window.__speechLog = { spoken: [], cancelled: 0 };
    window.SpeechSynthesisUtterance = class {
      constructor(text) { this.text = text; this.lang = ''; this.rate = 1; this.pitch = 1; this.voice = null; }
    };
    Object.defineProperty(window, 'speechSynthesis', {
      configurable: true,
      value: {
        getVoices() { return [{ lang: 'zh-CN', name: 'Mock Mandarin' }]; },
        speak(utterance) {
          window.__speechLog.spoken.push(utterance.text);
          setTimeout(() => utterance.onstart && utterance.onstart(), 0);
        },
        cancel() { window.__speechLog.cancelled += 1; }
      }
    });
  `
});

try {
  await page.goto(`${base}/index.html`, { settleMs: 1900 });
  const initial = await page.eval(() => ({
    musicPressed: document.getElementById('musicToggle').getAttribute('aria-pressed'),
    readPressed: document.querySelector('[data-read-toggle]').getAttribute('aria-pressed'),
    actions: [...document.querySelectorAll('.nav-action')].map((button) => {
      const rect = button.getBoundingClientRect();
      return { width: rect.width, height: rect.height, label: button.getAttribute('aria-label') };
    }),
    pageOverflow: document.documentElement.scrollWidth - innerWidth
  }));
  check('music starts paused by default', initial.musicPressed === 'false', initial);
  check('reading starts paused by default', initial.readPressed === 'false', initial);
  check('navigation audio controls meet touch size', initial.actions.length === 3 && initial.actions.every((item) => item.width >= 44 && item.height >= 44), initial.actions);
  check('audio controls cause no page overflow', initial.pageOverflow <= 0, initial.pageOverflow);
  await page.screenshot({ path: join(outputDir, 'audio-nav-mobile.png'), format: 'png' });

  await page.eval(() => document.getElementById('musicToggle').click());
  await sleep(1500);
  const musicOn = await page.eval(() => ({
    playing: window.DamMusic.playing,
    contextState: window.DamMusic.context?.state,
    melodyIndex: window.DamMusic.melodyIndex,
    gain: window.DamMusic.master?.gain.value,
    pressed: document.getElementById('musicToggle').getAttribute('aria-pressed')
  }));
  check('guqin score starts on explicit control', musicOn.playing && musicOn.contextState === 'running', musicOn);
  check('guqin score schedules notes', musicOn.melodyIndex > 0 && musicOn.gain > 0, musicOn);
  check('music control reflects playing state', musicOn.pressed === 'true', musicOn);

  await page.eval(() => document.getElementById('musicToggle').click());
  await sleep(900);
  const musicOff = await page.eval(() => ({
    playing: window.DamMusic.playing,
    pressed: document.getElementById('musicToggle').getAttribute('aria-pressed')
  }));
  check('guqin score pauses and remembers off', !musicOff.playing && musicOff.pressed === 'false', musicOff);

  await page.goto(`${base}/index.html?view=event&id=e1449_tumu`, { settleMs: 1900 });
  await sleep(300);
  await page.eval(async () => { await window.DamMusic.start(); });
  await page.eval(() => document.querySelector('#detailView [data-read-toggle]').click());
  await sleep(500);
  const reading = await page.eval(() => ({
    state: window.DamSpeech.state,
    engine: window.DamSpeech.engine,
    spokenLength: window.__speechLog.spoken[0]?.length || 0,
    spokenStart: window.__speechLog.spoken[0]?.slice(0, 60) || '',
    spokenHasLineBreaks: /[\r\n]/.test(window.__speechLog.spoken[0] || ''),
    extracted: window.DamSpeech.extractText(),
    pressed: document.querySelector('#detailView [data-read-toggle]').getAttribute('aria-pressed'),
    detailOverflow: document.getElementById('detailScroll').scrollWidth - document.getElementById('detailScroll').clientWidth,
    musicDucked: window.DamMusic.ducked,
    musicGain: window.DamMusic.master.gain.value
  }));
  check('reading falls back to system voice without credentials', reading.state === 'reading' && reading.engine === 'system', reading);
  check('reading receives the current article text', reading.spokenLength > 100 && reading.spokenStart.includes('土木堡'), reading);
  check('reading script removes line breaks and interface metadata', !reading.spokenHasLineBreaks && !reading.extracted.includes('战役 ·') && !reading.extracted.includes('前因线索'), reading.extracted.slice(0, 130));
  check('reading script does not repeat the article opening', (reading.extracted.match(/八月，大军抵大同/g) || []).length === 1, reading.extracted);
  check('detail reading control reflects active state', reading.pressed === 'true', reading);
  check('detail reading causes no horizontal overflow', reading.detailOverflow <= 0, reading.detailOverflow);
  check('reading ducks the background score', reading.musicDucked && reading.musicGain < 0.06, reading);
  await page.screenshot({ path: join(outputDir, 'reading-active-mobile.png'), format: 'png' });

  await page.eval(() => document.querySelector('#detailView [data-read-toggle]').click());
  const stopped = await page.eval(() => ({
    state: window.DamSpeech.state,
    cancelled: window.__speechLog.cancelled,
    pressed: document.querySelector('#detailView [data-read-toggle]').getAttribute('aria-pressed'),
    musicDucked: window.DamMusic.ducked
  }));
  check('reading stops on the same control', stopped.state === 'idle' && stopped.cancelled > 0 && stopped.pressed === 'false', stopped);
  check('stopping reading restores the background score', !stopped.musicDucked, stopped);
  await page.eval(() => { if (window.DamMusic.playing) window.DamMusic.pause(); });

  if (liveStatus.configured) {
    await page.goto(`${liveBase}/index.html?view=event&id=e1449_tumu`, { settleMs: 1900 });
    await page.eval(async () => { await window.DamMusic.start(); });
    const cloudReading = await page.eval(async () => {
      document.querySelector('#detailView [data-read-toggle]').click();
      for (let index = 0; index < 50; index += 1) {
        await new Promise((resolveWait) => setTimeout(resolveWait, 300));
        if (window.DamSpeech.state !== 'loading') break;
      }
      return {
        status: window.DamSpeech.apiStatus,
        state: window.DamSpeech.state,
        engine: window.DamSpeech.engine,
        cloudAudioActive: Boolean(window.DamSpeech.cloudSource),
        pressed: document.querySelector('#detailView [data-read-toggle]').getAttribute('aria-pressed'),
        musicDucked: window.DamMusic.ducked
      };
    });
    check('browser receives and plays real iFlytek audio', cloudReading.status === 'configured' && cloudReading.state === 'reading' && cloudReading.engine === 'iflytek' && cloudReading.cloudAudioActive, cloudReading);
    check('cloud reading activates its control and ducks music', cloudReading.pressed === 'true' && cloudReading.musicDucked, cloudReading);
    await page.eval(() => document.querySelector('#detailView [data-read-toggle]').click());
    await page.eval(() => { if (window.DamMusic.playing) window.DamMusic.pause(); });
  }

  check('no javascript errors', consoleErrors.length === 0 && page.consoleErrors.length === 0, { consoleErrors, exceptions: page.consoleErrors });

  const report = {
    generatedAt: new Date().toISOString(),
    viewport: { width: 402, height: 874, device: 'iPhone 16 Pro logical viewport' },
    pass: checks.every((item) => item.pass),
    checks,
    liveTtsBytes,
    privateVoiceFallback,
    screenshots: [join(outputDir, 'audio-nav-mobile.png'), join(outputDir, 'reading-active-mobile.png')]
  };
  writeFileSync(join(outputDir, 'audio-experience-regression.json'), `${JSON.stringify(report, null, 2)}\n`);
  console.log(JSON.stringify(report, null, 2));
  if (!report.pass) process.exitCode = 1;
} finally {
  await page.close();
  await browser.close();
  fallbackServer.closeAllConnections();
  liveServer.closeAllConnections();
  await Promise.all([
    new Promise((done) => fallbackServer.close(done)),
    new Promise((done) => liveServer.close(done))
  ]);
}
