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

const readStatuses = () => {
  const out = { items: {}, extra: [], files: [] };
  if (!existsSync(STATUS_DIR)) return out;
  for (const f of readdirSync(STATUS_DIR).filter((x) => x.endsWith('.json')).sort()) {
    const s = load(join(STATUS_DIR, f));
    out.files.push({ file: f, batch: s.batch, flutter: s.flutter, ionic: s.ionic });
    // later files (e.g. verification passes "zz-verify-*") override earlier ones
    for (const [id, st] of Object.entries(s.items ?? {})) out.items[id] = { ...out.items[id], ...st, src: f };
    for (const e of s.extra ?? []) out.extra.push({ ...e, src: f });
    for (const o of s.extraOverride ?? []) (out.overrides ??= []).push({ ...o, src: f });
  }
  // A later pass can withdraw or re-rate an extra finding (duplicate of an
  // item, disproved): { unit, title (prefix), drop: true | sev, why }.
  for (const o of out.overrides ?? []) {
    const hit = (e) => e.unit === o.unit && e.title.startsWith(o.title) && e.src !== o.src;
    if (o.drop) out.extra = out.extra.filter((e) => !hit(e));
    else out.extra.forEach((e) => { if (hit(e)) Object.assign(e, { sev: o.sev ?? e.sev, n: o.why ? `${e.n} [2. Prüfung: ${o.why}]` : e.n }); });
  }
  return out;
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
  const [oldFile, newFile = INVENTORY] = rest;
  const a = load(oldFile);
  const b = load(newFile);
  const ids = (inv) => new Map(inv.units.flatMap((u) => u.items.map((i) => [i.id, { unit: u.id, i }])));
  const A = ids(a);
  const B = ids(b);
  const added = [...B.keys()].filter((k) => !A.has(k));
  const removed = [...A.keys()].filter((k) => !B.has(k));
  console.log(`Ionic ${a.meta.ionicVersion} (${a.meta.ionicCommit}) → ${b.meta.ionicVersion} (${b.meta.ionicCommit})`);
  console.log(`added ${added.length}, removed ${removed.length}`);
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
} else if (cmd === 'report') {
  const inv = load(INVENTORY);
  const st = readStatuses();
  const rows = [];
  for (const u of inv.units) {
    for (const i of u.items) {
      const s = st.items[i.id];
      rows.push({ unit: u.id, unitKind: u.kind, routes: u.routes, item: i, status: s?.s ?? 'offen', sev: s?.sev ?? null, flutter: s?.f ?? [], note: s?.n ?? '', verified: s?.v ?? null });
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
    extra: st.extra.map((e) => [e.unit, e.title, short(e.n, 700), e.sev, e.ionic ?? null, e.f ?? []]),
  };
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
    const e = { unit: x.unit, id: `extra: ${x.title}`, kind: 'extra', where: x.ionic ? `[${x.ionic}](${ionicUrl(x.ionic.replace(/^src\/app\//, '').split(':')[0], x.ionic.split(':')[1])})` : '', s: 'diff', sev: x.sev, f: x.f ?? [], n: x.n ?? '' };
    const p = pkgOf(x.unit);
    if (/^Flutter besser/i.test(e.n) || /^Flutter besser/i.test(x.title)) add(p, 'better', e);
    else if (x.sev === 'hoch' || x.sev === 'mittel') add(p, 'fix', e);
    else add(p, 'low', e);
  }
  const out = join(DIR, 'fixes');
  if (!existsSync(out)) mkdirSync(out, { recursive: true });
  const order = { hoch: 0, mittel: 1, niedrig: 2 };
  const line = (e) => `- [ ] **${e.sev ?? '–'}** \`${e.unit}\` ${e.kind === 'extra' ? '' : `\`${e.id.split('#')[1]}\` `}${e.where}${e.v ? ` (2. Prüfung: ${e.v})` : ''}\n  ${e.n.replace(/\n/g, ' ')}${e.f.length ? `\n  Flutter: ${e.f.join(', ')}` : ''}`;
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
  console.error('usage: node tool/parity/parity.mjs batches|slice|todo|diff|verify-slices|report|fixlists');
  process.exit(64);
}
