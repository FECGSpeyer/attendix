import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/duty_providers.dart';
import '../../../../core/providers/files_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/tenant_settings_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../settings/presentation/pages/general_settings_page.dart'
    show holidayRegions, initialRegistrationFields, normalizeReasons, normalizeShowAllInfoText;
import '../../../settings/presentation/widgets/critical_rule_sheet.dart';
import '../../data/rd_manage_logic.dart' show RdManageArea;
import '../widgets/manage/rd_settings_sheets.dart';
import '../widgets/rd_widgets.dart';

/// REDESIGN: Verwaltung › Gruppe › Allgemein (canvas "Beta: Gruppe und
/// Daten", board "G1 Allgemeine Einstellungen"). The settings of the old
/// page `/settings/general` as page type "Einstellungen": every change is
/// saved right away (same `tenants` columns and rules as the old page),
/// values change in small sheets, no "Speichern" and no "Neu laden". The
/// links to Typen, Schichtpläne, Branding and Zusatzfelder are left out:
/// they have their own entries in the Verwaltung.
class RdGeneralSettingsPage extends ConsumerStatefulWidget {
  const RdGeneralSettingsPage({super.key});

  @override
  ConsumerState<RdGeneralSettingsPage> createState() => _RdGeneralSettingsPageState();
}

class _RdGeneralSettingsPageState extends ConsumerState<RdGeneralSettingsPage> {
  /// One save at a time; switches are disabled meanwhile.
  bool _saving = false;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RedesignRoutes.manageArea(RdManageArea.group.key));
    }
  }

  /// Saves [values] for the current tenant and applies them locally with
  /// [apply]. Returns whether it was stored.
  Future<bool> _save(Map<String, dynamic> values, Tenant Function(Tenant t) apply) async {
    if (_saving || DemoGuard.blocked()) return false;
    final tenantId = ref.read(currentTenantProvider)?.id;
    if (tenantId == null) return false;
    final repo = ref.read(tenantSettingsRepositoryForTenantProvider(tenantId));
    setState(() => _saving = true);
    try {
      await repo.updateSettings(values);
      await ref.read(currentTenantProvider.notifier).updateTenantLocalIfCurrent(tenantId, apply);
      return true;
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.rdSettingsSaveFailed);
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
    final ok = await _save({
      short ? 'shortName' : 'longName': value,
    }, (c) => short ? c.copyWith(shortName: value) : c.copyWith(longName: value));
    if (ok) ref.invalidate(userTenantsProvider);
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
    if (!await _save({'seasonStart': value}, (c) => c.copyWith(seasonStart: value))) return;
    // The season start changes every percentage: offer to undo it.
    messenger?.showSnackBar(
      SnackBar(
        content: Text(l10n.rdSettingsSeasonSaved(DateFormat(dateFmt()).format(picked))),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: l10n.rdSettingsUndo,
          onPressed: () {
            if (mounted) _save({'seasonStart': before}, (c) => c.copyWith(seasonStart: before));
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
    await _save({
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
    await _save({'show_all_attendances_info_text': info}, (c) => c.copyWith(showAllAttendancesInfoText: info));
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
    await _save({
      late ? 'late_reasons' : 'absence_reasons': value,
    }, (c) => late ? c.copyWith(lateReasons: value) : c.copyWith(absenceReasons: value));
  }

  bool _hasSelectableGroups() => (ref.read(groupsProvider).valueOrNull ?? const []).any((g) => g.maingroup != true);

  Future<void> _toggleRegistration(Tenant t, bool on) async {
    if (on) {
      // Ionic: registration needs a group to choose (not the main group).
      final groups = await ref.read(groupsProvider.future);
      if (!mounted) return;
      if (!groups.any((g) => g.maingroup != true)) {
        ToastHelper.showError(context, context.l10n.generalSettingsRegisterNoGroups);
        return;
      }
      final id = (t.registerId ?? '').isNotEmpty ? t.registerId! : const Uuid().v4();
      final fields = initialRegistrationFields(t.registrationFields);
      await _save({
        'register_id': id,
        'registration_fields': fields,
      }, (c) => c.copyWith(registerId: id, registrationFields: fields));
    } else {
      // Ionic: off → no link, no auto approval, no fields.
      await _save({
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
    await _save({'registration_fields': selected}, (c) => c.copyWith(registrationFields: selected));
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
    await _save({'song_sharing_id': id}, (c) => c.copyWith(songSharingId: id));
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
    await _save({'region': value}, (c) => c.copyWith(region: value));
  }

  String _regionLabel(Tenant t) {
    final region = t.region ?? '';
    if (region.isEmpty) return context.l10n.generalSettingsFlutterNoHolidays;
    return holidayRegions.where((r) => r.$1 == region).map((r) => r.$2).firstOrNull ?? region;
  }

  // ---------------------------------------------------------------- rules

  List<CriticalRule> _rules(Tenant t) => [...?t.criticalRules];

  Future<void> _saveRules(List<CriticalRule> rules, String toast) async {
    final tenantId = ref.read(currentTenantProvider)?.id;
    final ok = await _save({
      'critical_rules': rules.map(criticalRuleToJson).toList(),
    }, (c) => c.copyWith(criticalRules: rules));
    if (!ok || tenantId == null) return;
    if (mounted) ToastHelper.showSuccess(context, toast);
    // Ionic re-evaluates the Problemfall rules right away.
    await ref.read(tenantSettingsRepositoryForTenantProvider(tenantId)).evaluateCriticalRules();
  }

  Future<void> _ruleSheet(Tenant t, {int? index}) async {
    final l10n = context.l10n;
    final types = await ref.read(attendanceTypesProvider.future);
    if (!mounted) return;
    if (index == null && types.isEmpty) {
      ToastHelper.showError(context, l10n.generalSettingsFlutterNoTypes);
      return;
    }
    CriticalRule? saved;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder:
          (_) => CriticalRuleSheet(
            rule: index == null ? null : _rules(t)[index],
            attendanceTypes: types,
            onSave: (rule) => saved = rule,
          ),
    );
    final rule = saved;
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
    await _saveRules(rules, l10n.generalSettingsFlutterRuleDeleted);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final t = ref.watch(currentTenantProvider);
    final header = <Widget>[
      RdBackLink(label: l10n.rdSettingsBack, onTap: _back),
      const SizedBox(height: 4),
      Semantics(header: true, child: Text(l10n.rdSettingsGeneralTitle, style: RdType.largeTitle(p))),
      const SizedBox(height: 18),
    ];
    if (t == null) {
      return RdPage(
        children: [
          ...header,
          Center(child: Padding(padding: const EdgeInsets.all(32), child: CircularProgressIndicator(color: p.primary))),
        ],
      );
    }
    final enabled = !_saving;
    void Function(bool)? on(Future<void> Function(bool v) f) => enabled ? (v) => f(v) : null;
    final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const [];
    final registration = (t.registerId ?? '').isNotEmpty;
    final sharing = (t.songSharingId ?? '').isNotEmpty;
    final noGroups = registration && ref.watch(groupsProvider).hasValue && !_hasSelectableGroups();
    final rules = _rules(t);
    const gap = SizedBox(height: 24);

    return RdPage(
      children: [
        ...header,
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
        gap,
        RdGroupLabel(l10n.rdSettingsSectionAttendance),
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
              onChanged: on((v) => _save({'shift_excused_as_present': v}, (c) => c.copyWith(shiftExcusedAsPresent: v))),
            ),
          ],
        ),
        RdListNote(l10n.generalSettingsSeasonHelper),
        gap,
        RdGroupLabel(l10n.rdSettingsSectionMembers),
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
                subtitle:
                    (t.showAllAttendancesInfoText ?? '').isNotEmpty
                        ? t.showAllAttendancesInfoText
                        : l10n.defaultsShowAllInfoText,
                onTap: enabled ? () => _editInfoText(t) : null,
              ),
            if (ref.watch(hasDutyTypesProvider))
              RdSwitchRow(
                title: l10n.rdSettingsDutyView,
                subtitle: l10n.rdSettingsDutyViewHint,
                value: t.dutyView,
                onChanged: on((v) => _save({'duty_view': v}, (c) => c.copyWith(dutyView: v))),
              ),
            RdSwitchRow(
              title: l10n.rdSettingsMembersList,
              subtitle: l10n.rdSettingsMembersListHint,
              value: t.showMembersList,
              onChanged: on((v) => _save({'showMembersList': v}, (c) => c.copyWith(showMembersList: v))),
            ),
          ],
        ),
        gap,
        RdGroupLabel(l10n.rdSettingsSectionReasons),
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
        gap,
        RdGroupLabel(l10n.rdSettingsSectionRegistration),
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
                value: t.autoApproveRegistrations,
                onChanged: on(
                  (v) => _save({'auto_approve_registrations': v}, (c) => c.copyWith(autoApproveRegistrations: v)),
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
        gap,
        RdGroupLabel(l10n.rdSettingsSectionWorks),
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
        gap,
        RdGroupLabel(l10n.rdSettingsSectionFeatures),
        RdGroupedList(
          children: [
            if (t.type == 'orchestra')
              RdSwitchRow(
                title: l10n.generalSettingsMaintainTeachers,
                subtitle: l10n.rdSettingsTeachersHint,
                value: t.maintainTeachers,
                onChanged: on((v) => _save({'maintainTeachers': v}, (c) => c.copyWith(maintainTeachers: v))),
              ),
            RdSwitchRow(
              title: l10n.generalSettingsParentsFeature,
              subtitle: l10n.rdSettingsParentsHint,
              value: t.parents ?? false,
              onChanged: on((v) => _save({'parents': v}, (c) => c.copyWith(parents: v))),
            ),
            RdSwitchRow(
              title: l10n.rdSettingsHolidays,
              subtitle: l10n.rdSettingsHolidaysHint,
              value: t.showHolidays,
              onChanged: on((v) => _save({'showHolidays': v}, (c) => c.copyWith(showHolidays: v))),
            ),
            if (t.showHolidays)
              RdListRow(
                title: l10n.rdSettingsRegion,
                value: _regionLabel(t),
                onTap: enabled ? () => _pickRegion(t) : null,
              ),
          ],
        ),
        gap,
        RdGroupLabel(l10n.rdSettingsSectionCritical),
        RdGroupedList(
          children: [
            for (var i = 0; i < rules.length; i++)
              RdListRow(
                title: rules[i].describe(types),
                onTap: enabled ? () => _ruleActions(t, i) : null,
              ),
            RdListRow(
              title: l10n.rdSettingsAddRule,
              titleColor: p.primary,
              showChevron: false,
              onTap: enabled ? () => _ruleSheet(t) : null,
            ),
          ],
        ),
        if (rules.isEmpty) RdListNote(l10n.rdSettingsCriticalHint),
        const SizedBox(height: 32),
      ],
    );
  }
}
