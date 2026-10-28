// Builds lib/l10n/app_de.arb and lib/l10n/app_en.arb from
//   1. tool/i18n/ionic/{de,en}.json   – snapshot of the Ionic transloco files
//   2. lib/l10n/fragments/*.json      – Flutter-only strings, one file per
//                                       feature: {"de": {...}, "en": {...}}
//
// Usage (from the repo root):
//   dart run tool/i18n/build_arb.dart                 # rebuild ARBs
//   dart run tool/i18n/build_arb.dart --ionic ../ionic/src/i18n
//                                                     # refresh the snapshot first
//   dart run tool/i18n/build_arb.dart --lookup settings.language.title
//   dart run tool/i18n/build_arb.dart --find "Abmelden"
// Then: flutter gen-l10n
//
// Key mapping (deterministic): dotted Ionic key -> lowerCamelCase ARB key,
//   "settings.language.title" -> "settingsLanguageTitle"
//   "common.persons"          -> "commonPersons"
// The original dotted key is kept in each entry's @description.
//
// Message conversion: transloco-messageformat already uses ICU syntax.
//   {name}                         -> placeholder `name` (type Object)
//   {count, plural, one {…} …}     -> plural placeholder `count` (type num)
//   `#` inside a plural branch     -> {count} (gen-l10n has no `#` support)
import 'dart:convert';
import 'dart:io';

const languages = ['de', 'en'];
const templateLanguage = 'de';
final _ionicDir = 'tool/i18n/ionic';
final _fragmentsDir = 'lib/l10n/fragments';
final _outDir = 'lib/l10n';

void main(List<String> args) {
  if (args.length == 2 && args[0] == '--lookup') {
    final key = args[1];
    final arbKey = toArbKey(key);
    stdout.writeln('$key -> $arbKey   (context.l10n.$arbKey)');
    final de = _flattenSources('de');
    if (de.containsKey(key)) stdout.writeln('de: ${de[key]}');
    return;
  }
  if (args.length == 2 && args[0] == '--find') {
    final needle = args[1].toLowerCase();
    final de = _flattenSources('de');
    de.forEach((k, v) {
      if (v.toLowerCase().contains(needle)) {
        stdout.writeln('${toArbKey(k).padRight(48)} $k  =  $v');
      }
    });
    return;
  }
  if (args.length == 2 && args[0] == '--ionic') {
    for (final lang in languages) {
      File('${args[1]}/$lang.json').copySync('$_ionicDir/$lang.json');
    }
    stdout.writeln('Ionic snapshot refreshed from ${args[1]}');
  } else if (args.isNotEmpty) {
    stderr.writeln('Unknown arguments: $args');
    exit(64);
  }

  final sources = {for (final l in languages) l: _flattenSources(l)};
  final template = sources[templateLanguage]!;

  // Reject key collisions after camelCase mapping.
  final byArbKey = <String, String>{};
  for (final key in template.keys) {
    final arbKey = toArbKey(key);
    final other = byArbKey[arbKey];
    if (other != null) {
      stderr.writeln('Key collision: "$other" and "$key" both map to $arbKey');
      exit(1);
    }
    byArbKey[arbKey] = key;
  }

  final sortedArbKeys = byArbKey.keys.toList()..sort();
  for (final lang in languages) {
    final messages = sources[lang]!;
    final arb = <String, Object>{'@@locale': lang};
    var missing = 0;
    for (final arbKey in sortedArbKeys) {
      final key = byArbKey[arbKey]!;
      final templateMsg = convertMessage(template[key]!);
      var raw = messages[key];
      if (raw == null) {
        missing++;
        if (lang != templateLanguage) continue; // gen-l10n falls back to de
      }
      var msg = convertMessage(raw!);
      if (lang != templateLanguage &&
          !templateMsg.placeholders.keys.toSet().containsAll(msg.placeholders.keys)) {
        stderr.writeln('[$lang] $key uses placeholders not in de; using de text');
        msg = templateMsg;
      }
      arb[arbKey] = msg.text;
      if (lang == templateLanguage) {
        arb['@$arbKey'] = {
          'description': key,
          if (msg.placeholders.isNotEmpty)
            'placeholders': {
              for (final e in msg.placeholders.entries)
                e.key: e.value ? {'type': 'num'} : <String, Object>{},
            },
        };
      }
    }
    const encoder = JsonEncoder.withIndent('  ');
    File('$_outDir/app_$lang.arb').writeAsStringSync('${encoder.convert(arb)}\n');
    stdout.writeln('app_$lang.arb: ${sortedArbKeys.length - missing} messages'
        '${missing > 0 ? ' ($missing missing, fall back to de)' : ''}');
  }
}

/// "settings.language.title" -> "settingsLanguageTitle"
String toArbKey(String dotted) {
  final parts = dotted.split('.');
  final b = StringBuffer(parts.first);
  for (final p in parts.skip(1)) {
    if (p.isEmpty) continue;
    b.write(p[0].toUpperCase());
    b.write(p.substring(1));
  }
  return b.toString();
}

Map<String, String> _flattenSources(String lang) {
  final result = <String, String>{};
  final ionic = jsonDecode(File('$_ionicDir/$lang.json').readAsStringSync());
  _flatten(ionic as Map<String, dynamic>, '', result, 'ionic/$lang.json');

  final dir = Directory(_fragmentsDir);
  if (dir.existsSync()) {
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final part = json[lang];
      if (part == null) continue;
      final fragment = <String, String>{};
      _flatten(part as Map<String, dynamic>, '', fragment, f.path);
      for (final e in fragment.entries) {
        if (result.containsKey(e.key)) {
          stderr.writeln('${f.path}: key "${e.key}" already exists '
              '(Ionic or another fragment). Reuse it or pick a new key.');
          exit(1);
        }
        result[e.key] = e.value;
      }
    }
  }
  return result;
}

void _flatten(Map<String, dynamic> map, String prefix, Map<String, String> out,
    String source) {
  map.forEach((k, v) {
    final key = prefix.isEmpty ? k : '$prefix.$k';
    if (v is Map<String, dynamic>) {
      _flatten(v, key, out, source);
    } else if (v is String) {
      out[key] = v;
    } else {
      stderr.writeln('$source: $key is not a string');
      exit(1);
    }
  });
}

class ConvertedMessage {
  ConvertedMessage(this.text, this.placeholders);
  final String text;

  /// placeholder name -> used as plural selector
  final Map<String, bool> placeholders;
}

/// Walks an ICU message, collects placeholders and replaces `#` in plural
/// branches with `{selector}`.
ConvertedMessage convertMessage(String input) {
  final placeholders = <String, bool>{};
  final out = StringBuffer();
  var i = 0;
  late final void Function() parseArgument;

  // Parses text until an unmatched '}' (or end). [pluralVar] is the selector
  // of the enclosing plural branch, if any.
  void parseText(String? pluralVar) {
    while (i < input.length) {
      final c = input[i];
      if (c == '}') return;
      if (c == '#' && pluralVar != null) {
        out.write('{$pluralVar}');
        i++;
        continue;
      }
      if (c == '{') {
        parseArgument();
        continue;
      }
      out.write(c);
      i++;
    }
  }

  parseArgument = () {
    // at '{'
    final close = input.indexOf('}', i);
    final comma = input.indexOf(',', i);
    if (comma == -1 || (close != -1 && close < comma)) {
      // simple {name}
      final name = input.substring(i + 1, close).trim();
      placeholders.putIfAbsent(name, () => false);
      out.write('{$name}');
      i = close + 1;
      return;
    }
    final name = input.substring(i + 1, comma).trim();
    final comma2 = input.indexOf(',', comma + 1);
    final kind = input.substring(comma + 1, comma2).trim();
    if (kind != 'plural' && kind != 'select') {
      throw FormatException('Unsupported ICU argument "$kind" in: $input');
    }
    if (kind == 'plural') placeholders[name] = true;
    placeholders.putIfAbsent(name, () => false);
    out.write('{$name, $kind,');
    i = comma2 + 1;
    // branches: selector {text} ...
    while (i < input.length) {
      // copy selector & whitespace up to '{' or the closing '}'
      while (i < input.length && input[i] != '{' && input[i] != '}') {
        out.write(input[i]);
        i++;
      }
      if (i >= input.length) break;
      if (input[i] == '}') {
        out.write('}');
        i++;
        return;
      }
      out.write('{');
      i++;
      parseText(kind == 'plural' ? name : null);
      out.write('}');
      i++; // branch '}'
    }
  };

  parseText(null);
  if (i < input.length) {
    throw FormatException('Unbalanced braces in: $input');
  }
  return ConvertedMessage(out.toString(), placeholders);
}
