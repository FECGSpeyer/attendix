// Scenario checks for parity.mjs (points 1–4). Builds small fake parity
// directories under .tmp-parity/sc-*/docs/parity and runs the tool there.
// usage: node .tmp-parity/scenarios.mjs <path to tool/parity/parity.mjs>
import { mkdirSync, writeFileSync, readFileSync, rmSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const TOOL = resolve(process.argv[2] ?? 'tool/parity/parity.mjs');
const ROOT = resolve('.tmp-parity');
const xid = (unit, title) => `x-${createHash('sha1').update(`${unit}|${title}`).digest('hex').slice(0, 10)}`;
const U = 'p/page';
const inv = (extra = {}) => ({
  meta: { ionicVersion: '1', ionicCommit: 'c1', items: 3, units: 1 },
  units: [{ id: U, kind: 'page', ts: 'p/page.ts', html: 'p/page.html', items: [
    { kind: 'action', file: 'p/page.html', line: 1, cond: [], tag: 'ion-button', attrs: {}, events: ['(click)=go()'], id: `${U}#action-1` },
    { kind: 'text', file: 'p/page.html', line: 2, cond: [], tag: 'p', de: ['Hallo'], id: `${U}#text-2` },
    { kind: 'action', file: 'p/page.html', line: 3, cond: [], tag: 'ion-button', attrs: {}, events: ['(click)=b()'], id: `${U}#action-3` },
  ] }],
  i18n: {},
  ...extra,
});
const setup = (name, files, changes) => {
  const dir = join(ROOT, name);
  if (existsSync(dir)) rmSync(dir, { recursive: true });
  mkdirSync(join(dir, 'docs/parity/status'), { recursive: true });
  writeFileSync(join(dir, 'docs/parity/ionic-inventory.json'), JSON.stringify(inv()));
  writeFileSync(join(dir, 'docs/parity/batches.json'), JSON.stringify({ batches: [{ id: 'b01-p', units: [U] }] }));
  if (changes) writeFileSync(join(dir, 'docs/parity/changes.json'), JSON.stringify(changes));
  for (const [f, s] of Object.entries(files)) writeFileSync(join(dir, 'docs/parity/status', f), JSON.stringify(s));
  return dir;
};
const run = (dir, ...args) => {
  try { return execFileSync('node', [TOOL, ...args], { cwd: dir, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }); } catch (e) { return `ERROR ${e.stderr.split('\n').find((l) => /Error/.test(l))}`; }
};
const tracker = (dir) => { run(dir, 'report'); return JSON.parse(readFileSync(join(dir, 'docs/parity/tracker-data.json'), 'utf8')); };
const rows = (t) => Object.fromEntries(t.rows.map((r) => [r[0].split('#')[1], r[6]]));
const extras = (t) => Object.fromEntries(t.extra.map((e) => [e[2], { sev: e[4], v: e[7], stale: e[9] }]));
let fails = 0;
const check = (label, ok, got) => { console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${ok ? '' : ` → ${JSON.stringify(got)}`}`); if (!ok) fails += 1; };
const extra = (title, sev = 'hoch') => ({ unit: U, title, n: `Notiz ${title}`, sev });

// 1. re-rating / amendments and the Ionic commit of the check
{
  const changes = { base: 'c0', steps: [{ from: 'c0', to: 'c1', ids: [`${U}#action-1`] }] };
  const dir = setup('sc-1', {
    'b01-p.json': { ionic: 'c0', flutter: 'f0', items: { [`${U}#action-1`]: { s: 'ok' }, [`${U}#text-2`]: { s: 'ok' }, [`${U}#action-3`]: { s: 'ok' } }, extra: [extra('E'), extra('F'), extra('K')] },
    'zz-verify2-b01.json': { ionic: 'c1', flutter: 'f1', items: {
      [xid(U, 'E')]: { s: 'diff', sev: 'hoch', v: 'bestätigt' }, // full re-rating at c1
      [`${U}#action-1`]: { n: 'nur Notiz', v: 'bestätigt' }, // amendment at c1, verdict from c0
      [xid(U, 'F')]: { s: 'na', n: 'widerlegt', v: 'korrigiert' },
      [xid(U, 'K')]: { sev: 'mittel', v: 'bestätigt' }, // amendment of an extra at c1
    } },
    'zz-verify3-b01.json': { ionic: 'c1', flutter: 'f2', items: { [xid(U, 'F')]: { n: 'Nachtrag ohne s' } } },
  }, changes);
  const t = tracker(dir);
  const ex = extras(t);
  check('1a extra re-rated with s at c1 is not stale', ex.E && !ex.E.stale, ex.E);
  check('1b element amendment without s keeps the old Ionic commit (verdict from c0 → open)', rows(t)['action-1'] === 'offen', rows(t));
  check('1c amendment without s does not re-open a withdrawn extra', !ex.F, ex.F);
  check('1d extra amended without s keeps the commit of its definition (c0 → stale)', ex.K?.stale === 1 && ex.K.sev === 'mittel', ex.K);
  const t2 = tracker(setup('sc-1e', {
    'b01-p.json': { ionic: 'c1', flutter: 'f0', items: { [`${U}#action-1`]: { s: 'diff', sev: 'mittel', n: 'alt' } } },
    'zz-verify2-b01.json': { ionic: 'c9', flutter: 'f9', items: { [`${U}#action-1`]: { v: 'bestätigt' } } },
  }));
  check('1e amendment without s keeps flutterAt of the full verdict', t2.rows[0][12] === t2.meta.flutterCommits.indexOf('f0'), [t2.rows[0][12], t2.meta.flutterCommits]);
}

// 2. a redefinition of an extra takes no old v
{
  const dir = setup('sc-2', {
    'b01-p.json': { ionic: 'c1', flutter: 'f0', items: {}, extra: [extra('G')] },
    'zz-verify2-b01.json': { ionic: 'c1', flutter: 'f1', items: { [xid(U, 'G')]: { s: 'diff', sev: 'hoch', v: 'bestätigt' } } },
    'zz-verify3-b01.json': { ionic: 'c1', flutter: 'f2', items: {}, extra: [extra('G', 'mittel')] },
  });
  const ex = extras(tracker(dir));
  check('2 redefined extra has no old v and the new sev', ex.G && ex.G.v === null && ex.G.sev === 'mittel', ex.G);
  const out = run(dir, 'verify-round', '4', join(dir, 'out'));
  mkdirSync(join(dir, 'out'), { recursive: true });
  const out2 = run(dir, 'verify-round', '4', join(dir, 'out'));
  check('2b verify-round picks the redefined extra (mittel, no second verdict)', /zusatzbefund: 1/.test(out2), out2 || out);
}

// 3. zz-fixed: rank from afterRound, later rounds win, unchecked fixes are picked
{
  const base = {
    'b01-p.json': { ionic: 'c1', flutter: 'f0', items: { [`${U}#action-1`]: { s: 'diff', sev: 'hoch' }, [`${U}#text-2`]: { s: 'missing', sev: 'hoch' }, [`${U}#action-3`]: { s: 'diff', sev: 'mittel' } }, extra: [extra('H'), extra('J')] },
  };
  const noRound = setup('sc-3a', { ...base, 'zz-fixed-p.json': { ionic: 'c1', flutter: 'f1', items: { [`${U}#action-1`]: { s: 'ok' } } } });
  check('3a zz-fixed without afterRound is an error', /afterRound/.test(run(noRound, 'report')), run(noRound, 'report'));
  const dir = setup('sc-3b', {
    ...base,
    'zz-verify2-b01.json': { ionic: 'c1', flutter: 'f1', items: { [`${U}#action-3`]: { s: 'diff', sev: 'mittel', v: 'bestätigt' } } },
    'zz-fixed-p.json': { afterRound: 2, ionic: 'c1', flutter: 'f2', items: { [`${U}#action-1`]: { s: 'ok', n: 'PR #1' }, [`${U}#text-2`]: { s: 'ok', n: 'PR #1' }, [`${U}#action-3`]: { s: 'ok', n: 'PR #2' }, [xid(U, 'H')]: { s: 'ok', n: 'PR #1' }, [xid(U, 'J')]: { s: 'ok', n: 'PR #3' } } },
    'zz-verify3-b01.json': { ionic: 'c1', flutter: 'f3', items: { [`${U}#action-1`]: { s: 'diff', sev: 'mittel', n: 'Fix unvollständig', v: 'korrigiert' }, [`${U}#action-3`]: { v: 'bestätigt' }, [xid(U, 'J')]: { s: 'ok', v: 'bestätigt' } } },
  });
  const t = tracker(dir);
  check('3b a later round overrides zz-fixed (afterRound 2 < round 3)', rows(t)['action-1'] === 'diff', rows(t));
  mkdirSync(join(dir, 'out'), { recursive: true });
  const out = run(dir, 'verify-round', '4', join(dir, 'out'));
  const picked = JSON.parse(readFileSync(join(dir, 'out/zz-verify4-b01-p.json'), 'utf8')).items.map((p) => `${p.reason}:${p.item?.id.split('#')[1] ?? p.extra.title}`).sort();
  check('3c behoben-ungeprueft: text-2 and extra H (no round since fix); not action-1/action-3/J (round 3 looked at them)',
    JSON.stringify(picked) === JSON.stringify(['behoben-ungeprueft:H', 'behoben-ungeprueft:text-2']), { picked, out });
}

// 4. diff: field shape projected both ways, method names always compared
{
  const dir = join(ROOT, 'sc-4');
  if (existsSync(dir)) rmSync(dir, { recursive: true });
  mkdirSync(dir, { recursive: true });
  const unit = (items) => ({ meta: { ionicVersion: '1', ionicCommit: 'c1', items: items.length, units: 1 }, units: [{ id: U, kind: 'page', items }], i18n: {} });
  const old = unit([
    { kind: 'action', id: `${U}#a1`, file: 'f', line: 1, cond: [], attrs: { color: 'primary' }, legacy: 'x' },
    { kind: 'action', id: `${U}#a2`, file: 'f', line: 2, cond: [], attrs: {}, legacy: 'y' },
    { kind: 'embed', id: `${U}#e1`, file: 'f', line: 3, cond: [], tag: 'app-x', bindings: ['[editable]'] },
    { kind: 'logic', id: `${U}#l1`, file: 'f', line: 1, cond: [], methods: ['a:1-2', 'b:3-4'], bodies: { a: 'h1', b: 'h2' } },
    { kind: 'logic', id: `${U}#l2`, file: 'f', line: 1, cond: [], methods: ['a:1-2', 'b:3-4'], bodies: { a: 'h1', b: 'h2' } },
    { kind: 'logic', id: `${U}#l3`, file: 'f', line: 1, cond: [], methods: ['a:1-2'], bodies: { a: 'h1' } },
  ]);
  const neu = unit([
    { kind: 'action', id: `${U}#a1`, file: 'f', line: 9, cond: [], attrs: { color: 'primary' } }, // field legacy removed: no change
    { kind: 'action', id: `${U}#a2`, file: 'f', line: 2, cond: [], attrs: { '[disabled]': '"readOnly"' } }, // new attribute: change
    { kind: 'embed', id: `${U}#e1`, file: 'f', line: 3, cond: [], tag: 'app-x', bindings: ['[editable]'], bindingExprs: ['[editable]="isAdmin"'] }, // new field: no change
    { kind: 'logic', id: `${U}#l1`, file: 'f', line: 1, cond: [], methods: ['a:5-6', 'b:7-8', 'zNew:9-10'], bodies: { a: 'h1', b: 'h2', zNew: 'h3' } }, // new method: change
    { kind: 'logic', id: `${U}#l2`, file: 'f', line: 1, cond: [], methods: ['a:1-2'], bodies: { a: 'h1' } }, // removed method: change
    { kind: 'logic', id: `${U}#l3`, file: 'f', line: 1, cond: [], methods: ['a:3-9'], bodies: { a: 'h1' } }, // moved only: no change
  ]);
  writeFileSync(join(dir, 'old.json'), JSON.stringify(old));
  writeFileSync(join(dir, 'new.json'), JSON.stringify(neu));
  const out = run(dir, 'diff', 'old.json', 'new.json');
  const changed = out.split('\n').filter((l) => /^ {3}\w/.test(l)).map((l) => l.trim().split(/\s+/)[1]);
  check('4a diff: changed 3 (new attribute, new method, removed method)', /changed 3,/.test(out), out);
  check('4b diff: changed items are a2, l1, l2', JSON.stringify(changed.sort()) === JSON.stringify(['f:1', 'f:1', 'f:2']), changed);
  // older inventory without bodies (methods only) against one with bodies
  const oldNoBodies = unit([{ kind: 'logic', id: `${U}#l1`, file: 'f', line: 1, cond: [], methods: ['a:1-2', 'b:3-4'] }]);
  const newBodies = unit([{ kind: 'logic', id: `${U}#l1`, file: 'f', line: 1, cond: [], methods: ['a:1-2', 'b:3-4', 'c:5-6'], bodies: { a: 'h1', b: 'h2', c: 'h3' } }]);
  const sameBodies = unit([{ kind: 'logic', id: `${U}#l1`, file: 'f', line: 1, cond: [], methods: ['b:3-4', 'a:1-2'], bodies: { a: 'h1', b: 'h2' } }]);
  writeFileSync(join(dir, 'o2.json'), JSON.stringify(oldNoBodies));
  writeFileSync(join(dir, 'n2.json'), JSON.stringify(newBodies));
  writeFileSync(join(dir, 'n3.json'), JSON.stringify(sameBodies));
  check('4c methods-only vs bodies with a new method: changed', /changed 1,/.test(run(dir, 'diff', 'o2.json', 'n2.json')), run(dir, 'diff', 'o2.json', 'n2.json'));
  check('4d methods-only vs bodies with the same methods: unchanged', /changed 0,/.test(run(dir, 'diff', 'o2.json', 'n3.json')), run(dir, 'diff', 'o2.json', 'n3.json'));
}
console.log(fails ? `${fails} FAILED` : 'all passed');
process.exit(fails ? 1 : 0);
