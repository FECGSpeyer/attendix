// Compare old (git HEAD) and new summary.md ignoring the added ids.
import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
const old = execSync('git show HEAD:docs/parity/summary.md', { encoding: 'utf8', maxBuffer: 1e8 }).split('\n')
  .map((l) => l.replace(/^- \*\*([^*]+)\*\* `[a-z]+` /, '- **$1** '));
const neu = readFileSync('docs/parity/summary.md', 'utf8').split('\n')
  .map((l) => l.replace(/^- \*\*([^*]+)\*\* `[^`]+` /, '- **$1** '));
const a = new Map(); old.forEach((l) => a.set(l, (a.get(l) ?? 0) + 1));
const b = new Map(); neu.forEach((l) => b.set(l, (b.get(l) ?? 0) + 1));
for (const [l, n] of a) if ((b.get(l) ?? 0) !== n) console.log('-', n - (b.get(l) ?? 0), l.slice(0, 160));
for (const [l, n] of b) if ((a.get(l) ?? 0) !== n) console.log('+', n - (a.get(l) ?? 0), l.slice(0, 160));
console.log('old lines', old.length, 'new lines', neu.length);
const ids = readFileSync('docs/parity/summary.md', 'utf8').split('\n').filter((l) => l.startsWith('- **'));
const noId = ids.filter((l) => !/^- \*\*[^*]+\*\* `[^`]+` /.test(l));
const dup = ids.filter((l, k) => ids.indexOf(l) !== k);
console.log('item lines', ids.length, 'without id', noId.length, 'duplicate lines', dup.length);
