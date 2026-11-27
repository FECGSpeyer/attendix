part of 'attendance_repository.dart';

mixin _AttendanceExtrasMixin on _AttendanceRepositoryCore {
  // ATTENDANCE_SIGNOUT: history + date-change helpers (Ionic parity)

  /// Song history rows of one Termin (song, conductor person_id / otherConductor).
  Future<List<Map<String, dynamic>>> getHistoryForAttendance(int attendanceId) async {
    try {
      final response = await supabase
          .from('history')
          .select('id, songId, person_id, otherConductor, date')
          .eq('attendance_id', attendanceId)
          .eq('tenantId', currentTenantId)
          // Ionic getHistoryByAttendanceId: order('songId').
          .order('songId', ascending: true);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e, stack) {
      handleError(e, stack, 'getHistoryForAttendance');
      rethrow;
    }
  }

  /// LOGIC_ATT: Ionic addSongsToHistory – inserts song history rows of a
  /// Termin. `tenantId` is always forced to the current tenant.
  Future<void> addHistoryEntries(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    try {
      await supabase
          .from('history')
          .insert([for (final r in rows) {...r, 'tenantId': currentTenantId}]);
    } catch (e, stack) {
      handleError(e, stack, 'addHistoryEntries');
      rethrow;
    }
  }

  /// LOGIC_ATT: Ionic updateHistoryEntry (e.g. conductor change).
  Future<void> updateHistoryEntry(int id, Map<String, dynamic> updates) async {
    ensureNotDemo('updateHistoryEntry'); // DEMO_GUARD
    try {
      await supabase
          .from('history')
          .update(updates)
          .eq('id', id)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'updateHistoryEntry');
      rethrow;
    }
  }

  /// LOGIC_ATT: Ionic removeHistoryEntry.
  Future<void> deleteHistoryEntry(int id) async {
    ensureNotDemo('deleteHistoryEntry'); // DEMO_GUARD
    try {
      await supabase
          .from('history')
          .delete()
          .eq('id', id)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteHistoryEntry');
      rethrow;
    }
  }

  /// Moves the song history of a Termin to its new date.
  Future<void> updateHistoryDatesForAttendance(int attendanceId, String date) async {
    ensureNotDemo('updateHistoryDatesForAttendance'); // DEMO_GUARD
    try {
      await supabase
          .from('history')
          .update({'date': date})
          .eq('attendance_id', attendanceId)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'updateHistoryDatesForAttendance');
      rethrow;
    }
  }

  // ATT_DETAIL: ad-hoc reminder, description attachment

  /// Sends an ad-hoc reminder (push + e-mail) through the
  /// `send-ad-hoc-reminder` Edge Function (Ionic sendAdHocReminder).
  /// [playerAppId] targets one person, [playerAppIds] a subset
  /// ("nur Personen ohne Rückmeldung"); both null = everyone in the Termin.
  Future<void> sendAdHocReminder({
    required int attendanceId,
    String? title,
    String? message,
    String? playerAppId,
    List<String>? playerAppIds,
  }) async {
    try {
      await _assertAttendanceInTenant(attendanceId, 'sendAdHocReminder');
      await supabase.functions.invoke('send-ad-hoc-reminder', body: {
        'attendanceId': attendanceId,
        'tenantId': currentTenantId,
        if (title != null && title.isNotEmpty) 'title': title,
        if (message != null && message.isNotEmpty) 'message': message,
        if (playerAppId != null && playerAppId.isNotEmpty) 'playerAppId': playerAppId,
        if (playerAppIds != null) 'playerAppIds': playerAppIds,
      });
    } catch (e, stack) {
      handleError(e, stack, 'sendAdHocReminder');
      rethrow;
    }
  }

  /// Ionic 4.19.24 `sendTelegramCard`: signs a Telegram `startgroup` link for
  /// `@attendix_bot` via the `attendix-bot` Edge Function.
  Future<String?> createTelegramCardLink(int attendanceId) async {
    ensureNotDemo('createTelegramCardLink'); // DEMO_GUARD
    try {
      await _assertAttendanceInTenant(attendanceId, 'createTelegramCardLink');
      final response = await supabase.functions.invoke(
        'attendix-bot',
        body: {
          'action': 'card_link',
          'attendanceId': attendanceId,
        },
      );
      final data = response.data;
      final url = data is Map ? data['url']?.toString() : null;
      if (url == null || url.isEmpty) return null;
      final uri = Uri.tryParse(url);
      if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
        return null;
      }
      return url;
    } catch (e, stack) {
      if (e is DemoModeException) rethrow;
      handleError(e, stack, 'createTelegramCardLink');
      rethrow;
    }
  }

  /// Uploads the single attachment of a Termin to the public `attendances`
  /// bucket and stores url + name on the attendance row.
  Future<({String url, String name})> uploadAttachment(
    int attendanceId,
    Uint8List bytes,
    String fileName, {
    String? previousFileName,
  }) async {
    ensureNotDemo('uploadAttachment'); // DEMO_GUARD
    try {
      await _assertAttendanceInTenant(attendanceId, 'uploadAttachment');
      // Only one attachment per Termin: drop a previous file with another
      // name so it does not stay orphaned in storage.
      if (previousFileName != null &&
          previousFileName.isNotEmpty &&
          previousFileName != fileName) {
        try {
          await supabase.storage
              .from('attendances')
              .remove([AttendanceRepository.attachmentPath(attendanceId, previousFileName)]);
        } catch (_) {
          // Old file may already be gone.
        }
      }
      final path = AttendanceRepository.attachmentPath(attendanceId, fileName);
      await supabase.storage
          .from('attendances')
          .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
      final url = supabase.storage.from('attendances').getPublicUrl(path);
      await supabase
          .from('attendance')
          .update({'attachment_url': url, 'attachment_name': fileName})
          .eq('id', attendanceId)
          .eq('tenantId', currentTenantId);
      return (url: url, name: fileName);
    } catch (e, stack) {
      handleError(e, stack, 'uploadAttachment');
      rethrow;
    }
  }

  /// Uploads the Termin photo and stores its public URL in `attendance.img`.
  Future<String> uploadAttendanceImage(int attendanceId, Uint8List bytes) async {
    ensureNotDemo('uploadAttendanceImage'); // DEMO_GUARD
    try {
      await _assertAttendanceInTenant(attendanceId, 'uploadAttendanceImage');
      final path = AttendanceRepository.attendanceImagePath(attendanceId);
      await supabase.storage.from('attendances').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = supabase.storage.from('attendances').getPublicUrl(path);
      await supabase
          .from('attendance')
          .update({'img': url})
          .eq('id', attendanceId)
          .eq('tenantId', currentTenantId);
      return url;
    } catch (e, stack) {
      handleError(e, stack, 'uploadAttendanceImage');
      rethrow;
    }
  }

  /// Removes the attachment file and clears url + name on the attendance row.
  Future<void> removeAttachment(int attendanceId, String? fileName) async {
    ensureNotDemo('removeAttachment'); // DEMO_GUARD
    try {
      await _assertAttendanceInTenant(attendanceId, 'removeAttachment');
      if (fileName != null && fileName.isNotEmpty) {
        try {
          await supabase.storage
              .from('attendances')
              .remove([AttendanceRepository.attachmentPath(attendanceId, fileName)]);
        } catch (_) {
          // File may already be gone – still clear the reference.
        }
      }
      await supabase
          .from('attendance')
          .update({'attachment_url': null, 'attachment_name': null})
          .eq('id', attendanceId)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'removeAttachment');
      rethrow;
    }
  }
  // END ATT_DETAIL
}
