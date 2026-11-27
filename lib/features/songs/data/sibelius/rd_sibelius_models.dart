part of 'rd_sibelius_sync.dart';

/// "In Sibelius bearbeiten" (and "In Word bearbeiten") exist only in the
/// Mac app (the app may open files in other apps and see their saves).
bool get rdSibeliusSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// How often the copies are compared while any is open.
const Duration rdSibeliusPollInterval = Duration(seconds: 3);

/// How long a save must stay unchanged before it is uploaded (Sibelius
/// writes it in several steps), and how long no part may be added before the
/// parts are offered (Sibelius exports one part after the other).
const Duration rdSibeliusSaveSettle = Duration(seconds: 3);
const Duration rdSibeliusPartsSettle = Duration(seconds: 6);

/// The plug-in brings Attendix to the front (or starts it) once all parts are
/// written: parts written shortly before that moment are offered at once.
const Duration rdSibeliusBroughtToFront = Duration(seconds: 30);

const String _prefsKey = 'rd_sibelius_state_v1';

/// What happened with a save in Sibelius (shown as a toast).
sealed class RdSibeliusEvent {
  const RdSibeliusEvent(this.fileName);
  final String fileName;
}

/// The new content replaced the file in Attendix; [afterRetry]: only now, after
/// tries that failed (offline).
class RdSibeliusSaved extends RdSibeliusEvent {
  const RdSibeliusSaved(super.fileName, {this.afterRetry = false});
  final bool afterRetry;
}

/// The file changed in Attendix meanwhile: the save was added as [copyName].
class RdSibeliusSavedAsCopy extends RdSibeliusEvent {
  const RdSibeliusSavedAsCopy(super.fileName, this.copyName);
  final String copyName;
}

/// The upload failed: the save is on the Mac only and is uploaded by itself
/// later (shown once, not for every further try).
class RdSibeliusSaveFailed extends RdSibeliusEvent {
  const RdSibeliusSaveFailed(super.fileName, this.error);
  final Object error;
}

/// The Werk was deleted in Attendix: the copy is not kept in step any more
/// (it stays in Downloads › Attendix).
class RdSibeliusWorkGone extends RdSibeliusEvent {
  const RdSibeliusWorkGone(super.fileName);
}

/// The plug-in brought Attendix to the front with new [parts]; [fileName] is
/// their folder. Shown on the Werk page (opened if another page is shown).
class RdSibeliusPartsReady extends RdSibeliusEvent {
  RdSibeliusPartsReady(this.parts) : super(parts.folder);
  final RdSibeliusParts parts;
}

class RdSibeliusState {
  const RdSibeliusState({this.parts = const {}, this.waiting = const []});

  /// Exported parts per parts folder, waiting for their Werk page.
  final Map<String, RdSibeliusParts> parts;

  /// Copies whose last save is only on the Mac so far (upload failed, tried
  /// again by itself).
  final List<RdSibeliusCheckout> waiting;

  bool isWaiting(int tenantId, int songId, SongFile file) => waiting.any((c) => c.matches(tenantId, songId, file));

  RdSibeliusState copyWith({Map<String, RdSibeliusParts>? parts, List<RdSibeliusCheckout>? waiting}) =>
      RdSibeliusState(parts: parts ?? this.parts, waiting: waiting ?? this.waiting);

  RdSibeliusParts? partsFor(int tenantId, int songId) {
    for (final p in parts.values) {
      if (p.tenantId == tenantId && p.songId == songId) return p;
    }
    return null;
  }
}

/// Result of [RdSibeliusSync.edit].
enum RdSibeliusOpen { opened, noFolder, notOpened }
