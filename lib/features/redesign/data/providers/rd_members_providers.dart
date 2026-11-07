import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart' show currentAuthUserIdProvider;
import '../../../../core/providers/tenant_providers.dart';

/// REDESIGN (UX D3): "Fehlen oft" filter of the Mitglieder tab. A provider
/// and not page state, so "Heute" can open the tab already filtered.
final rdMembersCriticalOnlyProvider = StateProvider<bool>((ref) {
  // Starts unfiltered in another group or account.
  ref.watch(currentTenantIdProvider);
  ref.watch(currentAuthUserIdProvider);
  return false;
});
