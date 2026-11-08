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
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/tenant_settings_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../settings/presentation/pages/general_settings_page.dart'
    show holidayRegions, initialRegistrationFields, normalizeReasons, normalizeShowAllInfoText;
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import '../widgets/manage/rd_settings_sheets.dart';
import '../widgets/rd_widgets.dart';
import 'rd_critical_rule_page.dart';

/// The settings of the old page `/settings/general` ("Allgemein"), split by
/// where they act (canvas "Beta: Verwaltung neu gedacht", board "Bestand:
/// die 20 Schalter in „Allgemein“"). Same `tenants` columns, rules and
/// saving as before; only the place changes.
enum RdTenantSettings {
  /// Name und Kürzel (Verwaltung › Gruppe und Organisation).
  name,

  /// Saisonbeginn, schichtbedingt zählt als anwesend (Auswertung).
  counting,

  /// Alle Termine, Hinweistext, Dienstplan, Mitgliederliste (Rollen und
  /// Rechte › Was Mitglieder sehen).
  visibility,

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

/// REDESIGN: a page of group settings (canvas "Beta: Verwaltung neu
/// gedacht"): Name und Kürzel, Anmeldung per Link, Abmeldegründe,
/// Problemfälle, Ferien und Feiertage. Every change is saved right away,
/// values change in small sheets ([RdTenantSettingsBlock]).
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
        RdBackLink(label: l10n.redesignMeAdmin, onTap: () => _back(context)),
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
            RdSheetHead(
              title: ctx.l10n.rdAdminSharing,
              cancel: false,
              onDone: () => Navigator.of(ctx).pop(),
            ),
            const RdTenantSettingsBlock(sections: [RdTenantSettings.sharing]),
          ],
        ),
      ),
    );

/// Title of a settings page.
String rdTenantSettingsTitle(AppLocalizations l10n, RdTenantSettings s) => switch (s) {
      RdTenantSettings.name => l10n.rdAdminName,
      RdTenantSettings.registration => l10n.rdAdminRegistration,
      RdTenantSettings.reasons => l10n.rdAdminReasons,
      RdTenantSettings.critical => l10n.rdAdminCritical,
      RdTenantSettings.holidays => l10n.rdAdminHolidays,
      RdTenantSettings.counting => l10n.rdAdminCounting,
      RdTenantSettings.visibility => l10n.rdAdminVisibility,
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

/// The rows of [sections], to sit on any Beta page (Rollen und Rechte,
/// Auswertung, Eltern, Lehrer, the Werke "•••"). With [label] a group label
/// comes first.
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

  Future<void> _editName(Tenant t, {required bool short}) async {
    final l10n = context.l10n;
    final value = await showRdTextSheet(
      context,
      title: short ? l10n.rdSettingsShortName : l10n.rdSettingsName,
      initial: short ? t.shortName : t.longName,
      helper: short ? l10n.generalSettingsShortNameHelper : null,
      required: true,
      capitalization: TextCapitalization.words,
    );
    if (value == null || !mounted) return;
    await _save(t.id, {
      short ? 'shortName' : 'longName': value,
    }, (c) => short ? c.copyWith(shortName: value) : c.copyWith(longName: value));
  }

  DateTime _seasonOf(Tenant t) =>
      (t.seasonStart != null ? DateTime.tryParse(t.seasonStart!)?.toLocal() : null) ?? DateTime(2023, 1, 1);

  String _isoDate(DateTime d) => d.toIso8601String().split('T')[0];

  Future<void> _editSeason(Tenant t) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = DateTime(1900);
    final before = t.seasonStart;
    var initial = _seasonOf(t);
    if (initial.isAfter(today)) initial = today;
    if (initial.isBefore(first)) initial = first;
    final picked = await showAppDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: today,
      locale: Locale(currentLanguage()),
    );
    if (picked == null || !mounted) return;
    final value = _isoDate(picked);
    final ok = await _save(t.id, {'seasonStart': value}, (c) => c.copyWith(seasonStart: value), evaluate: true);
    if (!ok) return;
    // The season start changes every percentage: offer to undo it.
    messenger?.showSnackBar(
      SnackBar(
        content: Text(l10n.rdSettingsSeasonSaved(DateFormat(dateFmt()).format(picked))),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: l10n.rdSettingsUndo,
          onPressed: () {
            if (mounted) _save(t.id, {'seasonStart': before}, (c) => c.copyWith(seasonStart: before), evaluate: true);
          },
        ),
      ),
    );
  }

  Future<void> _toggleAllEvents(Tenant t, bool on) async {
    final info = normalizeShowAllInfoText(
      enabled: on,
      text: t.showAllAttendancesInfoText ?? '',
      defaultText: context.l10n.defaultsShowAllInfoText,
    );
    await _save(t.id, {
      'show_all_attendances': on,
      'show_all_attendances_info_text': info,
    }, (c) => c.copyWith(showAllAttendances: on, showAllAttendancesInfoText: info));
  }

  Future<void> _editInfoText(Tenant t) async {
    final l10n = context.l10n;
    final value = await showRdTextSheet(
      context,
      title: l10n.rdSettingsInfoText,
      initial: t.showAllAttendancesInfoText ?? '',
      hint: l10n.generalSettingsForeignInfoPh,
      maxLines: 3,
    );
    if (value == null || !mounted) return;
    final info = normalizeShowAllInfoText(enabled: true, text: value, defaultText: l10n.defaultsShowAllInfoText);
    await _save(t.id, {'show_all_attendances_info_text': info}, (c) => c.copyWith(showAllAttendancesInfoText: info));
  }

  Future<void> _editReasons(Tenant t, {required bool late}) async {
    final l10n = context.l10n;
    final list = await showRdReasonsSheet(
      context,
      title: late ? l10n.generalSettingsLateReasons : l10n.generalSettingsAbsenceReasons,
      reasons: late ? EventListUtils.lateReasonsOf(t.lateReasons) : EventListUtils.absenceReasonsOf(t.absenceReasons),
      defaults: late ? EventListUtils.defaultLateReasons : EventListUtils.defaultAbsenceReasons,
    );
    if (list == null || !mounted) return;
    final value = normalizeReasons(list);
    await _save(t.id, {
      late ? 'late_reasons' : 'absence_reasons': value,
    }, (c) => late ? c.copyWith(lateReasons: value) : c.copyWith(absenceReasons: value));
  }

  /// Loads data a change needs; on failure shows the error and drops the
  /// failed result, so tapping again loads it anew. Returns null then.
  Future<T?> _load<T>(FutureProvider<T> provider) async {
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      return await container.read(provider.future);
    } catch (e) {
      container.invalidate(provider);
      if (mounted) ToastHelper.showError(context, context.l10n.settingsFlutterLoadFailed(friendlyErrorMessage(e)));
      return null;
    }
  }

  bool _hasSelectableGroups() => (ref.read(groupsProvider).valueOrNull ?? const []).any((g) => g.maingroup != true);

  Future<void> _toggleRegistration(Tenant t, bool on) async {
    if (on) {
      // Ionic: registration needs a group to choose (not the main group).
      final groups = await _load(groupsProvider);
      if (groups == null || !mounted) return;
      if (!groups.any((g) => g.maingroup != true)) {
        ToastHelper.showError(context, context.l10n.generalSettingsRegisterNoGroups);
        return;
      }
      final id = (t.registerId ?? '').isNotEmpty ? t.registerId! : const Uuid().v4();
      final fields = initialRegistrationFields(t.registrationFields);
      await _save(t.id, {
        'register_id': id,
        'registration_fields': fields,
      }, (c) => c.copyWith(registerId: id, registrationFields: fields));
    } else {
      // Ionic: off → no link, no auto approval, no fields.
      await _save(t.id, {
        'register_id': null,
        'auto_approve_registrations': false,
        'registration_fields': <String>[],
      }, (c) => c.copyWith(registerId: null, autoApproveRegistrations: false, registrationFields: const []));
    }
  }

  Future<void> _editRegistrationFields(Tenant t) async {
    final l10n = context.l10n;
    final options = <RdMultiOption>[
      (key: 'firstName', label: l10n.peopleFirstName, locked: true),
      (key: 'lastName', label: l10n.peopleLastName, locked: true),
      (key: 'group', label: l10n.peopleGroup, locked: true),
      (key: 'picture', label: l10n.settingsPassPhoto, locked: false),
      (key: 'birthDate', label: l10n.peopleBirthday, locked: false),
      (key: 'phone', label: l10n.settingsMobile, locked: false),
      for (final f in t.additionalFields ?? const <ExtraField>[]) (key: f.id, label: f.name, locked: false),
    ];
    final selected = await showRdMultiChoiceSheet(
      context,
      title: l10n.rdSettingsRegisterFields,
      options: options,
      selected: initialRegistrationFields(t.registrationFields),
      hint: l10n.rdSettingsRegisterFieldsHint,
    );
    if (selected == null || !mounted) return;
    await _save(t.id, {'registration_fields': selected}, (c) => c.copyWith(registrationFields: selected));
  }

  String _registrationFieldsLabel(Tenant t) {
    final l10n = context.l10n;
    final labels = {
      'firstName': l10n.peopleFirstName,
      'lastName': l10n.peopleLastName,
      'group': l10n.peopleGroup,
      'picture': l10n.settingsPassPhoto,
      'birthDate': l10n.peopleBirthday,
      'phone': l10n.settingsMobile,
      for (final f in t.additionalFields ?? const <ExtraField>[]) f.id: f.name,
    };
    return initialRegistrationFields(t.registrationFields).map((k) => labels[k]).whereType<String>().join(', ');
  }

  Future<void> _toggleSharing(Tenant t, bool on) async {
    final id = on ? ((t.songSharingId ?? '').isNotEmpty ? t.songSharingId! : const Uuid().v4()) : null;
    await _save(t.id, {'song_sharing_id': id}, (c) => c.copyWith(songSharingId: id));
  }

  Future<void> _copyLink(String link) async {
    try {
      await Clipboard.setData(ClipboardData(text: link));
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.settingsFlutterCopyLinkFailed);
      return;
    }
    if (mounted) ToastHelper.showSuccess(context, context.l10n.settingsLinkCopied);
  }

  Future<void> _pickRegion(Tenant t) async {
    final l10n = context.l10n;
    final region = await showRdChoiceSheet<String>(
      context,
      title: l10n.rdSettingsRegion,
      selected: t.region ?? '',
      options: [for (final r in holidayRegions) (r.$1, r.$1.isEmpty ? l10n.generalSettingsFlutterNoHolidays : r.$2)],
    );
    if (region == null || !mounted) return;
    final value = region.isEmpty ? null : region;
    await _save(t.id, {'region': value}, (c) => c.copyWith(region: value));
  }

  String _regionLabel(Tenant t) {
    final region = t.region ?? '';
    if (region.isEmpty) return context.l10n.generalSettingsFlutterNoHolidays;
    return holidayRegions.where((r) => r.$1 == region).map((r) => r.$2).firstOrNull ?? region;
  }

  // ---------------------------------------------------------------- rules

  List<CriticalRule> _rules(Tenant t) => [...?t.criticalRules];

  Future<void> _saveRules(Tenant t, List<CriticalRule> rules, String toast) async {
    // Stored and local list are the same normalised rules (e.g. a legacy
    // rule without period is saved with its default period).
    final json = rules.map(criticalRuleToJson).toList();
    final normalised = json.map(CriticalRule.fromJson).toList();
    final ok = await _save(
      t.id,
      {'critical_rules': json},
      (c) => c.copyWith(criticalRules: normalised),
      // Ionic re-evaluates the Problemfall rules right away.
      evaluate: true,
    );
    if (ok && mounted) ToastHelper.showSuccess(context, toast);
  }

  Future<void> _ruleSheet(Tenant t, {int? index}) async {
    final l10n = context.l10n;
    final types = await _load(attendanceTypesProvider);
    if (types == null || !mounted) return;
    if (index == null && types.isEmpty) {
      ToastHelper.showError(context, l10n.generalSettingsFlutterNoTypes);
      return;
    }
    final rule = await openRdCriticalRulePage(
      context,
      rule: index == null ? null : _rules(t)[index],
      attendanceTypes: types,
    );
    if (rule == null || !mounted) return;
    final current = ref.read(currentTenantProvider);
    if (current == null) return;
    final rules = _rules(current);
    if (index == null) {
      rules.add(rule);
    } else if (index < rules.length) {
      rules[index] = rule;
    }
    await _saveRules(
      t,
      rules,
      index == null ? l10n.generalSettingsFlutterRuleAdded : l10n.generalSettingsFlutterRuleUpdated,
    );
  }

  Future<void> _ruleActions(Tenant t, int index) async {
    final l10n = context.l10n;
    final action = await showAppActionSheet<String>(
      context,
      title: _rules(t)[index].describe(ref.read(attendanceTypesProvider).valueOrNull ?? const []),
      actions: [
        AppActionSheetAction(value: 'edit', label: l10n.commonEdit, icon: Icons.edit_outlined),
        AppActionSheetAction(value: 'delete', label: l10n.commonDelete, icon: Icons.delete_outline, destructive: true),
      ],
    );
    if (!mounted) return;
    if (action == 'edit') return _ruleSheet(t, index: index);
    if (action != 'delete') return;
    final rule = _rules(t)[index];
    final confirmed = await showAppConfirm(
      context,
      title: l10n.generalSettingsDeleteRule,
      message: l10n.generalSettingsFlutterDeleteRuleNamed(rule.displayName),
      confirmText: l10n.commonDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final current = ref.read(currentTenantProvider);
    if (current == null) return;
    final rules = _rules(current)..removeWhere((r) => r.id == rule.id);
    await _saveRules(t, rules, l10n.generalSettingsFlutterRuleDeleted);
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
          RdListNote(l10n.rdSettingsSeasonHint),
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
                subtitle: l10n.rdSettingsMembersListHint,
                value: t.showMembersList,
                onChanged: on((v) => _save(t.id, {'showMembersList': v}, (c) => c.copyWith(showMembersList: v))),
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
          if (noGroups) RdListNote(l10n.generalSettingsNoGroupsYet),
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
                onChanged: on((v) => _save(t.id, {'showHolidays': v}, (c) => c.copyWith(showHolidays: v))),
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
          RdGroupedList(
            children: [
              for (var i = 0; i < rules.length; i++)
                RdListRow(title: rules[i].describe(types), onTap: enabled ? () => _ruleActions(t, i) : null),
              RdListRow(
                title: l10n.rdSettingsAddRule,
                titleColor: p.primary,
                showChevron: false,
                onTap: enabled ? () => _ruleSheet(t) : null,
              ),
            ],
          ),
          if (rules.isEmpty) RdListNote(l10n.rdSettingsCriticalHint),
        ];
    }
  }
}
