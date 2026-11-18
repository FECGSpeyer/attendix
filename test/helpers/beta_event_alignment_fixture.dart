import 'dart:convert';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/features/redesign/data/providers/rd_events_providers.dart';
import 'package:attendix/features/redesign/data/providers/rd_today_providers.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_events_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_split_view.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const betaShortEventTitle = 'Probe';
const betaLongEventTitle = 'Vortrag mit EV Gruppe in SP';

/// Real Beta page; only network-backed inputs are replaced. Relative dates
/// keep the regression current; screenshots pass a fixed reference day.
Widget betaEventAlignmentFixture({
  DateTime? referenceDay,
  double textScale = 1,
  String typeLabel = 'Vortrag',
}) {
  final day = referenceDay ?? DateTime.now();
  String date(int offset) =>
      DateTime(day.year, day.month, day.day + offset).toIso8601String();
  final theme = buildRdTheme(RdFarbwelt.petrol, Brightness.dark);
  return ProviderScope(
    overrides: [
      effectiveRoleProvider.overrideWithValue(Role.admin),
      canCreateAttendanceProvider.overrideWithValue(true),
      realtimeAttendanceListProvider.overrideWith(
        (ref) async => [
          Attendance(
            id: 71,
            tenantId: 7,
            date: date(6),
            typeId: 'probe',
            typeInfo: betaShortEventTitle,
            startTime: '17:50',
            endTime: '19:30',
          ),
          Attendance(
            id: 72,
            tenantId: 7,
            date: date(11),
            typeId: 'vortrag',
            typeInfo: betaLongEventTitle,
            startTime: '08:30',
            endTime: '12:00',
          ),
        ],
      ),
      attendanceTypesProvider.overrideWith(
        (ref) async => [
          const AttendanceType(id: 'probe', tenantId: 7, name: 'Probe'),
          AttendanceType(id: 'vortrag', tenantId: 7, name: typeLabel),
        ],
      ),
      rdUpcomingCountsProvider.overrideWith(
        (ref) async => const {
          71: RdStatusCounts(present: 45, excused: 4),
          72: RdStatusCounts(present: 41, excused: 8),
        },
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme.copyWith(
        platform: TargetPlatform.android,
        splashFactory: NoSplash.splashFactory,
        textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Roboto'),
      ),
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
      home: const RdSplitScope(
        isDetail: false,
        selectedId: 71,
        child: RdEventsPage(),
      ),
    ),
  );
}

Future<void> loadBetaEventFixtureFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}
