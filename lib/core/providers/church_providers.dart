import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/church/church.dart';
import '../../data/repositories/church_repository.dart';
import '../config/supabase_config.dart';
import '../utils/global_toast.dart';
import '../../l10n/l10n.dart';

/// Provider for all churches (global)
final churchesProvider = FutureProvider<List<Church>>((ref) async {
  final repo = ref.watch(churchRepositoryProvider);
  try {
    return await repo.getChurches();
  } catch (_) {
    // Ionic ChurchService.getChurches: toast wherever the list fails.
    GlobalToast.error(l10nWithoutContext.svcLoadChurchesFailed);
    rethrow;
  }
});

/// Notifier for church mutations
class ChurchNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  ChurchRepository get _repo => ref.read(churchRepositoryProvider);

  /// Create a new church
  Future<String?> createChurch(String name) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;
      final result = await _repo.createChurch(name, userId: userId);
      state = const AsyncValue.data(null);
      ref.invalidate(churchesProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
}

final churchNotifierProvider =
    NotifierProvider<ChurchNotifier, AsyncValue<void>>(() {
  return ChurchNotifier();
});
