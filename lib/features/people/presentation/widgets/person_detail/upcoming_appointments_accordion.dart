import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/l10n.dart';

/// Provider for upcoming attendances (future dates) for a person.
final upcomingAttendancesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>(
        (ref, personId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);

  if (tenant == null) return [];

  final today = DateTime.now().toIso8601String().substring(0, 10);

  // Get attendance types for name resolution
  final typesResponse = await supabase
      .from('attendance_types')
      .select('*')
      .eq('tenant_id', tenant.id!);
  final attendanceTypes = List<Map<String, dynamic>>.from(typesResponse as List);

  final response = await supabase
      .from('person_attendances')
      .select(
          '*, attendance:attendance_id!inner(id, date, type, typeInfo, type_id, tenantId)')
      .eq('person_id', personId)
      .eq('attendance.tenantId', tenant.id!)
      .gte('attendance.date', today);

  final attendances = (response as List).where((a) => a['attendance'] != null).map((a) {
    final attendance = a['attendance'] as Map<String, dynamic>;
    final typeId = attendance['type_id'];
    final typeInfo = attendance['typeInfo']?.toString();

    String meetingName = '';
    final attType = attendanceTypes.firstWhere(
      (t) => t['id'] == typeId,
      orElse: () => <String, dynamic>{},
    );
    if (attType.isNotEmpty) {
      final typeName = attType['name']?.toString() ?? '';
      meetingName =
          (typeInfo != null && typeInfo.isNotEmpty) ? typeInfo : typeName;
    } else {
      meetingName =
          typeInfo ?? attendance['type']?.toString() ?? 'Anwesenheit';
    }

    final statusValue = a['status'];
    int statusInt = 0;
    if (statusValue is int) {
      statusInt = statusValue;
    } else if (statusValue != null) {
      statusInt = int.tryParse(statusValue.toString()) ?? 0;
    }

    return {
      'date': attendance['date']?.toString(),
      'meetingName': meetingName,
      'status': statusInt,
      'notes': a['notes']?.toString(),
    };
  }).toList();

  // Sort by date ascending (nearest first)
  attendances.sort((a, b) {
    final dateA =
        DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2099);
    final dateB =
        DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2099);
    return dateA.compareTo(dateB);
  });

  return attendances;
});

/// Accordion showing upcoming appointments for a person.
class UpcomingAppointmentsAccordion extends ConsumerWidget {
  const UpcomingAppointmentsAccordion({
    super.key,
    required this.personId,
  });

  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingAttendancesProvider(personId));

    return upcomingAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (appointments) {
        if (appointments.isEmpty) return const SizedBox.shrink();

        return _UpcomingAppointmentsCard(appointments: appointments);
      },
    );
  }
}

class _UpcomingAppointmentsCard extends StatefulWidget {
  const _UpcomingAppointmentsCard({required this.appointments});

  final List<Map<String, dynamic>> appointments;

  @override
  State<_UpcomingAppointmentsCard> createState() =>
      _UpcomingAppointmentsCardState();
}

class _UpcomingAppointmentsCardState extends State<_UpcomingAppointmentsCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingXS,
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              context.l10n.personUpcomingEvents(widget.appointments.length),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing:
                Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingM,
                0,
                AppDimensions.paddingM,
                AppDimensions.paddingM,
              ),
              child: Column(
                children: widget.appointments
                    .map((item) => _buildAppointmentItem(item))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppointmentItem(Map<String, dynamic> item) {
    final date = DateTime.tryParse(item['date'] ?? '');
    final meetingName = item['meetingName']?.toString() ?? '';
    final status = item['status'] as int? ?? 0;
    final notes = item['notes']?.toString();

    final dateStr = date != null ? DateFormat(dateFmt()).format(date) : '';
    final titleStr =
        meetingName.isNotEmpty ? '$dateStr | $meetingName' : dateStr;

    // Status badge
    String? badgeText;
    Color? badgeColor;
    switch (status) {
      case 1:
        badgeText = '✓';
        badgeColor = AppColors.success;
        break;
      case 2:
        badgeText = 'E';
        badgeColor = AppColors.warning;
        break;
      case 3:
      case 5:
        badgeText = 'L';
        badgeColor = AppColors.tertiary;
        break;
      case 4:
        badgeText = 'A';
        badgeColor = AppColors.danger;
        break;
      case 0:
      default:
        badgeText = 'N';
        badgeColor = AppColors.medium;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingM),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titleStr, style: const TextStyle(fontSize: 15)),
                if (notes != null && notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      notes,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                badgeText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
