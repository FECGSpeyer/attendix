import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/providers/tenant_providers.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/tenant/tenant.dart';

/// AppBar title with a quick tenant switcher (Ionic people/list
/// `tenant-switcher-list` popover). Shows the current tenant's long name; if
/// the user belongs to more than one tenant, tapping opens a menu to switch.
class TenantSwitcherTitle extends ConsumerWidget {
  const TenantSwitcherTitle({super.key, this.fallbackTitle});

  /// Shown when no tenant is selected yet.
  final String? fallbackTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(currentTenantProvider);
    final tenants = ref.watch(userTenantsProvider).valueOrNull ?? const [];
    final title = tenant?.longName.isNotEmpty == true
        ? tenant!.longName
        : (tenant?.shortName ?? fallbackTitle ?? '');

    if (tenants.length <= 1) {
      return Text(title, overflow: TextOverflow.ellipsis);
    }

    return PopupMenuButton<Tenant>(
      tooltip: 'Instanz wechseln',
      position: PopupMenuPosition.under,
      onSelected: (t) => switchTenant(context, ref, t),
      itemBuilder: (context) => tenants
          .map((t) => PopupMenuItem<Tenant>(
                value: t,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.longName.isNotEmpty ? t.longName : t.shortName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (t.id == tenant?.id)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Aktuell',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ))
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
          const Icon(Icons.expand_more),
        ],
      ),
    );
  }
}

/// Switch to [tenant] and navigate to the role's default route
/// (Ionic onTenantChange: setTenant + navigate to Utils.getUrl(role)).
Future<void> switchTenant(
  BuildContext context,
  WidgetRef ref,
  Tenant tenant,
) async {
  final current = ref.read(currentTenantProvider);
  if (tenant.id == null || current?.id == tenant.id) return;

  final role = Role.fromValue(tenant.role ?? 99);
  final prefsNotifier = ref.read(userPreferencesNotifierProvider.notifier);
  final router = GoRouter.of(context);

  await ref.read(currentTenantProvider.notifier).setTenantLocal(tenant);
  // Wait for the role of the new tenant so the router does not redirect back
  await ref.read(currentTenantUserProvider.future);

  router.go(role.defaultRoute);
  prefsNotifier.updateCurrentTenantId(tenant.id!);
}
