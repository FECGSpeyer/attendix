// SOL_FIX16: folder listings of the file storage are paged. Before, every
// listing stopped after 1000 entries, so recursive delete / move / rename
// of a large folder handled only part of it and still reported success.
import 'dart:io';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/data/repositories/files_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../mocks/supabase_mocks.dart';

class _MockStorage extends Mock implements SupabaseStorageClient {}

class _MockFileApi extends Mock implements StorageFileApi {}

const _tenantId = 7;

FileObject _file(String name) => FileObject.fromJson({
      'name': name,
      'metadata': {'size': 1},
    });

FileObject _folder(String name) => FileObject.fromJson({'name': name});

void main() {
  late _MockFileApi api;
  late Map<String, List<FileObject>> tree;
  late List<({String path, int? offset, int? limit})> listCalls;
  late List<List<String>> removed;
  late List<(String, String)> moved;
  late FilesRepository repo;

  setUpAll(() {
    registerFallbackValue(const SearchOptions());
  });

  setUp(() {
    api = _MockFileApi();
    tree = {};
    listCalls = [];
    removed = [];
    moved = [];
    when(() => api.list(
          path: any(named: 'path'),
          searchOptions: any(named: 'searchOptions'),
        )).thenAnswer((inv) async {
      final path = inv.namedArguments[#path] as String;
      final options = inv.namedArguments[#searchOptions] as SearchOptions;
      listCalls.add((path: path, offset: options.offset, limit: options.limit));
      final all = tree[path] ?? const <FileObject>[];
      final from = options.offset ?? 0;
      final to = (from + (options.limit ?? 100)).clamp(0, all.length);
      return from >= all.length ? <FileObject>[] : all.sublist(from, to);
    });
    when(() => api.remove(any())).thenAnswer((inv) async {
      removed.add(List<String>.from(inv.positionalArguments.first as List));
      return <FileObject>[];
    });
    when(() => api.move(any(), any())).thenAnswer((inv) async {
      moved.add((inv.positionalArguments[0] as String, inv.positionalArguments[1] as String));
      return 'ok';
    });

    final storage = _MockStorage();
    when(() => storage.from(FilesRepository.bucket)).thenReturn(api);
    final supabase = MockSupabaseClient();
    when(() => supabase.storage).thenReturn(storage);

    final container = ProviderContainer(overrides: [
      supabaseClientProvider.overrideWithValue(supabase),
    ]);
    addTearDown(container.dispose);
    repo = container.read(filesRepositoryProvider)..bindTenantId(_tenantId);
  });

  List<FileObject> files(String prefix, int count) =>
      [for (var i = 0; i < count; i++) _file('$prefix${i.toString().padLeft(5, '0')}.pdf')];

  test('listEntries pages through all entries of a folder', () async {
    tree['7/Noten'] = files('n', 2500);
    final entries = await repo.listEntries('Noten');
    expect(entries.length, 2500);
    expect(listCalls.map((c) => c.offset), [0, 1000, 2000]);
    expect(listCalls.map((c) => c.limit).toSet(), {1000});
    expect(listCalls.map((c) => c.path).toSet(), {'7/Noten'});
  });

  test('an exact multiple of the page size fetches one empty page more', () async {
    tree['7'] = files('r', 1000);
    expect((await repo.listEntries()).length, 1000);
    expect(listCalls.map((c) => c.offset), [0, 1000]);
  });

  test('deleting a large folder removes every file, nested ones too', () async {
    tree['7/Archiv'] = [_folder('Alt'), ...files('a', 1499), _file('.keep')];
    tree['7/Archiv/Alt'] = files('b', 1200);
    await repo.deleteEntry('Archiv', isFolder: true);

    final keys = removed.expand((chunk) => chunk).toList();
    expect(keys.length, 1499 + 1 + 1200);
    expect(keys.toSet().length, keys.length);
    expect(keys.every((k) => k.startsWith('7/Archiv/')), isTrue);
    expect(keys, contains('7/Archiv/Alt/b01199.pdf'));
    expect(removed.every((chunk) => chunk.length <= 100), isTrue);
  });

  test('moving and renaming a large folder moves every file', () async {
    tree['7/Proben'] = files('p', 1234);
    await repo.moveEntry('Proben', 'Archiv', isFolder: true);
    expect(moved.length, 1234);
    expect(moved.last, ('7/Proben/p01233.pdf', '7/Archiv/Proben/p01233.pdf'));

    moved.clear();
    await repo.renameEntry('Proben', 'Konzert', isFolder: true);
    expect(moved.length, 1234);
    expect(moved.first, ('7/Proben/p00000.pdf', '7/Konzert/p00000.pdf'));
  });

  test('a failing page fails the operation before anything is changed', () async {
    tree['7/Gross'] = files('g', 1500);
    when(() => api.list(
          path: any(named: 'path'),
          searchOptions: any(named: 'searchOptions'),
        )).thenAnswer((inv) async {
      final options = inv.namedArguments[#searchOptions] as SearchOptions;
      if ((options.offset ?? 0) > 0) {
        throw const StorageException('timeout', statusCode: '500');
      }
      return tree['7/Gross']!.sublist(0, 1000);
    });

    await expectLater(repo.deleteEntry('Gross', isFolder: true), throwsA(anything));
    await expectLater(repo.moveEntry('Gross', 'X', isFolder: true), throwsA(anything));
    await expectLater(repo.listEntries('Gross'), throwsA(anything));
    expect(removed, isEmpty);
    expect(moved, isEmpty);
  });

  test('a server that ignores the offset fails instead of looping', () async {
    final page = files('x', 3);
    await expectLater(
      FilesRepository.listAllPages((_) async => page, pageSize: 3),
      throwsStateError,
    );
  });

  test('every listing goes through the paged helper', () {
    final source = File('lib/data/repositories/files_repository.dart').readAsStringSync();
    expect(RegExp(r'_storage\s*\.list\(').allMatches(source).length, 1);
    final listRaw = source.substring(source.indexOf('Future<List<FileObject>> _listRaw('));
    expect(listRaw.substring(0, listRaw.indexOf('\n  }\n')), contains('listAllPages('));
    expect(listRaw, contains('_assertOwnPrefix(prefix)'));
  });
}
