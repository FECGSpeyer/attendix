import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/providers/tenant_providers.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/tenant/tenant.dart';
import '../../../l10n/l10n.dart';
import '../adaptive/adaptive_platform.dart'; // IOS_SHELL

/// AppBar title with a quick tenant switcher (Ionic people/list
/// `tenant-switcher-list` popover). Shows the current tenant's long name; if
/// the user belongs to more than one tenant, tapping opens a menu to switch.
class TenantSwitcherTitle extends ConsumerWidget {
  const TenantSwitcherTitle({
    super.key,
    this.fallbackTitle,
    this.singleTenantTitle,
    this.onSelected,
  });

  /// Shown when no tenant is selected yet.
  final String? fallbackTitle;

  /// SETTINGS2: title shown instead of the tenant name when the user has only
  /// one tenant (Ionic att-list shows "Termine" then).
  final String? singleTenantTitle;

  /// IOS_SHELL: custom switch handler (default: [switchTenant]).
  final ValueChanged<Tenant>? onSelected;

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

    final ios = useIosLook(context);
    final textColor = Theme.of(context).colorScheme.onSurface;
    // Ionic toolbar button: "<longName> ⌄" (chevron-down-outline at the end).
    // iOS 26 theme: the ion-buttons group is a 44 pt glass capsule.
    // IOS_THEME2: md = Ionic md toolbar ion-button – UPPERCASE 14pt
    // medium in the toolbar colour ("CHOR ⌄").
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            ios ? title : title.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ios ? 17 : 14,
              fontWeight: FontWeight.w500,
              letterSpacing: ios ? null : 0.84,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.keyboard_arrow_down, size: 20, color: textColor),
      ],
    );
    final trigger = ios
        // IOS_SHELL: same Liquid Glass capsule as ToolbarButtonGroup.
        ? IosGlassSurface(
            borderRadius: const BorderRadius.all(Radius.circular(22)),
            blur: 2,
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(widthFactor: 1, child: label),
              ),
            ),
          )
        : label;

    void select(Tenant t) => onSelected != null
        ? onSelected!(t)
        : switchTenant(context, ref, t);

    if (ios) {
      // IOS_SHELL: Ionic iOS `ion-popover` (trigger click, --width 220px).
      // IOS_R4: ionic-theme-ios26/27 "replace" popover – it opens on top of
      // the glass capsule (same top-left corner) while the capsule fades out.
      return Semantics(
        button: true,
        label: context.l10n.settingsSwitchTenant,
        child: _IosPopoverTrigger(
          onOpen: (triggerContext) => showIosTenantPopover(
            triggerContext,
            tenants: tenants,
            currentTenantId: tenant?.id,
          ),
          onSelected: select,
          child: trigger,
        ),
      );
    }

    return PopupMenuButton<Tenant>(
      tooltip: context.l10n.settingsSwitchTenant,
      position: PopupMenuPosition.under,
      // ion-popover style="--width: 220px", list lines="none"
      constraints: const BoxConstraints.tightFor(width: 220),
      onSelected: select,
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

/// IOS_R4: the capsule that opens the tenant popover; hidden while the
/// popover (which replaces it, Ionic `ios-theme-replace-element`) is open.
class _IosPopoverTrigger extends StatefulWidget {
  const _IosPopoverTrigger({
    required this.onOpen,
    required this.onSelected,
    required this.child,
  });

  final Future<Tenant?> Function(BuildContext context) onOpen;
  final ValueChanged<Tenant> onSelected;
  final Widget child;

  @override
  State<_IosPopoverTrigger> createState() => _IosPopoverTriggerState();
}

class _IosPopoverTriggerState extends State<_IosPopoverTrigger> {
  bool _open = false;

  Future<void> _tap() async {
    setState(() => _open = true);
    final picked = await widget.onOpen(context);
    if (!mounted) return;
    setState(() => _open = false);
    if (picked != null) widget.onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _open ? null : _tap,
      child: AnimatedOpacity(
        opacity: _open ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        child: widget.child,
      ),
    );
  }
}

/// IOS_SHELL: the tenant switcher `ion-popover` of the Ionic headers in iOS
/// mode (iOS 26 theme): a 220pt wide glass card with 24pt corners placed
/// over [context]'s widget (IOS_R4: top-left corner = the capsule's, like
/// the theme's "replace" popover for toolbar buttons), dimmed backdrop
/// (0.2), one `ion-item` per instance (long name, Ionic order) and a primary
/// "Aktuell" badge on the current one.
/// Resolves with the tapped tenant (`dismissOnSelect`) or null.
Future<Tenant?> showIosTenantPopover(
  BuildContext context, {
  required List<Tenant> tenants,
  int? currentTenantId,
}) {
  final box = context.findRenderObject() as RenderBox?;
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlayBox =
      navigator.overlay?.context.findRenderObject() as RenderBox?;
  final anchor = box != null && box.hasSize
      ? (box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size)
      : Rect.zero;
  return navigator.push<Tenant>(_IosTenantPopoverRoute(
    anchor: anchor,
    tenants: tenants,
    currentTenantId: currentTenantId,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    capturedThemes:
        InheritedTheme.capture(from: context, to: navigator.context),
  ));
}

class _IosTenantPopoverRoute extends PopupRoute<Tenant> {
  _IosTenantPopoverRoute({
    required this.anchor,
    required this.tenants,
    required this.currentTenantId,
    required this.barrierLabel,
    required this.capturedThemes,
  });

  final Rect anchor;
  final List<Tenant> tenants;
  final int? currentTenantId;
  final CapturedThemes capturedThemes;

  /// `ion-popover style="--width: 220px"`
  static const double width = 220;

  @override
  final String barrierLabel;

  /// iOS 26 theme: `--backdrop-opacity: 0.2`
  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.2);

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final maxLeft =
        (size.width - width - 8 - padding.right).clamp(8.0, size.width);
    final left = anchor.left.clamp(8.0 + padding.left, maxLeft).toDouble();
    // IOS_R4: the popover replaces the capsule (popover top = capsule top).
    final top = anchor.top;
    final curve =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return capturedThemes.wrap(
      Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            child: FadeTransition(
              opacity: curve,
              child: ScaleTransition(
                alignment: Alignment.topLeft,
                scale: Tween<double>(begin: 0.9, end: 1).animate(curve),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        (size.height - top - 16).clamp(44.0, size.height),
                  ),
                  child: _IosTenantPopoverContent(
                    tenants: tenants,
                    currentTenantId: currentTenantId,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IosTenantPopoverContent extends StatelessWidget {
  const _IosTenantPopoverContent({
    required this.tenants,
    required this.currentTenantId,
  });

  final List<Tenant> tenants;
  final int? currentTenantId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // ion-list lines="none" on the glass popover
    final itemBackground = dark ? const Color(0xFF1C1C1D) : Colors.white;
    return Material(
      type: MaterialType.transparency,
      child: IosGlassSurface(
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        blur: 2,
        child: ColoredBox(
          color: itemBackground.withValues(alpha: 0.86),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in tenants)
                  InkWell(
                    onTap: () => Navigator.of(context).pop(t),
                    splashFactory: NoSplash.splashFactory,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.longName.isNotEmpty
                                    ? t.longName
                                    : t.shortName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (t.id == currentTenantId)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                // ion-badge color="primary" (iOS)
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  context.l10n.signoutCurrent,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
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
