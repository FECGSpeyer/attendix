import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/church_providers.dart';
import '../../../../../core/providers/group_providers.dart';
import '../../../../../core/providers/player_providers.dart';
import '../../../../../core/providers/profile_providers.dart';
import '../../../../../core/providers/realtime_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/providers/user_registration_providers.dart';
import '../../../../../core/services/error_reporter.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/demo_guard.dart';
import '../../../../../core/utils/dialog_helper.dart';
import '../../../../../core/utils/extra_field_utils.dart' show parseExtraFieldNumber;
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../data/repositories/player_repository.dart';
import '../../../../../data/repositories/profile_repository.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../people/person_write.dart' show organisationPersonKey, personUtcMidnightIso;
import '../../../../people/presentation/pages/person_detail_page.dart' show personProvider;
import '../../../../people/presentation/widgets/church_picker_sheet.dart';
import '../../../../people/presentation/widgets/pause_person_sheet.dart' show buildPauseHistoryText;
import '../../../../settings/presentation/pages/left_players_page.dart' show leftPlayersProvider;
import '../../../data/rd_words.dart';
import '../manage/rd_settings_sheets.dart' show showRdChoiceSheet, showRdTextSheet;

/// Runs [change] for every person and counts successes and failures, so
/// one failing row does not stop the rest.
Future<({int ok, int failed})> rdApplyToAll(
  List<Person> persons,
  Future<void> Function(Person person) change,
) async {
  var ok = 0;
  var failed = 0;
  for (final person in persons) {
    try {
      await change(person);
      ok++;
    } catch (_) {
      failed++;
    }
  }
  return (ok: ok, failed: failed);
}

/// REDESIGN: several members at once, from the "Auswählen" mode of the
/// Mitglieder tab (formerly its own page "Mitglieder bearbeiten" in the
/// Verwaltung). Register, Pausieren and Archivieren of that page plus
/// "Feld setzen" (Ionic people/bulk-edit: Notizen and Zusatzfelder; one value
/// for the whole selection). Writes through [PlayerRepository] like the
/// single person page.
mixin RdMemberBulkActions<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Ids of the selected members.
  final Set<int> bulkSelected = {};

  /// A bulk change is running (actions disabled).
  bool bulkBusy = false;

  /// Applies [change] to [persons] and reports the result.
  /// [boundRepo]: a repository the caller read before its own awaits.
  Future<void> _bulkRun(
    List<Person> persons,
    Future<void> Function(PlayerRepository repo, Person p) change, {
    PlayerRepository? boundRepo,
  }) async {
    if (persons.isEmpty || DemoGuard.blocked()) return; // DEMO_GUARD
    final l10n = context.l10n;
    // Bound before the first await (tenant switch safety).
    final PlayerRepository repo = boundRepo ?? ref.read(playerRepositoryWithTenantProvider);
    // The list may still show the previous group's people after a group
    // switch; never touch a person outside the bound tenant.
    persons = persons.where((p) => p.tenantId == repo.currentTenantId).toList();
    if (persons.isEmpty) return;
    setState(() => bulkBusy = true);
    // Bound before the await: the page may be closed while the writes run.
    final container = ProviderScope.containerOf(context, listen: false);
    final result = await rdApplyToAll(persons, (p) => change(repo, p));
    container
      ..invalidate(realtimePlayersProvider)
      ..invalidate(playersProvider)
      ..invalidate(leftPlayersProvider)
      ..invalidate(archivedPlayersProvider)
      ..invalidate(sharedPersonFieldValuesProvider);
    // The person page (and its stats/history, which watch it) of every
    // changed person; personProvider is kept alive and not realtime.
    for (final p in persons) {
      if (p.id != null) container.invalidate(personProvider(p.id!));
    }
    if (!mounted) return;
    setState(() {
      bulkBusy = false;
      bulkSelected.clear();
    });
    if (result.failed > 0) {
      ToastHelper.showError(context, l10n.redesignBulkFailed(result.failed));
    } else {
      ToastHelper.showSuccess(context, l10n.redesignBulkDone(result.ok));
    }
  }

  /// Ionic bulk-edit → syncPlayerWithUpcomingAttendances: a Register or
  /// filter field change adds/removes the person in upcoming Termine. Best
  /// effort: the change itself already succeeded.
  static Future<void> _sync(PlayerRepository repo, Person before, Person after) async {
    try {
      await repo.syncPlayerWithUpcomingAttendances(
        after,
        oldInstrument: before.instrument,
        oldAdditionalFields: before.additionalFields,
      );
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'rd_member_bulk');
    }
  }

  Future<void> bulkMoveToGroup(List<Person> persons) async {
    final l10n = context.l10n;
    // Bound before the first await (tenant switch safety).
    final repo = ref.read(playerRepositoryWithTenantProvider);
    final registration = ref.read(userRegistrationRepositoryWithTenantProvider);
    final mainGroup = ref.read(mainGroupProvider.future);
    final groups = ref.read(groupsProvider).valueOrNull ?? const [];
    final general = ref.read(currentTenantProvider)?.type == 'general';
    final groupId = await showRdChoiceSheet<int>(
      context,
      title: l10n.rdWordsNewGroup(ref.read(rdGroupKindProvider)),
      options: [for (final g in groups) if (g.id != null) (g.id!, g.name)],
    );
    if (groupId == null || !mounted) return;
    final names = {for (final g in groups) g.id: g.name};
    final mainId = (await mainGroup)?.id;
    if (!mounted) return;
    await _bulkRun(boundRepo: repo, persons.where((p) => p.instrument != groupId).toList(), (repo, p) async {
      // Ionic continueUpdatingPlayer (syncPersonRoles): joining or leaving
      // the main group makes the account Verantwortlicher or Spieler (admins
      // stay); a moved Stimmführer loses the Stimmführer role. Both role
      // changes come before the Register change: if one fails the person
      // stays in the old Register (counted as failed, a retry repeats every
      // step); if the Register change fails, the old role is restored.
      final appId = p.appId;
      Role? previousRole;
      try {
        if (appId != null && mainId != null && (groupId == mainId || p.instrument == mainId)) {
          final role = await registration.getTenantUserRole(appId);
          final next = groupId == mainId ? Role.responsible : Role.player;
          if (role != null && role != Role.admin && role != next) {
            await registration.updateTenantUserRole(appId, next);
            previousRole = role;
          }
        }
        if (p.isLeader && appId != null && !general) {
          final role = await registration.getTenantUserRole(appId);
          final next = switch (role) {
            Role.voiceLeader => Role.player,
            Role.voiceLeaderHelper => Role.helper,
            _ => null,
          };
          if (next != null) {
            await registration.updateTenantUserRole(appId, next);
            previousRole ??= role;
          }
        }
        await _changeGroup(repo, p, groupId, names);
      } catch (_) {
        if (appId != null && previousRole != null) {
          try {
            await registration.updateTenantUserRole(appId, previousRole);
          } catch (_) {
            // The failure below is reported; a retry sets the role again.
          }
        }
        rethrow;
      }
      await _sync(repo, p, p.copyWith(instrument: groupId, isLeader: false));
    });
  }

  /// Same history entry as the person page (Instrumentenwechsel).
  static Future<void> _changeGroup(PlayerRepository repo, Person p, int groupId, Map<int?, String> names) =>
      repo.updatePlayerFields(p.id!, {
        'instrument': groupId,
        'isLeader': false,
        'history': [
          ...p.history.map((h) => h.toJson()),
          {
            'date': DateTime.now().toUtc().toIso8601String(),
            'text': '${names[p.instrument] ?? 'Unbekannt'} -> ${names[groupId] ?? 'Unbekannt'}',
            'type': PlayerHistoryType.instrumentChange.value,
          },
        ],
      });

  Future<void> bulkPause(List<Person> persons) async {
    final l10n = context.l10n;
    // Bound before the dialog (tenant switch safety).
    final repo = ref.read(playerRepositoryWithTenantProvider);
    // Already paused members keep their pause (no second entry).
    final targets = persons.where((p) => !p.paused).toList();
    if (targets.isEmpty) {
      ToastHelper.showInfo(context, l10n.redesignBulkAllPaused);
      return;
    }
    final reason = await showRdTextSheet(
      context,
      title: l10n.redesignBulkActionPause,
      hint: l10n.redesignBulkPauseReason,
      required: true,
    );
    if (reason == null || reason.isEmpty) return;
    await _bulkRun(boundRepo: repo, targets, (repo, p) => repo.pausePlayer(p, null, buildPauseHistoryText(reason)));
  }

  Future<void> bulkArchive(List<Person> persons) async {
    final l10n = context.l10n;
    // Bound before the dialog (tenant switch safety).
    final repo = ref.read(playerRepositoryWithTenantProvider);
    // Same confirmation as the other destructive steps of the Beta.
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: l10n.redesignBulkArchiveConfirm(persons.length),
      message: l10n.redesignBulkArchiveHint,
      confirmText: l10n.redesignBulkActionArchive,
      isDestructive: true,
    );
    if (!confirmed) return;
    final today = DateTime.now().toIso8601String();
    await _bulkRun(boundRepo: repo, persons, (repo, p) => repo.archivePlayer(p, today, null));
  }

  /// Ionic people/bulk-edit: one field (Notizen or a Zusatzfeld) gets the
  /// same value for the whole selection. Organisation fields go to the
  /// shared values (tenant_group_person_fields), the rest to the player row.
  Future<void> bulkSetField(List<Person> persons) async {
    final l10n = context.l10n;
    // Bound before the first await (tenant switch safety).
    final repo = ref.read(playerRepositoryWithTenantProvider);
    final profileRepo = ref.read(profileRepositoryWithTenantProvider);
    final List<ProfileExtraField> fields;
    try {
      fields = await ref.read(personExtraFieldsProvider.future);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, l10n.svcLoadSharedFieldsFailed);
      return;
    }
    if (!mounted) return;
    const notesKey = '';
    final key = await showRdChoiceSheet<String>(
      context,
      title: l10n.redesignBulkPickField,
      options: [
        (notesKey, l10n.peopleNotes),
        for (final f in fields) (f.id, f.name),
      ],
    );
    if (key == null || !mounted) return;
    final field = key == notesKey ? null : fields.where((f) => f.id == key).firstOrNull;
    final name = field?.name ?? l10n.peopleNotes;
    final picked = await _pickValue(field, name);
    if (picked == null || !mounted) return;
    final value = picked.value;
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: l10n.redesignBulkFieldConfirm(name, persons.length),
      message: l10n.redesignBulkFieldConfirmHint(picked.label),
      confirmText: l10n.redesignBulkFieldApply,
    );
    if (!confirmed || !mounted) return;

    if (field == null) {
      await _bulkRun(boundRepo: repo, persons, (repo, p) => repo.updatePlayerFields(p.id!, {'notes': value}));
      return;
    }
    int? orgId;
    if (field.isOrganisationField) {
      try {
        orgId = await profileRepo.getOrganisationId();
      } catch (_) {
        if (mounted) ToastHelper.showError(context, l10n.svcLoadSharedFieldsFailed);
        return;
      }
      if (!mounted) return;
    }
    await _bulkRun(boundRepo: repo, persons, (repo, p) async {
      final before = p.additionalFields ?? const <String, dynamic>{};
      final merged = <String, dynamic>{...before, field.id: value};
      final personKey = organisationPersonKey(p);
      // The old value always passed explicitly (missing = default), so the
      // Termin sync sees what changed.
      var old = p.copyWith(additionalFields: {...before, field.id: before[field.id]});
      final org = orgId;
      if (field.isOrganisationField && org != null && personKey != null) {
        // A stored shared value wins over the own one (like the filter);
        // without a shared entry the own value stays the old one.
        final shared = await profileRepo.getSharedFieldValues(org, personKey);
        if (shared.containsKey(field.id)) {
          old = p.copyWith(additionalFields: {...before, field.id: shared[field.id]});
        }
        await profileRepo.updateSharedFieldValues(org, personKey, {field.id: value});
      } else {
        await repo.updatePlayerFields(p.id!, {'additional_fields': merged});
      }
      await _sync(repo, old, p.copyWith(additionalFields: merged));
    });
  }

  /// The value for [field] (null: Notizen) and how it reads; null when the
  /// sheet was closed.
  Future<({dynamic value, String label})?> _pickValue(ProfileExtraField? field, String name) async {
    final l10n = context.l10n;
    switch (field?.type) {
      case 'boolean':
        final v = await showRdChoiceSheet<bool>(
          context,
          title: name,
          options: [(true, l10n.commonYes), (false, l10n.commonNo)],
        );
        return v == null ? null : (value: v, label: v ? l10n.commonYes : l10n.commonNo);
      case 'select':
        final options = field!.options;
        if (options.isEmpty) return null;
        final v = await showRdChoiceSheet<String>(context, title: name, options: [for (final o in options) (o, o)]);
        return v == null ? null : (value: v, label: v);
      case 'bfecg_church':
        final churches = ref.read(churchesProvider).valueOrNull ?? const [];
        final v = await showChurchPickerSheet(context, title: name, churches: churches);
        return v == null ? null : (value: v, label: churchLabel(v, churches));
      case 'date':
        final picked = await showAppDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (picked == null || !mounted) return null;
        return (
          value: personUtcMidnightIso(picked),
          label: MaterialLocalizations.of(context).formatShortDate(picked),
        );
      case 'number':
        final text = await showRdTextSheet(
          context,
          title: name,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        );
        if (text == null) return null;
        final v = parseExtraFieldNumber(text);
        return (value: v, label: v?.toString() ?? l10n.redesignBulkFieldEmpty);
      default:
        // Notizen, Text, Textfeld: an empty value clears the field.
        final multi = field == null || field.type == 'textarea';
        final text = await showRdTextSheet(context, title: name, maxLines: multi ? 6 : 1);
        if (text == null) return null;
        return (value: text, label: text.isEmpty ? l10n.redesignBulkFieldEmpty : '„$text“');
    }
  }
}

/// Dark bar with the selection count and the actions for the selection.
class RdBulkActionBar extends StatelessWidget {
  const RdBulkActionBar({super.key, required this.label, required this.busy, required this.actions});

  final String label;
  final bool busy;

  /// Icon, label, action, destructive.
  final List<(IconData, String, VoidCallback, bool)> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    // A red with contrast on the bar (dark bar in light mode, light bar in
    // dark mode); the soft status red was barely visible on it.
    final dangerColor = p.brightness == Brightness.dark ? const Color(0xFFB42318) : const Color(0xFFFCA5A5);
    return Material(
      color: p.text,
      borderRadius: BorderRadius.circular(16),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Semantics(
                liveRegion: true,
                child: Text(label, style: TextStyle(color: p.bg, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
            Row(
              children: [
                for (final (icon, text, onTap, danger) in actions)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: busy ? null : onTap,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 6),
                            Icon(icon, size: 22, color: danger ? dangerColor : p.bg),
                            const SizedBox(height: 3),
                            Text(
                              text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: danger ? dangerColor : p.bg),
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
