// Regenerates lib/features/help/data/help_content.dart and
// help_content_en.dart from the Ionic help content
// (src/app/settings/help/content).
//
//   node tool/help/build_help.mjs <ionic>/src/app/settings/help/content
//
// The Ionic files are plain object literals; they are evaluated after the
// type imports and annotations are removed.
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const dir = process.argv[2];
if (!dir) {
  console.error('usage: node tool/help/build_help.mjs <ionic help content dir>');
  process.exit(1);
}

function load(file) {
  let src = readFileSync(join(dir, file), 'utf8');
  src = src.replace(/^import .*$/gm, '');
  const names = [];
  src = src.replace(/export const (\w+)\s*:[^=]+=/g, (_, name) => {
    names.push(name);
    return `const ${name} =`;
  });
  // eslint-disable-next-line no-new-func
  return new Function(`${src}\nreturn { ${names.join(', ')} };`)();
}

const dart = (v) => JSON.stringify(v).replace(/\$/g, '\\$');
const list = (a) => `[${(a ?? []).map(dart).join(', ')}]`;

const order = [
  ['getting-started.articles.ts', 'GETTING_STARTED_ARTICLES'],
  ['attendance.articles.ts', 'ATTENDANCE_ARTICLES'],
  ['people.articles.ts', 'PEOPLE_ARTICLES'],
  ['planning.articles.ts', 'PLANNING_ARTICLES'],
  ['songs.articles.ts', 'SONGS_ARTICLES'],
  ['self-service.articles.ts', 'SELF_SERVICE_ARTICLES'],
  ['settings.articles.ts', 'SETTINGS_ARTICLES'],
  ['team-organization.articles.ts', 'TEAM_ORGANIZATION_ARTICLES'],
  ['duty.articles.ts', 'DUTY_ARTICLES'],
  ['other-features.articles.ts', 'OTHER_FEATURES_ARTICLES'],
];
// Flutter-specific texts where the app behaves differently from Ionic
// (Flutter shows PDFs and images in its own viewer everywhere).
const OVERRIDES_DE = {
  'songs-add': {
    body: `Unter "Werke" legst du ein neues [[Werk]] mit Nummer, Namen, Schwierigkeitsgrad und Kategorien an. Optional lassen sich zu jeder [[Gruppe]]/Stimme passende Notendateien (PDF) hinterlegen.

Tippst du auf eine Datei und dann auf "Datei öffnen", zeigt Attendix PDFs und Bilder direkt in der App an. Andere Dateien öffnen sich in einem neuen Tab bzw. in der passenden App. Nutzt du Attendix als installierte Web-App (z. B. am Mac über "Zum Dock hinzufügen"), bekommst du für solche Dateien stattdessen einen Hinweis mit "Datei herunterladen" und "Schließen". In der Attendix-App aus dem App Store auf einem Mac mit Apple-Chip öffnen sie sich im Browser, und "Datei herunterladen" speichert sie über den Browser in deinem Downloads-Ordner.`,
  },
};
const OVERRIDES_EN = {
  'songs-add': {
    body: `Under "Pieces" you create a new [[Piece|piece]] with number, name, difficulty and categories. Optionally you can store matching sheet music files (PDF) for each [[Group|group]]/voice.

Tap a file and then "Open file": Attendix shows PDFs and images right inside the app. Other files open in a new tab or in the matching app. If you use Attendix as an installed web app (e.g. on a Mac via "Add to Dock"), you get a hint with "Download file" and "Close" for such files instead. In the Attendix app from the App Store on a Mac with Apple silicon, they open in the browser, and "Download file" saves them to your Downloads folder via the browser.`,
  },
};

const articles = order
  .flatMap(([f, n]) => load(join('articles', f))[n])
  .map((a) => ({ ...a, ...OVERRIDES_DE[a.id] }));
const { HELP_CATEGORIES } = load('categories.ts');
const { GLOSSARY } = load('glossary.ts');

let de = `// GENERATED from Ionic src/app/settings/help/content (German).
// Do not edit by hand; regenerate when the Ionic help content changes
// (node tool/help/build_help.mjs <ionic>/src/app/settings/help/content).

import 'help_models.dart';

const List<HelpCategory> helpCategories = [
`;
for (const c of HELP_CATEGORIES) {
  de += `  HelpCategory(\n    id: ${dart(c.id)},\n    label: ${dart(c.label)},\n    icon: ${dart(c.icon)},\n    order: ${c.order},\n  ),\n`;
}
de += `];\n\nconst List<HelpArticle> helpArticles = [\n`;
for (const a of articles) {
  de += `  HelpArticle(\n    id: ${dart(a.id)},\n    title: ${dart(a.title)},\n    categoryId: ${dart(a.categoryId)},\n    keywords: ${list(a.keywords)},\n    body: ${dart(a.body)},\n  ),\n`;
}
de += `];\n\nconst List<GlossaryTerm> glossaryTerms = [\n`;
for (const g of GLOSSARY) {
  de += `  GlossaryTerm(\n    id: ${dart(g.id)},\n    term: ${dart(g.term)},\n    aliases: ${list(g.aliases)},\n    definition: ${dart(g.definition)},\n  ),\n`;
}
de += `];\n`;

// English: same key order as Ionic en/index.ts.
const enIndex = readFileSync(join(dir, 'en/index.ts'), 'utf8');
const categoriesEn = {};
for (const m of enIndex.matchAll(/'([\w-]+)':\s*'([^']*)'/g)) categoriesEn[m[1]] = m[2];
const enFiles = {
  BASICS_EN: 'basics.en.ts', PLANNING_EN: 'planning.en.ts', SETTINGS_EN: 'settings.en.ts',
  DUTY_EN: 'duty.en.ts', OTHER_EN: 'other.en.ts',
};
const articlesEn = {};
for (const m of enIndex.matchAll(/\.\.\.(\w+_EN)/g)) {
  Object.assign(articlesEn, load(join('en', enFiles[m[1]]))[m[1]]);
}
for (const [id, o] of Object.entries(OVERRIDES_EN)) {
  if (articlesEn[id]) articlesEn[id] = { ...articlesEn[id], ...o };
}
const { GLOSSARY_EN } = load('en/glossary.en.ts');

let en = `// GENERATED from Ionic src/app/settings/help/content/en (English).
// Do not edit by hand; regenerate when the Ionic help content changes.
// Keyed by the ids of the German content in help_content.dart; missing
// entries fall back to German (Ionic localizeHelp).

import 'help_models.dart';

const Map<String, String> helpCategoriesEn = {
`;
for (const [k, v] of Object.entries(categoriesEn)) en += `  ${dart(k)}: ${dart(v)},\n`;
en += `};\n\nconst Map<String, HelpArticleTranslation> helpArticlesEn = {\n`;
for (const [k, a] of Object.entries(articlesEn)) {
  en += `  ${dart(k)}: HelpArticleTranslation(\n`;
  if (a.title !== undefined) en += `    title: ${dart(a.title)},\n`;
  if (a.keywords !== undefined) en += `    keywords: ${list(a.keywords)},\n`;
  if (a.body !== undefined) en += `    body: ${dart(a.body)},\n`;
  en += `  ),\n`;
}
en += `};\n\nconst Map<String, GlossaryTermTranslation> glossaryTermsEn = {\n`;
for (const [k, g] of Object.entries(GLOSSARY_EN)) {
  en += `  ${dart(k)}: GlossaryTermTranslation(\n`;
  if (g.term !== undefined) en += `    term: ${dart(g.term)},\n`;
  if (g.aliases !== undefined) en += `    aliases: ${list(g.aliases)},\n`;
  if (g.definition !== undefined) en += `    definition: ${dart(g.definition)},\n`;
  en += `  ),\n`;
}
en += `};\n`;

writeFileSync('lib/features/help/data/help_content.dart', de);
writeFileSync('lib/features/help/data/help_content_en.dart', en);
console.log(`${articles.length} articles, ${GLOSSARY.length} glossary terms, ${Object.keys(articlesEn).length} en articles`);
