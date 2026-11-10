import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/enums.dart';
import '../../core/providers/cross_tenant_person_providers.dart';
import '../../core/providers/player_providers.dart';
import '../../core/providers/profile_providers.dart';
import '../../core/providers/realtime_providers.dart';
import '../../core/services/tracking/tracking_event.dart';
import '../../core/services/tracking/tracking_service.dart';
import '../../core/utils/dialog_helper.dart';
import '../../core/utils/person_matcher.dart' show RankedMatch;
import '../../core/utils/toast_helper.dart';
import '../../data/models/person/person.dart';
import '../../data/repositories/cross_tenant_person_repository.dart';
import '../../data/repositories/player_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/services/auth_service.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/adaptive/adaptive.dart';

/// Write logic of a person shared by the person pages of the normal app
/// (`PersonCreatePage`, `PersonDetailPage`) and the pages "Neue Person" /
/// "Person bearbeiten" of the new design. Every query runs through the
/// tenant-bound repositories (id + tenantId).

/// Ionic e-mail check (person.page onEmailBlur / updatePlayer).
final personEmailPattern = RegExp(r'^[\w-\.+]+@([\w-]+\.)+[\w-]{2,}$');

bool isValidPersonEmail(String email) => personEmailPattern.hasMatch(email.trim());

/// Ionic dayjs(date).startOf('day').utc(true).toISOString().
String personUtcMidnightIso(DateTime d) => DateTime.utc(d.year, d.month, d.day).toIso8601String();

/// Ionic getOrganisationPersonKey.
String? organisationPersonKey(Person person) {
  final g = person.globalPersonId;
  if (g != null && g.isNotEmpty) return 'global:$g';
  final a = person.appId;
  if (a != null && a.isNotEmpty) return 'app:$a';
  return null;
}

/// One entry of `player.history`.
Map<String, dynamic> personHistoryEntry(PlayerHistoryType type, String text) => {
      'date': DateTime.now().toUtc().toIso8601String(),
      'text': text,
      'type': type.value,
    };

/// Ionic: "Alte Gruppe -> Neue Gruppe" when the group changes.
Map<String, dynamic> personGroupChangeEntry(Map<int, String> groups, int? oldGroupId, int? newGroupId) =>
    personHistoryEntry(
      PlayerHistoryType.instrumentChange,
      '${groups[oldGroupId] ?? 'Unbekannt'} -> ${groups[newGroupId] ?? 'Unbekannt'}',
    );

/// Ionic: the previous note goes to the history when the note changes.
Map<String, dynamic> personNotesChangeEntry(String? oldNotes) =>
    personHistoryEntry(PlayerHistoryType.notes, oldNotes ?? 'Keine Notiz');

/// Ionic: "Mit Person gesprochen" solves a Problemfall.
Map<String, dynamic> personProblemSolvedEntry(String remarks) =>
    personHistoryEntry(PlayerHistoryType.criticalPerson, remarks);

/// Columns written together with a solved Problemfall.
Map<String, dynamic> personProblemSolvedColumns() => {
      'isCritical': false,
      'lastSolve': DateTime.now().toUtc().toIso8601String(),
    };

/// Ionic person.enableVoiceLeader alert. Returns true = save with role,
/// false = status only, null = cancel.
Future<bool?> showVoiceLeaderRoleDialog(BuildContext context, String name) {
  return showAppDialog<bool>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(ctx.l10n.personEnableVoiceLeader),
      content: Text(ctx.l10n.personVoiceLeaderMessage(name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(ctx.l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.l10n.personVoiceLeaderStatusOnly),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.l10n.personSaveWithRole),
        ),
      ],
    ),
  );
}

/// Ionic updatePlayer(): "E-Mail hinzugefügt – Account jetzt erstellen?"
/// with "Abbrechen" (nothing saved) and "Ja".
Future<bool> confirmCreateAccountForNewEmail(BuildContext context) async {
  final create = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(ctx.l10n.personEmailAdded),
      content: Text(ctx.l10n.personCreateAccountNow),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.l10n.commonYes),
        ),
      ],
    ),
  );
  return create == true;
}

/// Ionic continueUpdatingPlayer(): main group ⇄ Verantwortlicher and the
/// Stimmführer roles after a save. Throws when a role write fails.
Future<void> syncPersonRoles(
  AuthService auth, {
  required String appId,
  required int tenantId,
  required int? mainGroupId,
  required int? oldGroupId,
  required int? newGroupId,
  required bool wasLeader,
  required bool isLeader,
  required bool isGeneral,
  required bool assignVoiceLeaderRole,
}) async {
  if (mainGroupId != null &&
      ((oldGroupId != newGroupId && newGroupId == mainGroupId) || oldGroupId == mainGroupId)) {
    final role = await auth.getUserRole(userId: appId, tenantId: tenantId);
    if (role != Role.admin) {
      await auth.updateUserRole(
        userId: appId,
        tenantId: tenantId,
        newRole: newGroupId == mainGroupId ? Role.responsible : Role.player,
      );
    }
  }

  if (isGeneral) return;
  if (assignVoiceLeaderRole) {
    final role = await auth.getUserRole(userId: appId, tenantId: tenantId);
    await auth.updateUserRole(
      userId: appId,
      tenantId: tenantId,
      newRole: role == Role.helper ? Role.voiceLeaderHelper : Role.voiceLeader,
    );
  } else if (wasLeader && !isLeader) {
    final role = await auth.getUserRole(userId: appId, tenantId: tenantId);
    if (role == Role.voiceLeader) {
      await auth.updateUserRole(userId: appId, tenantId: tenantId, newRole: Role.player);
    } else if (role == Role.voiceLeaderHelper) {
      await auth.updateUserRole(userId: appId, tenantId: tenantId, newRole: Role.helper);
    }
  }
}

/// Organisation fields of a person (Ionic getSharedPersonFieldValues):
/// values shared across the instances of an organisation.
class SharedPersonFields {
  const SharedPersonFields({required this.fieldIds, required this.orgId, required this.values});

  /// Ids of the organisation fields (empty: none).
  final Set<String> fieldIds;
  final int? orgId;

  /// Stored shared values of this person.
  final Map<String, dynamic> values;

  static const none = SharedPersonFields(fieldIds: {}, orgId: null, values: {});
}

/// Loads the organisation fields and their shared values. Throws when
/// they cannot be loaded (callers must not save then: the shown defaults
/// would overwrite the real values in every instance).
Future<SharedPersonFields> loadSharedPersonFields(WidgetRef ref, ProfileRepository repo, Person person) async {
  final fields = await ref.read(personExtraFieldsProvider.future);
  final ids = fields.where((f) => f.isOrganisationField).map((f) => f.id).toSet();
  if (ids.isEmpty) return SharedPersonFields.none;
  final orgId = await repo.getOrganisationId();
  final key = organisationPersonKey(person);
  if (orgId == null || key == null) return SharedPersonFields(fieldIds: ids, orgId: orgId, values: const {});
  final shared = await repo.getSharedFieldValues(orgId, key);
  return SharedPersonFields(fieldIds: ids, orgId: orgId, values: shared);
}

/// Ionic continueUpdatingPlayer: organisation field values go to
/// tenant_group_person_fields, the rest is returned for
/// `player.additional_fields`.
Future<Map<String, dynamic>> saveSharedPersonFields(
  ProfileRepository repo, {
  required Map<String, dynamic> values,
  required Set<String> orgFieldIds,
  required int? orgId,
  required String? personKey,
}) async {
  final local = Map<String, dynamic>.from(values);
  if (orgFieldIds.isEmpty || orgId == null || personKey == null) return local;
  final shared = <String, dynamic>{
    for (final id in orgFieldIds)
      if (local.containsKey(id)) id: local.remove(id),
  };
  await repo.updateSharedFieldValues(orgId, personKey, shared);
  return local;
}

/// Ionic addPerson: asks when a person with the same name exists (B3-015),
/// then db.addPlayer(player, Boolean(email), role) – the account is
/// registered right away when an e-mail is set (Verantwortlicher for the
/// main group, else Spieler), the person joins every Termin since the join
/// date, the Passbild is uploaded after the insert. Returns the created
/// person, null when the user cancelled at the duplicate question; throws
/// when saving fails.
///
/// [repo]: the tenant repository bound by the caller before its first await
/// (tenant switch); read from [ref] when null. [createWhenGone]: when the
/// page is gone at the duplicate question, the person is still created
/// (normal app) instead of cancelled.
Future<Person?> createPersonWithChecks(
  BuildContext context,
  WidgetRef ref,
  Person person, {
  required bool isMainGroup,
  Uint8List? imageBytes,
  PlayerRepository? repo,
  bool createWhenGone = false,
}) async {
  // Bind everything before the first await (tenant switch, page closed).
  final PlayerRepository players = repo ?? ref.read(playerRepositoryWithTenantProvider);
  final tracking = ref.read(trackingServiceProvider);
  final container = ProviderScope.containerOf(context, listen: false);
  final existing = await players.findPlayersByName(person.firstName, person.lastName);
  if (existing.isNotEmpty && (context.mounted || !createWhenGone)) {
    if (!context.mounted) return null;
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.peopleFlutterPossibleDuplicate,
      message: context.l10n.peopleFlutterDuplicateMessage('${person.firstName} ${person.lastName}', existing.length),
      confirmText: context.l10n.peopleFlutterCreateAnyway,
      cancelText: context.l10n.commonCancel,
    );
    if (!confirmed) return null;
  }

  final created = await players.addPlayer(
    person,
    register: person.email != null && person.email!.isNotEmpty,
    role: isMainGroup ? Role.responsible : Role.player,
    imageBytes: imageBytes,
  );
  tracking.track(TrackingEvent.playerAdded, properties: {'instrumentId': person.instrument});
  container
    ..invalidate(realtimePlayersProvider)
    ..invalidate(playersProvider);
  return created;
}

/// Ionic searchPerson(): finds the person in a linked instance, takes over
/// the e-mail and links both rows via a shared global_person_id. Returns
/// true when the person was linked; throws when the write fails. Without
/// a match [onNoMatch] reports it (default: an error toast).
Future<bool> searchPersonInOtherInstance(
  BuildContext context,
  WidgetRef ref,
  Person person, {
  required String firstName,
  required String lastName,
  VoidCallback? onNoMatch,
}) async {
  final playerRepo = ref.read(playerRepositoryWithTenantProvider);
  final repo = ref.read(crossTenantPersonRepositoryWithTenantProvider);
  final personId = person.id;
  if (personId == null) return false;
  final List<int> linkedIds;
  final List<RankedMatch<CrossTenantPersonCandidate>> matches;
  try {
    linkedIds = await ref.read(linkedTenantIdsProvider.future);
    matches = await repo.getPossiblePersonsByName(firstName, lastName, linkedTenantIds: linkedIds);
  } catch (_) {
    // Ionic getPossiblePersonsByName: error toast.
    if (context.mounted) ToastHelper.showError(context, context.l10n.dbLoadPeopleFailed);
    return false;
  }
  if (!context.mounted) return false;
  if (matches.isEmpty) {
    if (onNoMatch != null) {
      onNoMatch();
    } else {
      ToastHelper.showError(context, context.l10n.personNoMatchOther);
    }
    return false;
  }

  final chosen = await showAppActionSheet<CrossTenantPersonCandidate>(
    context,
    title: context.l10n.personChooseEntry,
    actions: [
      for (final m in matches)
        AppActionSheetAction(
          value: m.candidate,
          icon: AppIcons.personSearch,
          label: m.candidate.label,
          subtitle: m.reason,
        ),
    ],
  );
  if (chosen == null || !context.mounted) return false;
  final email = chosen.person.email?.trim();
  if (email == null || email.isEmpty) return false;

  final globalId = chosen.person.globalPersonId ?? const Uuid().v4();
  await playerRepo.updatePlayerFields(personId, {
    'email': email,
    'global_person_id': globalId,
  });
  if (chosen.person.globalPersonId == null && chosen.person.id != null) {
    await repo.setGlobalPersonId([chosen.person.id!], globalId, linkedTenantIds: linkedIds);
  }
  return true;
}
