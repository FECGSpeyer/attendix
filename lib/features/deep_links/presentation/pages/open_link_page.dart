import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/router/legacy_routes.dart';
import '../../../../core/utils/dashboard_logic.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// LINKS_STARTUP: resolves the tenant for an in-app link before opening it.
///
/// Used for
/// * `?tenantId=` on in-app links (Ionic att-list / attendance pages call
///   `db.setTenant(tenantId)` first – push, mail and Telegram links rely on
///   it, e.g. `/tabs/list?tenantId=`),
/// * cold starts / reloads on an in-app URL while no tenant is selected yet
///   (Ionic restores the stored tenant before the tab page loads).
///
/// Picks the link's tenant (if the user belongs to it), otherwise the current
/// / stored / first tenant, waits for the role and then opens [target] or the
/// role's home page. The router's role checks still apply to [target].
class OpenLinkPage extends ConsumerStatefulWidget {
  const OpenLinkPage({super.key, this.target, this.tenantId});

  final String? target;
  final String? tenantId;

  @override
  ConsumerState<OpenLinkPage> createState() => _OpenLinkPageState();
}

class _OpenLinkPageState extends ConsumerState<OpenLinkPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final linkTenantId = int.tryParse(widget.tenantId ?? '');
    try {
      final current = ref.read(currentTenantProvider);
      final needsSwitch = current == null ||
          (linkTenantId != null && linkTenantId != current.id);
      if (needsSwitch) {
        final tenants = await ref.read(userTenantsProvider.future);
        final storedId = ref.read(userPreferencesProvider).currentTenantId;
        final tenant = tenants.where((t) => t.id == linkTenantId).firstOrNull ??
            current ??
            tenants.where((t) => t.id == storedId).firstOrNull ??
            tenants.firstOrNull;
        if (tenant != null && tenant.id != current?.id) {
          // Explicit link tenant: persist like a manual switch (Ionic setTenant)
          if (tenant.id == linkTenantId) {
            await ref.read(currentTenantProvider.notifier).setTenant(tenant);
          } else {
            await ref.read(currentTenantProvider.notifier).setTenantLocal(tenant);
          }
        }
      }
    } catch (_) {
      // Fall back to whatever tenant is selected.
    }

    Role role = Role.none;
    try {
      final tenantUser = await ref.read(currentTenantUserProvider.future);
      role = tenantUser?.roleEnum ?? Role.none;
    } catch (_) {}
    if (!mounted) return;

    final tenant = ref.read(currentTenantProvider);
    if (tenant == null) {
      context.go('/tenants');
      return;
    }
    final target = sanitizeOpenLinkTarget(widget.target);
    context.go(
      target ??
          homeRouteFor(
            role,
            tenant.id,
            ref.read(supabaseAuthProvider).currentUser?.userMetadata,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: AppSpinner()));
  }
}
