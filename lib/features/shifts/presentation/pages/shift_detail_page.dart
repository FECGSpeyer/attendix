import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/shift_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/shift/shift_definition.dart';
import '../../../../data/models/shift/shift_instance.dart';
import '../../../../data/models/shift/shift_plan.dart';
import '../widgets/copy_shift_to_tenant_sheet.dart';
import '../widgets/shift_preview_sheet.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/theme/design_theme.dart';
import '../../../planning/presentation/widgets/plan_field_dialogs.dart' show PlanSheetAction;
import '../../../planning/presentation/widgets/plan_widgets.dart';
import '../../../attendance/presentation/widgets/event/form_widgets.dart' show RdFieldRow, rdInputDecoration;
import '../../../../shared/widgets/components/components.dart';
import '../../../today/presentation/widgets/today_common.dart' show RdInfoCard;

part 'shift_detail_view.dart';

/// Shift Detail Page
///
/// Shows and edits a single shift plan with definition segments and fixed
/// shifts. Layout mirrors Ionic `shift.page.html`: light toolbar with
/// arrow-back, copy and delete, condense large title, intro card and one
/// inset list with the sections General / Definition / Fixed shifts.
class ShiftDetailPage extends ConsumerStatefulWidget {
  final String shiftId;

  const ShiftDetailPage({super.key, required this.shiftId});

  @override
  ConsumerState<ShiftDetailPage> createState() => _ShiftDetailPageState();
}

class _ShiftDetailPageState extends ConsumerState<ShiftDetailPage> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  List<ShiftDefinition> _definitions = [];
  // Per segment input controllers (Ionic edits segments inline).
  final List<TextEditingController> _durationControllers = [];
  final List<TextEditingController> _repeatControllers = [];
  List<ShiftInstance> _shifts = [];
  bool _isLoading = false;
  bool _hasChanges = false;
  bool _isInitialized = false;

  // Debounced live saving of the detail view (shift_detail_view.dart).
  Timer? _rdSaveTimer;
  ShiftNotifier? _rdNotifier;

  /// REDESIGN: saves run one after another, also the flush on dispose.
  Future<void> _rdChain = Future.value();

  void _update(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    // Ionic ShiftService: a failed usage check toasts "Fehler beim
    // Überprüfen der Schichtverwendung" (also for a cached error).
    ref.listenManual<AsyncValue<int>>(
      shiftUsageCountProvider(widget.shiftId),
      (previous, next) {
        if (next.hasError && !next.isLoading && previous?.hasError != true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ToastHelper.showError(context, context.l10n.svcCheckShiftUsageFailed);
          });
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    // REDESIGN: a change made right before leaving is still saved.
    _rdSaveTimer?.cancel();
    final notifier = _rdNotifier;
    if (notifier != null && _hasChanges && _nameController.text.trim().isNotEmpty) {
      final plan = _rdPlan();
      unawaited(_rdChain.then((_) => notifier.updateShift(plan)).then((_) {}, onError: (_) {}));
    }
    _nameController.dispose();
    _descriptionController.dispose();
    for (final c in [..._durationControllers, ..._repeatControllers]) {
      c.dispose();
    }
    super.dispose();
  }

  void _initializeFromShift(ShiftPlan shift) {
    if (!_isInitialized) {
      _nameController.text = shift.name;
      _descriptionController.text = shift.description;
      _definitions = List.from(shift.definition);
      for (final d in _definitions) {
        _addSegmentControllers(d);
      }
      _shifts = List.from(shift.shifts);
      _isInitialized = true;
    }
  }

  void _addSegmentControllers(ShiftDefinition d) {
    _durationControllers.add(TextEditingController(text: _formatNumber(d.duration)));
    _repeatControllers.add(TextEditingController(text: d.repeatCount.toString()));
  }

  static String _formatNumber(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings/shifts');
    }
  }

  @override
  Widget build(BuildContext context) => _rdBuild(context);

  Future<void> _pickStartTime(int index) async {
    final parts = _definitions[index].startTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '8') ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final time = await showAppTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (time == null || !mounted || index >= _definitions.length) return;
    _updateSegment(
      index,
      _definitions[index].copyWith(
        startTime: '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      ),
    );
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  /// The segments with `index` = list position. Loading sorts by `index`
  /// (Ionic loadShifts); deleting a segment leaves gaps and a new segment
  /// gets `_definitions.length`, which could equal a remaining index and
  /// move the new segment on the next load.
  List<ShiftDefinition> _numberedDefinitions() => [
        for (var i = 0; i < _definitions.length; i++)
          _definitions[i].index == i ? _definitions[i] : _definitions[i].copyWith(index: i),
      ];

  // Definition segment methods
  void _addSegment() {
    setState(() {
      final segment = ShiftDefinition(
        index: _definitions.length,
        startTime: '08:00',
        duration: 8.0,
        free: false,
        repeatCount: 1,
      );
      _definitions.add(segment);
      _addSegmentControllers(segment);
      _markChanged();
    });
  }

  void _updateSegment(int index, ShiftDefinition segment) {
    setState(() {
      _definitions[index] = segment;
      _markChanged();
    });
  }

  void _deleteSegment(int index) {
    setState(() {
      _definitions.removeAt(index);
      _durationControllers.removeAt(index).dispose();
      _repeatControllers.removeAt(index).dispose();
      _markChanged();
    });
  }

  // Shift instance methods
  void _addShiftInstance() {
    setState(() {
      _shifts.add(ShiftInstance(
        name: '',
        date: DateTime.now().toIso8601String(),
      ));
      _markChanged();
    });
  }

  void _updateShiftName(int index, String name) {
    setState(() {
      _shifts[index] = _shifts[index].copyWith(name: name);
      _markChanged();
    });
  }

  void _updateShiftDate(int index, DateTime date) {
    setState(() {
      _shifts[index] = _shifts[index].copyWith(date: date.toIso8601String());
      _markChanged();
    });
  }

  void _deleteShiftInstance(int index) {
    setState(() {
      _shifts.removeAt(index);
      _markChanged();
    });
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    // Ionic shifts.deleteMessage (warns about the shifts and assignments).
    final message = l10n.shiftsDeleteMessage;

    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(l10n.shiftsDelete),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final notifier = ref.read(shiftNotifierProvider.notifier);
      final success = await notifier.deleteShift(widget.shiftId);

      if (context.mounted) {
        if (success) {
          ToastHelper.showSuccess(context, l10n.shiftsDeleted);
          context.pop();
        } else {
          ToastHelper.showError(context, l10n.shiftsDeleteFailed);
        }
      }
    }
  }

  void _showPreview(BuildContext context, ShiftPlan shift, ShiftInstance? startInstance) {
    // Create a plan with current edits
    final previewPlan = shift.copyWith(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      definition: _numberedDefinitions(),
      shifts: _shifts,
    );

    showShiftPreviewSheet(context, previewPlan, startInstance: startInstance);
  }

  Future<void> _copyToTenant(BuildContext context, ShiftPlan? shift) async {
    if (shift == null) return;

    // Ionic copies the bound model, i.e. including unsaved edits.
    final currentPlan = shift.copyWith(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      definition: _numberedDefinitions(),
      shifts: _shifts,
    );

    await copyShiftToTenant(context, ref, currentPlan);
  }
}
