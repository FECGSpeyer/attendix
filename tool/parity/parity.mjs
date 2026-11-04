// Helpers around docs/parity/ionic-inventory.json (see docs/parity/README.md).
//
//   node tool/parity/parity.mjs batches                 → docs/parity/batches.json
//   node tool/parity/parity.mjs slice <batch> <out>     → input file for one review batch
//   node tool/parity/parity.mjs report                  → docs/parity/summary.md + tracker-data.json
//   node tool/parity/parity.mjs diff <old.json> [new]   → items added/removed by a new Ionic version
//   node tool/parity/parity.mjs todo                    → items without a status yet, per batch
import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';

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
  writeFileSync(join(DIR, 'tracker-data.json'), `${JSON.stringify({ meta: inv.meta, statusFiles: st.files, rows: rows.map((r) => ({ ...r, item: undefined, id: r.item.id, kind: r.item.kind, file: r.item.file, line: r.item.line, cond: r.item.cond, label: r.item.de ?? r.item.header?.de ?? r.item.message?.de ?? null, detail: r.item })), extra: st.extra }, null, 0)}\n`);
  console.log(total, `extra ${st.extra.length}`);
} else {
  console.error('usage: node tool/parity/parity.mjs batches|slice|todo|diff|report');
  process.exit(64);
}
