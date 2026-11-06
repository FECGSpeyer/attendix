import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/auto_message_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../data/models/auto_message/auto_message.dart';
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

/// Own row of a Termin in a group of the user.
typedef RdOwnResponseKey = ({int tenantId, String personAttendanceId});

/// The Termin message a member can answer ("Grund nachtragen", "Ich war
/// doch da") and their answer so far.
class RdOwnResponseInfo {
  const RdOwnResponseInfo({required this.messageId, this.own});

  final String messageId;
  final AttendanceResponse? own;
}

/// Answering works in the current group only (like the message itself);
/// null elsewhere or without such a message.
final rdOwnResponseInfoProvider =
    FutureProvider.autoDispose.family<RdOwnResponseInfo?, RdOwnResponseKey>((ref, key) async {
  ref.watch(currentAuthUserIdProvider);
  if (ref.watch(currentTenantIdProvider) != key.tenantId) return null;
  final repo = ref.watch(autoMessageRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return null;
  final messageId = await repo.getOwnRespondableMessageId(key.personAttendanceId);
  if (messageId == null) return null;
  final own = await repo.getOwnResponse(key.personAttendanceId);
  return RdOwnResponseInfo(messageId: messageId, own: own);
});
