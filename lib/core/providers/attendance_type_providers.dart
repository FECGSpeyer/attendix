import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/attendance/attendance.dart';
import '../../data/repositories/attendance_type_repository.dart';
import '../utils/demo_guard.dart';
import 'tenant_providers.dart';

/// Initialized attendance type repository with tenant context
final attendanceTypeRepositoryWithTenantProvider = Provider<AttendanceTypeRepository>((ref) {
  final repo = ref.watch(attendanceTypeRepositoryProvider);
  final tenant = ref.watch(currentTenantIdProvider);

  if (tenant != null) {
    repo.setTenantId(tenant);
  }

  return repo;
});

/// Provider for attendance types list
final attendanceTypesProvider = FutureProvider<List<AttendanceType>>((ref) async {
  // Keep data in memory - attendance types rarely change during a session
  ref.keepAlive();

  final repo = ref.watch(attendanceTypeRepositoryWithTenantProvider);

  if (!repo.hasTenantId) return [];

  return repo.getTypes();
});

/// Provider for visible attendance types only (for creating new attendances)
final visibleAttendanceTypesProvider = FutureProvider<List<AttendanceType>>((ref) async {
  final allTypes = await ref.watch(attendanceTypesProvider.future);
  return allTypes.where((type) => type.visible == true).toList();
});

/// Provider for a single attendance type by ID
final attendanceTypeByIdProvider = FutureProvider.family<AttendanceType?, String>((ref, id) async {
  final repo = ref.watch(attendanceTypeRepositoryWithTenantProvider);

  if (!repo.hasTenantId) return null;

  return repo.getTypeById(id);
});

/// Notifier for attendance type mutations
class AttendanceTypeNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  AttendanceTypeRepository get _repo => ref.read(attendanceTypeRepositoryWithTenantProvider);

  /// LOGIC_SETTINGS: rethrows on failure so the caller shows
  /// `typeSettings.createFailed` (Ionic createType) instead of a success toast.
  Future<AttendanceType> createType(AttendanceType type) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.createType(type);
      state = const AsyncValue.data(null);
      ref.invalidate(attendanceTypesProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Saves the type. Returns null when the save itself failed (caller shows
  /// `typeSettings.updateFailed`); rethrows [DemoModeException] so the demo
  /// block is not reported as a generic failure.
  Future<AttendanceType?> updateType(String id, Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    final AttendanceType? result;
    try {
      result = await _repo.updateType(id, updates);
      state = const AsyncValue.data(null);
      ref.invalidate(attendanceTypesProvider);
      ref.invalidate(attendanceTypeByIdProvider(id));
    } on DemoModeException catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
    // DB_FIX: Ionic updateAttendanceType only updates the attendance_types
    // row. It never rewrites start_time/end_time of existing Termine (the
    // removed follow-up overwrote the times of ALL future Termine of the
    // type on every save, because the edit page always sends both times).
    return result;
  }

  Future<bool> deleteType(String id) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repo.deleteType(id);
      state = const AsyncValue.data(null);
      ref.invalidate(attendanceTypesProvider);
      return success;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> reorderTypes(List<String> orderedIds) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repo.reorderTypes(orderedIds);
      state = const AsyncValue.data(null);
      ref.invalidate(attendanceTypesProvider);
      return success;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final attendanceTypeNotifierProvider = NotifierProvider<AttendanceTypeNotifier, AsyncValue<void>>(() {
  return AttendanceTypeNotifier();
});
