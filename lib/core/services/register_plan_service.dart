import 'dart:math';

import '../../data/models/person/person.dart';
import '../../l10n/l10n.dart';

/// Register rehearsal plan entry
class RegisterPlanEntry {
  final int minute;
  final String time;
  final Map<String, String?> groupAssignments; // groupName -> conductorName

  RegisterPlanEntry({
    required this.minute,
    required this.time,
    required this.groupAssignments,
  });
}

/// Register rehearsal plan result
class RegisterPlan {
  final List<String> groups;
  final List<String> conductors;
  final List<RegisterPlanEntry> entries;
  final int totalMinutes;
  final int minutesPerUnit;

  RegisterPlan({
    required this.groups,
    required this.conductors,
    required this.entries,
    required this.totalMinutes,
    required this.minutesPerUnit,
  });
}

/// Service for generating register rehearsal plans
class RegisterPlanService {
  /// Group names for choir
  static List<String> get choirGroups {
    final l10n = l10nWithoutContext;
    return [
      l10n.coreFlutterRegisterPlanSoprano,
      l10n.coreFlutterRegisterPlanAlto,
      l10n.coreFlutterRegisterPlanTenor,
      l10n.coreFlutterRegisterPlanBass,
    ];
  }

  /// Group names for orchestra
  static List<String> get orchestraGroups {
    final l10n = l10nWithoutContext;
    return [
      l10n.coreFlutterRegisterPlanStrings,
      l10n.coreFlutterRegisterPlanWoodwinds,
      l10n.coreFlutterRegisterPlanOther,
    ];
  }

  /// General group names
  static List<String> get generalGroups => [
        for (var i = 1; i <= 3; i++) l10nWithoutContext.coreFlutterRegisterPlanGroupN(i),
      ];

  /// Fisher-Yates shuffle for random order
  List<T> _shuffle<T>(List<T> items) {
    final random = Random();
    final result = List<T>.from(items);
    for (var i = result.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = result[i];
      result[i] = result[j];
      result[j] = temp;
    }
    return result;
  }

  /// Generate register rehearsal plan
  ///
  /// [conductors]: List of conductor/voice leader persons
  /// [totalMinutes]: Total rehearsal time in minutes
  /// [tenantType]: 'choir', 'orchestra', or 'general'
  /// [startTime]: Start time (e.g., '17:50')
  RegisterPlan generate({
    required List<Person> conductors,
    required int totalMinutes,
    required String tenantType,
    String startTime = '17:50',
  }) {
    if (conductors.isEmpty) {
      throw ArgumentError('At least one conductor is required');
    }

    // Get groups based on tenant type
    final groups = switch (tenantType.toLowerCase()) {
      'choir' => choirGroups,
      'orchestra' => orchestraGroups,
      _ => generalGroups,
    };

    // Shuffle conductors for random rotation
    final shuffledConductors = _shuffle(conductors);

    // Calculate minutes per unit
    final minutesPerUnit = (totalMinutes / shuffledConductors.length).floor();

    // Parse start time
    final timeParts = startTime.split(':');
    int currentMinutes = (int.tryParse(timeParts[0]) ?? 17) * 60 +
        (int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0);

    // Generate rotation matrix
    final entries = <RegisterPlanEntry>[];
    final conductorNames = shuffledConductors.map((p) => p.fullName).toList();

    for (var round = 0; round < shuffledConductors.length; round++) {
      final elapsedMinutes = round * minutesPerUnit;
      final hours = (currentMinutes + elapsedMinutes) ~/ 60;
      final mins = (currentMinutes + elapsedMinutes) % 60;
      final timeStr = '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';

      // Rotate assignments
      final assignments = <String, String?>{};
      for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
        if (groupIndex < shuffledConductors.length) {
          // Rotate conductor index for each round
          final conductorIndex = (groupIndex + round) % shuffledConductors.length;
          assignments[groups[groupIndex]] = conductorNames[conductorIndex];
        } else {
          // More groups than conductors - some groups won't have a conductor
          assignments[groups[groupIndex]] = null;
        }
      }

      entries.add(RegisterPlanEntry(
        minute: elapsedMinutes,
        time: timeStr,
        groupAssignments: assignments,
      ));
    }

    return RegisterPlan(
      groups: groups,
      conductors: conductorNames,
      entries: entries,
      totalMinutes: totalMinutes,
      minutesPerUnit: minutesPerUnit,
    );
  }

  /// Format plan as text table for display/sharing
  String formatAsText(RegisterPlan plan) {
    final buffer = StringBuffer();

    // Header
    final l10n = l10nWithoutContext;
    final title = l10n.coreFlutterRegisterPlanTitle;
    buffer.writeln(title);
    buffer.writeln('=' * title.length);
    buffer.writeln(l10n.coreFlutterRegisterPlanTotalDuration(plan.totalMinutes));
    buffer.writeln(l10n.coreFlutterRegisterPlanPerUnit(plan.minutesPerUnit));
    buffer.writeln();

    // Table header
    buffer.write(l10nWithoutContext.coreFlutterRegisterPlanTime.padRight(8));
    for (final group in plan.groups) {
      buffer.write(group.padRight(15));
    }
    buffer.writeln();
    buffer.writeln('-' * (8 + 15 * plan.groups.length));

    // Table rows
    for (final entry in plan.entries) {
      buffer.write(entry.time.padRight(8));
      for (final group in plan.groups) {
        final conductor = entry.groupAssignments[group] ?? '-';
        buffer.write(conductor.padRight(15));
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}
