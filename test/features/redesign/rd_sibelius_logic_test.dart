import 'dart:io';

import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/redesign/data/rd_work_files_logic.dart';
import 'package:attendix/features/redesign/data/sibelius/rd_sibelius_logic.dart';
import 'package:flutter_test/flutter_test.dart';

SongFile _file(String name, {String? storageName, String url = 'https://x/songs/1/2/a.pdf'}) =>
    SongFile(fileName: name, fileType: '', url: url, storageName: storageName);

void main() {
  test('Sibelius scores are recognised by name, storage name or URL', () {
    expect(rdIsSibeliusFile(_file('06 Ich weiß.SIB')), isTrue);
    expect(rdIsSibeliusFile(_file('Partitur', storageName: 'Partitur_123.sib')), isTrue);
    expect(rdIsSibeliusFile(_file('Partitur', url: 'https://x/songs/1/2/p_1.sib?t=1')), isTrue);
    expect(rdIsSibeliusFile(_file('06 Viola.pdf')), isFalse);
  });

  test('work folders are safe path segments', () {
    expect(rdSibeliusWorkFolder(number: 1, name: 'Ich weiß / an wen: ich glaube'), '1 Ich weiß - an wen- ich glaube');
    expect(rdSafePathSegment('..  '), 'Werk');
    expect(rdSafePathSegment('a' * 120).length, 80);
    expect(rdSibeliusCopyName('Lied.sib', '(aus Sibelius)'), 'Lied (aus Sibelius).sib');
    expect(rdSafePathSegment('${'a' * 100}.sib'), endsWith('.sib'));
    expect(rdSibeliusAttemptName('Ich weiß.sib', 5), 'Ich-wei_5.sib');
    expect(rdSibeliusAttemptName('Partitur', 5), 'Partitur_5.sib');
  });

  test('failed uploads are tried again soon, then every minute', () {
    expect([for (var n = 0; n <= 4; n++) rdSibeliusRetryDelay(n).inSeconds], [0, 15, 30, 60, 60]);
  });

  test('the real home is found from the sandbox container', () {
    expect(rdRealHome('/Users/leon/Library/Containers/io.stephanus.attendix/Data/Downloads'), '/Users/leon');
    expect(rdRealHome('/Users/leon/Downloads/Attendix'), '/Users/leon');
    expect(
      rdSibeliusPluginsFolder('/Users/leon'),
      '/Users/leon/Library/Application Support/Avid/Sibelius/Plugins',
    );
  });

  test('only part PDFs newer than the last ones taken are offered', () {
    final entries = {'/w/Stimmen/Viola.pdf': 200, '/w/Stimmen/Harfe.pdf': 300, '/w/Stimmen/alt.pdf': 100, '/w/Stimmen/x.txt': 400};
    expect(rdNewPartPdfs(entries, 150), ['/w/Stimmen/Harfe.pdf', '/w/Stimmen/Viola.pdf']);
  });

  test('stored copies survive a restart', () {
    const checkout = RdSibeliusCheckout(
      path: '/Users/leon/Downloads/Attendix/Sinfo/1 Lied/Lied.sib',
      tenantId: 42,
      songId: 7,
      userId: 'u1',
      url: 'https://x/songs/42/7/Lied_123.sib',
      storageName: 'Lied_123.sib',
      fileName: 'Lied.sib',
      note: 'Sibelius',
      hash: 'abc',
      modified: 1000,
      failedModified: 2000,
      failedAt: 3000,
      failCount: 2,
      attempts: ['Lied_9.sib'],
    );
    final restored = rdSibeliusStateFromJson(rdSibeliusStateJson([checkout], {'/f/Stimmen': 5}));
    expect(restored.checkouts.single.toJson(), checkout.toJson());
    expect(restored.partsSince, {'/f/Stimmen': 5});
    expect(rdSibeliusStateFromJson('kaputt').checkouts, isEmpty);
    expect(checkout.matches(42, 7, _file('Lied.sib', storageName: 'Lied_123.sib', url: 'https://other')), isTrue);
    expect(checkout.matches(43, 7, _file('Lied.sib', storageName: 'Lied_123.sib')), isFalse);
    // A try whose answer got lost is still the same file.
    expect(checkout.matches(42, 7, _file('Lied.sib', storageName: 'Lied_9.sib', url: 'https://new')), isTrue);
  });

  test('the plug-in is stored as UTF-16 BE and exports the parts separately', () {
    final source = rdSibeliusPluginFor(rdAttendixAppPath('/Applications/Attendix.app/Contents/MacOS/Attendix'));
    final bytes = rdSibeliusPluginBytes(source);
    expect(bytes.sublist(0, 2), [0xFE, 0xFF]);
    final units = [for (var i = 2; i < bytes.length; i += 2) (bytes[i] << 8) | bytes[i + 1]];
    expect(String.fromCharCodes(units), source);
    // Brings this app to the front; a path that would break the string is not used.
    expect(source, contains('_App "/Applications/Attendix.app"'));
    expect(rdAttendixAppPath('/Users/a/Te"st/Attendix.app/Contents/MacOS/Attendix'), rdAttendixAppDefaultPath);
    expect(rdAttendixAppPath('/usr/bin/dart'), rdAttendixAppDefaultPath);
    // Parts only, one PDF per part, into the folder Attendix watches.
    expect(rdSibeliusPluginSource, contains("ExportPartsAsPDF(folder & Sibelius.PathSeparator & '%p.pdf', False, 0, False)"));
    expect(rdSibeliusPluginSource, contains('_Subfolder "$rdSibeliusPartsFolder"'));
    // Method bodies are double-quoted strings: no plain double quote inside.
    final run = RegExp(r'Run "\(\) \{(.*?)\}"\n', dotAll: true).firstMatch(rdSibeliusPluginSource)!.group(1)!;
    expect(run.contains('"'), isFalse);
  });

  test('each exported part replaces only its own PDF', () {
    SongFile pdf(String name, int? id) =>
        SongFile(fileName: name, fileType: 'application/pdf', url: 'u/$name', instrumentId: id);
    final v1 = pdf('05 Violine I.pdf', 7);
    final v2 = pdf('05korrigi Violine II.pdf', 7);
    final v3 = pdf('05korrigi Violine III.pdf', 7);
    final fl = pdf('05 Querflöte.pdf', 8);
    final kl = pdf('05 Klarinette 1.pdf', 9);
    final existing = [
      v1,
      v2,
      v3,
      fl,
      kl,
      SongFile(fileName: 'Violine.mp3', fileType: 'audio/mpeg', url: 'a', instrumentId: 7),
    ];
    expect(
      rdPartReplacements([
        (name: 'Violine III.pdf', instrumentId: 7, note: null),
        (name: 'Violine I.pdf', instrumentId: 7, note: null),
        (name: 'Violine II.pdf', instrumentId: 7, note: null),
        (name: 'Flöte.pdf', instrumentId: 8, note: null),
        (name: 'Klarinette in B.pdf', instrumentId: 9, note: null),
        (name: 'Violine IV.pdf', instrumentId: 7, note: null),
        (name: 'Pauken.pdf', instrumentId: null, note: null),
      ], existing),
      [v3, v1, v2, fl, kl, null, null],
    );
    // Own part first in the list of what it may replace.
    expect(rdPartReplaceOptions((name: 'Flöte.pdf', instrumentId: 8, note: null), existing).first, fl);
  });

  test('replacing a file keeps the tenant filter on every query', () {
    final source = File('lib/core/services/song_file_service.dart').readAsStringSync();
    final start = source.indexOf('Future<SongFile?> _replaceFileContent(');
    final body = source.substring(start, source.indexOf('/// Rename a file', start));
    final queries = ".from('songs')".allMatches(body).length;
    expect(queries, 3);
    expect(RegExp(r"\.eq\('tenantId', tenantId\)").allMatches(body).length, queries);
    expect(body, contains("'songs/\$tenantId/\$songId/"));
  });
}
