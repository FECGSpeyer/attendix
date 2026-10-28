/// Cross-cutting analytics events written to Supabase `usage_events`.
///
/// Wire-format strings MUST match Ionic v4.0.5
/// (`src/app/services/tracking/tracking.service.ts:6-44`) exactly — the
/// super-developer dashboard queries `event_name` by string.
enum TrackingEvent {
  pageView('page_view'),
  login('login'),
  attendanceCheckIn('attendance_check_in'),
  attendanceCheckOut('attendance_check_out'),
  parentSignIn('parent_signin'),
  parentSignOut('parent_signout'),
  pushReceived('push_received'),
  pushOpened('push_opened'),
  songShared('song_shared'),
  reportExported('report_exported'),
  handoverCreated('handover_created'),
  playerAdded('player_added'),
  playerUpdated('player_updated'),
  playerRemoved('player_removed'),
  teacherAdded('teacher_added'),
  teacherUpdated('teacher_updated'),
  instrumentAdded('instrument_added'),
  instrumentUpdated('instrument_updated'),
  instrumentRemoved('instrument_removed'),
  notificationSettingsChanged('notification_settings_changed'),
  fileUploaded('file_uploaded'),
  accountDeleted('account_deleted'),
  attendanceFetchAttempt('attendance_fetch_attempt'),
  attendanceFetchStageB('attendance_fetch_stage_b'),
  attendanceFetchResolved('attendance_fetch_resolved'),
  attendanceFetchModifyThrow('attendance_fetch_modify_throw'),
  attendanceTypeUnresolved('attendance_type_unresolved'),
  attendanceSecondaryInitFailed('attendance_secondary_init_failed');

  const TrackingEvent(this.wireName);

  /// snake_case string written to `usage_events.event_name`.
  final String wireName;
}
