import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../l10n/l10n.dart';
import '../../../auth/presentation/widgets/ion_form_list.dart';
import 'tenant_create_page.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import '../../../../core/providers/dashboard_providers.dart'; // DASHBOARD
import '../../../../core/providers/push_providers.dart'; // PUSH
import '../../../settings/presentation/widgets/settings_sheet.dart'; // IOS_SETTINGS2

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
  const TenantSelectionPage({super.key, this.sheet = false});

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
    if (widget.sheet) return; // IOS_SETTINGS2: opened by the user
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

    // If user wants to see selection, don't auto-navigate
    if (userPrefs.wantInstanceSelection) return;

    // If tenant is already set, user navigated here to switch - show selection
    final currentTenant = ref.read(currentTenantProvider);
    if (currentTenant != null) return;

    setState(() => _isAutoNavigating = true);

    // IOS_SHELL: setting the tenant lets the router replace this page, so
    // don't touch `ref` / `context` after async gaps ("Cannot use ref after
    // the widget was disposed"): use the captured container and router.
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);

    try {
      // Wait for tenants to load
      final tenants = await container.read(userTenantsProvider.future);
      // UX_NAV: Ionic db.setTenant opens the stored tenant, otherwise the
      // first one (no selection screen unless "Instanzauswahl" is enabled).
      final savedTenant =
          tenants.where((t) => t.id == userPrefs.currentTenantId).firstOrNull ??
          tenants.firstOrNull;

      // No tenant at all: show the (empty) list with "Neue Instanz anlegen"
      if (savedTenant == null) {
        if (mounted) setState(() => _isAutoNavigating = false);
        return;
      }

      // Get role FIRST, before any state changes (same pattern as _selectTenant)
      final role =
          await _getTenantUserRole(savedTenant.id!, container: container);

      if (!mounted) return;

      // Set tenant locally WITHOUT triggering auth sync
      await container
          .read(currentTenantProvider.notifier)
          .setTenantLocal(savedTenant);

      // Wait for currentTenantUserProvider to load so router doesn't redirect back
      await container.read(currentTenantUserProvider.future);

      // Get notifier BEFORE navigation (widget may be disposed after go())
      final prefsNotifier =
          container.read(userPreferencesNotifierProvider.notifier);

      // Navigate FIRST (also when the router already replaced this page)
      router.go(
        homeRouteFor(
          role,
          savedTenant.id,
          container.read(supabaseAuthProvider).currentUser?.userMetadata,
        ),
      ); // DASHBOARD

      // Auth sync AFTER navigation (fire and forget, notifier captured above)
      prefsNotifier.updateCurrentTenantId(savedTenant.id!);
    } catch (e) {
      debugPrint('Auto-navigation failed: $e');
      if (mounted) {
        setState(() => _isAutoNavigating = false);
      }
    }
  }

  /// Get the user's role for a specific tenant
  Future<Role> _getTenantUserRole(int tenantId,
      {ProviderContainer? container}) async {
    final supabase = container != null
        ? container.read(supabaseClientProvider)
        : ref.read(supabaseClientProvider);
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return Role.none;

    final response =
        await supabase
            .from('tenantUsers')
            .select('role')
            .eq('tenantId', tenantId)
            .eq('userId', userId)
            .maybeSingle();

    if (response == null) return Role.none;
    return Role.fromValue(response['role'] as int? ?? 99);
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
    ); // DASHBOARD

    // Navigate FIRST - before auth sync can cause rebuilds
    // IOS_SETTINGS2: Ionic `modal?.dismiss()` before navigating.
    sheetNavigator?.pop();
    router.go(home);

    // Auth sync AFTER navigation (fire and forget, notifier captured above)
    prefsNotifier.updateCurrentTenantId(tenant.id!);
  }

  /// Ionic settings.page.html instances modal: cog button opens a small sheet
  /// with the "Instanzauswahl aktivieren" toggle.
  void _openInstanceSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => Consumer(
            builder: (context, ref, _) {
              final prefs = ref.watch(userPreferencesProvider);
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: SwitchListTile.adaptive(
                      title: Text(context.l10n.settingsEnableTenantSelect),
                      subtitle: Text(context.l10n.settingsTenantSelectHelper),
                      value: prefs.wantInstanceSelection,
                      onChanged:
                          (value) => ref
                              .read(userPreferencesNotifierProvider.notifier)
                              .updatePreferences(wantInstanceSelection: value),
                    ),
                  ),
                ),
              );
            },
          ),
    );
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
            ? context.l10n.settingsFavoriteSet(tenant.longName)
            : context.l10n.settingsFavoriteRemoved(tenant.longName),
      );
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.svcSaveFailed);
    }
  }

  /// Ionic deleteInstance: only admins; alert with the instance name input.
  Future<void> _deleteInstance(Tenant tenant) async {
    if (tenant.id == null) return;
    // Ionic canDeleteTenant(): admin && !db.isDemo().
    if (tenant.role != Role.admin.value || DemoGuard.isDemo) { // DEMO_GUARD
      ToastHelper.showError(context, context.l10n.settingsCannotDeleteTenant);
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
                    title: Text(dialogContext.l10n.settingsDeleteTenant),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          error ??
                              dialogContext.l10n
                                  .settingsDeleteTenantMessage(tenant.longName),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: controller,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: dialogContext.l10n.settingsTenantNamePh,
                          ),
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
                          foregroundColor: AppColors.danger,
                        ),
                        onPressed: () {
                          if (controller.text == tenant.longName) {
                            Navigator.of(dialogContext).pop(true);
                          } else {
                            setDialogState(
                              () =>
                                  error =
                                      dialogContext.l10n.settingsWrongName,
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
      await deleteTenant(ref, tenant.id!);
      if (mounted) ToastHelper.showSuccess(context, context.l10n.tenantSelectFlutterDeleted);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.svcDeleteFailed);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _logout() async {
    final supabase = ref.read(supabaseClientProvider);
    await ref.read(currentTenantProvider.notifier).clearTenant();
    await removePushTokenBeforeSignOut(ref); // PUSH
    await supabase.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while auto-navigating
    if (_isAutoNavigating) {
      return const Scaffold(body: Center(child: AppSpinner()));
    }

    final tenantsAsync = ref.watch(userTenantsProvider);
    final currentTenant = ref.watch(currentTenantProvider);
    final count = tenantsAsync.valueOrNull?.length;

    // Ionic routeAfterAuth: no instance → the full-page "Neue Instanz
    // anlegen" (register.page, not dismissable, account menu).
    if (!widget.sheet && tenantsAsync.hasValue && count == 0) {
      return const TenantCreatePage(canDismiss: false);
    }

    // UX_NAV: layout of the Ionic "Instanz wechseln" modal
    // (settings.page.html): "+" (Neue Instanz) left, title "Instanzen (n)",
    // cog (Instanzauswahl) right; inset list with short/long name, "Aktuell"
    // badge, favorite star and swipe actions Löschen / Favorit.
    // IOS_SETTINGS2: Ionic openCreateInstanceModal dismisses the sheet first.
    void createInstance() {
      if (widget.sheet) {
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.push('/tenants/new');
      } else {
        context.push('/tenants/new');
      }
    }

    final title = count == null
        ? context.l10n.orgTenants
        : context.l10n.settingsTenantsCount(count);
    final addButton = IconButton(
      tooltip: context.l10n.tenantSelectFlutterNewTenant,
      icon: const Icon(Icons.add),
      onPressed: createInstance,
    );
    final settingsButton = IconButton(
      tooltip: context.l10n.tenantSelectFlutterTenantSelection,
      icon: const Icon(Icons.settings_outlined),
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
              leading: addButton,
              title: Text(title),
              actions: [
                settingsButton,
                if (currentTenant == null)
                  IconButton(
                    tooltip: context.l10n.registerLogout,
                    icon: const Icon(Icons.logout),
                    onPressed: _logout,
                  )
                else
                  IconButton(
                    tooltip: context.l10n.commonClose,
                    icon: const Icon(Icons.close),
                    onPressed: () => context.go('/settings'),
                  ),
              ],
            ),
      body: tenantsAsync.when(
        loading: () => const Center(child: AppSpinner()),
        error:
            (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
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
                  ElevatedButton(
                    onPressed: () => ref.refresh(userTenantsProvider),
                    child: Text(context.l10n.messagesRetry),
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
            icon: Icons.delete_outline,
          ),
          SlidableAction(
            onPressed: (_) => onFavorite(),
            backgroundColor: AppColors.warning,
            foregroundColor: Colors.black,
            icon: isFavorite ? Icons.star_border : Icons.star,
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
              const Icon(Icons.star, size: 18, color: AppColors.warning),
            // Flutter-only: instance details (members, delete) page
            IconButton(
              tooltip: context.l10n.tasksDetails,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.info_outline, color: AppColors.medium),
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
