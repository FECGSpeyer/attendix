import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/app_action_sheet.dart';
import '../../../profile/presentation/widgets/profile_helpers.dart' show profileRoleName;
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import '../widgets/join/rd_join_sheet.dart';
import '../widgets/rd_widgets.dart';

/// REDESIGN (Ich und Einstieg, E1): the group list on /tenants in the new
/// design. Only the look: [TenantSelectionPage] keeps its logic (automatic
/// start, opening, favourite, deleting, logout) and hands it in.
class RdTenantsView extends StatelessWidget {
  const RdTenantsView({
    super.key,
    required this.tenants,
    required this.currentTenantId,
    required this.onOpen,
    required this.onFavorite,
    required this.onDelete,
    required this.onRefresh,
    required this.onLogout,
  });

  final AsyncValue<List<Tenant>> tenants;

  /// The open group; null at the start (then "Ausloggen" instead of "‹ Ich").
  final int? currentTenantId;
  final void Function(Tenant tenant) onOpen;
  final void Function(Tenant tenant) onFavorite;
  final void Function(Tenant tenant) onDelete;
  final Future<void> Function() onRefresh;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final list = tenants.valueOrNull ?? const <Tenant>[];
    return RdPage(
      onRefresh: onRefresh,
      children: [
        if (currentTenantId != null)
          RdBackLink(label: l10n.redesignTabMe, onTap: () => context.go(RedesignRoutes.me))
        else
          const SizedBox(height: 16),
        Semantics(header: true, child: Text(l10n.redesignMeGroups, style: RdType.largeTitle(p))),
        const SizedBox(height: 4),
        Text(l10n.redesignTenantsIntro, style: RdType.meta(p, size: 14)),
        const SizedBox(height: 16),
        if (tenants.isLoading && list.isEmpty)
          RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
        else if (tenants.hasError && list.isEmpty)
          RdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.redesignGroupsLoadFailed, style: RdType.body(p)),
                const SizedBox(height: 12),
                RdOutlineButton(label: l10n.redesignCommonRetry, onPressed: onRefresh),
              ],
            ),
          )
        else
          RdGroupedList(
            children: [
              for (final t in list)
                _TenantRow(
                  tenant: t,
                  isCurrent: t.id == currentTenantId,
                  onOpen: () => onOpen(t),
                  onFavorite: () => onFavorite(t),
                  onDelete: () => onDelete(t),
                ),
            ],
          ),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.redesignTenantsAnother),
        RdGroupedList(
          children: [
            RdListRow(
              leading: RdRowIcon(Icons.group_add_outlined, color: p.primary, background: p.soft),
              title: l10n.redesignTenantsJoin,
              titleColor: p.link,
              subtitle: l10n.redesignJoinHaveInviteHint,
              showChevron: false,
              onTap: () => showRdJoinSheet(context),
            ),
            RdListRow(
              leading: RdRowIcon(Icons.add_business_outlined, color: p.primary, background: p.soft),
              title: l10n.redesignTenantsCreate,
              titleColor: p.link,
              subtitle: l10n.redesignJoinCreateHint,
              showChevron: false,
              onTap: () => context.push('/tenants/new'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.redesignTenantsStart),
        const RdGroupedList(children: [_AskOnStartRow()]),
        if (currentTenantId == null) ...[
          const SizedBox(height: 24),
          RdOutlineButton(label: l10n.redesignMeLogout, icon: Icons.logout, color: p.absent, onPressed: onLogout),
        ],
      ],
    );
  }
}

class _TenantRow extends StatelessWidget {
  const _TenantRow({
    required this.tenant,
    required this.isCurrent,
    required this.onOpen,
    required this.onFavorite,
    required this.onDelete,
  });

  final Tenant tenant;
  final bool isCurrent;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  Future<void> _more(BuildContext context) async {
    final l10n = context.l10n;
    final favorite = tenant.favorite == true;
    final action = await showAppActionSheet<int>(
      context,
      title: tenant.longName.isNotEmpty ? tenant.longName : tenant.shortName,
      actions: [
        AppActionSheetAction(value: 0, icon: Icons.info_outline, label: l10n.redesignTenantsDetails),
        AppActionSheetAction(
          value: 1,
          icon: favorite ? Icons.star_border : Icons.star_outline,
          label: favorite ? l10n.redesignTenantsUnfavorite : l10n.redesignTenantsFavorite,
        ),
        // Like the old swipe action: only admins of the group may delete it.
        if (tenant.role == Role.admin.value)
          AppActionSheetAction(value: 2, icon: Icons.delete_outline, label: l10n.redesignTenantsDelete, destructive: true),
      ],
    );
    if (!context.mounted) return;
    switch (action) {
      case 0:
        if (tenant.id != null) context.push('/tenants/${tenant.id}');
      case 1:
        onFavorite();
      case 2:
        onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final name = tenant.longName.isNotEmpty ? tenant.longName : tenant.shortName;
    final role = profileRoleName(Role.fromValue(tenant.role ?? 99));
    return RdListRow(
      leading: RdInitials(rdInitialsOf(tenant.shortName.isNotEmpty ? tenant.shortName : name), size: 40, square: true),
      title: name,
      subtitle: [role, if (isCurrent) l10n.redesignTenantsCurrent].where((s) => s.isNotEmpty).join(' · '),
      selected: isCurrent,
      showChevron: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tenant.favorite == true) Icon(Icons.star, size: 18, color: p.late),
          IconButton(
            tooltip: l10n.redesignTenantsMore(name),
            icon: Icon(Icons.more_horiz, color: p.text2),
            onPressed: () => _more(context),
          ),
        ],
      ),
      onTap: onOpen,
    );
  }
}

/// "Gruppe beim Start wählen" (old "Instanzauswahl aktivieren"): same write
/// as the old toggle, the switch shows the wanted value while it saves.
class _AskOnStartRow extends ConsumerStatefulWidget {
  const _AskOnStartRow();

  @override
  ConsumerState<_AskOnStartRow> createState() => _AskOnStartRowState();
}

class _AskOnStartRowState extends ConsumerState<_AskOnStartRow> {
  Future<void>? _awaiting;

  Future<void> _onChanged(bool value) async {
    final write = ref.read(userPreferencesNotifierProvider.notifier).setWantInstanceSelection(value);
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
    final p = context.rd;
    final l10n = context.l10n;
    final value = ref.watch(wantedInstanceSelectionProvider) ?? ref.watch(userPreferencesProvider).wantInstanceSelection;
    return RdListRow(
      title: l10n.redesignTenantsAskOnStart,
      subtitle: l10n.redesignTenantsAskOnStartHint,
      showChevron: false,
      trailing: Switch.adaptive(value: value, activeTrackColor: p.primary, onChanged: _onChanged),
    );
  }
}
