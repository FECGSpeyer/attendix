import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/team_org/team_org.dart';
import 'base_repository.dart';

/// Provider for TaskRepository
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref);
});

/// Select with joined person, topic and attendance (Ionic TASK_SELECT).
const String taskSelect =
    '*, responsible_person:player!responsible_person_id(id, firstName, lastName), agenda_item:agenda_items!agenda_item_id(id, title), attendance:attendance!attendance_id(id, date, typeInfo, type_id)';

/// Repository for tasks of the Teamorganisation (table `tasks`).
///
/// The tenant column of this table is `tenant_id` (snake_case). RLS on top:
/// leadership sees all tasks, members only the tasks assigned to them.
class TaskRepository extends BaseRepository with TenantAwareRepository {
  TaskRepository(super.ref);

  /// All tasks of the tenant (leadership; members get only their own via RLS).
  Future<List<TeamTask>> getTasks() async {
    try {
      final response = await supabase
          .from('tasks')
          .select(taskSelect)
          .eq('tenant_id', currentTenantId)
          .order('due_date', ascending: true, nullsFirst: false);

      return _parse(response);
    } catch (e, stack) {
      handleError(e, stack, 'getTasks');
      rethrow;
    }
  }

  /// Tasks assigned to the given persons.
  Future<List<TeamTask>> getTasksForPersons(List<int> personIds) async {
    if (personIds.isEmpty) return [];
    try {
      final response = await supabase
          .from('tasks')
          .select(taskSelect)
          .eq('tenant_id', currentTenantId)
          .inFilter('responsible_person_id', personIds)
          .order('due_date', ascending: true, nullsFirst: false);

      return _parse(response);
    } catch (e, stack) {
      handleError(e, stack, 'getTasksForPersons');
      rethrow;
    }
  }

  Future<List<TeamTask>> getTasksForAttendance(int attendanceId) async {
    try {
      final response = await supabase
          .from('tasks')
          .select(taskSelect)
          .eq('attendance_id', attendanceId)
          .eq('tenant_id', currentTenantId)
          .order('created_at', ascending: true);

      return _parse(response);
    } catch (e, stack) {
      handleError(e, stack, 'getTasksForAttendance');
      rethrow;
    }
  }

  Future<List<TeamTask>> getTasksForAgendaItem(String agendaItemId) async {
    try {
      final response = await supabase
          .from('tasks')
          .select(taskSelect)
          .eq('agenda_item_id', agendaItemId)
          .eq('tenant_id', currentTenantId)
          .order('created_at', ascending: true);

      return _parse(response);
    } catch (e, stack) {
      handleError(e, stack, 'getTasksForAgendaItem');
      rethrow;
    }
  }

  Future<TeamTask?> getTaskById(String id) async {
    try {
      final response = await supabase
          .from('tasks')
          .select(taskSelect)
          .eq('id', id)
          .eq('tenant_id', currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return TeamTask.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getTaskById');
      rethrow;
    }
  }

  Future<TeamTask> createTask(TeamTask task) async {
    try {
      final data = <String, dynamic>{
        'title': task.title,
        'description': task.description,
        'responsible_person_id': task.responsiblePersonId,
        'priority': task.priority,
        'due_date': task.dueDate,
        'status': task.status,
        'agenda_item_id': task.agendaItemId,
        'protocol_id': task.protocolId,
        'attendance_id': task.attendanceId,
        'tenant_id': currentTenantId,
      };

      final response = await supabase
          .from('tasks')
          .insert(data)
          .select(taskSelect)
          .single();

      return TeamTask.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'createTask');
      rethrow;
    }
  }

  /// Updates the given columns (snake_case keys). Members may only change
  /// `status` (enforced by the trigger tasks_guard_member_update).
  Future<TeamTask> updateTask(String id, Map<String, dynamic> updates) async {
    try {
      final data = Map<String, dynamic>.from(updates)
        ..remove('id')
        ..remove('tenant_id')
        ..remove('created_at')
        ..remove('completed_at')
        ..remove('responsible_person')
        ..remove('agenda_item')
        ..remove('attendance');
      data['updated_at'] = DateTime.now().toUtc().toIso8601String();

      final response = await supabase
          .from('tasks')
          .update(data)
          .eq('id', id)
          .eq('tenant_id', currentTenantId)
          .select(taskSelect)
          .single();

      return TeamTask.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'updateTask');
      rethrow;
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      final response = await supabase
          .from('tasks')
          .delete()
          .eq('id', id)
          .eq('tenant_id', currentTenantId)
          .select('id');

      if ((response as List).isEmpty) {
        throw const RepositoryException(
          message: 'Keine Berechtigung zum Löschen',
          operation: 'deleteTask',
        );
      }
    } catch (e, stack) {
      if (e is RepositoryException) rethrow;
      handleError(e, stack, 'deleteTask');
      rethrow;
    }
  }

  List<TeamTask> _parse(dynamic response) => (response as List)
      .map((e) => TeamTask.fromJson(e as Map<String, dynamic>))
      .toList();
}
