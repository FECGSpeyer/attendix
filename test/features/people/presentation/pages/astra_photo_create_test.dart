import 'dart:io';
import 'dart:typed_data';

import 'package:attendix/core/providers/church_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/parent_providers.dart';
import 'package:attendix/core/providers/shift_providers.dart';
import 'package:attendix/core/providers/teacher_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/features/people/presentation/pages/person_create_page.dart';
import 'package:attendix/features/people/presentation/widgets/person_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

/// ASTRA_PHOTO: Ionic person.page lets the user pick a Passbild while
/// creating a person; it is uploaded after the insert (db.addPlayer).
class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref);

  @override
  Tenant? build() => null;

  @override
  Future<void> setTenant(Tenant? tenant) async {}

  @override
  Future<void> loadFromPrefs() async {}
}

Widget _app(PersonImagePicker picker) => ProviderScope(
      overrides: [
        currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
        groupsProvider.overrideWith((ref) async => const []),
        churchesProvider.overrideWith((ref) async => const []),
        teachersProvider.overrideWith((ref) async => const []),
        parentsProvider.overrideWith((ref) async => const []),
        shiftsProvider.overrideWith((ref) async => const []),
        personImagePickerProvider.overrideWithValue(picker),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const PersonCreatePage(),
      ),
    );

String _read(String path) => File(path).readAsStringSync();

Finder _avatarImage() => find.descendant(
      of: find.byKey(const Key('person_create_avatar')),
      matching: find.byType(Image),
    );

void main() {
  group('ASTRA_PHOTO create page avatar', () {
    testWidgets('placeholder is tappable and opens the picker', (tester) async {
      var calls = 0;
      await tester.pumpWidget(_app(() async {
        calls++;
        return XFile.fromData(Uint8List.fromList(List.filled(64, 1)),
            name: 'a.jpg');
      }));
      await tester.pump();

      expect(_avatarImage(), findsNothing);
      await tester.tap(find.byKey(const Key('person_create_avatar')));
      await tester.pump();
      await tester.pump();

      expect(calls, 1);
      // Preview of the picked bytes replaces the placeholder.
      expect(_avatarImage(), findsOneWidget);

      // With a picture, the avatar offers replace / remove (Ionic viewer).
      await tester.tap(find.byKey(const Key('person_create_avatar')));
      await tester.pumpAndSettle();
      expect(find.text('Ersetzen'), findsOneWidget);
      expect(find.text('Entfernen'), findsOneWidget);
    });

    testWidgets('picture over 2 MB is rejected with the Ionic toast',
        (tester) async {
      await tester.pumpWidget(_app(() async => XFile.fromData(
          Uint8List(kPersonImageMaxBytes + 1),
          name: 'big.jpg')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('person_create_avatar')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Das Bild darf maximal 2MB groß sein.'), findsOneWidget);
      expect(_avatarImage(), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

  group('ASTRA_PHOTO upload (source analysis)', () {
    final repo = _read('lib/data/repositories/player_repository.dart');

    test('updateImage uses the Ionic key and filters id AND tenantId', () {
      final start = repo.indexOf('Future<String> updateImage(');
      expect(start, greaterThan(0));
      final body = repo.substring(start, repo.indexOf('\n  }\n', start));
      expect(body, contains('profileImageStoragePath(playerId)'));
      expect(body, contains('SupabaseBuckets.profiles'));
      expect(body, contains('upsert: true'));
      expect(body, contains(".update({'img': publicUrl})"));
      expect(body, contains(".eq('id', playerId)"));
      expect(body, contains(".eq('tenantId', currentTenantId)"));
    });

    test('addPlayer uploads only after a fresh insert and never rethrows', () {
      final start = repo.indexOf('Future<Person> addPlayer(');
      final body = repo.substring(start, repo.indexOf('\n  }\n', start));
      final insert = body.indexOf('result = await createPlayer(person);');
      final upload = body.indexOf('await updateImage(resultId, imageBytes)');
      final attendances = body.indexOf('addPlayerToAttendancesByDate(result)');
      expect(insert, greaterThan(0));
      expect(upload, greaterThan(insert));
      expect(attendances, greaterThan(upload));
      final uploadBlock = body.substring(upload, attendances);
      expect(uploadBlock, contains('catch (e, stack)'));
      expect(uploadBlock, isNot(contains('rethrow')));
    });

    test('create page passes the picked bytes, header shares the upload', () {
      final page = _read(
          'lib/features/people/presentation/pages/person_create_page.dart');
      expect(page, contains('imageBytes: _pickedImage'));
      expect(page, contains('ref.read(personImagePickerProvider)()'));
      final header = _read(
          'lib/features/people/presentation/widgets/person_detail/person_header.dart');
      expect(header, contains('ref.read(personImagePickerProvider)()'));
      expect(header, contains('repo.updateImage(personId, bytes)'));
      expect(header, isNot(contains('ImagePicker()')));
    });
  });
}
