// PWA_SW: executable behaviour tests for the service worker
// (tool/web/service_worker_template.js) and the update handling in
// web/index.html. Run: node --test tool/web/test/ (also run by
// test/tool/sw_behavior_test.dart inside `flutter test`).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash, webcrypto } from 'node:crypto';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const ORIGIN = 'https://app.test';
const sha = (text) => createHash('sha256').update(text).digest('hex');

// ---------------------------------------------------------------- page ---

/** Runs the "Service Worker Update Detection" script of web/index.html. */
function loadPage({ controller, registration = null }) {
  const html = readFileSync('web/index.html', 'utf8');
  const start = html.indexOf('<!-- Service Worker Update Detection -->');
  const body = html.slice(start).match(/<script>([\s\S]*?)<\/script>/)[1];
  const listeners = {};
  const page = { reloads: 0, events: [] };
  const serviceWorker = {
    controller,
    ready: registration ? Promise.resolve(registration) : new Promise(() => {}),
    addEventListener: (type, fn) => { (listeners[type] ||= []).push(fn); },
    getRegistration: async () => null,
  };
  const ctx = {
    navigator: { serviceWorker },
    document: { visibilityState: 'visible', addEventListener() {} },
    console,
    setTimeout,
    setInterval: () => 0,
    CustomEvent: class { constructor(type) { this.type = type; } },
  };
  ctx.window = ctx;
  ctx.location = { reload: () => { page.reloads++; } };
  ctx.addEventListener = () => {};
  ctx.dispatchEvent = (event) => { page.events.push(event.type); };
  vm.runInNewContext(body, ctx);
  page.controllerChange = () => (listeners.controllerchange || []).forEach((fn) => fn());
  page.updateAvailable = () => ctx.appUpdateAvailable;
  return page;
}

/** A ServiceWorker / registration stand-in with event listeners. */
class FakeTarget {
  constructor(props) { Object.assign(this, props); this.listeners = {}; }
  addEventListener(type, fn) { (this.listeners[type] ||= []).push(fn); }
  fire(type) { (this.listeners[type] || []).forEach((fn) => fn()); }
}

test('first visit: the first worker taking over reloads nothing, every later switch reloads', () => {
  const page = loadPage({ controller: null });
  page.controllerChange(); // the first deploy claims the fresh page
  assert.equal(page.reloads, 0);
  page.controllerChange(); // a later deploy, activated from another tab
  assert.equal(page.reloads, 1);
  page.controllerChange();
  assert.equal(page.reloads, 2);
});

test('a page that already had a worker reloads on the switch', () => {
  const page = loadPage({ controller: {} });
  page.controllerChange();
  assert.equal(page.reloads, 1);
});

const settle = () => new Promise((resolve) => setTimeout(resolve, 0));

test('a worker already installing when the page starts still shows the update hint', async () => {
  const installing = new FakeTarget({ state: 'installing' });
  const registration = new FakeTarget({ installing, waiting: null, update: async () => {} });
  const page = loadPage({ controller: {}, registration });
  await settle();
  assert.equal(page.updateAvailable(), false);
  installing.state = 'installed';
  installing.fire('statechange');
  assert.equal(page.updateAvailable(), true);
  assert.deepEqual(page.events, ['flutter-update-available']);
});

test('a worker found later and one already waiting show the hint once', async () => {
  const waiting = new FakeTarget({ state: 'installed' });
  const registration = new FakeTarget({ installing: null, waiting, update: async () => {} });
  const page = loadPage({ controller: {}, registration });
  await settle();
  assert.equal(page.updateAvailable(), true);
  const next = new FakeTarget({ state: 'installing' });
  registration.installing = next;
  registration.fire('updatefound');
  next.state = 'installed';
  next.fire('statechange');
  assert.deepEqual(page.events, ['flutter-update-available']);
});

// ------------------------------------------------------------- variants ---

const UA = {
  chrome: ['Google Inc.', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36'],
  edge: ['Google Inc.', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0'],
  android: ['Google Inc.', 'Mozilla/5.0 (Linux; Android 15; CPH2719) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36'],
  safari262: ['Apple Computer, Inc.', 'Mozilla/5.0 (iPhone; CPU iPhone OS 26_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.2 Mobile/15E148 Safari/604.1'],
  safari27: ['Apple Computer, Inc.', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.0 Safari/605.1.15'],
  safari261: ['Apple Computer, Inc.', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.1 Safari/605.1.15'],
  chromeIos: ['Apple Computer, Inc.', 'Mozilla/5.0 (iPhone; CPU iPhone OS 26_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/141.0.0.0 Mobile/15E148 Safari/604.1'],
  firefox: ['', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:144.0) Gecko/20100101 Firefox/144.0'],
};
const isBlink = (vendor) => vendor === 'Google Inc.';
const fakeIntl = (blink) => (blink
  ? { v8BreakIterator: function () {}, Segmenter: function () {} }
  : { Segmenter: function () {} });
const fakeWasm = (wasmGC) => ({ validate: () => wasmGC });

/** Engine files the page (PWA_WASM in web/index.html) picks. */
function pageEngineFiles([vendor, userAgent], wasmGC = true) {
  const html = readFileSync('web/index.html', 'utf8');
  const start = html.indexOf('PWA_WASM: preload');
  const body = html.slice(start).match(/<script>([\s\S]*?)<\/script>/)[1];
  const ctx = {
    navigator: { vendor, userAgent },
    document: { createElement: () => ({}), head: { appendChild() {} } },
    WebAssembly: fakeWasm(wasmGC),
    Intl: fakeIntl(isBlink(vendor)),
    Uint8Array,
  };
  // Chrome and Firefox have ImageDecoder, Safari does not.
  if (vendor !== 'Apple Computer, Inc.') ctx.ImageDecoder = function () {};
  ctx.window = ctx;
  vm.runInNewContext(body, ctx);
  return [...ctx.attendixEngineFiles];
}

// -------------------------------------------------------------- worker ---

class FakeCache {
  constructor() { this.map = new Map(); }
  key(req) { return new URL(typeof req === 'string' ? req : req.url, ORIGIN + '/').href; }
  async match(req) { const r = this.map.get(this.key(req)); return r ? r.clone() : undefined; }
  async put(req, res) { this.map.set(this.key(req), res.clone()); }
  async add(req) { const res = await this.fetch(req); this.map.set(this.key(req), res); }
  async keys() { return [...this.map.keys()].map((url) => ({ url })); }
}

class FakeCaches {
  constructor(fetchFn) { this.stores = new Map(); this.fetch = fetchFn; }
  async open(name) {
    if (!this.stores.has(name)) {
      const c = new FakeCache(); c.fetch = this.fetch; this.stores.set(name, c);
    }
    return this.stores.get(name);
  }
  async keys() { return [...this.stores.keys()]; }
  async delete(name) { return this.stores.delete(name); }
}

/**
 * Loads the worker template with [resources] (path -> file text) as the
 * deploy; [network] (path -> text) is what the server answers.
 */
function loadWorker({ resources, network, listWaitMs = 30, browser = UA.chrome, wasmGC = true,
  version = 'v1', caches: sharedCaches = null }) {
  const template = readFileSync('tool/web/service_worker_template.js', 'utf8');
  const hashes = Object.fromEntries(Object.entries(resources).map(([k, v]) => [k, sha(v)]));
  const source = template
    .replace("/*VERSION*/''", `'${version}'`)
    .replace('/*RESOURCES*/{}', JSON.stringify(hashes))
    .replace(/const LIST_WAIT_WITH_PREVIOUS_MS = \d+;/, `const LIST_WAIT_WITH_PREVIOUS_MS = ${listWaitMs};`)
    .replace(/const LIST_WAIT_FIRST_MS = \d+;/, `const LIST_WAIT_FIRST_MS = ${listWaitMs};`);
  const handlers = {};
  // sw.network may be swapped: what the server answers from then on.
  const sw = { navigated: [], updates: 0, fetched: [], offline: false, network };
  const fetchFn = async (req) => {
    if (sw.offline) throw new TypeError('Failed to fetch');
    const url = new URL(typeof req === 'string' ? req : req.url, ORIGIN + '/');
    const path = url.pathname.slice(1) || 'index.html';
    sw.fetched.push(path);
    if (!(path in sw.network)) return new Response('', { status: 404 });
    const res = new Response(sw.network[path], { status: 200 });
    Object.defineProperty(res, 'type', { value: 'basic' });
    return res;
  };
  const caches = sharedCaches || new FakeCaches(fetchFn);
  caches.fetch = fetchFn;
  sw.caches = caches;
  sw.clients = [
    { url: ORIGIN + '/#/termine', navigate: async (u) => { sw.navigated.push(u); } },
    { url: ORIGIN + '/#/werke', navigate: async (u) => { sw.navigated.push(u); } },
  ];
  const self = {
    location: { origin: ORIGIN },
    navigator: { userAgent: browser[1] }, // a worker has no navigator.vendor
    addEventListener: (type, fn) => { handlers[type] = fn; },
    skipWaiting: () => {},
    clients: { claim: async () => {}, matchAll: async () => sw.clients },
    registration: { update: async () => { sw.updates++; } },
  };
  // Relative URLs resolve against the worker's location, like in a browser.
  class SwRequest extends Request {
    constructor(input, init) {
      super(typeof input === 'string' ? new URL(input, ORIGIN + '/').href : input, init);
    }
  }
  const ctx = {
    self, caches, fetch: fetchFn, Request: SwRequest, Response, URL, crypto: webcrypto,
    setTimeout, console, Promise, Array, Uint8Array, Set, Map, JSON, Error, String, Object,
    TypeError, WebAssembly: fakeWasm(wasmGC), Intl: fakeIntl(/Chrome\//.test(browser[1])),
  };
  vm.runInNewContext(source, ctx);
  sw.engineFiles = () => [...ctx.engineFiles()];
  const extendable = () => {
    const ev = { promises: [], waitUntil(p) { this.promises.push(p); }, async done() { await Promise.all(this.promises); } };
    return ev;
  };
  sw.install = async () => { const ev = extendable(); handlers.install(ev); return ev.done(); };
  sw.activate = async () => { const ev = extendable(); handlers.activate(ev); return ev.done(); };
  sw.message = (data) => { const ev = extendable(); ev.data = data; handlers.message(ev); return ev.done(); };
  sw.request = async (path, mode = 'cors') => {
    const ev = extendable();
    ev.request = { method: 'GET', mode, url: ORIGIN + '/' + path };
    handlers.fetch(ev);
    const res = await ev.response;
    await ev.done();
    return res;
  };
  // respondWith stores the promise
  const origFetch = handlers.fetch;
  handlers.fetch = (ev) => { ev.respondWith = (p) => { ev.response = p; }; origFetch(ev); };
  return sw;
}

const DEPLOY = {
  'index.html': '<html>',
  'flutter_bootstrap.js': 'boot-B',
  'assets/FontManifest.json': 'fonts-B',
  'assets/.env.app': 'env-B',
  'main.dart.wasm': 'wasm-B',
  'main.dart.mjs': 'mjs-B',
  'main.dart.js': 'js-B',
  'canvaskit/skwasm.js': 'skwasm-js',
  'canvaskit/skwasm.wasm': 'skwasm-wasm',
  'canvaskit/skwasm_heavy.js': 'heavy-js',
  'canvaskit/skwasm_heavy.wasm': 'heavy-wasm',
  'canvaskit/canvaskit.js': 'ck-js',
  'canvaskit/canvaskit.wasm': 'ck-wasm',
  'canvaskit/chromium/canvaskit.js': 'ckc-js',
  'canvaskit/chromium/canvaskit.wasm': 'ckc-wasm',
};
const COMPLETE = 'attendix-cache-complete';

/** Paths stored in [cache], without the completion marker. */
async function cachedPaths(cache) {
  return (await cache.keys()).map((r) => new URL(r.url).pathname.slice(1))
    .filter((p) => p !== COMPLETE).sort();
}

test('the worker picks the same engine files as the page in every browser', () => {
  for (const [name, browser] of Object.entries(UA)) {
    for (const wasmGC of [true, false]) {
      const sw = loadWorker({ resources: DEPLOY, network: DEPLOY, browser, wasmGC });
      assert.deepEqual(sw.engineFiles(), pageEngineFiles(browser, wasmGC), `${name}, wasmGC ${wasmGC}`);
    }
  }
  // The variants themselves.
  assert.deepEqual(pageEngineFiles(UA.chrome), ['main.dart.wasm', 'main.dart.mjs', 'canvaskit/skwasm.js', 'canvaskit/skwasm.wasm']);
  assert.deepEqual(pageEngineFiles(UA.safari262), ['main.dart.wasm', 'main.dart.mjs', 'canvaskit/skwasm_heavy.js', 'canvaskit/skwasm_heavy.wasm']);
  assert.deepEqual(pageEngineFiles(UA.safari261), ['main.dart.js', 'canvaskit/canvaskit.js', 'canvaskit/canvaskit.wasm']);
  assert.deepEqual(pageEngineFiles(UA.chrome, false), ['main.dart.js', 'canvaskit/chromium/canvaskit.js', 'canvaskit/chromium/canvaskit.wasm']);
});

test('activate after an older Attendix deploy reloads every open tab', async () => {
  const sw = loadWorker({ resources: DEPLOY, network: DEPLOY });
  await sw.caches.open('attendix-app-cache-old');
  await sw.activate();
  assert.deepEqual(sw.navigated, [ORIGIN + '/#/termine', ORIGIN + '/#/werke']);
  assert.deepEqual(await sw.caches.keys(), []);
});

test('activate after the Flutter 3.29 worker reloads its open tabs too', async () => {
  const sw = loadWorker({ resources: DEPLOY, network: DEPLOY });
  await sw.caches.open('flutter-app-cache');
  await sw.activate();
  assert.equal(sw.navigated.length, 2);
});

test('the first worker of a fresh visit reloads nothing', async () => {
  const sw = loadWorker({ resources: DEPLOY, network: DEPLOY });
  await sw.activate();
  assert.deepEqual(sw.navigated, []);
});

test('only a Flutter 3.29 tab open (no list): install, wait, activate, then start offline', async () => {
  for (const browser of [UA.chrome, UA.safari262, UA.firefox]) {
    const sw = loadWorker({ resources: DEPLOY, network: DEPLOY, browser });
    const flutter = await sw.caches.open('flutter-app-cache');
    await flutter.put('main.dart.js', new Response('js-3.29'));
    await sw.install(); // no page list: the start set of this browser
    const cache = await sw.caches.open('attendix-app-cache-v1');
    const expected = ['', 'assets/.env.app', 'assets/FontManifest.json', 'flutter_bootstrap.js',
      ...sw.engineFiles()].sort();
    assert.deepEqual(await cachedPaths(cache), expected);
    assert.ok(await cache.match(COMPLETE));
    // Waiting; the old tab is closed, the new worker activates.
    await sw.activate();
    assert.deepEqual(await sw.caches.keys(), ['attendix-app-cache-v1']);
    sw.offline = true;
    assert.equal(await (await sw.request('', 'navigate')).text(), '<html>');
    for (const file of ['flutter_bootstrap.js', 'assets/FontManifest.json', 'assets/.env.app', ...sw.engineFiles()]) {
      assert.equal(await (await sw.request(file)).text(), DEPLOY[file], file);
    }
  }
});

test('a failed install leaves no cache behind', async () => {
  const sw = loadWorker({ resources: DEPLOY, network: { ...DEPLOY, 'main.dart.wasm': 'wasm-C' } });
  await assert.rejects(sw.install(), /main\.dart\.wasm is not this deploy's version/);
  assert.deepEqual(await sw.caches.keys(), []);
});

test('a cache of an interrupted install is no predecessor', async () => {
  const sw = loadWorker({ resources: DEPLOY, network: DEPLOY });
  const partial = await sw.caches.open('attendix-app-cache-old');
  await partial.put('flutter_bootstrap.js', new Response('boot-B'));
  await sw.install(); // no list: start set, not just the bootstrap
  const cache = await sw.caches.open('attendix-app-cache-v1');
  assert.equal(await (await cache.match('main.dart.wasm')).text(), 'wasm-B');
  assert.equal(await (await cache.match('canvaskit/skwasm.wasm')).text(), 'skwasm-wasm');
});

test('install fails when the server already has another deploy\'s app page', async () => {
  const sw = loadWorker({ resources: DEPLOY, network: { ...DEPLOY, 'index.html': '<html C>' } });
  await assert.rejects(sw.install(), /index\.html is not this deploy's version/);
  assert.deepEqual(await sw.caches.keys(), []);
});

test('online, another deploy\'s app page is not shown: this version\'s page, and the update is looked for', async () => {
  const sw = loadWorker({ resources: DEPLOY, network: DEPLOY });
  await sw.install();
  sw.network = { ...DEPLOY, 'index.html': '<html C>' };
  assert.equal(await (await sw.request('?mode=ios', 'navigate')).text(), '<html>');
  assert.equal(sw.updates, 1);
  const cache = await sw.caches.open('attendix-app-cache-v1');
  assert.equal(await (await cache.match('./')).text(), '<html>');
});

test('online, this deploy\'s app page comes from the network and is stored', async () => {
  const sw = loadWorker({ resources: DEPLOY, network: DEPLOY });
  await sw.install();
  assert.equal(await (await sw.request('', 'navigate')).text(), '<html>');
  assert.equal(sw.updates, 0);
});

test('a failed install of a new worker keeps the active worker\'s cache', async () => {
  const caches = new FakeCaches(null);
  const active = loadWorker({ resources: DEPLOY, network: DEPLOY, caches });
  await active.install();
  await active.activate();
  // New worker (other script, so other VERSION); its deploy is not online.
  const next = loadWorker({ resources: { ...DEPLOY, 'main.dart.wasm': 'wasm-D' }, network: DEPLOY,
    version: 'v2', caches });
  await assert.rejects(next.install(), /main\.dart\.wasm is not this deploy's version/);
  assert.deepEqual(await caches.keys(), ['attendix-app-cache-v1']);
  active.offline = true;
  assert.equal(await (await active.request('main.dart.wasm')).text(), 'wasm-B');
  assert.equal(await (await active.request('', 'navigate')).text(), '<html>');
});

test('install takes the page list and stores only verified files', async () => {
  const sw = loadWorker({ resources: DEPLOY, network: DEPLOY, listWaitMs: 2000 });
  const installed = sw.install();
  await sw.message({ type: 'cache-urls', urls: [ORIGIN + '/main.dart.wasm', ORIGIN + '/flutter_bootstrap.js'] });
  await installed;
  const cache = await sw.caches.open('attendix-app-cache-v1');
  assert.equal(await (await cache.match('main.dart.wasm')).text(), 'wasm-B');
  assert.equal(await (await cache.match('flutter_bootstrap.js')).text(), 'boot-B');
  assert.deepEqual(await cachedPaths(cache), ['', 'flutter_bootstrap.js', 'main.dart.wasm']);
  assert.ok(await cache.match(COMPLETE));
});

test('install fails when the server already has another deploy\'s file', async () => {
  const sw = loadWorker({ resources: DEPLOY, network: { ...DEPLOY, 'main.dart.wasm': 'wasm-C' }, listWaitMs: 2000 });
  const installed = sw.install();
  await sw.message({ type: 'cache-urls', urls: [ORIGIN + '/main.dart.wasm'] });
  await assert.rejects(installed, /main\.dart\.wasm is not this deploy's version/);
  assert.deepEqual(await sw.caches.keys(), []);
});

test('install copies unchanged files and downloads changed ones of the previous cache', async () => {
  const sw = loadWorker({ resources: DEPLOY, network: DEPLOY });
  const old = await sw.caches.open('attendix-app-cache-old');
  await old.put('main.dart.wasm', new Response('wasm-B'));
  await old.put('flutter_bootstrap.js', new Response('boot-A'));
  await old.put(COMPLETE, new Response('old'));
  await sw.install(); // complete previous cache: no page list needed
  const cache = await sw.caches.open('attendix-app-cache-v1');
  assert.equal(await (await cache.match('flutter_bootstrap.js')).text(), 'boot-B');
  assert.ok(!sw.fetched.includes('main.dart.wasm'), 'unchanged file copied, not downloaded');
  // Exactly what the device used before (plus the app page), no start set.
  assert.deepEqual(await cachedPaths(cache), ['', 'flutter_bootstrap.js', 'main.dart.wasm']);
});

test('a cache miss answered with another deploy\'s file is not stored and looks for the update', async () => {
  const sw = loadWorker({ resources: DEPLOY, network: { ...DEPLOY, 'main.dart.wasm': 'wasm-C' } });
  const res = await sw.request('main.dart.wasm');
  assert.equal(await res.text(), 'wasm-C');
  const cache = await sw.caches.open('attendix-app-cache-v1');
  assert.equal(await cache.match('main.dart.wasm'), undefined);
  assert.equal(sw.updates, 1);
});

test('a cache miss with this deploy\'s file is stored', async () => {
  const sw = loadWorker({ resources: DEPLOY, network: DEPLOY });
  await sw.request('main.dart.wasm');
  const cache = await sw.caches.open('attendix-app-cache-v1');
  assert.equal(await (await cache.match('main.dart.wasm')).text(), 'wasm-B');
  assert.equal(sw.updates, 0);
});
