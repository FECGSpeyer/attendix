import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// User preferences stored in Supabase user_metadata
/// Used for cross-device sync of settings like last selected tenant
class UserPreferences {
  final int? currentTenantId;
  final bool wantInstanceSelection;

  const UserPreferences({
    this.currentTenantId,
    this.wantInstanceSelection = false,
  });

  factory UserPreferences.fromUserMetadata(Map<String, dynamic>? metadata) {
    return UserPreferences(
      currentTenantId: metadata?['currentTenantId'] as int?,
      wantInstanceSelection:
          metadata?['wantInstanceSelection'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMetadata() {
    return {
      'currentTenantId': currentTenantId,
      'wantInstanceSelection': wantInstanceSelection,
    };
  }

  UserPreferences copyWith({
    int? currentTenantId,
    bool? wantInstanceSelection,
  }) {
    return UserPreferences(
      currentTenantId: currentTenantId ?? this.currentTenantId,
      wantInstanceSelection:
          wantInstanceSelection ?? this.wantInstanceSelection,
    );
  }
}

/// Provider for reading user preferences from current user's metadata
final userPreferencesProvider = Provider<UserPreferences>((ref) {
  // SOL_FIX14: per-user data – reload when the account changes.
  ref.watch(currentAuthUserIdProvider);
  final auth = ref.watch(supabaseAuthProvider);
  final user = auth.currentUser;
  return UserPreferences.fromUserMetadata(user?.userMetadata);
});

/// "Instanzauswahl aktivieren" value wanted by the user while a write is
/// pending (null: no write pending, show the stored value). Set only by
/// [UserPreferencesNotifier.setWantInstanceSelection].
final wantedInstanceSelectionProvider = StateProvider<bool?>((ref) => null);

/// Notifier for updating user preferences in Supabase user_metadata
class UserPreferencesNotifier extends AsyncNotifier<void> {
  /// Running write loop for wantInstanceSelection (null: idle).
  Future<void>? _instanceSelectionWrite;

  @override
  Future<void> build() async {}

  /// Ionic ngModel: every toggle change is written (settings.page.ts
  /// onTenantSelectionChange). Writes are serialized here, not in the widget,
  /// so they survive closing and reopening the sheet: only one runs at a time
  /// and afterwards the latest wanted value is written once if it differs, so
  /// an older write can't finish last. The returned future is the shared write
  /// loop; it throws if a write fails (the stored value is shown again).
  Future<void> setWantInstanceSelection(bool value) {
    ref.read(wantedInstanceSelectionProvider.notifier).state = value;
    return _instanceSelectionWrite ??= _writeInstanceSelection();
  }

  Future<void> _writeInstanceSelection() async {
    final wanted = ref.read(wantedInstanceSelectionProvider.notifier);
    try {
      bool written;
      do {
        written = wanted.state!;
        await updatePreferences(wantInstanceSelection: written);
      } while (wanted.state != written);
    } finally {
      _instanceSelectionWrite = null;
      wanted.state = null;
    }
  }

  /// Update user preferences in Supabase user_metadata
  Future<void> updatePreferences({
    int? currentTenantId,
    bool? wantInstanceSelection,
  }) async {
    state = const AsyncLoading();

    try {
      final auth = ref.read(supabaseAuthProvider);
      final currentMetadata = auth.currentUser?.userMetadata ?? {};

      // Merge new values with existing metadata
      final updatedData = <String, dynamic>{
        ...currentMetadata,
        if (currentTenantId != null) 'currentTenantId': currentTenantId,
        if (wantInstanceSelection != null)
          'wantInstanceSelection': wantInstanceSelection,
      };

      await auth.updateUser(UserAttributes(data: updatedData));
      // userPreferencesProvider only depends on the user id, which does not
      // change on updateUser – re-read the metadata explicitly.
      ref.invalidate(userPreferencesProvider);
      state = const AsyncData(null);
    } catch (e, stack) {
      debugPrint('Failed to update user preferences: $e');
      state = AsyncError(e, stack);
      rethrow;
    }
  }

  /// Update current tenant ID (fire and forget - does not throw)
  void updateCurrentTenantId(int tenantId) {
    final auth = ref.read(supabaseAuthProvider);
    final currentMetadata = auth.currentUser?.userMetadata ?? {};

    // Don't update if already the same
    if (currentMetadata['currentTenantId'] == tenantId) return;

    auth
        .updateUser(
          UserAttributes(
            data: {
              ...currentMetadata,
              'currentTenantId': tenantId,
            },
          ),
        )
        .then((_) {})
        .catchError((Object e) {
          debugPrint('Failed to sync tenant to user_metadata: $e');
        });
  }

  /// Clear current tenant ID from user_metadata
  void clearCurrentTenantId() {
    final auth = ref.read(supabaseAuthProvider);
    final currentMetadata = auth.currentUser?.userMetadata ?? {};

    // Remove the key by setting to null
    auth
        .updateUser(
          UserAttributes(
            data: {
              ...currentMetadata,
              'currentTenantId': null,
            },
          ),
        )
        .then((_) {})
        .catchError((Object e) {
          debugPrint('Failed to clear tenant from user_metadata: $e');
        });
  }
}

/// Provider for the UserPreferencesNotifier
final userPreferencesNotifierProvider =
    AsyncNotifierProvider<UserPreferencesNotifier, void>(
  UserPreferencesNotifier.new,
);
