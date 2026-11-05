// Helpers around docs/parity/ionic-inventory.json (see docs/parity/README.md).
//
//   node tool/parity/parity.mjs batches                 → docs/parity/batches.json
//   node tool/parity/parity.mjs slice <batch> <out>     → input file for one review batch
//   node tool/parity/parity.mjs report                  → docs/parity/summary.md + tracker-data.json
//   node tool/parity/parity.mjs diff <old.json> [new]   → items added/removed by a new Ionic version
//   node tool/parity/parity.mjs todo                    → items without a status yet, per batch
//   node tool/parity/parity.mjs verify-slices <dir> [n] [b01-x,b02-y] → input files for the second pass
//   node tool/parity/parity.mjs verify-round <N> <dir> [n] [--since <old.json>] → input files for a full round
//   node tool/parity/parity.mjs fixlists            → docs/parity/fixes/<paket>.md work lists
//   verify-round and report check whether referenced Flutter files changed since
//   each verdict (--flutter <path>: Flutter checkout, default "."; --no-flutter-check)
import { readFileSync, writeFileSync, readdirSync, existsSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { ROLE_TEXT } from './roles.mjs';

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

// Ionic versions in which items changed (`diff --stale` appends a step):
// { base, steps: [{ from, to, ids }] }. A verdict made at an earlier Ionic
// commit than a step that lists its item no longer counts.
const CHANGES = join(DIR, 'changes.json');
const loadChanges = () => (existsSync(CHANGES) ? load(CHANGES) : null);
const sameCommit = (a, b) => Boolean(a && b) && (String(a).startsWith(String(b)) || String(b).startsWith(String(a)));
const stepOf = (changes, commit) => {
  if (!changes || sameCommit(commit, changes.base)) return -1;
  for (let k = changes.steps.length - 1; k >= 0; k--) if (sameCommit(commit, changes.steps[k].to)) return k;
  return -1; // unknown commit: treated as the base version
};
const changedAfter = (changes, commit) => {
  const ids = new Set();
  if (!changes) return ids;
  changes.steps.slice(stepOf(changes, commit) + 1).forEach((st) => st.ids.forEach((id) => ids.add(id)));
  return ids;
};

// Reading order of status files: first pass (b*), verification rounds
// (zz-verify-* = 1, zz-verifyN-* = N), correction files after the round named
// in their "afterRound" (N + 0.5), fixed items from fix PRs (zz-fixed-*) after
// the round named in their mandatory "afterRound" (N + 0.6: after that
// round's corrections, before round N + 1, which may judge them again).
const isFixed = (f) => f.startsWith('zz-fixed-');
const isRound = (f) => /^zz-verify\d*-/.test(f);
const rankOf = (f, s) => {
  if (isFixed(f)) {
    if (!Number.isInteger(s.afterRound)) throw new Error(`${f}: zz-fixed-* needs "afterRound": <last verification round before the fix>`);
    return s.afterRound + 0.6;
  }
  if (s.afterRound !== undefined) return s.afterRound + 0.5;
  const m = f.match(/^zz-verify(\d*)-/);
  if (m) return m[1] ? Number(m[1]) : 1;
  return 0;
};
const readStatuses = () => {
  const out = { items: {}, extra: [], extraAll: [], extraUnits: new Set(), files: [], refs: [], warnings: [] };
  if (!existsSync(STATUS_DIR)) return out;
  const files = readdirSync(STATUS_DIR).filter((x) => x.endsWith('.json')).map((f) => ({ f, s: load(join(STATUS_DIR, f)) }));
  files.forEach((x) => { x.rank = rankOf(x.f, x.s); });
  files.sort((a, b) => a.rank - b.rank || (a.f < b.f ? -1 : 1));
  const changes = loadChanges();
  const extras = new Map();
  for (const { f, s, rank } of files) {
    out.files.push({ file: f, batch: s.batch, flutter: s.flutter, ionic: s.ionic, rank });
    // 1. extra findings defined in this file: a later definition replaces the
    // earlier one completely (re-opens it, no old second verdict v)
    for (const e of s.extra ?? []) {
      const id = extraId(e);
      extras.set(id, { ...e, id, src: f, ionicAt: s.ionic, flutterAt: s.flutter, withdrawn: false });
    }
    // 2. verdicts: a new status replaces the old verdict (f and n are kept
    // only when the status itself did not change) and sets the commits the
    // check was made at; without s it only amends sev/n/f/v (commits, status
    // and a withdrawal stay as they are). A verification round touching a
    // fixed item (full verdict or amendment) counts as its check after the fix.
    for (const [id, st] of Object.entries(s.items ?? {})) {
      if (id.startsWith('x-')) {
        const e = extras.get(id);
        if (!e) { out.warnings.push(`${f}: verdict for unknown extra finding ${id}`); continue; }
        const seen = isRound(f) ? { fixed: false } : {};
        if (st.s === undefined) extras.set(id, { ...e, ...seen, sev: st.sev ?? e.sev, n: st.n ?? e.n, f: st.f ?? e.f, v: st.v ?? e.v, vsrc: st.v ? f : e.vsrc });
        else if (st.s === 'ok' || st.s === 'na') extras.set(id, { ...e, withdrawn: true, wsrc: f, wAt: s.ionic, wn: st.n ?? null, fixed: isFixed(f) });
        else extras.set(id, { ...e, withdrawn: false, sev: st.sev ?? e.sev, n: st.n ?? e.n, f: st.f ?? e.f, v: st.v, vsrc: f, ionicAt: s.ionic, flutterAt: s.flutter ?? e.flutterAt, fixed: false });
        continue;
      }
      out.refs.push([id, f]);
      const prev = out.items[id];
      if (st.s === undefined) {
        if (!prev) { out.warnings.push(`${f}: amendment without s for ${id}, which has no verdict yet (ignored)`); continue; }
        out.items[id] = { ...prev, ...st, asrc: f, ...(isRound(f) ? { fixed: false } : {}) };
      } else {
        const same = prev?.s === st.s;
        out.items[id] = { s: st.s, sev: st.sev, f: st.f ?? (same ? prev.f : undefined), n: st.n ?? (same ? prev.n : undefined), v: st.v, src: f, ionicAt: s.ionic, flutterAt: s.flutter, fixed: isFixed(f) };
      }
    }
    // 3. older form: withdraw or re-rate an extra by unit + title prefix
    for (const o of s.extraOverride ?? []) {
      for (const [id, e] of extras) {
        if (e.unit !== o.unit || !e.title.startsWith(o.title) || e.src === f) continue;
        if (o.drop) extras.set(id, { ...e, withdrawn: true, wsrc: f, wAt: s.ionic, wn: o.why ?? null });
        else extras.set(id, { ...e, sev: o.sev ?? e.sev, n: o.why ? `${e.n} [2. Prüfung: ${o.why}]` : e.n });
      }
    }
  }
  // verdicts older than a later Ionic change of their item no longer count
  if (changes) {
    for (const [id, st] of Object.entries(out.items)) if (changedAfter(changes, st.ionicAt).has(id)) delete out.items[id];
    // extras and withdrawals: their unit changed later → open again, flagged
    for (const [id, e] of extras) {
      const unitChanged = (at) => [...changedAfter(changes, at)].some((x) => x.split('#')[0] === e.unit);
      if (e.withdrawn && unitChanged(e.wAt)) extras.set(id, { ...e, withdrawn: false, stale: true });
      else if (!e.withdrawn && unitChanged(e.ionicAt)) extras.set(id, { ...e, stale: true });
    }
  }
  out.extraAll = [...extras.values()];
  out.extra = out.extraAll.filter((e) => !e.withdrawn);
  // units whose logic item only summarises: their findings are the extras
  out.extraAll.forEach((e) => out.extraUnits.add(e.unit));
  return out;
};

// Options shared by several commands: --flutter <path> (Flutter checkout,
// default this repo) and --no-flutter-check.
const optValue = (name) => (rest.includes(name) ? rest[rest.indexOf(name) + 1] : null);
const OPTS_WITH_VALUE = new Set(['--since', '--flutter']);
const positional = () => rest.filter((x, k) => !OPTS_WITH_VALUE.has(x) && !OPTS_WITH_VALUE.has(rest[k - 1]) && x !== '--no-flutter-check');

// Flutter files changed since a verdict. A verdict carries the Flutter commit
// it was made at (flutterAt, short SHA) and its Flutter references (f:
// "lib/x.dart", "lib/x.dart:12", "lib/x.dart:12-30,41"). Per commit one
// `git diff --name-status` against HEAD of the Flutter checkout (lazy, cached),
// so a check costs one process per distinct commit, not per file. A file
// counts as changed when it was modified, renamed away or deleted; a reference
// ending in "/" (directory) when anything below it changed. Unknown commits
// (not in the checkout) are reported once and never mark anything.
const refPath = (r) => String(r).trim().replace(/:\d.*$/, '');
const makeFlutterCheck = (root = '.') => {
  const byCommit = new Map();
  const warned = new Set();
  let head = null;
  let disabled = false;
  const git = (...a) => execFileSync('git', ['-C', root, ...a], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 256 * 1024 * 1024 });
  try { head = git('rev-parse', '--short', 'HEAD').trim(); } catch {
    console.warn(`warning: ${root} is no git checkout: Flutter change check skipped`);
    disabled = true;
  }
  const changedPaths = (commit) => {
    if (byCommit.has(commit)) return byCommit.get(commit);
    let paths = null;
    try {
      git('rev-parse', '--verify', '-q', `${commit}^{commit}`);
      paths = new Map();
      // -z: NUL-separated "status path [new path]"; renames mark old and new path
      const tok = git('diff', '--name-status', '-M', '-z', commit, 'HEAD', '--').split('\0');
      for (let k = 0; k < tok.length - 1;) {
        const s = tok[k][0];
        if (s === 'R' || s === 'C') {
          if (s === 'R') { paths.set(tok[k + 1], 'R'); paths.set(tok[k + 2], 'R'); }
          k += 3;
        } else {
          paths.set(tok[k + 1], s);
          k += 2;
        }
      }
    } catch {
      if (!warned.has(commit)) console.warn(`warning: Flutter commit ${commit} not found in ${root}: verdicts made at it are not checked for Flutter changes`);
      warned.add(commit);
      paths = null;
    }
    byCommit.set(commit, paths);
    return paths;
  };
  // changed reference paths (deduplicated, without line numbers) or []
  const changed = (commit, refs) => {
    if (disabled || !commit || !refs?.length) return [];
    const paths = changedPaths(commit);
    if (!paths?.size) return [];
    const out = new Set();
    for (const p of refs.map(refPath).filter(Boolean)) {
      if (paths.has(p) || (p.endsWith('/') && [...paths.keys()].some((x) => x.startsWith(p)))) out.add(p);
    }
    return [...out];
  };
  return { changed, head: () => head };
};

// Content fingerprint of an inventory item: what a user sees or the code
// does, without position; keys sorted, so the order of fields does not matter.
const stable = (v) => {
  if (Array.isArray(v)) return `[${v.map(stable).join(',')}]`;
  if (v && typeof v === 'object') return `{${Object.keys(v).filter((k) => v[k] !== undefined).sort().map((k) => `${JSON.stringify(k)}:${stable(v[k])}`).join(',')}}`;
  return JSON.stringify(v ?? null);
};
// Fields that are not compared like the others: position (id, line),
// method lists (compared separately, see fpOf) and roleGuarded, which only
// steers the selection of a round and is derived from the method body (mbody).
const OWN = new Set(['id', 'line', 'methods', 'bodies', 'roleGuarded']);
// Fields whose keys are data (attribute names, method names), not field
// names of the extractor: compared as a whole, never cut by the projection.
const DATA_MAPS = new Set(['attrs', 'bodies']);
const methodNames = (i) => (i.bodies ? Object.keys(i.bodies) : (i.methods ?? []).map((m) => m.replace(/:\d+-\d+$/, ''))).sort();
// Fingerprint of an item (projected to the fields both inventories know, so
// body hashes count only if both have `bodies`) plus, for a logic item, the
// full list of method names taken from the unprojected item: a new or removed
// method is always a change.
const fpOf = (projected, original) => {
  const rest = Object.fromEntries(Object.entries(projected).filter(([k]) => !OWN.has(k) || k === 'bodies'));
  const names = original.kind === 'logic' ? methodNames(original) : undefined;
  return createHash('sha1').update(stable({ ...rest, names })).digest('hex').slice(0, 12);
};
// Shape (field names, nested) of all items of one kind in an inventory: a
// field only one of two inventories knows (newer extractor: added; older:
// removed or renamed) is cut away on both sides before comparing.
const shapeAdd = (shape, v) => {
  if (Array.isArray(v)) { v.forEach((x) => { shape.items = shapeAdd(shape.items ?? {}, x); }); return shape; }
  if (v && typeof v === 'object') {
    shape.keys ??= {};
    for (const [k, x] of Object.entries(v)) shape.keys[k] = DATA_MAPS.has(k) ? {} : shapeAdd(shape.keys[k] ?? {}, x);
  }
  return shape;
};
const shapesOf = (M) => {
  const shapes = {};
  M.forEach(({ i }) => { shapes[i.kind] = shapeAdd(shapes[i.kind] ?? {}, Object.fromEntries(Object.entries(i).filter(([k]) => !OWN.has(k) || k === 'bodies'))); });
  return shapes;
};
const project = (v, shape) => {
  if (!shape) return v;
  if (Array.isArray(v)) return shape.items ? v.map((x) => project(x, shape.items)) : v;
  if (v && typeof v === 'object' && shape.keys) return Object.fromEntries(Object.entries(v).filter(([k]) => k in shape.keys).map(([k, x]) => [k, project(x, shape.keys[k])]));
  return v;
};

// Differences between two inventories: new, removed and changed items (same
// id, other content: texts, conditions, DB payloads, method bodies), changed
// translations and the items using them. Only fields both inventories know
// per kind are compared (each side cut to the other's shape), so fields a
// newer extractor adds, removes or renames are no change.
const diffInv = (a, b) => {
  const ids = (inv) => new Map(inv.units.flatMap((u) => u.items.map((i) => [i.id, { unit: u.id, i }])));
  const A = ids(a);
  const B = ids(b);
  const added = [...B.keys()].filter((k) => !A.has(k));
  const removed = [...A.keys()].filter((k) => !B.has(k));
  const shA = shapesOf(A);
  const shB = shapesOf(B);
  const fpIn = (i, other) => fpOf(project(i, other[i.kind]), i);
  const changed = [...B.keys()].filter((k) => A.has(k) && fpIn(A.get(k).i, shB) !== fpIn(B.get(k).i, shA));
  const i18nChanged = Object.keys(b.i18n ?? {}).filter((k) => a.i18n?.[k] && a.i18n[k].de !== b.i18n[k].de);
  const viaText = [...B.keys()].filter((k) => A.has(k) && !changed.includes(k) && i18nChanged.some((key) => JSON.stringify(B.get(k).i).includes(`"${key}"`)));
  return { A, B, added, removed, changed, i18nChanged, viaText };
};

// Top-level names under src/app (inventory files are relative to it); paths
// starting elsewhere (android/, ios/, supabase/ …) keep their own root.
const appTopOf = (inv) => [...new Set(inv.units.flatMap((u) => u.items.map((i) => i.file.split('/')[0])))].sort();
const ionicUrlOf = (inv) => {
  const top = new Set(appTopOf(inv));
  return (ref) => {
    const m = String(ref).replace(/^src\/app\//, '').match(/^(.*?)(?::(\d+)(?:-(\d+))?)?$/);
    const path = top.has(m[1].split('/')[0]) ? `src/app/${m[1]}` : m[1];
    return `https://github.com/FECGSpeyer/attendance/blob/${inv.meta.ionicCommit}/${path}${m[2] ? `#L${m[2]}${m[3] ? `-L${m[3]}` : ''}` : ''}`;
  };
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
  const { A, B, added, removed, changed, i18nChanged, viaText } = diffInv(a, b);
  console.log(`Ionic ${a.meta.ionicVersion} (${a.meta.ionicCommit}) → ${b.meta.ionicVersion} (${b.meta.ionicCommit})`);
  console.log(`added ${added.length}, removed ${removed.length}, changed ${changed.length}, texts changed ${i18nChanged.length} (${viaText.length} items)`);
  if (writeStale) {
    if (sameCommit(a.meta.ionicCommit, b.meta.ionicCommit)) console.log('same Ionic commit: nothing to record in changes.json; items changed by a newer extractor are re-checked with verify-round … --since <old.json>');
    else {
      const ledger = loadChanges() ?? { base: a.meta.ionicCommit, steps: [] };
      ledger.steps = ledger.steps.filter((st) => !(sameCommit(st.from, a.meta.ionicCommit) && sameCommit(st.to, b.meta.ionicCommit)));
      ledger.steps.push({ from: a.meta.ionicCommit, to: b.meta.ionicCommit, ids: [...new Set([...added, ...changed, ...viaText])].sort() });
      writeFileSync(CHANGES, `${JSON.stringify(ledger, null, 1)}\n`);
      console.log(`changes.json: ${ledger.steps.at(-1).ids.length} items need a new verdict`);
    }
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
} else if (cmd === 'verify-round' || cmd === 'verify2-slices') {
  // Full verification round N (after round 1's sample), one file per batch:
  // zz-verify<N>-<batch>. Not sampled: every item without a verdict (new in
  // the inventory) or changed since the inventory given with --since, every
  // hoch/mittel/missing/unclear verdict without a second check, every ok/na
  // item whose visibility or reachability depends on role or tenant settings
  // (template conditions, bound attribute expressions, role members of the
  // class, role checks in TS code, the opener of an inline modal), every
  // unresolved DB call, every item or extra fixed by a fix PR (zz-fixed-*)
  // that no round has looked at since, every hoch/mittel extra finding
  // without a second verdict and every extra whose page changed in Ionic later.
  // Last: every verdict (any status) and open extra whose referenced Flutter
  // files changed since the commit it was made at (flutter-geaendert; off with
  // --no-flutter-check). Every picked entry lists those files in flutterChanged.
  const since = optValue('--since');
  const args = positional();
  const [N, outDir, perFile = '40'] = cmd === 'verify2-slices' ? ['2', ...args] : args;
  if (!/^\d+$/.test(N ?? '') || !outDir) throw new Error('usage: verify-round <N> <outDir> [perFile] [--since <old-inventory.json>] [--flutter <path>] [--no-flutter-check]');
  if (!existsSync(outDir)) mkdirSync(outDir, { recursive: true });
  const inv = load(INVENTORY);
  const st = readStatuses();
  const fcheck = rest.includes('--no-flutter-check') ? null : makeFlutterCheck(optValue('--flutter') ?? '.');
  const flutterChangedOf = (at, refs) => (fcheck ? fcheck.changed(at, refs) : []);
  let fcOther = 0;
  const { batches } = load(join(DIR, 'batches.json'));
  const recheck = new Set();
  if (since) { const d = diffInv(load(since), inv); [...d.changed, ...d.viaText].forEach((id) => recheck.add(id)); }
  // role and tenant-setting names (template conditions, bound attributes),
  // plus everything the extractor counts as role code (ROLE_TEXT); class
  // members that read role or tenant data come from the inventory
  // (unit.roleMembers)
  const ROLE = /\b(isConductor|isHelper|isAdmin|isPlayer|isViewer|isParent|isApplicant|isVoiceLeader|isResponsible|isOrganizer|isManager|isLeader|isTeamLeader|isSuperAdmin|isGeneral|isChoir|isOrchestra|isDemo|isMainGroup|isLoggedIn|hasOrg|readOnly|editableByPlayers|organisation|can[A-Z]\w*|enable_\w+|manage[A-Z]\w*|show(Planning|Team|Beamer|GemeindeApp|Landing))\b|role|Role|tenant|Tenant|permission/;
  const isRoleText = (t) => ROLE.test(t) || ROLE_TEXT.test(t);
  const identsOf = (txt) => new Set(String(txt).match(/[A-Za-z_]\w*/g) ?? []);
  const unitOf = new Map(inv.units.map((u) => [u.id, u]));
  const n = Number(perFile);
  let total = 0;
  let viaOpener = 0;
  const why = {};
  // expressions of bound attributes ([disabled]="readOnly", [isOpen]=…,
  // inputs of embedded components): the part after "=", string literals
  // (translation keys such as 'settings.roles') removed
  const exprOf = (b) => String(b).replace(/^[^=]*=\s*/, '').replace(/^"|"$/g, '').replace(/'(?:[^'\\]|\\.)*'|`(?:[^`\\]|\\.)*`/g, "''");
  const boundExprs = (i) => [
    ...Object.entries(i.attrs ?? {}).filter(([k]) => k.startsWith('[')).map(([, v]) => exprOf(v)),
    ...[...(i.bindings ?? []), ...(i.bindingExprs ?? [])].filter((b) => /^\[[^\]]+\]\s*=/.test(String(b))).map(exprOf),
  ];
  const directlyRoleDependent = (u, i) => {
    const cond = (i.cond ?? []).join(' ');
    const bound = boundExprs(i).join(' ');
    if (isRoleText(cond) || isRoleText(bound)) return true;
    if (i.roleGuarded) return true;
    const members = new Set(u.roleMembers ?? []);
    return [...identsOf(`${cond} ${bound}`)].some((x) => members.has(x));
  };
  const inherited = new Set();
  // Inline modals/popovers inherit the role dependence of what opens them:
  // an element setting their [isOpen] flag to true, their trigger id or a
  // call of <ref>.present(). Their contents carry "in <ion-modal …>" in cond.
  const roleItemsOf = (u) => {
    const set = new Set(u.items.filter((i) => directlyRoleDependent(u, i)).map((i) => i.id));
    const modals = u.items.filter((i) => i.inline && (i.kind === 'modal' || i.kind === 'popover')).map((m) => {
      const a = m.attrs ?? {};
      const flag = a['[isOpen]'] && /^"?\s*([A-Za-z_$][\w$]*)\s*"?$/.exec(a['[isOpen]'])?.[1];
      const trigger = a.trigger ?? null;
      const ref = a['#'] ?? null;
      if (!flag && !trigger && !ref) return null;
      const marker = `in <${m.tag}${trigger ? ` trigger=${trigger}` : ''}${a['[isOpen]'] ? ` isOpen=${a['[isOpen]']}` : ''}${ref ? ` #${ref}` : ''}>`;
      const opens = (i) => i.id !== m.id && (
        (flag && (i.events ?? []).some((e) => new RegExp(`\\b${flag}\\s*=\\s*true\\b`).test(e)))
        || (trigger && i.attrs?.id === trigger)
        || (ref && ref.split(',').some((r) => (i.events ?? []).some((e) => new RegExp(`\\b${r}\\.present\\(`).test(e)))));
      return { m, marker, opens };
    }).filter(Boolean);
    for (let changed = true; changed;) {
      changed = false;
      for (const { m, marker, opens } of modals) {
        if (set.has(m.id) && u.items.every((i) => !(i.cond ?? []).includes(marker) || set.has(i.id))) continue;
        if (!u.items.some((i) => set.has(i.id) && opens(i))) continue;
        for (const i of u.items) {
          if ((i.id === m.id || (i.cond ?? []).includes(marker)) && !set.has(i.id)) { set.add(i.id); inherited.add(i.id); changed = true; }
        }
      }
    }
    return set;
  };
  const roleItems = new Set(inv.units.flatMap((u) => [...roleItemsOf(u)]));
  const extraEntry = (e, reason, changed) => {
    const u = unitOf.get(e.unit);
    return { reason, unit: e.unit, ionic: { ts: u?.ts, html: u?.html }, extra: { id: e.id, title: e.title, n: e.n, sev: e.sev, ionic: e.ionic ?? null, f: e.f ?? [], stale: e.stale ?? false }, ...(e.fixed ? { fix: { src: e.wsrc, n: e.wn } } : {}), ...(changed.length ? { flutterChanged: changed } : {}) };
  };
  // withdrawn extras only come back when a fix PR withdrew them (not yet
  // re-checked); open extras also when their Flutter files changed since
  const extraPick = (e) => {
    const changed = e.withdrawn ? [] : flutterChangedOf(e.flutterAt, e.f);
    const reason = e.withdrawn ? (e.fixed ? 'behoben-ungeprueft' : null)
      : e.stale ? 'zusatzbefund-ionic-geaendert' : !e.v && ['hoch', 'mittel'].includes(e.sev) ? 'zusatzbefund' : changed.length ? 'flutter-geaendert' : null;
    return reason ? { reason, changed } : null;
  };
  const count = (reason, changed) => {
    why[reason] = (why[reason] ?? 0) + 1;
    if (changed.length && reason !== 'flutter-geaendert') fcOther += 1;
  };
  const write = (name, part) => {
    writeFileSync(join(outDir, `${name}.json`), `${JSON.stringify({ batch: name, ionicCommit: inv.meta.ionicCommit, items: part }, null, 1)}\n`);
    console.log(`${name} ${part.length}`);
  };
  for (const b of batches) {
    const pick = [];
    for (const u of inv.units.filter((x) => b.units.includes(x.id))) {
      for (const i of u.items) {
        const s0 = st.items[i.id];
        const changed = s0 ? flutterChangedOf(s0.flutterAt, s0.f) : [];
        let reason = null;
        if (!s0) reason = 'neu';
        else if (recheck.has(i.id)) reason = 'geaendert';
        else if (s0.fixed) reason = 'behoben-ungeprueft';
        else if (s0.v || s0.src?.startsWith('zz-fixed-')) reason = null; // checked twice: only a Flutter change re-opens it
        else if (i.unresolved) reason = 'db-unaufgeloest';
        else if (s0.s === 'missing' || s0.s === 'unclear' || (s0.s === 'diff' && s0.sev !== 'niedrig')) reason = 'abweichung-ungeprueft';
        else if ((s0.s === 'ok' || s0.s === 'na') && roleItems.has(i.id)) reason = 'rolle-mandant';
        if (!reason && changed.length) reason = 'flutter-geaendert';
        if (!reason) continue;
        count(reason, changed);
        // via: the role dependence comes from the element opening the modal/popover
        const via = reason === 'rolle-mandant' && inherited.has(i.id) ? { via: 'ausloeser' } : {};
        if (via.via) viaOpener += 1;
        pick.push({ reason, ...via, unit: u.id, ionic: { ts: u.ts, html: u.html }, item: i, first: s0 ? { s: s0.s, f: s0.f, n: s0.n, sev: s0.sev, v: s0.v ?? null, src: s0.fixed ? s0.src : undefined, flutterAt: s0.flutterAt ?? null } : null, ...(changed.length ? { flutterChanged: changed } : {}) });
      }
    }
    for (const e of st.extraAll) {
      const p = b.units.includes(e.unit) && extraPick(e);
      if (!p) continue;
      count(p.reason, p.changed);
      pick.push(extraEntry(e, p.reason, p.changed));
    }
    for (let k = 0; k * n < pick.length; k++) write(`zz-verify${N}-${b.id}${k ? `-${k + 1}` : ''}`, pick.slice(k * n, (k + 1) * n));
    total += pick.length;
  }
  // native/* findings (store build, permissions, icons) belong to no page batch
  const orphan = st.extraAll.filter((e) => !batches.some((b) => b.units.includes(e.unit))).map((e) => [e, extraPick(e)]).filter(([, p]) => p);
  if (orphan.length) {
    orphan.forEach(([, p]) => count(p.reason, p.changed));
    // native findings can be many: split like the page batches
    const all = orphan.map(([e, p]) => extraEntry(e, p.reason, p.changed));
    for (let k = 0; k * n < all.length; k++) write(`zz-verify${N}-native${k ? `-${k + 1}` : ''}`, all.slice(k * n, (k + 1) * n));
    total += orphan.length;
  }
  const notes = [
    viaOpener ? `rolle-mandant über Modal-Auslöser: ${viaOpener}` : '',
    fcOther ? `Flutter seit Urteil geändert, anderer Grund behalten: ${fcOther}` : '',
    fcheck ? `Flutter-Stand: ${fcheck.head() ?? '?'}` : 'Flutter-Prüfung aus',
  ].filter(Boolean);
  console.log(`${total} items to verify`, why, `(${notes.join('; ')})`);
} else if (cmd === 'report') {
  const inv = load(INVENTORY);
  const st = readStatuses();
  const rows = [];
  for (const u of inv.units) {
    for (const i of u.items) {
      const s = st.items[i.id];
      // a DB call whose table/operation the extractor could not resolve is never proven equal
      const status = i.unresolved && s?.s === 'ok' ? 'unclear' : s?.s ?? 'offen';
      // a logic item only summarises when the page's findings are listed as extras
      const summary = i.kind === 'logic' && st.extraUnits.has(u.id);
      rows.push({ unit: u.id, unitKind: u.kind, routes: u.routes, item: i, status, summary, sev: s?.sev ?? null, flutter: s?.f ?? [], note: s?.n ?? '', verified: s?.v ?? null, flutterAt: s?.flutterAt ?? null });
    }
  }
  // verdicts whose referenced Flutter files changed since (see makeFlutterCheck)
  const fcheck = rest.includes('--no-flutter-check') ? null : makeFlutterCheck(optValue('--flutter') ?? '.');
  rows.forEach((r) => { r.fchanged = r.status !== 'offen' && fcheck ? fcheck.changed(r.flutterAt, r.flutter).length > 0 : false; });
  const fchangedExtra = new Set(fcheck ? st.extra.filter((e) => fcheck.changed(e.flutterAt, e.f).length).map((e) => e.id) : []);
  // verdicts for ids the inventory does not know (removed or mistyped)
  const invIds = new Set(inv.units.flatMap((u) => u.items.map((i) => i.id)));
  const orphans = st.refs.filter(([id]) => !invIds.has(id));
  for (const [id, f] of orphans) console.warn(`warning: ${f}: verdict for ${id}, which is not in the inventory`);
  for (const w of st.warnings) console.warn(`warning: ${w}`);
  // a logic item that only summarises (its findings are extras) with diff or
  // missing is counted in a row of its own, not under diff/missing
  const SUMMARY = 'zusammenfassend';
  rows.forEach((r) => { r.tableStatus = r.summary && (r.status === 'diff' || r.status === 'missing') ? SUMMARY : r.status; });
  const count = (list, key) => list.reduce((m, r) => { m[r[key]] = (m[r[key]] ?? 0) + 1; return m; }, {});
  const total = count(rows, 'tableStatus');
  const lines = [];
  lines.push('# Parität Ionic → Flutter (normales Design)', '');
  lines.push(`Ionic ${inv.meta.ionicVersion} (${inv.meta.ionicCommit}), ${inv.meta.items} Punkte in ${inv.meta.units} Bausteinen.`, '');
  if (fcheck) {
    // "Abweichungen": diff/missing items and open extra findings
    const fc = rows.filter((r) => r.fchanged);
    const fcOk = fc.filter((r) => r.status === 'ok').length;
    const fcGap = fc.filter((r) => r.status === 'diff' || r.status === 'missing').length + fchangedExtra.size;
    lines.push(`Flutter seit Urteil geändert: ${fc.length + fchangedExtra.size} Punkte (davon ok ${fcOk}, Abweichungen ${fcGap}), verglichen mit HEAD ${fcheck.head() ?? '?'}.`, '');
  }
  lines.push('| Status | Anzahl |', '|---|---|');
  for (const [k, v] of Object.entries(total).sort()) lines.push(`| ${k} | ${v} |`);
  if (total[SUMMARY]) lines.push('', `\`${SUMMARY}\`: Logik-Einträge mit diff/missing, deren Befunde einzeln als Zusatzbefunde stehen (nicht unter diff/missing gezählt).`);
  lines.push('', `Zusätzliche Befunde: ${st.extra.length}${st.extra.some((e) => e.stale) ? ` (davon ${st.extra.filter((e) => e.stale).length} auf seither geänderten Ionic-Seiten)` : ''}`);
  lines.push('', '## Offene Abweichungen nach Schwere', '');
  for (const sev of ['hoch', 'mittel', 'niedrig']) {
    const list = rows.filter((r) => (r.status === 'diff' || r.status === 'missing') && r.sev === sev && !r.summary);
    const ex = st.extra.filter((e) => e.sev === sev);
    lines.push(`### ${sev} (${list.length + ex.length})`, '');
    for (const r of list) lines.push(`- **${r.unit}** \`${r.item.id.split('#')[1]}\` ${r.item.file}:${r.item.line} – ${r.note}`);
    for (const e of ex) lines.push(`- **${e.unit}** \`${e.id}\` zusätzlicher Befund${e.stale ? ' (Ionic-Seite seither geändert)' : ''}: ${e.title} – ${e.n}`);
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
  // newest first: index 0 is the default for links without a known commit
  const flutterCommits = [...new Set(st.files.map((f) => f.flutter).filter(Boolean).reverse())];
  const fcOf = (sha) => (sha && flutterCommits.includes(sha) ? flutterCommits.indexOf(sha) : null);
  const unitIdx = new Map(inv.units.map((u, k) => [u.id, k]));
  const tracker = {
    meta: { ...inv.meta, flutterCommits, appTop: appTopOf(inv), generatedAt: new Date().toISOString(), batches: st.files.map((f) => f.batch) },
    units: inv.units.map((u) => [u.id, u.kind, u.routes, family(u.id)]),
    summaryUnits: [...st.extraUnits].sort(),
    // [id, unit, kind, file, line, label, status, sev, flutterRefs, note, cond, verified, flutterCommitIdx, flutterChanged]
    rows: rows.map((r) => [r.item.id, unitIdx.get(r.unit), r.item.kind, r.item.file, r.item.line, labelOf(r.item), r.status, r.sev, r.flutter, short(r.note, 600), short(r.item.cond ?? [], 200), r.verified, fcOf(r.flutterAt), r.fchanged ? 1 : 0]),
    // [id, unit, title, note, sev, ionicRef, flutterRefs, verified, flutterCommitIdx, stale, flutterChanged]
    extra: st.extra.map((e) => [e.id, e.unit, e.title, short(e.n, 700), e.sev, e.ionic ?? null, e.f ?? [], e.v ?? null, fcOf(e.flutterAt), e.stale ? 1 : 0, fchangedExtra.has(e.id) ? 1 : 0]),
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
  const ionicUrl = ionicUrlOf(inv);
  const pk = {};
  const add = (p, k, entry) => { ((pk[p] ??= { fix: [], better: [], low: [] })[k]).push(entry); };
  for (const u of inv.units) {
    for (const i of u.items) {
      const s = st.items[i.id];
      if (!s || !['diff', 'missing'].includes(s.s)) continue;
      // a logic item only summarises; its findings are listed as extras
      if (i.kind === 'logic' && st.extraUnits.has(u.id)) continue;
      const e = { unit: u.id, id: i.id, kind: i.kind, where: `[${i.file}:${i.line}](${ionicUrl(`${i.file}:${i.line}`)})`, s: s.s, sev: s.sev, f: s.f ?? [], n: s.n ?? '', v: s.v };
      const p = pkgOf(u.id);
      if (/^Flutter besser/i.test(e.n)) add(p, 'better', e);
      else if (s.sev === 'hoch' || s.sev === 'mittel') add(p, 'fix', e);
      else add(p, 'low', e);
    }
  }
  for (const x of st.extra) {
    const e = { unit: x.unit, id: x.id, title: x.title, v: x.v, stale: x.stale, kind: 'extra', where: x.ionic ? `[${x.ionic}](${ionicUrl(x.ionic)})` : '', s: 'diff', sev: x.sev, f: x.f ?? [], n: x.n ?? '' };
    const p = pkgOf(x.unit);
    if (/^Flutter besser/i.test(e.n) || /^Flutter besser/i.test(x.title)) add(p, 'better', e);
    else if (x.sev === 'hoch' || x.sev === 'mittel') add(p, 'fix', e);
    else add(p, 'low', e);
  }
  const out = join(DIR, 'fixes');
  if (!existsSync(out)) mkdirSync(out, { recursive: true });
  const order = { hoch: 0, mittel: 1, niedrig: 2 };
  const line = (e) => `- [ ] **${e.sev ?? '–'}** \`${e.unit}\` ${e.kind === 'extra' ? `\`${e.id}\` **${e.title}** ` : `\`${e.id.split('#')[1]}\` `}${e.where}${e.v ? ` (2. Prüfung: ${e.v})` : ''}${e.stale ? ' (Ionic-Seite seither geändert)' : ''}\n  ${e.n.replace(/\n/g, ' ')}${e.f.length ? `\n  Flutter: ${e.f.join(', ')}` : ''}`;
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
  console.error('usage: node tool/parity/parity.mjs batches|slice|todo|diff <old> [new] [--stale]|verify-slices|verify-round <N> <dir> [n] [--since <old>] [--flutter <path>] [--no-flutter-check]|report [--flutter <path>] [--no-flutter-check]|fixlists');
  process.exit(64);
}
