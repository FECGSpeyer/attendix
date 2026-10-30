import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/holiday_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/attendance_logic_utils.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../attendance_create_writes.dart';
import '../widgets/multi_date_calendar.dart';
import '../widgets/songs_selection_sheet.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'
    hide IonInformationIcon;
import '../../../../shared/widgets/layout/ionic_ios.dart';
import '../widgets/ion_glyph_icons.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';

/// UX_ATT: opens "Termin hinzufügen" as a sheet over the list (Ionic att-list
/// addAttModal, breakpoints [0, 0.8, 1], initial 0.8). Returns true when
/// Termine were created.
Future<bool> showAttendanceCreateSheet(BuildContext context) async {
  // While saving, the sheet must not be dismissed (drag, barrier, back).
  final saving = ValueNotifier<bool>(false);
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    useSafeArea: true,
    // UX_ATT: Ionic sheet modals show the grabber (handle) at the top
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => ValueListenableBuilder<bool>(
      valueListenable: saving,
      builder: (context, isSaving, _) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 1,
        expand: false,
        snap: true,
        snapSizes: const [0.8],
        shouldCloseOnMinExtent: !isSaving,
        builder: (context, scrollController) => AttendanceCreatePage(
          asSheet: true,
          scrollController: scrollController,
          savingNotifier: saving,
        ),
      ),
    ),
  );
  saving.dispose();
  return result ?? false;
}

/// Page for creating a new attendance with all Ionic-like features:
/// - Multi-date selection
/// - Holiday highlighting
/// - TypeInfo custom text
/// - All-day duration
/// - Songs/works selection with conductor
/// - Checklist from type
/// - Relevant groups filtering
/// - Shift-based auto-status
///
/// UX_ATT: layout mirrors the Ionic addAttModal (inset grouped list:
/// Datum, Typ, Dauer, Info-Text, Benötigte Personen, Ort, Werke, primary
/// "Termin(e) hinzufügen" row).
class AttendanceCreatePage extends ConsumerStatefulWidget {
  const AttendanceCreatePage({
    super.key,
    this.asSheet = false,
    this.scrollController,
    this.savingNotifier,
  });

  /// Shown via [showAttendanceCreateSheet]: pops with `true` after creating
  /// and stays on the list (Ionic), instead of opening the new Termin.
  final bool asSheet;
  final ScrollController? scrollController;

  /// Set while saving so the hosting sheet blocks drag-to-close.
  final ValueNotifier<bool>? savingNotifier;

  @override
  ConsumerState<AttendanceCreatePage> createState() =>
      _AttendanceCreatePageState();
}

class _AttendanceCreatePageState extends ConsumerState<AttendanceCreatePage> {
  // Multi-date selection (Ionic: today is pre-selected)
  List<DateTime> _selectedDates = [_today()];

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 12);
  }

  // Type selection
  AttendanceType? _selectedType;

  // Times
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // TypeInfo (custom display text)
  String? _typeInfo;

  // All-day duration
  int _durationDays = 1;
  // FN-003: Duration controller as state variable to prevent memory leak
  late final TextEditingController _durationController;

  // ATT_DETAIL: place for navigation (types with place_enabled)
  String? _place;

  // Songs selection (if type.manageSongs)
  List<SongHistoryEntry> _songEntries = [];

  // Loading state
  bool _isLoading = false;

  // DUTY: persons needed per ISO weekday (Dienst-Modus)
  Map<int, int> _dutyRequiredByWeekday = {};

  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(text: '$_durationDays');
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(visibleAttendanceTypesProvider);
    final isAllDay = _selectedType?.allDay == true;
    // P10_ATTENDANCE: Ionic showSongsSelection(): !isGeneral && manage_songs
    final showSongs = showSongsForType(_selectedType, ref.watch(currentTenantProvider)?.type);
    final types = typesAsync.valueOrNull ?? const <AttendanceType>[];
    final ios = isIosLook(context);

    // Auto-select first visible type (Ionic type_id = first visible type)
    if (_selectedType == null && types.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedType == null) _onTypeChanged(types.first);
      });
    }

    final canSubmit = !_isLoading && _selectedDates.isNotEmpty;
    final submitLabel =
        _selectedDates.length > 1 ? context.l10n.attListAddEvents : context.l10n.attListAddEvent;

    final body = ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.only(bottom: scrollEndPadding(context, base: 32)),
      children: [
        _InsetGroup(children: [
          // Datum (Mehrfachauswahl möglich) + info button
          if (ios)
            _iosDateRow(context)
          else
          ListTile(
            title: Text(
              context.l10n.attListDateMulti,
              style: const TextStyle(fontSize: 12, color: AppColors.medium),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _getDateDisplayText(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.info_outline),
              color: AppColors.primary,
              tooltip: context.l10n.attListEventTypes,
              onPressed: _showHolidayInfo,
            ),
            onTap: _onDateClick,
          ),
          // Typ (ion-select). IOS_FORMS2: label and value share one row; the
          // value takes the remaining width (a long type name used to squeeze
          // the "Typ" label into a vertical column).
          if (ios)
            _iosTypeRow(context, typesAsync)
          else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(context.l10n.attListType,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(width: 16),
                Expanded(
                  child: typesAsync.when(
                    loading: () => const Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: AppSpinner(strokeWidth: 2),
                      ),
                    ),
                    error: (e, _) => const Align(
                      alignment: Alignment.centerRight,
                      child: Icon(Icons.error_outline, color: AppColors.danger),
                    ),
                    data: (types) => DropdownButtonHideUnderline(
                      child: DropdownButton<AttendanceType>(
                        isExpanded: true,
                        value: types.contains(_selectedType) ? _selectedType : null,
                        hint: Align(
                          alignment: Alignment.centerRight,
                          child: Text(context.l10n.attendanceFlutterNoEventTypes),
                        ),
                        alignment: AlignmentDirectional.centerEnd,
                        selectedItemBuilder: (context) => [
                          for (final type in types)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                type.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        items: [
                          for (final type in types)
                            DropdownMenuItem(value: type, child: Text(type.name)),
                        ],
                        onChanged: (value) {
                          if (value != null) _onTypeChanged(value);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isAllDay && ios)
            _IosStackedField(
              label: context.l10n.attListDurationDays,
              controller: _durationController,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null && parsed > 0) {
                  setState(() => _durationDays = parsed);
                }
              },
            )
          else if (isAllDay)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                keyboardType: TextInputType.number,
                controller: _durationController,
                decoration: InputDecoration(
                  labelText: context.l10n.attListDurationDays,
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed > 0) {
                    setState(() => _durationDays = parsed);
                  }
                },
              ),
            ),
          // Info-Text: Ionic stacked label + plain ion-textarea + helper text
          if (ios)
            _IosStackedField(
              label: context.l10n.attListInfoText,
              helperText: context.l10n.attListInfoTextHelper,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) =>
                  setState(() => _typeInfo = value.isEmpty ? null : value),
            )
          else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              decoration: InputDecoration(
                labelText: context.l10n.attListInfoText,
                helperText: context.l10n.attListInfoTextHelper,
                border: InputBorder.none,
              ),
              onChanged: (value) =>
                  setState(() => _typeInfo = value.isEmpty ? null : value),
            ),
          ),
          // DUTY: persons needed per weekday (Dienst-Modus)
          if (_selectedType?.dutyMode == true)
            for (final wd in _dutyWeekdays())
              ListTile(
                title: Text(context.l10n.attListNeededPeople(DateFormat('EEEE', currentIntlLocale()).format(DateTime(2024, 1, wd.weekday)))),
                subtitle: Text(context.l10n.attendanceFlutterEventsCount(wd.count)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      tooltip: context.l10n.attListLess,
                      onPressed: wd.required <= 1
                          ? null
                          : () => setState(
                              () => _dutyRequiredByWeekday[wd.weekday] = wd.required - 1),
                    ),
                    Text('${wd.required}'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: context.l10n.attListMore,
                      onPressed: () => setState(
                          () => _dutyRequiredByWeekday[wd.weekday] = wd.required + 1),
                    ),
                  ],
                ),
              ),
          // ATT_DETAIL: "Ort (für Navigation)" for types with place_enabled
          if (_selectedType?.placeEnabled == true && ios)
            _IosStackedField(
              label: context.l10n.attListPlace,
              hintText: context.l10n.attListPlacePlaceholder,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              onChanged: (value) =>
                  setState(() => _place = value.trim().isEmpty ? null : value.trim()),
            )
          else if (_selectedType?.placeEnabled == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.l10n.attListPlace,
                  hintText: context.l10n.attListPlacePlaceholder,
                  border: InputBorder.none,
                ),
                onChanged: (value) =>
                    setState(() => _place = value.trim().isEmpty ? null : value.trim()),
              ),
            ),
          // UX_ATT: no Flutter-only Uhrzeit/Notizen rows – Ionic takes the
          // type's default times; both are edited on the Termin afterwards.
        ]),

        // Werke (only if type.manageSongs)
        if (showSongs) ...[
          // IOS_FORMS2: Ionic `ion-list-header` button defaults to fill
          // "clear" → a small primary "+" next to the header label.
          if (ios)
            IonListHeader(
              context.l10n.attListSongs,
              trailing: [
                IconButton(
                  icon: const Icon(Icons.add, size: 24),
                  tooltip: context.l10n.attListAddSongs,
                  visualDensity: VisualDensity.compact,
                  onPressed: _addSongs,
                ),
              ],
            )
          else
          _InsetListHeader(
            title: context.l10n.attListSongs,
            // Ionic `<ion-button size="small">` with an add icon
            trailing: SizedBox(
              height: 28,
              child: FilledButton(
                onPressed: _addSongs,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(36, 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Tooltip(
                  message: context.l10n.attListAddSongs,
                  child: const Icon(Icons.add, size: 18),
                ),
              ),
            ),
          ),
          _InsetGroup(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              SelectedSongsList(
                entries: _songEntries,
                onEntriesChanged: (entries) => setState(() => _songEntries = entries),
              ),
            ],
          ),
        ],

        // Primary "Termin(e) hinzufügen" row (Ionic ion-item color="primary")
        // IOS_FORMS2: on iOS its own ion-item-group (28px corners on a 53px
        // row → stadium); a disabled item fades its label to 40 %.
        if (ios)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: AppColors.primary,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: canSubmit ? _createAttendances : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 53),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Opacity(
                            opacity: canSubmit || _isLoading ? 1 : 0.4,
                            child: Text(
                              submitLabel,
                              style: const TextStyle(color: Colors.white, fontSize: 17),
                            ),
                          ),
                        ),
                        if (_isLoading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: AppSpinner(strokeWidth: 2, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: canSubmit ? AppColors.primary : AppColors.primary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: canSubmit ? _createAttendances : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        submitLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: AppSpinner(strokeWidth: 2, color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    // No back/barrier dismissal while the Termine are being created.
    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? null
            : AppColors.light,
        appBar: AppBar(
          title: Text(context.l10n.attListAddEvent),
          automaticallyImplyLeading: !widget.asSheet,
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? null
              : AppColors.light,
          // UX_ATT: Ionic addAttModal toolbar has only the title (closed by
          // swiping the sheet down / tapping outside).
          toolbarHeight: widget.asSheet ? 44 : null,
          shape: widget.asSheet ? const Border() : null,
        ),
        body: body,
      ),
    );
  }

  // IOS_FORMS2: Ionic iOS "Datum" item – stacked label (16, text colour),
  // the readonly ion-input value below and a clear "information" button.
  Widget _iosDateRow(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: _onDateClick,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: IonIos.itemMinHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.attListDateMulti,
                      style: TextStyle(fontSize: 16, color: onSurface),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getDateDisplayText(),
                      style: TextStyle(fontSize: 17, color: onSurface),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const IonInformationIcon(size: 22, color: AppColors.primary),
                tooltip: context.l10n.attListEventTypes,
                onPressed: _showHolidayInfo,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // IOS_FORMS2: Ionic iOS `ion-select` item – label left, selected value
  // right-aligned with the chevron-expand (⇅) icon; tapping opens the
  // default alert interface with radio options.
  Widget _iosTypeRow(
    BuildContext context,
    AsyncValue<List<AttendanceType>> typesAsync,
  ) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final types = typesAsync.valueOrNull ?? const <AttendanceType>[];
    final selected = types.contains(_selectedType) ? _selectedType : null;
    final Widget value = typesAsync.when(
      loading: () => const Align(
        alignment: Alignment.centerRight,
        child: SizedBox(width: 16, height: 16, child: AppSpinner(strokeWidth: 2)),
      ),
      error: (e, _) => const Align(
        alignment: Alignment.centerRight,
        child: Icon(Icons.error_outline, color: AppColors.danger),
      ),
      data: (_) => Text(
        selected?.name ?? context.l10n.attendanceFlutterNoEventTypes,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: TextStyle(
          fontSize: 17,
          color: selected == null ? onSurface.withValues(alpha: 0.6) : onSurface,
        ),
      ),
    );
    return InkWell(
      onTap: types.isEmpty ? null : () => _pickTypeIos(types),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: IonIos.itemMinHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                context.l10n.attListType,
                style: TextStyle(fontSize: 17, color: onSurface),
              ),
              const SizedBox(width: 16),
              Expanded(child: value),
              const SizedBox(width: 4),
              IonChevronExpandIcon(
                size: 18,
                color: dark ? const Color(0xFFA6A6A6) : const Color(0xFF595959),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTypeIos(List<AttendanceType> types) async {
    var picked = types.contains(_selectedType) ? _selectedType : null;
    final result = await showAppDialog<AttendanceType>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AppAlertDialog(
          title: Text(context.l10n.attListType),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final type in types)
                InkWell(
                  onTap: () => setDialogState(() => picked = type),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            type.name,
                            style: TextStyle(
                              fontSize: 16,
                              color: type == picked ? AppColors.primary : null,
                            ),
                          ),
                        ),
                        if (type == picked)
                          const Icon(Icons.check, size: 20, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(picked),
              child: Text(context.l10n.commonOk),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) _onTypeChanged(result);
  }

  /// Ionic onDateClick: tapping the field while only today is selected
  /// deselects today first, then the date picker opens.
  Future<void> _onDateClick() async {
    final today = _today();
    if (_selectedDates.length == 1 &&
        DateUtils.isSameDay(_selectedDates.first, today)) {
      setState(() => _selectedDates = []);
      ToastHelper.showInfo(context, context.l10n.attListTodayDeselected);
    }
    await _pickDates();
  }

  void _onTypeChanged(AttendanceType type) {
    setState(() {
      _selectedType = type;
      _dutyRequiredByWeekday = {};
      // Set default times from type (always overwrite to match type defaults)
      _startTime = type.startTime != null ? _parseTime(type.startTime!) : null;
      _endTime = type.endTime != null ? _parseTime(type.endTime!) : null;
      // Set default duration for all-day events
      if (type.allDay == true) {
        _durationDays = type.durationDays ?? 1;
        // FN-003: Sync controller text with state
        _durationController.text = '$_durationDays';
      }
    });
  }

  // UX_ATT: Ionic dateString ("dd.MM.yyyy" / attList.eventsSelected / noDate)
  String _getDateDisplayText() {
    if (_selectedDates.isEmpty) {
      return context.l10n.attListNoDate;
    } else if (_selectedDates.length == 1) {
      return DateFormat(dateFmt()).format(_selectedDates.first);
    } else {
      return context.l10n.attListEventsSelected(_selectedDates.length);
    }
  }

  Future<void> _pickDates() async {
    final result = await MultiDateCalendarDialog.show(
      context,
      initialDates: _selectedDates,
    );

    if (result != null) {
      setState(() => _selectedDates = result);
    }
  }

  Future<void> _addSongs() async {
    final result = await SongsSelectionSheet.show(
      context,
      existingEntries: _songEntries,
    );

    if (result != null) {
      setState(() => _songEntries = result);
    }
  }

  // UX_ATT: Ionic info modal (breakpoint 0.5): Veranstaltungstypen legend,
  // then Ferien and Feiertage.
  void _showHolidayInfo() {
    final holidaysAsync = ref.read(holidaysProvider);
    final types = ref.read(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[];
    Widget dot(Color color) => Icon(Icons.circle, size: 18, color: color);
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
          child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        );
    final fmt = DateFormat(dateFmt());

    showModalBottomSheet(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => holidaysAsync.when(
          loading: () =>
              const Center(child: AppSpinner()),
          error: (e, _) => Center(child: Text(context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)))),
          data: (holidays) {
            final hasHolidays =
                holidays.publicHolidays.isNotEmpty || holidays.schoolHolidays.isNotEmpty;
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                header(context.l10n.attListEventTypes),
                _InsetGroup(
                  margin: EdgeInsets.zero,
                  children: [
                    for (final type in types)
                      ListTile(
                        dense: true,
                        leading: dot(ColorUtils.parseNamedColor(type.color)),
                        title: Text(type.name),
                      ),
                    if (hasHolidays) ...[
                      ListTile(
                        dense: true,
                        leading: dot(AppColors.danger),
                        title: Text(context.l10n.attListHolidaysOfState),
                      ),
                      ListTile(
                        dense: true,
                        leading: dot(AppColors.medium),
                        title: Text(context.l10n.attListSchoolHolidaysOfState),
                      ),
                    ],
                  ],
                ),
                header(context.l10n.attListSchoolHolidays),
                for (final h in holidays.schoolHolidays.where((h) => !h.isPast))
                  ListTile(
                    dense: true,
                    title: Text('${fmt.format(h.startDate)} - ${fmt.format(h.endDate)}: ${h.name}'),
                  ),
                header(context.l10n.attListHolidays),
                for (final h in holidays.publicHolidays.where((h) => !h.isPast))
                  ListTile(
                    dense: true,
                    title: Text('${fmt.format(h.startDate)}: ${h.name}'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _createAttendances() async {
    // UI_TENANT_HOIST: bind tenant + repositories before the first await.
    final writer = AttendanceCreateWriter(ref);
    final tenant = writer.tenant;
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.attendanceFlutterChooseType)),
      );
      return;
    }

    if (_selectedDates.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.attListChooseOneDate);
      return;
    }

    // ASTRA_UX3: no start/end check – like Ionic, Termine may run past
    // midnight (e.g. type times 22:00–01:00).

    if (DemoGuard.blocked()) return; // DEMO_GUARD

    // SOL_FIX2: enforce the resolved create permission in the write path
    // (helpers: role permission attendance_create, freshly loaded; any
    // loading error denies).
    final mayCreate = await confirmCanCreateAttendance(
      () => ref.read(canCreateAttendanceConfirmedProvider.future),
    );
    if (!mounted) return;
    if (!mayCreate) {
      ToastHelper.showError(context, context.l10n.attendanceFlutterNoPermission);
      return;
    }

    setState(() => _isLoading = true);
    widget.savingNotifier?.value = true;

    try {
      if (tenant == null) throw Exception(context.l10n.historyFlutterNoTenant);

      // Shared with the new design (attendance_create_writes.dart).
      final input = AttendanceCreateInput(
        type: _selectedType!,
        dates: _selectedDates,
        typeInfo: _typeInfo,
        startTime: _startTime != null ? _formatTime(_startTime!) : null,
        endTime: _endTime != null ? _formatTime(_endTime!) : null,
        durationDays: _durationDays,
        place: _place,
        songEntries: _songEntries,
        dutyRequiredByWeekday: _dutyRequiredByWeekday,
      );
      final ids = await writer.create(input);
      final lastCreatedId = ids.isEmpty ? null : ids.last;

      if (!mounted) return;

      // Invalidate attendance providers so lists are refreshed
      AttendanceCreateWriter.invalidateAfterCreate(ref, input);

      // UX_ATT: Ionic toasts attList.eventAdded / eventsAdded
      final message = _selectedDates.length == 1
          ? context.l10n.attListEventAdded
          : context.l10n.attListEventsAdded;
      ToastHelper.showSuccess(context, message);

      // UX_ATT: as sheet (Ionic) dismiss and stay on the list
      if (widget.asSheet) {
        Navigator.of(context).pop(true);
      } else if (lastCreatedId != null) {
        // Navigate to the last created attendance
        context.go('/attendance/$lastCreatedId');
      } else {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)))),
      );
    } finally {
      widget.savingNotifier?.value = false;
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // DUTY: weekdays of the selected dates with count and persons needed
  List<({int weekday, int count, int required})> _dutyWeekdays() {
    final counts = <int, int>{};
    for (final d in _selectedDates) {
      counts[d.weekday] = (counts[d.weekday] ?? 0) + 1;
    }
    final keys = counts.keys.toList()..sort();
    return [
      for (final wd in keys)
        (
          weekday: wd,
          count: counts[wd]!,
          required: _dutyRequiredByWeekday[wd] ?? _selectedType?.dutyRequired ?? 1,
        ),
    ];
  }

  TimeOfDay? _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// UX_ATT: Ionic `ion-list inset` group – rounded card with dividers.
class _InsetGroup extends StatelessWidget {
  const _InsetGroup({
    required this.children,
    this.margin = const EdgeInsets.all(16),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    // IOS_FORMS2: iOS inset group (ion-list inset > ion-item-group)
    if (isIosLook(context)) {
      return IonInsetList(margin: margin, children: children);
    }
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(height: 1, indent: 16));
      rows.add(children[i]);
    }
    return Card(
      margin: margin,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

/// IOS_FORMS2: Ionic iOS `ion-item` with `ion-label position="stacked"` and a
/// plain `ion-input` / `ion-textarea` (no outline): label in the text colour,
/// the borderless field below and the grey helper text under it.
class _IosStackedField extends StatelessWidget {
  const _IosStackedField({
    required this.label,
    required this.onChanged,
    this.controller,
    this.helperText,
    this.hintText,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.minLines,
  });

  final String label;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final String? helperText;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int? minLines;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final multiline = keyboardType != TextInputType.number;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 16, color: onSurface)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: multiline ? TextInputType.multiline : keyboardType,
            textCapitalization: textCapitalization,
            minLines: multiline ? minLines : null,
            maxLines: multiline ? null : 1,
            style: TextStyle(fontSize: 17, color: onSurface),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontSize: 17,
                color: onSurface.withValues(alpha: 0.6),
              ),
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
            ),
            onChanged: onChanged,
          ),
          if (helperText != null) ...[
            const SizedBox(height: 6),
            Text(
              helperText!,
              style: const TextStyle(fontSize: 12, color: AppColors.medium),
            ),
          ],
        ],
      ),
    );
  }
}

/// UX_ATT: Ionic `ion-list-header` with an optional trailing button.
class _InsetListHeader extends StatelessWidget {
  const _InsetListHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // iOS (ionic-theme-ios26) list header: 0.9rem medium-tint label
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14.4, color: AppColors.medium),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
