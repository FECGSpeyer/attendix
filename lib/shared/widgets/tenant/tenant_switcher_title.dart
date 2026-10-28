import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/providers/tenant_providers.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/tenant/tenant.dart';
import '../../../l10n/l10n.dart';

/// AppBar title with a quick tenant switcher (Ionic people/list
/// `tenant-switcher-list` popover). Shows the current tenant's long name; if
/// the user belongs to more than one tenant, tapping opens a menu to switch.
class TenantSwitcherTitle extends ConsumerWidget {
  const TenantSwitcherTitle({super.key, this.fallbackTitle, this.singleTenantTitle});

  /// Shown when no tenant is selected yet.
  final String? fallbackTitle;

  /// SETTINGS2: title shown instead of the tenant name when the user has only
  /// one tenant (Ionic att-list shows "Termine" then).
  final String? singleTenantTitle;

  /// UX_AUTH: Ionic puts the switcher into `ion-buttons slot="start"` (left,
  /// no ion-title), so the AppBar must not centre it. Returns `false` while
  /// the switcher is shown, otherwise null (theme default: centred iOS
  /// title). Use as `AppBar(centerTitle: TenantSwitcherTitle.centerTitle(ref))`.
  static bool? centerTitle(WidgetRef ref) {
    final tenants = ref.watch(userTenantsProvider).valueOrNull ?? const [];
    return tenants.length > 1 ? false : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(currentTenantProvider);
    final tenants = ref.watch(userTenantsProvider).valueOrNull ?? const [];
    final title = tenant?.longName.isNotEmpty == true
        ? tenant!.longName
        : (tenant?.shortName ?? fallbackTitle ?? '');

    if (tenants.length <= 1) {
      return Text(singleTenantTitle ?? title, overflow: TextOverflow.ellipsis);
    }

    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final textColor = Theme.of(context).colorScheme.onSurface;
    // Ionic toolbar button: "<longName> ⌄" (chevron-down-outline at the end).
    // iOS 26 theme: the ion-buttons group is a 44 pt glass capsule.
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.keyboard_arrow_down, size: 20, color: textColor),
      ],
    );
    final trigger = ios
        ? Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xB8303032)
                  : const Color(0xB8FFFFFF),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 8,
                  spreadRadius: -2,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: label,
          )
        : label;

    return PopupMenuButton<Tenant>(
      tooltip: context.l10n.settingsSwitchTenant,
      position: PopupMenuPosition.under,
      // ion-popover style="--width: 220px", list lines="none"
      constraints: const BoxConstraints.tightFor(width: 220),
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
                        // ion-badge color="primary"
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          context.l10n.settingsCurrent,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ))
          .toList(),
      child: trigger,
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
