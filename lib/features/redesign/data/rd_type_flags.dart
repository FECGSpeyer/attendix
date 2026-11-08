import '../../../core/providers/attendance_type_providers.dart';
import '../../../core/services/error_reporter.dart';
import '../../../data/models/attendance/attendance.dart';

/// Beta: Ort and Werke can be added at every Termin; the type has no
/// switches for them any more. When a Termin gets a place or Werke and its
/// type still has `place_enabled` / `manage_songs` off, they are switched
/// on, so the Ionic app shows them too. Returns the type with the flags on
/// (also when the update failed: the Termin keeps what was entered).
Future<AttendanceType> rdEnsureTypeFlags(
  AttendanceTypeNotifier notifier,
  AttendanceType type, {
  bool place = false,
  bool songs = false,
  void Function()? onFailed,
}) async {
  final updates = <String, dynamic>{
    if (place && !type.placeEnabled) 'place_enabled': true,
    if (songs && !type.manageSongs) 'manage_songs': true,
  };
  final id = type.id;
  if (updates.isEmpty || id == null) return type;
  var saved = false;
  // One retry: the Termin itself is already saved, only the Art's switch
  // is missing (the old app would hide the place / the Werke).
  for (var attempt = 0; attempt < 2 && !saved; attempt++) {
    try {
      saved = await notifier.updateType(id, updates) != null;
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'rdEnsureTypeFlags');
    }
  }
  if (!saved) onFailed?.call();
  return type.copyWith(
    placeEnabled: type.placeEnabled || place,
    manageSongs: type.manageSongs || songs,
  );
}

/// Beta "Für neue Termine dieser Art übernehmen": the Ablauf of a Termin
/// ([fields], stored rows) as the template of its Art. Werke of this
/// Termin become Werk placeholders (new Termine fill in their own Werke),
/// the Tagesordnung items become the one agenda marker, and per-Termin
/// data (Dirigent, actual time, Beamer file) is left out.
List<Map<String, dynamic>> rdPlanAsTypeTemplate(
  List<Map<String, dynamic>> fields, {
  required String Function(int n) songPlaceholderName,
  required Map<String, dynamic> Function() agendaMarker,
  required String agendaMarkerId,
}) {
  const keep = {'id', 'name', 'time', 'info', 'isGroup', 'groupId'};
  final result = <Map<String, dynamic>>[];
  var songs = 0;
  var agenda = false;
  for (final f in fields) {
    final id = f['id']?.toString() ?? '';
    if (f['agendaItemId'] != null || id == agendaMarkerId) {
      if (!agenda) {
        agenda = true;
        result.add({...agendaMarker(), if (f['groupId'] != null) 'groupId': f['groupId']});
      }
      continue;
    }
    if (f['songId'] != null || id.startsWith('song-placeholder-')) {
      songs++;
      result.add({
        'id': 'song-placeholder-$songs',
        'name': songPlaceholderName(songs),
        'time': f['time']?.toString() ?? '20',
        // Stays in its Block.
        if (f['groupId'] != null) 'groupId': f['groupId'],
      });
      continue;
    }
    result.add({
      for (final e in f.entries)
        if (keep.contains(e.key) && e.value != null) e.key: e.value,
    });
  }
  return result;
}
