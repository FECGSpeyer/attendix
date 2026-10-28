import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/enums.dart';
import '../../data/models/attendance/attendance.dart';
import '../../data/models/cross_tenant/cross_tenant_attendance.dart';
import '../../data/models/tenant/tenant.dart';

/// Service for loading attendance data across multiple tenants
class CrossTenantService {
  final SupabaseClient _supabase;

  CrossTenantService(this._supabase);

  /// Deterministic colors for tenant differentiation in UI
  static const List<String> _tenantColors = [
    '#FF6B6B', // Red
    '#4ECDC4', // Teal
    '#45B7D1', // Blue
    '#96CEB4', // Green
    '#FFEAA7', // Yellow
    '#DDA0DD', // Plum
    '#98D8C8', // Mint
    '#F7DC6F', // Gold
    '#BB8FCE', // Purple
    '#85C1E9', // Light Blue
    '#F8B500', // Orange
    '#00CED1', // Dark Cyan
    '#FF7F50', // Coral
    '#9370DB', // Medium Purple
    '#3CB371', // Medium Sea Green
    '#FFD700', // Gold
  ];

  /// Get deterministic color for a tenant
  String getTenantColor(int tenantId) {
    return _tenantColors[tenantId % _tenantColors.length];
  }

  /// Get the person ID for a user in a specific tenant
  /// Returns null if the user is not a member of this tenant
  Future<int?> getPersonIdForTenant(int tenantId, String userId) async {
    try {
      // DB_REVIEW_REST (M6): Ionic loads all rows (an archived and a new
      // active row can share the appId) and picks client-side; a single-row
      // read threw PGRST116 and dropped the whole tenant.
      final response = await _supabase
          .from('player')
          .select('id, pending, left')
          .eq('tenantId', tenantId)
          .eq('appId', userId);

      return pickPersonIdForTenant(
          (response as List).cast<Map<String, dynamic>>());
    } catch (e) {
      debugPrint('Error getting person ID for tenant $tenantId: $e');
      return null;
    }
  }

  /// Ionic getPersonIdForTenant row choice: first active (not pending, not
  /// archived) row, otherwise the first row.
  @visibleForTesting
  static int? pickPersonIdForTenant(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return null;
    final active = rows.where((p) =>
        p['pending'] != true && (p['left'] == null || p['left'] == ''));
    final row = active.isNotEmpty ? active.first : rows.first;
    return (row['id'] as num?)?.toInt();
  }

  /// Get person attendances for a specific tenant
  /// SEC-002: Added tenantId filter - parameter was unused before!
  Future<List<Map<String, dynamic>>> getPersonAttendancesForTenant(
    int personId,
    int tenantId,
    String startDate,
  ) async {
    try {
      final response = await _supabase
          .from('person_attendances')
          .select('''
            *,
            attendance:attendance_id!inner (
              id,
              date,
              type,
              typeInfo,
              type_id,
              start_time,
              end_time,
              deadline,
              tenantId
            )
          ''')
          .eq('person_id', personId)
          .eq('attendance.tenantId', tenantId)
          .gt('attendance.date', startDate);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error getting attendances for person $personId: $e');
      return [];
    }
  }

  /// Get attendance types for multiple tenants
  Future<Map<int, List<AttendanceType>>> getAttendanceTypesForTenants(
    List<int> tenantIds,
  ) async {
    final result = <int, List<AttendanceType>>{};

    try {
      // Load all in one query
      final response = await _supabase
          .from('attendance_types')
          .select('*')
          .inFilter('tenant_id', tenantIds)
          .order('index', ascending: true);

      // Group by tenant_id
      for (final item in response as List) {
        final tenantId = item['tenant_id'] as int?;
        if (tenantId != null) {
          result[tenantId] ??= [];
          result[tenantId]!.add(AttendanceType.fromJson(item));
        }
      }
    } catch (e) {
      debugPrint('Error getting attendance types: $e');
    }

    return result;
  }

  /// Load all person attendances across all tenants for a user
  Future<List<CrossTenantPersonAttendance>> loadAllPersonAttendancesAcrossTenants(
    String userId,
    List<Tenant> tenants,
    String startDate,
  ) async {
    if (tenants.isEmpty) return [];

    final results = <CrossTenantPersonAttendance>[];

    // Get attendance types for all tenants upfront
    final tenantIds = tenants
        .where((t) => t.id != null)
        .map((t) => t.id!)
        .toList();
    final attendanceTypes = await getAttendanceTypesForTenants(tenantIds);

    // Process each tenant
    for (final tenant in tenants) {
      if (tenant.id == null) continue;

      // Get person ID for this tenant
      final personId = await getPersonIdForTenant(tenant.id!, userId);
      if (personId == null) continue;

      // Get attendances for this person in this tenant
      final attendances = await getPersonAttendancesForTenant(
        personId,
        tenant.id!,
        startDate,
      );

      // Get types for this tenant
      final types = attendanceTypes[tenant.id!] ?? [];

      // Convert to CrossTenantPersonAttendance
      for (final att in attendances) {
        final attendanceData = att['attendance'] as Map<String, dynamic>?;
        if (attendanceData == null) continue;

        // Find matching attendance type
        final typeId = attendanceData['type_id']?.toString();
        final attendanceType = types.firstWhere(
          (t) => t.id == typeId,
          orElse: () => const AttendanceType(name: ''),
        );

        // Create PersonAttendance from the joined data
        final personAttendance = PersonAttendance(
          id: att['id']?.toString(),
          attendanceId: attendanceData['id'] as int?,
          personId: personId,
          status: _parseStatus(att['status']),
          notes: att['notes']?.toString(),
          date: attendanceData['date']?.toString(),
        );

        results.add(CrossTenantPersonAttendance(
          attendance: personAttendance,
          tenantId: tenant.id!,
          tenantName: tenant.shortName.isNotEmpty ? tenant.shortName : tenant.longName,
          tenantColor: getTenantColor(tenant.id!),
          attendanceType: attendanceType.name.isNotEmpty ? attendanceType : null,
          date: attendanceData['date']?.toString(),
          startTime: attendanceData['start_time']?.toString(),
          endTime: attendanceData['end_time']?.toString(),
          title: attendanceData['typeInfo']?.toString(),
        ));
      }
    }

    // Sort by date (newest first for upcoming, then oldest)
    results.sort((a, b) {
      final dateA = a.dateTime;
      final dateB = b.dateTime;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateA.compareTo(dateB);
    });

    return results;
  }

  /// Parse attendance status from dynamic value
  AttendanceStatus _parseStatus(dynamic value) {
    if (value == null) return AttendanceStatus.neutral;
    if (value is int) return AttendanceStatus.fromValue(value);
    if (value is String) {
      final intValue = int.tryParse(value);
      if (intValue != null) return AttendanceStatus.fromValue(intValue);
    }
    return AttendanceStatus.neutral;
  }
}
