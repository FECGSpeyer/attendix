import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Opens "Regelmäßig verhindert" for a person (as a full screen dialog).
Future<void> openUnavailabilityPage(
  BuildContext context, {
  required int personId,
  String personName = '',
  bool forOther = false,
}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
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
    if (rule.typeIds.isEmpty) return 'alle Termintypen';
    return rule.typeIds
        .map((id) => types.where((t) => t.id == id).firstOrNull?.name)
        .whereType<String>()
        .join(', ');
  }

  String _untilText(PersonUnavailability rule) {
    final until = DateTime.tryParse(rule.validUntil ?? '');
    if (until == null) return 'unbefristet';
    return 'bis ${until.day.toString().padLeft(2, '0')}.${until.month.toString().padLeft(2, '0')}.${until.year}';
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
      ToastHelper.showWarning(context, 'Bitte wähle mindestens einen Wochentag');
      return;
    }
    setState(() => _saving = true);
    final saved = await ref
        .read(dutyNotifierProvider.notifier)
        .saveUnavailability(editing.copyWith(reason: _reasonController.text.trim()));
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved == null) {
      ToastHelper.showError(context, 'Fehler beim Speichern');
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
      ToastHelper.showSuccess(context, 'Gespeichert');
      return;
    }
    final preview = dates.take(4).map((d) {
          final date = DateTime.tryParse(d)?.toLocal();
          return date == null ? d : '${date.day}.${date.month}.';
        }).join(', ') +
        (count > 4 ? ' …' : '');
    final countText = count == 1
        ? '1 schon geplanter Termin passt'
        : '$count schon geplante Termine passen';
    final message = widget.forOther
        ? '$countText zu dieser Regel ($preview). Soll ${widget.personName.split(' ').first} dort als '
            'entschuldigt eingetragen werden? Termine mit eigener Antwort oder Einteilung bleiben unverändert.'
        : '$countText zu dieser Regel ($preview). Sollst du dort als entschuldigt eingetragen werden? '
            'Termine mit eigener Antwort oder Einteilung bleiben unverändert.';
    final apply = await DialogHelper.showConfirmation(
      context,
      title: 'Auch geplante Termine?',
      message: message,
      confirmText: 'Auch geplante',
      cancelText: 'Nur neue Termine',
    );
    if (!apply || !mounted) return;
    final changed = await ref.read(dutyNotifierProvider.notifier).applyUnavailabilityToFuture(rule);
    if (!mounted) return;
    ToastHelper.showSuccess(context, changed == 1 ? '1 Termin angepasst' : '$changed Termine angepasst');
  }

  Future<void> _remove(PersonUnavailability rule) async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: 'Regel löschen?',
      message: 'Bereits eingetragene Abmeldungen bleiben bestehen.',
      confirmText: 'Löschen',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref.read(dutyNotifierProvider.notifier).deleteUnavailability(rule);
    if (!ok && mounted) ToastHelper.showError(context, 'Fehler beim Löschen');
  }

  Future<void> _pickValidUntil() async {
    final editing = _editing;
    if (editing == null) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
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
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Regelmäßig verhindert'),
        if (widget.forOther && widget.personName.isNotEmpty)
          Text(widget.personName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.medium)),
      ],
    );

    return PopScope(
      canPop: editing == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _editing = null);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: editing != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Zurück',
                  onPressed: () => setState(() => _editing = null),
                )
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Schließen',
                  onPressed: () => Navigator.of(context).pop(),
                ),
          title: title,
          actions: [
            if (editing != null)
              TextButton(
                onPressed: _saving ? null : _save,
                child: const Text('Speichern', style: TextStyle(fontWeight: FontWeight.bold)),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (rules) => ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          if (rules.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              child: Text(
                widget.forOther
                    ? 'Noch keine Regel. Trag ein, an welchen Wochentagen die Person grundsätzlich nicht '
                        'kann, z. B. mittwochs wegen der Kinderstunde.'
                    : 'Noch keine Regel. Trag ein, an welchen Wochentagen du grundsätzlich nicht kannst, '
                        'z. B. mittwochs wegen der Kinderstunde.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.medium),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final rule in rules)
                    ListTile(
                      title: Text(
                          '${weekdaysText(rule.weekdays)}${rule.reason.isNotEmpty ? ' · ${rule.reason}' : ''}'),
                      subtitle: Text('${_typesText(rule, types)} · ${_untilText(rule)}'),
                      onTap: () => _edit(rule),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        tooltip: 'Regel löschen',
                        onPressed: () => _remove(rule),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppDimensions.paddingM),
          FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Regel hinzufügen'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(PersonUnavailability editing) {
    final types = _types;
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      children: [
        Text('Wochentage', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppDimensions.paddingS),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < 7; i++)
              FilterChip(
                label: Text(weekdayShortNames[i]),
                tooltip: weekdayLongNames[i],
                selected: editing.weekdays.contains(i + 1),
                onSelected: (sel) {
                  final list = [...editing.weekdays];
                  sel ? list.add(i + 1) : list.remove(i + 1);
                  list.sort();
                  setState(() => _editing = editing.copyWith(weekdays: list));
                },
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.paddingL),
        Text('Für welche Termintypen?', style: Theme.of(context).textTheme.titleSmall),
        for (final t in types)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: editing.typeIds.contains(t.id),
            title: Text(t.name),
            onChanged: (_) {
              final list = [...editing.typeIds];
              if (!list.remove(t.id)) list.add(t.id!);
              setState(() => _editing = editing.copyWith(typeIds: list));
            },
          ),
        const Text('Ohne Auswahl gilt die Regel für alle Termintypen.',
            style: TextStyle(color: AppColors.medium, fontSize: 13)),
        const SizedBox(height: AppDimensions.paddingL),
        TextField(
          controller: _reasonController,
          decoration: const InputDecoration(
            labelText: 'Grund (optional)',
            hintText: 'z. B. Kinderstunde',
          ),
        ),
        const SizedBox(height: AppDimensions.paddingM),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Gültig bis (optional)'),
          subtitle: Text(_untilText(editing)),
          onTap: _pickValidUntil,
          trailing: editing.validUntil != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _editing = editing.copyWith(validUntil: null)),
                )
              : const Icon(Icons.calendar_today),
        ),
        const SizedBox(height: AppDimensions.paddingM),
        const Text(
          'Neue Termine an diesen Tagen werden automatisch als entschuldigt eingetragen. '
          'Bei Diensten wirst du dann nicht eingeteilt.',
          style: TextStyle(color: AppColors.medium, fontSize: 13),
        ),
      ],
    );
  }
}
