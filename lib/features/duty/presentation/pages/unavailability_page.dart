import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/duty_providers.dart';
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
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Opens "Regelmäßig verhindert" for a person (as a full screen dialog).
Future<void> openUnavailabilityPage(
  BuildContext context, {
  required int personId,
  String personName = '',
  bool forOther = false,
}) {
  return Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => UnavailabilityPage(personId: personId, personName: personName, forOther: forOther),
  ));
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
    final types = ref.read(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[];
    final (:count, :dates) = await repo.countFutureMatches(rule, types);
    if (!mounted) return;
    if (count == 0) {
      ToastHelper.showSuccess(context, context.l10n.dutySaved);
      return;
    }
    final preview = dates.take(4).map((d) {
          final date = DateTime.tryParse(d)?.toLocal();
          return date == null ? d : '${date.day}.${date.month}.';
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
          leadingWidth: editing != null ? 90 : null,
          leading: editing != null
              ? TextButton(
                  onPressed: () => setState(() => _editing = null),
                  child: IonButtonLabel(context.l10n.commonBack),
                )
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: context.l10n.commonClose,
                  onPressed: () => Navigator.of(context).pop(),
                ),
          title: title,
          actions: [
            if (editing != null)
              TextButton(
                onPressed: _saving ? null : _save,
                child: IonButtonLabel(context.l10n.commonSave, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
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
                          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
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
              icon: const Icon(Icons.add),
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
                      icon: const Icon(Icons.clear, color: AppColors.medium),
                      onPressed: () => setState(() => _editing = editing.copyWith(validUntil: null)),
                    )
                  : const Icon(Icons.calendar_today, color: AppColors.medium),
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
