import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';
import '../utils/demo_guard.dart';

/// DEMO_GUARD: Ionic `db.isDemo()` — true when the signed-in user is the
/// demo account (`DEMO_EMAIL`). Rebuilds on auth changes.
final isDemoProvider = Provider<bool>((ref) {
  final streamed = ref.watch(currentUserProvider).valueOrNull;
  String? email = streamed?.email;
  if (email == null) {
    try {
      email = ref.watch(supabaseClientProvider).auth.currentUser?.email;
    } catch (_) {
      email = null;
    }
  }
  return DemoGuard.isDemoEmail(email);
});
