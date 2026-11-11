import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/attendance_type_providers.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/demo_guard.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../data/repositories/attendance_type_repository.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../planning/presentation/widgets/rd_plan_widgets.dart' show showRdPlanSheet;
import '../../../../settings/presentation/pages/attendance_type_edit_page.dart' show buildNewAttendanceType;
import '../event/rd_form_widgets.dart' show RdFieldRow, rdInputDecoration;
import '../rd_widgets.dart';

/// Beta "Neue Terminart": a name and "Startet wie" (one of the group's
/// types, copied with everything switched on, or "Leer"). Returns the id
/// of the created type; the caller opens its page.
/// The "Anlegen" button stays pinned above the keyboard; the sheet has a
/// close button and stays below the status bar.
Future<String?> showRdTypeCreateSheet(BuildContext context) {
  final l10n = context.l10n;
  final formKey = GlobalKey<_RdTypeCreateFormState>();
  // Not disposed: the pinned button may still listen during the closing
  // animation; it holds no resources and is collected with the sheet.
  final busy = ValueNotifier<bool>(false);
  return showRdPlanSheet<String>(
    context,
    title: l10n.rdTypeNewTitle,
    builder: (ctx, pop) => [_RdTypeCreateForm(key: formKey, busy: busy, onCreated: pop)],
    footer:
        (ctx, pop) => ValueListenableBuilder<bool>(
          valueListenable: busy,
          builder:
              (_, isBusy, __) => RdPrimaryButton(
                key: const Key('rd-type-new-create'),
                label: l10n.rdTypeNewCreate,
                loading: isBusy,
                onPressed: isBusy ? null : () => formKey.currentState?._create(),
              ),
        ),
  );
}

class _RdTypeCreateForm extends ConsumerStatefulWidget {
  const _RdTypeCreateForm({super.key, required this.busy, required this.onCreated});

  /// Shared with the pinned "Anlegen" button of the sheet.
  final ValueNotifier<bool> busy;
  final void Function(String id) onCreated;

  @override
  ConsumerState<_RdTypeCreateForm> createState() => _RdTypeCreateFormState();
}

class _RdTypeCreateFormState extends ConsumerState<_RdTypeCreateForm> {
  final _name = TextEditingController();

  /// Id of the type to copy; null = "Leer". Starts with the first type.
  String? _template;
  bool _templateSet = false;
  bool get _busy => widget.busy.value;
  set _busyValue(bool v) {
    widget.busy.value = v;
    setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;
    final l10n = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ToastHelper.showError(context, l10n.typeSettingsEnterName);
      return;
    }
    final notifier = ref.read(attendanceTypeNotifierProvider.notifier);
    _busyValue = true;
    try {
      final template = _template;
      final AttendanceType created;
      if (template != null) {
        created = await notifier.copyType(template, name);
      } else {
        final data = AttendanceTypeRepository.buildInsertData(buildNewAttendanceType(name), 0)..remove('tenant_id');
        created = await notifier.createTypeFromData({...data, 'manage_songs': true, 'place_enabled': true});
      }
      if (!mounted) return;
      final id = created.id;
      if (id != null) widget.onCreated(id);
    } on DemoModeException {
      // DEMO_GUARD: the demo warning toast was already shown.
    } catch (_) {
      if (mounted) ToastHelper.showError(context, l10n.typeSettingsCreateFailed);
    } finally {
      if (mounted) _busyValue = false;
    }
  }

  String _summary(AttendanceType t) {
    final l10n = context.l10n;
    String hhmm(String? v) => v == null ? '' : (v.length >= 5 ? v.substring(0, 5) : v);
    final parts = <String>[
      if (t.allDay) l10n.rdTypeAllDay else '${hhmm(t.startTime)}–${hhmm(t.endTime)}',
      if (((t.defaultPlan?['fields'] as List?) ?? const []).isNotEmpty) l10n.rdTypePlan,
      if (t.checklist != null) l10n.rdTypeChecklist,
      if (t.dutyMode) l10n.rdTypeDuty,
      if (t.includeInAverage) l10n.rdTypeCountsForQuota,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final types = (ref.watch(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[]).where((t) => t.id != null).toList();
    if (!_templateSet && types.isNotEmpty) {
      _templateSet = true;
      _template = types.first.id;
    }

    Widget option(String? id, String title, String subtitle) {
      final selected = _template == id;
      return RdListRow(
        key: Key('rd-type-new-${id ?? 'empty'}'),
        leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selected ? p.primary : p.text2),
        title: title,
        subtitle: subtitle,
        showChevron: false,
        selected: selected,
        onTap: _busy ? null : () => setState(() => _template = id),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupedList(
          children: [
            RdFieldRow(
              label: l10n.rdTypeNewName,
              child: TextField(
                key: const Key('rd-type-new-name'),
                controller: _name,
                enabled: !_busy,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                style: TextStyle(fontSize: 17, color: p.text),
                decoration: rdInputDecoration(p, l10n.rdTypeNewNameHint),
                onSubmitted: (_) => _create(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        RdGroupLabel(l10n.rdTypeNewStartsLike),
        RdGroupedList(
          children: [for (final t in types) option(t.id, t.name, _summary(t)), option(null, l10n.rdTypeNewEmpty, l10n.rdTypeNewEmptyHint)],
        ),
        Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 0), child: Text(l10n.rdTypeNewStartsLikeHint, style: RdType.meta(p, size: 13))),
      ],
    );
  }
}
