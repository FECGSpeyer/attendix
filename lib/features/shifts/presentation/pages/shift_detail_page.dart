import 'dart:async';

import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/shift_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/shift/shift_definition.dart';
import '../../../../data/models/shift/shift_instance.dart';
import '../../../../data/models/shift/shift_plan.dart';
import '../../../planning/presentation/widgets/ion_items.dart';
import '../widgets/copy_shift_to_tenant_sheet.dart';
import '../widgets/shift_preview_sheet.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../planning/presentation/widgets/plan_field_dialogs.dart' show PlanSheetAction;
import '../../../planning/presentation/widgets/rd_plan_widgets.dart';
import '../../../redesign/presentation/widgets/event/rd_form_widgets.dart' show RdFieldRow, rdInputDecoration;
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../redesign/presentation/widgets/today/rd_today_common.dart' show RdInfoCard;

part 'shift_detail_page_beta.dart';

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

  // REDESIGN: live saving of the Beta page (shift_detail_page_beta.dart).
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
  Widget build(BuildContext context) {
    if (context.rdSkin != null) return _rdBuild(context);
    final shiftAsync = ref.watch(shiftByIdProvider(widget.shiftId));
    final usageCount = ref.watch(shiftUsageCountProvider(widget.shiftId));
    // Ionic `@if (linkedTenants.length > 0)`: hidden while loading/on error.
    final copyTargetsAsync = ref.watch(shiftCopyTargetTenantsProvider);

    return IonCondenseScaffold(
      title: context.l10n.shiftsEdit,
      leading: IconButton(
        icon: Icon(AppIcons.arrowBack),
        tooltip: context.l10n.commonBack,
        onPressed: _goBack,
      ),
      actions: [
        // Copy to tenant button (only with linked tenants)
        copyTargetsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (targets) {
            if (targets.isEmpty) return const SizedBox.shrink();

            return IconButton(
              icon: Icon(AppIcons.copyOutlined),
              tooltip: context.l10n.shiftsCopyToTenant,
              onPressed: () => _copyToTenant(context, shiftAsync.valueOrNull),
            );
          },
        ),
        IconButton(
          icon: Icon(AppIcons.deleteOutline, color: AppColors.danger),
          tooltip: context.l10n.commonDelete,
          onPressed: () => _confirmDelete(context),
        ),
      ],
      floatingActionButton: TabBarFab.wrap(FloatingActionButton(
        onPressed: _isLoading ? null : _saveChanges,
        tooltip: context.l10n.commonSave,
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: AppSpinner(strokeWidth: 2, color: Colors.white),
              )
            : Icon(AppIcons.saveOutlined),
      )),
      bodyBuilder: (context, largeTitle) => ListView(
        padding: EdgeInsets.only(bottom: scrollEndPadding(context, base: 16, fabRoom: 84)), // Space for FAB
        children: [
          if (largeTitle != null) largeTitle,
          _buildIntroCard(context),
          ...shiftAsync.when(
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: AppSpinner()),
              ),
            ],
            error: (error, stack) => [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.l10n.shiftsFlutterErrorWith(friendlyErrorMessage(error))),
              ),
            ],
            data: (shift) {
              if (shift == null) {
                return [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(context.l10n.shiftsFlutterNotFound, textAlign: TextAlign.center),
                  ),
                ];
              }
              _initializeFromShift(shift);
              // A failed usage check counts as used: name/date/remove of
              // the fixed shifts stay locked instead of being released.
              return [
                _buildList(context, shift,
                    usageCount.hasError ? 1 : usageCount.valueOrNull ?? 0),
              ];
            },
          ),
        ],
      ),
    );
  }

  /// Ionic intro `ion-card`: time icon header, intro text and the danger
  /// warning label.
  Widget _buildIntroCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(AppIcons.schedule, size: 64, color: AppColors.medium),
            const SizedBox(height: 16),
            Text(
              context.l10n.shiftsEditIntro,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.medium),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.shiftsWarning,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.danger),
            ),
          ],
        ),
      ),
    );
  }

  /// `ion-label > p`: small grey label.
  Widget _pLabel(String text) => Text(text, style: const TextStyle(fontSize: 14, color: AppColors.medium));

  Widget _sectionHeader(String title, {VoidCallback? onAdd, String? addTooltip}) => IonListHeader(
        title: title,
        padding: const EdgeInsets.fromLTRB(16, 14, 4, 2),
        trailing: onAdd == null
            ? null
            : IconButton(
                icon: Icon(AppIcons.add),
                color: AppColors.primary,
                tooltip: addTooltip,
                onPressed: onAdd,
              ),
      );

  static const _line = Divider(height: 1, indent: 16);

  Widget _buildList(BuildContext context, ShiftPlan shift, int usageCount) {
    final isUsed = usageCount > 0;
    return IonInsetList(
      dividerIndent: null,
      children: [
        // General
        _sectionHeader(context.l10n.generalSettingsGeneral),
        IonStackedInput(
          controller: _nameController,
          label: context.l10n.typeSettingsName,
          onChanged: (_) => _markChanged(),
        ),
        _line,
        IonStackedInput(
          controller: _descriptionController,
          label: context.l10n.tasksDescription,
          onChanged: (_) => _markChanged(),
        ),
        _line,

        // Definition
        _sectionHeader(context.l10n.shiftsDefinition,
            onAdd: _addSegment, addTooltip: context.l10n.shiftsFlutterAddSegment),
        if (_definitions.isEmpty) ...[
          ListTile(title: Text(context.l10n.shiftsNoShifts)),
          _line,
        ] else ...[
          for (var i = 0; i < _definitions.length; i++) ..._buildSegment(context, i),
          ListTile(
            title: Text(context.l10n.shiftsExample, style: const TextStyle(color: AppColors.primary)),
            onTap: () => _showPreview(context, shift, null),
          ),
          _line,
        ],

        // Fixed shifts (optional)
        _sectionHeader(context.l10n.shiftsFixedOptional,
            onAdd: _addShiftInstance, addTooltip: context.l10n.shiftsFlutterAddShift),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Text(context.l10n.shiftsFixedIntro, style: const TextStyle(fontSize: 14)),
        ),
        _line,
        if (_shifts.isEmpty)
          ListTile(title: Text(context.l10n.shiftsNoShifts))
        else
          for (var i = 0; i < _shifts.length; i++)
            _ShiftInstanceTile(
              key: ValueKey('shift_$i'),
              instance: _shifts[i],
              isLast: i == _shifts.length - 1,
              // LOGIC_SETTINGS: Ionic disables name/date/remove when the
              // plan is used by persons (they reference shift_name).
              isUsed: isUsed,
              onNameChanged: (name) => _updateShiftName(i, name),
              onDateChanged: (date) => _updateShiftDate(i, date),
              onDelete: () => _deleteShiftInstance(i),
              onShowPreview: () => _showPreview(context, shift, _shifts[i]),
            ),
      ],
    );
  }

  /// One definition segment: primary header row "Abschnitt n" with trash,
  /// "Frei" toggle, start time, duration and repetitions.
  List<Widget> _buildSegment(BuildContext context, int index) {
    final segment = _definitions[index];
    return [
      Material(
        color: AppColors.primary,
        child: ListTile(
          title: Text(
            context.l10n.shiftsSection(index + 1),
            style: const TextStyle(color: Colors.white),
          ),
          trailing: IconButton(
            icon: Icon(AppIcons.deleteOutline, color: Colors.white),
            tooltip: context.l10n.commonDelete,
            onPressed: () => _deleteSegment(index),
          ),
        ),
      ),
      ListTile(
        title: _pLabel(context.l10n.shiftsFree),
        trailing: Switch.adaptive(
          value: segment.free,
          onChanged: (v) => _updateSegment(index, segment.copyWith(free: v)),
        ),
      ),
      if (!segment.free) ...[
        ListTile(
          title: _pLabel(context.l10n.shiftsStartTime),
          trailing: IonDatetimeChip(
            text: segment.startTime,
            onTap: () => _pickStartTime(index),
          ),
        ),
        IonStackedInput(
          controller: _durationControllers[index],
          label: context.l10n.shiftsDurationHours,
          helper: context.l10n.shiftsDecimalHelper,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (text) {
            final value = double.tryParse(text.replaceAll(',', '.'));
            if (value == null) return;
            _updateSegment(index, _definitions[index].copyWith(duration: value.clamp(0, 24).toDouble()));
          },
        ),
        _line,
      ],
      IonStackedInput(
        controller: _repeatControllers[index],
        label: context.l10n.shiftsRepetitions,
        helper: context.l10n.shiftsRepetitionsHelper,
        keyboardType: TextInputType.number,
        onChanged: (text) {
          final value = int.tryParse(text);
          if (value == null) return;
          _updateSegment(index, _definitions[index].copyWith(repeatCount: value.clamp(1, 365)));
        },
      ),
      _line,
    ];
  }

  Future<void> _pickStartTime(int index) async {
    final parts = _definitions[index].startTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '8') ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final time = await showAppTimePicker(context: context, initialTime: initialTime);
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

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      ToastHelper.showError(context, context.l10n.shiftsEnterName);
      return;
    }

    setState(() => _isLoading = true);

    final notifier = ref.read(shiftNotifierProvider.notifier);
    final updatedPlan = ShiftPlan(
      id: widget.shiftId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      definition: _numberedDefinitions(),
      shifts: _shifts,
    );

    final result = await notifier.updateShift(updatedPlan);

    if (mounted) {
      setState(() => _isLoading = false);

      if (result != null) {
        setState(() => _hasChanges = false);
        ToastHelper.showSuccess(context, context.l10n.shiftsSaved);
      } else {
        final error = ref.read(shiftNotifierProvider);
        if (error.hasError) {
          ToastHelper.showError(context, context.l10n.shiftsFlutterErrorWith(friendlyErrorMessage(error.error)));
        }
      }
    }
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

/// A fixed shift instance: stacked label input with trash, start date chip
/// and the primary "Beispiel" item (Ionic fixed shifts group).
class _ShiftInstanceTile extends StatefulWidget {
  final ShiftInstance instance;
  final bool isUsed;
  final bool isLast;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onDelete;
  final VoidCallback onShowPreview;

  const _ShiftInstanceTile({
    super.key,
    required this.instance,
    this.isUsed = false,
    this.isLast = false,
    required this.onNameChanged,
    required this.onDateChanged,
    required this.onDelete,
    required this.onShowPreview,
  });

  @override
  State<_ShiftInstanceTile> createState() => _ShiftInstanceTileState();
}

class _ShiftInstanceTileState extends State<_ShiftInstanceTile> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.instance.name);
  }

  @override
  void didUpdateWidget(_ShiftInstanceTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.instance.name != _nameController.text) {
      _nameController.text = widget.instance.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(widget.instance.date) ?? DateTime.now();
    final dateFormat = DateFormat.yMMMd(currentIntlLocale());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: IonStackedInput(
                controller: _nameController,
                label: context.l10n.shiftsLabel,
                enabled: !widget.isUsed,
                onChanged: widget.onNameChanged,
              ),
            ),
            IconButton(
              icon: Icon(AppIcons.deleteOutline,
                  color: widget.isUsed ? AppColors.medium : AppColors.danger),
              onPressed: widget.isUsed ? null : widget.onDelete,
              tooltip: context.l10n.commonDelete,
            ),
          ],
        ),
        ListTile(
          title: Text(context.l10n.shiftsStartDate),
          trailing: Opacity(
            opacity: widget.isUsed ? 0.5 : 1,
            child: IonDatetimeChip(
              text: dateFormat.format(date),
              onTap: widget.isUsed ? null : () => _selectDate(context, date),
            ),
          ),
        ),
        ListTile(
          title: Text(context.l10n.shiftsExample, style: const TextStyle(color: AppColors.primary)),
          onTap: widget.onShowPreview,
        ),
        if (!widget.isLast) const Divider(height: 1, indent: 16),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, DateTime currentDate) async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: Locale(currentLanguage()),
    );

    if (selected != null) {
      widget.onDateChanged(selected);
    }
  }
}
