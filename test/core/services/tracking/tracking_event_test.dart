import 'package:attendix/core/services/tracking/tracking_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrackingEvent', () {
    test('exposes all event names from Ionic (no Flutter-only events)', () {
      expect(TrackingEvent.values.length, 28);
    });

    test('wireName matches Ionic snake_case strings', () {
      expect(TrackingEvent.pageView.wireName, 'page_view');
      expect(TrackingEvent.login.wireName, 'login');
      expect(TrackingEvent.attendanceCheckIn.wireName, 'attendance_check_in');
      expect(TrackingEvent.attendanceCheckOut.wireName, 'attendance_check_out');
      expect(TrackingEvent.parentSignIn.wireName, 'parent_signin');
      expect(TrackingEvent.parentSignOut.wireName, 'parent_signout');
      expect(TrackingEvent.pushReceived.wireName, 'push_received');
      expect(TrackingEvent.pushOpened.wireName, 'push_opened');
      expect(TrackingEvent.songShared.wireName, 'song_shared');
      expect(TrackingEvent.reportExported.wireName, 'report_exported');
      expect(TrackingEvent.handoverCreated.wireName, 'handover_created');
      expect(TrackingEvent.playerAdded.wireName, 'player_added');
      expect(TrackingEvent.playerUpdated.wireName, 'player_updated');
      expect(TrackingEvent.playerRemoved.wireName, 'player_removed');
      expect(TrackingEvent.teacherAdded.wireName, 'teacher_added');
      expect(TrackingEvent.teacherUpdated.wireName, 'teacher_updated');
      expect(TrackingEvent.instrumentAdded.wireName, 'instrument_added');
      expect(TrackingEvent.instrumentUpdated.wireName, 'instrument_updated');
      expect(TrackingEvent.instrumentRemoved.wireName, 'instrument_removed');
      expect(
        TrackingEvent.notificationSettingsChanged.wireName,
        'notification_settings_changed',
      );
      expect(TrackingEvent.fileUploaded.wireName, 'file_uploaded');
      expect(TrackingEvent.accountDeleted.wireName, 'account_deleted');
      expect(
        TrackingEvent.attendanceFetchAttempt.wireName,
        'attendance_fetch_attempt',
      );
      expect(
        TrackingEvent.attendanceFetchStageB.wireName,
        'attendance_fetch_stage_b',
      );
      expect(
        TrackingEvent.attendanceFetchResolved.wireName,
        'attendance_fetch_resolved',
      );
      expect(
        TrackingEvent.attendanceFetchModifyThrow.wireName,
        'attendance_fetch_modify_throw',
      );
      expect(
        TrackingEvent.attendanceTypeUnresolved.wireName,
        'attendance_type_unresolved',
      );
      expect(
        TrackingEvent.attendanceSecondaryInitFailed.wireName,
        'attendance_secondary_init_failed',
      );
    });
  });
}
