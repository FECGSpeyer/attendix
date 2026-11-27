import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/files_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/design_theme.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/tenant_settings_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../data/general_settings_helpers.dart'
    show holidayRegions, initialRegistrationFields, normalizeReasons, normalizeShowAllInfoText;
import '../../../../core/logic/words.dart';
import '../../../today/presentation/widgets/today_common.dart' show RdInfoCard;
import '../widgets/manage/manage_list.dart' show rdLoadedValue;
import '../widgets/manage/settings_sheets.dart';
import '../../../../shared/widgets/components/components.dart';
import '../../../../shared/widgets/components/split_view.dart' show RdManageBackLink;
import 'critical_rule_page.dart';
import '../../../people/data/providers/critical_providers.dart';
import '../../../people/data/critical_logic.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/person/person.dart';

part 'general_settings_tenant.dart';
part 'general_settings_critical.dart';

/// Tenant-wide settings sections, split by the domain where each applies.
/// Every change writes directly to `tenants` and re-evaluates rules when needed.
enum RdTenantSettings {
  /// Name und Kürzel (Verwaltung › Gruppe und Organisation).
  name,

  /// Saisonbeginn, schichtbedingt zählt als anwesend (Auswertung).
  counting,

  /// Alle Termine, Hinweistext, Mitgliederliste (Rollen und Rechte ›
  /// Mitglied › Sieht).
  visibility,

  /// Chat-Assistent (Rollen und Rechte › Für alle in der Gruppe).
  assistant,

  /// Abwesenheits- und Verspätungsgründe (Verwaltung › Termine).
  reasons,

  /// Anmeldung per Link, automatisch freigeben, Felder (Verwaltung ›
  /// Mitglieder).
  registration,

  /// Werke öffentlich teilen (Werke › •••).
  sharing,

  /// Problemfall-Regeln (Verwaltung › Mitglieder).
  critical,

  /// Ferien und Feiertage, Bundesland (Verwaltung › Termine).
  holidays,

  /// Lehrer pflegen (Lehrer-Seite; Orchester).
  teachers,

  /// Eltern-Zugang (Eltern-Seite).
  parents,
}

/// Group settings page: displays a [RdTenantSettingsBlock] for the selected
/// [section], saving every change right away.
class RdGeneralSettingsPage extends StatelessWidget {
  const RdGeneralSettingsPage({super.key, this.section = RdTenantSettings.name});

  final RdTenantSettings section;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RedesignRoutes.manage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final intro = rdTenantSettingsIntro(l10n, section);
    return RdPage(
      children: [
        RdManageBackLink(label: l10n.redesignMeAdmin, onTap: () => _back(context)),
        const SizedBox(height: 4),
        Semantics(header: true, child: Text(rdTenantSettingsTitle(l10n, section), style: RdType.largeTitle(p))),
        if (intro != null) ...[
          const SizedBox(height: 6),
          Text(intro, style: RdType.meta(p, size: 15)),
        ],
        const SizedBox(height: 18),
        RdTenantSettingsBlock(sections: [section]),
        const SizedBox(height: 32),
      ],
    );
  }
}

/// Werke › ••• › "Werke öffentlich teilen" (from the old "Allgemein"): the
/// switch and "Link kopieren"; every change is saved right away.
Future<void> showRdSharingSheet(BuildContext context) => showRdSettingsSheet<void>(
      context,
      (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // One switch that saves at once (and, when on, the link to
            // copy): no head repeating its title and no "Fertig", the
            // sheet closes by swiping down or tapping outside.
            const RdTenantSettingsBlock(sections: [RdTenantSettings.sharing]),
          ],
        ),
      ),
    );

/// Werke › ••• › "Werke öffentlich teilen" while the link is off: asks once
/// and switches it on. Returns the sharing id, or null when cancelled or the
/// save failed (switching it off stays in Verwaltung › Werke öffentlich
/// teilen).
Future<String?> rdEnableWorksSharing(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final ok = await showAppConfirm(
    context,
    title: l10n.generalSettingsShareSongs,
    message: l10n.rdSettingsShareWorksHint,
    confirmText: l10n.rdWmShareEnable,
  );
  if (!ok || !context.mounted || DemoGuard.blocked()) return null;
  final tenantId = ref.read(currentTenantProvider)?.id;
  if (tenantId == null) return null;
  final id = const Uuid().v4();
  try {
    await ref.read(tenantSettingsRepositoryForTenantProvider(tenantId)).updateSettings({'song_sharing_id': id});
    await ref
        .read(currentTenantProvider.notifier)
        .updateTenantLocalIfCurrent(tenantId, (c) => c.copyWith(songSharingId: id));
    ref.invalidate(userTenantsProvider);
    return id;
  } catch (_) {
    if (context.mounted) ToastHelper.showError(context, l10n.rdSettingsSaveFailed);
    return null;
  }
}

/// Title of a settings page.
String rdTenantSettingsTitle(AppLocalizations l10n, RdTenantSettings s) => switch (s) {
      RdTenantSettings.name => l10n.rdAdminName,
      RdTenantSettings.registration => l10n.rdAdminRegistration,
      RdTenantSettings.reasons => l10n.rdAdminReasons,
      RdTenantSettings.critical => l10n.rdAdminCritical,
      RdTenantSettings.holidays => l10n.rdAdminHolidays,
      RdTenantSettings.counting => l10n.rdAdminCounting,
      RdTenantSettings.visibility => l10n.rdAdminVisibility,
      RdTenantSettings.assistant => l10n.assistantSettingsToggle,
      RdTenantSettings.sharing => l10n.rdAdminSharing,
      RdTenantSettings.teachers => l10n.rdSettingsTeachers,
      RdTenantSettings.parents => l10n.rdSettingsParents,
    };

String? rdTenantSettingsIntro(AppLocalizations l10n, RdTenantSettings s) => switch (s) {
      RdTenantSettings.registration => l10n.rdAdminRegistrationIntro,
      RdTenantSettings.critical => l10n.rdAdminCriticalIntro,
      RdTenantSettings.holidays => l10n.rdAdminHolidaysIntro,
      RdTenantSettings.reasons => l10n.rdAdminReasonsIntro,
      _ => null,
    };

/// Renders the rows of [sections] on any settings or overview page. With
/// [label], a group label precedes the block.
class RdTenantSettingsBlock extends ConsumerStatefulWidget {
  const RdTenantSettingsBlock({super.key, required this.sections, this.label});

  final List<RdTenantSettings> sections;
  final String? label;

  @override
  ConsumerState<RdTenantSettingsBlock> createState() => _RdTenantSettingsBlockState();
}

class _RdTenantSettingsBlockState extends ConsumerState<RdTenantSettingsBlock> {
  /// One save at a time; switches are disabled meanwhile.
  bool _saving = false;

  /// Saves [values] for the group [tenantId] (the group shown when the
  /// change started) and applies them locally with [apply]. Aborts when the
  /// current group changed meanwhile. Everything it needs after the `await`
  /// is bound before it, so leaving the page while saving still updates the
  /// local group. With [evaluate] the Problemfall rules are re-evaluated
  /// (Ionic does that after every save). Returns whether it was stored.
  Future<bool> _save(
    int? tenantId,
    Map<String, dynamic> values,
    Tenant Function(Tenant t) apply, {
    bool evaluate = false,
  }) async {
    if (_saving || DemoGuard.blocked() || tenantId == null) return false;
    if (ref.read(currentTenantProvider)?.id != tenantId) return false;
    final container = ProviderScope.containerOf(context, listen: false);
    final repo = container.read(tenantSettingsRepositoryForTenantProvider(tenantId));
    final tenantNotifier = container.read(currentTenantProvider.notifier);
    final failed = context.l10n.rdSettingsSaveFailed;
    setState(() => _saving = true);
    try {
      await repo.updateSettings(values);
      await tenantNotifier.updateTenantLocalIfCurrent(tenantId, apply);
      // The group list keeps a copy of each group: refresh it, or switching
      // groups would bring back the old values.
      container.invalidate(userTenantsProvider);
      if (evaluate) {
        await repo.evaluateCriticalRules();
        // The Problemfälle shown elsewhere (e.g. on Heute) follow the new rules.
        container.invalidate(criticalPlayersProvider);
      }
      return true;
    } catch (_) {
      if (mounted) ToastHelper.showError(context, failed);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(currentTenantProvider);
    if (t == null) return RdInfoCard(text: context.l10n.redesignTodayLoading, loading: true);
    final out = <Widget>[];
    for (final s in widget.sections) {
      final rows = _section(s, t);
      if (rows.isEmpty) continue;
      if (out.isNotEmpty) out.add(const SizedBox(height: 24));
      out.addAll(rows);
    }
    if (out.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null) RdGroupLabel(widget.label!),
        ...out,
      ],
    );
  }

  List<Widget> _section(RdTenantSettings s, Tenant t) {
    final p = context.rd;
    final l10n = context.l10n;
    final kind = ref.watch(rdGroupKindProvider);
    final enabled = !_saving;
    void Function(bool)? on(Future<void> Function(bool v) f) => enabled ? (v) => f(v) : null;
    switch (s) {
      case RdTenantSettings.name:
        return [
          RdGroupedList(
            children: [
              RdListRow(
                title: l10n.rdSettingsName,
                value: t.longName,
                onTap: enabled ? () => _editName(t, short: false) : null,
              ),
              RdListRow(
                title: l10n.rdSettingsShortName,
                subtitle: l10n.rdSettingsShortNameHint,
                value: t.shortName,
                onTap: enabled ? () => _editName(t, short: true) : null,
              ),
            ],
          ),
        ];
      case RdTenantSettings.counting:
        return [
          RdGroupedList(
            children: [
              RdListRow(
                title: l10n.rdSettingsSeasonStart,
                subtitle: l10n.rdSettingsSeasonHint,
                value: DateFormat(dateFmt()).format(_seasonOf(t)),
                onTap: enabled ? () => _editSeason(t) : null,
              ),
              RdSwitchRow(
                title: l10n.rdSettingsShiftPresent,
                subtitle: l10n.rdSettingsShiftPresentHint,
                value: t.shiftExcusedAsPresent,
                onChanged: on(
                  (v) => _save(t.id, {'shift_excused_as_present': v}, (c) => c.copyWith(shiftExcusedAsPresent: v)),
                ),
              ),
            ],
          ),
        ];
      case RdTenantSettings.visibility:
        return [
          RdGroupedList(
            children: [
              RdSwitchRow(
                title: l10n.rdSettingsAllEvents,
                subtitle: l10n.rdSettingsAllEventsHint,
                value: t.showAllAttendances,
                onChanged: on((v) => _toggleAllEvents(t, v)),
              ),
              if (t.showAllAttendances)
                RdListRow(
                  title: l10n.rdSettingsInfoText,
                  subtitle: (t.showAllAttendancesInfoText ?? '').isNotEmpty
                      ? t.showAllAttendancesInfoText
                      : l10n.defaultsShowAllInfoText,
                  onTap: enabled ? () => _editInfoText(t) : null,
                ),
              RdSwitchRow(
                title: l10n.rdSettingsMembersList,
                subtitle: l10n.rdSettingsMembersListHint(kind),
                value: t.showMembersList,
                onChanged: on((v) => _save(t.id, {'showMembersList': v}, (c) => c.copyWith(showMembersList: v))),
              ),
            ],
          ),
        ];
      case RdTenantSettings.assistant:
        return [
          RdGroupedList(
            children: [
              // Chat-Assistent: switched on per tenant (admins).
              RdSwitchRow(
                title: l10n.assistantSettingsToggle,
                subtitle: l10n.assistantSettingsToggleHint,
                value: t.aiAssistantEnabled,
                onChanged: on(
                  (v) => _save(t.id, {'ai_assistant_enabled': v}, (c) => c.copyWith(aiAssistantEnabled: v)),
                ),
              ),
            ],
          ),
        ];
      case RdTenantSettings.reasons:
        return [
          RdGroupedList(
            children: [
              RdListRow(
                title: l10n.generalSettingsAbsenceReasons,
                value: '${EventListUtils.absenceReasonsOf(t.absenceReasons).length}',
                onTap: enabled ? () => _editReasons(t, late: false) : null,
              ),
              RdListRow(
                title: l10n.generalSettingsLateReasons,
                value: '${EventListUtils.lateReasonsOf(t.lateReasons).length}',
                onTap: enabled ? () => _editReasons(t, late: true) : null,
              ),
            ],
          ),
        ];
      case RdTenantSettings.registration:
        final registration = (t.registerId ?? '').isNotEmpty;
        final noGroups = registration && ref.watch(groupsProvider).hasValue && !_hasSelectableGroups();
        return [
          RdGroupedList(
            children: [
              RdSwitchRow(
                title: l10n.rdSettingsAllowRegister,
                subtitle: l10n.rdSettingsAllowRegisterHint,
                value: registration,
                onChanged: on((v) => _toggleRegistration(t, v)),
              ),
              if (registration) ...[
                RdListRow(
                  title: l10n.rdSettingsCopyRegisterLink,
                  titleColor: p.primary,
                  showChevron: false,
                  onTap: () => _copyLink('https://attendix.de/register/${t.registerId}'),
                ),
                RdSwitchRow(
                  title: l10n.rdSettingsAutoApprove,
                  subtitle: l10n.rdSettingsAutoApproveHint,
                  value: t.autoApproveRegistrations,
                  onChanged: on(
                    (v) => _save(
                      t.id,
                      {'auto_approve_registrations': v},
                      (c) => c.copyWith(autoApproveRegistrations: v),
                    ),
                  ),
                ),
                RdListRow(
                  title: l10n.rdSettingsRegisterFields,
                  subtitle: _registrationFieldsLabel(t),
                  onTap: enabled ? () => _editRegistrationFields(t) : null,
                ),
              ],
            ],
          ),
          if (noGroups) RdListNote(l10n.rdWordsNoGroupsYet(kind)),
        ];
      case RdTenantSettings.sharing:
        final sharing = (t.songSharingId ?? '').isNotEmpty;
        return [
          RdGroupedList(
            children: [
              RdSwitchRow(
                title: l10n.generalSettingsShareSongs,
                subtitle: l10n.rdSettingsShareWorksHint,
                value: sharing,
                onChanged: on((v) => _toggleSharing(t, v)),
              ),
              if (sharing)
                RdListRow(
                  title: l10n.rdSettingsCopyWorksLink,
                  titleColor: p.primary,
                  showChevron: false,
                  onTap: () => _copyLink('https://attendix.de/${t.songSharingId}'),
                ),
            ],
          ),
        ];
      case RdTenantSettings.teachers:
        // Like the old page: only orchestras keep teachers.
        if (t.type != 'orchestra') return const [];
        return [
          RdGroupedList(
            children: [
              RdSwitchRow(
                title: l10n.rdSettingsTeachers,
                subtitle: l10n.rdSettingsTeachersHint,
                value: t.maintainTeachers,
                onChanged: on((v) => _save(t.id, {'maintainTeachers': v}, (c) => c.copyWith(maintainTeachers: v))),
              ),
            ],
          ),
        ];
      case RdTenantSettings.parents:
        return [
          RdGroupedList(
            children: [
              RdSwitchRow(
                title: l10n.rdSettingsParents,
                subtitle: l10n.rdSettingsParentsHint,
                value: t.parents ?? false,
                onChanged: on((v) => _save(t.id, {'parents': v}, (c) => c.copyWith(parents: v))),
              ),
            ],
          ),
        ];
      case RdTenantSettings.holidays:
        return [
          RdGroupedList(
            children: [
              RdSwitchRow(
                title: l10n.rdSettingsHolidays,
                subtitle: l10n.rdSettingsHolidaysHint,
                value: t.showHolidays,
                onChanged: on((v) async {
                  final saved = await _save(t.id, {'showHolidays': v}, (c) => c.copyWith(showHolidays: v));
                  // Without a Bundesland nothing gets highlighted: ask for
                  // it right away.
                  if (!saved || !v || !mounted || (t.region ?? '').isNotEmpty) return;
                  final now = ref.read(currentTenantProvider);
                  if (now != null && now.id == t.id) await _pickRegion(now);
                }),
              ),
              if (t.showHolidays)
                RdListRow(
                  title: l10n.rdSettingsRegion,
                  value: _regionLabel(t),
                  onTap: enabled ? () => _pickRegion(t) : null,
                ),
            ],
          ),
        ];
      case RdTenantSettings.critical:
        final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const [];
        final rules = _rules(t);
        return [
          if (rules.isNotEmpty) ...[
            const _CriticalNow(),
            const SizedBox(height: 18),
          ],
          _CriticalRuleList(
            rules: rules,
            types: types,
            titleOf: _ruleTitle,
            onTap: enabled ? (i) => _ruleActions(t, i) : null,
            onAdd: enabled ? () => _ruleSheet(t) : null,
          ),
          RdListNote(rules.isEmpty ? l10n.rdSettingsCriticalHint : l10n.rdCriticalListFoot),
        ];
    }
  }
}
