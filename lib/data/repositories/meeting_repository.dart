import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/meeting/meeting.dart';
import 'base_repository.dart';
import '../../l10n/l10n.dart';

/// Provider for MeetingRepository
final meetingRepositoryProvider = Provider<MeetingRepository>((ref) {
  return MeetingRepository(ref);
});

/// Repository for meeting operations
class MeetingRepository extends BaseRepository with TenantAwareRepository {
  MeetingRepository(super.ref);

  /// Get all meetings for the current tenant
  Future<List<Meeting>> getMeetings() async {
    try {
      final response = await supabase
          .from('meetings')
          .select('*')
          .eq('tenantId', currentTenantId)
          .order('date', ascending: false);

      return (response as List)
          .map((e) => Meeting.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getMeetings');
      rethrow;
    }
  }

  /// Get a single meeting by ID
  Future<Meeting?> getMeetingById(int id) async {
    try {
      final response = await supabase
          .from('meetings')
          .select('*')
          .eq('id', id)
          .eq('tenantId', currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return Meeting.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getMeetingById');
      rethrow;
    }
  }

  /// Create a new meeting
  /// BL-005: Checks for duplicate meetings on the same date
  Future<Meeting> createMeeting(Meeting meeting) async {
    try {
      // BL-005: Check for existing meeting on the same date
      final existing = await supabase
          .from('meetings')
          .select('id')
          .eq('tenantId', currentTenantId)
          .eq('date', meeting.date)
          .maybeSingle();

      if (existing != null) {
        throw Exception(l10nWithoutContext.coreFlutterRepoMeetingExistsOnDate);
      }

      final data = {
        'tenantId': currentTenantId,
        'date': meeting.date,
        'notes': meeting.notes,
        'attendees': meeting.attendeeIds,
      };

      final response = await supabase
          .from('meetings')
          .insert(data)
          .select()
          .single();

      return Meeting.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'createMeeting');
      rethrow;
    }
  }

  /// Update an existing meeting
  /// BL-004: Checks for duplicate meetings when date changes
  Future<Meeting> updateMeeting(int id, {
    String? date,
    String? notes,
    List<int>? attendeeIds,
  }) async {
    try {
      // BL-004: Check for duplicate if date is being changed
      if (date != null) {
        final existing = await supabase
            .from('meetings')
            .select('id')
            .eq('tenantId', currentTenantId)
            .eq('date', date)
            .neq('id', id) // Exclude current meeting
            .maybeSingle();

        if (existing != null) {
          throw Exception(l10nWithoutContext.coreFlutterRepoMeetingExistsOnDate);
        }
      }

      final updates = <String, dynamic>{};
      if (date != null) updates['date'] = date;
      if (notes != null) updates['notes'] = notes;
      if (attendeeIds != null) updates['attendees'] = attendeeIds;

      final response = await supabase
          .from('meetings')
          .update(updates)
          .eq('id', id)
          .eq('tenantId', currentTenantId)
          .select()
          .single();

      return Meeting.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'updateMeeting');
      rethrow;
    }
  }

  /// Delete a meeting
  Future<void> deleteMeeting(int id) async {
    try {
      await supabase
          .from('meetings')
          .delete()
          .eq('id', id)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteMeeting');
      rethrow;
    }
  }
}
