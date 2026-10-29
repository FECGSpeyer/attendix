import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../../../profile/presentation/widgets/profile_helpers.dart'
    show profileRoleName;
import 'rd_widgets.dart';

/// REDESIGN: group chip at the top of "Heute" ("SO Stadtorchester ⌄").
/// Opens the "Gruppe wechseln" sheet when the user has more than one group.
class RdGroupChip extends ConsumerWidget {
  const RdGroupChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final tenant = ref.watch(currentTenantProvider);
    final name = tenant?.longName.isNotEmpty == true
        ? tenant!.longName
        : (tenant?.shortName ?? '');
    final logo = tenant?.shortName.isNotEmpty == true ? tenant!.shortName : name;
    return Semantics(
      button: true,
      label: context.l10n.redesignGroupsSwitchHint(name),
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => showRdGroupSwitchSheet(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RdInitials(rdInitialsOf(logo), size: 24, square: true, filled: true),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.keyboard_arrow_down, size: 18, color: p.text),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Gruppe wechseln" sheet (canvas E4): all groups of the user with their
/// role; tapping one switches to it and opens its "Heute".
Future<void> showRdGroupSwitchSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (_) => const _RdGroupSwitchSheet(),
  );
}

class _RdGroupSwitchSheet extends ConsumerStatefulWidget {
  const _RdGroupSwitchSheet();

  @override
  ConsumerState<_RdGroupSwitchSheet> createState() => _RdGroupSwitchSheetState();
}

class _RdGroupSwitchSheetState extends ConsumerState<_RdGroupSwitchSheet> {
  int? _switchingTo;

  /// Same steps as the old tenant switcher ([switchTenant]), but the new
  /// design always lands on "Heute".
  ///
  /// While it runs the sheet stays open (no back gesture, no buttons); if
  /// it was dragged closed anyway (also while it still animates out), the
  /// switch still finishes without popping the route below. The sheet's
  /// route and the providers' container are bound before the first await.
  Future<void> _switch(Tenant tenant) async {
    if (_switchingTo != null) return;
    final current = ref.read(currentTenantProvider);
    final navigator = Navigator.of(context);
    final sheet = ModalRoute.of(context);
    final router = GoRouter.of(context);
    if (tenant.id == null || current?.id == tenant.id) {
      navigator.pop();
      return;
    }
    setState(() => _switchingTo = tenant.id);
    final container = ProviderScope.containerOf(context, listen: false);
    final prefs = container.read(userPreferencesNotifierProvider.notifier);
    try {
      await container.read(currentTenantProvider.notifier).setTenantLocal(tenant);
      // Wait for the role of the new group so the router does not send the
      // user back.
      await container.read(currentTenantUserProvider.future);
      if (sheet != null && sheet.isCurrent) navigator.pop();
      router.go(RedesignRoutes.today);
      prefs.updateCurrentTenantId(tenant.id!);
    } catch (_) {
      if (!mounted) return;
      setState(() => _switchingTo = null);
      ToastHelper.showError(context, context.l10n.redesignGroupsSwitchFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final tenants = ref.watch(userTenantsProvider);
    final current = ref.watch(currentTenantProvider);

    return PopScope(
      canPop: _switchingTo == null,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(l10n.redesignGroupsTitle, style: RdType.section(p)),
                    ),
                  ),
                  TextButton(
                    onPressed: _switchingTo == null ? () => Navigator.of(context).pop() : null,
                    style: TextButton.styleFrom(foregroundColor: p.link),
                    child: Text(
                      l10n.redesignCommonDone,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: tenants.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.redesignGroupsLoadFailed, style: RdType.meta(p)),
                  ),
                  data: (list) => SingleChildScrollView(
                    child: RdGroupedList(
                      children: [
                        for (final t in list)
                          RdListRow(
                            leading: RdInitials(
                              rdInitialsOf(t.shortName.isNotEmpty ? t.shortName : t.longName),
                              size: 40,
                              square: true,
                            ),
                            title: t.longName.isNotEmpty ? t.longName : t.shortName,
                            subtitle: profileRoleName(Role.fromValue(t.role ?? 99)),
                            selected: t.id == current?.id,
                            showChevron: false,
                            trailing: _switchingTo == t.id
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : t.id == current?.id
                                    ? Icon(Icons.check_circle, color: p.primary)
                                    : null,
                            onTap: _switchingTo == null ? () => _switch(t) : null,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RdOutlineButton(
                      label: l10n.redesignGroupsManage,
                      icon: Icons.apps,
                      onPressed: _switchingTo != null
                          ? null
                          : () {
                              final router = GoRouter.of(context);
                              Navigator.of(context).pop();
                              router.go('/tenants');
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
