(() => {
  'use strict';

  const MUSIC_PREF_KEY = 'dam_guqin_enabled_v1';
  const musicButton = document.getElementById('musicToggle');
  const readButtons = [...document.querySelectorAll('[data-read-toggle]')];
  const notify = (message) => {
    if (typeof window.toast === 'function') window.toast(message);
  };

  const PENTATONIC = [146.83, 164.81, 185.00, 220.00, 246.94, 293.66, 329.63, 369.99, 440.00];
  const MELODY = [
    [3, 3.0, 5.4, .68], [5, 1.4, 4.2, .42], [3, 2.2, 5.0, .52], [2, 1.6, 4.4, .38],
    [0, 3.4, 6.4, .62], [3, 2.0, 4.8, .44], [5, 1.5, 4.1, .34], [7, 2.8, 5.6, .46],
    [5, 1.3, 4.0, .32], [3, 2.4, 5.0, .48], [2, 1.8, 4.3, .35], [0, 4.2, 6.8, .58],
    [2, 2.0, 4.8, .38], [3, 1.4, 4.0, .34], [5, 3.0, 5.8, .52], [4, 1.5, 4.0, .30],
    [3, 2.6, 5.2, .46], [2, 1.8, 4.4, .34], [0, 3.8, 6.2, .56], [5, 1.7, 4.2, .36],
    [7, 2.4, 5.2, .44], [8, 1.4, 3.8, .26], [7, 2.2, 4.9, .36], [5, 3.2, 5.7, .48],
    [3, 1.8, 4.2, .32], [2, 1.5, 4.0, .30], [0, 4.6, 7.2, .58]
  ];

  class GuqinMusic {
    constructor() {
      this.context = null;
      this.master = null;
      this.input = null;
      this.scheduler = null;
      this.nextNoteTime = 0;
      this.melodyIndex = 0;
      this.playing = false;
      this.ducked = false;
    }

    ensureContext() {
      if (this.context) return;
      const AudioContextClass = window.AudioContext || window.webkitAudioContext;
      if (!AudioContextClass) throw new Error('当前浏览器不支持 Web Audio');
      this.context = new AudioContextClass();
      const ctx = this.context;

      this.master = ctx.createGain();
      this.master.gain.value = 0.0001;
      this.input = ctx.createGain();
      this.input.gain.value = 0.9;

      const compressor = ctx.createDynamicsCompressor();
      compressor.threshold.value = -20;
      compressor.knee.value = 22;
      compressor.ratio.value = 5;
      compressor.attack.value = 0.012;
      compressor.release.value = 0.32;

      const reverb = ctx.createConvolver();
      reverb.buffer = this.createImpulse(3.2);
      const wet = ctx.createGain();
      wet.gain.value = 0.34;
      const dry = ctx.createGain();
      dry.gain.value = 0.78;

      this.input.connect(dry).connect(this.master);
      this.input.connect(reverb).connect(wet).connect(this.master);
      this.master.connect(compressor).connect(ctx.destination);
    }

    createImpulse(seconds) {
      const ctx = this.context;
      const length = Math.max(1, Math.floor(ctx.sampleRate * seconds));
      const impulse = ctx.createBuffer(2, length, ctx.sampleRate);
      for (let channel = 0; channel < 2; channel += 1) {
        const data = impulse.getChannelData(channel);
        for (let i = 0; i < length; i += 1) {
          data[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / length, 2.8);
        }
      }
      return impulse;
    }

    pluck(frequency, when, duration, velocity) {
      const ctx = this.context;
      const sampleRate = ctx.sampleRate;
      const length = Math.max(1, Math.ceil(sampleRate * duration));
      const buffer = ctx.createBuffer(1, length, sampleRate);
      const output = buffer.getChannelData(0);
      const ringSize = Math.max(2, Math.round(sampleRate / frequency));
      const ring = new Float32Array(ringSize);
      let previous = 0;
      for (let i = 0; i < ringSize; i += 1) {
        previous = previous * 0.68 + (Math.random() * 2 - 1) * 0.32;
        ring[i] = previous;
      }
      for (let i = 0; i < length; i += 1) {
        const index = i % ringSize;
        const current = ring[index];
        const next = ring[(index + 1) % ringSize];
        output[i] = current * (i < 180 ? i / 180 : 1);
        ring[index] = (current + next) * 0.5 * 0.9968;
      }

      const source = ctx.createBufferSource();
      source.buffer = buffer;
      const filter = ctx.createBiquadFilter();
      filter.type = 'lowpass';
      filter.frequency.setValueAtTime(2200 + velocity * 1500, when);
      filter.Q.value = 0.72;
      const envelope = ctx.createGain();
      envelope.gain.setValueAtTime(0.0001, when);
      envelope.gain.exponentialRampToValueAtTime(Math.max(0.02, velocity * 0.34), when + 0.018);
      envelope.gain.exponentialRampToValueAtTime(0.0001, when + duration);
      source.connect(filter).connect(envelope).connect(this.input);
      source.start(when);
      source.stop(when + duration + 0.05);
    }

    scheduleAhead() {
      if (!this.playing || !this.context) return;
      const beat = 60 / 44;
      const horizon = this.context.currentTime + 2.4;
      while (this.nextNoteTime < horizon) {
        const [degree, gap, hold, velocity] = MELODY[this.melodyIndex % MELODY.length];
        this.pluck(PENTATONIC[degree], this.nextNoteTime, hold, velocity);
        if (this.melodyIndex % 8 === 5) {
          this.pluck(PENTATONIC[Math.min(PENTATONIC.length - 1, degree + 3)] * 2, this.nextNoteTime + 0.07, 2.8, 0.16);
        }
        this.nextNoteTime += gap * beat;
        this.melodyIndex = (this.melodyIndex + 1) % MELODY.length;
      }
    }

    async start({ remember = true } = {}) {
      this.ensureContext();
      await this.context.resume();
      if (this.context.state !== 'running') throw new Error('浏览器阻止了自动播放');
      this.playing = true;
      this.ducked = false;
      this.nextNoteTime = Math.max(this.nextNoteTime || 0, this.context.currentTime + 0.12);
      clearInterval(this.scheduler);
      this.scheduler = window.setInterval(() => this.scheduleAhead(), 180);
      const now = this.context.currentTime;
      this.master.gain.cancelScheduledValues(now);
      this.master.gain.setValueAtTime(Math.max(this.master.gain.value, 0.0001), now);
      this.master.gain.exponentialRampToValueAtTime(0.115, now + 1.2);
      this.scheduleAhead();
      if (remember) localStorage.setItem(MUSIC_PREF_KEY, 'true');
      this.syncButton();
      return true;
    }

    pause({ remember = true } = {}) {
      if (!this.context) return;
      this.playing = false;
      clearInterval(this.scheduler);
      this.scheduler = null;
      const now = this.context.currentTime;
      this.master.gain.cancelScheduledValues(now);
      this.master.gain.setValueAtTime(Math.max(this.master.gain.value, 0.0001), now);
      this.master.gain.exponentialRampToValueAtTime(0.0001, now + 0.7);
      window.setTimeout(() => {
        if (!this.playing && this.context?.state === 'running') this.context.suspend().catch(() => {});
      }, 760);
      if (remember) localStorage.setItem(MUSIC_PREF_KEY, 'false');
      this.syncButton();
    }

    duck() {
      if (!this.context || !this.playing) return;
      this.ducked = true;
      const now = this.context.currentTime;
      this.master.gain.cancelScheduledValues(now);
      this.master.gain.setValueAtTime(Math.max(this.master.gain.value, 0.0001), now);
      this.master.gain.exponentialRampToValueAtTime(0.032, now + 0.35);
    }

    unduck() {
      if (!this.context || !this.playing) return;
      this.ducked = false;
      const now = this.context.currentTime;
      this.master.gain.cancelScheduledValues(now);
      this.master.gain.setValueAtTime(Math.max(this.master.gain.value, 0.0001), now);
      this.master.gain.exponentialRampToValueAtTime(0.115, now + 0.55);
    }

    syncButton() {
      if (!musicButton) return;
      musicButton.classList.toggle('on', this.playing);
      musicButton.setAttribute('aria-pressed', String(this.playing));
      musicButton.setAttribute('aria-label', this.playing ? '暂停背景古琴音乐' : '播放背景古琴音乐');
      musicButton.title = this.playing ? '暂停琴音' : '播放琴音';
    }
  }

  function splitSpeechText(text, limit = 1800) {
    const paragraphs = String(text || '')
      .replace(/\u00a0/g, ' ')
      .split(/\n+/)
      .map((part) => part.replace(/\s+/g, ' ').trim())
      .filter(Boolean);
    const chunks = [];
    let current = '';
    const push = () => {
      if (current.trim()) chunks.push(current.trim());
      current = '';
    };
    for (const paragraph of paragraphs) {
      const sentences = paragraph.match(/[^。！？!?；;]+[。！？!?；;]?/g) || [paragraph];
      for (const sentence of sentences) {
        if ((current + sentence).length <= limit) {
          current += sentence;
        } else {
          push();
          if (sentence.length <= limit) {
            current = sentence;
          } else {
            for (let index = 0; index < sentence.length; index += limit) {
              chunks.push(sentence.slice(index, index + limit));
            }
          }
        }
      }
      if (current && !/[。！？!?；;，,：:]$/.test(current)) current += '。';
    }
    push();
    return chunks;
  }

  class SpeechReader {
    constructor(buttons) {
      this.buttons = buttons;
      this.state = 'idle';
      this.audio = null;
      this.cloudContext = null;
      this.cloudSource = null;
      this.abortController = null;
      this.cancelled = false;
      this.engine = null;
      this.apiStatus = 'unknown';
      this.voice = null;
      this.checkBackend();
    }

    async checkBackend() {
      try {
        const response = await fetch('./api/tts/status', { cache: 'no-store' });
        if (!response.ok) throw new Error('status unavailable');
        const status = await response.json();
        this.apiStatus = status.configured ? 'configured' : 'unconfigured';
        this.voice = status.voice || null;
      } catch {
        this.apiStatus = 'unavailable';
      }
    }

    currentScope() {
      const detail = document.getElementById('detailView');
      return detail?.classList.contains('pushed')
        ? document.getElementById('detailScroll')
        : document.querySelector('.view.active');
    }

    extractText() {
      const scope = this.currentScope();
      if (!scope) return '';
      const clone = scope.cloneNode(true);
      clone.querySelectorAll([
        'button', 'input', 'select', 'textarea', 'svg', 'script', 'style',
        '[hidden]', '.pd-seg', '.source-entry', '.chart-legend', '.sync-act-strip',
        '.event-compass', '.causal-caveat', '.person-relations', '.year-focus-action',
        '.detail-head .dk', '.detail-head .ds', '.event-thread-tags', '.source-panel',
        '.causal-flow', '.chart-note', '.slider-quick', '.slider-years', '.dynasty-detail'
      ].join(',')).forEach((node) => node.remove());
      const detailOpen = document.getElementById('detailView')?.classList.contains('pushed');
      const blocks = detailOpen
        ? [...clone.querySelectorAll('.detail-head h2,p,blockquote')]
        : [...clone.querySelectorAll('h1,h2,h3,h4,p,dt,dd,li')];
      const seen = new Set();
      let result = '';
      blocks.map((node) => node.textContent.replace(/\s+/g, ' ').trim())
        .filter((text) => {
          if (!text || seen.has(text)) return false;
          seen.add(text);
          return true;
        })
        .forEach((text) => {
          if (result && !/[。！？!?；;，,：:]$/.test(result)) result += '。';
          result += text;
        });
      return result.replace(/。。+/g, '。').replace(/，，+/g, '，').trim();
    }

    async toggle() {
      if (this.state === 'loading' || this.state === 'reading') {
        this.stop();
        return;
      }
      const text = this.extractText();
      if (!text) {
        notify('当前页面没有可朗读的正文');
        return;
      }
      this.cancelled = false;
      this.setState('loading');
      window.DamMusic?.duck();
      if (location.protocol !== 'file:' && this.apiStatus !== 'unconfigured' && this.apiStatus !== 'unavailable') {
        this.unlockCloudAudio();
      }
      try {
        if (location.protocol === 'file:' || this.apiStatus === 'unconfigured' || this.apiStatus === 'unavailable') {
          this.speakWithSystem(text);
          return;
        }
        this.abortController = new AbortController();
        const chunks = splitSpeechText(text);
        const firstAudio = await this.requestIflytek(chunks[0]);
        this.engine = 'iflytek';
        notify(this.voice === 'x4_yezi' ? '讯飞语音朗读 · 小露' : '讯飞语音朗读');
        await this.playCloudQueue(chunks, firstAudio);
      } catch (error) {
        if (error?.name === 'AbortError' || this.cancelled) return;
        this.engine = 'system';
        notify('讯飞未就绪，改用系统朗读');
        this.speakWithSystem(text);
      }
    }

    async requestIflytek(text) {
      const response = await fetch('./api/tts', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ text }),
        signal: this.abortController.signal
      });
      if (!response.ok) throw new Error(`TTS ${response.status}`);
      return response.blob();
    }

    async playCloudQueue(chunks, firstAudio) {
      let audioBlob = firstAudio;
      for (let index = 0; index < chunks.length; index += 1) {
        if (this.cancelled) return;
        if (!audioBlob) audioBlob = await this.requestIflytek(chunks[index]);
        const nextAudioPromise = index + 1 < chunks.length
          ? this.requestIflytek(chunks[index + 1]).catch(() => null)
          : Promise.resolve(null);
        await this.playBlob(audioBlob);
        audioBlob = await nextAudioPromise;
      }
      if (!this.cancelled) this.finish();
    }

    async playBlob(blob) {
      if (this.cloudContext) {
        if (this.cloudContext.state !== 'running') await this.cloudContext.resume();
        const buffer = await this.cloudContext.decodeAudioData((await blob.arrayBuffer()).slice(0));
        return new Promise((resolve, reject) => {
          const source = this.cloudContext.createBufferSource();
          source.buffer = buffer;
          source.connect(this.cloudContext.destination);
          this.cloudSource = source;
          source.addEventListener('ended', () => {
            if (this.cloudSource === source) this.cloudSource = null;
            resolve();
          }, { once: true });
          try {
            this.setState('reading');
            source.start();
          } catch (error) {
            reject(error);
          }
        });
      }
      return new Promise((resolve, reject) => {
        const url = URL.createObjectURL(blob);
        const audio = new Audio(url);
        this.audio = audio;
        this.setState('reading');
        const cleanup = () => {
          URL.revokeObjectURL(url);
          if (this.audio === audio) this.audio = null;
        };
        audio.addEventListener('ended', () => {
          cleanup();
          resolve();
        }, { once: true });
        audio.addEventListener('error', () => {
          cleanup();
          reject(new Error('音频播放失败'));
        }, { once: true });
        audio.play().catch((error) => {
          cleanup();
          reject(error);
        });
      });
    }

    unlockCloudAudio() {
      try {
        const AudioContextClass = window.AudioContext || window.webkitAudioContext;
        if (!AudioContextClass) return;
        this.cloudContext ||= new AudioContextClass();
        if (this.cloudContext.state === 'suspended') this.cloudContext.resume().catch(() => {});
      } catch {}
    }

    speakWithSystem(text) {
      if (!('speechSynthesis' in window) || typeof SpeechSynthesisUtterance === 'undefined') {
        notify('当前浏览器没有可用的语音朗读');
        this.finish();
        return;
      }
      this.engine = 'system';
      window.speechSynthesis.cancel();
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = 'zh-CN';
      utterance.rate = 0.9;
      utterance.pitch = 0.92;
      const voices = window.speechSynthesis.getVoices();
      const chinese = voices.find((voice) => /^zh[-_]CN/i.test(voice.lang)) || voices.find((voice) => /^zh/i.test(voice.lang));
      if (chinese) utterance.voice = chinese;
      utterance.onstart = () => this.setState('reading');
      utterance.onend = () => {
        if (!this.cancelled) this.finish();
      };
      utterance.onerror = (event) => {
        if (event.error !== 'canceled' && event.error !== 'interrupted') {
          notify('系统朗读未能开始');
          this.finish();
        }
      };
      window.speechSynthesis.speak(utterance);
    }

    finish() {
      this.setState('idle');
      this.audio = null;
      this.cloudSource = null;
      this.abortController = null;
      window.DamMusic?.unduck();
    }

    stop() {
      this.cancelled = true;
      this.abortController?.abort();
      this.abortController = null;
      if (this.audio) {
        this.audio.pause();
        this.audio.src = '';
        this.audio.load();
        this.audio = null;
      }
      if (this.cloudSource) {
        try { this.cloudSource.stop(); } catch {}
        this.cloudSource = null;
      }
      if ('speechSynthesis' in window) window.speechSynthesis.cancel();
      this.setState('idle');
      window.DamMusic?.unduck();
    }

    setState(state) {
      this.state = state;
      const active = state === 'loading' || state === 'reading';
      this.buttons.forEach((button) => {
        button.classList.toggle('is-reading', active);
        button.classList.toggle('is-loading', state === 'loading');
        button.setAttribute('aria-pressed', String(active));
        button.setAttribute('aria-label', active ? '停止朗读' : '朗读当前页面');
        button.title = active ? '停止朗读' : '朗读当前页面';
        const icon = button.querySelector('use');
        icon?.setAttribute('href', active ? '#i-stop' : '#i-speaker');
      });
    }
  }

  const music = new GuqinMusic();
  window.DamMusic = music;
  music.syncButton();
  musicButton?.addEventListener('click', async () => {
    try {
      if (music.playing) {
        music.pause();
        notify('琴音已暂停');
      } else {
        await music.start();
        notify('琴音已开启 · 松风入卷');
      }
    } catch {
      notify('轻触琴音后再试一次');
    }
  });

  if (localStorage.getItem(MUSIC_PREF_KEY) === 'true') {
    musicButton?.classList.add('wanted');
    music.start({ remember: false }).catch(() => {
      if (musicButton) musicButton.setAttribute('aria-label', '继续播放背景古琴音乐');
    });
  }

  const speech = new SpeechReader(readButtons);
  window.DamSpeech = speech;
  readButtons.forEach((button) => button.addEventListener('click', () => speech.toggle()));
})();
