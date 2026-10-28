import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../core/utils/date_helper.dart';
import '../../../../../l10n/l10n.dart';

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
    this.hasNeutralStatuses = true,
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
  final bool hasNeutralStatuses;

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

  @override
  void initState() {
    super.initState();
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
    const primaryStyle = TextStyle(color: AppColors.primary);
    const valueStyle = TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500);
    const fieldPadding = EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: 4);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingXS,
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(context.l10n.attendanceGeneral),
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          // Typ (badge)
          if (widget.attendanceType != null)
            ListTile(
              title: Text(context.l10n.attListType),
              // UX_ATT: plain `<ion-badge slot="end">` = primary, iOS radius 10
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.attendanceType!.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              dense: true,
            ),

          // Datum (tap to change)
          if (widget.onDateSelect != null)
            ListTile(
              title: Text(context.l10n.attendanceDate),
              trailing: Text(_formatDate(widget.attendance.date), style: valueStyle),
              onTap: widget.onDateSelect,
              dense: true,
            ),

          // Info-Text
          Padding(
            padding: fieldPadding,
            child: TextField(
              decoration: InputDecoration(
                labelText: context.l10n.attendanceInfoText,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: InputBorder.none,
              ),
              textCapitalization: TextCapitalization.sentences,
              controller: _typeInfoController,
              focusNode: _typeInfoFocus,
              onSubmitted: (_) => _typeInfoFocus.unfocus(),
              onTapOutside: (_) => _typeInfoFocus.unfocus(),
            ),
          ),

          // Notizen
          Padding(
            padding: fieldPadding,
            child: TextField(
              decoration: InputDecoration(
                labelText: context.l10n.attendanceNotes,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: InputBorder.none,
              ),
              textCapitalization: TextCapitalization.sentences,
              controller: _notesController,
              minLines: 1,
              maxLines: 6,
              focusNode: _notesFocus,
              onTapOutside: (_) => _notesFocus.unfocus(),
            ),
          ),

          // Anmeldefrist setzen + Fristdatum
          if (widget.hasNeutralStatuses || hasDeadline) ...[
            SwitchListTile(
              title: Text(context.l10n.attendanceSetDeadline),
              subtitle: Text(
                context.l10n.attendanceDeadlineHelper,
                style: const TextStyle(fontSize: 12),
              ),
              value: hasDeadline,
              onChanged: widget.onDeadlineToggle,
            ),
            if (hasDeadline)
              ListTile(
                title: Text(context.l10n.attendanceDeadlineDate),
                trailing: _DatetimeButton(
                  label: formattedDeadline ?? '',
                  onTap: widget.onDeadlineSelect,
                ),
                onTap: widget.onDeadlineSelect,
                dense: true,
              ),
          ],

          // Beginn / Ende (or Dauer for all-day types)
          if (!isAllDay) ...[
            ListTile(
              title: Text(context.l10n.attendanceStart),
              trailing: _DatetimeButton(
                label: _formatTime(widget.attendance.startTime),
                onTap: widget.onStartTimeSelect,
              ),
              onTap: widget.onStartTimeSelect,
              dense: true,
            ),
            ListTile(
              title: Text(context.l10n.attendanceEnd),
              trailing: _DatetimeButton(
                label: _formatTime(widget.attendance.endTime),
                onTap: widget.onEndTimeSelect,
              ),
              onTap: widget.onEndTimeSelect,
              dense: true,
            ),
          ],
          if (isAllDay)
            ListTile(
              title: Text(context.l10n.attListDurationDays),
              trailing: Text('${widget.attendance.durationDays ?? 1}'),
              dense: true,
            ),

          // Ordner in der Dateiablage
          if (widget.onChooseFilesFolder != null) ...[
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
            Padding(
              padding: fieldPadding,
              child: TextField(
                controller: _placeController,
                focusNode: _placeFocus,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.l10n.attendancePlace,
                  hintText: context.l10n.attendanceAddressPlaceholder,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (v) => widget.onPlaceChanged!(v.trim()),
              ),
            ),
            if ((widget.attendance.place?.isNotEmpty ?? false) && widget.onOpenNavigation != null)
              ListTile(
                title: Text(context.l10n.signoutOpenNavigation, style: primaryStyle),
                onTap: widget.onOpenNavigation,
                dense: true,
              ),
          ],

          // Beschreibung & Anhang bearbeiten
          if (widget.onEditDescription != null)
            ListTile(
              title: Text(context.l10n.attendanceEditDescription, style: primaryStyle),
              onTap: widget.onEditDescription,
              dense: true,
            ),

          // Anwesenheit als Excel exportieren
          ListTile(
            title: Text(context.l10n.attendanceExportExcel, style: primaryStyle),
            onTap: widget.onExportExcel,
            dense: true,
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
  final VoidCallback onTap;

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
