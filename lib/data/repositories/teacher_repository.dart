import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/teacher/teacher.dart';
import 'base_repository.dart';

export '../models/teacher/teacher.dart';

/// Repository for Teacher (Ausbilder/Dirigent) operations
/// Uses the 'teachers' table (same as Ionic project)
class TeacherRepository extends BaseRepository with TenantAwareRepository {
  TeacherRepository(super.ref);

  /// Get all teachers for current tenant
  Future<List<Teacher>> getTeachers() async {
    try {
      final response = await supabase
          .from('teachers')
          .select()
          .eq('tenantId', currentTenantId)
          .order('name', ascending: true);

      return (response as List)
          .map((json) => Teacher.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getTeachers');
      rethrow;
    }
  }

  /// Get a single teacher by ID
  Future<Teacher?> getTeacherById(int id) async {
    try {
      final response = await supabase
          .from('teachers')
          .select()
          .eq('id', id)
          .eq('tenantId', currentTenantId)
          .single();

      return Teacher.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getTeacherById');
      rethrow;
    }
  }

  /// Create a new teacher
  Future<Teacher?> createTeacher(Teacher teacher) async {
    ensureNotDemo('createTeacher'); // DEMO_GUARD
    try {
      final data = {
        'name': teacher.name,
        'instruments': teacher.instruments,
        'notes': teacher.notes,
        'number': teacher.number,
        'private': teacher.isPrivate,
        'tenantId': currentTenantId,
      };

      final response = await supabase
          .from('teachers')
          .insert(data)
          .select()
          .single();

      return Teacher.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'createTeacher');
      rethrow;
    }
  }

  /// Update a teacher
  Future<Teacher?> updateTeacher(int id, Map<String, dynamic> updates) async {
    ensureNotDemo('updateTeacher'); // DEMO_GUARD
    try {
      updates.remove('id');
      updates.remove('created_at');
      updates.remove('tenantId');

      final response = await supabase
          .from('teachers')
          .update(updates)
          .eq('id', id)
          .eq('tenantId', currentTenantId)
          .select()
          .single();

      return Teacher.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'updateTeacher');
      rethrow;
    }
  }

  /// Delete a teacher
  Future<bool> deleteTeacher(int id) async {
    ensureNotDemo('deleteTeacher'); // DEMO_GUARD
    try {
      await supabase
          .from('teachers')
          .delete()
          .eq('id', id)
          .eq('tenantId', currentTenantId);

      return true;
    } catch (e, stack) {
      handleError(e, stack, 'deleteTeacher');
      rethrow;
    }
  }

  /// Get count of students per teacher
  Future<Map<int, int>> getStudentCounts() async {
    try {
      final response = await supabase
          .from('player')
          .select('teacher')
          .eq('tenantId', currentTenantId)
          .not('teacher', 'is', null);

      final counts = <int, int>{};
      for (final row in (response as List)) {
        final teacherId = row['teacher'] as int?;
        if (teacherId != null) {
          counts[teacherId] = (counts[teacherId] ?? 0) + 1;
        }
      }
      return counts;
    } catch (e, stack) {
      handleError(e, stack, 'getStudentCounts');
      rethrow;
    }
  }
}

/// Provider for TeacherRepository
final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  return TeacherRepository(ref);
});
