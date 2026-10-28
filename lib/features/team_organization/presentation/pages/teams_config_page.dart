import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/teams/teams_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../planning/presentation/widgets/ion_items.dart';
import '../../../../l10n/l10n.dart';

/// TEAMS: configuration page of the Attendix channel tab (Ionic
/// `teams-config`). Teams loads it in a dialog when someone adds Attendix to
/// a channel. The installer picks the Attendix instance; we save a content
/// URL scoped by that tenant id (`/open-attendance?tenantId=`), which then
/// switches to that tenant.
class TeamsConfigPage extends ConsumerStatefulWidget {
  const TeamsConfigPage({super.key});

  static String get saveFailed => l10nWithoutContext.teamsSaveFailed;

  @override
  ConsumerState<TeamsConfigPage> createState() => _TeamsConfigPageState();
}

class _TeamsConfigPageState extends ConsumerState<TeamsConfigPage> {
  int? _selectedTenantId;
  List<Tenant> _tenants = const [];
  bool _saveHandlerRegistered = false;

  TeamsService get _teams => ref.read(teamsServiceProvider);

  /// Runs on every build: keeps the tenant list read by the save handler
  /// current (the provider may first deliver an empty/error list and the
  /// real tenants later) and auto-selects a single instance. Only the Teams
  /// handler registration itself happens once.
  void _syncTenants(List<Tenant> tenants) {
    _tenants = tenants;
    final selected = _selectedTenantId;
    int? next = selected;
    if (selected != null && !tenants.any((t) => t.id == selected)) next = null;
    if (next == null && tenants.length == 1) next = tenants.first.id;
    final selectionChanged = next != selected;
    _selectedTenantId = next;

    if (!_saveHandlerRegistered) {
      _saveHandlerRegistered = true;
      // Enable the Teams "Save" button only once a tenant is chosen, and
      // define what gets persisted when the installer clicks it.
      _teams.sdk.registerConfigSaveHandler(() {
        final id = _selectedTenantId;
        if (id == null) return null;
        final tenant = _tenants.where((t) => t.id == id).firstOrNull;
        return TeamsService.tabConfigFor(
          tenantId: id,
          shortName: tenant?.shortName,
        );
      }, TeamsConfigPage.saveFailed);
      _updateValidity();
    } else if (selectionChanged) {
      _updateValidity();
    }
  }

  void _updateValidity() {
    _teams.sdk.setValidityState(_selectedTenantId != null);
  }

  void _onTenantChange(int? id) {
    setState(() => _selectedTenantId = id);
    _updateValidity();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(isInTeamsProvider)) {
      return Scaffold(
        body: _Centered(
          child: Text(
            context.l10n.teamsOnlyInTeams,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final tenantsAsync = ref.watch(userTenantsProvider);
    return Scaffold(
      body: tenantsAsync.when(
        loading: () =>
            const _Centered(child: CircularProgressIndicator()),
        error: (_, __) => _buildContent(context, const []),
        data: (tenants) => _buildContent(context, tenants),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Tenant> tenants) {
    // Touches only fields read by the save handler / this build; no setState.
    _syncTenants(tenants);
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          Text(context.l10n.teamsSetup, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppDimensions.paddingM),
          if (tenants.isEmpty)
            Text(context.l10n.teamsNoAccount)
          else ...[
            _TenantRadioList(
              tenants: tenants,
              selectedId: _selectedTenantId,
              onChanged: _onTenantChange,
            ),
            const SizedBox(height: AppDimensions.paddingM),
            Text(
              context.l10n.teamsChoose,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.medium),
            ),
          ],
        ],
      ),
    );
  }
}

/// Radio list of the user's instances (Ionic ion-radio-group).
class _TenantRadioList extends StatelessWidget {
  const _TenantRadioList({
    required this.tenants,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Tenant> tenants;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Ionic iOS ion-radio: label left, primary checkmark on the selected row.
    if (isIonIos(context)) {
      return Column(
        children: [
          for (var i = 0; i < tenants.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16),
            ListTile(
              title: Text(tenants[i].longName.isNotEmpty ? tenants[i].longName : tenants[i].shortName),
              trailing: tenants[i].id != null && tenants[i].id == selectedId
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: tenants[i].id == null ? null : () => onChanged(tenants[i].id),
            ),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (final tenant in tenants)
          RadioListTile<int>(
            value: tenant.id ?? -1,
            groupValue: selectedId,
            onChanged: tenant.id == null ? null : onChanged,
            title: Text(
              tenant.longName.isNotEmpty ? tenant.longName : tenant.shortName,
            ),
          ),
      ],
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: child,
      ),
    );
  }
}
