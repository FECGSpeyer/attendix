import 'dart:async';

import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/dialogs/ion_sheet.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/go_replace.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_registration_providers.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../l10n/l10n.dart';
import '../../../auth/presentation/widgets/ion_form_list.dart';
import 'tenant_create_page.dart';
import '../../../redesign/presentation/pages/rd_no_group_page.dart';
import '../../../redesign/presentation/pages/rd_tenants_view.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/providers/dashboard_providers.dart';
import '../../../../core/providers/push_providers.dart';
import '../../../settings/presentation/widgets/settings_sheet.dart';

/// IOS_SETTINGS2: Ionic settings "Instanz wechseln" row (and the iOS
/// `apps-outline` fab) open the instances `ion-modal` as a sheet
/// (`[breakpoints]="[0, 0.5, 1]"`, initial 0.5) instead of a page.
Future<void> showTenantsSheet(BuildContext context) => showSettingsSheet<void>(
      context,
      initialBreakpoint: 0.5,
      builder: (_) => const TenantSelectionPage(sheet: true),
    );

/// Tenant selection page
class TenantSelectionPage extends ConsumerStatefulWidget {
  const TenantSelectionPage({super.key, this.sheet = false, this.inTab = false});

  /// Beta "Meine Gruppen" inside the tab "Ich": opened by the user, so no
  /// auto navigation.
  final bool inTab;

  /// IOS_SETTINGS2: shown as the Ionic instances sheet from the settings
  /// page (no auto navigation, header "+" / title / cog only).
  final bool sheet;

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
    if (widget.sheet || widget.inTab) return; // opened by the user
    // Beta: right after a sign-in the group opens by itself. Decide that
    // before the first frame, so the list "Gruppen" does not flash up for a
    // moment before the loading screen (same condition as
    // [_tryAutoNavigation]).
    if (ref.read(redesignEnabledProvider) &&
        (InstanceSelectionGate.wanted(ref.read(userPreferencesProvider)) || ref.read(currentTenantProvider) == null)) {
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
    // IOS_SHELL: same lifecycle guard as _tryAutoNavigation.
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);
    final sheetNavigator = widget.sheet ? Navigator.of(context) : null;
    // IOS_SETTINGS2: Ionic onTenantChange — tapping the current instance in
    // the sheet does nothing.
    if (widget.sheet && tenant.id == ref.read(currentTenantProvider)?.id) {
      return;
    }

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

    // Ionic settings onTenantChange navigates to Utils.getUrl(role) (no
    // dashboard start page); the dashboard start only applies after login.
    final home = widget.sheet && !RedesignRoutes.active
        ? role.defaultRoute
        : homeRouteFor(
            role,
            tenant.id,
            container.read(supabaseAuthProvider).currentUser?.userMetadata,
          );

    // Navigate FIRST - before auth sync can cause rebuilds
    // IOS_SETTINGS2: Ionic `modal?.dismiss()` before navigating.
    sheetNavigator?.pop();
    goReplacingHistory(router, home);

    // Auth sync AFTER navigation (fire and forget, notifier captured above)
    prefsNotifier.updateCurrentTenantId(tenant.id!);
  }

  /// Ionic settings.page.html instances modal: cog button opens a small sheet
  /// with the "Instanzauswahl aktivieren" toggle.
  void _openInstanceSettings() {
    if (context.rdSkin == null) {
      // Ionic: [breakpoints]="[0, .2]" [initialBreakpoint]=".2", no header,
      // `ion-content color="light"` with the inset toggle.
      showIonSheet<void>(
        context,
        breakpoints: const [0, 0.2],
        initialBreakpoint: 0.2,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        builder: (sheetContext, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.only(top: 20),
          child: const _InstanceSelectionToggle(),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      showDragHandle: true,
      builder: (sheetContext) => const _InstanceSelectionToggle(),
    );
  }

  Future<void> _toggleFavorite(Tenant tenant) async {
    if (tenant.id == null) return;
    final setFavorite = tenant.favorite != true;
    try {
      await toggleTenantFavorite(ref, tenant.id!, setFavorite);
      if (!mounted) return;
      final beta = ref.read(redesignEnabledProvider);
      ToastHelper.showSuccess(
        context,
        setFavorite
            ? (beta
                ? context.l10n.redesignTenantsFavoriteSet(tenant.longName)
                : context.l10n.settingsFavoriteSet(tenant.longName))
            : (beta
                ? context.l10n.redesignTenantsFavoriteRemoved(tenant.longName)
                : context.l10n.settingsFavoriteRemoved(tenant.longName)),
      );
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.svcSaveFailed);
    }
  }

  /// Ionic deleteInstance: only admins; alert with the instance name input.
  Future<void> _deleteInstance(Tenant tenant) async {
    if (tenant.id == null) return;
    // Ionic canDeleteTenant(): admin && !db.isDemo().
    // REDESIGN (E1): same dialog and steps, Beta texts ("Gruppe").
    final beta = ref.read(redesignEnabledProvider);
    if (tenant.role != Role.admin.value || DemoGuard.isDemo) { // DEMO_GUARD
      ToastHelper.showError(
        context,
        beta ? context.l10n.redesignTenantsCannotDelete : context.l10n.settingsCannotDeleteTenant,
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
                    title: Text(beta ? dialogContext.l10n.redesignTenantsDeleteTitle : dialogContext.l10n.settingsDeleteTenant),
                    // Ionic alert: message + text input, plain buttons
                    // (settings.page.ts deleteInstance).
                    content: AppAlertInputGroup(
                      betaCrossAxisAlignment: CrossAxisAlignment.start,
                      message: Text(
                        error ??
                            (beta
                                ? dialogContext.l10n.redesignTenantsDeleteMessage(tenant.longName)
                                : dialogContext.l10n
                                    .settingsDeleteTenantMessage(tenant.longName)),
                      ),
                      children: [
                        const AppAlertBetaGap(12),
                        AppAlertInput(
                          controller: controller,
                          autofocus: true,
                          placeholder: beta ? dialogContext.l10n.redesignTenantsDeleteNamePh : dialogContext.l10n.settingsTenantNamePh,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text(dialogContext.l10n.commonCancel),
                      ),
                      TextButton(
                        style: beta
                            ? TextButton.styleFrom(
                                foregroundColor: AppColors.danger,
                              )
                            : null,
                        onPressed: () {
                          if (controller.text == tenant.longName) {
                            Navigator.of(dialogContext).pop(true);
                          } else {
                            setDialogState(
                              () =>
                                  error = beta
                                      ? dialogContext.l10n.redesignTenantsDeleteWrongName
                                      : dialogContext.l10n.settingsWrongName,
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
      // PARITY_R10: Ionic db.deleteInstance — close the instances sheet and,
      // when the open instance was deleted, open the next one (setTenant →
      // its start page, or "Neue Instanz anlegen" when none is left).
      final router = GoRouter.of(context);
      final rootContext = router.routerDelegate.navigatorKey.currentContext;
      final sheetNavigator = widget.sheet ? Navigator.of(context) : null;
      final wasCurrent = tenant.id == ref.read(currentTenantProvider)?.id;
      // Ionic deleteInstance: setTenant() + Utils.getUrl(role) after every
      // delete – the open instance's start page (read before the sheet closes).
      final currentId = ref.read(currentTenantIdProvider);
      final home = currentId == null
          ? null
          : homeRouteFor(
              ref.read(currentRoleProvider),
              currentId,
              ref.read(supabaseAuthProvider).currentUser?.userMetadata,
            );
      await deleteTenant(ref, tenant.id!);
      sheetNavigator?.pop();
      final toastContext = widget.sheet ? rootContext : (mounted ? context : null);
      if (toastContext != null && toastContext.mounted) {
        ToastHelper.showSuccess(
          toastContext,
          beta ? toastContext.l10n.redesignTenantsDeleteDone : toastContext.l10n.dbInstanceDeleted,
        );
      }
      if (wasCurrent) router.go('/tenants');
      if (!wasCurrent && home != null) goReplacingHistory(router, home);
    } catch (_) {
      if (mounted) {
        ToastHelper.showError(
          context,
          beta ? context.l10n.redesignTenantsDeleteFailed : context.l10n.dbDeleteInstanceFailed,
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
        backgroundColor: context.rdSkin != null ? context.rd.bg : null,
        body: const Center(child: AppSpinner()),
      );
    }

    final tenantsAsync = ref.watch(userTenantsProvider);
    final currentTenant = ref.watch(currentTenantProvider);
    final count = tenantsAsync.valueOrNull?.length;

    // Ionic routeAfterAuth: no instance → the full-page "Neue Instanz
    // anlegen" (register.page, not dismissable, account menu).
    if (!widget.sheet && tenantsAsync.hasValue && count == 0) {
      // REDESIGN (UX N1): with the Beta switch on, join or found instead
      // of the bare form; the default app keeps the Ionic flow.
      if (ref.watch(redesignSettingsProvider).enabled) return const RdNoGroupPage();
      return const TenantCreatePage(canDismiss: false);
    }

    // REDESIGN (Ich und Einstieg, E1): the Beta group list; the logic
    // above (auto start, no group) and the actions below stay the same.
    if (!widget.sheet && ref.watch(redesignEnabledProvider)) {
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

    // UX_NAV: layout of the Ionic "Instanz wechseln" modal
    // (settings.page.html): "+" (Neue Instanz) left, title "Instanzen (n)",
    // cog (Instanzauswahl) right; inset list with short/long name, "Aktuell"
    // badge, favorite star and swipe actions Löschen / Favorit.
    // IOS_SETTINGS2: Ionic openCreateInstanceModal dismisses the sheet and
    // presents RegisterPage as a card modal over the settings page.
    Future<void> createInstance() async {
      if (widget.sheet) {
        final navigator = Navigator.of(context);
        final sheetRoute = ModalRoute.of(context);
        navigator.pop();
        // The card modal scales the page behind it: wait until the sheet
        // is gone so it is not part of that picture.
        await _untilDismissed(sheetRoute);
        if (navigator.mounted) await showTenantCreateModal(navigator.context);
      } else {
        context.push('/tenants/new');
      }
    }

    final title = count == null
        ? context.l10n.orgTenants
        : context.l10n.settingsTenantsCount(count);
    final addButton = IconButton(
      tooltip: context.l10n.tenantSelectFlutterNewTenant,
      icon: Icon(AppIcons.add),
      onPressed: createInstance,
    );
    final settingsButton = IconButton(
      tooltip: context.l10n.tenantSelectFlutterTenantSelection,
      icon: Icon(AppIcons.settingsOutlined),
      onPressed: _openInstanceSettings,
    );

    return Scaffold(
      appBar: widget.sheet
          ? settingsSheetBar(
              context,
              title: title,
              leading: addButton,
              actions: [settingsButton],
            )
          : AppBar(
              // SEL-13: Ionic toolbar buttons (iOS glass capsules).
              leading: ToolbarButtonGroup(children: [addButton]),
              title: Text(title),
              actions: [
                ToolbarButtonGroup(children: [
                settingsButton,
                if (currentTenant == null)
                  IconButton(
                    tooltip: context.l10n.registerLogout,
                    icon: Icon(AppIcons.logout),
                    onPressed: _logout,
                  )
                else
                  IconButton(
                    tooltip: context.l10n.commonClose,
                    icon: Icon(AppIcons.close),
                    onPressed: () => context.go('/settings'),
                  ),
                ]),
              ],
            ),
      body: tenantsAsync.when(
        loading: () => const Center(child: AppSpinner()),
        error:
            (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    AppIcons.errorOutline,
                    size: 64,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                  Text(
                    context.l10n.tenantSelectFlutterLoadFailed,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                  Text(
                    error.toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.paddingL),
                  IonButton(
                    onPressed: () => ref.refresh(userTenantsProvider),
                    label: context.l10n.messagesRetry,
                  ),
                ],
              ),
            ),
        data: (tenants) {
          if (tenants.isEmpty) return const SizedBox.shrink();

          return RefreshIndicator.adaptive(
            onRefresh: () async => ref.refresh(userTenantsProvider.future),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // ion-list [inset] > ion-item-group
                IonInsetGroup(
                  children: [
                    for (final tenant in tenants)
                      _TenantTile(
                        tenant: tenant,
                        isCurrent: tenant.id == currentTenant?.id,
                        onTap: () => _selectTenant(tenant),
                        onFavorite: () => _toggleFavorite(tenant),
                        onDelete: () => _deleteInstance(tenant),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TenantTile extends StatelessWidget {
  const _TenantTile({
    required this.tenant,
    required this.isCurrent,
    required this.onTap,
    required this.onFavorite,
    required this.onDelete,
  });

  final Tenant tenant;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isFavorite = tenant.favorite == true;

    return Slidable(
      key: ValueKey('tenant-${tenant.id}'),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.4,
        // Ionic (ionSwipe) on the end options: full swipe toggles favorite.
        dismissible: DismissiblePane(
          onDismissed: () {},
          confirmDismiss: () async {
            onFavorite();
            return false;
          },
        ),
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: AppIcons.deleteOutline,
          ),
          SlidableAction(
            onPressed: (_) => onFavorite(),
            backgroundColor: AppColors.warning,
            foregroundColor: Colors.black,
            icon: isFavorite ? AppIcons.starBorder : AppIcons.star,
          ),
        ],
      ),
      // ion-item button detail="false": h2 short name, h3 long name,
      // "Aktuell" badge and favourite star at the end.
      child: IonItem(
        onTap: onTap,
        title: Text(tenant.shortName),
        subtitle: Text(
          tenant.longName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        end: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrent)
              Container(
                margin: const EdgeInsets.only(right: 5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            if (isFavorite)
              Icon(AppIcons.star, size: 18, color: AppColors.warning),
            // Flutter-only: instance details (members, delete) page
            IconButton(
              tooltip: context.l10n.tasksDetails,
              visualDensity: VisualDensity.compact,
              icon: Icon(AppIcons.infoOutline, color: AppColors.medium),
              onPressed: () {
                if (tenant.id != null) {
                  context.pushNamed(
                    AppRoutes.tenantDetail,
                    pathParameters: {'id': '${tenant.id}'},
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Ionic ngModel: the toggle flips at once and every change is written
/// (settings.page.ts onTenantSelectionChange). The writes are serialized in
/// [UserPreferencesNotifier.setWantInstanceSelection]; while writing, the
/// toggle shows the wanted value; on failure a toast and the stored value.
class _InstanceSelectionToggle extends ConsumerStatefulWidget {
  const _InstanceSelectionToggle();

  @override
  ConsumerState<_InstanceSelectionToggle> createState() => _InstanceSelectionToggleState();
}

class _InstanceSelectionToggleState extends ConsumerState<_InstanceSelectionToggle> {
  /// Write loop this toggle already waits for (one toast per failed loop).
  Future<void>? _awaiting;

  Future<void> _onChanged(bool newValue) async {
    final write = ref
        .read(userPreferencesNotifierProvider.notifier)
        .setWantInstanceSelection(newValue);
    if (identical(write, _awaiting)) return;
    _awaiting = write;
    try {
      await write;
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.svcSaveFailed);
    } finally {
      if (identical(_awaiting, write)) _awaiting = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(userPreferencesProvider);
    final value = ref.watch(wantedInstanceSelectionProvider) ??
        prefs.wantInstanceSelection;
    if (context.rdSkin == null) {
      // SEL-20: Ionic `ion-list [inset]` with one `ion-item` > `ion-toggle`
      // (label + helperText), no card.
      return SafeArea(
        child: IonInsetGroup(
          children: [
            IonItem(
              title: Text(context.l10n.settingsEnableTenantSelect),
              subtitle: Text(context.l10n.settingsTenantSelectHelper),
              onTap: () => _onChanged(!value),
              end: Switch.adaptive(value: value, onChanged: _onChanged),
            ),
          ],
        ),
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Card(
          margin: EdgeInsets.zero,
          child: SwitchListTile.adaptive(
            title: Text(context.l10n.settingsEnableTenantSelect),
            subtitle: Text(context.l10n.settingsTenantSelectHelper),
            value: value,
            onChanged: _onChanged,
          ),
        ),
      ),
    );
  }
}

/// Completes once [route]'s exit transition has finished (at the latest
/// after a short timeout, or right away without a running transition).
Future<void> _untilDismissed(ModalRoute<dynamic>? route) {
  final animation = route?.animation;
  if (animation == null || animation.isDismissed) return Future.value();
  final done = Completer<void>();
  void listener(AnimationStatus status) {
    if (status != AnimationStatus.dismissed) return;
    animation.removeStatusListener(listener);
    if (!done.isCompleted) done.complete();
  }

  animation.addStatusListener(listener);
  return done.future
      .timeout(const Duration(milliseconds: 600), onTimeout: () {});
}
