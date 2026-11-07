import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/duty_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/duty_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/duty/person_unavailability.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart' show showAppConfirm, showAppDatePicker;
import '../widgets/event/rd_form_widgets.dart';
import '../widgets/manage/rd_settings_sheets.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;

/// A rule being edited and how it was loaded (null: new, not saved yet).
class _Draft {
  _Draft(this.rule, this.original);

  PersonUnavailability rule;
  PersonUnavailability? original;
  final key = UniqueKey();

  /// A new rule nobody filled in yet: dropped on "Fertig".
  bool get untouched =>
      original == null && rule.weekdays.isEmpty && rule.reason.trim().isEmpty && rule.validUntil == null;

  bool get changed => original == null ? !untouched : rule != original;
}

/// REDESIGN: "Nicht verfügbar" (Beta-Bearbeiten-Seite of "Regelmäßig
/// verhindert"): every rule as a section with weekday and Termin chips,
/// "Grund" and "Gilt bis". "Fertig" (or back) saves the changed rules with
/// the same writes as the old page ([DutyNotifier.saveUnavailability] and
/// the offer to adjust already planned Termine); "Regel löschen" deletes
/// right away after a confirmation. The group is held when the page opens:
/// after a group switch nothing is written.
class RdUnavailabilityPage extends ConsumerStatefulWidget {
  const RdUnavailabilityPage({super.key, required this.personId, this.personName = '', this.forOther = false});

  final int personId;
  final String personName;

  /// Opened by the leadership for someone else.
  final bool forOther;

  @override
  ConsumerState<RdUnavailabilityPage> createState() => _RdUnavailabilityPageState();
}

class _RdUnavailabilityPageState extends ConsumerState<RdUnavailabilityPage> {
  /// The group when the page opened.
  int? _tenantId;
  List<_Draft>? _drafts;
  bool _saving = false;

  /// Saved rules whose "also planned Termine?" question was not asked yet;
  /// kept when a later save fails, so a retry still asks it.
  final List<PersonUnavailability> _toOffer = [];

  @override
  void initState() {
    super.initState();
    _tenantId = ref.read(currentTenantIdProvider);
  }

  bool get _sameGroup => _tenantId != null && ref.read(currentTenantIdProvider) == _tenantId;

  bool get _dirty => _toOffer.isNotEmpty || (_drafts?.any((d) => d.changed) ?? false);

  List<AttendanceType> get _types =>
      (ref.read(attendanceTypesProvider).valueOrNull ?? const []).where((t) => t.visible).toList();

  String _untilText(PersonUnavailability rule) {
    final until = DateTime.tryParse(rule.validUntil ?? '');
    if (until == null) return context.l10n.redesignUnavailabilityUnlimited;
    return DateFormat(dateFmt()).format(until);
  }

  /// No change while saving (it would be lost or overwritten).
  void _update(_Draft draft, PersonUnavailability rule) {
    if (_saving) return;
    setState(() => draft.rule = rule);
  }

  void _add() {
    final tenantId = _tenantId;
    if (tenantId == null || _saving) return;
    // Like the old page: a new rule starts with the Dienst types.
    final dutyTypeIds = _types.where((t) => t.dutyMode && t.id != null).map((t) => t.id!).toList();
    setState(() {
      _drafts = [
        ...?_drafts,
        _Draft(PersonUnavailability(tenantId: tenantId, personId: widget.personId, typeIds: dutyTypeIds), null),
      ];
    });
  }

  Future<void> _remove(_Draft draft) async {
    final l10n = context.l10n;
    if (_saving) return;
    if (draft.original == null) {
      setState(() => _drafts = [...?_drafts]..remove(draft));
      return;
    }
    final notifier = ref.read(dutyNotifierProvider.notifier);
    final confirmed = await showAppConfirm(
      context,
      title: l10n.dutyDeleteRuleConfirm,
      message: l10n.dutyDeleteRuleMessage,
      confirmText: l10n.commonDelete,
      destructive: true,
    );
    if (!confirmed || !mounted || !_sameGroup || _saving) return;
    final deleted = draft.original!;
    // Same lock as "Fertig": no save (and no offer of this rule) meanwhile.
    setState(() => _saving = true);
    final ok = await notifier.deleteUnavailability(deleted);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      ToastHelper.showError(context, l10n.dutyFlutterDeleteFailed);
      return;
    }
    setState(() {
      _drafts = [...?_drafts]..remove(draft);
      // A deleted rule adjusts no planned Termine.
      _toOffer.removeWhere((r) => r.id == deleted.id);
    });
  }

  Future<void> _editReason(_Draft draft) async {
    final l10n = context.l10n;
    final reason = await showRdTextSheet(
      context,
      title: l10n.redesignUnavailabilityReason,
      initial: draft.rule.reason,
      hint: l10n.dutyChildrenHourPlaceholder,
    );
    if (reason == null || !mounted) return;
    _update(draft, draft.rule.copyWith(reason: reason));
  }

  Future<void> _editUntil(_Draft draft) async {
    final l10n = context.l10n;
    final rule = draft.rule;
    final choice = await showRdChoiceSheet<bool>(
      context,
      title: l10n.redesignUnavailabilityUntil,
      options: [(false, l10n.redesignUnavailabilityUnlimited), (true, l10n.redesignUnavailabilityPickDate)],
      selected: rule.validUntil == null ? false : null,
    );
    if (choice == null || !mounted) return;
    if (!choice) {
      _update(draft, draft.rule.copyWith(validUntil: null));
      return;
    }
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: DateTime.tryParse(rule.validUntil ?? '') ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null || !mounted) return;
    _update(draft, draft.rule.copyWith(validUntil: DateFormat('yyyy-MM-dd').format(picked)));
  }

  /// "Fertig": saves every changed rule like the old "Speichern", then
  /// offers to adjust the planned Termine of each saved rule.
  Future<void> _done() async {
    if (_saving) return;
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final changed = (_drafts ?? const <_Draft>[]).where((d) => d.changed).toList();
    if (changed.any((d) => d.rule.weekdays.isEmpty)) {
      ToastHelper.showWarning(context, l10n.dutyChooseWeekday);
      return;
    }
    // Navigator.pop ignores the PopScope (which only catches back).
    if ((changed.isEmpty && _toOffer.isEmpty) || !_sameGroup) {
      navigator.pop();
      return;
    }
    final notifier = ref.read(dutyNotifierProvider.notifier);
    final repo = ref.read(dutyRepositoryWithTenantProvider);
    final types = _types;
    setState(() => _saving = true);
    for (final draft in changed) {
      if (!_sameGroup) break;
      final result = await notifier.saveUnavailability(draft.rule.copyWith(reason: draft.rule.reason.trim()));
      if (!mounted) return;
      if (result == null) {
        setState(() => _saving = false);
        ToastHelper.showError(context, l10n.extraFieldsSaveFailed);
        return;
      }
      draft
        ..rule = result
        ..original = result;
      // Only the newest state of a rule is offered.
      _toOffer
        ..removeWhere((r) => r.id == result.id)
        ..add(result);
    }
    while (_toOffer.isNotEmpty) {
      if (!mounted || !_sameGroup) break;
      final rule = _toOffer.removeAt(0);
      // P10_SELF_PLAN: Ionic passes the visible types.
      final (:count, :dates) = await repo.countFutureMatches(rule, types);
      if (!mounted) return;
      if (count == 0) {
        ToastHelper.showSuccess(context, l10n.dutySaved);
        continue;
      }
      final preview =
          dates
              .take(4)
              .map((d) {
                final date = DateTime.tryParse(d)?.toLocal();
                return date == null ? d : DateFormat(dateFmt(DateFmtKind.dayMonth)).format(date);
              })
              .join(', ') +
          (count > 4 ? ' …' : '');
      final apply = await showAppConfirm(
        context,
        title: l10n.dutyAlsoPlanned,
        message:
            widget.forOther
                ? l10n.dutyAlsoPlannedOther(count, preview, widget.personName.split(' ').first)
                : l10n.dutyAlsoPlannedSelf(count, preview),
        confirmText: l10n.dutyAlsoPlannedButton,
        cancelText: l10n.dutyOnlyNew,
      );
      if (!apply || !mounted || !_sameGroup) continue;
      final adjusted = await notifier.applyUnavailabilityToFuture(rule);
      if (!mounted) return;
      if (adjusted == null) {
        ToastHelper.showError(context, l10n.svcApplyToPlannedFailed);
      } else {
        ToastHelper.showSuccess(context, l10n.dutyEventsAdjusted(adjusted));
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final rulesAsync = ref.watch(unavailabilityByPersonProvider(widget.personId));
    final rules = rulesAsync.valueOrNull;
    if (_drafts == null && rules != null && !rulesAsync.isLoading) {
      _drafts = [for (final r in rules) _Draft(r, r)];
    }
    final drafts = _drafts;

    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              RdEditTopBar(
                title: l10n.redesignUnavailabilityTitle,
                onDone: _done,
                leading:
                    _saving
                        ? Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
                            ),
                          ),
                        )
                        : null,
              ),
              Expanded(
                // Locked while saving: a change made now would not be saved.
                child: ExcludeFocus(
                  excluding: _saving,
                  child: AbsorbPointer(
                    absorbing: _saving,
                    child: RdFormBody(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                          child: Text(
                            widget.forOther
                                ? l10n.redesignUnavailabilityIntro(widget.personName)
                                : l10n.redesignUnavailabilityIntroSelf,
                            style: RdType.body(p).copyWith(color: p.text2),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (drafts == null)
                          rulesAsync.hasError
                              ? RdInfoCard(
                                text: l10n.redesignTodayLoadFailed,
                                icon: Icons.cloud_off_outlined,
                                action: RdOutlineButton(
                                  label: l10n.redesignCommonRetry,
                                  onPressed: () => ref.invalidate(unavailabilityByPersonProvider(widget.personId)),
                                ),
                              )
                              : RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
                        else ...[
                          if (drafts.isEmpty) ...[
                            const SizedBox(height: 14),
                            RdInfoCard(
                              icon: Icons.event_busy_outlined,
                              text: widget.forOther ? l10n.dutyNoRuleOther : l10n.dutyNoRuleSelf,
                            ),
                          ],
                          for (final (i, d) in drafts.indexed) _ruleSection(i, d),
                          const SizedBox(height: 22),
                          RdOutlineButton(
                            icon: Icons.add,
                            label: l10n.redesignUnavailabilityAdd,
                            onPressed: _saving ? null : _add,
                          ),
                          RdListNote(l10n.dutyRuleHint),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleSection(int index, _Draft draft) {
    final p = context.rd;
    final l10n = context.l10n;
    final rule = draft.rule;
    final types =
        (ref.watch(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[])
            .where((t) => t.visible && t.id != null)
            .toList();
    final short = weekdayShortNames;
    final long = weekdayLongNames;
    Widget label(String text) =>
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: RdType.meta(p, size: 13)));

    return Padding(
      key: draft.key,
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdGroupLabel(l10n.redesignUnavailabilityRule(index + 1)),
          RdCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label(l10n.redesignUnavailabilityWeekdays),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      RdChoiceChip(
                        label: short[day - 1],
                        semanticLabel: long[day - 1],
                        selected: rule.weekdays.contains(day),
                        onTap: () {
                          final list = [...rule.weekdays];
                          list.contains(day) ? list.remove(day) : list.add(day);
                          list.sort();
                          _update(draft, rule.copyWith(weekdays: list));
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                label(l10n.redesignUnavailabilityTermine),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // No selection = all types (old page: "Ohne Auswahl gilt
                    // die Regel für alle Termintypen").
                    RdChoiceChip(
                      label: l10n.redesignUnavailabilityAll,
                      selected: rule.typeIds.isEmpty,
                      onTap: () => _update(draft, rule.copyWith(typeIds: const [])),
                    ),
                    for (final t in types)
                      RdChoiceChip(
                        label: t.name,
                        selected: rule.typeIds.contains(t.id),
                        onTap: () {
                          final list = [...rule.typeIds];
                          if (!list.remove(t.id)) list.add(t.id!);
                          _update(draft, rule.copyWith(typeIds: list));
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          RdGroupedList(
            children: [
              RdListRow(
                title: l10n.redesignUnavailabilityReason,
                value: rule.reason.isEmpty ? l10n.redesignUnavailabilityOptional : rule.reason,
                onTap: () => _editReason(draft),
              ),
              RdListRow(
                title: l10n.redesignUnavailabilityUntil,
                value: _untilText(rule),
                onTap: () => _editUntil(draft),
              ),
              RdListRow(
                title: l10n.redesignUnavailabilityDelete,
                titleColor: p.absent,
                showChevron: false,
                onTap: _saving ? null : () => _remove(draft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
