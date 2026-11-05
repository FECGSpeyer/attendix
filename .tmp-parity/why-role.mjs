// Show what made the rolle-mandant picks of a verify-round output role dependent.
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
const dir = process.argv[2];
const picks = readdirSync(dir).flatMap((f) => JSON.parse(readFileSync(join(dir, f), 'utf8')).items).filter((p) => p.reason === 'rolle-mandant');
const exprOf = (b) => String(b).replace(/^[^=]*=\s*/, '').replace(/^"|"$/g, '').replace(/'(?:[^'\\]|\\.)*'|`(?:[^`\\]|\\.)*`/g, "''");
const tally = {};
for (const p of picks) {
  const i = p.item;
  const bound = [...Object.entries(i.attrs ?? {}).filter(([k]) => k.startsWith('[')).map(([k, v]) => `${k}=${exprOf(v)}`),
    ...(i.bindings ?? []).filter((b) => /^\[[^\]]+\]\s*=/.test(b))];
  const key = p.via ? 'via-modal' : i.roleGuarded ? 'roleGuarded' : 'cond/bound';
  tally[key] = (tally[key] ?? 0) + 1;
  console.log(key.padEnd(12), i.id, '| cond:', (i.cond ?? []).join(' ; ').slice(0, 110), '| bound:', bound.join(' ; ').slice(0, 110));
}
console.log(tally);
