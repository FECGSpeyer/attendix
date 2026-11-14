import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/duty_providers.dart';
import '../../../../core/providers/redesign_providers.dart' show redesignEnabledProvider;
import '../../../redesign/presentation/pages/rd_unavailability_page.dart' show RdUnavailabilityPage;
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/duty_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/duty/person_unavailability.dart';
import '../../../planning/presentation/widgets/ion_items.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/dialogs/ion_modal.dart' show showIonModal;

/// Opens "Regelmäßig verhindert" for a person (as a full screen dialog).
/// REDESIGN: in the Beta the page "Nicht verfügbar" ([RdUnavailabilityPage]).
Future<void> openUnavailabilityPage(
  BuildContext context, {
  required int personId,
  String personName = '',
  bool forOther = false,
}) {
  if (ProviderScope.containerOf(context, listen: false).read(redesignEnabledProvider)) {
    return Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      builder: (_) => RdUnavailabilityPage(personId: personId, personName: personName, forOther: forOther),
    ));
  }
  // DAS-29: Ionic default `ion-modal` – full screen on phones, a centred
  // card from 768 × 600.
  return showIonModal<void>(
    context,
    builder: (_) => UnavailabilityPage(personId: personId, personName: personName, forOther: forOther),
  );
}

/// "Regelmäßig verhindert": weekly rules (e.g. every Wednesday, Kinderstunde).
/// New Termine on a matching weekday get "Entschuldigt" automatically; already
/// planned ones can be updated when saving.
class UnavailabilityPage extends ConsumerStatefulWidget {
  const UnavailabilityPage({
    super.key,
    required this.personId,
    this.personName = '',
    this.forOther = false,
  });

  final int personId;
  final String personName;

  /// Opened by the leadership for someone else
  final bool forOther;

  @override
  ConsumerState<UnavailabilityPage> createState() => _UnavailabilityPageState();
}

class _UnavailabilityPageState extends ConsumerState<UnavailabilityPage> {
  PersonUnavailability? _editing;
  final _reasonController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  List<AttendanceType> get _types =>
      (ref.read(attendanceTypesProvider).valueOrNull ?? const []).where((t) => t.visible).toList();

  String _typesText(PersonUnavailability rule, List<AttendanceType> types) {
    if (rule.typeIds.isEmpty) return context.l10n.dutyAllTypes;
    return rule.typeIds
        .map((id) => types.where((t) => t.id == id).firstOrNull?.name)
        .whereType<String>()
        .join(', ');
  }

  String _untilText(PersonUnavailability rule) {
    final until = DateTime.tryParse(rule.validUntil ?? '');
    if (until == null) return context.l10n.dutyUnlimited;
    return context.l10n.dutyUntil(DateFormat(dateFmt()).format(until));
  }

  void _add() {
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) return;
    final dutyTypeIds = _types.where((t) => t.dutyMode && t.id != null).map((t) => t.id!).toList();
    _reasonController.text = '';
    setState(() {
      _editing = PersonUnavailability(
        tenantId: tenantId,
        personId: widget.personId,
        typeIds: dutyTypeIds,
      );
    });
  }

  void _edit(PersonUnavailability rule) {
    _reasonController.text = rule.reason;
    setState(() => _editing = rule);
  }

  Future<void> _save() async {
    final editing = _editing;
    if (editing == null) return;
    if (editing.weekdays.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.dutyChooseWeekday);
      return;
    }
    setState(() => _saving = true);
    final saved = await ref
        .read(dutyNotifierProvider.notifier)
        .saveUnavailability(editing.copyWith(reason: _reasonController.text.trim()));
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved == null) {
      ToastHelper.showError(context, context.l10n.extraFieldsSaveFailed);
      return;
    }
    setState(() => _editing = null);
    await _offerApplyToFuture(saved);
  }

  Future<void> _offerApplyToFuture(PersonUnavailability rule) async {
    final repo = ref.read(dutyRepositoryWithTenantProvider);
    // P10_SELF_PLAN: Ionic passes the visible types (`this.types`).
    final (:count, :dates) = await repo.countFutureMatches(rule, _types);
    if (!mounted) return;
    if (count == 0) {
      ToastHelper.showSuccess(context, context.l10n.dutySaved);
      return;
    }
    final preview = dates.take(4).map((d) {
          final date = DateTime.tryParse(d)?.toLocal();
          return date == null ? d : DateFormat(dateFmt(DateFmtKind.dayMonth)).format(date);
        }).join(', ') +
        (count > 4 ? ' …' : '');
    final l10n = context.l10n;
    final message = widget.forOther
        ? l10n.dutyAlsoPlannedOther(count, preview, widget.personName.split(' ').first)
        : l10n.dutyAlsoPlannedSelf(count, preview);
    final apply = await DialogHelper.showConfirmation(
      context,
      title: l10n.dutyAlsoPlanned,
      message: message,
      confirmText: l10n.dutyAlsoPlannedButton,
      cancelText: l10n.dutyOnlyNew,
    );
    if (!apply || !mounted) return;
    final changed = await ref.read(dutyNotifierProvider.notifier).applyUnavailabilityToFuture(rule);
    if (!mounted) return;
    if (changed == null) {
      ToastHelper.showError(context, l10n.svcApplyToPlannedFailed);
      return;
    }
    ToastHelper.showSuccess(context, l10n.dutyEventsAdjusted(changed));
  }

  Future<void> _remove(PersonUnavailability rule) async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.dutyDeleteRuleConfirm,
      message: context.l10n.dutyDeleteRuleMessage,
      confirmText: context.l10n.commonDelete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref.read(dutyNotifierProvider.notifier).deleteUnavailability(rule);
    if (!ok && mounted) ToastHelper.showError(context, context.l10n.dutyFlutterDeleteFailed);
  }

  Future<void> _pickValidUntil() async {
    final editing = _editing;
    if (editing == null) return;
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: DateTime.tryParse(editing.validUntil ?? '') ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      // md look: Ionic has a native date input here (calendar with buttons).
      overlay: IonDatetimeOverlay.buttons,
    );
    if (picked == null) return;
    final iso = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() => _editing = editing.copyWith(validUntil: iso));
  }

  @override
  Widget build(BuildContext context) {
    final editing = _editing;
    // Ionic: centered title with a small grey `.sub` line.
    final title = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.l10n.signoutRegularlyUnavailable),
        if (widget.forOther && widget.personName.isNotEmpty)
          Text(widget.personName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.medium)),
      ],
    );

    return PopScope(
      canPop: editing == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _editing = null);
      },
      child: Scaffold(
        appBar: AppBar(
          // Ionic: text button "Zurück" while editing a rule.
          // DAS-02: Ionic `ion-buttons` (iOS glass capsule).
          leadingWidth: editing != null ? (useIosLook(context) ? 120 : 90) : (useIosLook(context) ? 68 : null),
          leading: editing != null
              ? ToolbarButtonGroup(children: [
                  TextButton(
                    onPressed: () => setState(() => _editing = null),
                    child: IonButtonLabel(context.l10n.commonBack),
                  ),
                ])
              : IonCloseButton(onPressed: () => Navigator.of(context).pop()),
          // F-TEAM-20: iOS `ion-title` lies over the whole toolbar with
          // `padding-inline: 90px`, so "Regelmäßig verhindert" fits between
          // "Zurück" and "Speichern" (between the buttons it was cut off).
          title: useIosLook(context) ? null : title,
          flexibleSpace: useIosLook(context)
              ? SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 90),
                    child: Center(
                      child: DefaultTextStyle.merge(
                        style: Theme.of(context).appBarTheme.titleTextStyle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        child: title,
                      ),
                    ),
                  ),
                )
              : null,
          actions: [
            if (editing != null)
              ToolbarButtonGroup(children: [
                TextButton(
                  onPressed: _saving ? null : _save,
                  child: IonButtonLabel(context.l10n.commonSave, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ]),
          ],
        ),
        body: editing != null ? _buildEditor(editing) : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    final rulesAsync = ref.watch(unavailabilityByPersonProvider(widget.personId));
    final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[];
    return rulesAsync.when(
      loading: () => const Center(child: AppSpinner()),
      error: (e, _) => Center(child: Text(context.l10n.dutyFlutterErrorWith(friendlyErrorMessage(e)))),
      data: (rules) => ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          if (rules.isEmpty)
            // Ionic `.empty`
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Text(
                widget.forOther
                    ? context.l10n.dutyNoRuleOther
                    : context.l10n.dutyNoRuleSelf,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.medium),
              ),
            )
          else
            IonInsetList(
              children: [
                for (final rule in rules)
                  ListTile(
                    title: Text(
                        '${weekdaysText(rule.weekdays)}${rule.reason.isNotEmpty ? ' · ${rule.reason}' : ''}'),
                    subtitle: Text('${_typesText(rule, types)} · ${_untilText(rule)}',
                        style: const TextStyle(color: AppColors.medium)),
                    onTap: () => _edit(rule),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(AppIcons.deleteOutline, color: AppColors.danger),
                          tooltip: context.l10n.dutyDeleteRule,
                          onPressed: () => _remove(rule),
                        ),
                        const IonDetailIcon(),
                      ],
                    ),
                  ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: FilledButton.icon(
              onPressed: _add,
              icon: Icon(AppIcons.add),
              label: IonButtonLabel(context.l10n.dutyAddRule),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(PersonUnavailability editing) {
    final types = _types;
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        // Ionic: inset list "Wochentage" with ion-chips.
        IonInsetList(
          header: context.l10n.dutyWeekdays,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < 7; i++)
                    Tooltip(
                      message: weekdayLongNames[i],
                      child: IonChip(
                        label: weekdayShortNames[i],
                        color: editing.weekdays.contains(i + 1) ? AppColors.primary : AppColors.medium,
                        outline: !editing.weekdays.contains(i + 1),
                        onTap: () {
                          final list = [...editing.weekdays];
                          list.contains(i + 1) ? list.remove(i + 1) : list.add(i + 1);
                          list.sort();
                          setState(() => _editing = editing.copyWith(weekdays: list));
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        IonInsetList(
          header: context.l10n.dutyForWhichTypes,
          dividerIndent: 56,
          children: [
            for (final t in types)
              CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                value: editing.typeIds.contains(t.id),
                title: Text(t.name),
                onChanged: (_) {
                  final list = [...editing.typeIds];
                  if (!list.remove(t.id)) list.add(t.id!);
                  setState(() => _editing = editing.copyWith(typeIds: list));
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Text(context.l10n.dutyAllTypesHint,
                  style: const TextStyle(color: AppColors.medium, fontSize: 12)),
            ),
          ],
        ),
        IonInsetList(
          children: [
            IonStackedInput(
              controller: _reasonController,
              label: context.l10n.dutyReasonOptional,
              hint: context.l10n.dutyChildrenHourPlaceholder,
            ),
            ListTile(
              title: Text(context.l10n.dutyValidUntil, style: const TextStyle(fontSize: 12, color: AppColors.medium)),
              subtitle: Text(_untilText(editing), style: Theme.of(context).textTheme.bodyLarge),
              onTap: _pickValidUntil,
              trailing: editing.validUntil != null
                  ? IconButton(
                      icon: Icon(AppIcons.clear, color: AppColors.medium, semanticLabel: context.l10n.a11yClearInput),
                      onPressed: () => setState(() => _editing = editing.copyWith(validUntil: null)),
                    )
                  : Icon(AppIcons.calendarToday, color: AppColors.medium),
            ),
          ],
        ),
        // Ionic `.hint`
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Text(
            context.l10n.dutyRuleHint,
            style: const TextStyle(color: AppColors.medium, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
