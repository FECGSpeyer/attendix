import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/player_providers.dart';
import '../../../../core/utils/parent_registration.dart';
import '../../../../l10n/l10n.dart';
import '../../../profile/presentation/widgets/profile_helpers.dart' show profileRoleName;

/// Freigaben hint under the Elternteil of a "Mein Kind" registration (U9):
/// a new account becomes Elternteil; an account that is already in the
/// group with its own role keeps it and gets the child linked (U9b).
String parentReviewHint(WidgetRef ref, AppLocalizations l10n, ParentRegistration parent) {
  final role = ref.watch(parentRegistrationRoleProvider(parent.appId)).valueOrNull;
  if (keepsOwnRole(role)) {
    return l10n.parentRegisterReviewParentMemberHint(parent.firstName, profileRoleName(role!));
  }
  return l10n.parentRegisterReviewParentHint(parent.firstName);
}
