import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/providers/debug_providers.dart';
import '../../../core/providers/push_providers.dart';
import '../../../core/providers/redesign_providers.dart';
import '../../../core/providers/tenant_providers.dart';
import '../../../core/router/redesign_routes.dart';
import '../../../core/utils/dashboard_logic.dart' show homeRouteFor;

/// REDESIGN: Abmelden, same steps as the settings page (no confirmation,
/// like Ionic).
Future<void> rdLogout(BuildContext context, WidgetRef ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final tenantNotifier = ref.read(currentTenantProvider.notifier);
  await removePushTokenBeforeSignOut(ref);
  await supabase.auth.signOut();
  await tenantNotifier.clearTenant();
  if (context.mounted) context.go('/login');
}

/// Switches "Neues Design (Beta)" on or off and opens the start page of
/// the chosen design ("Heute", or the old start page of the role).
Future<void> rdSetRedesignEnabled(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  final router = GoRouter.of(context);
  await ref.read(redesignSettingsProvider.notifier).setEnabled(enabled);
  final target = enabled
      ? RedesignRoutes.today
      : homeRouteFor(
          ref.read(effectiveRoleProvider),
          ref.read(currentTenantProvider)?.id,
          ref.read(supabaseClientProvider).auth.currentUser?.userMetadata,
        );
  router.go(target);
}
