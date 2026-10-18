const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const { renderPlayerPage } = require('../src/player/playerPage');

function playerHarness({ timestamps = {}, query = {}, embedUrl = null, delayed = false, mediaType = 'tv' } = {}) {
  const media = { providerId: 'test', type: mediaType, id: '42', season: '1', episode: '2', lang: 'es', sub: '0' };
  const elements = new Map();
  const messages = [];
  const requests = [];
  const documentListeners = new Map();
  const timers = new Map();
  let timerId = 0;
  let resolveTimestamps;
  function element() {
    const listeners = new Map();
    return {
      hidden: true, value: '', currentTime: 0, duration: 100, options: [], dataset: {},
      addEventListener(event, callback) {
        if (!listeners.has(event)) listeners.set(event, []);
        listeners.get(event).push(callback);
      },
      async dispatch(event) { for (const callback of listeners.get(event) || []) await callback({ type: event }); },
      replaceChildren(...options) { this.options = options; this.value = options[0]?.value || ''; },
      get selectedOptions() { return this.options.filter((option) => option.value === this.value); },
      add(option) { this.options.push(option); },
      appendChild() {}, pause() {}, removeAttribute() {}, load() {},
      canPlayType() { return true; },
      async play() {},
      async requestFullscreen() {
        document.fullscreenElement = this;
        await document.dispatch('fullscreenchange');
      },
    };
  }
  const document = {
    fullscreenElement: null,
    addEventListener(event, callback) {
      if (!documentListeners.has(event)) documentListeners.set(event, []);
      documentListeners.get(event).push(callback);
    },
    async dispatch(event) { for (const callback of documentListeners.get(event) || []) await callback(); },
    async exitFullscreen() {
      this.fullscreenElement = null;
      await this.dispatch('fullscreenchange');
    },
    querySelectorAll() { return []; },
    getElementById(id) {
      if (id === 'media-form') return null;
      if (!elements.has(id)) elements.set(id, element());
      return elements.get(id);
    },
  };
  const window = {
    location: { search: '?' + new URLSearchParams({ parentOrigin: 'https://app.example', nextSeason: '2', nextEpisode: '1', ...query }) },
    parent: { postMessage(message) { messages.push(message); } },
    addEventListener() {},
  };
  const context = vm.createContext({
    document, window, URLSearchParams, Date,
    setTimeout(callback, delay) {
      const id = ++timerId;
      timers.set(id, { callback, delay });
      return id;
    },
    clearTimeout(id) { timers.delete(id); },
    Option: function Option(label, value) { return { textContent: label, value, dataset: {} }; },
    fetch: async (url) => {
      requests.push(url);
      if (url.startsWith('/introdb')) {
        const json = delayed ? await new Promise((resolve) => { resolveTimestamps = resolve; }) : timestamps;
        return { ok: true, json: async () => json };
      }
      return { ok: true, json: async () => [] };
    },
  });
  vm.runInContext(renderPlayerPage(media, { showForm: false, embedUrl }).match(/<script>([\s\S]*?)<\/script>/)[1], context);
  return {
    elements, messages, requests, context, document, timers,
    expireTimers() {
      const pending = Array.from(timers.values());
      timers.clear();
      for (const timer of pending) timer.callback();
    },
    resolve(data) { resolveTimestamps(data); },
  };
}

test('missing credits show next episode in the last 20 seconds and seeking back hides it', async () => {
  const { elements, messages } = playerHarness();
  const video = elements.get('video');
  const next = elements.get('next-episode');
  await video.dispatch('loadedmetadata');
  await elements.get('start-playback').dispatch('click');
  for (const [position, visible] of [[79.999, false], [80, true], [100, true], [100.001, false], [50, false]]) {
    video.currentTime = position;
    await video.dispatch('seeked');
    assert.equal(!next.hidden, visible);
  }
  video.currentTime = 80;
  await video.dispatch('timeupdate');
  await next.dispatch('click');
  assert.equal(messages.at(-1).type, 'popcorn:next');
});

test('next action label distinguishes season rollover from the next episode', async () => {
  for (const [nextSeason, nextEpisode, label] of [['1', '3', 'Next episode'], ['2', '1', 'Next season'], ['3', '1', 'Next season']]) {
    const { elements, messages } = playerHarness({ query: { nextSeason, nextEpisode } });
    const video = elements.get('video');
    await video.dispatch('loadedmetadata');
    await elements.get('start-playback').dispatch('click');
    video.currentTime = 80;
    await video.dispatch('timeupdate');
    const button = elements.get('next-episode');
    assert.equal(button.hidden, false);
    assert.equal(button.textContent, label);
    await button.dispatch('click');
    assert.equal(messages.at(-1).type, 'popcorn:next');
  }
});

test('standalone next episode replaces browser history instead of adding an entry', async () => {
  const { elements, context } = playerHarness({ query: { parentOrigin: '' } });
  let destination;
  context.window.location.replace = (url) => { destination = new URL(url, 'https://player.example'); };
  context.window.location.assign = () => assert.fail('Episode advancement must replace the history entry');
  const video = elements.get('video');
  await video.dispatch('loadedmetadata');
  await elements.get('start-playback').dispatch('click');
  video.currentTime = 80;
  await video.dispatch('timeupdate');
  await elements.get('next-episode').dispatch('click');
  assert.equal(destination.pathname, '/player');
  assert.equal(destination.searchParams.get('season'), '2');
  assert.equal(destination.searchParams.get('episode'), '1');
  assert.equal(destination.searchParams.get('lang'), 'es');
  assert.equal(destination.searchParams.has('resume'), false);
});

test('last-20-second fallback requires a TV next episode and a finite positive duration', async () => {
  for (const options of [{ mediaType: 'movie' }, { query: { nextSeason: '', nextEpisode: '' } }, { embedUrl: 'https://example.com/embed' }]) {
    const { elements } = playerHarness(options);
    const video = elements.get('video');
    await video.dispatch('loadedmetadata');
    await elements.get('start-playback').dispatch('click');
    video.currentTime = 90;
    await video.dispatch('timeupdate');
    assert.equal(elements.get('next-episode').hidden, true);
  }
  const { elements } = playerHarness();
  await elements.get('start-playback').dispatch('click');
  const video = elements.get('video');
  for (const duration of [0, NaN, Infinity]) {
    video.duration = duration;
    video.currentTime = 0;
    await video.dispatch('timeupdate');
    assert.equal(elements.get('next-episode').hidden, true);
  }
});

test('known credits keep their timing rather than using the last-20-second fallback', async () => {
  const { elements } = playerHarness({ timestamps: { credits: [{ start_ms: 50000, end_ms: 60000 }] } });
  const video = elements.get('video');
  await video.dispatch('loadedmetadata');
  await elements.get('start-playback').dispatch('click');
  for (const [position, visible] of [[50, true], [60, false], [80, false]]) {
    video.currentTime = position;
    await video.dispatch('timeupdate');
    assert.equal(!elements.get('next-episode').hidden, visible);
  }
});

test('exit fullscreen fades after three seconds and activity restores it without hiding skip actions', async () => {
  const harness = playerHarness({ timestamps: { intro: [{ start_ms: 0, end_ms: 23000 }] } });
  const { elements, timers } = harness;
  const video = elements.get('video');
  const container = elements.get('video-container');
  const toggle = elements.get('fullscreen-toggle');
  await video.dispatch('loadedmetadata');
  await elements.get('start-playback').dispatch('click');
  assert.equal(toggle.dataset.inactive, 'false');
  assert.equal(timers.size, 1);
  assert.equal(Array.from(timers.values())[0].delay, 3000);
  harness.expireTimers();
  assert.equal(toggle.dataset.inactive, 'true');
  assert.equal(elements.get('skip-intro').hidden, false);
  for (const event of ['pointermove', 'pointerdown', 'keydown']) {
    await container.dispatch(event);
    assert.equal(toggle.dataset.inactive, 'false');
    assert.equal(timers.size, 1);
    harness.expireTimers();
    assert.equal(toggle.dataset.inactive, 'true');
  }
});

test('fullscreen control stays hidden when fading causes the focused button to lose focus', async () => {
  const harness = playerHarness();
  const { elements, document } = harness;
  const container = elements.get('video-container');
  const toggle = elements.get('fullscreen-toggle');
  await container.dispatch('pointerdown');
  await elements.get('start-playback').dispatch('click');
  document.activeElement = toggle;
  await container.dispatch('focusin');
  harness.expireTimers();
  assert.equal(toggle.dataset.inactive, 'true');
  document.activeElement = null;
  await container.dispatch('focusout');
  assert.equal(toggle.dataset.inactive, 'true');
  assert.equal(harness.timers.size, 0);
  await container.dispatch('pointermove');
  assert.equal(toggle.dataset.inactive, 'false');
  harness.expireTimers();
  assert.equal(toggle.dataset.inactive, 'true');
});

test('fullscreen control fades after pointer exit and re-entry even when the button retains focus', async () => {
  const harness = playerHarness();
  const { elements, document } = harness;
  const container = elements.get('video-container');
  const toggle = elements.get('fullscreen-toggle');
  await elements.get('start-playback').dispatch('click');
  harness.expireTimers();
  for (let cycle = 0; cycle < 2; cycle++) {
    document.activeElement = toggle;
    await container.dispatch('pointerdown');
    await container.dispatch('focusin');
    await toggle.dispatch('click');
    assert.equal(document.fullscreenElement, null);
    await container.dispatch('pointerdown');
    await toggle.dispatch('click');
    assert.equal(document.fullscreenElement, container);
    assert.equal(toggle.dataset.inactive, 'false');
    harness.expireTimers();
    assert.equal(toggle.dataset.inactive, 'true');
    await container.dispatch('pointermove');
    assert.equal(toggle.dataset.inactive, 'false');
    harness.expireTimers();
    assert.equal(toggle.dataset.inactive, 'true');
  }
  await container.dispatch('keydown');
  harness.expireTimers();
  assert.equal(toggle.dataset.inactive, 'false');
});

test('fullscreen control stays visible on pause, keyboard focus and fullscreen exit', async () => {
  const harness = playerHarness();
  const { elements, document, timers } = harness;
  const video = elements.get('video');
  const toggle = elements.get('fullscreen-toggle');
  await elements.get('start-playback').dispatch('click');
  document.activeElement = toggle;
  await elements.get('video-container').dispatch('focusin');
  harness.expireTimers();
  assert.equal(toggle.dataset.inactive, 'false');
  document.activeElement = video;
  await elements.get('video-container').dispatch('focusout');
  harness.expireTimers();
  assert.equal(toggle.dataset.inactive, 'true');
  video.paused = true;
  await video.dispatch('pause');
  assert.equal(toggle.dataset.inactive, 'false');
  assert.equal(timers.size, 0);
  video.paused = false;
  await video.dispatch('playing');
  assert.equal(timers.size, 1);
  await document.exitFullscreen();
  assert.equal(toggle.dataset.inactive, 'false');
  assert.equal(timers.size, 0);
  await elements.get('video-container').dispatch('pointermove');
  assert.equal(timers.size, 0);
});

test('fullscreen targets the container and keeps intro and next actions working through exit and re-entry', async () => {
  const { elements, document, messages } = playerHarness({ timestamps: {
    intro: [{ start_ms: 10000, end_ms: 23000 }],
    credits: [{ start_ms: 80000, end_ms: null }],
  } });
  const video = elements.get('video');
  const container = elements.get('video-container');
  const toggle = elements.get('fullscreen-toggle');
  assert.equal(toggle.hidden, true);
  await video.dispatch('loadedmetadata');
  await elements.get('start-playback').dispatch('click');
  assert.equal(document.fullscreenElement, container);
  assert.notEqual(document.fullscreenElement, video);
  assert.equal(toggle.hidden, false);
  assert.equal(toggle.ariaPressed, 'true');
  assert.equal(toggle.ariaLabel, 'Exit fullscreen');
  video.currentTime = 10;
  await video.dispatch('timeupdate');
  assert.equal(elements.get('skip-intro').hidden, false);
  await elements.get('skip-intro').dispatch('click');
  assert.equal(video.currentTime, 23);
  await document.exitFullscreen();
  assert.equal(toggle.ariaLabel, 'Enter fullscreen');
  assert.equal(toggle.ariaPressed, 'false');
  await toggle.dispatch('click');
  assert.equal(document.fullscreenElement, container);
  video.currentTime = 80;
  await video.dispatch('timeupdate');
  assert.equal(elements.get('next-episode').hidden, false);
  await elements.get('next-episode').dispatch('click');
  assert.equal(messages.at(-1).type, 'popcorn:next');
  await toggle.dispatch('click');
  assert.equal(document.fullscreenElement, null);
  assert.equal(toggle.textContent, 'Fullscreen');
});

test('fullscreen rejection leaves playback and skip actions usable and reports the error', async () => {
  const { elements, document } = playerHarness({ timestamps: { intro: [{ start_ms: 0, end_ms: 23000 }] } });
  elements.get('video-container').requestFullscreen = async () => { throw new Error('Permission denied'); };
  await elements.get('video').dispatch('loadedmetadata');
  await elements.get('start-playback').dispatch('click');
  assert.equal(elements.get('start-playback').hidden, true);
  assert.equal(elements.get('skip-intro').hidden, false);
  await elements.get('fullscreen-toggle').dispatch('click');
  assert.match(elements.get('status').textContent, /Could not change fullscreen: Permission denied/);
  assert.equal(document.fullscreenElement, null);
  assert.equal(elements.get('skip-intro').hidden, false);
});

test('fullscreen control stays hidden when container fullscreen is unsupported or playback is embedded', async () => {
  const { elements } = playerHarness();
  elements.get('video-container').requestFullscreen = undefined;
  await elements.get('start-playback').dispatch('click');
  assert.equal(elements.get('fullscreen-toggle').hidden, true);
  const embedded = playerHarness({ embedUrl: 'https://example.com/embed' });
  await embedded.document.dispatch('fullscreenchange');
  assert.equal(embedded.elements.get('fullscreen-toggle').hidden, true);
});

test('floating controls honor exact ranges, seek intro end and request next episode with settings', async () => {
  const harness = playerHarness({ timestamps: {
    intro: [{ start_ms: 10000, end_ms: 23000 }, { start_ms: 30000, end_ms: 40000 }],
    credits: [{ start_ms: 80000, end_ms: 90000 }, { start_ms: 95000, end_ms: null }],
  } });
  const { elements, messages, requests } = harness;
  const video = elements.get('video');
  await video.dispatch('loadedmetadata');
  await elements.get('start-playback').dispatch('click');
  assert.match(requests.find((url) => url.startsWith('/introdb')), /duration_ms=100000/);
  const intro = elements.get('skip-intro');
  const next = elements.get('next-episode');
  for (const [position, visible] of [[9.999, false], [10, true], [23, false], [30, true], [40, false]]) {
    video.currentTime = position;
    await video.dispatch('timeupdate');
    assert.equal(!intro.hidden, visible);
  }
  video.currentTime = 10;
  await video.dispatch('timeupdate');
  await intro.dispatch('click');
  assert.equal(video.currentTime, 23);
  assert.equal(intro.hidden, true);
  await video.dispatch('seeked');
  assert.equal(messages.at(-1).session.positionSeconds, 23);
  for (const [position, visible] of [[79.999, false], [80, true], [90, false], [95, true]]) {
    video.currentTime = position;
    await video.dispatch('timeupdate');
    assert.equal(!next.hidden, visible);
  }
  await next.dispatch('click');
  assert.equal(messages.at(-1).type, 'popcorn:next');
  assert.equal(messages.at(-1).media.episode, '2');
  assert.equal(messages.at(-1).session.language, 'es');
  assert.equal(messages.at(-1).session.positionSeconds, 95);
});

test('unavailable next episode, unseekable intros and embedded provider controls stay hidden', async () => {
  const harness = playerHarness({
    query: { nextSeason: '', nextEpisode: '' },
    timestamps: { intro: [{ start_ms: 0, end_ms: null }, { start_ms: 0, end_ms: 200000 }], credits: [{ start_ms: 0, end_ms: null }] },
  });
  await harness.elements.get('video').dispatch('loadedmetadata');
  await harness.elements.get('start-playback').dispatch('click');
  assert.equal(harness.elements.get('skip-intro').hidden, true);
  assert.equal(harness.elements.get('next-episode').hidden, true);
  const embedded = playerHarness({ embedUrl: 'https://example.com/embed' });
  await embedded.elements.get('video').dispatch('loadedmetadata');
  assert.equal(embedded.requests.some((url) => url.startsWith('/introdb')), false);
});

test('malformed timestamps surface an error without changing playback', async () => {
  const harness = playerHarness({ timestamps: { intro: [{ start_ms: 100, end_ms: 50 }] } });
  await harness.elements.get('video').dispatch('loadedmetadata');
  assert.match(harness.elements.get('skip-status').textContent, /Skip controls unavailable: Invalid IntroDB/);
  assert.equal(harness.elements.get('skip-intro').hidden, true);
  assert.equal(harness.elements.get('video').currentTime, 0);
});

test('old source timestamp response cannot re-enable controls after a source switch', async () => {
  const harness = playerHarness({ delayed: true });
  const pending = harness.elements.get('video').dispatch('loadedmetadata');
  vm.runInContext('start(selectedMedia)', harness.context);
  harness.resolve({ intro: [{ start_ms: 0, end_ms: 23000 }], credits: [] });
  await pending;
  await harness.elements.get('start-playback').dispatch('click');
  assert.equal(harness.elements.get('skip-intro').hidden, true);
});

test('release timestamps refresh when stream duration changes without re-fetching minor jitter', async () => {
  const harness = playerHarness();
  const video = harness.elements.get('video');
  await video.dispatch('loadedmetadata');
  video.duration = 100.5;
  await video.dispatch('durationchange');
  assert.equal(harness.requests.filter((url) => url.startsWith('/introdb')).length, 1);
  video.duration = 120;
  await video.dispatch('durationchange');
  const requests = harness.requests.filter((url) => url.startsWith('/introdb'));
  assert.equal(requests.length, 2);
  assert.match(requests[1], /duration_ms=120000/);
});

test('subtitle timing controls adjust half a second at a time and report the current offset', async () => {
  const harness = playerHarness({ query: { resumeSubtitleDelay: '-2' } });
  const { elements, messages } = harness;
  const value = elements.get('subtitle-delay-value');
  const decrease = elements.get('subtitle-delay-decrease');
  const increase = elements.get('subtitle-delay-increase');

  assert.equal(value.textContent, '-2 s');
  await increase.dispatch('click');
  assert.equal(value.textContent, '-1.5 s');
  assert.equal(messages.at(-1).session.subtitleDelaySeconds, -1.5);
  await decrease.dispatch('click');
  await decrease.dispatch('click');
  assert.equal(value.textContent, '-2.5 s');
  assert.equal(messages.at(-1).session.subtitleDelaySeconds, -2.5);
});

test('subtitle timing controls shift active subtitle cues in either direction', async () => {
  const harness = playerHarness();
  const video = harness.elements.get('video');
  const cue = { startTime: 10, endTime: 12 };
  video.textTracks = [{ cues: [cue] }];
  const { elements } = harness;

  await elements.get('subtitle-delay-increase').dispatch('click');
  assert.deepEqual([cue.startTime, cue.endTime], [10.5, 12.5]);
  await elements.get('subtitle-delay-increase').dispatch('click');
  assert.deepEqual([cue.startTime, cue.endTime], [11, 13]);
  await elements.get('subtitle-delay-decrease').dispatch('click');
  assert.deepEqual([cue.startTime, cue.endTime], [10.5, 12.5]);
});

test('subtitle timing controls are disabled for provider-owned players', () => {
  const { elements } = playerHarness({ embedUrl: 'https://example.com/embed' });
  assert.equal(elements.get('subtitle-delay-decrease').disabled, true);
  assert.equal(elements.get('subtitle-delay-increase').disabled, true);
  assert.equal(elements.get('subtitle-delay-note').textContent, 'Subtitle timing is controlled by the provider player.');
});
