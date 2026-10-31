import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../data/models/organisation/organisation.dart';
import '../../data/models/plan/plan.dart';
import 'plan_utils.dart';

/// "Beamer-Datei nötig" for Ablaufplan rows (Gemeinde App link, FECG Speyer
/// and FECG Schwegenheim only). Port of Ionic `utilities/plan-beamer.ts`;
/// the same rule lives in the `fecg-bridge` edge function.
class PlanBeamer {
  PlanBeamer._();

  /// Titles with these words need a Beamer file unless switched off by hand.
  static final RegExp _autoWords = RegExp('lied|gedicht', caseSensitive: false);

  /// The org may use the Gemeinde App link at all (database flag, no UI).
  static bool gemeindeAppLinked(Organisation? org) => org?.fecgLinkEnabled ?? false;

  /// Beamer rows are shown: org linked, setting on and the plan is an ORG plan.
  static bool active(Organisation? org, bool isOrgPlan) =>
      gemeindeAppLinked(org) && (org?.beamerFilesEnabled ?? false) && isOrgPlan;

  /// Notes, Programmblock heads and the agenda marker never need a file.
  static bool canNeedBeamer(PlanField field) =>
      !PlanUtils.isNote(field) && !PlanUtils.isGroupHead(field) && !PlanUtils.isAgendaPlaceholder(field);

  /// Default when nobody switched it: Werke and titles with "Lied" or "Gedicht".
  static bool autoNeedsBeamer({required String name, int? songId}) =>
      songId != null || _autoWords.hasMatch(name);

  static bool needsBeamer(PlanField field) {
    if (!canNeedBeamer(field)) return false;
    return field.needsBeamer ?? autoNeedsBeamer(name: field.name, songId: field.songId);
  }

  /// Why the switch is on by itself (Ionic `autoReason`): null when switched
  /// by hand ([manual] set) or off; otherwise `song: true` for a Werk or the
  /// word found in the title.
  static ({bool song, String? word})? autoReason({required String name, int? songId, bool? manual}) {
    if (manual != null || !autoNeedsBeamer(name: name, songId: songId)) return null;
    if (songId != null) return (song: true, word: null);
    final lower = name.toLowerCase();
    return (song: false, word: lower.contains('gedicht') && !lower.contains('lied') ? 'Gedicht' : 'Lied');
  }

  /// File linked in the Gemeinde App: at the row, otherwise the one stored
  /// with its Werk ([songFile], Ionic 4.17.11 `beamerFileOf`).
  static BeamerFile? fileOf(PlanField field, BeamerFile? Function(int songId)? songFile) {
    if (field.beamerFile != null) return field.beamerFile;
    final songId = field.songId;
    return songId != null ? songFile?.call(songId) : null;
  }

  /// Gives every row a unique uid so the Gemeinde App can link files to it.
  /// Returns the same list when nothing changed; a repeated uid comes from a
  /// copied row, so the copy loses its file.
  static List<PlanField> ensureFieldUids(List<PlanField> fields, {String Function()? newUid}) {
    final makeUid = newUid ?? PlanUtils.uuid;
    final seen = <String>{};
    var changed = false;
    final result = fields.map((field) {
      final uid = field.uid;
      if (uid != null && uid.isNotEmpty && !seen.contains(uid)) {
        seen.add(uid);
        return field;
      }
      changed = true;
      final fresh = makeUid();
      seen.add(fresh);
      return uid != null && uid.isNotEmpty ? field.copyWith(uid: fresh, beamerFile: null) : field.copyWith(uid: fresh);
    }).toList();
    return changed ? result : fields;
  }

  /// New Gemeinde App connection key (Ionic org-settings
  /// `createGemeindeAppKey`): `atx_` + 24 random bytes as hex. Only the
  /// SHA-256 [hash] (hex) and the last four characters ([hint]) are stored.
  static ({String key, String hash, String hint}) newGemeindeAppKey([Random? random]) {
    final rnd = random ?? Random.secure();
    final hex = List.generate(24, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final key = 'atx_$hex';
    return (key: key, hash: gemeindeAppKeyHash(key), hint: key.substring(key.length - 4));
  }

  /// SHA-256 of [key] as lowercase hex (what `fecg-bridge` compares).
  static String gemeindeAppKeyHash(String key) => sha256.convert(utf8.encode(key)).toString();
}
