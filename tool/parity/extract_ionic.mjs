// Builds the parity "Soll-Liste": every user-visible element and every
// backend access of the Ionic app (FECGSpeyer/attendance), extracted from
// the source code instead of from anyone's memory of it.
//
//   cd tool/parity && npm ci
//   node tool/parity/extract_ionic.mjs <ionic-repo> [--out docs/parity/ionic-inventory.json]
//
// What is extracted (one item each, with a stable id):
//   route        every path of the Angular router (incl. guards, redirects)
//   action       template elements a user can trigger: (event) bindings,
//                routerLink, href (buttons, items, tabs, fab, sliding options …)
//   field        form controls (ion-input/select/toggle/checkbox/segment/…),
//                incl. their options
//   text         remaining translated or literal texts (titles, labels, notes)
//   embed        app-* child components used by a template
//   alert, actionsheet, modal, popover, toast, loading
//                dialogs created in TypeScript, with header/message/buttons
//   nav          router.navigate / navCtrl calls
//   db           supabase .from(table).<op>, .rpc(), functions.invoke(),
//                storage.from(bucket).<op>
//   native       Capacitor plugin calls (Haptics, Share, Browser, Push, …)
//   effect       downloads, file opening, printing, clipboard, window.open
//
// Every item keeps its visibility conditions (@if/*ngIf/@for/@switch around
// it) so role-dependent UI is visible, the German text of every i18n key and
// the matching Flutter ARB key (same mapping as tool/i18n/build_arb.dart).
// With --flutter <repo> each i18n key also lists where the normal (non-Beta)
// Flutter code uses it – a starting point for the mapping, not a verdict.
import { readFileSync, writeFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, relative, dirname, resolve, basename } from 'node:path';
import { execSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import ts from 'typescript';
import * as ng from '@angular/compiler';

// ---------------------------------------------------------------- args
const args = process.argv.slice(2);
const ionicRoot = args.find((a) => !a.startsWith('--'));
const opt = (name, def) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : def;
};
if (!ionicRoot) {
  console.error('usage: node tool/parity/extract_ionic.mjs <ionic-repo> [--out file] [--flutter repo]');
  process.exit(64);
}
const outFile = opt('--out', 'docs/parity/ionic-inventory.json');
const flutterRoot = opt('--flutter', null);
const appDir = join(ionicRoot, 'src/app');

// ---------------------------------------------------------------- helpers
const walk = (dir, out = []) => {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    const st = statSync(p);
    if (st.isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
};
const rel = (p) => relative(appDir, p).replaceAll('\\', '/');
const hash = (s) => createHash('sha1').update(s).digest('hex').slice(0, 8);
const squash = (s) => (s ?? '').replace(/\s+/g, ' ').trim();
const clip = (s, n = 160) => {
  s = squash(s);
  return s.length > n ? `${s.slice(0, n - 1)}…` : s;
};
const lineOf = (text, offset) => text.slice(0, offset).split('\n').length;
const uniq = (a) => [...new Set(a)];

// i18n ---------------------------------------------------------------
const flatten = (obj, prefix = '', out = {}) => {
  for (const [k, v] of Object.entries(obj)) {
    const key = prefix ? `${prefix}.${k}` : k;
    if (v && typeof v === 'object') flatten(v, key, out);
    else out[key] = String(v);
  }
  return out;
};
const de = flatten(JSON.parse(readFileSync(join(ionicRoot, 'src/i18n/de.json'), 'utf8')));
// Same mapping as tool/i18n/build_arb.dart toArbKey().
const toArbKey = (key) => {
  const parts = key.split(/[._-]/).filter(Boolean);
  return parts
    .map((p, i) => (i === 0 ? p[0].toLowerCase() + p.slice(1) : p[0].toUpperCase() + p.slice(1)))
    .join('');
};
const KEY_RE = /['"`]([A-Za-z][\w-]*(?:\.[\w-]+)+)['"`]/g;
// Keys inside translate('…') / t('…') calls or piped through transloco.
const keysIn = (text) => {
  const out = [];
  for (const m of text.matchAll(/(?:translate|\bt|selectTranslate)\(\s*['"`]([\w.-]+)['"`]/g)) out.push(m[1]);
  for (const m of text.matchAll(/['"`]([\w.-]+)['"`]\s*\|\s*transloco/g)) out.push(m[1]);
  // Keys selected via ternaries etc. inside a transloco expression:
  // (cond ? 'a.b' : 'c.d') | transloco
  for (const m of text.matchAll(/\(([^()]*)\)\s*\|\s*transloco/g)) {
    for (const k of m[1].matchAll(KEY_RE)) out.push(k[1]);
  }
  return uniq(out.filter((k) => k in de || k.includes('.')));
};
const literalsIn = (raw) => {
  // German/English UI literals that are not i18n keys, not code-ish.
  const text = raw
    .replace(/(['"`])[\w.-]+\1\s*\|\s*transloco(\s*:\s*\{[^}]*\})?/g, ' ')
    .replace(/\([^()]*\)\s*\|\s*transloco/g, ' ');
  const out = [];
  for (const m of text.matchAll(/(['"`])((?:(?!\1)[^\\]|\\.)*)\1/g)) {
    const s = m[2];
    if (!/[A-Za-zÄÖÜäöüß]{2}/.test(s)) continue;
    if (/^[\w.-]+$/.test(s) && (s in de || s.includes('.') || /^[a-z]/.test(s))) continue; // keys, identifiers
    if (/^(cancel|destructive|confirm|danger|primary|secondary|success|warning|medium|light|dark|tertiary)$/.test(s)) continue;
    if (/^[a-z-]+(-outline|-sharp)?$/.test(s)) continue; // icon names, css classes
    if (/[{}<>;=]|=>|\$\{/.test(s) && !/\s/.test(s)) continue;
    out.push(s);
  }
  return uniq(out).slice(0, 12);
};
const label = (text) => {
  const keys = keysIn(text);
  return {
    keys,
    de: keys.map((k) => de[k] ?? null),
    literals: literalsIn(text.replace(/(?:translate|\bt)\(\s*['"`][\w.-]+['"`]/g, '')),
  };
};

// ---------------------------------------------------------------- files
const allFiles = walk(appDir);
const tsFiles = allFiles.filter((f) => f.endsWith('.ts') && !f.endsWith('.spec.ts'));
const htmlFiles = new Set(allFiles.filter((f) => f.endsWith('.html')));

const units = new Map(); // unitId -> unit
const unitFor = (file, kind) => {
  const id = rel(file).replace(/\.(ts|html)$/, '');
  if (!units.has(id)) {
    units.set(id, { id, kind, ts: null, html: null, selector: null, className: null, routes: [], items: [] });
  }
  const u = units.get(id);
  if (kind && (!u.kind || u.kind === 'file')) u.kind = kind;
  return u;
};
const counters = new Map();
const addItem = (unit, item) => {
  const sig = `${unit.id}|${item.kind}|${item.sig ?? ''}`;
  const n = (counters.get(sig) ?? 0) + 1;
  counters.set(sig, n);
  item.id = `${unit.id}#${item.kind}-${hash(sig)}${n > 1 ? `-${n}` : ''}`;
  delete item.sig;
  unit.items.push(item);
};

// ---------------------------------------------------------------- TypeScript
const sourceFiles = new Map();
const parseTs = (file) => {
  if (!sourceFiles.has(file)) {
    sourceFiles.set(file, ts.createSourceFile(file, readFileSync(file, 'utf8'), ts.ScriptTarget.Latest, true));
  }
  return sourceFiles.get(file);
};
const nodeText = (sf, n) => n.getText(sf);
const enclosingMethod = (node) => {
  let n = node;
  let methodName = null;
  while (n) {
    if (!methodName) {
      if (ts.isMethodDeclaration(n) || ts.isGetAccessor(n) || ts.isSetAccessor(n)) methodName = n.name?.getText();
      else if (ts.isConstructorDeclaration(n)) methodName = 'constructor';
      else if (ts.isPropertyDeclaration(n) && n.initializer) methodName = n.name?.getText();
      else if (ts.isFunctionDeclaration(n)) methodName = n.name?.getText();
    }
    if (ts.isClassDeclaration(n)) return `${n.name?.getText() ?? '?'}.${methodName ?? '?'}`;
    n = n.parent;
  }
  return methodName ?? '?';
};
const objProps = (sf, obj) => {
  const out = {};
  if (!obj || !ts.isObjectLiteralExpression(obj)) return out;
  for (const p of obj.properties) {
    if (ts.isPropertyAssignment(p) || ts.isShorthandPropertyAssignment(p)) {
      out[p.name.getText(sf).replace(/['"]/g, '')] = ts.isPropertyAssignment(p) ? p.initializer : p.name;
    }
  }
  return out;
};
const textField = (sf, node) => (node ? { ...label(nodeText(sf, node)), expr: clip(nodeText(sf, node), 200) } : null);
const buttonsOf = (sf, arr) => {
  if (!arr) return [];
  if (!ts.isArrayLiteralExpression(arr)) return [{ expr: clip(nodeText(sf, arr), 120), ...label(nodeText(sf, arr)) }];
  return arr.elements.map((el) => {
    if (ts.isObjectLiteralExpression(el)) {
      const p = objProps(sf, el);
      return {
        text: p.text ? textField(sf, p.text) : null,
        role: p.role ? nodeText(sf, p.role).replace(/['"]/g, '') : null,
        icon: p.icon ? nodeText(sf, p.icon).replace(/['"]/g, '') : null,
        cssClass: p.cssClass ? clip(nodeText(sf, p.cssClass), 60) : null,
        type: p.type ? nodeText(sf, p.type).replace(/['"]/g, '') : null,
        label: p.label ? textField(sf, p.label) : null,
        name: p.name ? clip(nodeText(sf, p.name), 60) : null,
        placeholder: p.placeholder ? textField(sf, p.placeholder) : null,
        value: p.value ? clip(nodeText(sf, p.value), 60) : null,
        checked: p.checked ? clip(nodeText(sf, p.checked), 60) : null,
        handler: p.handler ? clip(nodeText(sf, p.handler), 240) : null,
      };
    }
    return { expr: clip(nodeText(sf, el), 120), ...label(nodeText(sf, el)) };
  });
};
const conditionsTs = (sf, node) => {
  // if-conditions around a call, innermost first (max 4).
  const out = [];
  let n = node.parent;
  while (n && out.length < 4 && !ts.isClassDeclaration(n)) {
    if (ts.isIfStatement(n) && !nodeText(sf, n.expression).includes('\n')) {
      const inElse = n.elseStatement && node.pos >= n.elseStatement.pos && node.end <= n.elseStatement.end;
      out.push(`${inElse ? '!' : ''}(${clip(nodeText(sf, n.expression), 120)})`);
    }
    if (ts.isConditionalExpression(n)) out.push(`?(${clip(nodeText(sf, n.condition), 120)})`);
    if (ts.isMethodDeclaration(n) || ts.isFunctionDeclaration(n)) break;
    n = n.parent;
  }
  return out;
};

const NATIVE = [
  'Haptics', 'Share', 'Browser', 'Camera', 'Filesystem', 'PushNotifications', 'LocalNotifications',
  'Clipboard', 'App', 'Preferences', 'StatusBar', 'Keyboard', 'SplashScreen', 'Badge', 'Device',
  'Network', 'LiveActivity', 'LiveActivities', 'FileOpener', 'Printer', 'BarcodeScanner',
  'CapacitorBarcodeScanner', 'Capacitor', 'CapacitorHttp', 'FirebaseMessaging', 'ScreenOrientation',
  'TextZoom', 'Dialog', 'Toast', 'Geolocation', 'Contacts', 'Calendar', 'InAppBrowser', 'NativeSettings',
  'AppLauncher', 'SafeArea', 'EdgeToEdge', 'SignInWithApple', 'GoogleAuth', 'Sentry', 'LiveUpdate',
  'CapacitorUpdater', 'Widget', 'WidgetsBridge', 'AppReview', 'RateApp', 'PlatformInfo', 'FilePicker',
  'Media', 'NativeAudio', 'VoiceRecorder', 'SpeechRecognition', 'Motion', 'Toast',
];
const DB_OPS = new Set(['select', 'insert', 'update', 'upsert', 'delete']);
const FILTERS = new Set(['eq', 'neq', 'gt', 'gte', 'lt', 'lte', 'in', 'is', 'not', 'or', 'match', 'like', 'ilike', 'contains', 'containedBy', 'overlaps', 'filter', 'textSearch', 'order', 'limit', 'range', 'single', 'maybeSingle', 'csv']);
const STORAGE_OPS = new Set(['upload', 'remove', 'download', 'getPublicUrl', 'createSignedUrl', 'createSignedUrls', 'list', 'move', 'copy', 'update']);

// Walks up a call chain a.from('x').select().eq().… and returns the calls.
const chainCalls = (sf, startCall) => {
  const calls = [];
  let n = startCall;
  while (n.parent && ts.isPropertyAccessExpression(n.parent) && n.parent.parent && ts.isCallExpression(n.parent.parent)) {
    const call = n.parent.parent;
    calls.push({ name: n.parent.name.getText(sf), args: call.arguments.map((a) => clip(nodeText(sf, a), 160)) });
    n = call;
  }
  return calls;
};

// enum SupabaseTable { PLAYER = 'player', … } → table names for .from(SupabaseTable.X)
const enumValues = {};
for (const f of tsFiles) {
  const text = readFileSync(f, 'utf8');
  if (!/\benum\s+\w+/.test(text)) continue;
  const sf = parseTs(f);
  const visitEnum = (n) => {
    if (ts.isEnumDeclaration(n)) {
      for (const m of n.members) {
        if (m.initializer && ts.isStringLiteralLike(m.initializer)) enumValues[`${n.name.getText(sf)}.${m.name.getText(sf)}`] = m.initializer.text;
      }
    }
    ts.forEachChild(n, visitEnum);
  };
  visitEnum(sf);
}
const unwrap = (n) => {
  while (n && (ts.isAsExpression(n) || ts.isParenthesizedExpression(n) || ts.isNonNullExpression(n) || ts.isTypeAssertionExpression?.(n))) n = n.expression;
  return n;
};
const tableName = (sf, n) => {
  n = unwrap(n);
  if (!n) return null;
  if (ts.isStringLiteralLike(n)) return n.text;
  const t = n.getText(sf);
  return enumValues[t] ?? t;
};

const scanTs = (file) => {
  const sf = parseTs(file);
  const src = sf.getFullText();
  let unit = null;
  // Decide unit kind from decorators.
  const visitClass = (n) => {
    if (ts.isClassDeclaration(n)) {
      const decos = ts.canHaveDecorators(n) ? ts.getDecorators(n) ?? [] : [];
      for (const d of decos) {
        const call = d.expression;
        if (!ts.isCallExpression(call)) continue;
        const name = call.expression.getText(sf);
        const props = objProps(sf, call.arguments[0]);
        if (name === 'Component') {
          unit = unitFor(file, file.endsWith('.page.ts') ? 'page' : 'component');
          unit.className = n.name?.getText(sf) ?? null;
          unit.ts = rel(file);
          if (props.selector) unit.selector = nodeText(sf, props.selector).replace(/['"]/g, '');
          if (props.templateUrl) {
            const t = resolve(dirname(file), nodeText(sf, props.templateUrl).replace(/['"]/g, ''));
            if (existsSync(t)) unit.html = rel(t);
          }
          if (props.template) unit.inlineTemplate = { node: props.template, sf };
        } else if (name === 'Injectable') {
          unit = unitFor(file, 'service');
          unit.className = n.name?.getText(sf) ?? null;
          unit.ts = rel(file);
        } else if (name === 'NgModule' || name === 'Directive' || name === 'Pipe') {
          // modules are only read for routing
        }
      }
    }
    ts.forEachChild(n, visitClass);
  };
  visitClass(sf);
  if (!unit) {
    unit = unitFor(file, 'file');
    unit.ts = rel(file);
  }

  // Every method of the class: one 'logic' item per unit lists them so the
  // behaviour behind the UI (loading, sorting, filtering, calculations,
  // role flags) is compared method by method, not only the visible parts.
  const methods = [];
  const visitMembers = (n) => {
    if (ts.isClassDeclaration(n)) {
      for (const m of n.members) {
        const isFn = ts.isMethodDeclaration(m) || ts.isGetAccessor(m) || ts.isSetAccessor(m) || ts.isConstructorDeclaration(m)
          || (ts.isPropertyDeclaration(m) && m.initializer && (ts.isArrowFunction(m.initializer) || ts.isFunctionExpression(m.initializer) || /^(computed|effect|signal)\(/.test(m.initializer.getText(sf))));
        if (!isFn) continue;
        const start = lineOf(src, m.getStart(sf));
        const end = lineOf(src, m.getEnd());
        const name = ts.isConstructorDeclaration(m) ? 'constructor' : `${ts.isGetAccessor(m) ? 'get ' : ts.isSetAccessor(m) ? 'set ' : ''}${m.name?.getText(sf)}`;
        methods.push(`${name}:${start}-${end}`);
      }
    } else if (ts.isFunctionDeclaration(n) && n.name) {
      methods.push(`function ${n.name.getText(sf)}:${lineOf(src, n.getStart(sf))}-${lineOf(src, n.getEnd())}`);
    }
    ts.forEachChild(n, visitMembers);
  };
  visitMembers(sf);
  if (methods.length) {
    addItem(unit, { kind: 'logic', file: rel(file), line: 1, cond: [], methods, sig: 'logic' });
  }

  const push = (kind, node, data, sig) => {
    addItem(unit, {
      kind,
      file: rel(file),
      line: lineOf(src, node.getStart(sf)),
      method: enclosingMethod(node),
      cond: conditionsTs(sf, node),
      ...data,
      sig: sig ?? `${enclosingMethod(node)}|${clip(nodeText(sf, node), 300)}`,
    });
  };

  const visit = (n) => {
    if (ts.isCallExpression(n)) {
      const callee = n.expression;
      const calleeText = callee.getText(sf);
      const last = ts.isPropertyAccessExpression(callee) ? callee.name.getText(sf) : calleeText;
      const target = ts.isPropertyAccessExpression(callee) ? callee.expression.getText(sf) : '';
      const arg0 = n.arguments[0];

      // ---- dialogs
      if (last === 'create' && /alert(Controller|Ctrl)\b/i.test(target)) {
        const p = objProps(sf, arg0);
        push('alert', n, {
          header: textField(sf, p.header),
          subHeader: textField(sf, p.subHeader),
          message: textField(sf, p.message),
          buttons: buttonsOf(sf, p.buttons),
          inputs: buttonsOf(sf, p.inputs),
          cssClass: p.cssClass ? clip(nodeText(sf, p.cssClass), 80) : null,
          backdropDismiss: p.backdropDismiss ? nodeText(sf, p.backdropDismiss) : null,
        });
      } else if (last === 'create' && /actionSheet(Controller|Ctrl)\b/i.test(target)) {
        const p = objProps(sf, arg0);
        push('actionsheet', n, { header: textField(sf, p.header), subHeader: textField(sf, p.subHeader), buttons: buttonsOf(sf, p.buttons) });
      } else if (last === 'create' && /modal(Controller|Ctrl)\b/i.test(target)) {
        const p = objProps(sf, arg0);
        push('modal', n, {
          component: p.component ? nodeText(sf, p.component) : null,
          props: p.componentProps ? Object.keys(objProps(sf, p.componentProps)) : [],
          sheet: Boolean(p.breakpoints || p.initialBreakpoint),
          breakpoints: p.breakpoints ? nodeText(sf, p.breakpoints) : null,
          cssClass: p.cssClass ? clip(nodeText(sf, p.cssClass), 80) : null,
          presentingElement: Boolean(p.presentingElement),
          canDismiss: p.canDismiss ? clip(nodeText(sf, p.canDismiss), 80) : null,
        });
      } else if (last === 'create' && /popover(Controller|Ctrl)\b/i.test(target)) {
        const p = objProps(sf, arg0);
        push('popover', n, { component: p.component ? nodeText(sf, p.component) : null });
      } else if ((last === 'create' && /toast(Controller|Ctrl)\b/i.test(target)) || calleeText === 'Utils.showToast') {
        const p = last === 'create' ? objProps(sf, arg0) : null;
        const msg = p ? p.message : arg0;
        const color = p ? p.color : n.arguments[1];
        push('toast', n, {
          message: textField(sf, msg),
          color: color ? nodeText(sf, color).replace(/['"]/g, '') : null,
          duration: p?.duration ? nodeText(sf, p.duration) : (n.arguments[2] ? nodeText(sf, n.arguments[2]) : null),
        });
      } else if ((last === 'create' && /loading(Controller|Ctrl)\b/i.test(target)) || calleeText === 'Utils.getLoadingElement') {
        const p = last === 'create' ? objProps(sf, arg0) : null;
        push('loading', n, { message: textField(sf, p ? p.message : arg0) });
      }
      // ---- navigation
      else if (/^(navigate|navigateByUrl)$/.test(last) && /router/i.test(target)) {
        push('nav', n, { via: calleeText.replace(/^this\./, ''), to: clip(n.arguments.map((a) => nodeText(sf, a)).join(', '), 200) });
      } else if (/^(navigateForward|navigateBack|navigateRoot|back|pop)$/.test(last) && /nav(Ctrl|Controller)|location/i.test(target)) {
        push('nav', n, { via: calleeText.replace(/^this\./, ''), to: clip(n.arguments.map((a) => nodeText(sf, a)).join(', '), 200) });
      }
      // ---- backend
      else if (last === 'from' && arg0 && !/\bstorage$/.test(target) && !/^(Array|Object|Buffer|Uint8Array|Observable|rxjs)$/.test(target)
        && (ts.isStringLiteralLike(unwrap(arg0)) || /^SupabaseTable\./.test(unwrap(arg0).getText(sf)))) {
        const calls = chainCalls(sf, n);
        const op = calls.find((c) => DB_OPS.has(c.name));
        const table = tableName(sf, arg0);
        push('db', n, {
          table,
          op: op?.name ?? 'select?',
          payload: op && op.name !== 'select' && op.name !== 'delete' ? op.args[0] ?? null : null,
          options: op?.args.slice(op.name === 'select' ? 1 : 1).filter(Boolean) ?? [],
          columns: op?.name === 'select' ? op.args[0] ?? '*' : calls.find((c) => c.name === 'select')?.args[0] ?? null,
          filters: calls.filter((c) => FILTERS.has(c.name)).map((c) => `${c.name}(${c.args.join(', ')})`),
          tenantFilter: calls.some((c) => c.name === 'eq' && /tenant[_]?id/i.test(c.args[0] ?? '')),
        }, `${enclosingMethod(n)}|${table}|${op?.name}|${calls.map((c) => c.name).join('.')}`);
      } else if (last === 'from' && arg0 && /\bstorage$/.test(target)) {
        const calls = chainCalls(sf, n);
        const op = calls.find((c) => STORAGE_OPS.has(c.name));
        push('db', n, { table: `storage:${tableName(sf, arg0)}`, op: op?.name ?? '?', payload: op?.args.join(', ') ?? null, filters: [] },
          `${enclosingMethod(n)}|storage|${nodeText(sf, arg0)}|${op?.name}`);
      } else if (last === 'rpc' && arg0) {
        push('db', n, { table: `rpc:${ts.isStringLiteralLike(arg0) ? arg0.text : nodeText(sf, arg0)}`, op: 'rpc', payload: n.arguments[1] ? clip(nodeText(sf, n.arguments[1]), 300) : null, filters: [] });
      } else if (last === 'invoke' && /functions$/.test(target) && arg0) {
        push('db', n, { table: `edge:${ts.isStringLiteralLike(arg0) ? arg0.text : nodeText(sf, arg0)}`, op: 'invoke', payload: n.arguments[1] ? clip(nodeText(sf, n.arguments[1]), 400) : null, filters: [] });
      } else if (/^(signInWithPassword|signUp|signOut|resetPasswordForEmail|updateUser|verifyOtp|setSession|refreshSession|signInWithOtp|exchangeCodeForSession|signInWithOAuth|getUser|getSession|onAuthStateChange)$/.test(last) && /auth$/.test(target)) {
        push('db', n, { table: 'auth', op: last, payload: arg0 ? clip(nodeText(sf, arg0), 200) : null, filters: [] });
      } else if (/^(channel|subscribe|removeChannel)$/.test(last) && /supabase|client|\bsb\b/i.test(target)) {
        push('db', n, { table: 'realtime', op: last, payload: arg0 ? clip(nodeText(sf, arg0), 120) : null, filters: [] });
      }
      // ---- native & effects
      else if (target === 'Capacitor' && /^(isNativePlatform|getPlatform|isPluginAvailable|convertFileSrc)$/.test(last)) {
        // platform checks show up in conditions; not an item of their own
      } else if (ts.isPropertyAccessExpression(callee) && NATIVE.includes(target)) {
        push('native', n, { plugin: target, call: last, args: clip(n.arguments.map((a) => nodeText(sf, a)).join(', '), 160) }, `${enclosingMethod(n)}|${target}.${last}`);
      } else if (/^Utils\.(downloadFileNative|openFileNative|openNavigation|createPlanExport|getUrl)$/.test(calleeText)
        || /^(window\.open|window\.print|navigator\.clipboard\.writeText|navigator\.share|saveAs|FileSaver\.saveAs)$/.test(calleeText)
        || (last === 'writeFile' && /XLSX|xlsx/.test(target)) || (/^(save|output|autoPrint|open)$/.test(last) && /\b(doc|pdf|jsPDF)\b/.test(target))) {
        push('effect', n, { call: calleeText.replace(/^this\./, ''), args: clip(n.arguments.map((a) => nodeText(sf, a)).join(', '), 160) });
      }
    }
    ts.forEachChild(n, visit);
  };
  visit(sf);
  return unit;
};

// ---------------------------------------------------------------- templates
const FIELD_TAGS = new Set([
  'ion-input', 'ion-textarea', 'ion-select', 'ion-toggle', 'ion-checkbox', 'ion-radio-group', 'ion-datetime',
  'ion-datetime-button', 'ion-segment', 'ion-searchbar', 'ion-range', 'input', 'textarea', 'select', 'ion-input-otp',
]);
const OPTION_TAGS = new Set(['ion-select-option', 'ion-segment-button', 'ion-radio', 'option']);
const TEXT_TAGS = new Set([
  'ion-title', 'ion-label', 'ion-note', 'ion-list-header', 'ion-item-divider', 'ion-card-title', 'ion-card-subtitle',
  'ion-card-content', 'ion-badge', 'ion-chip', 'ion-text', 'ion-back-button', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'p',
  'span', 'small', 'strong', 'b', 'em', 'div', 'li', 'td', 'th', 'ion-col', 'ion-item', 'ion-segment-button',
  'ion-select-option', 'label', 'a', 'ion-tab-button', 'ion-button',
]);

const scanTemplate = (unit, htmlFile, text, baseOffset = 0, baseLine = 0) => {
  const parsed = ng.parseTemplate(text, htmlFile, { preserveWhitespaces: false });
  const slice = (span) => (span ? text.slice(span.start.offset, span.end.offset) : '');
  const ln = (span) => baseLine + lineOf(text, span.start.offset);
  const claimed = new Set(); // element nodes whose texts are already part of an action/field

  const ownText = (el, depth = 0) => {
    // translated/literal text in an element subtree (excluding nested modals)
    let s = '';
    for (const c of el.children ?? []) {
      if (c instanceof ng.TmplAstText) s += ` "${c.value}"`;
      else if (c instanceof ng.TmplAstBoundText) s += ` ${slice(c.sourceSpan)}`;
      else if (c instanceof ng.TmplAstElement && !/^ion-(modal|popover)$/.test(c.name)) {
        s += ` ${attrText(c)} ${ownText(c, depth + 1)}`;
      } else if (c.children || c.branches) s += ` ${ownText(c.children ? c : { children: c.branches.flatMap((b) => b.children) }, depth + 1)}`;
    }
    return s;
  };
  const attrText = (el) => [
    ...el.attributes.filter((a) => /^(label|placeholder|title|aria-label|helperText|helper-text|cancelText|okText|doneText|header|text|value|description|message|subHeader)$/i.test(a.name)).map((a) => `"${a.value}"`),
    ...el.inputs.filter((a) => /^(label|placeholder|title|helperText|cancelText|okText|doneText|header|text|subHeader|message|interfaceOptions|description)$/i.test(a.name)).map((a) => slice(a.sourceSpan)),
  ].join(' ');
  const icons = (el) => {
    const out = [];
    const rec = (n) => {
      for (const c of n.children ?? []) {
        if (c instanceof ng.TmplAstElement && c.name === 'ion-icon') {
          const a = c.attributes.find((x) => /^(name|icon|ios|md)$/.test(x.name));
          const b = c.inputs.find((x) => /^(name|icon)$/.test(x.name));
          out.push(a ? a.value : b ? slice(b.sourceSpan) : '?');
        } else rec(c.branches ? { children: c.branches.flatMap((x) => x.children) } : c);
      }
    };
    const own = el.attributes.find((x) => x.name === 'icon' || x.name === 'name');
    if (el.name === 'ion-icon' && own) out.push(own.value);
    rec(el);
    return uniq(out).slice(0, 6);
  };
  const keyAttrs = (el) => {
    const out = {};
    for (const a of el.attributes) {
      if (/^(routerLink|href|tab|slot|color|fill|expand|shape|size|type|interface|presentation|side|vertical|horizontal|lines|mode|trigger|id|lang|value|button|detail|multiple|disabled|readonly|required|inputmode|autocomplete|class)$/i.test(a.name)) out[a.name] = clip(a.value, 120);
    }
    for (const a of el.inputs) {
      if (/^(routerLink|href|color|disabled|isOpen|trigger|value|multiple|readonly|interface|hidden|button|detail|max|min|presentation|class\..+|style\..+)$/i.test(a.name)) out[`[${a.name}]`] = clip(slice(a.sourceSpan).replace(/^[^=]*=\s*/, ''), 160);
    }
    if (el.references?.length) out['#'] = el.references.map((r) => r.name).join(',');
    return out;
  };

  const visitNodes = (nodes, cond) => nodes.forEach((n) => visitNode(n, cond));
  const visitNode = (n, cond) => {
    if (n instanceof ng.TmplAstIfBlock) {
      const prev = [];
      for (const b of n.branches) {
        const head = squash(slice(b.startSourceSpan)).replace(/\s*\{$/, '');
        const c = b.expression ? head : `@else (not ${prev.join(' / ')})`;
        prev.push(b.expression ? clip(b.expression.source ?? head, 100) : 'else');
        visitNodes(b.children, [...cond, clip(c, 200)]);
      }
      return;
    }
    if (n instanceof ng.TmplAstForLoopBlock) {
      visitNodes(n.children, [...cond, clip(squash(slice(n.startSourceSpan)).replace(/\s*\{$/, ''), 160)]);
      if (n.empty) visitNodes(n.empty.children, [...cond, `@empty of ${clip(n.expression?.source ?? '', 100)}`]);
      return;
    }
    if (n instanceof ng.TmplAstSwitchBlock) {
      const head = `@switch (${clip(n.expression?.source ?? '', 100)})`;
      for (const g of n.groups ?? n.cases ?? []) {
        const cases = g.cases ? g.cases.map((c) => (c.expression ? `case ${c.expression.source}` : 'default')) : [g.expression ? `case ${g.expression.source}` : 'default'];
        visitNodes(g.children, [...cond, `${head} ${cases.join('|')}`]);
      }
      return;
    }
    if (n instanceof ng.TmplAstDeferredBlock) {
      visitNodes(n.children, cond);
      return;
    }
    if (n instanceof ng.TmplAstTemplate) {
      const extra = (n.templateAttrs ?? []).filter((a) => /^ng(If|For|ForOf|Switch|SwitchCase)$/.test(a.name)).map((a) => `*${a.name}="${clip(a.value?.source ?? '', 140)}"`);
      const refs = n.references?.length ? [`<ng-template #${n.references.map((r) => r.name).join(',')}>`] : [];
      visitNodes(n.children, [...cond, ...extra, ...refs]);
      return;
    }
    if (n instanceof ng.TmplAstElement || n instanceof ng.TmplAstComponent) {
      visitElement(n, cond);
      return;
    }
    if ((n instanceof ng.TmplAstBoundText || n instanceof ng.TmplAstText) && !claimed.has(n)) {
      // loose text directly inside a block: handled by the parent element
    }
    if (n.children) visitNodes(n.children, cond);
  };

  const visitElement = (el, cond) => {
    const name = el.name;
    const attrsMap = keyAttrs(el);
    const condHere = [...cond];
    const hiddenIn = el.inputs.find((a) => a.name === 'hidden');
    if (hiddenIn) condHere.push(`[hidden]=${clip(slice(hiddenIn.sourceSpan).replace(/^[^=]*=\s*/, ''), 120)}`);

    // modal / popover / sheet containers
    if (/^ion-(modal|popover|action-sheet|alert|loading|toast)$/.test(name)) {
      const own = `${attrText(el)}`;
      addItem(unit, {
        kind: name === 'ion-modal' ? 'modal' : name === 'ion-popover' ? 'popover' : name.replace('ion-', '').replace('-', ''),
        file: unit.html,
        line: ln(el.sourceSpan),
        cond: condHere,
        inline: true,
        tag: name,
        attrs: attrsMap,
        events: el.outputs.map((o) => `(${o.name})=${clip(slice(o.handlerSpan), 160)}`),
        ...label(own),
        sig: `${name}|${JSON.stringify(attrsMap)}|${keysIn(own).join(',')}`,
      });
      visitNodes(el.children, [...condHere, `in <${name}${attrsMap.trigger ? ` trigger=${attrsMap.trigger}` : ''}${attrsMap['[isOpen]'] ? ` isOpen=${attrsMap['[isOpen]']}` : ''}${attrsMap['#'] ? ` #${attrsMap['#']}` : ''}>`]);
      return;
    }

    const events = el.outputs.filter((o) => !/^(ngModelChange)$/.test(o.name) || !FIELD_TAGS.has(name)).map((o) => `(${o.name})=${clip(slice(o.handlerSpan), 200)}`);
    const link = attrsMap.routerLink ?? attrsMap['[routerLink]'] ?? attrsMap.href ?? attrsMap['[href]'] ?? (name === 'ion-tab-button' ? `tab:${attrsMap.tab}` : null);
    const isField = FIELD_TAGS.has(name);
    const isAction = !isField && (events.length > 0 || link || name === 'ion-tab-button' || name === 'ion-back-button' || name === 'ion-menu-button' || (name === 'ion-button' && attrsMap.type === 'submit') || (name === 'ion-button' && attrsMap.id) || (name === 'ion-item' && attrsMap.id && /trigger|open/i.test(attrsMap.id)));

    if (isField || isAction) {
      const fullText = `${attrText(el)} ${ownText(el)}`;
      const options = [];
      if (isField) {
        const collect = (n2) => {
          for (const c of n2.children ?? (n2.branches ? n2.branches.flatMap((b) => b.children) : [])) {
            if (c instanceof ng.TmplAstElement && OPTION_TAGS.has(c.name)) {
              const v = c.attributes.find((a) => a.name === 'value')?.value ?? slice(c.inputs.find((a) => a.name === 'value')?.sourceSpan).replace(/^[^=]*=\s*/, '');
              const t = ownText(c) + attrText(c);
              options.push({ value: clip(v, 60), ...label(t), text: clip(t, 80) });
            } else collect(c instanceof ng.TmplAstElement || c.children || c.branches ? c : { children: [] });
          }
        };
        collect(el);
      }
      const model = el.inputs.find((a) => /^(ngModel|formControlName|value|checked|formControl)$/.test(a.name)) ?? null;
      const modelAttr = el.attributes.find((a) => /^(formControlName|name)$/.test(a.name)) ?? null;
      addItem(unit, {
        kind: isField ? 'field' : 'action',
        file: unit.html,
        line: ln(el.sourceSpan),
        cond: condHere,
        tag: name,
        attrs: attrsMap,
        events,
        link: link ?? null,
        model: model ? clip(slice(model.sourceSpan), 160) : modelAttr ? `${modelAttr.name}=${modelAttr.value}` : null,
        icons: icons(el),
        options: options.length ? options : undefined,
        ...label(fullText),
        text: clip(fullText.replace(/\s+/g, ' '), 200),
        sig: `${name}|${events.join(';')}|${link ?? ''}|${model ? slice(model.sourceSpan) : ''}|${keysIn(fullText).join(',')}`,
      });
      // nested interactive children are still visited (e.g. button inside item)
      for (const c of el.children) {
        if (c instanceof ng.TmplAstElement && (c.outputs.length || FIELD_TAGS.has(c.name) || /^ion-(modal|popover)$/.test(c.name) || c.attributes.some((a) => /routerLink|href/.test(a.name)) || c.inputs.some((a) => /routerLink|href/.test(a.name)))) {
          visitElement(c, [...condHere, `in <${name}>`]);
        } else if (!(c instanceof ng.TmplAstElement) && (c.children || c.branches)) {
          // blocks inside an action (e.g. @if around a button inside an item)
          visitInteractiveOnly(c, [...condHere, `in <${name}>`]);
        } else if (c instanceof ng.TmplAstElement) {
          visitInteractiveOnly(c, [...condHere, `in <${name}>`]);
        }
      }
      return;
    }

    // custom component embeds
    if (name.startsWith('app-')) {
      const bindings = [...el.inputs.map((i) => `[${i.name}]`), ...el.outputs.map((o) => `(${o.name})`), ...el.attributes.map((a) => a.name)];
      addItem(unit, {
        kind: 'embed',
        file: unit.html,
        line: ln(el.sourceSpan),
        cond: condHere,
        tag: name,
        bindings,
        events,
        sig: `${name}|${bindings.join(',')}`,
      });
    }

    // texts directly owned by this element
    const direct = el.children.filter((c) => c instanceof ng.TmplAstText || c instanceof ng.TmplAstBoundText).map((c) => (c instanceof ng.TmplAstText ? `"${c.value}"` : slice(c.sourceSpan))).join(' ') + ` ${attrText(el)}`;
    const lab = label(direct);
    // data shown without a translated label ({{ person.firstName }}, {{ x | date }})
    const bound = el.children.filter((c) => c instanceof ng.TmplAstBoundText).map((c) => clip(slice(c.sourceSpan), 120)).filter((b) => !keysIn(b).length);
    if (lab.keys.length || lab.literals.length || bound.length) {
      addItem(unit, {
        kind: 'text',
        file: unit.html,
        line: ln(el.sourceSpan),
        cond: condHere,
        tag: name,
        attrs: Object.fromEntries(Object.entries(attrsMap).filter(([k]) => /slot|color|size|class/.test(k))),
        icons: name === 'ion-item' ? icons(el) : undefined,
        ...lab,
        bound: bound.length ? bound : undefined,
        text: clip(direct, 200),
        sig: `${name}|${lab.keys.join(',')}|${lab.literals.join(',')}|${bound.join(',')}`,
      });
    }
    visitNodes(el.children, condHere);
  };

  // Inside an action, only nested interactive elements become items.
  const visitInteractiveOnly = (n, cond) => {
    if (n instanceof ng.TmplAstElement) {
      if (n.outputs.length || FIELD_TAGS.has(n.name) || /^ion-(modal|popover)$/.test(n.name)) return visitElement(n, cond);
      return n.children.forEach((c) => visitInteractiveOnly(c, cond));
    }
    if (n.branches) {
      for (const b of n.branches) b.children.forEach((c) => visitInteractiveOnly(c, [...cond, clip(squash(slice(b.startSourceSpan)).replace(/\s*\{$/, ''), 160)]));
      return;
    }
    (n.children ?? []).forEach((c) => visitInteractiveOnly(c, cond));
  };

  if (parsed.errors?.length) unit.templateErrors = parsed.errors.map((e) => clip(e.msg, 160));
  visitNodes(parsed.nodes, []);
};

// ---------------------------------------------------------------- routing
const routes = [];
const parseRoutes = (file, prefix, seen = new Set()) => {
  if (!file || !existsSync(file) || seen.has(`${file}|${prefix}`)) return;
  seen.add(`${file}|${prefix}`);
  const sf = parseTs(file);
  const imports = {};
  sf.statements.forEach((s) => {
    if (ts.isImportDeclaration(s) && s.importClause?.namedBindings && ts.isNamedImports(s.importClause.namedBindings)) {
      for (const e of s.importClause.namedBindings.elements) imports[e.name.getText(sf)] = resolve(dirname(file), s.moduleSpecifier.text);
    }
  });
  const routeArrays = [];
  const find = (n) => {
    if (ts.isVariableDeclaration(n) && n.initializer && ts.isArrayLiteralExpression(n.initializer) && /routes/i.test(n.name.getText(sf))) routeArrays.push(n.initializer);
    ts.forEachChild(n, find);
  };
  find(sf);
  const handle = (arr, base) => {
    for (const el of arr.elements) {
      if (!ts.isObjectLiteralExpression(el)) continue;
      const p = objProps(sf, el);
      const path = p.path ? p.path.getText(sf).replace(/['"]/g, '') : '';
      const full = [base, path].filter(Boolean).join('/');
      const guards = p.canActivate ? p.canActivate.getText(sf) : null;
      const r = { path: `/${full}`, file: rel(file), line: lineOf(sf.getFullText(), el.getStart(sf)), guards, redirectTo: p.redirectTo ? p.redirectTo.getText(sf).replace(/['"]/g, '') : null, component: null, data: p.data ? clip(p.data.getText(sf), 160) : null };
      if (p.component) {
        const cname = p.component.getText(sf);
        const target = imports[cname];
        r.component = cname;
        r.unit = target ? rel(`${target}.ts`).replace(/\.ts$/, '') : null;
      }
      if (p.loadComponent) {
        const m = p.loadComponent.getText(sf).match(/import\(['"]([^'"]+)['"]\)/);
        if (m) r.unit = rel(`${resolve(dirname(file), m[1])}.ts`).replace(/\.ts$/, '');
      }
      if (p.loadChildren) {
        const m = p.loadChildren.getText(sf).match(/import\(['"]([^'"]+)['"]\)/);
        if (m) {
          const modFile = `${resolve(dirname(file), m[1])}.ts`;
          const routing = modFile.replace(/\.module\.ts$/, '-routing.module.ts');
          r.module = rel(modFile);
          if (existsSync(routing)) parseRoutes(routing, full, seen);
          else parseRoutes(modFile, full, seen);
        }
      }
      if (r.component || r.redirectTo || r.unit) routes.push(r);
      if (p.children && ts.isArrayLiteralExpression(p.children)) handle(p.children, full);
    }
  };
  routeArrays.forEach((a) => handle(a, prefix));
};

// ---------------------------------------------------------------- run
for (const f of tsFiles) scanTs(f);
for (const u of units.values()) {
  if (u.html) {
    const file = join(appDir, u.html);
    scanTemplate(u, u.html, readFileSync(file, 'utf8'));
  } else if (u.inlineTemplate) {
    const { node, sf } = u.inlineTemplate;
    const raw = node.getText(sf).replace(/^[`'"]|[`'"]$/g, '');
    u.html = `${u.ts} (inline)`;
    scanTemplate(u, u.html, raw, 0, lineOf(sf.getFullText(), node.getStart(sf)) - 1);
  }
  delete u.inlineTemplate;
}
// Templates not referenced by any component (should not happen; listed for completeness)
const usedHtml = new Set([...units.values()].map((u) => u.html).filter(Boolean));
const orphanHtml = [...htmlFiles].map(rel).filter((h) => !usedHtml.has(h) && !h.endsWith('index.html'));

parseRoutes(join(appDir, 'app-routing.module.ts'), '');
for (const r of routes) {
  const u = r.unit && units.get(r.unit);
  if (u) u.routes.push(r.path);
}
// route items live on the unit 'routes'
const routeUnit = unitFor(join(appDir, 'app-routing.module.ts'), 'routing');
for (const r of routes) {
  addItem(routeUnit, { kind: 'route', file: r.file, line: r.line, cond: r.guards ? [`canActivate: ${r.guards}`] : [], path: r.path, component: r.component, unit: r.unit ?? null, redirectTo: r.redirectTo, data: r.data, sig: r.path });
}

// i18n keys referenced by any item
const allKeys = new Set();
const collectKeys = (o) => {
  if (!o || typeof o !== 'object') return;
  if (Array.isArray(o.keys)) o.keys.forEach((k) => allKeys.add(k));
  Object.values(o).forEach(collectKeys);
};
for (const u of units.values()) u.items.forEach(collectKeys);

// Flutter key usage (normal design only: Beta lives in features/redesign and theme/redesign)
let flutterKeyUse = null;
if (flutterRoot) {
  flutterKeyUse = {};
  const isBeta = (p) => /lib\/(features|core\/theme)\/redesign\//.test(p) || /\/rd_[^/]*\.dart$/.test(p);
  const dartFiles = walk(join(flutterRoot, 'lib')).filter((f) => f.endsWith('.dart') && !/\.(g|freezed)\.dart$/.test(f) && !/lib\/l10n\/generated\//.test(f));
  const arbToKey = new Map([...allKeys].map((k) => [toArbKey(k), k]));
  const re = /\.l10n\.([a-zA-Z0-9]+)|\bl10n\.([a-zA-Z0-9]+)|\bl\.([a-zA-Z0-9]+)\b|AppLocalizations\.of\([^)]*\)!?\.([a-zA-Z0-9]+)/g;
  for (const f of dartFiles) {
    const relPath = relative(flutterRoot, f).replaceAll('\\', '/');
    const lines = readFileSync(f, 'utf8').split('\n');
    lines.forEach((line, i) => {
      for (const m of line.matchAll(re)) {
        const arb = m[1] ?? m[2] ?? m[3] ?? m[4];
        const key = arbToKey.get(arb);
        if (!key) continue;
        const entry = (flutterKeyUse[key] ??= { normal: [], beta: [] });
        (isBeta(relPath) ? entry.beta : entry.normal).push(`${relPath}:${i + 1}`);
      }
    });
  }
}

let ionicCommit = null;
let ionicVersion = null;
try {
  ionicCommit = execSync('git rev-parse --short HEAD', { cwd: ionicRoot }).toString().trim();
  ionicVersion = JSON.parse(readFileSync(join(ionicRoot, 'package.json'), 'utf8')).version;
} catch { /* not a git checkout */ }

const unitList = [...units.values()].filter((u) => u.items.length).sort((a, b) => a.id.localeCompare(b.id));
const counts = {};
for (const u of unitList) for (const it of u.items) counts[it.kind] = (counts[it.kind] ?? 0) + 1;

const out = {
  meta: {
    ionicVersion,
    ionicCommit,
    generator: 'tool/parity/extract_ionic.mjs',
    units: unitList.length,
    items: unitList.reduce((s, u) => s + u.items.length, 0),
    counts,
    orphanHtml,
  },
  i18n: Object.fromEntries([...allKeys].sort().map((k) => [k, { de: de[k] ?? null, arb: toArbKey(k), flutter: flutterKeyUse ? flutterKeyUse[k] ?? { normal: [], beta: [] } : undefined }])),
  units: unitList,
};
// One item per line: readable git diffs when the Ionic app changes.
const J = (v) => JSON.stringify(v);
const lines = ['{', `"meta": ${J(out.meta)},`, '"i18n": {'];
const i18nEntries = Object.entries(out.i18n);
i18nEntries.forEach(([k, v], i) => lines.push(` ${J(k)}: ${J(v)}${i < i18nEntries.length - 1 ? ',' : ''}`));
lines.push('},', '"units": [');
out.units.forEach((u, ui) => {
  const { items, ...head } = u;
  lines.push(` {${J(head).slice(1, -1)}, "items": [`);
  items.forEach((it, i) => lines.push(`  ${J(it)}${i < items.length - 1 ? ',' : ''}`));
  lines.push(` ]}${ui < out.units.length - 1 ? ',' : ''}`);
});
lines.push(']', '}');
writeFileSync(outFile, `${lines.join('\n')}\n`);
console.log(`Ionic ${ionicVersion} (${ionicCommit}): ${out.meta.units} units, ${out.meta.items} items → ${outFile}`);
console.log(Object.entries(counts).map(([k, v]) => `${k}: ${v}`).join(', '));
if (orphanHtml.length) console.log(`templates without component: ${orphanHtml.join(', ')}`);
