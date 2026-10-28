import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/color_utils.dart';
import '../../../../../data/models/attendance/attendance.dart';

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
    super.dispose();
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return DateFormat('EEE, dd.MM.yyyy', 'de_DE').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final hasDeadline = widget.attendance.deadline != null;
    final isAllDay = widget.attendanceType?.allDay ?? false;

    String? formattedDeadline;
    if (hasDeadline && widget.attendance.deadline != null) {
      final deadline = DateTime.tryParse(widget.attendance.deadline!);
      if (deadline != null) {
        formattedDeadline = DateFormat('dd.MM.yyyy HH:mm').format(deadline);
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingXS,
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.info_outline, color: AppColors.primary),
        title: const Text('Allgemein'),
        children: [
          // Type badge (read-only)
          if (widget.attendanceType != null)
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Typ'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: ColorUtils.parseNamedColor(widget.attendanceType!.color)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  widget.attendanceType!.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              dense: true,
            ),

          // Datum (change date)
          if (widget.onDateSelect != null)
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Datum'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatDate(widget.attendance.date),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: widget.onDateSelect,
              dense: true,
            ),

          // TypeInfo TextField
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM,
              vertical: AppDimensions.paddingS,
            ),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Bezeichnung',
                hintText: 'z.B. Generalprobe, Konzert...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
              controller: _typeInfoController,
              onSubmitted: widget.onTypeInfoChanged,
            ),
          ),

          // Notes TextField
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM,
              vertical: AppDimensions.paddingS,
            ),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Notizen',
                hintText: 'Allgemeine Notizen...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_outlined),
              ),
              controller: _notesController,
              maxLines: 2,
              onSubmitted: widget.onNotesChanged,
            ),
          ),

          // Ort (place) – only for types with place_enabled
          if (widget.attendanceType?.placeEnabled == true && widget.onPlaceChanged != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
              child: TextField(
                controller: _placeController,
                focusNode: _placeFocus,
                decoration: InputDecoration(
                  labelText: 'Ort',
                  hintText: 'Adresse oder Ortsname',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.place_outlined),
                  suffixIcon: (widget.attendance.place?.isNotEmpty ?? false) &&
                          widget.onOpenNavigation != null
                      ? IconButton(
                          icon: const Icon(Icons.navigation_outlined),
                          tooltip: 'Navigation öffnen',
                          onPressed: widget.onOpenNavigation,
                        )
                      : null,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (v) => widget.onPlaceChanged!(v.trim()),
              ),
            ),

          // Ordner in der Dateiablage
          if (widget.onChooseFilesFolder != null)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Ordner in der Dateiablage'),
              subtitle: Text(
                widget.attendance.filesFolder?.isNotEmpty == true
                    ? widget.attendance.filesFolder!
                    : 'z. B. Aufnahmen des Termins',
              ),
              onTap: widget.attendance.filesFolder?.isNotEmpty == true
                  ? widget.onOpenFilesFolder
                  : widget.onChooseFilesFolder,
              trailing: widget.attendance.filesFolder?.isNotEmpty == true
                  ? PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'change') widget.onChooseFilesFolder?.call();
                        if (v == 'remove') widget.onRemoveFilesFolder?.call();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'change', child: Text('Ordner ändern')),
                        PopupMenuItem(
                          value: 'remove',
                          child: Text('Ordner entfernen', style: TextStyle(color: AppColors.danger)),
                        ),
                      ],
                    )
                  : TextButton(
                      onPressed: widget.onChooseFilesFolder,
                      child: const Text('Wählen'),
                    ),
              dense: true,
            ),

          // Time pickers (if not all-day)
          if (!isAllDay) ...[
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Beginn'),
              trailing: Text(
                widget.attendance.startTime ?? 'Nicht gesetzt',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              onTap: widget.onStartTimeSelect,
              dense: true,
            ),
            ListTile(
              leading: const Icon(Icons.access_time_filled),
              title: const Text('Ende'),
              trailing: Text(
                widget.attendance.endTime ?? 'Nicht gesetzt',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              onTap: widget.onEndTimeSelect,
              dense: true,
            ),
          ],

          // Duration (if all-day)
          if (isAllDay)
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Dauer'),
              trailing: Text(
                '${widget.attendance.durationDays ?? 1} Tag(e)',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              dense: true,
            ),

          const Divider(),

          // Deadline toggle (only show when there are neutral statuses or deadline is already set)
          if (widget.hasNeutralStatuses || hasDeadline) ...[
            SwitchListTile(
              secondary: const Icon(Icons.event_busy),
              title: const Text('Anmeldefrist'),
              subtitle: hasDeadline && formattedDeadline != null
                  ? Text(formattedDeadline)
                  : const Text('Nicht gesetzt'),
              value: hasDeadline,
              onChanged: widget.onDeadlineToggle,
            ),

            // Deadline picker (if enabled)
            if (hasDeadline)
              ListTile(
                leading: const Icon(Icons.edit_calendar),
                title: const Text('Frist ändern'),
                trailing: const Icon(Icons.chevron_right),
                onTap: widget.onDeadlineSelect,
                dense: true,
              ),
          ],

          const Divider(),

          // ATT_DETAIL: description & attachment editor
          if (widget.onEditDescription != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingS),
              child: TextButton.icon(
                onPressed: widget.onEditDescription,
                icon: const Icon(Icons.description_outlined),
                label: const Text('Beschreibung & Anhang bearbeiten'),
              ),
            ),

          // Export button
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            child: TextButton.icon(
              onPressed: widget.onExportExcel,
              icon: const Icon(Icons.table_chart),
              label: const Text('Als Excel exportieren'),
            ),
          ),
        ],
      ),
    );
  }
}
