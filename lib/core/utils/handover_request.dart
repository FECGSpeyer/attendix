import '../../data/models/person/person.dart';
import '../../data/models/tenant/tenant.dart';
import '../constants/enums.dart';

/// Key in `player.additional_fields` that marks a person another group of
/// the organisation wants to hand over ("Übergabe als Anfrage").
///
/// Whoever hands over without being Admin or Verantwortliche of the target
/// group does not add the person there any more: the target gets a waiting
/// row (pending, so it shows in Freigaben) with this marker. Only when a
/// lead of the target group approves it, the account gets access there (the
/// "hinzugefügt" mail goes out then, sent by somebody who may send it) and
/// the source group is updated (history; `left` when the person moves
/// completely). Declined: the waiting row is removed, the source keeps the
/// person. The waiting row carries no `appId` (the account is linked on
/// approval). The marker only says where to look: account and "stays /
/// moves" are read from the source person itself, which must carry the
/// asking group's own history note. No DB schema change is needed for this.
const String kHandoverRequestKey = '_handover_request';

/// Where a waiting handover comes from.
class HandoverRequest {
  const HandoverRequest({
    required this.fromTenantId,
    required this.fromTenantName,
    required this.fromPersonId,
    required this.keep,
    this.by = '',
  });

  final int fromTenantId;
  final String fromTenantName;

  /// The person's row in the source group.
  final int fromPersonId;

  /// The person stays active in the source group too ("Bleiben auch hier").
  /// Only for display: what really happens at the source is read from the
  /// source group's own history note on approval, like the account.
  final bool keep;

  /// E-mail of who asked.
  final String by;

  Map<String, dynamic> toJson() => {
        'fromTenantId': fromTenantId,
        'fromTenantName': fromTenantName,
        'fromPersonId': fromPersonId,
        'keep': keep,
        if (by.isNotEmpty) 'by': by,
      };

  /// Reads the marker from `additional_fields`; null when it is missing or
  /// malformed.
  static HandoverRequest? fromAdditionalFields(Map<String, dynamic>? fields) {
    final raw = fields?[kHandoverRequestKey];
    if (raw is! Map) return null;
    final tenantId = raw['fromTenantId'];
    final personId = raw['fromPersonId'];
    if (tenantId is! num || personId is! num) return null;
    // The marker is plain JSON anybody of the group can write: wrong types
    // count as missing instead of breaking the Freigaben pages.
    String text(Object? v) => v is String ? v.trim() : '';
    return HandoverRequest(
      fromTenantId: tenantId.toInt(),
      fromTenantName: text(raw['fromTenantName']),
      fromPersonId: personId.toInt(),
      keep: raw['keep'] == true,
      by: text(raw['by']),
    );
  }
}

/// The handover marker of [person] (a waiting person), or null.
HandoverRequest? handoverRequestOf(Person person) =>
    person.pending ? HandoverRequest.fromAdditionalFields(person.additionalFields) : null;

/// [fields] without the handover marker (written on approval).
Map<String, dynamic> withoutHandoverRequest(Map<String, dynamic>? fields) =>
    {...?fields}..remove(kHandoverRequestKey);

/// Whether a handover to [targetTenantId] goes there as a request: always,
/// unless the viewer is Admin or Verantwortliche of that group (then the
/// viewer would only ask themselves). [tenants] are the viewer's own groups
/// with their role; unknown counts as "no lead there".
bool handoverNeedsRequest({required List<Tenant>? tenants, required int targetTenantId}) {
  final role = tenants?.where((t) => t.id == targetTenantId).firstOrNull?.role;
  if (role == null) return true;
  final r = Role.fromValue(role);
  return !(r.isAdmin || r.isResponsible);
}
