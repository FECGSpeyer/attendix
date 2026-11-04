// Helpers around docs/parity/ionic-inventory.json (see docs/parity/README.md).
//
//   node tool/parity/parity.mjs batches                 → docs/parity/batches.json
//   node tool/parity/parity.mjs slice <batch> <out>     → input file for one review batch
//   node tool/parity/parity.mjs report                  → docs/parity/summary.md + tracker-data.json
//   node tool/parity/parity.mjs diff <old.json> [new]   → items added/removed by a new Ionic version
//   node tool/parity/parity.mjs todo                    → items without a status yet, per batch
//   node tool/parity/parity.mjs verify-slices <dir> [n] [b01-x,b02-y] → input files for the second pass
//   node tool/parity/parity.mjs fixlists            → docs/parity/fixes/<paket>.md work lists
import { readFileSync, writeFileSync, readdirSync, existsSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { createHash } from 'node:crypto';

const DIR = 'docs/parity';
const INVENTORY = join(DIR, 'ionic-inventory.json');
const STATUS_DIR = join(DIR, 'status');
const load = (f) => JSON.parse(readFileSync(f, 'utf8'));
const [cmd, ...rest] = process.argv.slice(2);

const weight = (u) => u.items.length + Math.ceil((u.items.find((i) => i.kind === 'logic')?.methods.length ?? 0) / 4);
const family = (id) => {
  const p = id.split('/');
  if (p[0] === 'services' || p[0] === 'utilities' || p[0] === 'i18n') return 'services';
  if (['app-routing.module', 'app.component', 'app.module', 'tabs', 'app-redirect', 'legal', 'terms', 'login', 'register', 'open-attendance', 'open-file', 'teams-config'].includes(p[0])) return 'app';
  if (['org-settings', 'org-plans', 'org-plan-public', 'public-planning', 'shared-plan', 'planning'].includes(p[0])) return 'planning-org';
  if (['team-organization', 'tasks', 'agenda-items', 'protocols'].includes(p[0])) return 'team';
  if (['messages', 'notifications', 'shared', 'home-dashboard', 'dashboard', 'stats', 'history', 'export'].includes(p[0])) return p[0] === 'shared' ? 'shared' : 'overview';
  if (['teacher', 'teachers', 'instruments', 'duty'].includes(p[0])) return 'teachers-instruments-duty';
  if (p[0] === 'song-viewer') return 'songs';
  if (p[0] === 'settings') return `settings-${p[1] === 'general' ? 'general' : p[1] === 'settings' ? 'main' : 'other'}`;
  return p[0];
};

const makeBatches = (inv, max = 230) => {
  const fams = new Map();
  for (const u of inv.units) {
    const f = family(u.id);
    if (!fams.has(f)) fams.set(f, []);
    fams.get(f).push(u);
  }
  const batches = [];
  for (const [f, units] of [...fams.entries()].sort()) {
    let cur = null;
    const total = units.reduce((s, u) => s + weight(u), 0);
    const target = total / Math.ceil(total / max);
    for (const u of units.sort((a, b) => a.id.localeCompare(b.id))) {
      const w = weight(u);
      if (!cur || (cur.weight + w > target * 1.15 && cur.weight > 0)) {
        cur = { id: null, family: f, units: [], weight: 0 };
        batches.push(cur);
      }
      cur.units.push(u.id);
      cur.weight += w;
    }
  }
  // fold tiny batches into the lighter neighbour of the same family
  for (let i = batches.length - 1; i >= 0; i--) {
    const b = batches[i];
    if (b.weight >= 60) continue;
    const cands = [batches[i - 1], batches[i + 1]].filter((x) => x && x.family === b.family);
    if (!cands.length) continue;
    const t = cands.sort((x, y) => x.weight - y.weight)[0];
    t.units.push(...b.units);
    t.weight += b.weight;
    batches.splice(i, 1);
  }
  batches.forEach((b, i) => { b.id = `b${String(i + 1).padStart(2, '0')}-${b.family}`; });
  return batches;
};

// Extra findings (hidden logic) get a stable id from unit + title, so the
// same finding reported twice is one entry and a later pass can rate it.
const extraId = (e) => `x-${createHash('sha1').update(`${e.unit}|${e.title}`).digest('hex').slice(0, 10)}`;
const readStatuses = () => {
  const out = { items: {}, extra: [], files: [] };
  if (!existsSync(STATUS_DIR)) return out;
  const extras = new Map();
  const extraVerdicts = [];
  for (const f of readdirSync(STATUS_DIR).filter((x) => x.endsWith('.json')).sort()) {
    const s = load(join(STATUS_DIR, f));
    out.files.push({ file: f, batch: s.batch, flutter: s.flutter, ionic: s.ionic });
    // later files (e.g. verification passes "zz-verify-*") override earlier ones
    for (const [id, st] of Object.entries(s.items ?? {})) {
      if (id.startsWith('x-')) extraVerdicts.push({ id, ...st, src: f });
      else out.items[id] = { ...out.items[id], ...st, src: f, ionicAt: s.ionic };
    }
    for (const e of s.extra ?? []) {
      const id = extraId(e);
      extras.set(id, { ...extras.get(id), ...e, id, src: f });
    }
    for (const o of s.extraOverride ?? []) (out.overrides ??= []).push({ ...o, src: f });
  }
  // second pass on an extra: s ok/na withdraws it, otherwise sev/n/f are updated
  for (const v of extraVerdicts) {
    const e = extras.get(v.id);
    if (!e) continue;
    if (v.s === 'ok' || v.s === 'na') extras.delete(v.id);
    else extras.set(v.id, { ...e, sev: v.sev ?? e.sev, n: v.n ?? e.n, f: v.f ?? e.f, v: v.v, vsrc: v.src });
  }
  out.extra = [...extras.values()];
  // A later pass can withdraw or re-rate an extra finding (duplicate of an
  // item, disproved): { unit, title (prefix), drop: true | sev, why }.
  for (const o of out.overrides ?? []) {
    const hit = (e) => e.unit === o.unit && e.title.startsWith(o.title) && e.src !== o.src;
    if (o.drop) out.extra = out.extra.filter((e) => !hit(e));
    else out.extra.forEach((e) => { if (hit(e)) Object.assign(e, { sev: o.sev ?? e.sev, n: o.why ? `${e.n} [2. Prüfung: ${o.why}]` : e.n }); });
  }
  // `diff --stale` lists items that are new or changed in a newer Ionic
  // version; a verdict from before that version no longer counts.
  const staleFile = join(DIR, 'stale.json');
  if (existsSync(staleFile)) {
    const stale = load(staleFile);
    for (const id of stale.ids) {
      const s = out.items[id];
      if (s && !String(stale.ionicCommit).startsWith(String(s.ionicAt ?? '-'))) delete out.items[id];
    }
  }
  return out;
};

// Content fingerprint of an inventory item: what a user sees or the code
// does, without position. Logic items use the method body hashes.
const fpOf = (i) => {
  const { id, line, methods, bodies, ...rest } = i;
  const body = bodies ?? (i.kind === 'logic' ? methods?.map((m) => m.replace(/:\d+-\d+$/, '')) : undefined);
  return createHash('sha1').update(JSON.stringify({ ...rest, body })).digest('hex').slice(0, 12);
};

if (cmd === 'batches') {
  const inv = load(INVENTORY);
  const batches = makeBatches(inv);
  writeFileSync(join(DIR, 'batches.json'), `${JSON.stringify({ ionicCommit: inv.meta.ionicCommit, batches }, null, 1)}\n`);
  for (const b of batches) console.log(`${b.id.padEnd(28)} ${String(b.weight).padStart(4)}  ${b.units.length} units`);
} else if (cmd === 'slice') {
  const [batchId, out] = rest;
  const inv = load(INVENTORY);
  const { batches } = load(join(DIR, 'batches.json'));
  const b = batches.find((x) => x.id === batchId);
  if (!b) throw new Error(`unknown batch ${batchId}`);
  const units = inv.units.filter((u) => b.units.includes(u.id));
  const keys = new Set();
  const collect = (o) => {
    if (!o || typeof o !== 'object') return;
    if (Array.isArray(o.keys)) o.keys.forEach((k) => keys.add(k));
    Object.values(o).forEach(collect);
  };
  units.forEach((u) => u.items.forEach(collect));
  const i18n = Object.fromEntries([...keys].sort().map((k) => [k, inv.i18n[k]]));
  writeFileSync(out, `${JSON.stringify({ batch: b.id, ionicCommit: inv.meta.ionicCommit, units, i18n }, null, 1)}\n`);
  console.log(`${b.id}: ${units.length} units, ${units.reduce((s, u) => s + u.items.length, 0)} items, ${keys.size} keys → ${out}`);
} else if (cmd === 'todo') {
  const inv = load(INVENTORY);
  const st = readStatuses();
  const { batches } = load(join(DIR, 'batches.json'));
  for (const b of batches) {
    const ids = inv.units.filter((u) => b.units.includes(u.id)).flatMap((u) => u.items.map((i) => i.id));
    const open = ids.filter((id) => !st.items[id]);
    console.log(`${b.id.padEnd(28)} ${String(ids.length - open.length).padStart(4)}/${String(ids.length).padEnd(4)} ${open.length ? `open: ${open.slice(0, 3).join(' ')}${open.length > 3 ? ' …' : ''}` : 'done'}`);
  }
} else if (cmd === 'diff') {
  const writeStale = rest.includes('--stale');
  const [oldFile, newFile = INVENTORY] = rest.filter((x) => x !== '--stale');
  const a = load(oldFile);
  const b = load(newFile);
  const ids = (inv) => new Map(inv.units.flatMap((u) => u.items.map((i) => [i.id, { unit: u.id, i }])));
  const A = ids(a);
  const B = ids(b);
  const added = [...B.keys()].filter((k) => !A.has(k));
  const removed = [...A.keys()].filter((k) => !B.has(k));
  // same id, different content: changed texts, conditions, DB payloads, method bodies
  // Fields a newer extractor adds (e.g. bindings, bodies) are not a change: compare only keys the old item has.
  const onlyOld = (o, n) => Object.fromEntries(Object.entries(n).filter(([k]) => k in o));
  const changed = [...B.keys()].filter((k) => A.has(k) && fpOf(A.get(k).i) !== fpOf(onlyOld(A.get(k).i, B.get(k).i)));
  // translations: same key, other German text
  const i18nChanged = Object.keys(b.i18n ?? {}).filter((k) => a.i18n?.[k] && a.i18n[k].de !== b.i18n[k].de);
  console.log(`Ionic ${a.meta.ionicVersion} (${a.meta.ionicCommit}) → ${b.meta.ionicVersion} (${b.meta.ionicCommit})`);
  console.log(`added ${added.length}, removed ${removed.length}, changed ${changed.length}, texts changed ${i18nChanged.length}`);
  if (writeStale) {
    writeFileSync(join(DIR, 'stale.json'), `${JSON.stringify({ ionicCommit: b.meta.ionicCommit, from: a.meta.ionicCommit, ids: [...added, ...changed].sort() }, null, 1)}\n`);
    console.log(`stale.json: ${added.length + changed.length} items need a new verdict`);
  }
  const show = (list, M, sign) => {
    const byUnit = {};
    list.forEach((k) => { (byUnit[M.get(k).unit] ??= []).push(M.get(k).i); });
    for (const [u, items] of Object.entries(byUnit).sort()) {
      console.log(`${sign} ${u}`);
      items.forEach((i) => console.log(`   ${i.kind.padEnd(11)} ${i.file}:${i.line}  ${(i.de ?? i.header?.de ?? i.message?.de ?? []).filter(Boolean).join(' | ').slice(0, 90) || i.table || i.path || i.tag || ''}`));
    }
  };
  show(added, B, '+');
  show(removed, A, '-');
  show(changed, B, '~');
  i18nChanged.forEach((k) => console.log(`~ text ${k}: "${a.i18n[k].de}" → "${b.i18n[k].de}"`));
} else if (cmd === 'verify-slices') {
  // Second, independent pass: every hoch/mittel/missing/unclear finding, every
  // DB write, 20 % of the niedrig findings, 10 % of na and 5 % of the ok items.
  // The sample is drawn per item id (hash), so it is reproducible and does not
  // depend on which batches are finished. One file per batch: zz-verify-<batch>.
  const [outDir, perFile = '80', only] = rest;
  const inv = load(INVENTORY);
  const st = readStatuses();
  const { batches } = load(join(DIR, 'batches.json'));
  const wanted = only ? new Set(only.split(',')) : null;
  const chance = (id) => parseInt(createHash('sha1').update(`verify:${id}`).digest('hex').slice(0, 8), 16) / 0x100000000;
  const WRITE = /insert|update|upsert|delete|rpc|invoke|upload|remove|move|copy|signUp|updateUser|signOut/;
  const n = Number(perFile);
  let total = 0;
  for (const b of batches) {
    if (wanted && !wanted.has(b.id)) continue;
    const units = inv.units.filter((u) => b.units.includes(u.id));
    const ids = units.flatMap((u) => u.items.map((i) => i.id));
    if (ids.some((id) => !st.items[id])) { console.log(`${b.id}: not finished, skipped`); continue; }
    const pick = [];
    for (const u of units) {
      for (const i of u.items) {
        const s0 = st.items[i.id];
        if (s0.src?.startsWith('zz-verify')) continue;
        const r = chance(i.id);
        const write = i.kind === 'db' && WRITE.test(i.op);
        const take = write || s0.s === 'missing' || s0.s === 'unclear' || (s0.s === 'diff' && s0.sev !== 'niedrig')
          || (s0.s === 'diff' && r < 0.2) || (s0.s === 'ok' && r < 0.05) || (s0.s === 'na' && r < 0.1);
        if (take) pick.push({ unit: u.id, ionic: { ts: u.ts, html: u.html }, item: i, first: { s: s0.s, f: s0.f, n: s0.n, sev: s0.sev } });
      }
    }
    for (let k = 0; k * n < pick.length; k++) {
      const part = pick.slice(k * n, (k + 1) * n);
      const name = `zz-verify-${b.id}${k ? `-${k + 1}` : ''}`;
      writeFileSync(join(outDir, `${name}.json`), `${JSON.stringify({ batch: name, ionicCommit: inv.meta.ionicCommit, items: part }, null, 1)}\n`);
      console.log(`${name} ${part.length}`);
    }
    total += pick.length;
  }
  console.log(`${total} items to verify`);
} else if (cmd === 'verify2-slices') {
  // Round 2 (after Sol's review of round 1), one file per batch: zz-verify2-<batch>.
  // Fully, not sampled: every hoch/mittel extra finding without a second
  // verdict, every ok/na item whose visibility depends on role or tenant
  // settings, every unresolved DB call and every item without a verdict
  // (new in the inventory). Items already checked in a second pass are skipped.
  const [outDir, perFile = '40'] = rest;
  const inv = load(INVENTORY);
  const st = readStatuses();
  const { batches } = load(join(DIR, 'batches.json'));
  const ROLE = /\b(isConductor|isHelper|isAdmin|isPlayer|isViewer|isParent|isApplicant|isVoiceLeader|isResponsible|isOrganizer|isManager|isLeader|isSuperAdmin|readOnly|canEdit)\b|role|Role|tenant/;
  const verified = (s) => s?.v || s?.src?.startsWith('zz-verify');
  const unitOf = new Map(inv.units.map((u) => [u.id, u]));
  const n = Number(perFile);
  let total = 0;
  const why = {};
  for (const b of batches) {
    const pick = [];
    for (const u of inv.units.filter((x) => b.units.includes(x.id))) {
      for (const i of u.items) {
        const s0 = st.items[i.id];
        let reason = null;
        if (!s0) reason = 'neu';
        else if (verified(s0)) continue;
        else if (i.unresolved) reason = 'db-unaufgeloest';
        else if ((s0.s === 'ok' || s0.s === 'na') && ROLE.test((i.cond ?? []).join(' '))) reason = 'rolle-mandant';
        if (!reason) continue;
        why[reason] = (why[reason] ?? 0) + 1;
        pick.push({ reason, unit: u.id, ionic: { ts: u.ts, html: u.html }, item: i, first: s0 ? { s: s0.s, f: s0.f, n: s0.n, sev: s0.sev } : null });
      }
    }
    for (const e of st.extra) {
      if (!b.units.includes(e.unit) || e.v || !['hoch', 'mittel'].includes(e.sev)) continue;
      why.zusatzbefund = (why.zusatzbefund ?? 0) + 1;
      const u = unitOf.get(e.unit);
      pick.push({ reason: 'zusatzbefund', unit: e.unit, ionic: { ts: u?.ts, html: u?.html }, extra: { id: e.id, title: e.title, n: e.n, sev: e.sev, ionic: e.ionic ?? null, f: e.f ?? [] } });
    }
    for (let k = 0; k * n < pick.length; k++) {
      const part = pick.slice(k * n, (k + 1) * n);
      const name = `zz-verify2-${b.id}${k ? `-${k + 1}` : ''}`;
      writeFileSync(join(outDir, `${name}.json`), `${JSON.stringify({ batch: name, ionicCommit: inv.meta.ionicCommit, items: part }, null, 1)}\n`);
      console.log(`${name} ${part.length}`);
    }
    total += pick.length;
  }
  // native/* findings (store build, permissions, icons) belong to no page batch
  const orphan = st.extra.filter((e) => !batches.some((b) => b.units.includes(e.unit)) && !e.v && ['hoch', 'mittel'].includes(e.sev));
  if (orphan.length) {
    const part = orphan.map((e) => ({ reason: 'zusatzbefund', unit: e.unit, ionic: {}, extra: { id: e.id, title: e.title, n: e.n, sev: e.sev, ionic: e.ionic ?? null, f: e.f ?? [] } }));
    writeFileSync(join(outDir, 'zz-verify2-native.json'), `${JSON.stringify({ batch: 'zz-verify2-native', ionicCommit: inv.meta.ionicCommit, items: part }, null, 1)}\n`);
    console.log(`zz-verify2-native ${part.length}`);
    total += part.length;
    why.zusatzbefund = (why.zusatzbefund ?? 0) + part.length;
  }
  console.log(`${total} items to verify`, why);
} else if (cmd === 'report') {
  const inv = load(INVENTORY);
  const st = readStatuses();
  const rows = [];
  for (const u of inv.units) {
    for (const i of u.items) {
      const s = st.items[i.id];
      // a DB call whose table/operation the extractor could not resolve is never proven equal
      const status = i.unresolved && s?.s === 'ok' ? 'unclear' : s?.s ?? 'offen';
      rows.push({ unit: u.id, unitKind: u.kind, routes: u.routes, item: i, status, sev: s?.sev ?? null, flutter: s?.f ?? [], note: s?.n ?? '', verified: s?.v ?? null });
    }
  }
  const count = (list, key) => list.reduce((m, r) => { m[r[key]] = (m[r[key]] ?? 0) + 1; return m; }, {});
  const total = count(rows, 'status');
  const lines = [];
  lines.push('# Parität Ionic → Flutter (normales Design)', '');
  lines.push(`Ionic ${inv.meta.ionicVersion} (${inv.meta.ionicCommit}), ${inv.meta.items} Punkte in ${inv.meta.units} Bausteinen.`, '');
  lines.push('| Status | Anzahl |', '|---|---|');
  for (const [k, v] of Object.entries(total).sort()) lines.push(`| ${k} | ${v} |`);
  lines.push('', `Zusätzliche Befunde: ${st.extra.length}`, '');
  lines.push('## Offene Abweichungen nach Schwere', '');
  for (const sev of ['hoch', 'mittel', 'niedrig']) {
    const list = rows.filter((r) => (r.status === 'diff' || r.status === 'missing') && r.sev === sev);
    lines.push(`### ${sev} (${list.length})`, '');
    for (const r of list) lines.push(`- **${r.unit}** \`${r.item.kind}\` ${r.item.file}:${r.item.line} – ${r.note}`);
    const ex = st.extra.filter((e) => e.sev === sev);
    for (const e of ex) lines.push(`- **${e.unit}** zusätzlicher Befund: ${e.title} – ${e.n}`);
    lines.push('');
  }
  writeFileSync(join(DIR, 'summary.md'), `${lines.join('\n')}\n`);
  // Compact data for the tracker page (docs/parity/tracker/index.html).
  const short = (v, n) => {
    const t = Array.isArray(v) ? v.filter(Boolean).join(' · ') : (v ?? '');
    return t.length > n ? `${t.slice(0, n - 1)}…` : t;
  };
  const labelOf = (i) => {
    if (i.kind === 'route') return i.path;
    if (i.kind === 'db') return `${i.table} · ${i.op}`;
    if (i.kind === 'logic') return `${i.methods.length} Methoden`;
    if (i.kind === 'native') return `${i.plugin}.${i.call}`;
    if (i.kind === 'effect') return i.call;
    if (i.kind === 'nav') return `→ ${i.to}`;
    if (i.kind === 'embed') return `<${i.tag}>`;
    if (i.kind === 'media') return `<${i.tag}> ${i.src ?? ''}`.trim();
    if (i.kind === 'modal' && !i.inline) return i.component ?? 'Modal';
    const de = i.de?.length ? i.de : [i.header?.de, i.message?.de].flat().filter(Boolean);
    const lit = i.literals?.length ? i.literals : [];
    return short(de.length ? de : lit.length ? lit : i.bound ?? i.tag ?? i.kind, 140);
  };
  const flutterCommits = [...new Set(st.files.map((f) => f.flutter).filter(Boolean))];
  const unitIdx = new Map(inv.units.map((u, k) => [u.id, k]));
  const tracker = {
    meta: { ...inv.meta, flutterCommits, generatedAt: new Date().toISOString(), batches: st.files.map((f) => f.batch) },
    units: inv.units.map((u) => [u.id, u.kind, u.routes, family(u.id)]),
    // [id, unit, kind, file, line, label, status, sev, flutterRefs, note, cond, verified]
    rows: rows.map((r) => [r.item.id, unitIdx.get(r.unit), r.item.kind, r.item.file, r.item.line, labelOf(r.item), r.status, r.sev, r.flutter, short(r.note, 600), short(r.item.cond ?? [], 200), r.verified]),
    // [id, unit, title, note, sev, ionicRef, flutterRefs, verified]
    extra: st.extra.map((e) => [e.id, e.unit, e.title, short(e.n, 700), e.sev, e.ionic ?? null, e.f ?? [], e.v ?? null]),
  };
  // the tracker stores Leon's decisions under these ids: they must stay unique
  const docId = (id) => id.replace(/[^A-Za-z0-9_.~:@+-]/g, (c) => (c === '/' ? '~' : c === '#' ? '@' : '+'));
  const allIds = [...tracker.rows.map((r) => r[0]), ...tracker.extra.map((e) => e[0])].map(docId);
  const dupIds = allIds.filter((id, k) => allIds.indexOf(id) !== k);
  if (dupIds.length) throw new Error(`tracker ids not unique: ${dupIds.slice(0, 5).join(', ')}`);
  writeFileSync(join(DIR, 'tracker-data.json'), `${JSON.stringify(tracker)}\n`);
  console.log(total, `extra ${st.extra.length}`);
} else if (cmd === 'fixlists') {
  // One Markdown work list per fix package (docs/parity/fixes/<pkg>.md):
  // hoch/mittel gaps to fix, "Flutter besser" cases for Leon, niedrig rest.
  const inv = load(INVENTORY);
  const st = readStatuses();
  const pkgOf = (unit) => {
    const f = family(unit);
    if (unit.startsWith('native/')) return 'nativ';
    return ({ app: 'app', attendance: 'termine', overview: 'uebersicht', people: 'personen', 'teachers-instruments-duty': 'personen',
      'planning-org': 'planung', selfService: 'selbstservice', 'settings-general': 'einstellungen', 'settings-main': 'einstellungen',
      'settings-other': 'einstellungen', songs: 'werke', team: 'team', services: 'querschnitt', shared: 'querschnitt' })[f] ?? f;
  };
  const ionicUrl = (file, line) => `https://github.com/FECGSpeyer/attendance/blob/${inv.meta.ionicCommit}/src/app/${file}${line ? `#L${line}` : ''}`;
  const pk = {};
  const add = (p, k, entry) => { ((pk[p] ??= { fix: [], better: [], low: [] })[k]).push(entry); };
  for (const u of inv.units) {
    for (const i of u.items) {
      const s = st.items[i.id];
      if (!s || !['diff', 'missing'].includes(s.s)) continue;
      // a logic item only summarises; its findings are listed as extras
      if (i.kind === 'logic' && st.extra.some((x) => x.unit === u.id)) continue;
      const e = { unit: u.id, id: i.id, kind: i.kind, where: `[${i.file}:${i.line}](${ionicUrl(i.file, i.line)})`, s: s.s, sev: s.sev, f: s.f ?? [], n: s.n ?? '', v: s.v };
      const p = pkgOf(u.id);
      if (/^Flutter besser/i.test(e.n)) add(p, 'better', e);
      else if (s.sev === 'hoch' || s.sev === 'mittel') add(p, 'fix', e);
      else add(p, 'low', e);
    }
  }
  for (const x of st.extra) {
    const e = { unit: x.unit, id: x.id, title: x.title, v: x.v, kind: 'extra', where: x.ionic ? `[${x.ionic}](${ionicUrl(x.ionic.replace(/^src\/app\//, '').split(':')[0], x.ionic.split(':')[1])})` : '', s: 'diff', sev: x.sev, f: x.f ?? [], n: x.n ?? '' };
    const p = pkgOf(x.unit);
    if (/^Flutter besser/i.test(e.n) || /^Flutter besser/i.test(x.title)) add(p, 'better', e);
    else if (x.sev === 'hoch' || x.sev === 'mittel') add(p, 'fix', e);
    else add(p, 'low', e);
  }
  const out = join(DIR, 'fixes');
  if (!existsSync(out)) mkdirSync(out, { recursive: true });
  const order = { hoch: 0, mittel: 1, niedrig: 2 };
  const line = (e) => `- [ ] **${e.sev ?? '–'}** \`${e.unit}\` ${e.kind === 'extra' ? `\`${e.id}\` **${e.title}** ` : `\`${e.id.split('#')[1]}\` `}${e.where}${e.v ? ` (2. Prüfung: ${e.v})` : ''}\n  ${e.n.replace(/\n/g, ' ')}${e.f.length ? `\n  Flutter: ${e.f.join(', ')}` : ''}`;
  const index = [];
  for (const [p, l] of Object.entries(pk).sort()) {
    l.fix.sort((a, b) => order[a.sev] - order[b.sev] || a.unit.localeCompare(b.unit));
    const md = [`# Fix-Paket „${p}“`, '', `Soll: Ionic ${inv.meta.ionicVersion} (${inv.meta.ionicCommit}). Ist: Flutter ${[...new Set(st.files.map((f) => f.flutter))].join(', ')} (normales Design).`,
      'Erzeugt mit `node tool/parity/parity.mjs fixlists` aus `docs/parity/status/`. Item-IDs siehe `ionic-inventory.json`.', '',
      `## Angleichen (hoch/mittel): ${l.fix.length}`, '', ...l.fix.map(line), '',
      `## Flutter besser – Leon entscheidet: ${l.better.length}`, '', ...l.better.map(line), '',
      `## Kleinigkeiten (niedrig): ${l.low.length}`, '', ...l.low.map(line), ''];
    writeFileSync(join(out, `${p}.md`), md.join('\n'));
    const c = (sev) => l.fix.filter((e) => e.sev === sev).length;
    index.push(`${p.padEnd(14)} hoch ${String(c('hoch')).padStart(3)}  mittel ${String(c('mittel')).padStart(3)}  besser ${String(l.better.length).padStart(3)}  niedrig ${String(l.low.length).padStart(3)}`);
  }
  index.forEach((x) => console.log(x));
} else {
  console.error('usage: node tool/parity/parity.mjs batches|slice|todo|diff|verify-slices|verify2-slices|report|fixlists');
  process.exit(64);
}
