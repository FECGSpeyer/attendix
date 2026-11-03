import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../data/repositories/sign_in_out_repository.dart';
import '../rd_event_details_logic.dart';

/// Werke of an own Termin of a Spieler (any of the user's groups).
typedef RdOwnProgramKey = ({int tenantId, int attendanceId, int? personId});

/// The Programm of an own Termin, the Spieler's group there and the
/// group's tenant type.
class RdOwnProgram {
  const RdOwnProgram({required this.items, this.instrumentId, this.tenantType});

  final List<RdProgramItem> items;
  final int? instrumentId;
  final String? tenantType;

  /// "Chor (alle)" scores count as own scores.
  bool get isChoir => tenantType == 'choir';

  /// Groups of type "general" have no Werke (Ionic `!isGeneral`).
  bool get usesWorks => tenantType != 'general';
}

final rdOwnProgramProvider =
    FutureProvider.autoDispose.family<RdOwnProgram, RdOwnProgramKey>((ref, key) async {
  // Never keep another account's Programm after an account switch.
  ref.watch(currentAuthUserIdProvider);
  final repo = ref.watch(signInOutRepositoryProvider);
  final result = await repo.getOwnProgram(
    tenantId: key.tenantId,
    attendanceId: key.attendanceId,
    personId: key.personId,
  );
  return RdOwnProgram(
    items: rdProgramItems(result.rows),
    instrumentId: result.instrumentId,
    tenantType: result.tenantType,
  );
});
