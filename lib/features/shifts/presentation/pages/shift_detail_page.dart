import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/shift_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
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
    final shiftAsync = ref.watch(shiftByIdProvider(widget.shiftId));
    final usageCount = ref.watch(shiftUsageCountProvider(widget.shiftId));
    final tenantsAsync = ref.watch(userTenantsProvider);
    final currentTenantId = ref.watch(currentTenantIdProvider);

    return IonCondenseScaffold(
      title: context.l10n.shiftsEdit,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: context.l10n.commonBack,
        onPressed: _goBack,
      ),
      actions: [
        // Copy to tenant button (only with linked tenants)
        tenantsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (tenants) {
            final otherTenants = tenants.where((t) => t.id != currentTenantId).toList();
            if (otherTenants.isEmpty) return const SizedBox.shrink();

            return IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: context.l10n.shiftsCopyToTenant,
              onPressed: () => _showCopySheet(context, shiftAsync.valueOrNull),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          tooltip: context.l10n.commonDelete,
          onPressed: () => _confirmDelete(context, usageCount.valueOrNull ?? 0),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _saveChanges,
        tooltip: context.l10n.commonSave,
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save_outlined),
      ),
      bodyBuilder: (context, largeTitle) => ListView(
        padding: const EdgeInsets.only(bottom: 100), // Space for FAB
        children: [
          if (largeTitle != null) largeTitle,
          _buildIntroCard(context),
          ...shiftAsync.when(
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
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
              return [_buildList(context, shift, usageCount.valueOrNull ?? 0)];
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
            const Icon(Icons.schedule, size: 64, color: AppColors.medium),
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
                icon: const Icon(Icons.add),
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
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: context.l10n.commonDelete,
            onPressed: () => _deleteSegment(index),
          ),
        ),
      ),
      ListTile(
        title: _pLabel(context.l10n.shiftsFree),
        trailing: Switch(
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
    final time = await showTimePicker(context: context, initialTime: initialTime);
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
      definition: _definitions,
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

  Future<void> _confirmDelete(BuildContext context, int usageCount) async {
    final l10n = context.l10n;
    String message = l10n.shiftsFlutterDeleteConfirm;
    if (usageCount > 0) {
      message = l10n.shiftsFlutterDeleteConfirmUsed(usageCount);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      definition: _definitions,
      shifts: _shifts,
    );

    showShiftPreviewSheet(context, previewPlan, startInstance: startInstance);
  }

  Future<void> _showCopySheet(BuildContext context, ShiftPlan? shift) async {
    if (shift == null) return;

    // Create updated plan with current edits
    final currentPlan = shift.copyWith(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      definition: _definitions,
      shifts: _shifts,
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CopyShiftToTenantSheet(shift: currentPlan),
    );
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
              icon: Icon(Icons.delete_outline,
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
    final selected = await showDatePicker(
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
