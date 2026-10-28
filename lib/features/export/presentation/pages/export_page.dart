import 'dart:typed_data';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/attendance_repository.dart';
import '../../export_fields.dart';
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/presentation/widgets/settings_list.dart'; // UX_SETTINGS (WAVE 8)
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import '../../../../core/services/native/native_file_service.dart'; // NATIVE_MISC
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart'; // IOS_SHELL2

/// Export Page
///
/// Allows exporting player lists and attendance data to PDF or Excel.
/// Port of Ionic export.page.ts: standard fields + tenant extra fields
/// (additional_fields), custom empty columns, sorting, season-wide
/// attendance export.
class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  String _exportType = 'pdf';
  String _contentType = 'player';
  List<String> _selectedFields = [...defaultPlayerExportFields];
  String _sortField = 'gruppe';
  bool _sortAscending = true;
  bool _isExporting = false;

  // PARITY_B (I2): Ionic export uses db.getPersonExtraFields()
  List<ExtraField> get _extraFields => ref.read(personListExtraFieldsProvider);

  void _setContentType(String value) {
    if (value == _contentType) return;
    setState(() {
      _contentType = value;
      _sortField = 'gruppe';
      _sortAscending = true;
      _selectedFields = value == 'player'
          ? [...defaultPlayerExportFields]
          : [...defaultAttendanceExportFields];
    });
  }

  /// Ionic `ion-select multiple` "Felder": keeps the current order of the
  /// fields that stay selected, appends newly selected ones.
  Future<void> _pickFields(List<String> available) async {
    final selection = {..._selectedFields};
    final result = await showAppDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AppAlertDialog(
          title: Text(context.l10n.exportFields),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final f in available)
                  CheckboxListTile(
                    dense: true,
                    title: Text(exportFieldLabel(f, context.l10n)),
                    value: selection.contains(f),
                    onChanged: (v) => setLocal(() {
                      v == true ? selection.add(f) : selection.remove(f);
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, selection),
              child: Text(context.l10n.commonOk),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedFields = [
        // custom (free text) columns are not part of `available` and stay
        for (final f in _selectedFields)
          if (result.contains(f) || !available.contains(f)) f,
        for (final f in available)
          if (result.contains(f) && !_selectedFields.contains(f)) f,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final extraFields = ref.watch(personListExtraFieldsProvider);
    final available = availableExportFields(_contentType, extraFields);
    final sortOptions = exportSortOptions(_contentType, extraFields);
    if (!sortOptions.any((o) => o.value == _sortField)) {
      _sortField = 'gruppe';
    }
    final selectedAvailable = _selectedFields
        .where(available.contains)
        .map((f) => exportFieldLabel(f, context.l10n))
        .join(', ');

    final ios = ionIsIos(context);
    // UX_SETTINGS (WAVE 8): export.page.html is a modal — iOS shows the
    // close "x" at the end of the toolbar instead of a back button.
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !ios,
        title: Text(context.l10n.exportTitle),
        actions: [
          if (ios)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: scrollEndPadding(context, base: AppDimensions.paddingL)),
        children: [
          // Ionic `ion-segment mode="md"`: Spieler | Anwesenheit
          _ExportSegment(
            value: _contentType,
            options: [('player', context.l10n.exportPlayers), ('attendance', context.l10n.exportAttendance)],
            onChanged: _setContentType,
          ),
          // "Felder" multi select
          ListTile(
            title: Text(context.l10n.exportFields),
            trailing: _SelectValue(selectedAvailable, maxWidthFactor: 0.55),
            onTap: () => _pickFields(available),
          ),
          _itemLine(context, indent: 0),
          // Selected fields: reorder via handle, swipe left to remove (Ionic
          // ion-reorder-group + ion-item-sliding)
          SlidableAutoCloseBehavior(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _selectedFields.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _selectedFields.removeAt(oldIndex);
                  _selectedFields.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final field = _selectedFields[index];
                return Slidable(
                  key: ValueKey('$field-$index'),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.22,
                    children: [
                      SlidableAction(
                        onPressed: (_) => setState(() => _selectedFields.removeAt(index)),
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: Text(exportFieldLabel(field, context.l10n)),
                          subtitle: available.contains(field)
                              ? null
                              : Text(context.l10n.exportFlutterCustomFieldEmpty),
                          trailing: ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.reorder, color: AppColors.medium),
                            ),
                          ),
                        ),
                        _itemLine(context),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 13),
                ),
                onPressed: _addCustomField,
                child: Text(context.l10n.exportAddExtraField),
              ),
            ),
          ),
          _SelectItem<String>(
            label: context.l10n.exportSortBy,
            value: _sortField,
            options: [for (final o in sortOptions) (o.value, o.label)],
            onChanged: (v) => setState(() => _sortField = v),
          ),
          _SelectItem<bool>(
            label: context.l10n.exportOrder,
            value: _sortAscending,
            options: [(true, context.l10n.exportAsc), (false, context.l10n.exportDesc)],
            onChanged: (v) => setState(() => _sortAscending = v),
          ),
          _SelectItem<String>(
            label: context.l10n.exportExportType,
            value: _exportType,
            options: const [('pdf', 'PDF'), ('excel', 'Excel')],
            onChanged: (v) => setState(() => _exportType = v),
          ),
          // Flutter hint: the PDF attendance export is limited to 8 dates
          if (_contentType == 'attendance' && _exportType == 'pdf')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                context.l10n.exportFlutterPdfLimitHint,
                style: const TextStyle(fontSize: 12, color: AppColors.medium),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: FilledButton(
              onPressed: _isExporting ? null : _export,
              child: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: AppSpinner(strokeWidth: 2),
                    )
                  : Text(context.l10n.exportExport),
            ),
          ),
        ],
      ),
    );
  }

  /// Ionic addExtraField(): free text column (values stay empty)
  Future<void> _addCustomField() async {
    final controller = TextEditingController();
    final name = await showAppDialog<String>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.exportAddField),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: context.l10n.exportFlutterColumnName),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(context.l10n.attendanceAdd),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty && mounted) {
      setState(() => _selectedFields.add(name));
    }
  }

  Future<void> _export() async {
    if (_selectedFields.isEmpty) {
      ToastHelper.showError(context, context.l10n.planningChooseFieldMin);
      return;
    }

    setState(() => _isExporting = true);

    try {
      final tenant = ref.read(currentTenantProvider);
      final tenantId = ref.read(currentTenantIdProvider);
      if (tenant == null || tenantId == null) {
        throw Exception(context.l10n.historyFlutterNoTenant);
      }
      final tenantName = tenant.shortName;

      // Active (not left) players incl. paused — Ionic db.getPlayers()
      ref.invalidate(playersProvider);
      // PARITY_B (I2): Ionic export.page hydrateSharedPersonFieldValues
      final rawPlayers = await ref
          .read(profileRepositoryWithTenantProvider)
          .hydrateSharedPersonFieldValues(
              await ref.read(playersProvider.future));
      final groupsMap = await ref.read(groupsMapProvider.future);
      final players = rawPlayers
          .map((p) => p.copyWith(
                groupName:
                    p.instrument != null ? groupsMap[p.instrument] : null,
              ))
          .toList();

      final percentages =
          await ref.read(playerAttendancePercentagesProvider.future);
      final extraFields = _extraFields;
      final churchNames = <String, String>{};
      if (extraFields.any((f) => f.type == 'bfecg_church')) {
        try {
          for (final c in await ref.read(churchesProvider.future)) {
            if (c.id != null) churchNames[c.id!] = c.name;
          }
        } catch (_) {
          // Church names are optional — fall back to raw ids
        }
      }

      // Ionic: column headers are the translated labels (fieldLabel); the
      // values are still resolved by the German field id.
      final l10n = context.l10n;
      final headerFields = [for (final f in _selectedFields) exportFieldLabel(f, l10n)];
      final idByHeader = {
        for (var i = 0; i < _selectedFields.length; i++) headerFields[i]: _selectedFields[i],
      };

      String valueOf(Person p, String header) => exportFieldValue(
            p,
            idByHeader[header] ?? header,
            extraFields: extraFields,
            churchNames: churchNames,
            percentage: p.id != null ? percentages[p.id] : null,
          );

      final sortedPlayers = sortPlayersForExport(
        players,
        _sortField,
        ascending: _sortAscending,
        percentages: percentages,
      );

      final exportService = ExportService();
      final date = DateFormat(dateFmt()).format(DateTime.now());
      ref.read(trackingServiceProvider).track(TrackingEvent.reportExported, properties: {'format': _exportType == 'pdf' ? 'pdf' : 'xlsx', 'kind': _contentType == 'player' ? 'player' : 'attendance'});

      if (_contentType == 'player') {
        if (_exportType == 'pdf') {
          if (!mounted) return;
          await exportService.exportPlayerListPdf(
            context: context,
            players: sortedPlayers,
            fields: headerFields,
            tenantName: tenantName,
            valueOf: valueOf,
          );
        } else {
          final bytes = await exportService.exportPlayerListExcel(
            players: sortedPlayers,
            fields: headerFields,
            tenantName: tenantName,
            valueOf: valueOf,
          );
          await _shareExcel(bytes, l10n.exportPlayerListFile(tenantName, date));
        }
      } else {
        // All attendances of the current season up to yesterday
        // (Ionic: getAttendance(false, true) + date < today).
        final attendanceRepo =
            ref.read(attendanceRepositoryForTenantProvider(tenantId));
        // PARITY_A (R1): Ionic getCurrentAttDate() bound, all pages.
        final attendances = await attendanceRepo.getAttendances(
          since: AttendanceRepository.currentAttDate(tenant.seasonStart),
        );
        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day);
        final pastAttendances = attendances.where((a) {
          final d = DateTime.tryParse(a.date);
          return d != null && d.isBefore(startOfToday);
        }).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        final personAttendances = await attendanceRepo
            .getPersonAttendancesForAttendances(
                pastAttendances.map((a) => a.id).whereType<int>().toList());

        // Only attendances that actually have person entries
        final withPersons =
            personAttendances.map((pa) => pa.attendanceId).toSet();
        final relevant =
            pastAttendances.where((a) => withPersons.contains(a.id)).toList();

        if (_exportType == 'pdf') {
          if (!mounted) return;
          await exportService.exportAttendancePdf(
            context: context,
            players: sortedPlayers,
            attendances: relevant,
            personAttendances: personAttendances,
            fields: headerFields,
            tenantName: tenantName,
            valueOf: valueOf,
          );
        } else {
          final bytes = await exportService.exportAttendanceExcel(
            players: sortedPlayers,
            attendances: relevant,
            personAttendances: personAttendances,
            fields: headerFields,
            tenantName: tenantName,
            valueOf: valueOf,
          );
          await _shareExcel(bytes, l10n.exportAttendanceFileAsOf(tenantName, date));
        }
      }

      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.exportFlutterSuccess);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.exportFlutterFailedWith(friendlyErrorMessage(e)));
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  /// Share/download the Excel file (works on web/PWA as well)
  Future<void> _shareExcel(Uint8List bytes, String baseName) async {
    await NativeFileService.saveBytes(bytes, '$baseName.xlsx'); // NATIVE_MISC
  }
}

/// Ionic `ion-segment mode="md"` spanning the full width.
class _ExportSegment extends StatelessWidget {
  const _ExportSegment({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final o in options)
          Expanded(
            child: InkWell(
              onTap: () => onChanged(o.$1),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: value == o.$1 ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  o.$2.toUpperCase(),
                  style: TextStyle(
                    color: value == o.$1 ? AppColors.primary : AppColors.medium,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ionic `ion-item` with `ion-select interface="popover"`: label left,
/// current value right, popup menu on tap.
class _SelectItem<T> extends StatelessWidget {
  const _SelectItem({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = options.where((o) => o.$1 == value).firstOrNull?.$2 ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<T>(
          initialValue: value,
          onSelected: onChanged,
          itemBuilder: (_) => [
            for (final o in options) PopupMenuItem<T>(value: o.$1, child: Text(o.$2)),
          ],
          child: ListTile(
            title: Text(label),
            trailing: _SelectValue(current),
          ),
        ),
        _itemLine(context),
      ],
    );
  }
}

/// Ionic item line: iOS 0.55px #c8c7cc inset hairline, md 1px divider.
Widget _itemLine(BuildContext context, {double indent = 16}) => ionIsIos(context)
    ? Divider(height: 0.5, thickness: 0.5, indent: indent, color: IonIos.line(context))
    : Divider(height: 1, indent: indent);

/// Ionic `ion-select` value + icon at the end of an item. iOS: value in the
/// text colour and the `chevron-expand` icon (opacity .33); md: grey value
/// and caret.
class _SelectValue extends StatelessWidget {
  const _SelectValue(this.text, {this.maxWidthFactor = 0.5});

  final String text;
  final double maxWidthFactor;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * maxWidthFactor),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ios ? 16 : null,
                color: ios ? IonIos.text(context) : AppColors.medium,
              ),
            ),
          ),
          if (ios)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                CupertinoIcons.chevron_up_chevron_down,
                size: 16,
                color: IonIos.text(context).withValues(alpha: 0.33),
              ),
            )
          else
            const Icon(Icons.arrow_drop_down, color: AppColors.medium),
        ],
      ),
    );
  }
}
