import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../core/providers/dashboard_providers.dart'; // DASHBOARD

/// Tenant selection page
class TenantSelectionPage extends ConsumerStatefulWidget {
  const TenantSelectionPage({super.key});

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

    // If no saved tenant, don't auto-navigate
    if (userPrefs.currentTenantId == null) return;

    // If tenant is already set, user navigated here to switch - show selection
    final currentTenant = ref.read(currentTenantProvider);
    if (currentTenant != null) return;

    setState(() => _isAutoNavigating = true);

    try {
      // Wait for tenants to load
      final tenants = await ref.read(userTenantsProvider.future);
      final savedTenant = tenants
          .where((t) => t.id == userPrefs.currentTenantId)
          .firstOrNull;

      // User no longer has access to saved tenant
      if (savedTenant == null) {
        setState(() => _isAutoNavigating = false);
        return;
      }

      // Get role FIRST, before any state changes (same pattern as _selectTenant)
      final role = await _getTenantUserRole(savedTenant.id!);

      if (!mounted) return;

      // Set tenant locally WITHOUT triggering auth sync
      await ref.read(currentTenantProvider.notifier).setTenantLocal(savedTenant);

      // Wait for currentTenantUserProvider to load so router doesn't redirect back
      await ref.read(currentTenantUserProvider.future);

      if (!mounted) return;

      // Get notifier BEFORE navigation (widget may be disposed after go())
      final prefsNotifier = ref.read(userPreferencesNotifierProvider.notifier);

      // Navigate FIRST
      context.go(homeRouteFor(role, savedTenant.id, ref.read(supabaseAuthProvider).currentUser?.userMetadata)); // DASHBOARD

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
  Future<Role> _getTenantUserRole(int tenantId) async {
    final supabase = ref.read(supabaseClientProvider);
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return Role.none;

    final response = await supabase
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
    // Get the user's role FIRST, before any state changes
    final role = await _getTenantUserRole(tenant.id!);

    // Check mounted before state change
    if (!mounted) return;

    // Set tenant locally WITHOUT triggering auth sync
    await ref.read(currentTenantProvider.notifier).setTenantLocal(tenant);

    // Wait for currentTenantUserProvider to load so router doesn't redirect back
    await ref.read(currentTenantUserProvider.future);

    if (!mounted) return;

    // Get notifier BEFORE navigation (widget may be disposed after go())
    final prefsNotifier = ref.read(userPreferencesNotifierProvider.notifier);

    // Navigate FIRST - before auth sync can cause rebuilds
    context.go(homeRouteFor(role, tenant.id, ref.read(supabaseAuthProvider).currentUser?.userMetadata)); // DASHBOARD

    // Auth sync AFTER navigation (fire and forget, notifier captured above)
    prefsNotifier.updateCurrentTenantId(tenant.id!);
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while auto-navigating
    if (_isAutoNavigating) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final tenantsAsync = ref.watch(userTenantsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gruppe auswählen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final supabase = ref.read(supabaseClientProvider);
              await ref.read(currentTenantProvider.notifier).clearTenant();
              await supabase.auth.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: tenantsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
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
                'Fehler beim Laden',
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
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
        data: (tenants) {
          if (tenants.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.group_off_outlined,
                      size: 80,
                      color: AppColors.medium,
                    ),
                    const SizedBox(height: AppDimensions.paddingL),
                    Text(
                      'Keine Gruppen',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    Text(
                      'Du bist noch keiner Gruppe zugeordnet. '
                      'Bitte wende dich an einen Administrator oder erstelle eine neue Gruppe.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.medium,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.paddingXL),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/register'),
                      icon: const Icon(Icons.add),
                      label: const Text('Neue Gruppe erstellen'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            itemCount: tenants.length + 1, // +1 for create button
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppDimensions.paddingS),
            itemBuilder: (context, index) {
              if (index == tenants.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.paddingS),
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/register'),
                    icon: const Icon(Icons.add),
                    label: const Text('Neue Instanz erstellen'),
                  ),
                );
              }
              final tenant = tenants[index];
              return _TenantCard(
                tenant: tenant,
                onTap: () => _selectTenant(tenant),
              );
            },
          );
        },
      ),
    );
  }
}

class _TenantCard extends ConsumerWidget {
  const _TenantCard({
    required this.tenant,
    required this.onTap,
  });

  final Tenant tenant;
  final VoidCallback onTap;

  String get _displayName =>
      tenant.shortName.isNotEmpty ? tenant.shortName : tenant.longName;
  String? get _description =>
      tenant.longName != tenant.shortName ? tenant.longName : null;
  String get _initials => _displayName.length >= 2
      ? _displayName.substring(0, 2).toUpperCase()
      : _displayName.toUpperCase();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = tenant.favorite == true;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Row(
            children: [
              // Tenant avatar/image
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.paddingM),

              // Tenant info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (_description != null) ...[
                      const SizedBox(height: AppDimensions.paddingXS),
                      Text(
                        _description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.medium,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Favorite toggle
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite ? AppColors.warning : AppColors.medium,
                ),
                onPressed: () {
                  if (tenant.id != null) {
                    toggleTenantFavorite(ref, tenant.id!, !isFavorite);
                  }
                },
              ),

              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  color: AppColors.medium,
                ),
                onPressed: () {
                  if (tenant.id != null) {
                    context.pushNamed(
                      AppRoutes.tenantDetail,
                      pathParameters: {'id': '${tenant.id}'},
                    );
                  }
                },
              ),

              const Icon(
                Icons.chevron_right,
                color: AppColors.medium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
