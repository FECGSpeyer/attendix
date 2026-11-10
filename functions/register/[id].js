// LINK_PREVIEW: Cloudflare Pages Function for the invitation link
// attendix.de/register/<register_id>.
//
// WhatsApp, Telegram, iMessage, Signal … fetch the shared link and read the
// Open Graph tags; they do not run the Flutter app. web/index.html carries a
// generic preview (logo, "Attendix"). Here the page gets the group's name as
// well: "Einladung zu Sinfo Speyer" instead of just "Attendix".
//
// Only this path runs a Function (Pages builds _routes.json from this
// folder); every other path stays a plain static file. The page itself is
// the normal app (context.next()), so a person opening the link sees the
// same as before. Anything that goes wrong (unknown id, Supabase not
// reachable) returns the page unchanged with the generic preview.
//
// The group is read like the app's registration page does
// (tenantByRegisterIdProvider: tenants where register_id = id) with the
// public anon key the web app ships in assets/.env.app, so the Function
// needs no own settings in Cloudflare.

const LOOKUP_TTL_SECONDS = 600;

// Same headers as web/_headers for "/*" – _headers is not applied to
// Function responses, and the app needs them (COOP/COEP for multi-threaded
// rendering, frame-ancestors for Teams).
const PAGE_HEADERS = {
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'require-corp',
  'Content-Security-Policy':
    "frame-ancestors 'self' *.cloud.microsoft teams.microsoft.com *.teams.microsoft.com *.microsoft365.com *.office.com *.skype.com *.teams.microsoft.us *.gov.teams.microsoft.us local.teams.office.com;",
};

export async function onRequestGet(context) {
  const page = await context.next();
  const response = withPageHeaders(page);
  const type = response.headers.get('Content-Type') || '';
  if (!response.ok || !type.includes('text/html')) return response;

  let group = null;
  try {
    group = await groupName(context, String(context.params.id || ''));
  } catch (e) {
    group = null;
  }
  if (!group) return response;

  const title = `Einladung zu ${group}`;
  const description =
    `Du bist zu ${group} in Attendix eingeladen. Hier meldest du dich an – ` +
    'im Browser oder in der App.';
  return new HTMLRewriter()
    .on('meta[property="og:title"], meta[name="twitter:title"]', {
      element(el) { el.setAttribute('content', title); },
    })
    .on('meta[property="og:description"], meta[name="twitter:description"], meta[name="description"]', {
      element(el) { el.setAttribute('content', description); },
    })
    .on('title', {
      element(el) { el.setInnerContent(`${title} · Attendix`); },
    })
    .transform(response);
}

function withPageHeaders(page) {
  const response = new Response(page.body, page);
  for (const [name, value] of Object.entries(PAGE_HEADERS)) {
    if (!response.headers.has(name)) response.headers.set(name, value);
  }
  return response;
}

async function groupName(context, id) {
  // Register ids are UUIDs; anything else is not looked up.
  if (!/^[A-Za-z0-9-]{20,64}$/.test(id)) return null;

  const cache = caches.default;
  const cacheKey = new Request(new URL(`/__link_preview/register/${id}`, context.request.url).toString());
  const cached = await cache.match(cacheKey);
  if (cached) return (await cached.json()).name || null;

  const env = await appEnv(context);
  if (!env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) return null;

  const url = `${env.SUPABASE_URL.replace(/\/+$/, '')}/rest/v1/tenants` +
    `?select=shortName,longName&register_id=eq.${encodeURIComponent(id)}&limit=1`;
  const res = await fetch(url, {
    headers: {
      apikey: env.SUPABASE_ANON_KEY,
      Authorization: `Bearer ${env.SUPABASE_ANON_KEY}`,
      Accept: 'application/json',
    },
  });
  if (!res.ok) return null;
  const rows = await res.json();
  const row = Array.isArray(rows) ? rows[0] : null;
  const name = row ? (String(row.longName || '').trim() || String(row.shortName || '').trim()) : '';

  // Also remember "no group" so a wrong id does not hit Supabase each time.
  context.waitUntil(cache.put(cacheKey, new Response(JSON.stringify({ name }), {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': `max-age=${LOOKUP_TTL_SECONDS}`,
    },
  })));
  return name || null;
}

// SUPABASE_URL and SUPABASE_ANON_KEY from the deployed assets/.env.app
// (KEY=value lines, written by the deploy workflow).
async function appEnv(context) {
  const res = await context.env.ASSETS.fetch(new URL('/assets/.env.app', context.request.url));
  if (!res.ok) return {};
  const env = {};
  for (const line of (await res.text()).split(/\r?\n/)) {
    const m = /^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*?)\s*$/.exec(line);
    if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
  return env;
}
