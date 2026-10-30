import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/utils/dashboard_logic.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Shared Dateiablage link that was opened while signed out. The router
/// resumes it after login (Ionic `FilesService.setPendingLink`).
class PendingFileLink {
  PendingFileLink._();

  static String? _value;

  static void set(String link) => _value = link;

  /// Returns the stashed link once and clears it.
  static String? consume() {
    final v = _value;
    _value = null;
    return v;
  }
}

/// Resolver for shared file links
/// (`/open-file?tenantId=7&path=Noten/Marsch.pdf[&folder=1]`, Ionic `open-file`).
///
/// Signs in if needed, switches to the link's tenant and opens the files page
/// in the linked folder, or in the parent folder with the file opened.
class OpenFilePage extends ConsumerStatefulWidget {
  const OpenFilePage({
    super.key,
    required this.tenantId,
    required this.path,
    required this.isFolder,
  });

  final int? tenantId;
  final String path;
  final bool isFolder;

  @override
  ConsumerState<OpenFilePage> createState() => _OpenFilePageState();
}

class _OpenFilePageState extends ConsumerState<OpenFilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    try {
      await _resolveLink();
    } catch (_) {
      if (!mounted) return;
      ToastHelper.showError(context, context.l10n.openFileLinkFailed);
      context.go('/login');
    }
  }

  Future<void> _resolveLink() async {
    final tenantId = widget.tenantId;
    if (tenantId == null || tenantId <= 0) {
      context.go('/login');
      return;
    }

    final supabase = ref.read(supabaseClientProvider);
    if (supabase.auth.currentSession == null) {
      final query = Uri(queryParameters: {
        'tenantId': '$tenantId',
        'path': widget.path,
        if (widget.isFolder) 'folder': '1',
      }).query;
      PendingFileLink.set('/open-file?$query');
      context.go('/login');
      return;
    }

    final current = ref.read(currentTenantProvider);
    if (current?.id != tenantId) {
      final tenants = await ref.read(userTenantsProvider.future);
      final target = tenants.where((t) => t.id == tenantId).firstOrNull;
      if (!mounted) return;
      if (target == null) {
        ToastHelper.showError(context, context.l10n.openFileNoTenantAccess);
        // ASTRA_FILES: Ionic routeAfterAuth(undefined, current tenant).
        context.go(current == null ? '/tenants' : _homeRoute(current.id));
        return;
      }
      await ref.read(currentTenantProvider.notifier).setTenant(target);
    }
    // Wait until the role of the (new) tenant is loaded so the router
    // does not bounce the navigation to the tenant selection.
    for (var i = 0; i < 50 && ref.read(isRoleLoadingProvider); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;

    // ASTRA_FILES: Ionic `if (!db.canAccessFiles())` after the switch ->
    // toast files.noAccess + routeAfterAuth(undefined, tenantId).
    if (!ref.read(canAccessFilesProvider)) {
      ToastHelper.showError(context, context.l10n.filesNoAccess);
      context.go(_homeRoute(tenantId));
      return;
    }

    final segments = widget.path.split('/').where((s) => s.isNotEmpty).toList();
    final folder = widget.isFolder
        ? segments.join('/')
        : segments.take(segments.isEmpty ? 0 : segments.length - 1).join('/');
    final query = Uri(queryParameters: {
      'path': folder,
      'tenantId': '$tenantId',
      if (!widget.isFolder && segments.isNotEmpty) 'open': segments.last,
    }).query;
    context.go('/settings/files?$query');
  }

  /// Ionic `routeAfterAuth(undefined, tenantId)` – the role's start page.
  String _homeRoute(int? tenantId) => homeRouteFor(
        ref.read(currentRoleProvider),
        tenantId,
        ref.read(supabaseClientProvider).auth.currentUser?.userMetadata,
      );

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: AppSpinner()),
    );
  }
}
