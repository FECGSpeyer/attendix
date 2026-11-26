import 'package:flutter/material.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/go_replace.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_registration_providers.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../l10n/l10n.dart';
import '../../../redesign/presentation/pages/rd_no_group_page.dart';
import '../../../redesign/presentation/pages/rd_tenants_view.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/providers/dashboard_providers.dart';
import '../../../../core/providers/push_providers.dart';

/// Tenant selection page
class TenantSelectionPage extends ConsumerStatefulWidget {
  const TenantSelectionPage({super.key, this.inTab = false});

  /// Opened inside the tab "Ich": user-triggered, so no auto navigation.
  final bool inTab;

  @override
  ConsumerState<TenantSelectionPage> createState() =>
      _TenantSelectionPageState();
}

class _TenantSelectionPageState extends ConsumerState<TenantSelectionPage> {
  bool _isAutoNavigating = false;
  bool _hasAttemptedAutoNav = false;

  @override
  void initState() {
    super.initState();
    // Try auto-navigation after the first frame
    if (widget.inTab) return; // opened by the user
    // Right after a sign-in the group opens by itself. Decide that before the
    // first frame, so the list "Gruppen" does not flash up before loading.
    if (InstanceSelectionGate.wanted(ref.read(userPreferencesProvider)) ||
        ref.read(currentTenantProvider) == null) {
      _isAutoNavigating = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoNavigation();
    });
  }

  /// Try to auto-navigate to saved tenant on cold start
  Future<void> _tryAutoNavigation() async {
    // Only try once
    if (_hasAttemptedAutoNav) return;
    _hasAttemptedAutoNav = true;

    final userPrefs = ref.read(userPreferencesProvider);

    // Ionic getWantedTenant(): with "Instanzauswahl aktivieren" a radio
    // alert asks right after a sign-in (a restored session opens the stored
    // instance). It runs here and not on the login page, because the router
    // replaces /login with /tenants as soon as the session exists.
    final ask = InstanceSelectionGate.wanted(userPrefs);

    // If tenant is already set, user navigated here to switch - show selection
    final currentTenant = ref.read(currentTenantProvider);
    if (!ask && currentTenant != null) {
      // Set since initState (restore): show the list as before.
      if (_isAutoNavigating && mounted) setState(() => _isAutoNavigating = false);
      return;
    }

    setState(() => _isAutoNavigating = true);

    // IOS_SHELL: setting the tenant lets the router replace this page, so
    // don't touch `ref` / `context` after async gaps ("Cannot use ref after
    // the widget was disposed"): use the captured container and router.
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);
    final route = ModalRoute.of(context);
    final userId = container.read(supabaseAuthProvider).currentUser?.id;

    try {
      // Wait for tenants to load
      final tenants = await container.read(userTenantsProvider.future);
      // UX_NAV: Ionic db.setTenant opens the stored tenant, otherwise the
      // first one (no selection screen unless "Instanzauswahl" is enabled).
      // Same order as the background restore (Ionic setTenant): a group the
      // restore set meanwhile is kept; otherwise IONIC_SESSION's pending
      // Ionic group, this device's instance, then user_metadata. Setting it
      // below also ends the pending restore in CurrentTenantNotifier.
      final restoredId = container.read(currentTenantProvider)?.id;
      Tenant? storedTenant = tenants.where((t) => t.id == restoredId).firstOrNull;
      if (storedTenant == null) {
        for (final id in await preferredTenantIds(userPrefs.currentTenantId)) {
          storedTenant = tenants.where((t) => t.id == id).firstOrNull;
          if (storedTenant != null) break;
        }
      }
      var savedTenant = storedTenant ?? tenants.firstOrNull;
      if (ask && savedTenant != null) {
        if (!mounted) return;
        savedTenant = await _askWantedTenant(tenants, storedTenant);
        if (!mounted) return;
        // The choice is made; a later visit of the list shows it normally.
        InstanceSelectionGate.afterSignIn = false;
      }

      // No tenant at all: show the (empty) list with "Neue Instanz anlegen"
      if (savedTenant == null) {
        if (mounted) setState(() => _isAutoNavigating = false);
        return;
      }

      // Get role FIRST, before any state changes (same pattern as _selectTenant)
      final role =
          await _getTenantUserRole(savedTenant.id!, container: container);

      if (!mounted) return;

      // An account switch opens this page from inside the tab shell: going
      // back into the shell before this page is fully shown left "Heute"
      // blank (old and new shell shared their navigator key). Nothing is
      // changed before that; if the page was left meanwhile (back, link,
      // another sign-in) the other navigation wins.
      final shown = await untilRouteShown(route);
      if (!mounted) return;
      bool stillWanted() =>
          route?.isCurrent == true &&
          container.read(supabaseAuthProvider).currentUser?.id == userId;
      if (!shown || !stillWanted()) {
        setState(() => _isAutoNavigating = false);
        return;
      }

      // Set tenant locally WITHOUT triggering auth sync
      await container
          .read(currentTenantProvider.notifier)
          .setTenantLocal(savedTenant);

      // Wait for currentTenantUserProvider to load so router doesn't redirect back
      await container.read(currentTenantUserProvider.future);

      // Same checks again after the loads above: the page, the account and
      // the group must still be the ones this run started for.
      if (!stillWanted() ||
          container.read(currentTenantProvider)?.id != savedTenant.id) {
        if (mounted) setState(() => _isAutoNavigating = false);
        return;
      }

      // Get notifier BEFORE navigation (widget may be disposed after go())
      final prefsNotifier =
          container.read(userPreferencesNotifierProvider.notifier);

      // Navigate FIRST, before the auth sync below
      goReplacingHistory(
        router,
        homeRouteFor(
          role,
          savedTenant.id,
          container.read(supabaseAuthProvider).currentUser?.userMetadata,
        ),
      ); // DASHBOARD, NAV_REPLACE

      // Auth sync AFTER navigation (fire and forget, notifier captured above)
      prefsNotifier.updateCurrentTenantId(savedTenant.id!);
    } catch (e) {
      debugPrint('Auto-navigation failed: $e');
      if (mounted) {
        setState(() => _isAutoNavigating = false);
      }
    }
  }

  /// Ionic `getWantedTenant()`: radio alert "Instanz auswählen" (no
  /// backdrop dismiss). "Abbrechen" opens the stored tenant, otherwise the
  /// first one; "Öffnen" the checked one.
  Future<Tenant> _askWantedTenant(List<Tenant> tenants, Tenant? stored) async {
    final fallback = stored ?? tenants.first;
    final result = await showAppRadioAlert<int>(
      context,
      title: context.l10n.dbChooseInstanceHeader,
      subtitle: context.l10n.dbChooseInstanceMessage,
      options: [for (final t in tenants) (t.id!, t.longName)],
      initialValue: stored?.id,
      confirmText: context.l10n.commonOpen,
      cancelDestructive: true,
      barrierDismissible: false,
    );
    // Cancelled, or "Öffnen" without a checked tenant → fallback.
    final id = result?.value;
    return tenants.where((t) => t.id == id).firstOrNull ?? fallback;
  }

  /// Get the user's role for a specific tenant
  Future<Role> _getTenantUserRole(int tenantId,
      {ProviderContainer? container}) async {
    final supabase = container != null
        ? container.read(supabaseClientProvider)
        : ref.read(supabaseClientProvider);
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return Role.none;

    final repo = container != null
        ? container.read(userRegistrationRepositoryForTenantProvider(tenantId))
        : ref.read(userRegistrationRepositoryForTenantProvider(tenantId));
    return await repo.getTenantUserRole(userId, tenantId: tenantId) ??
        Role.none;
  }

  /// Navigate to the appropriate page based on role
  Future<void> _selectTenant(Tenant tenant) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);

    // Get the user's role FIRST, before any state changes
    final role = await _getTenantUserRole(tenant.id!, container: container);

    // Check mounted before state change
    if (!mounted) return;

    // Set tenant locally WITHOUT triggering auth sync
    InstanceSelectionGate.afterSignIn = false;
    await container.read(currentTenantProvider.notifier).setTenantLocal(tenant);

    // Wait for currentTenantUserProvider to load so router doesn't redirect back
    await container.read(currentTenantUserProvider.future);

    // Get notifier BEFORE navigation (widget may be disposed after go())
    final prefsNotifier =
        container.read(userPreferencesNotifierProvider.notifier);

    final home = homeRouteFor(
      role,
      tenant.id,
      container.read(supabaseAuthProvider).currentUser?.userMetadata,
    );

    // Navigate FIRST - before auth sync can cause rebuilds
    goReplacingHistory(router, home);

    // Auth sync AFTER navigation (fire and forget, notifier captured above)
    prefsNotifier.updateCurrentTenantId(tenant.id!);
  }

  Future<void> _toggleFavorite(Tenant tenant) async {
    if (tenant.id == null) return;
    final setFavorite = tenant.favorite != true;
    try {
      await toggleTenantFavorite(ref, tenant.id!, setFavorite);
      if (!mounted) return;
      ToastHelper.showSuccess(
        context,
        setFavorite
            ? context.l10n.redesignTenantsFavoriteSet(tenant.longName)
            : context.l10n.redesignTenantsFavoriteRemoved(tenant.longName),
      );
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.svcSaveFailed);
    }
  }

  /// Delete group (admins only; confirms with group name input).
  Future<void> _deleteInstance(Tenant tenant) async {
    if (tenant.id == null) return;
    if (tenant.role != Role.admin.value || DemoGuard.isDemo) { // DEMO_GUARD
      ToastHelper.showError(
        context,
        context.l10n.redesignTenantsCannotDelete,
      );
      return;
    }
    final controller = TextEditingController();
    String? error;
    try {
      final confirmed = await showAppDialog<bool>(
        context: context,
        builder:
            (dialogContext) => StatefulBuilder(
              builder:
                  (dialogContext, setDialogState) => AppAlertDialog(
                    title: Text(dialogContext.l10n.redesignTenantsDeleteTitle),
                    content: AppAlertInputGroup(
                      betaCrossAxisAlignment: CrossAxisAlignment.start,
                      message: Text(
                        error ??
                            dialogContext.l10n.redesignTenantsDeleteMessage(
                              tenant.longName,
                            ),
                      ),
                      children: [
                        const AppAlertBetaGap(12),
                        AppAlertInput(
                          controller: controller,
                          autofocus: true,
                          placeholder:
                              dialogContext.l10n.redesignTenantsDeleteNamePh,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text(dialogContext.l10n.commonCancel),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: context.rd.absent,
                        ),
                        onPressed: () {
                          if (controller.text == tenant.longName) {
                            Navigator.of(dialogContext).pop(true);
                          } else {
                            setDialogState(
                              () => error = dialogContext
                                  .l10n.redesignTenantsDeleteWrongName,
                            );
                          }
                        },
                        child: Text(dialogContext.l10n.commonDelete),
                      ),
                    ],
                  ),
            ),
      );
      if (confirmed != true || !mounted) return;
      final router = GoRouter.of(context);
      final wasCurrent = tenant.id == ref.read(currentTenantProvider)?.id;
      final currentId = ref.read(currentTenantIdProvider);
      final home = currentId == null
          ? null
          : homeRouteFor(
              ref.read(currentRoleProvider),
              currentId,
              ref.read(supabaseAuthProvider).currentUser?.userMetadata,
            );
      await deleteTenant(ref, tenant.id!);
      if (mounted) {
        ToastHelper.showSuccess(
          context,
          context.l10n.redesignTenantsDeleteDone,
        );
      }
      if (wasCurrent) router.go('/tenants');
      if (!wasCurrent && home != null) goReplacingHistory(router, home);
    } catch (_) {
      if (mounted) {
        ToastHelper.showError(
          context,
          context.l10n.redesignTenantsDeleteFailed,
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _logout() async {
    final supabase = ref.read(supabaseClientProvider);
    await ref.read(currentTenantProvider.notifier).clearTenant();
    await removePushTokenBeforeSignOut(ref);
    await supabase.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while auto-navigating
    if (_isAutoNavigating) {
      return Scaffold(
        backgroundColor: context.rd.bg,
        body: const Center(child: AppSpinner()),
      );
    }

    final tenantsAsync = ref.watch(userTenantsProvider);
    final currentTenant = ref.watch(currentTenantProvider);
    final count = tenantsAsync.valueOrNull?.length;

    if (tenantsAsync.hasValue && count == 0) {
      return const RdNoGroupPage();
    }

    return RdTenantsView(
      tenants: tenantsAsync,
      currentTenantId: currentTenant?.id,
      onOpen: _selectTenant,
      onFavorite: _toggleFavorite,
      onDelete: _deleteInstance,
      onRefresh: () async {
        try {
          final _ = await ref.refresh(userTenantsProvider.future);
        } catch (_) {}
      },
      onLogout: _logout,
    );
  }
}
