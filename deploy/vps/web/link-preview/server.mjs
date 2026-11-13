// LINK_PREVIEW on the VPS: port of functions/register/[id].js (Cloudflare Pages
// Function). Serves /register/<id> as the normal app page (index.html) with the
// group's name in title and Open Graph tags, so WhatsApp, Telegram, iMessage …
// show "Einladung zu <Gruppe>". nginx adds the security headers and falls back
// to the plain index.html when this service is down.
//
// Reads SUPABASE_URL and SUPABASE_ANON_KEY from the deployed assets/.env.app,
// so it needs no own settings. No dependencies (Node >= 20).
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';

const WEB_ROOT = process.env.WEB_ROOT || '/web';
const LOOKUP_TTL_MS = 10 * 60 * 1000;
const cache = new Map(); // id -> { name, at }

async function appEnv() {
  const env = {};
  const text = await readFile(`${WEB_ROOT}/assets/.env.app`, 'utf8');
  for (const line of text.split(/\r?\n/)) {
    const m = /^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*?)\s*$/.exec(line);
    if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
  return env;
}

async function groupName(id) {
  // Register ids are UUIDs; anything else is not looked up.
  if (!/^[A-Za-z0-9-]{20,64}$/.test(id)) return null;

  const hit = cache.get(id);
  if (hit && Date.now() - hit.at < LOOKUP_TTL_MS) return hit.name || null;

  const env = await appEnv();
  if (!env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) return null;

  const url = `${env.SUPABASE_URL.replace(/\/+$/, '')}/rest/v1/tenants` +
    `?select=shortName,longName&register_id=eq.${encodeURIComponent(id)}&limit=1`;
  const res = await fetch(url, {
    headers: {
      apikey: env.SUPABASE_ANON_KEY,
      Authorization: `Bearer ${env.SUPABASE_ANON_KEY}`,
      Accept: 'application/json',
    },
    signal: AbortSignal.timeout(3000),
  });
  if (!res.ok) return null;
  const rows = await res.json();
  const row = Array.isArray(rows) ? rows[0] : null;
  const name = row ? (String(row.longName || '').trim() || String(row.shortName || '').trim()) : '';

  // Also remember "no group" so a wrong id does not hit Supabase each time.
  if (cache.size > 5000) cache.clear();
  cache.set(id, { name, at: Date.now() });
  return name || null;
}

function escapeHtml(s) {
  return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

export function withGroup(html, group) {
  const title = escapeHtml(`Einladung zu ${group}`);
  const description = escapeHtml(
    `Du bist zu ${group} in Attendix eingeladen. Hier meldest du dich an – ` +
    'im Browser oder in der App.');
  const setContent = (tag, value) => tag.replace(/content="[^"]*"/, `content="${value}"`);
  return html
    .replace(/<meta (?:property="og:title"|name="twitter:title")[^>]*>/g, (t) => setContent(t, title))
    .replace(/<meta (?:property="og:description"|name="twitter:description"|name="description")[^>]*>/g,
      (t) => setContent(t, description))
    .replace(/<title>[^<]*<\/title>/, `<title>${title} · Attendix</title>`);
}

createServer(async (req, res) => {
  try {
    const html = await readFile(`${WEB_ROOT}/index.html`, 'utf8');
    let out = html;
    const m = /^\/register\/([^/?#]+)/.exec(req.url || '');
    if (m) {
      let group = null;
      try {
        group = await groupName(decodeURIComponent(m[1]));
      } catch {
        group = null;
      }
      if (group) out = withGroup(html, group);
    }
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(req.method === 'HEAD' ? undefined : out);
  } catch (e) {
    console.error('link-preview:', e);
    res.writeHead(502);
    res.end();
  }
}).listen(8080, () => console.log('link-preview listening on 8080'));
