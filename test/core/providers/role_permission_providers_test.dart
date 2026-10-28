import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/files_providers.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/utils/person_matcher.dart';
import 'package:attendix/data/models/role_permission/tenant_role_permission.dart';
import 'package:attendix/data/models/storage/storage_entry.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/data/repositories/extra_fields_repository.dart';
import 'package:attendix/data/repositories/files_repository.dart';
import 'package:attendix/features/settings/presentation/pages/extra_fields_page.dart';
import 'package:attendix/features/settings/presentation/pages/files_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:attendix/core/providers/debug_providers.dart' show effectiveRoleProvider;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rollenberechtigungen', () {
    const helperPerm = TenantRolePermission(
      tenantId: 1,
      role: 4,
      attendanceAllGroups: false,
      attendanceCreate: false,
      playerNotesView: true,
      checklistView: false,
    );

    test('fromJson liest snake_case-Spalten', () {
      final p = TenantRolePermission.fromJson({
        'id': 3,
        'tenant_id': 42,
        'role': 4,
        'attendance_all_groups': false,
        'attendance_create': false,
        'player_notes_view': true,
        'checklist_view': true,
        'player_self_pause': true,
        'player_planned_absence': true,
      });
      expect(p.tenantId, 42);
      expect(p.attendanceAllGroups, isFalse);
      expect(p.playerSelfPause, isTrue);
      expect(p.toUpdatePayload().containsKey('tenant_id'), isFalse);
    });

    test('Admin/Verantwortliche dürfen immer Anwesenheiten erstellen', () {
      expect(canCreateAttendanceFor(Role.admin, helperPerm), isTrue);
      expect(canCreateAttendanceFor(Role.responsible, null), isTrue);
    });

    test('Helfer abhängig von attendance_create, Viewer nie', () {
      expect(canCreateAttendanceFor(Role.helper, helperPerm), isFalse);
      expect(canCreateAttendanceFor(Role.helper, null), isTrue);
      expect(canCreateAttendanceFor(Role.viewer, null), isFalse);
    });

    // SOL_FIX2: nicht bestätigte Berechtigungen = verweigert
    test('Helfer dürfen ohne bestätigte Berechtigungen nicht anlegen', () {
      expect(canCreateAttendanceFor(Role.helper, null, permissionsConfirmed: false), isFalse);
      expect(canCreateAttendanceFor(Role.voiceLeaderHelper, null, permissionsConfirmed: false), isFalse);
      expect(canCreateAttendanceFor(Role.admin, null, permissionsConfirmed: false), isTrue);
    });

    test('permissionsConfirmed unterscheidet loading/error/data', () {
      expect(permissionsConfirmed(const AsyncValue.loading()), isFalse);
      expect(permissionsConfirmed(AsyncValue.error('x', StackTrace.empty)), isFalse);
      expect(permissionsConfirmed(const AsyncValue.data([])), isTrue);
      // Reload mit Wert der vorherigen Instanz
      expect(
        permissionsConfirmed(const AsyncLoading<List<TenantRolePermission>>()
            .copyWithPrevious(const AsyncData([helperPerm]))),
        isFalse,
      );
    });

    test('Gruppen-Scope: fehlendes Profil/Gruppe = kein Zugriff', () {
      expect(attendanceGroupScopeFor(Role.helper, helperPerm, null), const AttendanceGroupScope.denied());
      expect(attendanceGroupScopeFor(Role.helper, helperPerm, 7), const AttendanceGroupScope.group(7));
      expect(attendanceGroupScopeFor(Role.helper, null, null), const AttendanceGroupScope.all());
      expect(attendanceGroupScopeFor(Role.admin, helperPerm, null), const AttendanceGroupScope.all());
      const denied = AttendanceGroupScope.denied();
      expect(denied.allowsGroup(7), isFalse);
      expect(denied.allowsGroup(null), isFalse);
      expect(const AttendanceGroupScope.group(7).allowsGroup(8), isFalse);
      expect(const AttendanceGroupScope.all().allowsGroup(null), isTrue);
    });

    test('resolvedGroupScope: loading/error = verweigert', () {
      expect(resolvedGroupScope(const AsyncValue.loading()).denied, isTrue);
      expect(resolvedGroupScope(AsyncValue.error('x', StackTrace.empty)).denied, isTrue);
      expect(resolvedGroupScope(const AsyncValue.data(AttendanceGroupScope.all())).isAll, isTrue);
    });

    test('Gruppen-Scope-Provider wartet auf Berechtigungen (Fehler → Fehler)', () async {
      final container = ProviderContainer(overrides: [
        effectiveRoleProvider.overrideWithValue(Role.helper),
        rolePermissionsProvider.overrideWith((ref) async => throw Exception('offline')),
      ]);
      addTearDown(container.dispose);
      expect(resolvedGroupScope(container.read(attendanceGroupScopeProvider)).denied, isTrue);
      await expectLater(container.read(attendanceGroupScopeProvider.future), throwsException);
      expect(resolvedGroupScope(container.read(attendanceGroupScopeProvider)).denied, isTrue);
      expect(container.read(canCreateAttendanceProvider), isFalse);
      expect(await confirmCanCreateAttendance(() => container.read(canCreateAttendanceConfirmedProvider.future)), isFalse);
    });

    test('Notizen/Checkliste nur für Helfer eingeschränkt', () {
      expect(canViewAttendanceNotesFor(Role.helper, helperPerm), isTrue);
      expect(canViewAttendanceChecklistFor(Role.helper, helperPerm), isFalse);
      expect(canViewAttendanceChecklistFor(Role.helper, null), isFalse);
      expect(canViewAttendanceChecklistFor(Role.admin, null), isTrue);
    });

    test('Gruppen-Einschränkung nur für Helfer ohne "Alle Gruppen"', () {
      expect(restrictToOwnGroupFor(Role.helper, helperPerm), isTrue);
      expect(restrictToOwnGroupFor(Role.helper, null), isFalse);
      expect(restrictToOwnGroupFor(Role.admin, helperPerm), isFalse);
    });

    test('Dateiablage-Zugriff wie files_bucket_policies.sql', () {
      expect(canAccessFilesFor(Role.helper, filesShared: false), isTrue);
      expect(canAccessFilesFor(Role.voiceLeaderHelper, filesShared: false), isTrue);
      expect(canAccessFilesFor(Role.player, filesShared: false), isFalse);
      expect(canAccessFilesFor(Role.player, filesShared: true), isTrue);
      expect(canAccessFilesFor(Role.applicant, filesShared: true), isFalse);
      expect(canAccessFilesFor(Role.none, filesShared: true), isFalse);
      expect(canEditFilesFor(Role.helper), isFalse);
      expect(canEditFilesFor(Role.responsible), isTrue);
    });
  });

  group('Dateiablage', () {
    test('sanitizeFileName transliteriert und bereinigt', () {
      expect(FilesRepository.sanitizeFileName('Größe & Übung.PDF'), 'Groesse und Uebung.pdf');
      expect(FilesRepository.sanitizeFileName('Привет.mp3'), 'Privet.mp3');
      expect(FilesRepository.sanitizeFileName('a/b:c?.txt'), 'a b-c.txt');
      expect(FilesRepository.sanitizeFileName('CON'), 'CON-file');
      expect(FilesRepository.sanitizeFileName('.txt'), 'txt');
    });

    test('normalizeRelativePath', () {
      expect(FilesRepository.normalizeRelativePath(r'\a//b/'), 'a/b');
      expect(FilesRepository.parentPath('a/b/c.pdf'), 'a/b');
      expect(FilesRepository.nameFromPath('a/b/c.pdf'), 'c.pdf');
    });

    test('formatFileSize', () {
      expect(formatFileSize(500), '500 B');
      expect(formatFileSize(1536), '1.5 KB');
      expect(formatFileSize(5368709120), '5.0 GB');
    });

    test('Suche mit typ: und datum: Filtern', () {
      final pdf = StorageEntry(name: 'Protokoll.pdf', path: 'Protokoll.pdf', isFolder: false, updatedAt: DateTime(2026, 3, 3));
      final folder = const StorageEntry(name: 'Noten', path: 'Noten', isFolder: true);
      expect(FilesSearch.matches(pdf, FilesSearch.parse('protokoll typ:pdf datum:2026')), isTrue);
      expect(FilesSearch.matches(pdf, FilesSearch.parse('datum:03.2026')), isTrue);
      expect(FilesSearch.matches(pdf, FilesSearch.parse('typ:ordner')), isFalse);
      expect(FilesSearch.matches(folder, FilesSearch.parse('typ:ordner')), isTrue);
    });

    test('Sortierung: Ordner zuerst', () {
      final entries = [
        const StorageEntry(name: 'b.pdf', path: 'b.pdf', isFolder: false, size: 1),
        const StorageEntry(name: 'z', path: 'z', isFolder: true),
        const StorageEntry(name: 'a.pdf', path: 'a.pdf', isFolder: false, size: 9),
      ];
      final sorted = FilesSearch.sort(entries, FilesSortBy.size, false);
      expect(sorted.map((e) => e.name), ['z', 'a.pdf', 'b.pdf']);
    });
  });

  group('Zusatzfelder', () {
    test('ID aus Name', () {
      expect(extraFieldIdFromName('Mein Feld!'), 'mein_feld');
    });

    test('Standardwerte wie Ionic', () {
      expect(extraFieldDefaultValue('select', options: ['A', 'B']), 'A');
      expect(extraFieldDefaultValue('boolean'), isTrue);
      expect(extraFieldDefaultValue('number'), 0);
      expect(extraFieldDefaultValue('text', defaultValue: 'x'), 'x');
    });

    test('Validierung', () {
      expect(validateExtraFields(const [ExtraField(id: 'a', name: 'A', type: 'select', options: [])]), isNotNull);
      expect(validateExtraFields(const [ExtraField(id: 'a', name: 'A', type: 'text')]), isNull);
    });

    test('JSON behält visibleToPlayers/displayMode', () {
      final json = extraFieldToJson(const ExtraField(
        id: 'a', name: 'A', type: 'text', visibleToPlayers: true, editableByPlayers: true, displayMode: 'underneath'));
      expect(json['visibleToPlayers'], isTrue);
      expect(json['displayMode'], 'underneath');
      expect(ExtraField.fromJson(json).editableByPlayers, isTrue);
    });
  });

  group('Personen-Matcher', () {
    PersonLike id(PersonLike p) => p;

    test('normalizeName', () {
      expect(normalizeName('Müller'), 'mueller');
      expect(normalizeName('  José  '), 'jose');
    });

    test('findet vertauschte Namen und gleiche Geburtstage', () {
      const query = PersonLike(firstName: 'Anna', lastName: 'Schmidt', birthday: '2000-05-01');
      final matches = rankCandidates<PersonLike>(query, const [
        PersonLike(firstName: 'Schmidt', lastName: 'Anna'),
        PersonLike(firstName: 'Anna', lastName: 'Schmidt', birthday: '2000-05-01'),
        PersonLike(firstName: 'Bernd', lastName: 'Schmidt'),
      ], id, threshold: 0.85);
      // "Bernd Schmidt" fällt raus (Vorname passt nicht)
      expect(matches.length, 2);
      expect(matches.first.score, 1.0);
      expect(matches.first.reason, 'Gleicher Geburtstag');
      expect(matches.last.reason, 'Vor-/Nachname vertauscht');
    });
  });
}
