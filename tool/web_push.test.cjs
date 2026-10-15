const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const webRoot = path.join(__dirname, '..', 'web');

function browser({ granted = true, subscribeError = false } = {}) {
  const calls = [];
  const subscription = {
    toJSON: () => ({ endpoint: 'https://fcm.googleapis.com/token', keys: { p256dh: 'key', auth: 'auth' } }),
    unsubscribe: async () => { calls.push('unsubscribe'); return true; },
  };
  const reg = {
    scope: 'https://example.com/popcorn/push/',
    active: {},
    pushManager: {
      getSubscription: async () => subscription,
      subscribe: async (options) => {
        calls.push('subscribe');
        assert.equal(options.userVisibleOnly, true);
        assert.deepEqual(Array.from(options.applicationServerKey), [1, 2, 3]);
        if (subscribeError) throw new Error('Push service unavailable');
        return subscription;
      },
    },
  };
  const context = {
    URL, Uint8Array, atob,
    document: { baseURI: 'https://example.com/popcorn/' },
    window: { isSecureContext: true, PushManager: {}, Notification: {} },
    Notification: { permission: granted ? 'granted' : 'denied', requestPermission: async () => { calls.push('permission'); return granted ? 'granted' : 'denied'; } },
    navigator: {
      serviceWorker: {
        register: async (url, options) => {
          calls.push('register');
          assert.equal(url, 'https://example.com/popcorn/push_service_worker.js');
          assert.equal(options.scope, reg.scope);
          return reg;
        },
        getRegistration: async () => reg,
      },
    },
  };
  vm.runInNewContext(fs.readFileSync(path.join(webRoot, 'push_notifications.js'), 'utf8'), context);
  return { context, calls, reg, api: context.window };
}

test('opt-in requests permission first and registers a dedicated subpath scope', async () => {
  const { api, calls } = browser();
  assert.equal(api.popcornPushSupported(), true);
  const permission = api.popcornPushPermission();
  assert.deepEqual(calls, ['permission']);
  await permission;
  const data = JSON.parse(await api.popcornPushSubscribe('AQID'));
  assert.equal(data.endpoint, 'https://fcm.googleapis.com/token');
  assert.deepEqual(calls, ['permission', 'register', 'subscribe']);
  await api.popcornPushUnsubscribe();
  assert.equal(calls.at(-1), 'unsubscribe');
});

test('permission denial and push service errors are surfaced', async () => {
  const denied = browser({ granted: false });
  await assert.rejects(denied.api.popcornPushPermission(), /permission/);
  await assert.rejects(denied.api.popcornPushSubscribe('AQID'), /permission/);
  assert.deepEqual(denied.calls, ['permission']);
  const failed = browser({ subscribeError: true });
  await assert.rejects(failed.api.popcornPushSubscribe('AQID'), /unavailable/);
});

test('does not read or unsubscribe a different service worker scope', async () => {
  const { api, reg, calls } = browser();
  reg.scope = 'https://example.com/popcorn/';
  assert.equal(await api.popcornPushSubscription(), '');
  await api.popcornPushUnsubscribe();
  assert.deepEqual(calls, []);
});

test('unsupported browser is detected without requesting permission', async () => {
  const { api, context } = browser();
  context.window.isSecureContext = false;
  assert.equal(api.popcornPushSupported(), false);
  await assert.rejects(api.popcornPushSubscribe('AQID'), /not supported/);
});

test('worker displays notifications and opens only URLs inside its app path', async () => {
  const listeners = {};
  const shown = [];
  const opened = [];
  const self = {
    location: { href: 'https://example.com/popcorn/push_service_worker.js' },
    addEventListener: (name, handler) => { listeners[name] = handler; },
    registration: { showNotification: async (title, options) => shown.push({ title, options }) },
    clients: { matchAll: async () => [], openWindow: async (url) => opened.push(url) },
  };
  vm.runInNewContext(fs.readFileSync(path.join(webRoot, 'push_service_worker.js'), 'utf8'), { self, URL });
  let pending;
  listeners.push({ data: { json: () => ({ title: 'News', body: 'Hello', url: 'https://example.com/popcorn/#/home' }) }, waitUntil: (promise) => { pending = promise; } });
  await pending;
  assert.equal(shown[0].title, 'News');
  assert.equal(shown[0].options.icon, 'https://example.com/popcorn/icons/Icon-192.png');
  const click = (url) => {
    listeners.notificationclick({ notification: { close() {}, data: { url } }, waitUntil: (promise) => { pending = promise; } });
    return pending;
  };
  await click(shown[0].options.data.url);
  assert.deepEqual(opened, ['https://example.com/popcorn/#/home']);
  await assert.rejects(click('https://evil.example/'), /outside/);
  await assert.rejects(click('https://example.com/popcorn-evil/'), /outside/);
});

test('startup cache cleanup preserves the push worker and unrelated caches', async () => {
  const removed = [];
  const deleted = [];
  const reg = (script) => ({ active: { scriptURL: `https://example.com/popcorn/${script}` }, unregister: () => removed.push(script) });
  const html = fs.readFileSync(path.join(webRoot, 'index.html'), 'utf8');
  const script = html.split('<!-- Self-heal stale Flutter caches')[1].match(/<script>([\s\S]*?)<\/script>/)[1];
  vm.runInNewContext(script, {
    URL,
    window: { caches: {} },
    navigator: { serviceWorker: { getRegistrations: async () => [reg('flutter_service_worker.js'), reg('push_service_worker.js')] } },
    caches: { keys: async () => ['flutter-app-cache', 'other-cache'], delete: (key) => deleted.push(key) },
  });
  await new Promise((resolve) => setImmediate(resolve));
  assert.deepEqual(removed, ['flutter_service_worker.js']);
  assert.deepEqual(deleted, ['flutter-app-cache']);
});
