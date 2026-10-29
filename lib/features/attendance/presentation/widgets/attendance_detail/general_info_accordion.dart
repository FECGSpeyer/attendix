import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../core/utils/date_helper.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/adaptive_platform.dart';
import 'attendance_accordion.dart';
import '../../../../../shared/widgets/display/ion_badge_text.dart'; // PARITY_R8

/// Accordion widget for displaying and editing general attendance info
/// Uses StatefulWidget to properly manage TextEditingController lifecycle
class GeneralInfoAccordion extends StatefulWidget {
  const GeneralInfoAccordion({
    super.key,
    required this.attendance,
    required this.attendanceType,
    required this.onTypeInfoChanged,
    required this.onNotesChanged,
    required this.onStartTimeSelect,
    required this.onEndTimeSelect,
    required this.onDeadlineToggle,
    required this.onDeadlineSelect,
    required this.onExportExcel,
    this.onDateSelect,
    this.onPlaceChanged,
    this.onOpenNavigation,
    this.onChooseFilesFolder,
    this.onRemoveFilesFolder,
    this.onOpenFilesFolder,
    this.onEditDescription,
  });

  final Attendance attendance;
  final AttendanceType? attendanceType;
  final void Function(String) onTypeInfoChanged;
  final void Function(String) onNotesChanged;
  final VoidCallback onStartTimeSelect;
  final VoidCallback onEndTimeSelect;
  final void Function(bool) onDeadlineToggle;
  final VoidCallback onDeadlineSelect;
  final VoidCallback onExportExcel;

  /// "Datum" – move the Termin to another day.
  final VoidCallback? onDateSelect;

  /// "Ort" – only shown when the type has `place_enabled`.
  final void Function(String)? onPlaceChanged;
  final VoidCallback? onOpenNavigation;

  /// "Ordner in der Dateiablage".
  final VoidCallback? onChooseFilesFolder;
  final VoidCallback? onRemoveFilesFolder;
  final VoidCallback? onOpenFilesFolder;

  /// ATT_DETAIL: "Beschreibung & Anhang bearbeiten"
  final VoidCallback? onEditDescription;

  @override
  State<GeneralInfoAccordion> createState() => _GeneralInfoAccordionState();
}

class _GeneralInfoAccordionState extends State<GeneralInfoAccordion> {
  late TextEditingController _typeInfoController;
  late TextEditingController _notesController;
  late TextEditingController _placeController;
  final FocusNode _placeFocus = FocusNode();
  // UX_ATT: Info-Text and Notizen save on blur like Ionic (ionBlur)
  final FocusNode _typeInfoFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();

  /// IOS_DETAIL: Ionic `isDeadlineReadonly`, computed once when the page
  /// loads (a Termin in the past that already has a deadline).
  late bool _deadlineReadonly;

  @override
  void initState() {
    super.initState();
    _deadlineReadonly = isDeadlineReadonly(widget.attendance);
    _typeInfoController = TextEditingController(text: widget.attendance.typeInfo ?? '');
    _notesController = TextEditingController(text: widget.attendance.notes ?? '');
    _placeController = TextEditingController(text: widget.attendance.place ?? '');
    // Save the place when the field loses focus (Ionic: ionBlur).
    _placeFocus.addListener(() {
      if (!_placeFocus.hasFocus &&
          _placeController.text.trim() != (widget.attendance.place ?? '')) {
        widget.onPlaceChanged?.call(_placeController.text.trim());
      }
    });
    _typeInfoFocus.addListener(() {
      if (!_typeInfoFocus.hasFocus &&
          _typeInfoController.text != (widget.attendance.typeInfo ?? '')) {
        widget.onTypeInfoChanged(_typeInfoController.text);
      }
    });
    _notesFocus.addListener(() {
      if (!_notesFocus.hasFocus &&
          _notesController.text != (widget.attendance.notes ?? '')) {
        widget.onNotesChanged(_notesController.text);
      }
    });
  }

  @override
  void didUpdateWidget(GeneralInfoAccordion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attendance.id != widget.attendance.id) {
      _deadlineReadonly = isDeadlineReadonly(widget.attendance);
    }
    // Update controllers if attendance data changed externally
    if (oldWidget.attendance.typeInfo != widget.attendance.typeInfo) {
      _typeInfoController.text = widget.attendance.typeInfo ?? '';
    }
    if (oldWidget.attendance.notes != widget.attendance.notes) {
      _notesController.text = widget.attendance.notes ?? '';
    }
    if (oldWidget.attendance.place != widget.attendance.place && !_placeFocus.hasFocus) {
      _placeController.text = widget.attendance.place ?? '';
    }
  }

  @override
  void dispose() {
    _typeInfoController.dispose();
    _notesController.dispose();
    _placeController.dispose();
    _placeFocus.dispose();
    _typeInfoFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return DateFormat(dateFmt()).format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final ios = useIosLook(context);
    final hasDeadline = widget.attendance.deadline != null;
    final isAllDay = widget.attendanceType?.allDay ?? false;

    String? formattedDeadline;
    if (hasDeadline && widget.attendance.deadline != null) {
      final deadline = DateTime.tryParse(widget.attendance.deadline!);
      if (deadline != null) {
        formattedDeadline = DateFormat('${dateFmt()} HH:mm').format(deadline);
      }
    }

    // UX_ATT: element order and wording of the Ionic "Allgemein" accordion:
    // Typ, Datum, Info-Text, Notizen, Anmeldefrist setzen, Fristdatum,
    // Beginn, Ende / Dauer, Ordner, Ort (+ Navigation öffnen),
    // Beschreibung & Anhang bearbeiten, Anwesenheit als Excel exportieren.
    // IOS_DETAIL: on iOS the rows are plain ion-items (16 pt labels, 16 pt
    // notes, hairlines only where Ionic has no `lines="none"`).
    const primaryStyle = TextStyle(color: AppColors.primary);
    final valueStyle = ios
        ? const TextStyle(color: AppColors.primary, fontSize: 16)
        : const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500);

    return AttendanceAccordion(
      title: Text(context.l10n.attendanceGeneral),
      children: [
        // Typ (badge)
        if (widget.attendanceType != null)
          _item(
            context,
            label: context.l10n.attListType,
            // UX_ATT: plain `<ion-badge slot="end">` = primary, iOS radius 10
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.attendanceType!.name,
                // PARITY_R8: ion-badge is bold (700), was 600
                style: ionBadgeTextStyle(color: Colors.white, height: null),
              ),
            ),
          ),

        // Datum (tap to change)
        if (widget.onDateSelect != null)
          _item(
            context,
            label: context.l10n.attendanceDate,
            trailing: Text(_formatDate(widget.attendance.date), style: valueStyle),
            onTap: widget.onDateSelect,
          ),

        // Info-Text
        _stackedField(
          context,
          label: context.l10n.attendanceInfoText,
          controller: _typeInfoController,
          focusNode: _typeInfoFocus,
          onSubmitted: (_) => _typeInfoFocus.unfocus(),
        ),

        // Notizen
        _stackedField(
          context,
          label: context.l10n.attendanceNotes,
          controller: _notesController,
          focusNode: _notesFocus,
          minLines: 1,
          maxLines: 6,
        ),

        // IOS_DETAIL: Ionic `@if (!isDeadlineReadonly)` – the toggle is shown
        // unless the Termin already had a deadline and lies in the past.
        if (!_deadlineReadonly)
          ios
              ? _iosRow(
                  context,
                  line: true,
                  child: Row(
                    children: [
                      // PARITY_R3: the toggle's helperText is not shown
                      // on iOS (toggle without its own label).
                      Expanded(
                        child: Text(context.l10n.attendanceSetDeadline, style: const TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(width: 12),
                      Switch.adaptive(value: hasDeadline, onChanged: widget.onDeadlineToggle),
                    ],
                  ),
                )
              : SwitchListTile.adaptive(
                  title: Text(context.l10n.attendanceSetDeadline),
                  subtitle: Text(
                    context.l10n.attendanceDeadlineHelper,
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: hasDeadline,
                  onChanged: widget.onDeadlineToggle,
                ),
        // Ionic `@if (attendance.deadline)`: Fristdatum (disabled when read-only)
        if (hasDeadline)
          _item(
            context,
            label: context.l10n.attendanceDeadlineDate,
            trailing: _DatetimeButton(
              label: formattedDeadline ?? '',
              onTap: _deadlineReadonly ? null : widget.onDeadlineSelect,
            ),
            onTap: _deadlineReadonly ? null : widget.onDeadlineSelect,
          ),

        // Beginn / Ende (or Dauer for all-day types)
        if (!isAllDay) ...[
          _item(
            context,
            label: context.l10n.attendanceStart,
            trailing: _DatetimeButton(
              label: _formatTime(widget.attendance.startTime),
              onTap: widget.onStartTimeSelect,
            ),
            onTap: widget.onStartTimeSelect,
            line: true,
          ),
          _item(
            context,
            label: context.l10n.attendanceEnd,
            trailing: _DatetimeButton(
              label: _formatTime(widget.attendance.endTime),
              onTap: widget.onEndTimeSelect,
            ),
            onTap: widget.onEndTimeSelect,
            line: true,
          ),
        ],
        if (isAllDay)
          _item(
            context,
            label: context.l10n.attListDurationDays,
            trailing: Text(
              '${widget.attendance.durationDays ?? 1}',
              style: ios ? const TextStyle(fontSize: 16) : null,
            ),
            line: true,
          ),

        // Ordner in der Dateiablage
        if (widget.onChooseFilesFolder != null) ...[
          if (ios)
            _iosRow(
              context,
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, color: AppColors.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.attendanceFilesFolder, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.attendanceFilesFolderHint,
                          style: const TextStyle(fontSize: 14, color: AppColors.medium),
                        ),
                      ],
                    ),
                  ),
                  if (widget.attendance.filesFolder?.isNotEmpty != true)
                    TextButton(
                      onPressed: widget.onChooseFilesFolder,
                      // Ionic: an ion-button inside an item is small (13 px)
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(context.l10n.attendanceChoose),
                    ),
                ],
              ),
            )
          else
            ListTile(
              leading: const Icon(Icons.folder_outlined, color: AppColors.primary),
              title: Text(context.l10n.attendanceFilesFolder),
              subtitle: Text(context.l10n.attendanceFilesFolderHint),
              trailing: widget.attendance.filesFolder?.isNotEmpty == true
                  ? null
                  : TextButton(
                      onPressed: widget.onChooseFilesFolder,
                      child: Text(context.l10n.attendanceChoose),
                    ),
              dense: true,
            ),
          if (widget.attendance.filesFolder?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(left: AppDimensions.paddingM),
              child: Row(
                children: [
                  Flexible(
                    child: ActionChip(
                      avatar: const Icon(Icons.folder_open_outlined, size: 18),
                      label: Text(widget.attendance.filesFolder!, overflow: TextOverflow.ellipsis),
                      onPressed: widget.onOpenFilesFolder,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    color: AppColors.primary,
                    tooltip: context.l10n.attendanceChangeFolder,
                    onPressed: widget.onChooseFilesFolder,
                  ),
                  IconButton(
                    icon: const Icon(Icons.highlight_off),
                    color: AppColors.danger,
                    tooltip: context.l10n.attendanceRemoveFolder,
                    onPressed: widget.onRemoveFilesFolder,
                  ),
                ],
              ),
            ),
        ],

        // Ort + "Navigation öffnen" – only for types with place_enabled
        if (widget.attendanceType?.placeEnabled == true && widget.onPlaceChanged != null) ...[
          _stackedField(
            context,
            label: context.l10n.attendancePlace,
            hintText: context.l10n.attendanceAddressPlaceholder,
            controller: _placeController,
            focusNode: _placeFocus,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => widget.onPlaceChanged!(v.trim()),
          ),
          if ((widget.attendance.place?.isNotEmpty ?? false) && widget.onOpenNavigation != null)
            _item(
              context,
              label: context.l10n.signoutOpenNavigation,
              labelStyle: primaryStyle,
              onTap: widget.onOpenNavigation,
              line: true,
            ),
        ],

        // Beschreibung & Anhang bearbeiten
        if (widget.onEditDescription != null)
          _item(
            context,
            label: context.l10n.attendanceEditDescription,
            labelStyle: primaryStyle,
            onTap: widget.onEditDescription,
            line: true,
          ),

        // Anwesenheit als Excel exportieren
        _item(
          context,
          label: context.l10n.attendanceExportExcel,
          labelStyle: primaryStyle,
          onTap: widget.onExportExcel,
          line: true,
        ),
      ],
    );
  }

  /// IOS_DETAIL: an `ion-item` row. iOS: 16 px padding, min height 44,
  /// 16 pt label, optional inset hairline below ([line] = Ionic items
  /// without `lines="none"`). Material: the previous dense [ListTile].
  Widget _item(
    BuildContext context, {
    required String label,
    Widget? trailing,
    VoidCallback? onTap,
    bool line = false,
    TextStyle? labelStyle,
  }) {
    if (!useIosLook(context)) {
      return ListTile(
        title: Text(label, style: labelStyle),
        trailing: trailing,
        onTap: onTap,
        dense: true,
      );
    }
    return _iosRow(
      context,
      line: line,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16).merge(labelStyle),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  Widget _iosRow(
    BuildContext context, {
    required Widget child,
    bool line = false,
    VoidCallback? onTap,
  }) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Align(alignment: AlignmentDirectional.centerStart, child: child),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        onTap == null ? row : InkWell(onTap: onTap, child: row),
        if (line) const Divider(height: 0.5, thickness: 0.5, indent: 16),
      ],
    );
  }

  /// `ion-item lines="none"` + `ion-label position="stacked"` + borderless
  /// ion-input / ion-textarea. Material keeps the floating-label field.
  Widget _stackedField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    String? hintText,
    int? minLines,
    int maxLines = 1,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    if (!useIosLook(context)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: 4),
        child: TextField(
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            border: InputBorder.none,
          ),
          textCapitalization: TextCapitalization.sentences,
          controller: controller,
          focusNode: focusNode,
          minLines: minLines,
          maxLines: maxLines,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          onTapOutside: (_) => focusNode.unfocus(),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          TextField(
            controller: controller,
            focusNode: focusNode,
            minLines: minLines,
            maxLines: maxLines,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            onTapOutside: (_) => focusNode.unfocus(),
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              hintText: hintText,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  /// "19:00" from "19:00:00"; Ionic shows the datetime button value.
  String _formatTime(String? value) {
    if (value == null || value.isEmpty) return '--:--';
    return DateHelper.hhmm(value);
  }
}

/// UX_ATT: Ionic `ion-datetime-button`: grey rounded value button.
class _DatetimeButton extends StatelessWidget {
  const _DatetimeButton({required this.label, required this.onTap});

  final String label;

  /// null = disabled (Ionic `[disabled]="isDeadlineReadonly"`).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFEDEEF0),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 17,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// IOS_DETAIL: Ionic attendance.page `isDeadlineReadonly`: only a Termin that
/// already has a deadline and whose date lies before now
/// (`dayjs(attendance.date).isBefore(dayjs())`).
bool isDeadlineReadonly(Attendance attendance, {DateTime? now}) {
  if (attendance.deadline == null) return false;
  final date = DateTime.tryParse(attendance.date);
  if (date == null) return false;
  return date.isBefore(now ?? DateTime.now());
}
