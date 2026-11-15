import { createHmac } from 'node:crypto';
import { createReadStream, existsSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, join, resolve, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const ROOT = resolve(fileURLToPath(new URL('.', import.meta.url)));
const ENV_FILE = join(ROOT, '.env');
if (existsSync(ENV_FILE) && typeof process.loadEnvFile === 'function') process.loadEnvFile(ENV_FILE);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.mp3': 'audio/mpeg',
  '.m4a': 'audio/mp4',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2'
};

function ttsConfig() {
  return {
    appId: process.env.XFYUN_APP_ID || '',
    apiKey: process.env.XFYUN_API_KEY || '',
    apiSecret: process.env.XFYUN_API_SECRET || '',
    endpoint: process.env.XFYUN_TTS_URL || 'wss://tts-api.xfyun.cn/v2/tts',
    voice: process.env.XFYUN_VOICE || '',
    speed: Number(process.env.XFYUN_SPEED || 45),
    volume: Number(process.env.XFYUN_VOLUME || 65),
    pitch: Number(process.env.XFYUN_PITCH || 48)
  };
}

export function buildTtsUrl({ apiKey, apiSecret, endpoint = 'wss://tts-api.xfyun.cn/v2/tts' }, now = new Date()) {
  const target = new URL(endpoint);
  const host = target.host;
  const path = `${target.pathname}${target.search}`;
  const date = now.toUTCString();
  const signatureOrigin = `host: ${host}\ndate: ${date}\nGET ${path} HTTP/1.1`;
  const signature = createHmac('sha256', apiSecret).update(signatureOrigin).digest('base64');
  const authorizationOrigin = `api_key="${apiKey}", algorithm="hmac-sha256", headers="host date request-line", signature="${signature}"`;
  const authorization = Buffer.from(authorizationOrigin).toString('base64');
  const query = new URLSearchParams({ authorization, date, host });
  return `${target.protocol}//${host}${path}?${query.toString()}`;
}

export async function synthesizeIflytek(text, config = ttsConfig(), timeoutMs = 30000) {
  if (!config.appId || !config.apiKey || !config.apiSecret) {
    const error = new Error('iFlytek TTS is not configured');
    error.code = 'TTS_NOT_CONFIGURED';
    throw error;
  }
  if (!text || Buffer.byteLength(text, 'utf8') >= 8000) {
    const error = new Error('TTS text must contain fewer than 8000 UTF-8 bytes');
    error.code = 'TTS_TEXT_INVALID';
    throw error;
  }

  const url = buildTtsUrl(config);
  const privateEndpoint = config.endpoint.includes('/v1/private/');
  return new Promise((resolvePromise, rejectPromise) => {
    const chunks = [];
    let settled = false;
    const socket = new WebSocket(url);
    const timer = setTimeout(() => fail(new Error('iFlytek TTS timed out')), timeoutMs);

    function finish(error, audio) {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      try { socket.close(); } catch {}
      if (error) rejectPromise(error);
      else resolvePromise(audio);
    }

    function fail(error) {
      finish(error);
    }

    socket.addEventListener('open', () => {
      const encodedText = Buffer.from(text, 'utf8').toString('base64');
      const payload = privateEndpoint ? {
        header: { app_id: config.appId, status: 2 },
        parameter: { oral: {}, tts: { vcn: config.voice } },
        payload: {
          text: {
            encoding: 'utf8',
            compress: 'raw',
            format: 'plain',
            status: 2,
            seq: 0,
            text: encodedText
          }
        }
      } : {
        common: { app_id: config.appId },
        business: {
          aue: 'lame',
          sfl: 1,
          auf: 'audio/L16;rate=16000',
          speed: config.speed,
          volume: config.volume,
          pitch: config.pitch,
          tte: 'UTF8',
          bgs: 0,
          reg: '2',
          rdn: '3',
          ...(config.voice ? { vcn: config.voice } : {})
        },
        data: { status: 2, text: encodedText }
      };
      socket.send(JSON.stringify(payload));
    });

    socket.addEventListener('message', (event) => {
      try {
        const payload = JSON.parse(typeof event.data === 'string' ? event.data : Buffer.from(event.data).toString('utf8'));
        const code = payload.header?.code ?? payload.code;
        const message = payload.header?.message || payload.message;
        if (code !== 0) {
          const error = new Error(message || `iFlytek error ${code ?? 'unknown'}`);
          error.code = code ?? 'XFYUN_RESPONSE_ERROR';
          fail(error);
          return;
        }
        const audio = payload.payload?.audio?.audio || payload.data?.audio;
        if (audio) chunks.push(Buffer.from(audio, 'base64'));
        const status = payload.header?.status ?? payload.data?.status;
        if (status === 2) finish(null, Buffer.concat(chunks));
      } catch (error) {
        fail(error);
      }
    });
    socket.addEventListener('error', () => fail(new Error('iFlytek WebSocket failed')));
    socket.addEventListener('close', () => {
      if (!settled && !chunks.length) fail(new Error('iFlytek connection closed without audio'));
    });
  });
}

function sendJson(response, status, payload) {
  const body = Buffer.from(JSON.stringify(payload));
  response.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': body.length,
    'cache-control': 'no-store'
  });
  response.end(body);
}

async function readJson(request, limit = 20000) {
  let size = 0;
  const chunks = [];
  for await (const chunk of request) {
    size += chunk.length;
    if (size > limit) throw Object.assign(new Error('Request body too large'), { status: 413 });
    chunks.push(chunk);
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    throw Object.assign(new Error('Invalid JSON'), { status: 400 });
  }
}

export function createAppServer({ configProvider = ttsConfig } = {}) {
  return createServer(async (request, response) => {
    const url = new URL(request.url || '/', 'http://localhost');
    if (url.pathname === '/api/tts/status' && request.method === 'GET') {
      const config = configProvider();
      sendJson(response, 200, {
        configured: Boolean(config.appId && config.apiKey && config.apiSecret),
        provider: 'iFlytek WebAPI',
        voice: config.voice || null,
        speed: config.speed,
        endpointKind: config.endpoint.includes('/v1/private/') ? 'private-super-human' : 'standard-online'
      });
      return;
    }
    if (url.pathname === '/api/tts' && request.method === 'POST') {
      try {
        const body = await readJson(request);
        const audio = await synthesizeIflytek(String(body.text || ''), configProvider());
        response.writeHead(200, {
          'content-type': 'audio/mpeg',
          'content-length': audio.length,
          'cache-control': 'no-store',
          'x-tts-provider': 'iFlytek'
        });
        response.end(audio);
      } catch (error) {
        const status = error.code === 'TTS_NOT_CONFIGURED' ? 503
          : error.code === 'TTS_TEXT_INVALID' ? 422
            : error.status || 502;
        sendJson(response, status, {
          error: error.code || 'TTS_FAILED',
          message: status === 503 ? 'XFYUN credentials are not configured' : error.message
        });
      }
      return;
    }
    if (!['GET', 'HEAD'].includes(request.method || 'GET')) {
      sendJson(response, 405, { error: 'METHOD_NOT_ALLOWED' });
      return;
    }

    try {
      const pathname = decodeURIComponent(url.pathname);
      let file = resolve(ROOT, `.${pathname}`);
      if (file !== ROOT && !file.startsWith(ROOT + sep)) throw new Error('outside root');
      if (statSync(file).isDirectory()) file = join(file, 'index.html');
      const stat = statSync(file);
      response.writeHead(200, {
        'content-type': MIME[extname(file).toLowerCase()] || 'application/octet-stream',
        'content-length': stat.size,
        'cache-control': 'no-store'
      });
      if (request.method === 'HEAD') response.end();
      else createReadStream(file).pipe(response);
    } catch {
      response.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
      response.end('Not found');
    }
  });
}

const isMain = process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url;
if (isMain) {
  const port = Number(process.env.PORT || 4173);
  const host = process.env.HOST || '127.0.0.1';
  createAppServer().listen(port, host, () => {
    console.log(`Daming Atlas: http://${host}:${port}`);
    console.log(ttsConfig().appId ? `iFlytek TTS: configured (${ttsConfig().endpoint.includes('/v1/private/') ? 'super-human' : 'standard'})` : 'iFlytek TTS: not configured, using browser speech fallback');
  });
}
