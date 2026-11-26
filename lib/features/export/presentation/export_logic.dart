import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/attendance_providers.dart';
import '../../../core/providers/branding_providers.dart';
import '../../../core/providers/church_providers.dart';
import '../../../core/providers/group_providers.dart';
import '../../../core/providers/player_providers.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/providers/tenant_providers.dart';
import '../../../core/services/export_service.dart';
import '../../../core/services/native/native_file_service.dart';
import '../../../core/services/tracking/tracking_event.dart';
import '../../../core/services/tracking/tracking_service.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../data/models/person/person.dart';
import '../../../data/models/tenant/tenant.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../l10n/l10n.dart';
import '../../people/people_list_utils.dart' show sortPeopleByGroup;
import '../export_fields.dart';

/// Opens the export page (`/export` -> `RdExportPage`).
Future<void> showExportModal(BuildContext context) =>
    context.push<void>('/export');

/// Export state and export execution used by `RdExportPage`.
mixin ExportLogic<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  String exportType = 'pdf';
  String contentType = 'player';
  List<String> selectedFields = [...defaultPlayerExportFields];
  String sortField = 'gruppe';
  bool sortAscending = true;
  bool isExporting = false;

  List<ExtraField> get _extraFields => ref.read(personListExtraFieldsProvider);

  void setContentType(String value) {
    if (value == contentType) return;
    setState(() {
      contentType = value;
      sortField = 'gruppe';
      sortAscending = true;
      selectedFields = value == 'player'
          ? [...defaultPlayerExportFields]
          : [...defaultAttendanceExportFields];
    });
  }

  Future<void> runExport() async {
    if (selectedFields.isEmpty) {
      ToastHelper.showError(context, context.l10n.planningChooseFieldMin);
      return;
    }

    final fields = [...selectedFields];
    final kind = contentType;
    final format = exportType;
    final sortBy = sortField;
    final ascendingOrder = sortAscending;
    setState(() => isExporting = true);
    ProviderSubscription<int?>? tenantWatch;

    try {
      final tenant = ref.read(currentTenantProvider);
      final tenantId = ref.read(currentTenantIdProvider);
      if (tenant == null || tenantId == null) {
        throw Exception(context.l10n.historyFlutterNoTenant);
      }
      final tenantName = tenant.shortName;
      final container = ProviderScope.containerOf(context, listen: false);
      var switched = false;
      tenantWatch = container.listen<int?>(currentTenantIdProvider, (prev, next) {
        if (prev != next) switched = true;
      });
      bool stillCurrent() =>
          !switched && container.read(currentTenantIdProvider) == tenantId;

      ref.invalidate(playersProvider);
      final rawPlayers = await ref
          .read(profileRepositoryWithTenantProvider)
          .hydrateSharedPersonFieldValues(
            await ref.read(playersProvider.future),
          );
      final groupsMap = await ref.read(groupsMapProvider.future);
      final players = sortPeopleByGroup(
        rawPlayers
            .map(
              (p) => p.copyWith(
                groupName:
                    p.instrument != null ? groupsMap[p.instrument] : null,
              ),
            )
            .toList(),
        await ref.read(groupsProvider.future),
      );

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

      if (!mounted || !stillCurrent()) return;
      final l10n = context.l10n;
      final headerFields = [for (final f in fields) exportFieldLabel(f, l10n)];
      final idByHeader = {
        for (var i = 0; i < fields.length; i++) headerFields[i]: fields[i],
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
        sortBy,
        ascending: ascendingOrder,
        percentages: percentages,
      );

      final exportService = ExportService();
      final date = DateFormat(dateFmt()).format(DateTime.now());
      ref.read(trackingServiceProvider).track(
        TrackingEvent.reportExported,
        properties: {
          'format': format == 'pdf' ? 'pdf' : 'xlsx',
          'kind': kind == 'player' ? 'player' : 'attendance',
        },
      );
      final branding = format == 'pdf' ? await resolvePdfBranding(ref) : null;

      final Uint8List bytes;
      final String baseName;
      if (kind == 'player') {
        baseName = l10n.exportPlayerListFile(tenantName, date);
        bytes = format == 'pdf'
            ? await exportService.buildPlayerListPdf(
                branding: branding,
                players: sortedPlayers,
                fields: headerFields,
                tenantName: tenantName,
                valueOf: valueOf,
              )
            : await exportService.exportPlayerListExcel(
                players: sortedPlayers,
                fields: headerFields,
                tenantName: tenantName,
                valueOf: valueOf,
              );
      } else {
        final attendanceRepo =
            container.read(attendanceRepositoryForTenantProvider(tenantId));
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
              pastAttendances.map((a) => a.id).whereType<int>().toList(),
            );

        final withPersons =
            personAttendances.map((pa) => pa.attendanceId).toSet();
        final relevant =
            pastAttendances.where((a) => withPersons.contains(a.id)).toList();

        baseName = l10n.exportAttendanceFileAsOf(tenantName, date);
        bytes = format == 'pdf'
            ? await exportService.buildAttendancePdf(
                branding: branding,
                players: sortedPlayers,
                attendances: relevant,
                personAttendances: personAttendances,
                fields: headerFields,
                tenantName: tenantName,
                valueOf: valueOf,
              )
            : await exportService.exportAttendanceExcel(
                players: sortedPlayers,
                attendances: relevant,
                personAttendances: personAttendances,
                fields: headerFields,
                tenantName: tenantName,
                valueOf: valueOf,
              );
      }

      if (!stillCurrent()) return;
      await NativeFileService.saveBytes(
        bytes,
        '$baseName.${format == 'pdf' ? 'pdf' : 'xlsx'}',
      );

      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.exportFlutterSuccess);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(
          context,
          context.l10n.exportFlutterFailedWith(friendlyErrorMessage(e)),
        );
      }
    } finally {
      tenantWatch?.close();
      if (mounted) {
        setState(() => isExporting = false);
      }
    }
  }
}
