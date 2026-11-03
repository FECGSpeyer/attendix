import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auto_message/auto_message.dart';
import '../models/message/message.dart';
import '../../core/utils/paged_query.dart';
import 'base_repository.dart';
import '../../core/utils/archived_attendance.dart';

/// Provider for AutoMessageRepository
final autoMessageRepositoryProvider = Provider<AutoMessageRepository>((ref) {
  return AutoMessageRepository(ref);
});

/// Automatische Nachrichten (port of Ionic `AutoMessageService`, 4.18):
/// rules, their history (runs), the preview and the answers of members.
/// Sending happens in the `send-auto-messages` Edge Function (cron), answers
/// go through `attendance-response`.
///
/// SECURITY: every table query filters `.eq('tenantId', currentTenantId)`
/// (all three tables, `attendance` and `message_recipients` carry it). RLS
/// additionally limits rules/runs/responses to admins/responsibles; members
/// only read their own response.
class AutoMessageRepository extends BaseRepository with TenantAwareRepository {
  AutoMessageRepository(super.ref);

  String? get _userId => supabase.auth.currentUser?.id;

  // --- Rules -----------------------------------------------------------------

  Future<List<AutoMessageRule>> getRules() async {
    try {
      final response = await supabase
          .from('auto_message_rules')
          .select('*')
          .eq('tenantId', currentTenantId)
          .order('created_at', ascending: true);
      return (response as List)
          .map((e) => AutoMessageRule.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getRules');
      rethrow;
    }
  }

  Future<AutoMessageRule?> getRule(String id) async {
    try {
      final response =
          await supabase
              .from('auto_message_rules')
              .select('*')
              .eq('id', id)
              .eq('tenantId', currentTenantId)
              .maybeSingle();
      return response == null ? null : AutoMessageRule.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getRule');
      rethrow;
    }
  }

  /// Inserts or updates a rule. Switching it on stamps `enabled_at`, so older
  /// Termine are never sent (Ionic saveRule).
  Future<AutoMessageRule> saveRule(AutoMessageRule rule, AutoMessageRule? previous) async {
    ensureNotDemo('saveAutoMessageRule'); // DEMO_GUARD
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final row = <String, dynamic>{...rule.toRow(), 'updated_at': now};
      if (rule.enabled && (previous == null || !previous.enabled || previous.enabledAt == null)) {
        row['enabled_at'] = now;
      }
      final Map<String, dynamic> saved;
      if (rule.id != null) {
        saved =
            await supabase
                .from('auto_message_rules')
                .update(row)
                .eq('id', rule.id!)
                .eq('tenantId', currentTenantId)
                .select('*')
                .single();
      } else {
        saved =
            await supabase
                .from('auto_message_rules')
                .insert({...row, 'tenantId': currentTenantId, 'created_by': _userId})
                .select('*')
                .single();
      }
      return AutoMessageRule.fromJson(saved);
    } catch (e, stack) {
      handleError(e, stack, 'saveRule');
      rethrow;
    }
  }

  Future<AutoMessageRule> setEnabled(String id, bool enabled) async {
    ensureNotDemo('toggleAutoMessageRule'); // DEMO_GUARD
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final saved =
          await supabase
              .from('auto_message_rules')
              .update({'enabled': enabled, 'updated_at': now, if (enabled) 'enabled_at': now})
              .eq('id', id)
              .eq('tenantId', currentTenantId)
              .select('*')
              .single();
      return AutoMessageRule.fromJson(saved);
    } catch (e, stack) {
      handleError(e, stack, 'setEnabled');
      rethrow;
    }
  }

  Future<void> deleteRule(String id) async {
    ensureNotDemo('deleteAutoMessageRule'); // DEMO_GUARD
    try {
      await supabase
          .from('auto_message_rules')
          .delete()
          .eq('id', id)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteRule');
      rethrow;
    }
  }

  /// What the rule would have sent for the last Termine (dry run, sends nothing).
  Future<List<AutoMessagePreviewTermin>> preview(AutoMessageRule rule) async {
    try {
      final response = await supabase.functions.invoke(
        'send-auto-messages',
        body: {'dryRun': true, 'tenantId': currentTenantId, 'rule': rule.toPreviewJson()},
      );
      final data = response.data;
      final termine = data is Map ? data['termine'] : null;
      return (termine as List? ?? const [])
          .whereType<Map>()
          .map((t) => AutoMessagePreviewTermin.fromJson(t.cast<String, dynamic>()))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'preview');
      rethrow;
    }
  }

  // --- Runs ------------------------------------------------------------------

  Future<List<AutoMessageRun>> getRuns(String ruleId, {int limit = 30}) async {
    try {
      final response = await supabase
          .from('auto_message_runs')
          .select('*')
          .eq('rule_id', ruleId)
          .eq('tenantId', currentTenantId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (response as List)
          .map((e) => AutoMessageRun.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getRuns');
      rethrow;
    }
  }

  Future<List<AutoMessageRun>> getRunsForAttendance(int attendanceId) async {
    try {
      final response = await supabase
          .from('auto_message_runs')
          .select('*')
          .eq('attendance_id', attendanceId)
          .eq('tenantId', currentTenantId);
      return (response as List)
          .map((e) => AutoMessageRun.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getRunsForAttendance');
      rethrow;
    }
  }

  /// Runs of all rules since [since] (for the "last 7 days" line).
  Future<List<AutoMessageRun>> getRecentRuns(DateTime since) async {
    try {
      final response = await supabase
          .from('auto_message_runs')
          .select('*')
          .eq('tenantId', currentTenantId)
          .gte('created_at', since.toUtc().toIso8601String())
          .limit(500);
      return (response as List)
          .map((e) => AutoMessageRun.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getRecentRuns');
      rethrow;
    }
  }

  /// "Diesmal aussetzen": no automatic message of this rule for this Termin.
  /// RLS only allows inserting runs with status 'suspended'.
  Future<void> suspend(AutoMessageRule rule, int attendanceId, String userName) async {
    ensureNotDemo('suspendAutoMessage'); // DEMO_GUARD
    try {
      await supabase.from('auto_message_runs').insert({
        'rule_id': rule.id,
        'tenantId': currentTenantId,
        'attendance_id': attendanceId,
        'status': 'suspended',
        'created_by': _userId,
        'created_by_name': userName,
      });
    } catch (e, stack) {
      handleError(e, stack, 'suspend');
      rethrow;
    }
  }

  Future<void> unsuspend(String runId) async {
    ensureNotDemo('unsuspendAutoMessage'); // DEMO_GUARD
    try {
      await supabase
          .from('auto_message_runs')
          .delete()
          .eq('id', runId)
          .eq('status', 'suspended')
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'unsuspend');
      rethrow;
    }
  }

  // --- History helpers -------------------------------------------------------

  /// Date and name of Termine (history rows, message Termin card).
  Future<List<AutoMessageTerminInfo>> getAttendanceInfo(List<int> ids) async {
    if (ids.isEmpty) return [];
    try {
      final response = await supabase
          .from('attendance')
          .select('id, date, typeInfo, type_id, archived')
          .inFilter('id', ids)
          .eq('tenantId', currentTenantId);
      // Ionic 4.17.24: archived Termine stay hidden for every role except
      // admins/responsible (no Termin card and no answer actions).
      final showArchived = canSeeArchivedAttendances(currentUserRole);
      return (response as List)
          .cast<Map<String, dynamic>>()
          .where((e) => showArchived || !isArchivedRow(e))
          .map(AutoMessageTerminInfo.fromJson)
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getAttendanceInfo');
      rethrow;
    }
  }

  /// Recipient rows of several messages (read state per person for the history).
  Future<List<MessageRecipient>> getRecipientsOf(List<String> messageIds) async {
    if (messageIds.isEmpty) return [];
    try {
      final tenantId = currentTenantId;
      final response = await fetchAllPages<dynamic>((from, to) async {
        final page = await supabase
            .from('message_recipients')
            .select(
              'id, message_id, player_id, user_id, name, email, push_sent_at, '
              'telegram_sent_at, push_enabled, email_sent_at, email_opened_at, read_at',
            )
            .inFilter('message_id', messageIds)
            .eq('tenantId', tenantId)
            .order('id', ascending: true)
            .range(from, to);
        return page as List;
      });
      return response.map((e) => MessageRecipient.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e, stack) {
      handleError(e, stack, 'getRecipientsOf');
      rethrow;
    }
  }

  // --- Termin messages -------------------------------------------------------

  /// Ionic 4.18 columns of a message (Termin, answers allowed, template
  /// texts and placeholder values).
  Future<MessageAutoInfo?> getMessageAutoInfo(String messageId) async {
    try {
      final row =
          await supabase
              .from('messages')
              .select('auto_rule_id, attendance_id, allow_responses, vars, i18n')
              .eq('id', messageId)
              .eq('tenantId', currentTenantId)
              .maybeSingle();
      return row == null ? null : MessageAutoInfo.fromJson(row);
    } catch (e, stack) {
      handleError(e, stack, 'getMessageAutoInfo');
      rethrow;
    }
  }

  /// The caller's own recipient row of a message (Termin row, placeholder
  /// values, language).
  Future<RecipientAutoInfo?> getOwnRecipientAutoInfo(String messageId) async {
    final userId = _userId;
    if (userId == null) return null;
    try {
      final row =
          await supabase
              .from('message_recipients')
              .select('person_attendance_id, vars, lang')
              .eq('message_id', messageId)
              .eq('user_id', userId)
              .eq('tenantId', currentTenantId)
              .limit(1)
              .maybeSingle();
      return row == null ? null : RecipientAutoInfo.fromJson(row);
    } catch (e, stack) {
      handleError(e, stack, 'getOwnRecipientAutoInfo');
      rethrow;
    }
  }

  // --- Responses -------------------------------------------------------------

  Future<List<AttendanceResponse>> getResponsesForAttendance(int attendanceId) async {
    try {
      final response = await supabase
          .from('attendance_responses')
          .select('*')
          .eq('attendance_id', attendanceId)
          .eq('tenantId', currentTenantId)
          .order('created_at', ascending: true);
      return (response as List)
          .map((e) => AttendanceResponse.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getResponsesForAttendance');
      rethrow;
    }
  }

  Future<List<AttendanceResponse>> getResponsesForMessages(List<String> messageIds) async {
    if (messageIds.isEmpty) return [];
    try {
      final response = await supabase
          .from('attendance_responses')
          .select('*')
          .inFilter('message_id', messageIds)
          .eq('tenantId', currentTenantId);
      return (response as List)
          .map((e) => AttendanceResponse.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getResponsesForMessages');
      rethrow;
    }
  }

  /// The current member's own answer to a Termin message, if any.
  Future<AttendanceResponse?> getOwnResponse(String personAttendanceId) async {
    try {
      final response =
          await supabase
              .from('attendance_responses')
              .select('*')
              .eq('person_attendance_id', personAttendanceId)
              .eq('tenantId', currentTenantId)
              .maybeSingle();
      return response == null ? null : AttendanceResponse.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getOwnResponse');
      rethrow;
    }
  }

  /// Status of the current member for the Termin of a message (scoped to the
  /// tenant via the Termin, person_attendances has no tenantId column).
  Future<int?> getPersonAttendanceStatus(String personAttendanceId) async {
    try {
      final row =
          await supabase
              .from('person_attendances')
              .select('status, attendance:attendance_id!inner(tenantId)')
              .eq('id', personAttendanceId)
              .eq('attendance.tenantId', currentTenantId)
              .maybeSingle();
      final status = row?['status'];
      return status is int ? status : int.tryParse('${status ?? ''}');
    } catch (e, stack) {
      handleError(e, stack, 'getPersonAttendanceStatus');
      rethrow;
    }
  }

  /// Member answer: a reason or "I was there". Returns the new state
  /// ('pending' | 'accepted'). Errors: 'expired', 'alreadyDecided', other.
  Future<String> submitResponse({
    required String messageId,
    required String kind,
    String? reasonCode,
    String text = '',
  }) async {
    ensureNotDemo('submitAttendanceResponse'); // DEMO_GUARD
    try {
      final response = await supabase.functions.invoke(
        'attendance-response',
        body: {
          'action': 'submit',
          'messageId': messageId,
          'kind': kind,
          'reasonCode': reasonCode,
          'text': text,
        },
      );
      final data = response.data;
      return (data is Map ? data['state'] as String? : null) ?? 'pending';
    } on FunctionException catch (e) {
      throw RepositoryException(message: _functionError(e), operation: 'submitResponse');
    } catch (e, stack) {
      handleError(e, stack, 'submitResponse');
      rethrow;
    }
  }

  /// Admin/responsible confirms or rejects an answer (the function changes
  /// the status and notifies the member).
  Future<void> decideResponse(String responseId, bool accept) async {
    ensureNotDemo('decideAttendanceResponse'); // DEMO_GUARD
    try {
      await supabase.functions.invoke(
        'attendance-response',
        body: {'action': 'decide', 'responseId': responseId, 'accept': accept},
      );
    } on FunctionException catch (e) {
      throw RepositoryException(message: _functionError(e), operation: 'decideResponse');
    } catch (e, stack) {
      handleError(e, stack, 'decideResponse');
      rethrow;
    }
  }

  static String _functionError(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] != null) return '${details['error']}';
    return e.reasonPhrase ?? 'error';
  }
}
