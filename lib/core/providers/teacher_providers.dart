import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/teacher_repository.dart';
import 'group_providers.dart';
import 'tenant_providers.dart';
import '../services/tracking/tracking_event.dart';
import '../services/tracking/tracking_service.dart';

/// Initialized teacher repository with tenant context
final teacherRepositoryWithTenantProvider = Provider<TeacherRepository>((ref) {
  final repo = ref.watch(teacherRepositoryProvider);
  final tenant = ref.watch(currentTenantIdProvider);

  if (tenant != null) {
    repo.setTenantId(tenant);
  }

  return repo;
});

/// Provider for teachers list
final teachersProvider = FutureProvider<List<Teacher>>((ref) async {
  final repo = ref.watch(teacherRepositoryWithTenantProvider);

  if (!repo.hasTenantId) return [];

  return repo.getTeachers();
});

/// Provider for a single teacher by ID
final teacherByIdProvider = FutureProvider.family<Teacher?, int>((ref, id) async {
  final repo = ref.watch(teacherRepositoryWithTenantProvider);

  if (!repo.hasTenantId) return null;

  return repo.getTeacherById(id);
});

/// Provider for student counts per teacher
final studentCountsProvider = FutureProvider<Map<int, int>>((ref) async {
  final repo = ref.watch(teacherRepositoryWithTenantProvider);

  if (!repo.hasTenantId) return {};

  return repo.getStudentCounts();
});

/// Enriched teachers with instrument names and student counts
final enrichedTeachersProvider = FutureProvider<List<Teacher>>((ref) async {
  final teachers = await ref.watch(teachersProvider.future);
  if (teachers.isEmpty) return [];

  final groupsMap = await ref.watch(groupsMapProvider.future);
  final studentCounts = await ref.watch(studentCountsProvider.future);

  return teachers.map((teacher) {
    // Resolve instrument IDs to names
    final names = teacher.instruments
        .map((id) => groupsMap[id])
        .where((name) => name != null)
        .join(', ');

    return teacher.copyWith(
      insNames: names.isNotEmpty ? names : null,
      playerCount: studentCounts[teacher.id] ?? 0,
    );
  }).toList();
});

/// Notifier for teacher mutations
class TeacherNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  TeacherRepository get _repo => ref.read(teacherRepositoryWithTenantProvider);

  Future<Teacher?> createTeacher(Teacher teacher) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.createTeacher(teacher);
      ref.read(trackingServiceProvider).track(TrackingEvent.teacherAdded);
      state = const AsyncValue.data(null);
      ref.invalidate(teachersProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<Teacher?> updateTeacher(int id, Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.updateTeacher(id, updates);
      ref.read(trackingServiceProvider).track(TrackingEvent.teacherUpdated);
      state = const AsyncValue.data(null);
      ref.invalidate(teachersProvider);
      ref.invalidate(teacherByIdProvider(id));
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<bool> deleteTeacher(int id) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repo.deleteTeacher(id);
      state = const AsyncValue.data(null);
      ref.invalidate(teachersProvider);
      return success;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final teacherNotifierProvider = NotifierProvider<TeacherNotifier, AsyncValue<void>>(() {
  return TeacherNotifier();
});
