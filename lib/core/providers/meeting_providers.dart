import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/meeting/meeting.dart';
import '../../data/repositories/meeting_repository.dart';
import 'tenant_providers.dart';

/// Initialized meeting repository with tenant context
final meetingRepositoryWithTenantProvider = Provider<MeetingRepository>((ref) {
  final repo = ref.watch(meetingRepositoryProvider);
  final tenant = ref.watch(currentTenantIdProvider);

  if (tenant != null) {
    repo.setTenantId(tenant);
  }

  return repo;
});

/// Provider for meetings list
final meetingsProvider = FutureProvider<List<Meeting>>((ref) async {
  final repo = ref.watch(meetingRepositoryWithTenantProvider);

  if (!repo.hasTenantId) return [];

  return repo.getMeetings();
});

/// Provider for a single meeting by ID
final meetingByIdProvider = FutureProvider.family<Meeting?, int>((ref, id) async {
  final repo = ref.watch(meetingRepositoryWithTenantProvider);

  if (!repo.hasTenantId) return null;

  return repo.getMeetingById(id);
});

/// Notifier for meeting mutations
class MeetingNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  MeetingRepository get _repo => ref.read(meetingRepositoryWithTenantProvider);

  Future<Meeting?> createMeeting(Meeting meeting) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.createMeeting(meeting);
      state = const AsyncValue.data(null);
      ref.invalidate(meetingsProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<Meeting?> updateMeeting(int id, {
    String? date,
    String? notes,
    List<int>? attendeeIds,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.updateMeeting(
        id,
        date: date,
        notes: notes,
        attendeeIds: attendeeIds,
      );
      state = const AsyncValue.data(null);
      ref.invalidate(meetingsProvider);
      ref.invalidate(meetingByIdProvider(id));
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<void> deleteMeeting(int id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteMeeting(id);
      state = const AsyncValue.data(null);
      ref.invalidate(meetingsProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final meetingNotifierProvider = NotifierProvider<MeetingNotifier, AsyncValue<void>>(() {
  return MeetingNotifier();
});
