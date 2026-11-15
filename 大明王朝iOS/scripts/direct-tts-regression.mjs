import { createAppServer } from '../server.mjs';
import { mkdirSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join, resolve } from 'node:path';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const cdpModule = pathToFileURL('C:/Users/Administrator/.codex/skills/design-taste-frontend/scripts/lib/cdp.mjs').href;
const { Browser, sleep } = await import(cdpModule);

const appId = process.env.XFYUN_APP_ID || '';
const apiKey = process.env.XFYUN_API_KEY || '';
const apiSecret = process.env.XFYUN_API_SECRET || '';
if (!appId || !apiKey || !apiSecret) {
  console.error('XFYUN credentials are not available in the local environment.');
  process.exit(2);
}

const server = createAppServer();
mkdirSync(join(scriptDir, '..', 'output', 'playwright', 'audio'), { recursive: true });
await new Promise((done) => server.listen(0, '127.0.0.1', done));
const base = `http://127.0.0.1:${server.address().port}`;
const browser = await Browser.launch();
const page = await browser.newPage({ width: 402, height: 874, dsf: 2, mobile: true });
const config = JSON.stringify({
  appId,
  apiKey,
  apiSecret,
  endpoint: 'wss://tts-api.xfyun.cn/v2/tts',
  voice: 'x4_yezi'
});
await page.send('Page.addScriptToEvaluateOnNewDocument', {
  source: `
    window.DAM_NATIVE_TTS_DIRECT = true;
    window.DAM_TTS_VOICE = 'x4_yezi';
    window.DAM_TTS_ENDPOINT = 'wss://tts-api.xfyun.cn/v2/tts';
    Object.defineProperty(window, 'DAM_TTS_DEFAULT_CONFIG', {
      value: ${config},
      writable: false,
      configurable: false
    });
  `
});

try {
  await page.goto(`${base}/index.html?view=event&id=e1449_tumu`, { settleMs: 1900 });
  await page.eval(() => document.querySelector('#detailView [data-read-toggle]').click());
  await page.screenshot({
    path: join(scriptDir, '..', 'output', 'playwright', 'audio', 'iflytek-direct-setup.png'),
    format: 'png'
  });
  const result = await page.eval(async () => {
    for (let index = 0; index < 80; index += 1) {
      await new Promise((done) => setTimeout(done, 250));
      if (window.DamSpeech.state !== 'loading') break;
    }
    return {
      direct: window.DamSpeech.direct,
      status: window.DamSpeech.apiStatus,
      voice: window.DamSpeech.voice,
      state: window.DamSpeech.state,
      engine: window.DamSpeech.engine,
      audioActive: Boolean(window.DamSpeech.cloudSource),
      setupModal: Boolean(document.getElementById('ttsSetup'))
    };
  });
  await page.eval(() => window.DamSpeech.stop());
  console.log(JSON.stringify(result));
  if (!(result.direct && result.status === 'configured' && result.voice === 'x4_yezi' && result.state === 'reading' && result.engine === 'iflytek' && result.audioActive && !result.setupModal)) {
    process.exitCode = 1;
  }
} finally {
  await page.close();
  await browser.close();
  server.closeAllConnections();
  await new Promise((done) => server.close(done));
}
