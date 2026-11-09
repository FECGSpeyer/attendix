// Side-by-side screenshots of the Ionic web app and the Flutter web app for
// every route of the parity inventory and every test role.
// Runs on a machine that can reach attendix.de and Supabase (Leon's Mac).
//
//   cd tool/parity/screens && npm install
//   ATTX_PASSWORD=… node compare.mjs \
//     --env ../../../.env.app \
//     --out ~/privateRepos/parity-shots \
//     [--ionic https://attendix.de] [--flutter https://attendix-5eg.pages.dev] \
//     [--roles admin,helfer] [--only settings] [--look ios|md|both]
//
// Read-only: it signs in with the test accounts of the tenant "Attendix Test"
// (leonjaeger00+attx-<rolle>@gmail.com), reads a few ids via the REST API to
// fill route parameters and only opens pages. Both apps get their own session
// (password grant), injected into localStorage under sb-<ref>-auth-token –
// the key supabase-js and supabase_flutter (web) both use.
import { chromium } from 'playwright';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const opt = (n, d) => {
  const i = args.indexOf(n);
  return i >= 0 ? args[i + 1] : d;
};
const expand = (p) => (p.startsWith('~') ? join(homedir(), p.slice(1)) : p);
const envFile = expand(opt('--env', join(here, '../../../.env.app')));
const outDir = expand(opt('--out', join(homedir(), 'privateRepos/parity-shots')));
const IONIC = opt('--ionic', 'https://attendix.de').replace(/\/$/, '');
const FLUTTER = opt('--flutter', 'https://attendix-5eg.pages.dev').replace(/\/$/, '');
const looks = { ios: ['ios'], md: ['md'], both: ['ios', 'md'] }[opt('--look', 'both')];
const only = opt('--only', '');
const password = process.env.ATTX_PASSWORD;
if (!password) {
  console.error('ATTX_PASSWORD is not set (password of the attx test accounts).');
  process.exit(64);
}
const env = Object.fromEntries(readFileSync(envFile, 'utf8').split('\n').filter((l) => /^\w+=/.test(l)).map((l) => [l.split('=')[0], l.slice(l.indexOf('=') + 1).trim()]));
const SB = env.SUPABASE_URL;
const ANON = env.SUPABASE_ANON_KEY;
const REF = new URL(SB).host.split('.')[0];
const HELP_ARTICLE = 'gs-overview';
const TENANT_NAME = opt('--tenant', 'Attendix Test');

const ROLES = (opt('--roles', 'admin,verantwortlich,beobachter,helfer,stimmfuehrer,stimmhelfer,spieler,eltern,bewerber')).split(',');
const email = (role) => `leonjaeger00+attx-${role}@gmail.com`;

// Routes from the inventory (Ionic paths; Flutter maps /tabs/... itself).
const inv = JSON.parse(readFileSync(join(here, '../../../docs/parity/ionic-inventory.json'), 'utf8'));
const routeItems = inv.units.find((u) => u.id === 'app-routing.module').items.filter((i) => i.kind === 'route' && !i.redirectTo);
const SKIP = new Set(['/', '/tabs', '/register', '/app', '/:songSharingId', '/:songSharingId/import', '/:songSharingId/:songId', '/tabs/settings/register']);

const api = async (path, { token, method = 'GET', body } = {}) => {
  const r = await fetch(`${SB}${path}`, {
    method,
    headers: { apikey: ANON, Authorization: `Bearer ${token ?? ANON}`, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!r.ok) throw new Error(`${method} ${path}: ${r.status} ${await r.text()}`);
  return r.json();
};
const signIn = (role) => api('/auth/v1/token?grant_type=password', { method: 'POST', body: { email: email(role), password } });

const one = async (token, table, query) => {
  try {
    const rows = await api(`/rest/v1/${table}?${query}&limit=1`, { token });
    return rows[0] ?? null;
  } catch {
    return null;
  }
};

const fillParams = async (path, token, tenantId) => {
  const ids = {};
  if (path.includes(':id') || path.includes(':attendanceId')) {
    if (path.includes('/attendance')) ids.id = ids.attendanceId = (await one(token, 'attendance', `tenantId=eq.${tenantId}&select=id&order=date.desc`))?.id;
    else if (path.includes('/songs')) ids.id = (await one(token, 'songs', `tenantId=eq.${tenantId}&select=id&order=number.asc`))?.id;
    else if (path.includes('/types')) ids.id = (await one(token, 'attendance_types', `tenant_id=eq.${tenantId}&select=id&order=index.asc`))?.id;
    else if (path.includes('/shifts')) ids.id = (await one(token, 'shifts', `tenant_id=eq.${tenantId}&select=id`))?.id;
    else if (path.includes('/tasks')) ids.id = (await one(token, 'tasks', `tenant_id=eq.${tenantId}&select=id`))?.id;
    else if (path.includes('/agenda-items')) ids.id = (await one(token, 'agenda_items', `tenant_id=eq.${tenantId}&select=id`))?.id;
    else if (path.includes('/messages')) ids.id = (await one(token, 'messages', `tenantId=eq.${tenantId}&select=id`))?.id;
    else if (path.includes('/auto-messages')) ids.id = (await one(token, 'auto_message_rules', `tenantId=eq.${tenantId}&select=id`))?.id;
    else if (path.includes('/help/article')) ids.id = HELP_ARTICLE;
  }
  if (Object.values(ids).some((v) => v == null)) return null;
  return path.replace(/:(\w+)/g, (_, k) => ids[k] ?? `:${k}`);
};

const slug = (p) => p.replace(/^\//, '').replace(/[/:?=&]+/g, '_') || 'root';

const VIEWPORTS = {
  ios: { viewport: { width: 393, height: 852 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1' },
  md: { viewport: { width: 1280, height: 860 }, deviceScaleFactor: 1 },
};

const shoot = async (browser, look, base, session, tenantId, path, file, isIonic) => {
  const ctx = await browser.newContext({ ...VIEWPORTS[look], locale: 'de-DE', timezoneId: 'Europe/Berlin' });
  await ctx.addInitScript(({ key, value, tenantId, isIonic }) => {
    try {
      if (!localStorage.getItem('__parity_seeded')) {
        localStorage.setItem(key, value);
        if (isIonic) localStorage.setItem('currentTenantId', String(tenantId));
        else localStorage.setItem('flutter.current_tenant_id', String(tenantId));
        // no "install the app" / push prompts in screenshots
        localStorage.setItem('native_app_ad_shown', 'true');
        localStorage.setItem('push_prompt_shown', 'true');
        localStorage.setItem('flutter.push_prompt_shown', 'true');
        localStorage.setItem('__parity_seeded', '1');
      }
    } catch { /* ignore */ }
  }, { key: `sb-${REF}-auth-token`, value: JSON.stringify(session), tenantId, isIonic });
  if (isIonic && look === 'ios') {
    // On a real iPhone Ionic renders with html{font:-apple-system-body} = 17px.
    await ctx.addInitScript(() => {
      document.addEventListener('DOMContentLoaded', () => {
        const s = document.createElement('style');
        s.textContent = 'html{font-size:17px!important}';
        document.head.appendChild(s);
      });
    });
  }
  const page = await ctx.newPage();
  const sep = path.includes('?') ? '&' : '?';
  const url = `${base}${path}${sep}${isIonic ? 'ionic:mode' : 'mode'}=${look}`;
  let finalUrl = null;
  let error = null;
  try {
    await page.goto(url, { waitUntil: 'networkidle', timeout: 45000 });
    await page.waitForTimeout(isIonic ? 1500 : 3500);
    finalUrl = page.url().replace(base, '');
    await page.screenshot({ path: file, fullPage: false });
  } catch (e) {
    error = String(e.message ?? e).split('\n')[0];
    try { await page.screenshot({ path: file }); } catch { /* ignore */ }
  }
  await ctx.close();
  return { url, finalUrl, error };
};

const main = async () => {
  mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch({ channel: process.env.PW_CHANNEL || undefined });
  const results = [];
  for (const role of ROLES) {
    let session;
    try {
      session = await signIn(role);
    } catch (e) {
      console.error(`${role}: sign-in failed (${e.message.slice(0, 120)})`);
      continue;
    }
    const token = session.access_token;
    const tenants = await api(`/rest/v1/tenantUsers?userId=eq.${session.user.id}&select=tenantId,role,tenants(longName,shortName)`, { token }).catch(() => []);
    const t = tenants.find((x) => x.tenants?.longName === TENANT_NAME) ?? tenants[0];
    if (!t) {
      console.error(`${role}: no tenant`);
      continue;
    }
    for (const r of routeItems) {
      if (SKIP.has(r.path)) continue;
      if (only && !r.path.includes(only)) continue;
      const path = await fillParams(r.path, token, t.tenantId);
      if (!path) {
        results.push({ role, route: r.path, skipped: 'keine Daten für Parameter' });
        continue;
      }
      for (const look of looks) {
        const dir = join(outDir, role, look);
        mkdirSync(dir, { recursive: true });
        const name = slug(path);
        const a = await shoot(browser, look, IONIC, session, t.tenantId, path, join(dir, `${name}__ionic.png`), true);
        const b = await shoot(browser, look, FLUTTER, session, t.tenantId, path, join(dir, `${name}__flutter.png`), false);
        const row = { role, look, route: r.path, path, ionic: a, flutter: b, img: `${role}/${look}/${name}` };
        results.push(row);
        console.log(`${role.padEnd(15)} ${look} ${path.padEnd(48)} ionic→${a.finalUrl ?? a.error}  flutter→${b.finalUrl ?? b.error}`);
      }
    }
  }
  await browser.close();
  writeFileSync(join(outDir, 'results.json'), JSON.stringify({ ionic: IONIC, flutter: FLUTTER, at: new Date().toISOString(), results }, null, 1));
  // simple gallery
  const esc = (s) => String(s ?? '').replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
  const html = [`<!doctype html><meta charset="utf-8"><title>Parität Bildvergleich</title><style>body{font:14px system-ui;margin:16px}figure{display:inline-block;margin:0 8px 0 0}img{max-width:420px;border:1px solid #ccc}section{margin:0 0 28px}h3{margin:4px 0}.warn{color:#b00}</style>`];
  for (const r of results.filter((x) => x.img)) {
    const mismatch = (r.ionic.finalUrl ?? '').split('?')[0] !== (r.flutter.finalUrl ?? '').split('?')[0];
    html.push(`<section><h3>${esc(r.role)} · ${esc(r.look)} · ${esc(r.path)}</h3><div class="${mismatch ? 'warn' : ''}">Ionic → ${esc(r.ionic.finalUrl ?? r.ionic.error)} · Flutter → ${esc(r.flutter.finalUrl ?? r.flutter.error)}</div><figure><img src="${r.img}__ionic.png"><figcaption>Ionic</figcaption></figure><figure><img src="${r.img}__flutter.png"><figcaption>Flutter</figcaption></figure></section>`);
  }
  writeFileSync(join(outDir, 'index.html'), html.join('\n'));
  console.log(`done: ${results.length} rows → ${outDir}/index.html`);
};

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
