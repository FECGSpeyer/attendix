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
function loadPage({ controller }) {
  const html = readFileSync('web/index.html', 'utf8');
  const start = html.indexOf('<!-- Service Worker Update Detection -->');
  const body = html.slice(start).match(/<script>([\s\S]*?)<\/script>/)[1];
  const listeners = {};
  const page = { reloads: 0 };
  const serviceWorker = {
    controller,
    ready: new Promise(() => {}),
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
  ctx.dispatchEvent = () => {};
  vm.runInNewContext(body, ctx);
  page.controllerChange = () => (listeners.controllerchange || []).forEach((fn) => fn());
  return page;
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
function loadWorker({ resources, network, listWaitMs = 30 }) {
  const template = readFileSync('tool/web/service_worker_template.js', 'utf8');
  const hashes = Object.fromEntries(Object.entries(resources).map(([k, v]) => [k, sha(v)]));
  const source = template
    .replace("/*VERSION*/''", "'v1'")
    .replace('/*RESOURCES*/{}', JSON.stringify(hashes))
    .replace(/const LIST_WAIT_WITH_PREVIOUS_MS = \d+;/, `const LIST_WAIT_WITH_PREVIOUS_MS = ${listWaitMs};`)
    .replace(/const LIST_WAIT_FIRST_MS = \d+;/, `const LIST_WAIT_FIRST_MS = ${listWaitMs};`);
  const handlers = {};
  const sw = { navigated: [], updates: 0, fetched: [] };
  const fetchFn = async (req) => {
    const url = new URL(typeof req === 'string' ? req : req.url, ORIGIN + '/');
    const path = url.pathname.slice(1) || 'index.html';
    sw.fetched.push(path);
    if (!(path in network)) return new Response('', { status: 404 });
    const res = new Response(network[path], { status: 200 });
    Object.defineProperty(res, 'type', { value: 'basic' });
    return res;
  };
  const caches = new FakeCaches(fetchFn);
  sw.caches = caches;
  sw.clients = [
    { url: ORIGIN + '/#/termine', navigate: async (u) => { sw.navigated.push(u); } },
    { url: ORIGIN + '/#/werke', navigate: async (u) => { sw.navigated.push(u); } },
  ];
  const self = {
    location: { origin: ORIGIN },
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
  vm.runInNewContext(source, {
    self, caches, fetch: fetchFn, Request: SwRequest, Response, URL, crypto: webcrypto,
    setTimeout, console, Promise, Array, Uint8Array, Set, Map, JSON, Error, String,
  });
  const extendable = () => {
    const ev = { promises: [], waitUntil(p) { this.promises.push(p); }, async done() { await Promise.all(this.promises); } };
    return ev;
  };
  sw.install = async () => { const ev = extendable(); handlers.install(ev); return ev.done(); };
  sw.activate = async () => { const ev = extendable(); handlers.activate(ev); return ev.done(); };
  sw.message = (data) => { const ev = extendable(); ev.data = data; handlers.message(ev); return ev.done(); };
  sw.request = async (path) => {
    const ev = extendable();
    ev.request = { method: 'GET', mode: 'cors', url: ORIGIN + '/' + path };
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

const DEPLOY = { 'index.html': '<html>', 'main.dart.wasm': 'wasm-B', 'flutter_bootstrap.js': 'boot-B' };

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

test('install without a previous cache and without a file list fails', async () => {
  const sw = loadWorker({ resources: DEPLOY, network: DEPLOY });
  await assert.rejects(sw.install(), /no file list from the page/);
});

test('install takes the page list and stores only verified files', async () => {
  const sw = loadWorker({ resources: DEPLOY, network: DEPLOY, listWaitMs: 2000 });
  const installed = sw.install();
  await sw.message({ type: 'cache-urls', urls: [ORIGIN + '/main.dart.wasm', ORIGIN + '/flutter_bootstrap.js'] });
  await installed;
  const cache = await sw.caches.open('attendix-app-cache-v1');
  assert.equal(await (await cache.match('main.dart.wasm')).text(), 'wasm-B');
  assert.equal(await (await cache.match('flutter_bootstrap.js')).text(), 'boot-B');
});

test('install fails when the server already has another deploy\'s file', async () => {
  const sw = loadWorker({ resources: DEPLOY, network: { ...DEPLOY, 'main.dart.wasm': 'wasm-C' }, listWaitMs: 2000 });
  const installed = sw.install();
  await sw.message({ type: 'cache-urls', urls: [ORIGIN + '/main.dart.wasm'] });
  await assert.rejects(installed, /main\.dart\.wasm is not this deploy's version/);
});

test('install copies unchanged files and downloads changed ones of the previous cache', async () => {
  const sw = loadWorker({ resources: DEPLOY, network: DEPLOY });
  const old = await sw.caches.open('attendix-app-cache-old');
  await old.put('main.dart.wasm', new Response('wasm-B'));
  await old.put('flutter_bootstrap.js', new Response('boot-A'));
  await sw.install(); // previous cache: no page list needed
  const cache = await sw.caches.open('attendix-app-cache-v1');
  assert.equal(await (await cache.match('flutter_bootstrap.js')).text(), 'boot-B');
  assert.ok(!sw.fetched.includes('main.dart.wasm'), 'unchanged file copied, not downloaded');
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
