import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/plan/plan.dart'; // ORG_PLANS
import '../../../../data/repositories/sign_in_out_repository.dart';
import '../../../planning/presentation/pages/plan_viewer_page.dart'; // ORG_PLANS

/// Plan viewer bottom sheet for displaying attendance plans
///
/// Based on Ionic PlanViewerComponent
class PlanViewerSheet extends ConsumerWidget {
  const PlanViewerSheet({
    super.key,
    required this.attendance,
    this.playerInstrumentId,
    this.songs = const [],
  });

  final CrossTenantPersonAttendance attendance;
  final int? playerInstrumentId;
  final List<Map<String, dynamic>> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = attendance.plan;
    final fields = (plan?['fields'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (fields.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('Kein Ablaufplan verfügbar'),
        ),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.borderRadiusL),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.medium.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt, color: AppColors.primary),
                    const SizedBox(width: AppDimensions.paddingS),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ablaufplan',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            _getDateFormatted(),
                            style: TextStyle(
                              color: AppColors.medium,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Plan content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  children: [
                    // Start time
                    _PlanTimeRow(
                      label: 'Beginn',
                      time: _getStartTime(),
                      isStart: true,
                    ),
                    const Divider(),
                    // Plan fields
                    ...fields.asMap().entries.map((entry) {
                      final index = entry.key;
                      final field = entry.value;
                      final name = field['name'] as String? ?? '';
                      final duration = field['time'] as int? ?? 0;
                      final conductor = field['conductor'] as String?;
                      final songId = field['songId'] as int?;
                      final isMissing = _isInstrumentMissing(songId);

                      return _PlanFieldRow(
                        name: name,
                        duration: duration,
                        time: _calculateTimeAtIndex(index, fields),
                        conductor: conductor,
                        isInstrumentMissing: isMissing,
                      );
                    }),
                    const Divider(),
                    // End time
                    _PlanTimeRow(
                      label: 'Ende',
                      time: _getEndTime(),
                      isStart: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getDateFormatted() {
    final date = attendance.date;
    if (date == null) return '';
    final dateObj = DateTime.tryParse(date);
    if (dateObj == null) return date;
    return DateFormat('dd.MM.yyyy').format(dateObj);
  }

  String _getStartTime() {
    final plan = attendance.plan;
    final time = plan?['time'];
    if (time == null) return '';
    return _parseTime(time);
  }

  String _getEndTime() {
    final plan = attendance.plan;
    final end = plan?['end'];
    if (end == null) return '';
    return _parseTime(end);
  }

  String _parseTime(dynamic time) {
    if (time is String) {
      // Try to parse as DateTime first
      final dateTime = DateTime.tryParse(time);
      if (dateTime != null) {
        return DateFormat('HH:mm').format(dateTime);
      }
      // If it's a time string like "09:00", return as-is
      if (time.contains(':') && time.length <= 5) {
        return time;
      }
      // If it's a longer ISO string, try to extract the time part
      if (time.length > 5) {
        return time.substring(0, 5);
      }
    }
    return time?.toString() ?? '';
  }

  String _calculateTimeAtIndex(int index, List<Map<String, dynamic>> fields) {
    final plan = attendance.plan;
    final startTimeStr = plan?['time'];
    if (startTimeStr == null) return '';

    int minutesToAdd = 0;
    for (int i = 0; i < index; i++) {
      final duration = fields[i]['time'];
      if (duration is int) {
        minutesToAdd += duration;
      } else if (duration is String) {
        minutesToAdd += int.tryParse(duration) ?? 0;
      }
    }

    // Parse start time
    DateTime? startTime;
    if (startTimeStr is String) {
      startTime = DateTime.tryParse(startTimeStr);
      if (startTime == null && startTimeStr.contains(':')) {
        // Parse time string like "09:00"
        final parts = startTimeStr.split(':');
        if (parts.length >= 2) {
          final hour = int.tryParse(parts[0]) ?? 0;
          final minute = int.tryParse(parts[1]) ?? 0;
          startTime = DateTime(2000, 1, 1, hour, minute);
        }
      }
    }

    if (startTime == null) return '';

    final resultTime = startTime.add(Duration(minutes: minutesToAdd));
    return DateFormat('HH:mm').format(resultTime);
  }

  bool _isInstrumentMissing(int? songId) {
    if (songId == null || playerInstrumentId == null || songs.isEmpty) {
      return false;
    }

    final song = songs.firstWhere(
      (s) => s['id'] == songId,
      orElse: () => <String, dynamic>{},
    );

    final instrumentIds = song['instrument_ids'] as List?;
    if (instrumentIds == null || instrumentIds.isEmpty) {
      return false;
    }

    return !instrumentIds.contains(playerInstrumentId);
  }
}

/// Row showing start or end time
class _PlanTimeRow extends StatelessWidget {
  const _PlanTimeRow({
    required this.label,
    required this.time,
    required this.isStart,
  });

  final String label;
  final String time;
  final bool isStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
      child: Row(
        children: [
          Icon(
            isStart ? Icons.play_arrow : Icons.stop,
            color: isStart ? AppColors.success : AppColors.danger,
            size: 20,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isStart ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

/// Row showing a plan field (song/activity)
class _PlanFieldRow extends StatelessWidget {
  const _PlanFieldRow({
    required this.name,
    required this.duration,
    required this.time,
    this.conductor,
    this.isInstrumentMissing = false,
  });

  final String name;
  final int duration;
  final String time;
  final String? conductor;
  final bool isInstrumentMissing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isInstrumentMissing) ...[
            const Icon(
              Icons.warning_amber,
              color: AppColors.warning,
              size: 18,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isInstrumentMissing ? AppColors.warning : null,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.medium.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$duration min',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.medium,
                        ),
                      ),
                    ),
                    if (conductor != null && conductor!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        conductor!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.medium,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the plan viewer of a Termin.
///
/// ORG_PLANS: delegates to the shared [showPlanViewer] (Programmblöcke,
/// Notizen, live mode with countdown, export incl. Telegram). Rows of Werke
/// without parts for [playerInstrumentId] show "Keine Noten für dein Instrument".
Future<void> showPlanViewerSheet(
  BuildContext context, {
  required CrossTenantPersonAttendance attendance,
  int? playerInstrumentId,
  List<Map<String, dynamic>> songs = const [],
}) {
  Plan? plan;
  try {
    if (attendance.plan != null) plan = Plan.fromJson(attendance.plan!);
  } catch (_) {}
  bool missing(int? songId) {
    if (songId == null || playerInstrumentId == null || songs.isEmpty) return false;
    final song = songs.firstWhere((s) => s['id'] == songId, orElse: () => <String, dynamic>{});
    final ids = song['instrument_ids'] as List?;
    return ids != null && ids.isNotEmpty && !ids.contains(playerInstrumentId);
  }

  final date = attendance.date ?? '';
  final isToday = DateUtils.isSameDay(DateTime.tryParse(date), DateTime.now());
  return showPlanViewer(
    context,
    attendance: PlanAttendance(
      id: attendance.attendanceId,
      tenantId: attendance.tenantId,
      date: date,
      plan: plan,
      typeInfo: attendance.typeInfo,
    ),
    plan: plan,
    title: (attendance.typeInfo?.isNotEmpty ?? false) ? attendance.typeInfo : 'Ablaufplan',
    defaultLive: isToday,
    fieldWarning: (f) => missing(f.songId) ? 'Keine Noten für dein Instrument' : null,
  );
}
